import SwiftUI

/// Rendered clay art, one set per theme palette (`scripts/render-app-art.sh`).
/// Art appears only beside page titles and at moments with nothing else to read:
/// ready to start, goal reached, and empty lists. Figures and charts stay flat.
enum ThemeArt: String {
    case sun, flag, calendar, bars, stopwatch, trophy, mug

    func image(for theme: PopoverTheme) -> NSImage? {
        NSImage(named: "art-\(rawValue)-\(theme.name.lowercased())-\(theme.isLight ? "light" : "dark")")
    }
}

/// Draws theme art at a fixed size, or nothing when the asset is missing. Decorative: hidden from VoiceOver.
struct ThemeArtView: View {
    let art: ThemeArt
    let theme: PopoverTheme
    var size: CGFloat = 48

    var body: some View {
        if let image = art.image(for: theme) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

extension DashboardDestination {
    /// The page's art beside its title. Settings stays plain.
    var art: ThemeArt? {
        switch self {
        case .today: .sun
        case .week: .flag
        case .month: .calendar
        case .analytics: .bars
        case .settings: nil
        }
    }
}
