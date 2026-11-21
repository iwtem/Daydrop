import SwiftUI
import WidgetKit

struct SmallCalendarWidgetView: View {
    let entry: DaydropCalendarEntry
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var isFullColor: Bool { renderingMode == .fullColor }
    private var l10n: L10n { entry.l10n }
    private var palette: ThemePalette { entry.palette }

    var body: some View {
        let info = entry.todayInfo
        VStack(spacing: 0) {
            HStack {
                Text(l10n.monthShort(info.month))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isFullColor ? .white : .primary)
                Spacer()
                Text(l10n.weekdayShort(info.weekday))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isFullColor ? .white.opacity(0.95) : .primary.opacity(0.85))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isFullColor ? palette.primaryAccent : Color.primary.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isFullColor ? Color.clear : Color.primary.opacity(0.18), lineWidth: 0.75)
            )

            Spacer(minLength: 4)

            Text("\(info.day)")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75)

            Text(l10n.lunarMonthDay(info.lunar))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 4)

            bottomTag(info)
        }
        .padding(15)
        .containerBackground(for: .widget) {
            DaydropTheme.cardBackground(colorScheme)
        }
    }

    @ViewBuilder
    private func bottomTag(_ info: CalendarDayInfo) -> some View {
        if let firstTag = info.specialTags.first {
            let isTerm = (info.solarTerm?.name == firstTag)
            let accent = isTerm ? palette.solarTermAccent : palette.primaryAccent
            Text(l10n.localizedTag(firstTag, isSolarTerm: isTerm))
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(isFullColor ? accent : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 2.5)
                .background(
                    Capsule().fill(isFullColor ? accent.opacity(0.14) : Color.primary.opacity(0.14))
                )
        } else if let nextTerm = entry.nextSolarTerm, nextTerm.daysUntil <= 15 {
            HStack(spacing: 4) {
                Circle()
                    .fill(isFullColor ? palette.solarTermAccent : Color.primary.opacity(0.7))
                    .frame(width: 5, height: 5)
                Text(l10n.countdownCompact(label: l10n.solarTermName(nextTerm.term.name, compact: true), days: nextTerm.daysUntil))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } else if let nextHoliday = entry.nextHoliday {
            HStack(spacing: 4) {
                Circle()
                    .fill(isFullColor ? palette.primaryAccent : Color.primary.opacity(0.7))
                    .frame(width: 5, height: 5)
                Text(l10n.countdownCompact(label: l10n.holidayName(nextHoliday.name), days: nextHoliday.daysUntil))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}
