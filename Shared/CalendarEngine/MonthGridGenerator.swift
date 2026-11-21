import Foundation

public struct MonthGridGenerator {
    public static func weekdayHeaders(weekStartsOnMonday: Bool) -> [(title: String, isWeekend: Bool)] {
        if weekStartsOnMonday {
            return [
                ("一", false), ("二", false), ("三", false), ("四", false),
                ("五", false), ("六", true), ("日", true)
            ]
        } else {
            return [
                ("日", true), ("一", false), ("二", false), ("三", false),
                ("四", false), ("五", false), ("六", true)
            ]
        }
    }

    public static func dayInfo(
        for date: Date,
        inCurrentMonth: Bool = true,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> CalendarDayInfo {
        let comps = calendar.dateComponents([.year, .month, .day, .weekday, .weekOfYear], from: date)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        let wd = comps.weekday ?? 1
        let woy = comps.weekOfYear ?? 1

        let todayComps = calendar.dateComponents([.year, .month, .day], from: today)
        let isToday = (y == todayComps.year && m == todayComps.month && d == todayComps.day)
        let isWeekend = (wd == 1 || wd == 7)

        let lunar = LunarCalendarEngine.shared.lunarInfo(year: y, month: m, day: d)
        let solarTerm = SolarTermCalculator.shared.solarTerm(year: y, month: m, day: d)
        let holidayStatus = HolidayStore.shared.status(year: y, month: m, day: d)

        let id = String(format: "%04d-%02d-%02d", y, m, d)
        return CalendarDayInfo(
            id: id,
            date: date,
            year: y,
            month: m,
            day: d,
            weekday: wd,
            weekOfYear: woy,
            isInCurrentMonth: inCurrentMonth,
            isToday: isToday,
            isWeekend: isWeekend,
            lunar: lunar,
            solarTerm: solarTerm,
            holidayStatus: holidayStatus
        )
    }

    /// Generates a fixed 42-cell (6 rows × 7 columns) grid for smooth layout stability.
    public static func generateMonthGrid(
        year: Int,
        month: Int,
        weekStartsOnMonday: Bool,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [CalendarDayInfo] {
        var cal = calendar
        cal.firstWeekday = weekStartsOnMonday ? 2 : 1

        guard let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return []
        }

        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        // Number of leading days from previous month
        let leadingDays: Int
        if weekStartsOnMonday {
            // Monday(2)->0, Tuesday(3)->1, ..., Saturday(7)->5, Sunday(1)->6
            leadingDays = (firstWeekday + 5) % 7
        } else {
            // Sunday(1)->0, Monday(2)->1, ..., Saturday(7)->6
            leadingDays = firstWeekday - 1
        }

        guard let gridStart = cal.date(byAdding: .day, value: -leadingDays, to: firstOfMonth) else {
            return []
        }

        var days: [CalendarDayInfo] = []
        days.reserveCapacity(42)

        for offset in 0..<42 {
            guard let cellDate = cal.date(byAdding: .day, value: offset, to: gridStart) else { continue }
            let cellMonth = cal.component(.month, from: cellDate)
            let cellYear = cal.component(.year, from: cellDate)
            let inMonth = (cellYear == year && cellMonth == month)
            days.append(dayInfo(for: cellDate, inCurrentMonth: inMonth, today: today, calendar: cal))
        }

        return days
    }
}
