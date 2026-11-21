import SwiftUI

@main
struct DaydropApp: App {
    @StateObject private var appState = AppState()
    @ObservedObject private var preferences = AppPreferences.shared
    @ObservedObject private var updater = AppUpdater.shared

    var body: some Scene {
        // 1. Primary Resident Menu Bar Calendar (Hidden from Dock via LSUIElement = true)
        MenuBarExtra {
            MenuBarPopoverView(appState: appState, preferences: preferences)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        // 2. Expandable Standalone Window (Month + Year View)
        Window("知时", id: "expanded-calendar") {
            ExpandedCalendarView(appState: appState, preferences: preferences)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 820, height: 560)

        // 3. Minimalist Preferences Window
        Window("偏好设置", id: "settings-window") {
            SettingsView(preferences: preferences)
        }
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    private var menuBarIcon: some View {
        if updater.hasMenuBarUpdateBadge {
            Image(nsImage: MenuBarBadgedIcon.badgedImage)
                .renderingMode(.original)
        } else {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        let l10n = L10n(language: preferences.language)
        let title = appState.menuBarTitle(for: preferences.menuBarDisplayStyle, l10n: l10n)
        if title.isEmpty {
            menuBarIcon
        } else {
            HStack(spacing: 4) {
                menuBarIcon
                Text(title)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
            }
        }
    }
}
