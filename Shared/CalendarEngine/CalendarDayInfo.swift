import Foundation

public enum DaySubtitleKind: Hashable, Sendable {
    case festival     // Major traditional or Gregorian festival
    case solarTerm    // 二十四节气
    case lunarMonth   // 初一显示农历月份 (e.g. "十月", "闰六月")
    case lunarDay     // 普通农历日 (e.g. "十一", "廿三")
}

public struct CalendarDayInfo: Identifiable, Hashable, Sendable {
    public let id: String            // "YYYY-MM-DD"
    public let date: Date
    public let year: Int
    public let month: Int
    public let day: Int
    public let weekday: Int          // 1 = Sunday ... 7 = Saturday
    public let weekOfYear: Int
    public let isInCurrentMonth: Bool
    public let isToday: Bool
    public let isWeekend: Bool
    public let lunar: LunarDateInfo
    public let solarTerm: SolarTerm?
    public let holidayStatus: HolidayStatus?

    public var weekdayShortName: String {
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
    }

    public var weekdayFullName: String {
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
    }

    /// Prioritized subtitle text for compact calendar cells.
    public var subtitle: (text: String, kind: DaySubtitleKind) {
        if let traditional = lunar.traditionalFestival {
            return (traditional, .festival)
        }
        if let term = solarTerm {
            return (term.name, .solarTerm)
        }
        if let gregorian = lunar.gregorianFestival {
            return (gregorian, .festival)
        }
        if lunar.day == 1 {
            return (lunar.monthName, .lunarMonth)
        }
        return (lunar.dayName, .lunarDay)
    }

    /// Combined tags for detail banner (e.g. ["清明", "清明节"]).
    public var specialTags: [String] {
        var tags: [String] = []
        if let term = solarTerm {
            tags.append(term.name)
        }
        if let traditional = lunar.traditionalFestival, !tags.contains(traditional) {
            tags.append(traditional)
        }
        if let gregorian = lunar.gregorianFestival, !tags.contains(gregorian) {
            tags.append(gregorian)
        }
        return tags
    }

    /// Short festival or solar-term label intended for the macOS menu bar.
    /// Returns `nil` on ordinary days so only the minimalist icon is shown.
    public func menuBarFestivalLabel(includeSolarTerms: Bool) -> String? {
        if let traditional = lunar.traditionalFestival {
            return traditional
        }
        if solarTerm?.name == "清明" {
            return "清明节"
        }
        if let gregorian = lunar.gregorianFestival {
            return gregorian
        }
        if includeSolarTerms, let term = solarTerm {
            return term.name
        }
        return nil
    }

    public var isOffDay: Bool {
        if case .offDay = holidayStatus { return true }
        return false
    }

    public var isAdjustedWorkday: Bool {
        if case .workDay = holidayStatus { return true }
        return false
    }
}
