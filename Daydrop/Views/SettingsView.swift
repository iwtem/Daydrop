import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @Environment(\.colorScheme) private var colorScheme

    private var l10n: L10n { L10n(language: preferences.language) }

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

                Section(l10n.sectionCalendarWidgets) {
                    Picker(l10n.labelWeekStart, selection: $preferences.weekStartsOnMonday) {
                        Text(l10n.monday).tag(true)
                        Text(l10n.sunday).tag(false)
                    }
                    .pickerStyle(.segmented)

                    Toggle(l10n.labelShowHolidays, isOn: $preferences.showHolidayBadges)
                    Toggle(l10n.labelShowSolarTerms, isOn: $preferences.showSolarTerms)
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
                .foregroundStyle(DaydropTheme.coral)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 460, height: 460)
        .background(DaydropTheme.cardBackground(colorScheme))
        .preferredColorScheme(preferences.appearanceMode.preferredColorScheme)
        .background(WindowConfigurator(isPinnedOnTop: false, title: l10n.settingsTitle))
    }
}
