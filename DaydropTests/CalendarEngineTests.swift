import XCTest
@testable import Daydrop

final class CalendarEngineTests: XCTestCase {

    func testSolarTermsAccuracyFor2026() {
        let terms = SolarTermCalculator.shared.solarTerms(for: 2026)
        XCTAssertEqual(terms.count, 24)

        // Verify key official 2026 Beijing Time solar terms
        XCTAssertEqual(SolarTermCalculator.shared.solarTerm(year: 2026, month: 2, day: 4)?.name, "立春")
        XCTAssertEqual(SolarTermCalculator.shared.solarTerm(year: 2026, month: 3, day: 20)?.name, "春分")
        XCTAssertEqual(SolarTermCalculator.shared.solarTerm(year: 2026, month: 4, day: 5)?.name, "清明")
        XCTAssertEqual(SolarTermCalculator.shared.solarTerm(year: 2026, month: 6, day: 21)?.name, "夏至")
        XCTAssertEqual(SolarTermCalculator.shared.solarTerm(year: 2026, month: 9, day: 23)?.name, "秋分")
        XCTAssertEqual(SolarTermCalculator.shared.solarTerm(year: 2026, month: 11, day: 22)?.name, "小雪")
        XCTAssertEqual(SolarTermCalculator.shared.solarTerm(year: 2026, month: 12, day: 22)?.name, "冬至")
    }

    func testLunarCalendarAndTraditionalFestivals() {
        // 2026-02-16 is 除夕 (29-day 腊月 in 乙巳年)
        let eve2026 = LunarCalendarEngine.shared.lunarInfo(year: 2026, month: 2, day: 16)
        XCTAssertEqual(eve2026.traditionalFestival, "除夕")

        // 2026-02-17 is 春节 (丙午马年 正月初一)
        let cny2026 = LunarCalendarEngine.shared.lunarInfo(year: 2026, month: 2, day: 17)
        XCTAssertEqual(cny2026.ganZhiYear, "丙午")
        XCTAssertEqual(cny2026.zodiac, "马")
        XCTAssertEqual(cny2026.monthName, "正月")
        XCTAssertEqual(cny2026.dayName, "初一")
        XCTAssertEqual(cny2026.traditionalFestival, "春节")

        // 2026-09-25 is 中秋节 (八月十五)
        let midAutumn2026 = LunarCalendarEngine.shared.lunarInfo(year: 2026, month: 9, day: 25)
        XCTAssertEqual(midAutumn2026.traditionalFestival, "中秋节")
    }

    func testHolidayStoreChina2026() {
        // National Day 2026-10-01 offDay
        let oct1 = HolidayStore.shared.status(year: 2026, month: 10, day: 1)
        XCTAssertEqual(oct1, .offDay(name: "国庆节"))

        // Adjusted workday 2026-10-10
        let oct10 = HolidayStore.shared.status(year: 2026, month: 10, day: 10)
        XCTAssertEqual(oct10, .workDay(name: "国庆节"))

        // Upcoming holiday from 2026-11-20 should be 2027 元旦 (42 days later)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let nov20 = cal.date(from: DateComponents(year: 2026, month: 11, day: 20))!
        let next = HolidayStore.shared.nextHoliday(from: nov20, calendar: cal)
        XCTAssertEqual(next?.name, "元旦")
        XCTAssertEqual(next?.daysUntil, 42)
    }

