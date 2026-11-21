import Foundation
import SwiftUI
import Combine
import WidgetKit

public enum ExpandedViewMode: String, CaseIterable, Identifiable {
    case month = "月视图"
    case year = "年视图"
    public var id: String { rawValue }
}

final class AppState: ObservableObject {
    @Published var today: Date = Date()
    @Published var displayedYear: Int
    @Published var displayedMonth: Int
    @Published var selectedDate: Date
    @Published var expandedViewMode: ExpandedViewMode = .month
    @Published var isPinnedOnTop: Bool = false
    @Published var holidayRevision: Int = 0

    private var dayChangeObserver: NSObjectProtocol?
    private var holidayUpdateObserver: NSObjectProtocol?
    private var midnightTimer: Timer?

    init() {
        let now = Date()
        let cal = Calendar.current
        self.today = now
        self.selectedDate = now
        self.displayedYear = cal.component(.year, from: now)
        self.displayedMonth = cal.component(.month, from: now)

        setupDayRolloverTracking()
        holidayUpdateObserver = NotificationCenter.default.addObserver(
            forName: .daydropHolidaysDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.holidayRevision += 1
        }
        HolidayStore.shared.syncIfNeededOnLaunch()
        reconcileWidgetExtensionOnLaunch()
        Task { @MainActor in
            AppUpdater.shared.startBackgroundScheduler()
        }
    }

    deinit {
        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = holidayUpdateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        midnightTimer?.invalidate()
    }

    var todayInfo: CalendarDayInfo {
        MonthGridGenerator.dayInfo(for: today, inCurrentMonth: true, today: today)
    }

    var selectedDayInfo: CalendarDayInfo {
        MonthGridGenerator.dayInfo(for: selectedDate, inCurrentMonth: true, today: today)
    }

    var isDisplayingCurrentMonth: Bool {
        let cal = Calendar.current
        return displayedYear == cal.component(.year, from: today)
            && displayedMonth == cal.component(.month, from: today)
    }

    var currentMonthDays: [CalendarDayInfo] {
        MonthGridGenerator.generateMonthGrid(
            year: displayedYear,
            month: displayedMonth,
            weekStartsOnMonday: AppPreferences.shared.weekStartsOnMonday,
            today: today
        )
    }

    func menuBarTitle(for style: MenuBarDisplayStyle, l10n: L10n) -> String {
        let info = todayInfo
        switch style {
        case .iconAndFestival:
            return l10n.localizedMenuBarFestival(for: info, includeSolarTerms: AppPreferences.shared.showSolarTerms) ?? ""
        case .iconAndFestivalOnly:
            return l10n.localizedMenuBarFestival(for: info, includeSolarTerms: false) ?? ""
        case .iconOnly:
            return ""
        case .iconAndLunar:
            return l10n.localizedMenuBarFestival(for: info, includeSolarTerms: AppPreferences.shared.showSolarTerms) ?? l10n.lunarMonthDay(info.lunar)
        }
    }

    func goToToday() {
        refreshTodayIfNeeded()
        let cal = Calendar.current
        displayedYear = cal.component(.year, from: today)
        displayedMonth = cal.component(.month, from: today)
        selectedDate = today
        expandedViewMode = .month
    }

    func shiftMonth(by delta: Int) {
        let cal = Calendar.current
        guard let base = cal.date(from: DateComponents(year: displayedYear, month: displayedMonth, day: 1)),
              let shifted = cal.date(byAdding: .month, value: delta, to: base) else {
            return
        }
        displayedYear = cal.component(.year, from: shifted)
        displayedMonth = cal.component(.month, from: shifted)
    }

    func shiftYear(by delta: Int) {
        displayedYear = max(1901, min(2099, displayedYear + delta))
    }

    func jumpTo(year: Int, month: Int) {
        displayedYear = max(1901, min(2099, year))
        displayedMonth = max(1, min(12, month))
    }

    func selectDay(_ info: CalendarDayInfo) {
        selectedDate = info.date
        if !info.isInCurrentMonth {
            displayedYear = info.year
            displayedMonth = info.month
        }
    }

    func moveSelection(byDays delta: Int) {
        let cal = Calendar.current
        guard let next = cal.date(byAdding: .day, value: delta, to: selectedDate) else { return }
        selectedDate = next
        displayedYear = cal.component(.year, from: next)
        displayedMonth = cal.component(.month, from: next)
    }

    func refreshTodayIfNeeded() {
        let now = Date()
        let cal = Calendar.current
        if !cal.isDate(today, inSameDayAs: now) {
            today = now
            AppPreferences.reloadAllWidgets()
        }
    }

    static func currentAppBuildSignature(bundle: Bundle = .main) -> String {
        let short = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        let build = (bundle.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
        return "\(short) (\(build))"
    }

    /// Reconciles the embedded WidgetKit extension after an app update (both in-app and manual)
    /// so `chronod` never talks to a stale `DaydropWidget` process whose CFBundleVersion conflicts
    /// with LaunchServices — which would otherwise cause all widget timeline reloads to fail and
    /// fall back to stale, redacted placeholders with outdated themes.
    private func reconcileWidgetExtensionOnLaunch() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else { return }

        let currentSignature = Self.currentAppBuildSignature()
        let lastSignature = AppPreferences.shared.lastLaunchedBuildSignature
        let bundlePath = bundleURL.path
        let isTemporaryBuildPath = bundlePath.hasPrefix("/tmp/")
            || bundlePath.hasPrefix("/private/tmp/")
            || bundlePath.contains("/.tmp/")
            || bundlePath.contains("/DerivedData/")

        if lastSignature != currentSignature && !isTemporaryBuildPath {
            AppPreferences.shared.lastLaunchedBuildSignature = currentSignature
            let widgetAppexPath = bundleURL
                .appendingPathComponent("Contents/PlugIns/DaydropWidget.appex")
                .path

            DispatchQueue.global(qos: .utility).async {
                Self.runSilently("/usr/bin/pkill", arguments: ["-x", "DaydropWidget"])
                Self.runSilently(
                    "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                    arguments: ["-f", "-R", bundlePath]
                )
                if FileManager.default.fileExists(atPath: widgetAppexPath) {
                    Self.runSilently("/usr/bin/pluginkit", arguments: ["-a", widgetAppexPath])
                }
                Self.runSilently("/usr/bin/pkill", arguments: ["-x", "DaydropWidget"])

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    AppPreferences.reloadAllWidgets()
                }
            }
        } else {
            AppPreferences.reloadAllWidgets()
        }
    }

    private static func runSilently(_ executable: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Best-effort helper; never block or crash app startup
        }
    }

    private func setupDayRolloverTracking() {
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshTodayIfNeeded()
            self?.scheduleNextMidnightTimer()
        }
        scheduleNextMidnightTimer()
    }

    private func scheduleNextMidnightTimer() {
        midnightTimer?.invalidate()
        let cal = Calendar.current
        let now = Date()
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) else { return }
        let interval = max(1.0, tomorrow.timeIntervalSince(now) + 1.0)
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.refreshTodayIfNeeded()
            self?.scheduleNextMidnightTimer()
        }
    }
}
