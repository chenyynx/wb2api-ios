import SwiftUI

/// 可选强调色。颜色同时提供浅色/深色变体，保证两种外观下都有足够对比度。
enum AccentChoice: String, CaseIterable, Identifiable, Sendable {
    case violet
    case blue
    case pink
    case rose
    case yellow
    case green
    case orange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .violet: return "紫罗兰"
        case .blue: return "蓝色"
        case .pink: return "粉色"
        case .rose: return "玫红"
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .orange: return "橙色"
        }
    }

    var primary: Color {
        switch self {
        case .violet: return Color(light: "7C5CFF", dark: "A48BFF")
        case .blue: return Color(light: "2563EB", dark: "7EA8FF")
        case .pink: return Color(light: "D6336C", dark: "FF85B3")
        case .rose: return Color(light: "C92A54", dark: "FF7E9D")
        case .yellow: return Color(light: "B45309", dark: "FBBF24")
        case .green: return Color(light: "0F8A5F", dark: "4FD69A")
        case .orange: return Color(light: "D65A0B", dark: "FF9A5A")
        }
    }

    var soft: Color {
        switch self {
        case .violet: return Color(light: "EFEAFF", dark: "2A2350")
        case .blue: return Color(light: "E8F1FF", dark: "18263D")
        case .pink: return Color(light: "FFE8F1", dark: "3A1C2A")
        case .rose: return Color(light: "FFE7ED", dark: "3A1A24")
        case .yellow: return Color(light: "FFF4D6", dark: "3A2A10")
        case .green: return Color(light: "E6F7EF", dark: "153126")
        case .orange: return Color(light: "FFEEE0", dark: "3A2416")
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientEnd: Color {
        switch self {
        case .violet: return Color(light: "5B3BE0", dark: "8E74FF")
        case .blue: return Color(light: "1D4ED8", dark: "9CBEFF")
        case .pink: return Color(light: "B02A5C", dark: "FFA6CC")
        case .rose: return Color(light: "A81C42", dark: "FF9CB4")
        case .yellow: return Color(light: "92400E", dark: "FCD34D")
        case .green: return Color(light: "0B6B4A", dark: "7FE6B7")
        case .orange: return Color(light: "B34700", dark: "FFB27F")
        }
    }
}

/// 当前生效的视觉主题：通过 Environment 下发，切换时全 App 同步更新。
struct AppTheme: Equatable, Sendable {
    static let storageKey = "wb2api.accentColor"

    let accent: AccentChoice

    static let defaultTheme = AppTheme(accent: .violet)

    var primary: Color { accent.primary }
    var soft: Color { accent.soft }
    var gradient: LinearGradient { accent.gradient }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.defaultTheme
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
