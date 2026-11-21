import Foundation
import AppKit
import Combine

public struct AppUpdateInfo: Equatable, Sendable {
    public let version: String
    public let tagName: String
    public let releaseNotes: String
    public let downloadURL: URL
    public let htmlURL: URL
}

public enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(AppUpdateInfo)
    case downloading(info: AppUpdateInfo, progress: Double)
    case readyToInstall(AppUpdateInfo)
    case installing
    case failed(String)
}

private struct GitHubReleaseResponse: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let body: String?
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlURL = "html_url"
        case assets
    }
}

private struct StagedUpdatePackage {
    let info: AppUpdateInfo
    let stagedAppURL: URL
    let workDirURL: URL
}

@MainActor
public final class AppUpdater: ObservableObject {
    public static let shared = AppUpdater()
    public static let repoSlug = "iwtem/Daydrop"
    private static let checkInterval: TimeInterval = 6 * 3600

    @Published public var state: UpdateState = .idle
    @Published public var availableUpdate: AppUpdateInfo?
    @Published public var dismissedVersionForSession: String?
    @Published public var isPushConnected: Bool = false

    private var stagedPackage: StagedUpdatePackage?
    private var periodicTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var pushListener: UpdatePushListener?
    private var lastETag: String?
    private var hasStartedScheduler = false

