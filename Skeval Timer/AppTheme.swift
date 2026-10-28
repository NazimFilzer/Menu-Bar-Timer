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

    var theme: PopoverTheme {
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
        case "Matcha", "Lagoon", "Orchid", "Terracotta", "Slate": return .white
        default: return .black
        }
    }

    func statusColor(for state: SprintState) -> Color {
        switch state {
        case .recovery: return .orange
        case .paused:
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

}

#if canImport(AppKit)
import AppKit

extension PopoverTheme {
    var accentNSColor: NSColor {
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
        case "abyss": self.current = .slate
        default: self.current = AppTheme(rawValue: saved) ?? .citrus
        }
    }
}

// A theme-matched date control for recovery, where the end date may span days.
struct RecoveryDatePicker: View {
    @Binding var selection: Date
    let theme: PopoverTheme
    @State private var showingCalendar = false

    var body: some View {
        HStack(spacing: 8) {
            Text("End date")
                .foregroundStyle(theme.textSecondary)
            Button { showingCalendar.toggle() } label: {
                Label(selection.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.cardBg, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.cardBorder))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Recovery end date")
            .accessibilityValue(selection.formatted(date: .abbreviated, time: .omitted))
            .popover(isPresented: $showingCalendar) {
                DatePicker("Recovery end date", selection: $selection, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(theme.accentColor)
                    .padding()
                    .environment(\.colorScheme, .light)
            }
        }
    }
}
