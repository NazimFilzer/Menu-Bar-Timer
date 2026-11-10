import SwiftUI

// Shared parts for the dashboard pages, taken from the Month page, so Today, Week, and Month
// read as one product. Cards use `WorkInsightsCardStyle`.

/// Card title: accent icon on the left, an uppercase tracked label, and optional trailing content.
struct DashboardCardHeader<Trailing: View>: View {
    let title: String
    let icon: String
    let theme: PopoverTheme
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.accentIcon)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .kerning(0.8)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .fixedSize()
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension DashboardCardHeader where Trailing == EmptyView {
    init(title: String, icon: String, theme: PopoverTheme) {
        self.init(title: title, icon: icon, theme: theme) { EmptyView() }
    }
}

extension Font {
    /// The main duration on a card, such as Worked.
    static let dashboardHero = Font.system(size: 28, weight: .bold, design: .monospaced)
    /// A clock time used as a card's answer, such as the finish forecast.
    static let dashboardHeroTime = Font.system(size: 28, weight: .semibold, design: .rounded)
    /// An amount beside or under the hero figure.
    static let dashboardMoney = Font.system(size: 18, weight: .bold, design: .monospaced)
    /// Subtitles and captions inside cards.
    static let dashboardCaption = Font.system(size: 12, weight: .medium, design: .rounded)
}

/// A label and value on one line, with an optional right-aligned detail under the value.
struct DashboardFactRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil
    var emphasized = false
    var detail: String? = nil
    let theme: PopoverTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.dashboardCaption)
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: emphasized ? 16 : 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(valueColor ?? theme.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

/// A theme-drawn progress capsule. Native progress views turn grey while the window is inactive.
struct DashboardProgressBar: View {
    let fraction: Double
    var isComplete = false
    let theme: PopoverTheme
    let accessibilityTitle: String

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.cardBorder.opacity(0.35))
                if fraction > 0 {
                    Capsule()
                        .fill(isComplete ? theme.successText : theme.accentColor)
                        .frame(width: max(8, proxy.size.width * min(1, fraction)))
                }
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue("\(Int((min(1, fraction) * 100).rounded())) percent")
    }
}

/// An info button that shows an explanation on click, so explanations stay out of the card body.
/// The same words are its tooltip and VoiceOver hint.
struct DashboardInfoButton: View {
    let text: String
    let theme: PopoverTheme
    var accessibilityTitle = "More information"
    @State private var showing = false

    var body: some View {
        Button { showing.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSecondary)
        }
        .buttonStyle(.plain)
        .help(text)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityHint(text)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 280, alignment: .leading)
                .padding(14)
        }
    }
}

/// Previous and next buttons around the period label, plus a reset button when another period
/// is shown. Command [ and Command ] move by one period on every page.
struct DashboardPeriodNavigator<Label: View>: View {
    let periodName: String
    var canGoForward: Bool
    var resetTitle: String? = nil
    var resetShortcut: KeyboardShortcut? = nil
    let theme: PopoverTheme
    let move: (Int) -> Void
    var reset: () -> Void = {}
    @ViewBuilder var label: Label

    var body: some View {
        HStack(spacing: 8) {
            chevron("chevron.left", label: "Previous \(periodName)", enabled: true, shortcut: "[") { move(-1) }
            label
            chevron("chevron.right", label: "Next \(periodName)", enabled: canGoForward, shortcut: "]") { move(1) }
            if let resetTitle {
                Button(resetTitle, action: reset)
                    .keyboardShortcut(resetShortcut)
                    .help("Back to \(resetTitle.lowercased())")
            }
            Spacer(minLength: 0)
        }
    }

    private func chevron(_ icon: String, label: String, enabled: Bool, shortcut: KeyEquivalent,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26)
                .background(theme.cardBg, in: Circle())
                .foregroundStyle(enabled ? theme.textPrimary : theme.textSecondary.opacity(0.4))
                .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .keyboardShortcut(shortcut, modifiers: .command)
        .accessibilityLabel(label)
        .help("\(label), Command \(String(shortcut.character))")
    }
}
