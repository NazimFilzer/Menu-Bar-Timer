import SwiftUI
import Observation

enum AppTheme: String, CaseIterable, Identifiable {
    case citrus = "citrus"
    case sand = "sepia"
    case sky = "nord"
    case cloud = "cloud"
    case matcha = "matcha"
    case mint = "forest"
    case rose = "rose"
    case slate = "lavender"
    case confetti = "sorbet"
    case lagoon = "lagoon"
    case orchid = "orchid"
    case terracotta = "peach"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .citrus: return "Citrus"
        case .sand: return "Sand"
        case .sky: return "Sky"
        case .cloud: return "Cloud"
        case .matcha: return "Matcha"
        case .mint: return "Mint"
        case .rose: return "Rose"
        case .slate: return "Slate"
        case .confetti: return "Confetti"
        case .lagoon: return "Lagoon"
        case .orchid: return "Orchid"
        case .terracotta: return "Terracotta"
        }
    }

    /// The light palette. Use `theme(dark:)` to follow the system appearance.
    var theme: PopoverTheme { theme(dark: false) }

    func theme(dark: Bool) -> PopoverTheme {
        dark ? darkTheme : lightTheme
    }

    private var darkTheme: PopoverTheme {
        switch self {
        case .citrus: return PopoverTheme.citrusDark
        case .sand: return PopoverTheme.sandDark
        case .sky: return PopoverTheme.skyDark
        case .cloud: return PopoverTheme.cloudDark
        case .matcha: return PopoverTheme.matchaDark
        case .mint: return PopoverTheme.mintDark
        case .rose: return PopoverTheme.roseDark
        case .slate: return PopoverTheme.slateDark
        case .confetti: return PopoverTheme.confettiDark
        case .lagoon: return PopoverTheme.lagoonDark
        case .orchid: return PopoverTheme.orchidDark
        case .terracotta: return PopoverTheme.terracottaDark
        }
    }

    private var lightTheme: PopoverTheme {
        switch self {
        case .citrus: return PopoverTheme.citrus
        case .sand: return PopoverTheme.sand
        case .sky: return PopoverTheme.sky
        case .cloud: return PopoverTheme.cloud
        case .matcha: return PopoverTheme.matcha
        case .mint: return PopoverTheme.mint
        case .rose: return PopoverTheme.rose
        case .slate: return PopoverTheme.slate
        case .confetti: return PopoverTheme.confetti
        case .lagoon: return PopoverTheme.lagoon
        case .orchid: return PopoverTheme.orchid
        case .terracotta: return PopoverTheme.terracotta
        }
    }
}

