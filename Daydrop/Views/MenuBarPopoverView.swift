import SwiftUI
import AppKit

struct MenuBarPopoverView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var preferences: AppPreferences
    @ObservedObject private var updater = AppUpdater.shared

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showMonthYearPicker = false
    @State private var popoverWindow: NSWindow?
    @State private var isHoveringQuit = false

    private var l10n: L10n { L10n(language: preferences.language) }
    private var palette: ThemePalette { DaydropTheme.palette(for: preferences.theme) }

    var body: some View {
        let _ = appState.holidayRevision
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
                palette: palette,
                style: .compact
            ) { day in
                appState.selectDay(day)
            }

            DayDetailBannerView(
                dayInfo: appState.selectedDayInfo,
                today: appState.today,
                l10n: l10n,
                palette: palette
            )

            updateBannerIfNeeded
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
        .onKeyPress(characters: CharacterSet(charactersIn: "tT")) { _ in
            appState.goToToday()
            return .handled
        }
    }

    private var headerBar: some View {
        HStack(spacing: 5) {
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
                    l10n: l10n,
                    palette: palette
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
                        .background(Circle().fill(palette.todayAccent))
                }
                .buttonStyle(.plain)
            }

            Spacer()

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
                        .foregroundStyle(isHoveringQuit ? palette.primaryAccent : .secondary)
                        .frame(width: 25, height: 25)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isHoveringQuit ? palette.primaryAccent.opacity(0.14) : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringQuit = hovering
                }
            }
        }
    }

    @ViewBuilder
    private var updateBannerIfNeeded: some View {
        switch updater.state {
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .tint(palette.todayAccent)
                Text(l10n.downloadingPercent(Int(progress * 100)))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.todayAccent.opacity(0.09))
            )

        case .installing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(l10n.installingUpdate)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.todayAccent.opacity(0.09))
            )

        default:
            if updater.shouldShowBanner, let info = updater.availableUpdate {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.todayAccent)

                    Text(l10n.newVersionBanner(info.version))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        updater.installAvailableUpdate()
                    } label: {
                        Text(l10n.updateNow)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(palette.todayAccent))
                    }
                    .buttonStyle(.plain)

                    Button {
                        updater.dismissBannerForSession()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.todayAccent.opacity(0.10))
                )
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
