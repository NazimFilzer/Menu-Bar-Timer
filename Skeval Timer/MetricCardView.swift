import SwiftUI

struct MetricCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let theme: PopoverTheme
    /// Optional link shown in place of the subtitle, for example "Set hourly rate".
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .kerning(0.8)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.accentIcon)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.link)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            } else {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
        // VoiceOver reads title, value, and subtitle as one item. A link keeps its own focus.
        .accessibilityElement(children: action == nil ? .combine : .contain)
    }
}
