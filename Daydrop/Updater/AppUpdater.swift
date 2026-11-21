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
    case downloading(progress: Double)
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

@MainActor
public final class AppUpdater: ObservableObject {
    public static let shared = AppUpdater()
    public static let repoSlug = "iwtem/Daydrop"

    @Published public var state: UpdateState = .idle
    @Published public var availableUpdate: AppUpdateInfo?
    @Published public var dismissedVersionForSession: String?

    public var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.1.0"
    }

    public var shouldShowBanner: Bool {
        guard let update = availableUpdate else { return false }
        return dismissedVersionForSession != update.version
    }

    private init() {}

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

    // MARK: - Check for Updates

    public func checkOnLaunchIfNeeded() {
        guard AppPreferences.shared.autoCheckUpdates else { return }
        if let last = AppPreferences.shared.lastUpdateCheckDate,
           Date().timeIntervalSince(last) < 6 * 3600 {
            return
        }
        Task {
            await checkForUpdates(silent: true)
        }
    }

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

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                if !silent {
                    state = .failed(L10n.current.updateCheckFailed)
                }
                return
            }

            AppPreferences.shared.lastUpdateCheckDate = Date()

            guard let release = Self.parseLatestRelease(data) else {
                if !silent { state = .upToDate }
                return
            }

            if Self.isVersion(release.version, newerThan: currentVersion) {
                availableUpdate = release
                state = .available(release)
            } else {
                availableUpdate = nil
                if !silent {
                    state = .upToDate
                } else {
                    state = .idle
                }
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

    // MARK: - Download, Extract, Atomic Replace & Relaunch

    public func installAvailableUpdate() {
        guard let update = availableUpdate else { return }
        Task {
            await downloadAndInstall(update)
        }
    }

    private func downloadAndInstall(_ update: AppUpdateInfo) async {
        state = .downloading(progress: 0.02)

        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("DaydropUpdate-\(UUID().uuidString)", isDirectory: true)
        let zipURL = workDir.appendingPathComponent("Daydrop-update.zip")
        let extractDir = workDir.appendingPathComponent("extracted", isDirectory: true)

        do {
            try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

            // 1. Stream download with live progress
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
                        let p = min(0.99, Double(downloaded) / Double(expectedLength))
                        if p - lastReportedProgress >= 0.02 {
                            lastReportedProgress = p
                            state = .downloading(progress: p)
                        }
                    }
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
            }
            try handle.close()

            state = .installing

            // 2. Extract with macOS ditto (preserves bundle structure & code signatures)
            try runTool("/usr/bin/ditto", arguments: ["-x", "-k", zipURL.path, extractDir.path])

            // 3. Locate and validate Daydrop.app
            guard let stagedApp = findAppBundle(in: extractDir) else {
                throw NSError(domain: "DaydropUpdater", code: 2, userInfo: [NSLocalizedDescriptionKey: L10n.current.updateVerifyFailed])
            }

            let stagedBundle = Bundle(url: stagedApp)
            guard stagedBundle?.bundleIdentifier == "com.daydrop.app",
                  fm.fileExists(atPath: stagedApp.appendingPathComponent("Contents/MacOS/Daydrop").path) else {
                throw NSError(domain: "DaydropUpdater", code: 3, userInfo: [NSLocalizedDescriptionKey: L10n.current.updateVerifyFailed])
            }

            // Strip quarantine attribute from freshly downloaded bundle
            _ = try? runTool("/usr/bin/xattr", arguments: ["-dr", "com.apple.quarantine", stagedApp.path])

            // 4. Resolve install destination (replace current running .app if writable, else /Applications/Daydrop.app)
            let targetApp = resolveInstallTargetURL()
            let targetParent = targetApp.deletingLastPathComponent()
            guard fm.isWritableFile(atPath: targetParent.path) else {
                throw NSError(domain: "DaydropUpdater", code: 4, userInfo: [NSLocalizedDescriptionKey: L10n.current.updatePermissionFailed])
            }

            // 5. Spawn detached shell script to wait for exit, swap atomically, re-register LaunchServices, and relaunch
            try launchAtomicSwapAndRelaunch(
                stagedAppPath: stagedApp.path,
                targetAppPath: targetApp.path,
                workDirPath: workDir.path,
                currentPID: ProcessInfo.processInfo.processIdentifier
            )

            // 6. Quit current instance immediately so swap runs cleanly
            NSApplication.shared.terminate(nil)
        } catch {
            try? fm.removeItem(at: workDir)
            state = .failed(error.localizedDescription)
        }
    }

    private func resolveInstallTargetURL() -> URL {
        let current = Bundle.main.bundleURL
        let path = current.path
        // If running from AppTranslocation, DerivedData, or a read-only DMG volume, install into /Applications
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

        # Wait up to 15 seconds for current app instance to exit
        COUNT=0
        while kill -0 "$PID" 2>/dev/null; do
          sleep 0.2
          COUNT=$((COUNT + 1))
          if [ "$COUNT" -ge 75 ]; then
            break
          fi
        done

        # Backup existing bundle if present
        if [ -d "$TARGET" ]; then
          mv "$TARGET" "$BACKUP" || exit 1
        fi

        # Move newly downloaded bundle into place
        if /usr/bin/ditto "$STAGED" "$TARGET"; then
          rm -rf "$BACKUP"
        else
          # Rollback on failure
          if [ -d "$BACKUP" ]; then
            mv "$BACKUP" "$TARGET"
          fi
          rm -rf "$WORKDIR"
          exit 1
        fi

        # Re-register bundle + WidgetKit extension with LaunchServices
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "$TARGET" >/dev/null 2>&1 || true

        # Relaunch updated app cleanly
        /usr/bin/open -n "$TARGET"

        # Cleanup temp staging directory
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
