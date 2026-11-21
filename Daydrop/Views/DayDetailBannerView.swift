import SwiftUI

struct DayDetailBannerView: View {
    let dayInfo: CalendarDayInfo
    let today: Date
    let l10n: L10n

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primary line: Gregorian date + week number + holiday status
            HStack(alignment: .center, spacing: 6) {
                Text("\(l10n.monthDayTitle(month: dayInfo.month, day: dayInfo.day)) \(l10n.weekdayShort(dayInfo.weekday))")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(l10n.weekOfYear(dayInfo.weekOfYear, compact: true))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))

                Spacer()

                if let status = dayInfo.holidayStatus {
                    holidayPill(status)
                }
            }

            // Lunar + special tags
            HStack(spacing: 6) {
                Text(l10n.lunarFullDescription(dayInfo.lunar))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ForEach(dayInfo.specialTags, id: \.self) { tag in
                    let isTerm = (dayInfo.solarTerm?.name == tag)
                    Text(l10n.localizedTag(tag, isSolarTerm: isTerm))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isTerm ? DaydropTheme.solarTermGreen : DaydropTheme.coral)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule().fill((isTerm ? DaydropTheme.solarTermGreen : DaydropTheme.coral).opacity(0.13))
                        )
                }
            }

            // Upcoming solar term & holiday countdowns
            countdownStrip
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DaydropTheme.secondarySurface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(DaydropTheme.subtleBorder(colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var countdownStrip: some View {
        let nextTerm = SolarTermCalculator.shared.nextSolarTerm(from: today)
        let nextHoliday = HolidayStore.shared.nextHoliday(from: today)

        if nextTerm != nil || nextHoliday != nil {
            HStack(spacing: 12) {
                if let nextTerm {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(DaydropTheme.solarTermGreen)
                            .frame(width: 6, height: 6)
                        Text(l10n.countdownCompact(label: l10n.solarTermName(nextTerm.term.name, compact: true), days: nextTerm.daysUntil))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                if let nextHoliday {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(DaydropTheme.coral)
                            .frame(width: 6, height: 6)
                        Text(l10n.countdownCompact(label: l10n.holidayName(nextHoliday.name), days: nextHoliday.daysUntil))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.top, 1)
        }
    }

    private func holidayPill(_ status: HolidayStatus) -> some View {
        let isOff: Bool
        switch status {
        case .offDay: isOff = true
        case .workDay: isOff = false
        }
        return Text(l10n.holidayStatusPill(status, compact: true))
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(isOff ? DaydropTheme.coral : DaydropTheme.workdayBadge))
    }
}
