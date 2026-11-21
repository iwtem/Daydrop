import SwiftUI
import AppKit

/// Live vector rendition of the Option 5 Daydrop app icon that dynamically adapts to the active theme.
struct ThemedAppIconView: View {
    let palette: ThemePalette
    var size: CGFloat = 52

    var body: some View {
        let s = size / 824.0
        ZStack {
            // Pure white macOS squircle base
            RoundedRectangle(cornerRadius: 192 * s, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 192 * s, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.75)
                )

            // Inner calendar geometry
            VStack(spacing: 48 * s) {
                // Header bar with two pill binding tabs
                ZStack(alignment: .top) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28 * s,
                        bottomLeadingRadius: 6 * s,
                        bottomTrailingRadius: 6 * s,
                        topTrailingRadius: 28 * s,
                        style: .continuous
                    )
                    .fill(palette.iconHeader)
                    .frame(width: 564 * s, height: 120 * s)
                    .padding(.top, 56 * s)

                    HStack(spacing: 244 * s) {
                        bindingTab(scale: s)
                        bindingTab(scale: s)
                    }
                }

                // 4 x 3 signature dot grid
                VStack(spacing: 42 * s) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 44 * s) {
                            ForEach(0..<4, id: \.self) { col in
                                let isToday = (row == 1 && col == 1)
                                Circle()
                                    .fill(isToday ? palette.todayAccent : palette.softTint)
                                    .frame(width: 108 * s, height: 108 * s)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 12 * s)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.2), value: palette.theme)
    }

    private func bindingTab(scale s: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(palette.iconTabs)
            .frame(width: 44 * s, height: 116 * s)
            .padding(14 * s)
            .background(Capsule(style: .continuous).fill(Color.white))
    }
}

/// Native-proportioned macOS switch toggle that respects the active Daydrop theme color.
struct ThemedSwitchToggleStyle: ToggleStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Button {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                    configuration.isOn.toggle()
                }
            } label: {
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule(style: .continuous)
                        .fill(configuration.isOn ? tint : Color.primary.opacity(0.16))
                        .frame(width: 36, height: 20)

                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.16), radius: 1.5, x: 0, y: 1)
                        .frame(width: 16, height: 16)
                        .padding(2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// Clean macOS segmented control that dynamically adopts the active Daydrop theme color.
struct ThemedSegmentedControl<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [(value: Option, label: String)]
    let tint: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = (selection == option.value)
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selection = option.value
                    }
                } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .white : .primary.opacity(0.82))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .frame(minWidth: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? tint : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.07))
        )
    }
}

/// Renders the menu bar calendar icon with a quiet coral dot badge at the top-right corner
/// while dynamically adapting the base icon tint to macOS light and dark menu bars.
enum MenuBarBadgedIcon {
    static let badgedImage: NSImage = {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            let isDark = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let iconTint: NSColor = isDark ? .white : .black

            if let base = NSImage(named: "MenuBarIcon"),
               let ctx = NSGraphicsContext.current?.cgContext {
                ctx.saveGState()
                ctx.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
                base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                iconTint.setFill()
                rect.fill(using: .sourceIn)
                ctx.endTransparencyLayer()
                ctx.restoreGState()
            }

            let dotDiameter: CGFloat = 5.6
            let dotRect = CGRect(
                x: 16.5 - dotDiameter / 2,
                y: 15.8 - dotDiameter / 2,
                width: dotDiameter,
                height: dotDiameter
            )
            NSColor(DaydropTheme.updateBadge).setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }()
}
