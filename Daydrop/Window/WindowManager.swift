import SwiftUI
import AppKit

/// Configures the hosting NSWindow (floating pin-on-top & smooth activation for LSUIElement apps).
struct WindowConfigurator: NSViewRepresentable {
    let isPinnedOnTop: Bool
    let title: String
    var hideTitlebarSeparator: Bool = false

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applyConfiguration(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyConfiguration(to: nsView.window)
        }
    }

    private func applyConfiguration(to window: NSWindow?) {
        guard let window else { return }
        window.title = title
        window.level = isPinnedOnTop ? .floating : .normal
        window.collectionBehavior.insert(.moveToActiveSpace)
        if hideTitlebarSeparator {
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
        }
    }
}

/// Captures a weak reference to the hosting NSWindow (used to dismiss MenuBarExtra popovers cleanly).
struct HostingWindowFinder: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

enum WindowActivator {
    static func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