    func testHolidayStoreChina2027Official() {
        // Spring Festival 2027: Feb 5 - Feb 13 off (9 days), Jan 31 & Feb 14 workdays
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 1, day: 31), .workDay(name: "春节"))
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 2, day: 5), .offDay(name: "春节"))
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 2, day: 13), .offDay(name: "春节"))
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 2, day: 14), .workDay(name: "春节"))

        // Labor Day 2027: May 1 - May 5 off, May 8 workday
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 5, day: 5), .offDay(name: "劳动节"))
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 5, day: 8), .workDay(name: "劳动节"))

        // Dragon Boat 2027: June 9 only (1 day, no adjustment)
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 6, day: 9), .offDay(name: "端午节"))
        XCTAssertNil(HolidayStore.shared.status(year: 2027, month: 6, day: 10))

        // Mid-Autumn 2027: Sep 15 only
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 9, day: 15), .offDay(name: "中秋节"))

        // National Day 2027: Oct 1 - Oct 7 off, Sep 26 & Oct 9 workdays
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 9, day: 26), .workDay(name: "国庆节"))
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 10, day: 7), .offDay(name: "国庆节"))
        XCTAssertEqual(HolidayStore.shared.status(year: 2027, month: 10, day: 9), .workDay(name: "国庆节"))
    }

    func testMonthGridStabilityAndWeekdayAlignment() {
        // 2026-11-01 is a Sunday
        let mondayStart = MonthGridGenerator.generateMonthGrid(year: 2026, month: 11, weekStartsOnMonday: true)
        XCTAssertEqual(mondayStart.count, 42)
        // With Monday start, Sunday Nov 1 should be at index 6
        XCTAssertEqual(mondayStart[6].month, 11)
        XCTAssertEqual(mondayStart[6].day, 1)
        XCTAssertTrue(mondayStart[6].isInCurrentMonth)

        let sundayStart = MonthGridGenerator.generateMonthGrid(year: 2026, month: 11, weekStartsOnMonday: false)
        XCTAssertEqual(sundayStart.count, 42)
        // With Sunday start, Sunday Nov 1 should be at index 0
        XCTAssertEqual(sundayStart[0].month, 11)
        XCTAssertEqual(sundayStart[0].day, 1)
    }

    func testMenuBarFestivalLabel() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!

        // Ordinary day: 2026-11-20 -> nil (icon only)
        let nov20 = cal.date(from: DateComponents(year: 2026, month: 11, day: 20))!
        let nov20Info = MonthGridGenerator.dayInfo(for: nov20, calendar: cal)
        XCTAssertNil(nov20Info.menuBarFestivalLabel(includeSolarTerms: true))
        XCTAssertNil(nov20Info.menuBarFestivalLabel(includeSolarTerms: false))

        // Solar term day: 2026-11-22 小雪
        let nov22 = cal.date(from: DateComponents(year: 2026, month: 11, day: 22))!
        let nov22Info = MonthGridGenerator.dayInfo(for: nov22, calendar: cal)
        XCTAssertEqual(nov22Info.menuBarFestivalLabel(includeSolarTerms: true), "小雪")
        XCTAssertNil(nov22Info.menuBarFestivalLabel(includeSolarTerms: false))

        // Qingming: 2026-04-05 -> 清明节 in both modes
        let apr5 = cal.date(from: DateComponents(year: 2026, month: 4, day: 5))!
        let apr5Info = MonthGridGenerator.dayInfo(for: apr5, calendar: cal)
        XCTAssertEqual(apr5Info.menuBarFestivalLabel(includeSolarTerms: true), "清明节")
        XCTAssertEqual(apr5Info.menuBarFestivalLabel(includeSolarTerms: false), "清明节")

        // Traditional festival: 2026-09-25 中秋节
        let sep25 = cal.date(from: DateComponents(year: 2026, month: 9, day: 25))!
        let sep25Info = MonthGridGenerator.dayInfo(for: sep25, calendar: cal)
        XCTAssertEqual(sep25Info.menuBarFestivalLabel(includeSolarTerms: false), "中秋节")

        // Gregorian festival: 2026-10-01 国庆节
        let oct1 = cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let oct1Info = MonthGridGenerator.dayInfo(for: oct1, calendar: cal)
        XCTAssertEqual(oct1Info.menuBarFestivalLabel(includeSolarTerms: false), "国庆节")
    }

    func testBilingualLocalization() {
        let zh = L10n(isChinese: true)
        let en = L10n(isChinese: false)

        XCTAssertEqual(zh.appName, "知时")
        XCTAssertEqual(en.appName, "Daydrop")
        XCTAssertEqual(zh.yearMonthTitle(year: 2026, month: 11), "2026年 11月")
        XCTAssertEqual(en.yearMonthTitle(year: 2026, month: 11), "Nov 2026")
        XCTAssertEqual(zh.solarTermName("小雪"), "小雪")
        XCTAssertEqual(en.solarTermName("小雪"), "Minor Snow")
        XCTAssertEqual(en.holidayName("中秋节"), "Mid-Autumn")
        XCTAssertEqual(en.offDayBadge, "Off")
        XCTAssertEqual(zh.offDayBadge, "休")
        XCTAssertEqual(en.lunarYearCompact(LunarCalendarEngine.shared.lunarInfo(year: 2026, month: 11, day: 20)), "Horse Year")

        // Verify shared preferences domain is readable/writable inside app sandbox
        let sharedDefaults = UserDefaults(suiteName: AppPreferences.suiteName)
        XCTAssertNotNil(sharedDefaults)
        sharedDefaults?.set("zh-Hans", forKey: "_testSharedSync")
        XCTAssertEqual(sharedDefaults?.string(forKey: "_testSharedSync"), "zh-Hans")
        sharedDefaults?.removeObject(forKey: "_testSharedSync")
    }

    func testRemoteHolidayJSONParsingAndThemes() {
        // Test NateScarlet/holiday-cn format
        let sampleCN = """
        {
          "year": 2028,
          "days": [
            { "name": "元旦", "date": "2028-01-01", "isOffDay": true },
            { "name": "春节", "date": "2028-01-22", "isOffDay": false }
          ]
        }
        """.data(using: .utf8)!

        let parsed = HolidayStore.parseRemoteHolidayJSON(sampleCN)
        XCTAssertEqual(parsed?.count, 2)
        XCTAssertEqual(parsed?.first?.date, "2028-01-01")
        XCTAssertEqual(parsed?.first?.isOffDay, true)
        XCTAssertEqual(parsed?.last?.isOffDay, false)

        // Verify all 5 themes instantiate cleanly with bilingual names
        let zh = L10n(isChinese: true)
        let en = L10n(isChinese: false)
        XCTAssertEqual(AppTheme.allCases.count, 5)
        for theme in AppTheme.allCases {
            let p = DaydropTheme.palette(for: theme)
            XCTAssertEqual(p.theme, theme)
            XCTAssertFalse(zh.themeName(theme).isEmpty)
            XCTAssertFalse(en.themeName(theme).isEmpty)
        }
    }

    func testAppUpdaterVersionComparisonAndParsing() {
        XCTAssertTrue(AppUpdater.isVersion("1.1.0", newerThan: "1.0.0"))
        XCTAssertTrue(AppUpdater.isVersion("v1.1.1", newerThan: "1.1.0"))
        XCTAssertTrue(AppUpdater.isVersion("1.10.0", newerThan: "1.9.5"))
        XCTAssertFalse(AppUpdater.isVersion("1.1.0", newerThan: "1.1.0"))
        XCTAssertFalse(AppUpdater.isVersion("1.0.9", newerThan: "1.1.0"))

        let sampleRelease = """
        {
          "tag_name": "v1.2.0",
          "body": "Bug fixes and improvements",
          "html_url": "https://github.com/iwtem/Daydrop/releases/tag/v1.2.0",
          "assets": [
            {
              "name": "Daydrop-v1.2.0-macOS.zip",
              "browser_download_url": "https://github.com/iwtem/Daydrop/releases/download/v1.2.0/Daydrop-v1.2.0-macOS.zip"
            }
          ]
        }
        """.data(using: .utf8)!

        let parsed = AppUpdater.parseLatestRelease(sampleRelease)
        XCTAssertEqual(parsed?.version, "1.2.0")
        XCTAssertEqual(parsed?.tagName, "v1.2.0")
        XCTAssertEqual(parsed?.downloadURL.lastPathComponent, "Daydrop-v1.2.0-macOS.zip")
    }

    func testRelativeDayLabel() {
        let cal = Calendar(identifier: .gregorian)
        let base = cal.date(from: DateComponents(year: 2026, month: 11, day: 20))!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: base)!
        let inFiveDays = cal.date(byAdding: .day, value: 5, to: base)!
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: base)!

        let zh = L10n(isChinese: true)
        let en = L10n(isChinese: false)

        XCTAssertEqual(zh.relativeDayLabel(from: base, to: base, calendar: cal), "今天")
        XCTAssertEqual(zh.relativeDayLabel(from: base, to: tomorrow, calendar: cal), "明天")
        XCTAssertEqual(zh.relativeDayLabel(from: base, to: inFiveDays, calendar: cal), "5天后")
        XCTAssertEqual(zh.relativeDayLabel(from: base, to: threeDaysAgo, calendar: cal), "3天前")

        XCTAssertEqual(en.relativeDayLabel(from: base, to: base, calendar: cal), "Today")
        XCTAssertEqual(en.relativeDayLabel(from: base, to: tomorrow, calendar: cal), "Tomorrow")
        XCTAssertEqual(en.relativeDayLabel(from: base, to: inFiveDays, calendar: cal), "In 5d")
        XCTAssertEqual(en.relativeDayLabel(from: base, to: threeDaysAgo, calendar: cal), "3d ago")
    }

    func testSSEPushParsing() {
        let messageLine = #"data: {"id":"abc","time":1700000000,"event":"message","topic":"daydrop-iwtem-releases-7f3a9c2e","message":"v1.2.1"}"#
        let keepaliveLine = #"data: {"id":"def","time":1700000010,"event":"keepalive","topic":"daydrop-iwtem-releases-7f3a9c2e"}"#
        let openLine = #"data: {"id":"ghi","time":1700000001,"event":"open","topic":"daydrop-iwtem-releases-7f3a9c2e"}"#

        XCTAssertEqual(UpdatePushListener.parseSSEDataLine(messageLine), "v1.2.1")
        XCTAssertNil(UpdatePushListener.parseSSEDataLine(keepaliveLine))
        XCTAssertNil(UpdatePushListener.parseSSEDataLine(openLine))
        XCTAssertNil(UpdatePushListener.parseSSEDataLine("event: keepalive"))
    }
}
