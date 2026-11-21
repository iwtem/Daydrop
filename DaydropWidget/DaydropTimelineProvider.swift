import WidgetKit
import Foundation

struct DaydropCalendarEntry: TimelineEntry {
    let date: Date
    let todayInfo: CalendarDayInfo
    let monthDays: [CalendarDayInfo]
    let weekStartsOnMonday: Bool
    let showHolidayBadges: Bool
    let l10n: L10n
    let palette: ThemePalette
    let nextSolarTerm: (term: SolarTerm, daysUntil: Int)?
    let nextHoliday: UpcomingHoliday?
}

struct DaydropTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaydropCalendarEntry {
        makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DaydropCalendarEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaydropCalendarEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(for: now)

        // Schedule next refresh right after local midnight
        let cal = Calendar.current
        let nextMidnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))
            ?? now.addingTimeInterval(3600)
        let refreshDate = nextMidnight.addingTimeInterval(2)

        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func makeEntry(for date: Date) -> DaydropCalendarEntry {
        // Reload any newly synced holiday data from shared preferences
        HolidayStore.shared.reloadFromStorage()

        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let weekStartsOnMonday = AppPreferences.widgetWeekStartsOnMonday()
        let showHolidayBadges = AppPreferences.widgetShowHolidayBadges()
        let palette = DaydropTheme.palette(for: AppPreferences.widgetTheme())

        let todayInfo = MonthGridGenerator.dayInfo(for: date, inCurrentMonth: true, today: date, calendar: cal)
        let monthDays = MonthGridGenerator.generateMonthGrid(
            year: year,
            month: month,
            weekStartsOnMonday: weekStartsOnMonday,
            today: date,
            calendar: cal
        )

        return DaydropCalendarEntry(
            date: date,
            todayInfo: todayInfo,
            monthDays: monthDays,
            weekStartsOnMonday: weekStartsOnMonday,
            showHolidayBadges: showHolidayBadges,
            l10n: L10n.widgetCurrent,
            palette: palette,
            nextSolarTerm: SolarTermCalculator.shared.nextSolarTerm(from: date, calendar: cal),
            nextHoliday: HolidayStore.shared.nextHoliday(from: date, calendar: cal)
        )
    }
}
