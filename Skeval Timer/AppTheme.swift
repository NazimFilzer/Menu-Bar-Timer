import SwiftUI
import Observation

enum AppTheme: String, CaseIterable, Identifiable {
    case citrus = "citrus"
    case sepia = "sepia"
    case nord = "nord"
    case cloud = "cloud"
    case matcha = "matcha"
    case forest = "forest"
    case rose = "rose"
    case lavender = "lavender"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .citrus: return "Citrus"
        case .sepia: return "Sepia"
        case .nord: return "Nord"
        case .cloud: return "Cloud"
        case .matcha: return "Matcha"
        case .forest: return "Forest"
        case .rose: return "Rose"
        case .lavender: return "Lavender"
        }
    }

    var theme: PopoverTheme {
        switch self {
        case .citrus: return PopoverTheme.citrus
        case .sepia: return PopoverTheme.sepia
        case .nord: return PopoverTheme.nord
        case .cloud: return PopoverTheme.cloud
        case .matcha: return PopoverTheme.matcha
        case .forest: return PopoverTheme.forest
        case .rose: return PopoverTheme.rose
        case .lavender: return PopoverTheme.lavender
        }
    }
}

struct PopoverTheme: Equatable {
    let name: String
    let isLight: Bool
    let bgDark: Color
    let cardBg: Color
    let cardBorder: Color
    let accentColor: Color
    let softRed: Color
    let textPrimary: Color
    let textSecondary: Color

    init(
        name: String,
        isLight: Bool = false,
        bgDark: Color,
        cardBg: Color,
        cardBorder: Color,
        accentColor: Color,
        softRed: Color,
        textPrimary: Color,
        textSecondary: Color
    ) {
        self.name = name
        self.isLight = isLight
        self.bgDark = bgDark
        self.cardBg = cardBg
        self.cardBorder = cardBorder
        self.accentColor = accentColor
        self.softRed = softRed
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
    }

    // Backward-compatible alias for existing views referencing neonTeal
    var neonTeal: Color { accentColor }
    var dividerColor: Color { cardBorder }

    var actionButtonForeground: Color {
        switch name {
        case "Matcha": return .white
        default: return .black
        }
    }

    func statusColor(for state: SprintState) -> Color {
        switch state {
        case .recovery: return .orange
        case .paused:
            switch name {
            case "Sepia": return Color(red: 0.90, green: 0.49, blue: 0.26)
            case "Nord": return Color(red: 0.92, green: 0.80, blue: 0.55)
            case "Cloud": return Color(red: 0.55, green: 0.53, blue: 0.30)
            case "Rose": return Color(red: 0.78, green: 0.43, blue: 0.32)
            case "Citrus": return Color(red: 0.72, green: 0.48, blue: 0.12)
            case "Lavender": return Color(red: 0.58, green: 0.43, blue: 0.70)
            case "Matcha": return Color(red: 0.85, green: 0.42, blue: 0.15)
            case "Forest": return Color(red: 0.95, green: 0.65, blue: 0.15)
            default: return Color(red: 1.0, green: 0.65, blue: 0.0)
            }
        case .active: return accentColor
        case .idle: return textSecondary
        }
    }

    static let citrus = PopoverTheme(
        name: "Citrus",
        isLight: true,
        bgDark: Color(red: 1.0, green: 0.98, blue: 0.90),
        cardBg: Color(white: 1.0),
        cardBorder: Color(red: 0.91, green: 0.88, blue: 0.73),
        accentColor: Color(red: 0.88, green: 0.70, blue: 0.30),
        softRed: Color(red: 0.84, green: 0.35, blue: 0.31),
        textPrimary: Color(red: 0.22, green: 0.19, blue: 0.11),
        textSecondary: Color(red: 0.50, green: 0.46, blue: 0.32)
    )

    static let sepia = PopoverTheme(
        name: "Sepia",
        isLight: false,
        bgDark: Color(red: 0.15, green: 0.13, blue: 0.11),
        cardBg: Color(red: 0.21, green: 0.17, blue: 0.15),
        cardBorder: Color(red: 0.35, green: 0.29, blue: 0.25, opacity: 0.5),
        accentColor: Color(red: 0.90, green: 0.66, blue: 0.35),
        softRed: Color(red: 0.92, green: 0.42, blue: 0.38),
        textPrimary: Color(red: 0.96, green: 0.92, blue: 0.88),
        textSecondary: Color(red: 0.66, green: 0.60, blue: 0.55)
    )

    static let nord = PopoverTheme(
        name: "Nord",
        isLight: false,
        bgDark: Color(red: 0.12, green: 0.13, blue: 0.16),
        cardBg: Color(red: 0.16, green: 0.18, blue: 0.21),
        cardBorder: Color(red: 0.24, green: 0.27, blue: 0.32, opacity: 0.6),
        accentColor: Color(red: 0.53, green: 0.75, blue: 0.82),
        softRed: Color(red: 0.75, green: 0.38, blue: 0.42),
        textPrimary: Color(red: 0.93, green: 0.94, blue: 0.96),
        textSecondary: Color(red: 0.60, green: 0.64, blue: 0.70)
    )

    static let cloud = PopoverTheme(
        name: "Cloud",
        isLight: true,
        bgDark: Color(red: 0.96, green: 0.97, blue: 0.99),
        cardBg: Color(white: 1.0),
        cardBorder: Color(red: 0.84, green: 0.87, blue: 0.92),
        accentColor: Color(red: 0.42, green: 0.60, blue: 0.82),
        softRed: Color(red: 0.86, green: 0.35, blue: 0.37),
        textPrimary: Color(red: 0.13, green: 0.17, blue: 0.24),
        textSecondary: Color(red: 0.43, green: 0.48, blue: 0.57)
    )

