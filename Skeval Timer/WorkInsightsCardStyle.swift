import SwiftUI

struct WorkInsightsCardStyle: ViewModifier {
    let theme: PopoverTheme

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(theme.textPrimary)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))
    }
}
