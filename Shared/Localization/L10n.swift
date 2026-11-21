import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    public var id: String { rawValue }

    public var resolvedIsChinese: Bool {
        switch self {
        case .zhHans:
            return true
        case .en:
            return false
        case .system:
            let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
            return preferred.lowercased().hasPrefix("zh")
        }
    }

    public func displayName(isChinese: Bool) -> String {
        switch self {
        case .system: return isChinese ? "跟随系统" : "System Default"
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

/// Centralized bilingual (Simplified Chinese / English) localization provider shared by
/// both the main macOS app and the WidgetKit desktop extension.
public struct L10n: Sendable {
    public let isChinese: Bool

    public init(language: AppLanguage = AppPreferences.shared.language) {
        self.isChinese = language.resolvedIsChinese
    }

    public init(isChinese: Bool) {
        self.isChinese = isChinese
    }

    public static var current: L10n {
        L10n(language: AppPreferences.shared.language)
    }

    public static var widgetCurrent: L10n {
        L10n(language: AppPreferences.widgetLanguage())
    }

    // MARK: - Brand & Chrome

    public var appName: String { isChinese ? "知时" : "Daydrop" }
    public var appBrandFooter: String { isChinese ? "知时 · Daydrop" : "Daydrop" }
    public var windowTitle: String { isChinese ? "知时 · Daydrop" : "Daydrop" }
    public var settingsTitle: String { isChinese ? "知时 · 偏好设置" : "Daydrop Settings" }
    public var settingsSubtitle: String {
        let ver = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.1.0"
        return isChinese ? "轻如水滴的 macOS 原生极简日历 · v\(ver)" : "Minimalist native macOS calendar · v\(ver)"
    }
    public var quit: String { isChinese ? "退出" : "Quit" }
    public var quitApp: String { isChinese ? "退出知时" : "Quit Daydrop" }
    public var todayShort: String { isChinese ? "今" : "T" }
    public var todayFull: String { isChinese ? "今天" : "Today" }
    public var todayPrefix: String { isChinese ? "今日" : "Today" }

    // MARK: - View Modes & Sections

    public var viewModeMonth: String { isChinese ? "月视图" : "Month" }
    public var viewModeYear: String { isChinese ? "年视图" : "Year" }

    public var solarTermsThisMonth: String { isChinese ? "本月节气" : "Solar Terms" }
    public var upcomingTitle: String { isChinese ? "近期提醒" : "Upcoming" }

    // MARK: - Date Formatting

    public func yearTitle(_ year: Int) -> String {
        isChinese ? "\(String(year))年" : "\(String(year))"
    }

    public func yearLabelInPicker(_ year: Int) -> String {
        isChinese ? "\(String(year)) 年" : "\(String(year))"
    }

    public func monthShort(_ month: Int) -> String {
        if isChinese { return "\(month)月" }
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return names[max(0, min(11, month - 1))]
    }

    public func yearMonthTitle(year: Int, month: Int) -> String {
        isChinese ? "\(String(year))年 \(month)月" : "\(monthShort(month)) \(String(year))"
    }

    public func monthDayTitle(month: Int, day: Int) -> String {
        isChinese ? "\(month)月\(day)日" : "\(monthShort(month)) \(day)"
    }

    public func weekOfYear(_ week: Int, compact: Bool = true) -> String {
        if isChinese {
            return compact ? "第\(week)周" : "第 \(week) 周"
        }
        return compact ? "W\(week)" : "Week \(week)"
    }

    public func weekdayShort(_ weekday: Int) -> String {
        if isChinese {
            switch weekday {
            case 1: return "周日"
            case 2: return "周一"
            case 3: return "周二"
            case 4: return "周三"
            case 5: return "周四"
            case 6: return "周五"
            case 7: return "周六"
            default: return ""
            }
        } else {
            switch weekday {
            case 1: return "Sun"
            case 2: return "Mon"
            case 3: return "Tue"
            case 4: return "Wed"
            case 5: return "Thu"
            case 6: return "Fri"
            case 7: return "Sat"
            default: return ""
            }
        }
    }

    public func weekdayFull(_ weekday: Int) -> String {
        if isChinese {
            switch weekday {
            case 1: return "星期日"
            case 2: return "星期一"
            case 3: return "星期二"
            case 4: return "星期三"
            case 5: return "星期四"
            case 6: return "星期五"
            case 7: return "星期六"
            default: return ""
            }
        } else {
            switch weekday {
            case 1: return "Sunday"
            case 2: return "Monday"
            case 3: return "Tuesday"
            case 4: return "Wednesday"
            case 5: return "Thursday"
            case 6: return "Friday"
            case 7: return "Saturday"
            default: return ""
            }
        }
    }

    public func weekdayHeaders(weekStartsOnMonday: Bool, singleLetter: Bool = false) -> [(title: String, isWeekend: Bool)] {
        if isChinese {
            return MonthGridGenerator.weekdayHeaders(weekStartsOnMonday: weekStartsOnMonday)
        }
        let monToSun: [(String, Bool)] = singleLetter
            ? [("M", false), ("T", false), ("W", false), ("T", false), ("F", false), ("S", true), ("S", true)]
            : [("Mo", false), ("Tu", false), ("We", false), ("Th", false), ("Fr", false), ("Sa", true), ("Su", true)]
        if weekStartsOnMonday {
            return monToSun
        } else {
            return [monToSun[6]] + Array(monToSun[0..<6])
        }
    }

    // MARK: - Badges & Countdowns

    public var offDayBadge: String { isChinese ? "休" : "Off" }
    public var workDayBadge: String { isChinese ? "班" : "Wk" }

    public func holidayStatusPill(_ status: HolidayStatus, compact: Bool = true) -> String {
        switch status {
        case .offDay(let name):
            let localized = holidayName(name)
            return isChinese ? (compact ? "\(localized)休" : "\(localized)假期") : "\(localized) Off"
        case .workDay(let name):
            let localized = holidayName(name)
            return isChinese ? (compact ? "\(localized)调休上班" : "\(localized)补班") : "\(localized) Work"
        }
    }

    public func countdownCompact(label: String, days: Int) -> String {
        isChinese ? "距\(label) \(days)天" : "\(label) in \(days)d"
    }

    public func countdownTiny(label: String, days: Int) -> String {
        isChinese ? "\(label) \(days)天" : "\(label) \(days)d"
    }

    public func daysLater(_ days: Int) -> String {
        isChinese ? "\(days)天后" : "in \(days)d"
    }

    public func nextSolarTermRow(_ termName: String) -> String {
        let name = solarTermName(termName, compact: false)
        return isChinese ? "下一个节气 · \(name)" : "Next Term · \(name)"
    }

    public func nextHolidayRow(_ holiday: String) -> String {
        let name = holidayName(holiday)
        return isChinese ? "下一个假期 · \(name)" : "Next Holiday · \(name)"
    }

    // MARK: - Lunar, Solar Terms & Festivals

    public func lunarCompactCell(_ lunar: LunarDateInfo) -> String {
        if isChinese { return lunar.compactLunarText }
        if lunar.day == 1 {
            return lunar.isLeapMonth ? "Leap \(lunar.month)" : "L\(lunar.month)/1"
        }
        return "L\(lunar.day)"
    }

    public func lunarMonthDay(_ lunar: LunarDateInfo) -> String {
        if isChinese { return lunar.monthDayText }
        return lunar.isLeapMonth ? "Lunar Leap \(lunar.month)/\(lunar.day)" : "Lunar \(lunar.month)/\(lunar.day)"
    }

    public func lunarYearLabel(_ lunar: LunarDateInfo) -> String {
        if isChinese { return "\(lunar.ganZhiYear)\(lunar.zodiac)年" }
        return "Year of the \(zodiacEnglish(lunar.zodiac))"
    }

    public func lunarYearCompact(_ lunar: LunarDateInfo) -> String {
        if isChinese { return "\(lunar.ganZhiYear)\(lunar.zodiac)年" }
        return "\(zodiacEnglish(lunar.zodiac)) Year"
    }

    public func lunarFullDescription(_ lunar: LunarDateInfo) -> String {
        if isChinese { return lunar.fullDescription }
        return "\(lunarYearLabel(lunar)) · \(lunarMonthDay(lunar))"
    }

    public func zodiacEnglish(_ zh: String) -> String {
        switch zh {
        case "鼠": return "Rat"
        case "牛": return "Ox"
        case "虎": return "Tiger"
        case "兔": return "Rabbit"
        case "龙": return "Dragon"
        case "蛇": return "Snake"
        case "马": return "Horse"
        case "羊": return "Goat"
        case "猴": return "Monkey"
        case "鸡": return "Rooster"
        case "狗": return "Dog"
        case "猪": return "Pig"
        default: return zh
        }
    }

    public func solarTermName(_ zh: String, compact: Bool = true) -> String {
        if isChinese { return zh }
        switch zh {
        case "小寒": return "Minor Cold"
        case "大寒": return "Major Cold"
        case "立春": return compact ? "Spring Bgn" : "Start of Spring"
        case "雨水": return "Rain Water"
        case "惊蛰": return compact ? "Insects" : "Awakening"
        case "春分": return compact ? "Vernal Eq" : "Spring Equinox"
        case "清明": return "Qingming"
        case "谷雨": return "Grain Rain"
        case "立夏": return compact ? "Summer Bgn" : "Start of Summer"
        case "小满": return "Grain Buds"
        case "芒种": return compact ? "Grain Ear" : "Grain in Ear"
        case "夏至": return compact ? "Solstice" : "Summer Solstice"
        case "小暑": return "Minor Heat"
        case "大暑": return "Major Heat"
        case "立秋": return compact ? "Autumn Bgn" : "Start of Autumn"
        case "处暑": return compact ? "End Heat" : "End of Heat"
        case "白露": return "White Dew"
        case "秋分": return compact ? "Autumn Eq" : "Autumn Equinox"
        case "寒露": return "Cold Dew"
        case "霜降": return compact ? "Frost" : "Frost's Descent"
        case "立冬": return compact ? "Winter Bgn" : "Start of Winter"
        case "小雪": return "Minor Snow"
        case "大雪": return "Major Snow"
        case "冬至": return compact ? "Solstice" : "Winter Solstice"
        default: return zh
        }
    }

    public func holidayName(_ zh: String) -> String {
        if isChinese { return zh }
        switch zh {
        case "除夕": return "CNY Eve"
        case "春节": return "Spring Fest"
        case "元宵节": return "Lantern"
        case "龙抬头": return "Longtaitou"
        case "清明节": return "Qingming"
        case "端午节": return "Dragon Boat"
        case "七夕": return "Qixi"
        case "中元节": return "Zhongyuan"
        case "中秋节": return "Mid-Autumn"
        case "重阳节": return "Double 9th"
        case "腊八节": return "Laba"
        case "小年": return "Little NY"
        case "元旦": return "New Year"
        case "情人节": return "Valentine's"
        case "妇女节": return "Women's Day"
        case "植树节": return "Arbor Day"
        case "劳动节": return "Labor Day"
        case "青年节": return "Youth Day"
        case "儿童节": return "Children's"
        case "建党节": return "CPC Day"
        case "建军节": return "Army Day"
        case "教师节": return "Teachers'"
        case "国庆节": return "National Day"
        case "圣诞节": return "Christmas"
        default: return zh
        }
    }

    public func localizedSubtitle(for day: CalendarDayInfo, showSolarTerms: Bool) -> (text: String, kind: DaySubtitleKind) {
        if let traditional = day.lunar.traditionalFestival {
            return (holidayName(traditional), .festival)
        }
        if showSolarTerms, let term = day.solarTerm {
            return (solarTermName(term.name, compact: true), .solarTerm)
        }
        if let gregorian = day.lunar.gregorianFestival {
            return (holidayName(gregorian), .festival)
        }
        if day.lunar.day == 1 {
            return (lunarCompactCell(day.lunar), .lunarMonth)
        }
        return (lunarCompactCell(day.lunar), .lunarDay)
    }

    public func localizedTag(_ rawTag: String, isSolarTerm: Bool) -> String {
        isSolarTerm ? solarTermName(rawTag, compact: false) : holidayName(rawTag)
    }

    public func localizedMenuBarFestival(for day: CalendarDayInfo, includeSolarTerms: Bool) -> String? {
        guard let raw = day.menuBarFestivalLabel(includeSolarTerms: includeSolarTerms) else { return nil }
        if day.solarTerm?.name == raw {
            return solarTermName(raw, compact: true)
        }
        return holidayName(raw)
    }

    // MARK: - Settings Labels

    public var sectionGeneral: String { isChinese ? "常规" : "General" }
    public var sectionCalendarWidgets: String { isChinese ? "日历与桌面小组件" : "Calendar & Widgets" }
    public var labelLanguage: String { isChinese ? "语言" : "Language" }
    public var labelLaunchAtLogin: String { isChinese ? "开机自动启动" : "Launch at Login" }
    public var labelMenuBarStyle: String { isChinese ? "菜单栏展示" : "Menu Bar" }
    public var labelAppearance: String { isChinese ? "外观模式" : "Appearance" }
    public var labelWeekStart: String { isChinese ? "每周起始日" : "Week Starts On" }
    public var monday: String { isChinese ? "周一" : "Monday" }
    public var sunday: String { isChinese ? "周日" : "Sunday" }
    public var labelShowHolidays: String { isChinese ? "显示法定节假日与调休角标（休 / 班）" : "Show Holiday & Workday Badges" }
    public var labelShowSolarTerms: String { isChinese ? "显示二十四节气" : "Show 24 Solar Terms" }
    public var labelTheme: String { isChinese ? "主题配色" : "Theme" }
    public var sectionHolidayData: String { isChinese ? "节假日数据" : "Holiday Data" }
    public var labelCoveredYears: String { isChinese ? "已覆盖年份" : "Covered Years" }
    public var checkHolidayUpdate: String { isChinese ? "检查更新" : "Check Updates" }
    public var checkingHolidayUpdate: String { isChinese ? "正在同步…" : "Syncing…" }
    public var holidaySyncSuccess: String { isChinese ? "已同步最新节假日数据" : "Holiday data is up to date" }
    public var holidaySyncFailed: String { isChinese ? "网络暂不可用，继续使用内置离线数据" : "Offline — using built-in data" }

    // Software Updates
    public var sectionAppUpdate: String { isChinese ? "软件更新" : "Software Update" }
    public var labelAutoCheckUpdates: String { isChinese ? "自动检查新版本" : "Check for Updates Automatically" }
    public var labelCurrentVersion: String { isChinese ? "当前版本" : "Current Version" }
    public var checkAppUpdate: String { isChinese ? "检查更新" : "Check for Updates" }
    public var checkingAppUpdate: String { isChinese ? "正在检查…" : "Checking…" }
    public var appUpToDate: String { isChinese ? "已是最新版本" : "You're up to date" }
    public var updateNow: String { isChinese ? "立即更新" : "Update" }
    public var updateAndRelaunch: String { isChinese ? "立即更新并重启" : "Update & Relaunch" }
    public var installingUpdate: String { isChinese ? "正在安装并重启…" : "Installing & relaunching…" }
    public var updateCheckFailed: String { isChinese ? "检查更新失败，请稍后重试" : "Update check failed" }
    public var updateDownloadFailed: String { isChinese ? "下载更新包失败，请重试" : "Download failed" }
    public var updateVerifyFailed: String { isChinese ? "更新包校验失败" : "Update package verification failed" }
    public var updateInstallFailed: String { isChinese ? "解压更新包失败" : "Failed to unpack update" }
    public var updatePermissionFailed: String { isChinese ? "没有写入应用目录的权限" : "No write permission to app folder" }

    public func newVersionBanner(_ version: String) -> String {
        isChinese ? "发现新版本 v\(version)" : "v\(version) available"
    }

    public func downloadingPercent(_ pct: Int) -> String {
        isChinese ? "正在下载 \(pct)%" : "Downloading \(pct)%"
    }

    public var settingsSyncHint: String {
        isChinese ? "更改偏好将自动同步至桌面小组件" : "Changes sync automatically to desktop widgets"
    }

    public func themeName(_ theme: AppTheme) -> String {
        switch theme {
        case .peachSoda: return isChinese ? "蜜桃苏打" : "Peach Soda"
        case .mintCoral: return isChinese ? "薄荷珊瑚" : "Mint Coral"
        case .sunnyCitrus: return isChinese ? "阳光柑橘" : "Sunny Citrus"
        case .electricSky: return isChinese ? "电光晴空" : "Electric Sky"
        case .irisBerry: return isChinese ? "鸢尾莓粉" : "Iris Berry"
        }
    }

    public func menuBarStyleName(_ style: MenuBarDisplayStyle) -> String {
        switch style {
        case .iconAndFestival:
            return isChinese ? "极简图标（节日与节气显示名称）" : "Icon Only (Show Festivals & Solar Terms)"
        case .iconAndFestivalOnly:
            return isChinese ? "极简图标（仅节日显示名称）" : "Icon Only (Show Festivals Only)"
        case .iconOnly:
            return isChinese ? "始终仅显示图标" : "Icon Only"
        case .iconAndLunar:
            return isChinese ? "图标 + 农历（如 十月十一）" : "Icon + Lunar Date"
        }
    }

    public func appearanceName(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return isChinese ? "跟随系统" : "System"
        case .light: return isChinese ? "浅色" : "Light"
        case .dark: return isChinese ? "深色" : "Dark"
        }
    }

    // MARK: - Widget Gallery

    public var widgetDisplayName: String { isChinese ? "知时日历" : "Daydrop Calendar" }
    public var widgetDescription: String {
        isChinese ? "简洁展示公历、农历、二十四节气与法定节假日。" : "Minimalist calendar with holidays, 24 solar terms, and lunar dates."
    }
}