    public var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.2.0"
    }

    public var shouldShowBanner: Bool {
        guard let update = availableUpdate else { return false }
        return dismissedVersionForSession != update.version
    }

    /// Shows a quiet coral dot badge on the menu bar icon once an update is downloaded
    /// and ready to install (or waiting for manual download when auto-download is off).
    public var hasMenuBarUpdateBadge: Bool {
        guard shouldShowBanner else { return false }
        switch state {
        case .readyToInstall, .available:
            return true
        default:
            return false
        }
    }

    private init() {}

    deinit {
        periodicTimer?.invalidate()
        pushListener?.stop()
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Version Parsing & Comparison (Pure & Testable)

    public nonisolated static func normalizedVersion(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    public nonisolated static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let rParts = normalizedVersion(remote).split(separator: ".").map { Int($0) ?? 0 }
        let lParts = normalizedVersion(local).split(separator: ".").map { Int($0) ?? 0 }
        let count = max(rParts.count, lParts.count)
        for i in 0..<count {
            let rv = i < rParts.count ? rParts[i] : 0
            let lv = i < lParts.count ? lParts[i] : 0
            if rv != lv {
                return rv > lv
            }
        }
        return false
    }

    public nonisolated static func parseLatestRelease(_ data: Data) -> AppUpdateInfo? {
        guard let payload = try? JSONDecoder().decode(GitHubReleaseResponse.self, from: data) else {
            return nil
        }
        guard let zipAsset = payload.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) else {
            return nil
        }
        let version = normalizedVersion(payload.tagName)
        return AppUpdateInfo(
            version: version,
            tagName: payload.tagName,
            releaseNotes: payload.body ?? "",
            downloadURL: zipAsset.browserDownloadURL,
            htmlURL: payload.htmlURL
        )
    }

    // MARK: - Background Scheduler (Real-Time SSE Push + Periodic 6h Fallback + Wake)

    public func startBackgroundScheduler() {
        guard !hasStartedScheduler else { return }
        hasStartedScheduler = true

        // 1. Start real-time SSE push listener if automatic updates are enabled
        refreshPushSubscription()

        // 2. Startup check (throttled to 6h fallback)
        checkIfDueInBackground()

        // 3. Periodic 6h fallback check (safety net in case push was missed while offline)
        periodicTimer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIfDueInBackground()
            }
        }

        // 4. Reconnect SSE & run fallback check on Mac wake from sleep
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if AppPreferences.shared.autoCheckUpdates {
                    self?.pushListener?.restart()
                }
                self?.checkIfDueInBackground()
            }
        }
    }

    public func refreshPushSubscription() {
        if AppPreferences.shared.autoCheckUpdates {
            if pushListener == nil {
                pushListener = UpdatePushListener { [weak self] versionHint in
                    Task { @MainActor in
                        await self?.handlePushSignal(versionHint: versionHint)
                    }
                }
            }
            pushListener?.start()
            isPushConnected = true
        } else {
            pushListener?.stop()
            isPushConnected = false
        }
    }

    private func handlePushSignal(versionHint: String?) async {
        guard AppPreferences.shared.autoCheckUpdates else { return }
        // If push carries a version hint and it's not newer than current, skip unnecessary API call
        if let hint = versionHint, !hint.isEmpty,
           hint.rangeOfCharacter(from: .decimalDigits) != nil,
           !Self.isVersion(hint, newerThan: currentVersion) {
            return
        }
        // Bypass ETag cache slightly on explicit push signal so fresh release is fetched immediately
        lastETag = nil
        await checkForUpdates(silent: true)
    }

    private func checkIfDueInBackground() {
        guard AppPreferences.shared.autoCheckUpdates else { return }
        if let last = AppPreferences.shared.lastUpdateCheckDate,
           Date().timeIntervalSince(last) < Self.checkInterval {
            return
        }
        Task {
            await checkForUpdates(silent: true)
        }
    }

    // MARK: - Check for Updates

    public func checkForUpdates(silent: Bool = false) async {
        if case .downloading = state { return }
        if case .installing = state { return }

        if !silent {
            state = .checking
        }

        guard let url = URL(string: "https://api.github.com/repos/\(Self.repoSlug)/releases/latest") else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Daydrop/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        if let etag = lastETag, silent {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                if !silent { state = .failed(L10n.current.updateCheckFailed) }
                return
            }

            if http.statusCode == 304 {
                AppPreferences.shared.lastUpdateCheckDate = Date()
                return
            }

            guard (200...299).contains(http.statusCode) else {
                if !silent {
                    state = .failed(L10n.current.updateCheckFailed)
                }
                return
            }

            if let etag = http.value(forHTTPHeaderField: "ETag") {
                lastETag = etag
            }
            AppPreferences.shared.lastUpdateCheckDate = Date()

            guard let release = Self.parseLatestRelease(data) else {
                if !silent { state = .upToDate }
                return
            }

            if Self.isVersion(release.version, newerThan: currentVersion) {
                availableUpdate = release

                // Already downloaded & verified this exact version? Stay ready to install!
                if let staged = stagedPackage,
                   staged.info.version == release.version,
                   FileManager.default.fileExists(atPath: staged.stagedAppURL.path) {
                    state = .readyToInstall(release)
                    return
                }

                // Auto-download silently in background if enabled; otherwise wait for user click
                if AppPreferences.shared.autoDownloadUpdates {
                    await downloadAndStage(release, silentErrors: silent)
                } else {
                    state = .available(release)
                }
            } else {
                availableUpdate = nil
                cleanupStagedPackage()
                state = silent ? .idle : .upToDate
            }
        } catch {
            if !silent {
                state = .failed(L10n.current.updateCheckFailed)
            }
        }
    }

    public func dismissBannerForSession() {
        dismissedVersionForSession = availableUpdate?.version
    }

    // MARK: - Step 1: Download, Extract & Verify (Staged Ready — Does NOT Auto-Quit)

    public func startManualDownload() {
        guard let update = availableUpdate else { return }
        if let staged = stagedPackage,
           staged.info.version == update.version,
           FileManager.default.fileExists(atPath: staged.stagedAppURL.path) {
            state = .readyToInstall(update)
            return
        }
        Task {
            await downloadAndStage(update, silentErrors: false)
        }
    }

    private func downloadAndStage(_ update: AppUpdateInfo, silentErrors: Bool) async {
        if case .downloading = state { return }
        if case .installing = state { return }

        cleanupStagedPackage()
        state = .downloading(info: update, progress: 0.02)

        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("DaydropUpdate-\(UUID().uuidString)", isDirectory: true)
        let zipURL = workDir.appendingPathComponent("Daydrop-update.zip")
        let extractDir = workDir.appendingPathComponent("extracted", isDirectory: true)

        do {
            try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

            var request = URLRequest(url: update.downloadURL)
            request.timeoutInterval = 120
            request.setValue("Daydrop/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw NSError(domain: "DaydropUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: L10n.current.updateDownloadFailed])
            }

            let expectedLength = response.expectedContentLength
            fm.createFile(atPath: zipURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: zipURL)
            defer { try? handle.close() }

            var buffer = Data()
            buffer.reserveCapacity(65_536)
            var downloaded: Int64 = 0
            var lastReportedProgress: Double = 0

            for try await byte in asyncBytes {
                buffer.append(byte)
                downloaded += 1
                if buffer.count >= 65_536 {
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                    if expectedLength > 0 {
                        let p = min(0.98, Double(downloaded) / Double(expectedLength))
                        if p - lastReportedProgress >= 0.02 {
                            lastReportedProgress = p
                            state = .downloading(info: update, progress: p)
                        }
                    }
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
            }
            try handle.close()

            // Extract using ditto (preserves macOS bundle structure & signatures)
            try runTool("/usr/bin/ditto", arguments: ["-x", "-k", zipURL.path, extractDir.path])

            // Validate extracted Daydrop.app
            guard let stagedApp = findAppBundle(in: extractDir) else {
                throw NSError(domain: "DaydropUpdater", code: 2, userInfo: [NSLocalizedDescriptionKey: L10n.current.updateVerifyFailed])
            }

            let stagedBundle = Bundle(url: stagedApp)
            guard stagedBundle?.bundleIdentifier == "com.daydrop.app",
                  fm.fileExists(atPath: stagedApp.appendingPathComponent("Contents/MacOS/Daydrop").path) else {
                throw NSError(domain: "DaydropUpdater", code: 3, userInfo: [NSLocalizedDescriptionKey: L10n.current.updateVerifyFailed])
            }

            // Strip quarantine attribute before user restarts
            _ = try? runTool("/usr/bin/xattr", arguments: ["-dr", "com.apple.quarantine", stagedApp.path])

            // Remove zip archive to save temp space while keeping extracted app ready
            try? fm.removeItem(at: zipURL)

            stagedPackage = StagedUpdatePackage(
                info: update,
                stagedAppURL: stagedApp,
                workDirURL: workDir
            )
            state = .readyToInstall(update)
        } catch {
            try? fm.removeItem(at: workDir)
            if silentErrors {
                // Fall back gracefully to manual download prompt
                state = .available(update)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Step 2: User-Initiated Restart & Atomic Replace

    public func restartAndInstallReadyUpdate() {
        guard let staged = stagedPackage,
              FileManager.default.fileExists(atPath: staged.stagedAppURL.path) else {
            // If temp package was purged by OS, re-download gracefully
            startManualDownload()
            return
        }

        state = .installing

        do {
            let targetApp = resolveInstallTargetURL()
            let targetParent = targetApp.deletingLastPathComponent()
            guard FileManager.default.isWritableFile(atPath: targetParent.path) else {
                throw NSError(domain: "DaydropUpdater", code: 4, userInfo: [NSLocalizedDescriptionKey: L10n.current.updatePermissionFailed])
            }

            try launchAtomicSwapAndRelaunch(
                stagedAppPath: staged.stagedAppURL.path,
                targetAppPath: targetApp.path,
                workDirPath: staged.workDirURL.path,
                currentPID: ProcessInfo.processInfo.processIdentifier
            )

            NSApplication.shared.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func cleanupStagedPackage() {
        if let existing = stagedPackage {
            try? FileManager.default.removeItem(at: existing.workDirURL)
            stagedPackage = nil
        }
    }

    private func resolveInstallTargetURL() -> URL {
        let current = Bundle.main.bundleURL
        let path = current.path
        if path.contains("AppTranslocation") || path.hasPrefix("/Volumes/") || !FileManager.default.isWritableFile(atPath: current.deletingLastPathComponent().path) {
            return URL(fileURLWithPath: "/Applications/Daydrop.app")
        }
        return current
    }

    private func findAppBundle(in directory: URL) -> URL? {
        let direct = directory.appendingPathComponent("Daydrop.app")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        if let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for item in contents where item.pathExtension == "app" {
                return item
            }
        }
        return nil
    }

    @discardableResult
    private func runTool(_ executable: String, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(domain: "DaydropUpdater", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: L10n.current.updateInstallFailed
            ])
        }
        return process.terminationStatus
    }

    private func launchAtomicSwapAndRelaunch(
        stagedAppPath: String,
        targetAppPath: String,
        workDirPath: String,
        currentPID: Int32
    ) throws {
        let scriptPath = (workDirPath as NSString).appendingPathComponent("apply_update.sh")
        let backupPath = (workDirPath as NSString).appendingPathComponent("Daydrop.backup.app")

        let script = """
        #!/bin/sh
        PID="$1"
        STAGED="$2"
        TARGET="$3"
        BACKUP="$4"
        WORKDIR="$5"

        COUNT=0
        while kill -0 "$PID" 2>/dev/null; do
          sleep 0.2
          COUNT=$((COUNT + 1))
          if [ "$COUNT" -ge 75 ]; then
            break
          fi
        done

        # Stop any resident widget extension from the previous version before swapping bundles,
        # preventing chronod from reusing an old-version process whose archives fail validation.
        /usr/bin/pkill -x DaydropWidget >/dev/null 2>&1 || true

        if [ -d "$TARGET" ]; then
          mv "$TARGET" "$BACKUP" || exit 1
        fi

        if /usr/bin/ditto "$STAGED" "$TARGET"; then
          rm -rf "$BACKUP"
        else
          if [ -d "$BACKUP" ]; then
            mv "$BACKUP" "$TARGET"
          fi
          rm -rf "$WORKDIR"
          exit 1
        fi

        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "$TARGET" >/dev/null 2>&1 || true
        if [ -d "$TARGET/Contents/PlugIns/DaydropWidget.appex" ]; then
          /usr/bin/pluginkit -a "$TARGET/Contents/PlugIns/DaydropWidget.appex" >/dev/null 2>&1 || true
        fi
        # Ensure no stale DaydropWidget process respawned mid-swap before launching the new app
        /usr/bin/pkill -x DaydropWidget >/dev/null 2>&1 || true

        /usr/bin/open -n "$TARGET"
        rm -rf "$WORKDIR"
        """

        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/bin/sh")
        launcher.arguments = [scriptPath, "\(currentPID)", stagedAppPath, targetAppPath, backupPath, workDirPath]
        launcher.standardOutput = FileHandle.nullDevice
        launcher.standardError = FileHandle.nullDevice
        try launcher.run()
    }
}
