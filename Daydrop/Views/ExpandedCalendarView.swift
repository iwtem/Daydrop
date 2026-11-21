import SwiftUI

struct ExpandedCalendarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var preferences: AppPreferences

    @Environment(\.colorScheme) private var colorScheme
    @State private var showMonthYearPicker = false

    private var l10n: L10n { L10n(language: preferences.language) }
    private var palette: ThemePalette { DaydropTheme.palette(for: preferences.theme) }

    var body: some View {
        let _ = appState.holidayRevision
        VStack(spacing: 0) {
            topToolbar
            Divider()

            if appState.expandedViewMode == .month {
                monthContent
            } else {
                YearOverviewView(
                    year: appState.displayedYear,
                    today: appState.today,
                    weekStartsOnMonday: preferences.weekStartsOnMonday,
                    showHolidayBadges: preferences.showHolidayBadges,
                    l10n: l10n,
                    palette: palette
                ) { month in
                    appState.jumpTo(year: appState.displayedYear, month: month)
                    appState.expandedViewMode = .month
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(DaydropTheme.cardBackground(colorScheme))
        .preferredColorScheme(preferences.appearanceMode.preferredColorScheme)
        .background(
            WindowConfigurator(
                isPinnedOnTop: false,
                title: l10n.windowTitle,
                hideTitlebarSeparator: true
            )
        )
        .onAppear {
            appState.refreshTodayIfNeeded()
        }
        .onKeyPress(.leftArrow) {
            if appState.expandedViewMode == .month {
                appState.moveSelection(byDays: -1)
            } else {
                appState.shiftYear(by: -1)
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if appState.expandedViewMode == .month {
                appState.moveSelection(byDays: 1)
            } else {
                appState.shiftYear(by: 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if appState.expandedViewMode == .month {
                appState.moveSelection(byDays: -7)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if appState.expandedViewMode == .month {
                appState.moveSelection(byDays: 7)
            }
            return .handled
        }
    }

    private var topToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    showMonthYearPicker.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Text(
                            appState.expandedViewMode == .month
                                ? l10n.yearMonthTitle(year: appState.displayedYear, month: appState.displayedMonth)
                                : l10n.yearTitle(appState.displayedYear)
                        )
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showMonthYearPicker, arrowEdge: .bottom) {
                    MonthYearPickerPopover(
                        selectedYear: $appState.displayedYear,
                        selectedMonth: $appState.displayedMonth,
                        l10n: l10n,
                        palette: palette
                    ) {
                        showMonthYearPicker = false
                    }
                }

                HStack(spacing: 4) {
                    toolbarIconButton("chevron.left") {
                        if appState.expandedViewMode == .month {
                            appState.shiftMonth(by: -1)
                        } else {
                            appState.shiftYear(by: -1)
                        }
                    }
                    toolbarIconButton("chevron.right") {
                        if appState.expandedViewMode == .month {
                            appState.shiftMonth(by: 1)
                        } else {
                            appState.shiftYear(by: 1)
                        }
                    }
                }

                Button {
                    appState.goToToday()
                } label: {
                    Text(l10n.todayFull)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.todayAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(palette.todayAccent.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Picker("", selection: $appState.expandedViewMode) {
                Text(l10n.viewModeMonth).tag(ExpandedViewMode.month)
                Text(l10n.viewModeYear).tag(ExpandedViewMode.year)
            }
            .pickerStyle(.segmented)
            .frame(width: 148)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var monthContent: some View {
        HStack(alignment: .top, spacing: 20) {
            CalendarGridView(
                days: appState.currentMonthDays,
                selectedDate: appState.selectedDate,
                todayDayOfMonth: appState.todayInfo.day,
                weekStartsOnMonday: preferences.weekStartsOnMonday,
                showHolidayBadges: preferences.showHolidayBadges,
                showSolarTerms: preferences.showSolarTerms,
                l10n: l10n,
                palette: palette,
                style: .spacious
            ) { day in
                appState.selectDay(day)
            }
            .frame(maxWidth: .infinity)

            rightDetailSidebar
                .frame(width: 248)
        }
        .padding(20)
    }

    private var rightDetailSidebar: some View {
        let info = appState.selectedDayInfo
        let monthTerms = SolarTermCalculator.shared.solarTerms(for: appState.displayedYear)
            .filter { $0.month == appState.displayedMonth }

        return VStack(spacing: 14) {
            VStack(spacing: 0) {
                HStack {
                    Text(l10n.yearMonthTitle(year: info.year, month: info.month))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(l10n.weekdayFull(info.weekday))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(palette.primaryAccent)

                VStack(spacing: 8) {
                    Text("\(info.day)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(info.isToday ? palette.todayAccent : .primary)
                        .padding(.top, 8)

                    Text(l10n.lunarFullDescription(info.lunar))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(l10n.weekOfYear(info.weekOfYear, compact: false))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)

                    if !info.specialTags.isEmpty || info.holidayStatus != nil {
                        HStack(spacing: 6) {
                            ForEach(info.specialTags, id: \.self) { tag in
                                let isTerm = (info.solarTerm?.name == tag)
                                let tagColor = isTerm ? palette.solarTermAccent : palette.primaryAccent
                                Text(l10n.localizedTag(tag, isSolarTerm: isTerm))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(tagColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(tagColor.opacity(0.14)))
                            }
                            if let status = info.holidayStatus {
                                let isOff: Bool = {
                                    if case .offDay = status { return true }
                                    return false
                                }()
                                Text(l10n.holidayStatusPill(status, compact: false))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(isOff ? palette.primaryAccent : palette.workdayBadge))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
                .background(DaydropTheme.secondarySurface(colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DaydropTheme.subtleBorder(colorScheme), lineWidth: 1)
            )

            upcomingCard

            if !monthTerms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.solarTermsThisMonth)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(monthTerms) { term in
                        HStack {
                            Circle()
                                .fill(palette.solarTermAccent)
                                .frame(width: 6, height: 6)
                            Text(l10n.solarTermName(term.name, compact: false))
                                .font(.system(size: 12.5, weight: .medium))
                            Spacer()
                            Text(l10n.monthDayTitle(month: term.month, day: term.day))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
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
                        .strokeBorder(DaydropTheme.subtleBorder(colorScheme), lineWidth: 1)
                )
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var upcomingCard: some View {
        let nextTerm = SolarTermCalculator.shared.nextSolarTerm(from: appState.today)
        let nextHoliday = HolidayStore.shared.nextHoliday(from: appState.today)

        if nextTerm != nil || nextHoliday != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.upcomingTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let nextTerm {
                    HStack {
                        Circle()
                            .fill(palette.solarTermAccent)
                            .frame(width: 7, height: 7)
                        Text(l10n.nextSolarTermRow(nextTerm.term.name))
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        Text(l10n.daysLater(nextTerm.daysUntil))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.solarTermAccent)
                    }
                }

                if let nextHoliday {
                    HStack {
                        Circle()
                            .fill(palette.primaryAccent)
                            .frame(width: 7, height: 7)
                        Text(l10n.nextHolidayRow(nextHoliday.name))
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        Text(l10n.daysLater(nextHoliday.daysUntil))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.primaryAccent)
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
                    .strokeBorder(DaydropTheme.subtleBorder(colorScheme), lineWidth: 1)
            )
        }
    }

    private func toolbarIconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }
}
