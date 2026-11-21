import Foundation
import SwiftUI
import Combine
import WidgetKit
#if canImport(ServiceManagement)
import ServiceManagement
#endif

public enum MenuBarDisplayStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case iconAndFestival = "iconAndFestival"
    case iconAndFestivalOnly = "iconAndFestivalOnly"
    case iconOnly = "iconOnly"
    case iconAndLunar = "iconAndLunar"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .iconAndFestival: return "极简图标（节日与节气显示名称）"
        case .iconAndFestivalOnly: return "极简图标（仅节日显示名称）"
        case .iconOnly: return "始终仅显示图标"
        case .iconAndLunar: return "图标 + 农历（如 十月十一）"
        }
    }
}

public enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public final class AppPreferences: ObservableObject {
    public static let suiteName = "com.daydrop.shared"
    public static let shared = AppPreferences()

    private let defaults: UserDefaults

    private enum Keys {
        static let language = "appLanguage"
        static let theme = "appTheme"
        static let weekStartsOnMonday = "weekStartsOnMonday"
        static let menuBarDisplayStyle = "menuBarDisplayStyle"
        static let appearanceMode = "appearanceMode"
        static let showHolidayBadges = "showHolidayBadges"
        static let showSolarTerms = "showSolarTerms"
        static let autoCheckUpdates = "autoCheckUpdates"
        static let autoDownloadUpdates = "autoDownloadUpdates"
        static let lastUpdateCheckTimestamp = "lastUpdateCheckTimestamp"
        static let lastHolidaySyncTimestamp = "lastHolidaySyncTimestamp"
    }

    @Published public var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            reloadWidgets()
        }
    }

    @Published public var theme: AppTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: Keys.theme)
            reloadWidgets()
        }
    }

    @Published public var weekStartsOnMonday: Bool {
        didSet {
            defaults.set(weekStartsOnMonday, forKey: Keys.weekStartsOnMonday)
            reloadWidgets()
        }
    }

    @Published public var menuBarDisplayStyle: MenuBarDisplayStyle {
        didSet {
            defaults.set(menuBarDisplayStyle.rawValue, forKey: Keys.menuBarDisplayStyle)
        }
    }

    @Published public var appearanceMode: AppearanceMode {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
            reloadWidgets()
        }
    }

    @Published public var showHolidayBadges: Bool {
        didSet {
            defaults.set(showHolidayBadges, forKey: Keys.showHolidayBadges)
            reloadWidgets()
        }
    }

    @Published public var showSolarTerms: Bool {
        didSet {
            defaults.set(showSolarTerms, forKey: Keys.showSolarTerms)
            reloadWidgets()
        }
    }

    @Published public var autoCheckUpdates: Bool {
        didSet {
            defaults.set(autoCheckUpdates, forKey: Keys.autoCheckUpdates)
        }
    }

    @Published public var autoDownloadUpdates: Bool {
        didSet {
            defaults.set(autoDownloadUpdates, forKey: Keys.autoDownloadUpdates)
        }
    }

    public var launchAtLogin: Bool {
        get {
            #if canImport(ServiceManagement)
            return SMAppService.mainApp.status == .enabled
            #else
            return false
            #endif
        }
        set {
            #if canImport(ServiceManagement)
            objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Ignore sandbox / dev-signed registration errors gracefully
            }
            #endif
        }
    }

    private init() {
        let store = UserDefaults(suiteName: Self.suiteName) ?? .standard
        self.defaults = store

        if let rawLang = store.string(forKey: Keys.language),
           let parsedLang = AppLanguage(rawValue: rawLang) {
            self.language = parsedLang
        } else {
            self.language = .system
        }

        if let rawTheme = store.string(forKey: Keys.theme),
           let parsedTheme = AppTheme(rawValue: rawTheme) {
            self.theme = parsedTheme
        } else {
            self.theme = .peachSoda
        }

        if store.object(forKey: Keys.weekStartsOnMonday) == nil {
            self.weekStartsOnMonday = true
        } else {
            self.weekStartsOnMonday = store.bool(forKey: Keys.weekStartsOnMonday)
        }

        if let raw = store.string(forKey: Keys.menuBarDisplayStyle),
           let parsed = MenuBarDisplayStyle(rawValue: raw) {
            self.menuBarDisplayStyle = parsed
        } else {
            self.menuBarDisplayStyle = .iconAndFestival
        }

        if let raw = store.string(forKey: Keys.appearanceMode),
           let parsed = AppearanceMode(rawValue: raw) {
            self.appearanceMode = parsed
        } else {
            self.appearanceMode = .system
        }

        if store.object(forKey: Keys.showHolidayBadges) == nil {
            self.showHolidayBadges = true
        } else {
            self.showHolidayBadges = store.bool(forKey: Keys.showHolidayBadges)
        }

        if store.object(forKey: Keys.showSolarTerms) == nil {
            self.showSolarTerms = true
        } else {
            self.showSolarTerms = store.bool(forKey: Keys.showSolarTerms)
        }

        if store.object(forKey: Keys.autoCheckUpdates) == nil {
            self.autoCheckUpdates = true
        } else {
            self.autoCheckUpdates = store.bool(forKey: Keys.autoCheckUpdates)
        }

        if store.object(forKey: Keys.autoDownloadUpdates) == nil {
            self.autoDownloadUpdates = true
        } else {
            self.autoDownloadUpdates = store.bool(forKey: Keys.autoDownloadUpdates)
        }
    }

    /// Snapshot readers for WidgetKit timelines without side effects.
    public static func widgetLanguage() -> AppLanguage {
        let store = UserDefaults(suiteName: suiteName) ?? .standard
        if let raw = store.string(forKey: Keys.language),
           let parsed = AppLanguage(rawValue: raw) {
            return parsed
        }
        return .system
    }

    public static func widgetTheme() -> AppTheme {
        let store = UserDefaults(suiteName: suiteName) ?? .standard
        if let raw = store.string(forKey: Keys.theme),
           let parsed = AppTheme(rawValue: raw) {
            return parsed
        }
        return .peachSoda
    }

    public var lastUpdateCheckDate: Date? {
        get {
            let ts = defaults.double(forKey: Keys.lastUpdateCheckTimestamp)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            if let date = newValue {
                defaults.set(date.timeIntervalSince1970, forKey: Keys.lastUpdateCheckTimestamp)
            } else {
                defaults.removeObject(forKey: Keys.lastUpdateCheckTimestamp)
            }
            defaults.synchronize()
        }
    }

    public var lastHolidaySyncDate: Date? {
        get {
            let ts = defaults.double(forKey: Keys.lastHolidaySyncTimestamp)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            objectWillChange.send()
            if let date = newValue {
                defaults.set(date.timeIntervalSince1970, forKey: Keys.lastHolidaySyncTimestamp)
            } else {
                defaults.removeObject(forKey: Keys.lastHolidaySyncTimestamp)
            }
            defaults.synchronize()
        }
    }

    public static func widgetWeekStartsOnMonday() -> Bool {
        let store = UserDefaults(suiteName: suiteName) ?? .standard
        if store.object(forKey: Keys.weekStartsOnMonday) == nil { return true }
        return store.bool(forKey: Keys.weekStartsOnMonday)
    }

    public static func widgetShowHolidayBadges() -> Bool {
        let store = UserDefaults(suiteName: suiteName) ?? .standard
        if store.object(forKey: Keys.showHolidayBadges) == nil { return true }
        return store.bool(forKey: Keys.showHolidayBadges)
    }

    private func reloadWidgets() {
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
