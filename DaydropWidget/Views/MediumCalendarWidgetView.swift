import SwiftUI
import WidgetKit

struct MediumCalendarWidgetView: View {
    let entry: DaydropCalendarEntry
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var isFullColor: Bool { renderingMode == .fullColor }
    private var l10n: L10n { entry.l10n }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        let info = entry.todayInfo
        HStack(spacing: 14) {
            // Left: Balanced 3-tier Today Column with generous vertical breathing room
            VStack(alignment: .leading, spacing: 0) {
                // Tier 1: Compact Month + Weekday pill
                HStack(spacing: 4) {
                    Text(l10n.monthShort(info.month))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(isFullColor ? .white : .primary)
                    Text(l10n.weekdayShort(info.weekday))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isFullColor ? .white.opacity(0.92) : .primary.opacity(0.85))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    Capsule().fill(isFullColor ? DaydropTheme.coral : Color.primary.opacity(0.14))
                )
                .overlay(
                    Capsule().strokeBorder(isFullColor ? Color.clear : Color.primary.opacity(0.18), lineWidth: 0.75)
                )

                Spacer(minLength: 6)

                // Tier 2: Horizontal Hero — Day numeral paired with Lunar metadata
                HStack(alignment: .center, spacing: 8) {
                    Text("\(info.day)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.lunarMonthDay(info.lunar))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(l10n.lunarYearCompact(info.lunar))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }

                Spacer(minLength: 6)

                // Tier 3: Clean compact countdowns (aligned with bottom row of right grid)
                VStack(alignment: .leading, spacing: 3) {
                    if let nextTerm = entry.nextSolarTerm {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isFullColor ? DaydropTheme.solarTermGreen : Color.primary.opacity(0.7))
                                .frame(width: 5, height: 5)
                            Text(l10n.countdownTiny(label: l10n.solarTermName(nextTerm.term.name, compact: true), days: nextTerm.daysUntil))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    if let nextHoliday = entry.nextHoliday {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isFullColor ? DaydropTheme.coral : Color.primary.opacity(0.7))
                                .frame(width: 5, height: 5)
                            Text(l10n.countdownTiny(label: l10n.holidayName(nextHoliday.name), days: nextHoliday.daysUntil))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }
            .frame(width: 118, alignment: .leading)

            // Subtle vertical hairline divider
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 1)
                .padding(.vertical, 2)

            // Right: Compact Month Grid
            VStack(spacing: 4) {
                let headers = l10n.weekdayHeaders(weekStartsOnMonday: entry.weekStartsOnMonday, singleLetter: true)
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, h in
                        Text(h.title)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(h.isWeekend && isFullColor ? DaydropTheme.coral : .secondary)
                    }
                }

                LazyVGrid(columns: columns, spacing: 2.5) {
                    ForEach(entry.monthDays) { day in
                        ZStack {
                            if day.isToday {
                                if isFullColor {
                                    Circle()
                                        .fill(DaydropTheme.skyBlue)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Circle()
                                        .fill(Color.primary.opacity(0.18))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.primary.opacity(0.75), lineWidth: 1.25)
                                        )
                                }
                            } else if entry.showHolidayBadges && day.isOffDay && day.isInCurrentMonth {
                                Circle()
                                    .fill(isFullColor ? DaydropTheme.coral.opacity(0.16) : Color.primary.opacity(0.10))
                                    .frame(width: 20, height: 20)
                            }

                            Text("\(day.day)")
                                .font(.system(size: 10.5, weight: day.isToday ? .bold : .medium, design: .rounded))
                                .foregroundStyle(dayColor(day))
                        }
                        .frame(height: 18)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .containerBackground(for: .widget) {
            DaydropTheme.cardBackground(colorScheme)
        }
    }

    private func dayColor(_ day: CalendarDayInfo) -> Color {
        if day.isToday {
            return isFullColor ? .white : .primary
        }
        let alpha = day.isInCurrentMonth ? 1.0 : 0.35
        if isFullColor {
            if day.isOffDay || (day.isWeekend && !day.isAdjustedWorkday) {
                return DaydropTheme.coral.opacity(alpha)
            }
            if day.solarTerm != nil {
                return DaydropTheme.solarTermGreen.opacity(alpha)
            }
        }
        return Color.primary.opacity(alpha)
    }
}