/// The user's Light/Dark choice in Settings. Independent of the macOS appearance.
enum ThemeAppearance: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }
    var displayName: String { self == .light ? "Light" : "Dark" }
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
        if !isLight { return .black }
        switch name {
        case "Matcha", "Lagoon", "Orchid", "Terracotta", "Slate": return .white
        default: return .black
        }
    }

    func statusColor(for state: SprintState) -> Color {
        switch state {
        case .recovery: return .orange
        case .paused:
            if !isLight { return Color(red: 1.0, green: 0.65, blue: 0.0) }
            switch name {
            case "Sand": return Color(red: 0.90, green: 0.49, blue: 0.26)
            case "Sky": return Color(red: 0.92, green: 0.80, blue: 0.55)
            case "Cloud": return Color(red: 0.55, green: 0.53, blue: 0.30)
            case "Rose": return Color(red: 0.78, green: 0.43, blue: 0.32)
            case "Citrus": return Color(red: 0.72, green: 0.48, blue: 0.12)
            case "Slate": return Color(red: 0.70, green: 0.38, blue: 0.18)
            case "Matcha": return Color(red: 0.85, green: 0.42, blue: 0.15)
            case "Mint": return Color(red: 0.95, green: 0.65, blue: 0.15)
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

    static let sand = PopoverTheme(
        name: "Sand",
        isLight: true,
        bgDark: Color(red: 0.98, green: 0.95, blue: 0.90),
        cardBg: Color(red: 1.0, green: 0.99, blue: 0.97),
        cardBorder: Color(red: 0.88, green: 0.82, blue: 0.73),
        accentColor: Color(red: 0.76, green: 0.54, blue: 0.31),
        softRed: Color(red: 0.78, green: 0.32, blue: 0.28),
        textPrimary: Color(red: 0.25, green: 0.19, blue: 0.14),
        textSecondary: Color(red: 0.51, green: 0.43, blue: 0.36)
    )

    static let sky = PopoverTheme(
        name: "Sky",
        isLight: true,
        bgDark: Color(red: 0.92, green: 0.97, blue: 0.98),
        cardBg: Color(red: 0.98, green: 1.0, blue: 1.0),
        cardBorder: Color(red: 0.75, green: 0.86, blue: 0.89),
        accentColor: Color(red: 0.32, green: 0.64, blue: 0.71),
        softRed: Color(red: 0.75, green: 0.32, blue: 0.36),
        textPrimary: Color(red: 0.12, green: 0.23, blue: 0.27),
        textSecondary: Color(red: 0.35, green: 0.48, blue: 0.52)
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
        textSecondary: Color(red: 0.40, green: 0.45, blue: 0.54)
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

    static let mint = PopoverTheme(
        name: "Mint",
        isLight: true,
        bgDark: Color(red: 0.91, green: 0.97, blue: 0.94),
        cardBg: Color(red: 0.98, green: 1.0, blue: 0.99),
        cardBorder: Color(red: 0.73, green: 0.86, blue: 0.79),
        accentColor: Color(red: 0.31, green: 0.66, blue: 0.51),
        softRed: Color(red: 0.80, green: 0.32, blue: 0.32),
        textPrimary: Color(red: 0.12, green: 0.24, blue: 0.19),
        textSecondary: Color(red: 0.35, green: 0.48, blue: 0.41)
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

    static let slate = PopoverTheme(
        name: "Slate",
        isLight: true,
        bgDark: Color(red: 0.92, green: 0.93, blue: 0.93),
        cardBg: Color(red: 0.99, green: 0.99, blue: 0.98),
        cardBorder: Color(red: 0.76, green: 0.79, blue: 0.79),
        accentColor: Color(red: 0.29, green: 0.35, blue: 0.37),
        softRed: Color(red: 0.76, green: 0.31, blue: 0.26),
        textPrimary: Color(red: 0.16, green: 0.19, blue: 0.20),
        textSecondary: Color(red: 0.36, green: 0.40, blue: 0.41)
    )
    static let confetti = PopoverTheme(
        name: "Confetti", isLight: true,
        bgDark: Color(red: 1.0, green: 0.97, blue: 0.80),
        cardBg: Color(red: 1.0, green: 0.99, blue: 0.95),
        cardBorder: Color(red: 0.86, green: 0.82, blue: 0.67),
        accentColor: Color(red: 0.64, green: 0.37, blue: 0.66),
        softRed: Color(red: 0.75, green: 0.30, blue: 0.33),
        textPrimary: Color(red: 0.25, green: 0.19, blue: 0.25),
        textSecondary: Color(red: 0.47, green: 0.39, blue: 0.43)
    )

    static let lagoon = PopoverTheme(
        name: "Lagoon", isLight: true,
        bgDark: Color(red: 0.90, green: 0.97, blue: 0.96),
        cardBg: Color(red: 0.98, green: 1.0, blue: 0.99),
        cardBorder: Color(red: 0.71, green: 0.85, blue: 0.83),
        accentColor: Color(red: 0.67, green: 0.35, blue: 0.23),
        softRed: Color(red: 0.75, green: 0.32, blue: 0.31),
        textPrimary: Color(red: 0.11, green: 0.23, blue: 0.25),
        textSecondary: Color(red: 0.31, green: 0.44, blue: 0.45)
    )

    static let orchid = PopoverTheme(
        name: "Orchid", isLight: true,
        bgDark: Color(red: 0.96, green: 0.93, blue: 0.99),
        cardBg: Color(red: 1.0, green: 0.98, blue: 1.0),
        cardBorder: Color(red: 0.84, green: 0.78, blue: 0.90),
        accentColor: Color(red: 0.49, green: 0.36, blue: 0.68),
        softRed: Color(red: 0.76, green: 0.30, blue: 0.42),
        textPrimary: Color(red: 0.22, green: 0.15, blue: 0.28),
        textSecondary: Color(red: 0.45, green: 0.37, blue: 0.51)
    )

    static let terracotta = PopoverTheme(
        name: "Terracotta", isLight: true,
        bgDark: Color(red: 1.0, green: 0.94, blue: 0.92),
        cardBg: Color(red: 1.0, green: 0.99, blue: 0.97),
        cardBorder: Color(red: 0.92, green: 0.80, blue: 0.75),
        accentColor: Color(red: 0.20, green: 0.43, blue: 0.42),
        softRed: Color(red: 0.75, green: 0.28, blue: 0.29),
        textPrimary: Color(red: 0.27, green: 0.17, blue: 0.15),
        textSecondary: Color(red: 0.49, green: 0.36, blue: 0.33)
    )

    // MARK: Dark twins
    // Same hue as each light theme; the accent is lifted so it reads as a fill on a dark card.
    // ThemeManager picks these when macOS is in Dark Mode.

    static let citrusDark = PopoverTheme(
        name: "Citrus", isLight: false,
        bgDark: Color(red: 0.12, green: 0.11, blue: 0.08),
        cardBg: Color(red: 0.16, green: 0.16, blue: 0.12),
        cardBorder: Color(red: 0.27, green: 0.26, blue: 0.20),
        accentColor: Color(red: 0.88, green: 0.70, blue: 0.30),
        softRed: Color(red: 0.84, green: 0.35, blue: 0.31),
        textPrimary: Color(red: 0.93, green: 0.92, blue: 0.89),
        textSecondary: Color(red: 0.73, green: 0.71, blue: 0.62)
    )

    static let sandDark = PopoverTheme(
        name: "Sand", isLight: false,
        bgDark: Color(red: 0.12, green: 0.11, blue: 0.09),
        cardBg: Color(red: 0.17, green: 0.15, blue: 0.13),
        cardBorder: Color(red: 0.28, green: 0.26, blue: 0.22),
        accentColor: Color(red: 0.86, green: 0.63, blue: 0.40),
        softRed: Color(red: 0.78, green: 0.32, blue: 0.28),
        textPrimary: Color(red: 0.95, green: 0.92, blue: 0.89),
        textSecondary: Color(red: 0.76, green: 0.69, blue: 0.63)
    )

    static let skyDark = PopoverTheme(
        name: "Sky", isLight: false,
        bgDark: Color(red: 0.10, green: 0.12, blue: 0.12),
        cardBg: Color(red: 0.14, green: 0.16, blue: 0.17),
        cardBorder: Color(red: 0.23, green: 0.27, blue: 0.28),
        accentColor: Color(red: 0.42, green: 0.74, blue: 0.81),
        softRed: Color(red: 0.75, green: 0.32, blue: 0.36),
        textPrimary: Color(red: 0.89, green: 0.93, blue: 0.95),
        textSecondary: Color(red: 0.63, green: 0.73, blue: 0.76)
    )

    static let cloudDark = PopoverTheme(
        name: "Cloud", isLight: false,
        bgDark: Color(red: 0.11, green: 0.11, blue: 0.12),
        cardBg: Color(red: 0.15, green: 0.16, blue: 0.17),
        cardBorder: Color(red: 0.25, green: 0.26, blue: 0.28),
        accentColor: Color(red: 0.51, green: 0.70, blue: 0.92),
        softRed: Color(red: 0.86, green: 0.35, blue: 0.37),
        textPrimary: Color(red: 0.90, green: 0.92, blue: 0.95),
        textSecondary: Color(red: 0.67, green: 0.71, blue: 0.78)
    )

    static let matchaDark = PopoverTheme(
        name: "Matcha", isLight: false,
        bgDark: Color(red: 0.11, green: 0.12, blue: 0.10),
        cardBg: Color(red: 0.15, green: 0.16, blue: 0.14),
        cardBorder: Color(red: 0.26, green: 0.26, blue: 0.24),
        accentColor: Color(red: 0.46, green: 0.76, blue: 0.56),
        softRed: Color(red: 0.86, green: 0.34, blue: 0.28),
        textPrimary: Color(red: 0.90, green: 0.93, blue: 0.91),
        textSecondary: Color(red: 0.66, green: 0.73, blue: 0.67)
    )

    static let mintDark = PopoverTheme(
        name: "Mint", isLight: false,
        bgDark: Color(red: 0.09, green: 0.12, blue: 0.11),
        cardBg: Color(red: 0.13, green: 0.16, blue: 0.15),
        cardBorder: Color(red: 0.22, green: 0.27, blue: 0.25),
        accentColor: Color(red: 0.42, green: 0.76, blue: 0.61),
        softRed: Color(red: 0.80, green: 0.32, blue: 0.32),
        textPrimary: Color(red: 0.89, green: 0.93, blue: 0.91),
        textSecondary: Color(red: 0.64, green: 0.73, blue: 0.68)
    )

    static let roseDark = PopoverTheme(
        name: "Rose", isLight: false,
        bgDark: Color(red: 0.13, green: 0.11, blue: 0.10),
        cardBg: Color(red: 0.17, green: 0.15, blue: 0.15),
        cardBorder: Color(red: 0.28, green: 0.25, blue: 0.24),
        accentColor: Color(red: 0.88, green: 0.59, blue: 0.61),
        softRed: Color(red: 0.84, green: 0.32, blue: 0.36),
        textPrimary: Color(red: 0.95, green: 0.91, blue: 0.91),
        textSecondary: Color(red: 0.78, green: 0.68, blue: 0.68)
    )

    static let slateDark = PopoverTheme(
        name: "Slate", isLight: false,
        bgDark: Color(white: 0.11),
        cardBg: Color(red: 0.15, green: 0.16, blue: 0.16),
        cardBorder: Color(red: 0.25, green: 0.26, blue: 0.26),
        accentColor: Color(red: 0.63, green: 0.70, blue: 0.72),
        softRed: Color(red: 0.76, green: 0.31, blue: 0.26),
        textPrimary: Color(red: 0.89, green: 0.93, blue: 0.94),
        textSecondary: Color(red: 0.63, green: 0.73, blue: 0.75)
    )

    static let confettiDark = PopoverTheme(
        name: "Confetti", isLight: false,
        bgDark: Color(red: 0.12, green: 0.11, blue: 0.08),
        cardBg: Color(red: 0.16, green: 0.16, blue: 0.12),
        cardBorder: Color(red: 0.27, green: 0.26, blue: 0.21),
        accentColor: Color(red: 0.85, green: 0.56, blue: 0.87),
        softRed: Color(red: 0.75, green: 0.30, blue: 0.33),
        textPrimary: Color(red: 0.94, green: 0.91, blue: 0.94),
        textSecondary: Color(red: 0.77, green: 0.68, blue: 0.72)
    )

    static let lagoonDark = PopoverTheme(
        name: "Lagoon", isLight: false,
        bgDark: Color(red: 0.09, green: 0.12, blue: 0.12),
        cardBg: Color(red: 0.13, green: 0.16, blue: 0.16),
        cardBorder: Color(red: 0.22, green: 0.27, blue: 0.27),
        accentColor: Color(red: 0.93, green: 0.58, blue: 0.45),
        softRed: Color(red: 0.75, green: 0.32, blue: 0.31),
        textPrimary: Color(red: 0.89, green: 0.93, blue: 0.94),
        textSecondary: Color(red: 0.62, green: 0.73, blue: 0.74)
    )

    static let orchidDark = PopoverTheme(
        name: "Orchid", isLight: false,
        bgDark: Color(red: 0.12, green: 0.11, blue: 0.13),
        cardBg: Color(red: 0.16, green: 0.15, blue: 0.18),
        cardBorder: Color(red: 0.27, green: 0.25, blue: 0.30),
        accentColor: Color(red: 0.74, green: 0.60, blue: 0.95),
        softRed: Color(red: 0.76, green: 0.30, blue: 0.42),
        textPrimary: Color(red: 0.93, green: 0.91, blue: 0.95),
        textSecondary: Color(red: 0.73, green: 0.69, blue: 0.76)
    )

    static let terracottaDark = PopoverTheme(
        name: "Terracotta", isLight: false,
        bgDark: Color(red: 0.13, green: 0.11, blue: 0.10),
        cardBg: Color(red: 0.18, green: 0.15, blue: 0.14),
        cardBorder: Color(red: 0.30, green: 0.25, blue: 0.23),
        accentColor: Color(red: 0.50, green: 0.73, blue: 0.72),
        softRed: Color(red: 0.75, green: 0.28, blue: 0.29),
        textPrimary: Color(red: 0.95, green: 0.91, blue: 0.90),
        textSecondary: Color(red: 0.78, green: 0.68, blue: 0.66)
    )
}

#if canImport(AppKit)
import AppKit

extension PopoverTheme {
    /// The accent colour, darkened until it reads as text (5:1) on the card.
    /// Use it for text. Keep `accentColor` for bars, icons, and borders.
    var accentText: Color { readable(NSColor(accentColor)) }

    /// Orange for "behind" and warning text, darkened until it reads as text on the card.
    var warningText: Color { readable(NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1)) }

    /// Green for "goal reached" text, darkened until it reads as text on the card.
    var successText: Color { readable(NSColor(red: 0.18, green: 0.62, blue: 0.40, alpha: 1)) }

    /// The theme red, adjusted until it reads as text on the card. Keep `softRed` for glows.
    var dangerText: Color { readable(NSColor(softRed)) }

    /// Readable text for a sprint state word ("Active", "Paused"). `statusColor` stays for dots and pills.
    func statusText(for state: SprintState) -> Color {
        switch state {
        case .active: return accentText
        case .paused, .recovery: return warningText
        case .idle: return textSecondary
        }
    }

    /// The accent, adjusted until an icon or graphic is visible (3:1) on the card.
    /// Use it for SF Symbols and indicator lines. Text uses `accentText`.
    var accentIcon: Color { readable(NSColor(accentColor), minimumRatio: 3) }

    /// The red for filled buttons with white labels, darkened until white reads on it (4.5:1).
    var dangerFill: Color { Color(Self.adjusted(NSColor(softRed), against: .white, toward: .black, minimumRatio: 4.5)) }

    /// The darker end of the Clock Out gradient.
    var dangerFillDeep: Color {
        let fill = Self.adjusted(NSColor(softRed), against: .white, toward: .black, minimumRatio: 4.5)
        return Color(fill.blended(withFraction: 0.12, of: .black) ?? fill)
    }

    private func readable(_ base: NSColor, minimumRatio: Double = 5) -> Color {
        Color(Self.adjusted(base, against: NSColor(cardBg), toward: isLight ? .black : .white,
                            minimumRatio: minimumRatio))
    }

    /// Blends `base` toward `target` in 5% steps until it reaches `minimumRatio` against `background`.
    private static func adjusted(_ base: NSColor, against background: NSColor, toward target: NSColor,
                                 minimumRatio: Double) -> NSColor {
        guard let back = background.usingColorSpace(.sRGB),
              let start = base.usingColorSpace(.sRGB),
              let end = target.usingColorSpace(.sRGB) else { return base }
        var color = start
        var step = 0.0
        while contrast(color, back) < minimumRatio, step < 1 {
            step += 0.05
            color = start.blended(withFraction: step, of: end)?.usingColorSpace(.sRGB) ?? color
        }
        return color
    }

    private static func contrast(_ a: NSColor, _ b: NSColor) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    private static func luminance(_ color: NSColor) -> Double {
        func linear(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.redComponent) + 0.7152 * linear(color.greenComponent)
            + 0.0722 * linear(color.blueComponent)
    }
}

extension PopoverTheme {
    var accentNSColor: NSColor {
        if !isLight { return NSColor(accentColor) }
        switch name {
        case "Sand":
            return NSColor(red: 0.76, green: 0.54, blue: 0.31, alpha: 0.95)
        case "Sky":
            return NSColor(red: 0.32, green: 0.64, blue: 0.71, alpha: 0.95)
        case "Cloud":
            return NSColor(red: 0.42, green: 0.60, blue: 0.82, alpha: 0.95)
        case "Rose":
            return NSColor(red: 0.82, green: 0.53, blue: 0.55, alpha: 0.95)
        case "Matcha":
            return NSColor(red: 0.17, green: 0.48, blue: 0.30, alpha: 1.0)
        case "Mint":
            return NSColor(red: 0.31, green: 0.66, blue: 0.51, alpha: 0.95)
        case "Citrus":
            return NSColor(red: 0.88, green: 0.70, blue: 0.30, alpha: 0.95)
        case "Slate":
            return NSColor(red: 0.29, green: 0.35, blue: 0.37, alpha: 0.95)
        case "Confetti", "Lagoon", "Orchid", "Terracotta":
            return NSColor(accentColor)
        default:
            return NSColor(red: 0.22, green: 0.85, blue: 0.65, alpha: 0.95)
        }
    }

    var pausedNSColor: NSColor {
        if !isLight { return NSColor(red: 1.0, green: 0.68, blue: 0.0, alpha: 0.95) }
        switch name {
        case "Sand":
            return NSColor(red: 0.90, green: 0.49, blue: 0.26, alpha: 0.95)
        case "Sky":
            return NSColor(red: 0.92, green: 0.80, blue: 0.55, alpha: 0.95)
        case "Matcha":
            return NSColor(red: 0.85, green: 0.42, blue: 0.15, alpha: 1.0)
        case "Mint":
            return NSColor(red: 0.95, green: 0.65, blue: 0.15, alpha: 0.95)
        default:
            return NSColor(red: 1.0, green: 0.68, blue: 0.0, alpha: 0.95)
        }
    }

    func statusTextNSColor(isIdle: Bool) -> NSColor {
        if isIdle { return .white }
        if ["Cloud", "Rose", "Citrus", "Sand", "Sky", "Mint", "Confetti"].contains(name) { return .black }
        return isLight ? .white : .black
    }
}
#endif

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()

    private let storageKey = "skeval_app_theme"
    private let appearanceKey = "skeval_app_appearance"
    @ObservationIgnored private let defaults: UserDefaults

    var current: AppTheme {
        didSet {
            defaults.set(current.rawValue, forKey: storageKey)
        }
    }

    /// Light or Dark, chosen in Settings. The app does not follow the macOS appearance.
    var appearance: ThemeAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: appearanceKey)
        }
    }

    var theme: PopoverTheme {
        current.theme(dark: appearance == .dark)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appearance = ThemeAppearance(rawValue: defaults.string(forKey: "skeval_app_appearance") ?? "") ?? .light
        let saved = defaults.string(forKey: "skeval_app_theme") ?? AppTheme.citrus.rawValue
        switch saved {
        case "midnight": self.current = .cloud
        case "sunset": self.current = .rose
        case "neon": self.current = .citrus
        case "abyss": self.current = .slate
        default: self.current = AppTheme(rawValue: saved) ?? .citrus
        }
    }
}