    static let matcha = PopoverTheme(
        name: "Matcha",
        isLight: true,
        bgDark: Color(red: 0.95, green: 0.96, blue: 0.93),
        cardBg: Color(white: 1.0),
        cardBorder: Color(red: 0.81, green: 0.86, blue: 0.81),
        accentColor: Color(red: 0.17, green: 0.48, blue: 0.30),
        softRed: Color(red: 0.86, green: 0.34, blue: 0.28),
        textPrimary: Color(red: 0.10, green: 0.16, blue: 0.12),
        textSecondary: Color(red: 0.38, green: 0.45, blue: 0.39)
    )

    static let forest = PopoverTheme(
        name: "Forest",
        isLight: false,
        bgDark: Color(red: 0.04, green: 0.09, blue: 0.07),
        cardBg: Color(red: 0.07, green: 0.14, blue: 0.11),
        cardBorder: Color(red: 0.13, green: 0.24, blue: 0.19, opacity: 0.6),
        accentColor: Color(red: 0.18, green: 0.90, blue: 0.62),
        softRed: Color(red: 0.95, green: 0.38, blue: 0.38),
        textPrimary: Color(red: 0.91, green: 0.98, blue: 0.95),
        textSecondary: Color(red: 0.48, green: 0.62, blue: 0.55)
    )

    static let rose = PopoverTheme(
        name: "Rose",
        isLight: true,
        bgDark: Color(red: 1.0, green: 0.96, blue: 0.95),
        cardBg: Color(white: 1.0),
        cardBorder: Color(red: 0.93, green: 0.84, blue: 0.83),
        accentColor: Color(red: 0.82, green: 0.53, blue: 0.55),
        softRed: Color(red: 0.84, green: 0.32, blue: 0.36),
        textPrimary: Color(red: 0.24, green: 0.15, blue: 0.16),
        textSecondary: Color(red: 0.53, green: 0.40, blue: 0.41)
    )

    static let lavender = PopoverTheme(
        name: "Lavender",
        isLight: true,
        bgDark: Color(red: 0.97, green: 0.95, blue: 0.99),
        cardBg: Color(white: 1.0),
        cardBorder: Color(red: 0.87, green: 0.83, blue: 0.92),
        accentColor: Color(red: 0.64, green: 0.52, blue: 0.79),
        softRed: Color(red: 0.85, green: 0.35, blue: 0.45),
        textPrimary: Color(red: 0.19, green: 0.15, blue: 0.25),
        textSecondary: Color(red: 0.46, green: 0.41, blue: 0.55)
    )
}

#if canImport(AppKit)
import AppKit

extension PopoverTheme {
    var accentNSColor: NSColor {
        switch name {
        case "Sepia":
            return NSColor(red: 0.90, green: 0.66, blue: 0.35, alpha: 0.95)
        case "Nord":
            return NSColor(red: 0.53, green: 0.75, blue: 0.82, alpha: 0.95)
        case "Cloud":
            return NSColor(red: 0.42, green: 0.60, blue: 0.82, alpha: 0.95)
        case "Rose":
            return NSColor(red: 0.82, green: 0.53, blue: 0.55, alpha: 0.95)
        case "Matcha":
            return NSColor(red: 0.17, green: 0.48, blue: 0.30, alpha: 1.0)
        case "Forest":
            return NSColor(red: 0.18, green: 0.90, blue: 0.62, alpha: 0.95)
        case "Citrus":
            return NSColor(red: 0.88, green: 0.70, blue: 0.30, alpha: 0.95)
        case "Lavender":
            return NSColor(red: 0.64, green: 0.52, blue: 0.79, alpha: 0.95)
        default:
            return NSColor(red: 0.22, green: 0.85, blue: 0.65, alpha: 0.95)
        }
    }

    var pausedNSColor: NSColor {
        switch name {
        case "Sepia":
            return NSColor(red: 0.90, green: 0.49, blue: 0.26, alpha: 0.95)
        case "Nord":
            return NSColor(red: 0.92, green: 0.80, blue: 0.55, alpha: 0.95)
        case "Matcha":
            return NSColor(red: 0.85, green: 0.42, blue: 0.15, alpha: 1.0)
        case "Forest":
            return NSColor(red: 0.95, green: 0.65, blue: 0.15, alpha: 0.95)
        default:
            return NSColor(red: 1.0, green: 0.68, blue: 0.0, alpha: 0.95)
        }
    }

    func statusTextNSColor(isIdle: Bool) -> NSColor {
        if isIdle { return .white }
        if ["Cloud", "Rose", "Citrus", "Lavender"].contains(name) { return .black }
        return isLight ? .white : .black
    }
}
#endif

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()

    private let storageKey = "skeval_app_theme"

    var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: storageKey)
        }
    }

    var theme: PopoverTheme {
        current.theme
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "skeval_app_theme") ?? AppTheme.citrus.rawValue
        switch saved {
        case "midnight": self.current = .cloud
        case "sunset": self.current = .rose
        case "neon": self.current = .citrus
        case "abyss": self.current = .lavender
        default: self.current = AppTheme(rawValue: saved) ?? .citrus
        }
    }
}
