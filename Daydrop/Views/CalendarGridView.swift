import SwiftUI

enum CalendarGridStyle {
    case compact   // Menu bar popover
    case spacious  // Expanded standalone window
}

struct CalendarGridView: View {
    let days: [CalendarDayInfo]
    let selectedDate: Date
    let todayDayOfMonth: Int
    let weekStartsOnMonday: Bool
    let showHolidayBadges: Bool
    let showSolarTerms: Bool
    let l10n: L10n
    let style: CalendarGridStyle
    let onSelect: (CalendarDayInfo) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredDayID: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: style == .compact ? 6 : 10) {
            weekdayHeaderRow
            LazyVGrid(columns: columns, spacing: style == .compact ? 4 : 8) {
                ForEach(days) { day in
                    dayCell(day)
                }
            }
        }
    }

    private var weekdayHeaderRow: some View {
        let headers = l10n.weekdayHeaders(weekStartsOnMonday: weekStartsOnMonday, singleLetter: false)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(headers.enumerated()), id: \.offset) { _, item in
                Text(item.title)
                    .font(.system(size: style == .compact ? 11 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(item.isWeekend ? DaydropTheme.coral : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
        }
    }

    private func dayCell(_ day: CalendarDayInfo) -> some View {
        let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
        let isHovered = hoveredDayID == day.id
        let subtitle = resolvedSubtitle(for: day)

        return Button {
            onSelect(day)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: style == .compact ? 1 : 3) {
                    Text("\(day.day)")
                        .font(.system(
                            size: style == .compact ? 14 : 17,
                            weight: day.isToday || isSelected ? .bold : .medium,
                            design: .rounded
                        ))
                        .foregroundStyle(dayNumberColor(for: day))

                    Text(subtitle.text)
                        .font(.system(
                            size: style == .compact ? 9.5 : 11,
                            weight: subtitle.kind == .festival || subtitle.kind == .solarTerm ? .medium : .regular
                        ))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(
                            DaydropTheme.subtitleColor(
                                for: subtitle.kind,
                                isToday: day.isToday,
                                isInMonth: day.isInCurrentMonth
                            )
                        )
                }
                .frame(maxWidth: .infinity)
                .frame(height: style == .compact ? 40 : 54)

                // Compact 休 / 班 corner badge
                if showHolidayBadges, let status = day.holidayStatus {
                    holidayCornerBadge(status: status, isToday: day.isToday, isInMonth: day.isInCurrentMonth)
                        .padding(.top, style == .compact ? 2 : 4)
                        .padding(.trailing, style == .compact ? 3 : 5)
                }
            }
            .background(cellBackground(day: day, isSelected: isSelected, isHovered: isHovered))
            .overlay(
                RoundedRectangle(cornerRadius: style == .compact ? 9 : 11, style: .continuous)
                    .strokeBorder(
                        isSelected && !day.isToday ? DaydropTheme.skyBlue : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredDayID = hovering ? day.id : (hoveredDayID == day.id ? nil : hoveredDayID)
        }
    }

    private func resolvedSubtitle(for day: CalendarDayInfo) -> (text: String, kind: DaySubtitleKind) {
        l10n.localizedSubtitle(for: day, showSolarTerms: showSolarTerms)
    }

    private func dayNumberColor(for day: CalendarDayInfo) -> Color {
        if day.isToday {
            return .white
        }
        let alpha = day.isInCurrentMonth ? 1.0 : 0.34
        if day.isOffDay || (day.isWeekend && !day.isAdjustedWorkday) {
            return DaydropTheme.coral.opacity(alpha)
        }
        return Color.primary.opacity(alpha)
    }

    @ViewBuilder
    private func cellBackground(day: CalendarDayInfo, isSelected: Bool, isHovered: Bool) -> some View {
        let radius: CGFloat = style == .compact ? 9 : 11
        let isSameDayInOtherMonth = !day.isToday && day.isInCurrentMonth && day.day == todayDayOfMonth
        if day.isToday {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DaydropTheme.skyBlue)
        } else if isSelected {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DaydropTheme.selectedCellTint(colorScheme))
        } else if isSameDayInOtherMonth {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(isHovered ? DaydropTheme.selectedCellTint(colorScheme) : DaydropTheme.sameDayOfMonthTint(colorScheme))
        } else if showHolidayBadges && day.isOffDay && day.isInCurrentMonth {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(isHovered ? DaydropTheme.coral.opacity(0.20) : DaydropTheme.holidayCellTint(colorScheme))
        } else if isHovered {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DaydropTheme.hoverCellTint(colorScheme))
        } else {
            Color.clear
        }
    }

    private func holidayCornerBadge(status: HolidayStatus, isToday: Bool, isInMonth: Bool) -> some View {
        let isOff: Bool
        switch status {
        case .offDay: isOff = true
        case .workDay: isOff = false
        }
        let text = isOff ? l10n.offDayBadge : l10n.workDayBadge
        let opacity = isInMonth ? 1.0 : 0.45

        return Text(text)
            .font(.system(size: style == .compact ? (l10n.isChinese ? 8 : 7) : (l10n.isChinese ? 9 : 8), weight: .bold))
            .foregroundStyle(isToday ? .white : (isOff ? DaydropTheme.coral.opacity(opacity) : DaydropTheme.workdayBadge.opacity(opacity)))
            .padding(.horizontal, 2.5)
            .padding(.vertical, 0.5)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        isToday
                            ? Color.white.opacity(0.25)
                            : (isOff ? DaydropTheme.coral.opacity(0.14 * opacity) : DaydropTheme.workdayBadge.opacity(0.14 * opacity))
                    )
            )
    }
}
