import SwiftUI

public enum AppTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case peachSoda = "peachSoda"
    case mintCoral = "mintCoral"
    case sunnyCitrus = "sunnyCitrus"
    case electricSky = "electricSky"
    case irisBerry = "irisBerry"

    public var id: String { rawValue }
}

public struct ThemePalette: Sendable {
    public let theme: AppTheme
    public let primaryAccent: Color    // Header / Holiday / Weekend accent
    public let todayAccent: Color      // Today highlight / Active selection
    public let softTint: Color         // Soft holiday cell tint (light mode)
    public let solarTermAccent: Color  // 24 Solar terms accent
    public let workdayBadge: Color     // 班 badge

    public func holidayCellTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryAccent.opacity(0.15) : softTint.opacity(0.55)
    }

    public func selectedCellTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? todayAccent.opacity(0.22) : todayAccent.opacity(0.12)
    }

    public func sameDayOfMonthTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? todayAccent.opacity(0.14) : todayAccent.opacity(0.09)
    }

    public func subtitleColor(for kind: DaySubtitleKind, isToday: Bool, isInMonth: Bool) -> Color {
        if isToday {
            return .white.opacity(0.92)
        }
        let opacity = isInMonth ? 1.0 : 0.38
        switch kind {
        case .festival:
            return primaryAccent.opacity(opacity)
        case .solarTerm:
            return solarTermAccent.opacity(opacity)
        case .lunarMonth:
            return todayAccent.opacity(opacity)
        case .lunarDay:
            return Color.secondary.opacity(isInMonth ? 0.85 : 0.35)
        }
    }
}

/// Visual design system supporting 5 bright, clean flat palettes (default: 蜜桃苏打 Peach Soda).
public enum DaydropTheme {
    public static let charcoal = Color(red: 0.137, green: 0.153, blue: 0.188)       // #232730
    public static let defaultWorkday = Color(red: 0.392, green: 0.455, blue: 0.545) // #64748B
    public static let emerald = Color(red: 0.063, green: 0.725, blue: 0.506)        // #10B981

    public static func palette(for theme: AppTheme) -> ThemePalette {
        switch theme {
        case .peachSoda:
            return ThemePalette(
                theme: .peachSoda,
                primaryAccent: Color(red: 1.000, green: 0.392, blue: 0.486), // #FF647C 珊瑚粉
                todayAccent: Color(red: 0.000, green: 0.706, blue: 1.000),   // #00B4FF 清透天蓝
                softTint: Color(red: 1.000, green: 0.878, blue: 0.902),      // #FFE0E6
                solarTermAccent: emerald,
                workdayBadge: defaultWorkday
            )
        case .mintCoral:
            return ThemePalette(
                theme: .mintCoral,
                primaryAccent: Color(red: 0.086, green: 0.827, blue: 0.604), // #16D39A 薄荷绿
                todayAccent: Color(red: 1.000, green: 0.353, blue: 0.373),   // #FF5A5F 珊瑚红
                softTint: Color(red: 0.843, green: 0.953, blue: 0.918),      // #D7F3EA
                solarTermAccent: Color(red: 0.055, green: 0.647, blue: 0.914), // #0EA5E9 晴蓝节气
                workdayBadge: defaultWorkday
            )
        case .sunnyCitrus:
            return ThemePalette(
                theme: .sunnyCitrus,
                primaryAccent: Color(red: 0.961, green: 0.651, blue: 0.137), // #F5A623 暖阳橙黄
                todayAccent: Color(red: 1.000, green: 0.353, blue: 0.212),   // #FF5A36 活力柑橘
                softTint: Color(red: 1.000, green: 0.945, blue: 0.820),      // #FFF1D1
                solarTermAccent: emerald,
                workdayBadge: defaultWorkday
            )
        case .electricSky:
            return ThemePalette(
                theme: .electricSky,
                primaryAccent: Color(red: 0.106, green: 0.631, blue: 1.000), // #1BA1FF 电光晴蓝
                todayAccent: Color(red: 0.961, green: 0.682, blue: 0.000),   // #F5AE00 阳光琥珀
                softTint: Color(red: 0.863, green: 0.937, blue: 1.000),      // #DCEFFF
                solarTermAccent: emerald,
                workdayBadge: defaultWorkday
            )
        case .irisBerry:
            return ThemePalette(
                theme: .irisBerry,
                primaryAccent: Color(red: 0.388, green: 0.400, blue: 0.945), // #6366F1 鸢尾蓝紫
                todayAccent: Color(red: 1.000, green: 0.302, blue: 0.553),   // #FF4D8D 树莓粉
                softTint: Color(red: 0.890, green: 0.898, blue: 1.000),      // #E3E5FF
                solarTermAccent: emerald,
                workdayBadge: defaultWorkday
            )
        }
    }

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

    public static func hoverCellTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.07)
            : Color.black.opacity(0.04)
    }
}
