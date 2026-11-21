import SwiftUI
import AppKit

struct MenuBarPopoverView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var preferences: AppPreferences

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showMonthYearPicker = false
    @State private var popoverWindow: NSWindow?
    @State private var isHoveringQuit = false

    private var l10n: L10n { L10n(language: preferences.language) }

    var body: some View {
        VStack(spacing: 12) {
            headerBar

            CalendarGridView(
                days: appState.currentMonthDays,
                selectedDate: appState.selectedDate,
                todayDayOfMonth: appState.todayInfo.day,
                weekStartsOnMonday: preferences.weekStartsOnMonday,
                showHolidayBadges: preferences.showHolidayBadges,
                showSolarTerms: preferences.showSolarTerms,
                l10n: l10n,
                style: .compact
            ) { day in
                appState.selectDay(day)
            }

            DayDetailBannerView(
                dayInfo: appState.selectedDayInfo,
                today: appState.today,
                l10n: l10n
            )
        }
        .padding(14)
        .frame(width: 344)
        .background(DaydropTheme.cardBackground(colorScheme))
        .background(
            HostingWindowFinder { window in
                if popoverWindow !== window {
                    popoverWindow = window
                }
            }
        )
        .preferredColorScheme(preferences.appearanceMode.preferredColorScheme)
        .onAppear {
            appState.refreshTodayIfNeeded()
        }
        .onKeyPress(.leftArrow) {
            appState.moveSelection(byDays: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            appState.moveSelection(byDays: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            appState.moveSelection(byDays: -7)
            return .handled
        }
        .onKeyPress(.downArrow) {
            appState.moveSelection(byDays: 7)
            return .handled
        }
    }

    private var headerBar: some View {
        HStack(spacing: 5) {
            // Clickable Year & Month selector
            Button {
                showMonthYearPicker.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(l10n.yearMonthTitle(year: appState.displayedYear, month: appState.displayedMonth))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showMonthYearPicker, arrowEdge: .bottom) {
                MonthYearPickerPopover(
                    selectedYear: $appState.displayedYear,
                    selectedMonth: $appState.displayedMonth,
                    l10n: l10n
                ) {
                    showMonthYearPicker = false
                }
            }

            if !appState.isDisplayingCurrentMonth || !Calendar.current.isDate(appState.selectedDate, inSameDayAs: appState.today) {
                Button {
                    appState.goToToday()
                } label: {
                    Text(l10n.todayShort)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(DaydropTheme.skyBlue))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Month steppers
            HStack(spacing: 3) {
                iconButton(systemName: "chevron.left") {
                    appState.shiftMonth(by: -1)
                }
                iconButton(systemName: "chevron.right") {
                    appState.shiftMonth(by: 1)
                }
            }

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)

            // Expand, Settings, Quit (all icon-only, no hover tooltips)
            HStack(spacing: 3) {
                iconButton(systemName: "arrow.up.left.and.arrow.down.right") {
                    closePopoverAndOpenWindow(id: "expanded-calendar")
                }

                iconButton(systemName: "gearshape") {
                    closePopoverAndOpenWindow(id: "settings-window")
                }

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(isHoveringQuit ? DaydropTheme.coral : .secondary)
                        .frame(width: 25, height: 25)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isHoveringQuit ? DaydropTheme.coral.opacity(0.14) : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringQuit = hovering
                }
            }
        }
    }

    private func closePopoverAndOpenWindow(id: String) {
        let currentPopover = popoverWindow
        openWindow(id: id)
        WindowActivator.activateApp()
        currentPopover?.orderOut(nil)
        dismiss()
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 25, height: 25)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
}
