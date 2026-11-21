import SwiftUI
import WidgetKit

struct LargeCalendarWidgetView: View {
    let entry: DaydropCalendarEntry
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var isFullColor: Bool { renderingMode == .fullColor }
    private var l10n: L10n { entry.l10n }
    private var palette: ThemePalette { entry.palette }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        let info = entry.todayInfo
        let headers = l10n.weekdayHeaders(weekStartsOnMonday: entry.weekStartsOnMonday, singleLetter: false)

        VStack(spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text(l10n.yearMonthTitle(year: info.year, month: info.month))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isFullColor ? .white : .primary)
                    Text(l10n.lunarYearLabel(info.lunar))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isFullColor ? .white.opacity(0.88) : .secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(l10n.todayPrefix) \(l10n.lunarMonthDay(info.lunar))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isFullColor ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFullColor ? palette.primaryAccent : Color.primary.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFullColor ? Color.clear : Color.primary.opacity(0.18), lineWidth: 0.75)
            )

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, h in
                    Text(h.title)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(h.isWeekend && isFullColor ? palette.primaryAccent : .secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(entry.monthDays) { day in
                    let sub = l10n.localizedSubtitle(for: day, showSolarTerms: entry.showSolarTerms)
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 1) {
                            Text("\(day.day)")
                                .font(.system(size: 13, weight: day.isToday ? .bold : .medium, design: .rounded))
                                .foregroundStyle(dayColor(day))
                            Text(sub.text)
                                .font(.system(size: 8.5, weight: sub.kind == .festival || sub.kind == .solarTerm ? .semibold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(subtitleColor(sub.kind, isToday: day.isToday, isInMonth: day.isInCurrentMonth))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)

                        if entry.showHolidayBadges, let status = day.holidayStatus, day.isInCurrentMonth {
                            let isOff: Bool = {
                                if case .offDay = status { return true }
                                return false
                            }()
                            Text(isOff ? l10n.offDayBadge : l10n.workDayBadge)
                                .font(.system(size: l10n.isChinese ? 7.5 : 6.5, weight: .bold))
                                .foregroundStyle(badgeColor(isOff: isOff, isToday: day.isToday))
                                .padding(.top, 2)
                                .padding(.trailing, 3)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(cellBackground(day))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                day.isToday && !isFullColor ? Color.primary.opacity(0.75) : Color.clear,
                                lineWidth: 1.25
                            )
                    )
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if let nextTerm = entry.nextSolarTerm {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isFullColor ? palette.solarTermAccent : Color.primary.opacity(0.7))
                            .frame(width: 6, height: 6)
                        Text(l10n.countdownCompact(label: l10n.solarTermName(nextTerm.term.name, compact: true), days: nextTerm.daysUntil))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                if let nextHoliday = entry.nextHoliday {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isFullColor ? palette.primaryAccent : Color.primary.opacity(0.7))
                            .frame(width: 6, height: 6)
                        Text(l10n.countdownCompact(label: l10n.holidayName(nextHoliday.name), days: nextHoliday.daysUntil))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(l10n.appName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            DaydropTheme.cardBackground(colorScheme)
        }
    }

    private func dayColor(_ day: CalendarDayInfo) -> Color {
        if day.isToday {
            return isFullColor ? .white : .primary
        }
        let alpha = day.isInCurrentMonth ? 1.0 : 0.35
        if isFullColor && (day.isOffDay || (day.isWeekend && !day.isAdjustedWorkday)) {
            return palette.primaryAccent.opacity(alpha)
        }
        return Color.primary.opacity(alpha)
    }

    private func subtitleColor(_ kind: DaySubtitleKind, isToday: Bool, isInMonth: Bool) -> Color {
        if !isFullColor {
            if isToday { return .primary.opacity(0.88) }
            return Color.secondary.opacity(isInMonth ? 0.9 : 0.38)
        }
        return palette.subtitleColor(for: kind, isToday: isToday, isInMonth: isInMonth)
    }

    private func badgeColor(isOff: Bool, isToday: Bool) -> Color {
        if !isFullColor {
            return .primary.opacity(0.85)
        }
        if isToday { return .white }
        return isOff ? palette.primaryAccent : palette.workdayBadge
    }

    private func cellBackground(_ day: CalendarDayInfo) -> Color {
        if day.isToday {
            return isFullColor ? palette.todayAccent : Color.primary.opacity(0.18)
        }
        if entry.showHolidayBadges && day.isOffDay && day.isInCurrentMonth {
            return isFullColor ? palette.holidayCellTint(colorScheme) : Color.primary.opacity(0.10)
        }
        return .clear
    }
}
