import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject private var updater = AppUpdater.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var isSyncingHolidays = false
    @State private var syncStatusMessage: String?
    @State private var coveredYearsText: String = HolidayStore.shared.coveredYearsSummary

    private var l10n: L10n { L10n(language: preferences.language) }
    private var palette: ThemePalette { DaydropTheme.palette(for: preferences.theme) }

    var body: some View {
        VStack(spacing: 0) {
            // Header identity card
            HStack(spacing: 14) {
                if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 52, height: 52)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n.appBrandFooter)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(l10n.settingsSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            .background(DaydropTheme.secondarySurface(colorScheme))

            Divider()

            Form {
                Section(l10n.sectionGeneral) {
                    Toggle(l10n.labelLaunchAtLogin, isOn: $preferences.launchAtLogin)

                    Picker(l10n.labelLanguage, selection: $preferences.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName(isChinese: l10n.isChinese)).tag(lang)
                        }
                    }

                    Picker(l10n.labelMenuBarStyle, selection: $preferences.menuBarDisplayStyle) {
                        ForEach(MenuBarDisplayStyle.allCases) { style in
                            Text(l10n.menuBarStyleName(style)).tag(style)
                        }
                    }

                    Picker(l10n.labelAppearance, selection: $preferences.appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(l10n.appearanceName(mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(l10n.labelTheme) {
                    themeSwatchPicker
                }

                Section(l10n.sectionCalendarWidgets) {
                    Picker(l10n.labelWeekStart, selection: $preferences.weekStartsOnMonday) {
                        Text(l10n.monday).tag(true)
                        Text(l10n.sunday).tag(false)
                    }
                    .pickerStyle(.segmented)

                    Toggle(l10n.labelShowHolidays, isOn: $preferences.showHolidayBadges)
                    Toggle(l10n.labelShowSolarTerms, isOn: $preferences.showSolarTerms)
                }

                Section(l10n.sectionHolidayData) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(l10n.labelCoveredYears)：\(coveredYearsText)")
                                .font(.system(size: 12.5, weight: .medium))
                            if let msg = syncStatusMessage {
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            triggerHolidaySync()
                        } label: {
                            if isSyncingHolidays {
                                HStack(spacing: 5) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(l10n.checkingHolidayUpdate)
                                }
                            } else {
                                Text(l10n.checkHolidayUpdate)
                            }
                        }
                        .disabled(isSyncingHolidays)
                    }
                }

                Section(l10n.sectionAppUpdate) {
                    Toggle(l10n.labelAutoCheckUpdates, isOn: $preferences.autoCheckUpdates)
                        .onChange(of: preferences.autoCheckUpdates) { _, _ in
                            updater.refreshPushSubscription()
                        }
                    Toggle(l10n.labelAutoDownloadUpdates, isOn: $preferences.autoDownloadUpdates)
                    appUpdateRow
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Text(l10n.settingsSyncHint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(l10n.quitApp) {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundStyle(palette.primaryAccent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480, height: 670)
        .background(DaydropTheme.cardBackground(colorScheme))
        .preferredColorScheme(preferences.appearanceMode.preferredColorScheme)
        .background(WindowConfigurator(isPinnedOnTop: false, title: l10n.settingsTitle, hideTitlebarSeparator: true))
    }

    @ViewBuilder
    private var appUpdateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(l10n.labelCurrentVersion)：v\(updater.currentVersion)")
                            .font(.system(size: 12.5, weight: .medium))
                        if updater.isPushConnected {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(palette.solarTermAccent)
                                    .frame(width: 6, height: 6)
                                Text(l10n.pushConnectedHint)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(palette.solarTermAccent.opacity(0.10)))
                        }
                    }

                    switch updater.state {
                    case .upToDate:
                        Text(l10n.appUpToDate)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    case .available(let info):
                        Text(l10n.newVersionBanner(info.version))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.todayAccent)
                    case .downloading(_, let progress):
                        Text(l10n.downloadingPercent(Int(progress * 100)))
                            .font(.system(size: 11))
                            .foregroundStyle(palette.todayAccent)
                    case .readyToInstall(let info):
                        Text(l10n.readyToInstallBanner(info.version))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.solarTermAccent)
                    case .installing:
                        Text(l10n.installingUpdate)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.todayAccent)
                    case .failed(let message):
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.primaryAccent)
                    default:
                        EmptyView()
                    }
                }

                Spacer()

                switch updater.state {
                case .checking:
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.small)
                        Text(l10n.checkingAppUpdate)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                case .available:
                    Button(l10n.downloadUpdate) {
                        updater.startManualDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.todayAccent)
                case .readyToInstall:
                    Button(l10n.restartAndUpdate) {
                        updater.restartAndInstallReadyUpdate()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.solarTermAccent)
                case .downloading, .installing:
                    ProgressView()
                        .controlSize(.small)
                default:
                    Button(l10n.checkAppUpdate) {
                        Task {
                            await updater.checkForUpdates(silent: false)
                        }
                    }
                }
            }

            if case .downloading(_, let progress) = updater.state {
                ProgressView(value: progress)
                    .tint(palette.todayAccent)
            }
        }
    }

    private var themeSwatchPicker: some View {
        HStack(spacing: 8) {
            ForEach(AppTheme.allCases) { theme in
                let p = DaydropTheme.palette(for: theme)
                let isSelected = (preferences.theme == theme)

                Button {
                    preferences.theme = theme
                } label: {
                    VStack(spacing: 5) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(p.primaryAccent)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(p.todayAccent)
                                .frame(width: 12, height: 12)
                        }
                        Text(l10n.themeName(theme))
                            .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isSelected ? p.primaryAccent.opacity(0.12) : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(isSelected ? p.primaryAccent : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private func triggerHolidaySync() {
        isSyncingHolidays = true
        syncStatusMessage = nil
        Task {
            let ok = await HolidayStore.shared.syncRemoteHolidays()
            await MainActor.run {
                isSyncingHolidays = false
                coveredYearsText = HolidayStore.shared.coveredYearsSummary
                syncStatusMessage = ok ? l10n.holidaySyncSuccess : l10n.holidaySyncFailed
            }
        }
    }
}
