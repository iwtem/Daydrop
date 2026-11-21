import Foundation

public struct LunarDateInfo: Hashable, Sendable {
    public let ganZhiYear: String       // e.g. "丙午"
    public let zodiac: String           // e.g. "马"
    public let month: Int               // 1...12
    public let day: Int                 // 1...30
    public let isLeapMonth: Bool
    public let monthName: String        // e.g. "正月", "闰六月", "腊月"
    public let dayName: String          // e.g. "初一", "十五", "廿九"
    public let traditionalFestival: String?
    public let gregorianFestival: String?

    /// Compact label for calendar grid cell (first day shows month name).
    public var compactLunarText: String {
        day == 1 ? monthName : dayName
    }

    /// Full readable lunar string, e.g. "丙午马年 十月十一"
    public var fullDescription: String {
        "\(ganZhiYear)\(zodiac)年 \(monthName)\(dayName)"
    }

    /// Short month+day string, e.g. "十月十一"
    public var monthDayText: String {
        "\(monthName)\(dayName)"
    }
}

public final class LunarCalendarEngine: @unchecked Sendable {
    public static let shared = LunarCalendarEngine()

    private static let heavenlyStems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let earthlyBranches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    private static let zodiacs = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]

    private static let monthNames = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月"
    ]

    private static let dayNames = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ]

    private static let beijingTimeZone = TimeZone(secondsFromGMT: 8 * 3600)!

    private static let chineseCalendar: Calendar = {
        var cal = Calendar(identifier: .chinese)
        cal.timeZone = beijingTimeZone
        return cal
    }()

    private static let gregorianCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = beijingTimeZone
        return cal
    }()

    private init() {}

    /// Computes lunar date info for the given Gregorian (year, month, day).
    public func lunarInfo(year: Int, month: Int, day: Int) -> LunarDateInfo {
        // Anchor at 12:00 Beijing Time to eliminate DST / timezone edge issues.
        var dc = DateComponents()
        dc.year = year
        dc.month = month
        dc.day = day
        dc.hour = 12
        let date = Self.gregorianCalendar.date(from: dc) ?? Date()

        let comps = Self.chineseCalendar.dateComponents([.year, .month, .day, .isLeapMonth], from: date)
        let cycleYear = comps.year ?? 1 // 1...60 in sexagenary cycle
        let lMonth = max(1, min(12, comps.month ?? 1))
        let lDay = max(1, min(30, comps.day ?? 1))
        let isLeap = comps.isLeapMonth ?? false

        let stemIndex = (cycleYear - 1) % 10
        let branchIndex = (cycleYear - 1) % 12
        let ganZhi = Self.heavenlyStems[stemIndex] + Self.earthlyBranches[branchIndex]
        let zodiac = Self.zodiacs[branchIndex]

        let baseMonthName = Self.monthNames[lMonth - 1]
        let monthName = isLeap ? "闰\(baseMonthName)" : baseMonthName
        let dayName = Self.dayNames[lDay - 1]

        let traditional = detectTraditionalFestival(
            date: date,
            lunarMonth: lMonth,
            lunarDay: lDay,
            isLeapMonth: isLeap
        )
        let gregorian = detectGregorianFestival(month: month, day: day)

        return LunarDateInfo(
            ganZhiYear: ganZhi,
            zodiac: zodiac,
            month: lMonth,
            day: lDay,
            isLeapMonth: isLeap,
            monthName: monthName,
            dayName: dayName,
            traditionalFestival: traditional,
            gregorianFestival: gregorian
        )
    }

    private func detectTraditionalFestival(
        date: Date,
        lunarMonth: Int,
        lunarDay: Int,
        isLeapMonth: Bool
    ) -> String? {
        guard !isLeapMonth else { return nil }

        // Check 除夕 (Lunar New Year's Eve): tomorrow is 正月初一
        if lunarMonth == 12 && lunarDay >= 29 {
            if let tomorrow = Self.gregorianCalendar.date(byAdding: .day, value: 1, to: date) {
                let tComps = Self.chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: tomorrow)
                if tComps.month == 1 && tComps.day == 1 && (tComps.isLeapMonth ?? false) == false {
                    return "除夕"
                }
            }
        }

        switch (lunarMonth, lunarDay) {
        case (1, 1):   return "春节"
        case (1, 15):  return "元宵节"
        case (2, 2):   return "龙抬头"
        case (5, 5):   return "端午节"
        case (7, 7):   return "七夕"
        case (7, 15):  return "中元节"
        case (8, 15):  return "中秋节"
        case (9, 9):   return "重阳节"
        case (12, 8):  return "腊八节"
        case (12, 23): return "小年"
        default:       return nil
        }
    }

    private func detectGregorianFestival(month: Int, day: Int) -> String? {
        switch (month, day) {
        case (1, 1):   return "元旦"
        case (2, 14):  return "情人节"
        case (3, 8):   return "妇女节"
        case (3, 12):  return "植树节"
        case (5, 1):   return "劳动节"
        case (5, 4):   return "青年节"
        case (6, 1):   return "儿童节"
        case (7, 1):   return "建党节"
        case (8, 1):   return "建军节"
        case (9, 10):  return "教师节"
        case (10, 1):  return "国庆节"
        case (12, 25): return "圣诞节"
        default:       return nil
        }
    }
}