// A theme-matched date control for recovery, where the end date may span days.
struct RecoveryDatePicker: View {
    @Binding var selection: Date
    let theme: PopoverTheme

    var body: some View {
        HStack(spacing: 8) {
            Text("End date")
                .foregroundStyle(theme.textSecondary)
            CalendarDatePicker(title: "Recovery end date", selection: $selection, theme: theme)
        }
    }
}

// MARK: - Window appearance

extension PopoverTheme {
    var nsAppearance: NSAppearance? { NSAppearance(named: isLight ? .aqua : .darkAqua) }
}

/// `preferredColorScheme` does not reach an `NSPopover`'s window, so native menus,
/// steppers, and alerts would follow the macOS appearance instead of the theme.
/// This sets the hosting window's appearance to match, and updates it live.
private struct WindowAppearanceView: NSViewRepresentable {
    let appearance: NSAppearance?

    final class Probe: NSView {
        var appearanceToApply: NSAppearance?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.appearance = appearanceToApply
        }
    }

    func makeNSView(context: Context) -> Probe {
        let view = Probe()
        view.appearanceToApply = appearance
        return view
    }

    func updateNSView(_ view: Probe, context: Context) {
        view.appearanceToApply = appearance
        if view.window?.appearance?.name != appearance?.name {
            view.window?.appearance = appearance
        }
    }
}

extension View {
    /// Applies the theme's light or dark appearance to SwiftUI and to the hosting AppKit window.
    func themeAppearance(_ theme: PopoverTheme) -> some View {
        preferredColorScheme(theme.isLight ? .light : .dark)
            .background(WindowAppearanceView(appearance: theme.nsAppearance).frame(width: 0, height: 0))
    }

    /// The dashboard card surface: card fill, rounded corners, and a hairline border.
    func themedCard(_ theme: PopoverTheme, padding: CGFloat = 12, radius: CGFloat = 10) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBg, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(theme.cardBorder, lineWidth: 1))
    }
}
