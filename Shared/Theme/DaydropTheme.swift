import SwiftUI

/// Visual design system built around the selected "蜜桃苏打" (Peach Soda) palette.
public enum DaydropTheme {
    // Core brand solids (Palette E)
    public static let coral = Color(red: 1.000, green: 0.392, blue: 0.486)       // #FF647C — Header / Holiday / Weekend accent
    public static let skyBlue = Color(red: 0.000, green: 0.706, blue: 1.000)     // #00B4FF — Today highlight / Active selection
    public static let blush = Color(red: 1.000, green: 0.878, blue: 0.902)       // #FFE0E6 — Soft coral pill tint
    public static let charcoal = Color(red: 0.137, green: 0.153, blue: 0.188)    // #232730 — Crisp ink accent

    // Supporting semantic accents
    public static let solarTermGreen = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981 — Fresh emerald for 24 solar terms
    public static let workdayBadge = Color(red: 0.392, green: 0.455, blue: 0.545)   // #64748B — Crisp slate for 班 badge

    // Adaptive surface helpers
    public static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.145, green: 0.153, blue: 0.173)
            : Color.white
    }

    public static func secondarySurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.06)
            : Color(red: 0.969, green: 0.973, blue: 0.980)
    }

    public static func subtleBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.09)
            : Color.black.opacity(0.06)
    }

    public static func holidayCellTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? coral.opacity(0.14)
            : blush.opacity(0.45)
    }

    public static func selectedCellTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? skyBlue.opacity(0.22)
            : skyBlue.opacity(0.12)
    }

    public static func sameDayOfMonthTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? skyBlue.opacity(0.14)
            : skyBlue.opacity(0.09)
    }

    public static func hoverCellTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.07)
            : Color.black.opacity(0.04)
    }

    public static func subtitleColor(for kind: DaySubtitleKind, isToday: Bool, isInMonth: Bool) -> Color {
        if isToday {
            return .white.opacity(0.92)
        }
        let opacity = isInMonth ? 1.0 : 0.38
        switch kind {
        case .festival:
            return coral.opacity(opacity)
        case .solarTerm:
            return solarTermGreen.opacity(opacity)
        case .lunarMonth:
            return skyBlue.opacity(opacity)
        case .lunarDay:
            return Color.secondary.opacity(isInMonth ? 0.85 : 0.35)
        }
    }
}
