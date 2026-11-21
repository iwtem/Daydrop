import SwiftUI

struct YearOverviewView: View {
    let year: Int
    let today: Date
    let weekStartsOnMonday: Bool
    let showHolidayBadges: Bool
    let l10n: L10n
    let onSelectMonth: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredMonth: Int?

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(1...12, id: \.self) { month in
                    miniMonthCard(month: month)
                }
            }
            .padding(20)
        }
    }

    private func miniMonthCard(month: Int) -> some View {
        let days = MonthGridGenerator.generateMonthGrid(
            year: year,
            month: month,
            weekStartsOnMonday: weekStartsOnMonday,
            today: today
        )
        let isCurrentMonth = Calendar.current.component(.year, from: today) == year
            && Calendar.current.component(.month, from: today) == month
        let isHovered = hoveredMonth == month
        let headers = l10n.weekdayHeaders(weekStartsOnMonday: weekStartsOnMonday, singleLetter: true)

        return Button {
            onSelectMonth(month)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(l10n.monthShort(month))
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(isCurrentMonth ? DaydropTheme.skyBlue : .primary)
                    Spacer()
                    if l10n.isChinese {
                        let monthTerms = SolarTermCalculator.shared.solarTerms(for: year)
                            .filter { $0.month == month }
                            .map(\.name)
                            .joined(separator: "·")
                        if !monthTerms.isEmpty {
                            Text(monthTerms)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(DaydropTheme.solarTermGreen)
                        }
                    }
                }

                // Weekday initials
                LazyVGrid(columns: dayColumns, spacing: 2) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, h in
                        Text(h.title)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(h.isWeekend ? DaydropTheme.coral.opacity(0.8) : .secondary.opacity(0.7))
                    }
                }

                // 42-day mini grid
                LazyVGrid(columns: dayColumns, spacing: 2) {
                    ForEach(days) { day in
                        if day.isInCurrentMonth {
                            ZStack {
                                if day.isToday {
                                    Circle()
                                        .fill(DaydropTheme.skyBlue)
                                        .frame(width: 18, height: 18)
                                } else if showHolidayBadges && day.isOffDay {
                                    Circle()
                                        .fill(DaydropTheme.coral.opacity(0.18))
                                        .frame(width: 18, height: 18)
                                }
                                Text("\(day.day)")
                                    .font(.system(size: 9.5, weight: day.isToday ? .bold : .regular, design: .rounded))
                                    .foregroundStyle(miniDayColor(day))
                            }
                            .frame(height: 18)
                        } else {
                            Color.clear.frame(height: 18)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DaydropTheme.secondarySurface(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isCurrentMonth ? DaydropTheme.skyBlue.opacity(0.6)
                            : (isHovered ? DaydropTheme.coral.opacity(0.5) : DaydropTheme.subtleBorder(colorScheme)),
                        lineWidth: isCurrentMonth || isHovered ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredMonth = hovering ? month : (hoveredMonth == month ? nil : hoveredMonth)
        }
    }

    private func miniDayColor(_ day: CalendarDayInfo) -> Color {
        if day.isToday { return .white }
        if day.isOffDay || (day.isWeekend && !day.isAdjustedWorkday) { return DaydropTheme.coral }
        if day.solarTerm != nil { return DaydropTheme.solarTermGreen }
        return .primary
    }
}
