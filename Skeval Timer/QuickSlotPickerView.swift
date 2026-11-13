import SwiftUI

/// One-click durations that fill a sprint form with the latest free slot of that length.
/// `onPick` fills the form and returns false when the day has no gap that long.
struct QuickSlotPickerView: View {
    let theme: PopoverTheme
    let onPick: (Int) -> Bool

    static let presets = [10, 20, 30, 50, 90]
    static let maxMinutes = 24 * 60

    @State private var customText = ""
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text("QUICK")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .help("Fill the latest free slot of this length, before now for today")
                ForEach(Self.presets, id: \.self) { minutes in
                    chip("\(minutes)m") { pick(minutes) }
                        .accessibilityLabel("Fill latest free \(minutes)-minute slot")
                }
                TextField("min", text: $customText)
                    .accessibilityLabel("Custom quick slot minutes")
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 34)
                    .padding(.vertical, 3)
                    .background(theme.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.cardBorder, lineWidth: 1))
                    .onSubmit(pickCustom)
                chip("Fill", action: pickCustom)
                    .disabled(customMinutes == nil)
            }
            if let message {
                Text(message)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.dangerText)
            }
        }
    }

    private var customMinutes: Int? {
        guard let value = Int(customText.trimmingCharacters(in: .whitespaces)),
              (1...Self.maxMinutes).contains(value) else { return nil }
        return value
    }

    private func pickCustom() {
        if let minutes = customMinutes { pick(minutes) }
    }

    private func pick(_ minutes: Int) {
        message = onPick(minutes) ? nil : "No free \(minutes)-min slot on this day"
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(theme.accentText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.cardBorder.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}
