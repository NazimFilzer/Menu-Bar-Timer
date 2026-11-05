import SwiftUI

/// Shared calendar button and popover for date selection throughout the app.
struct CalendarDatePicker: View {
    let title: String
    @Binding var selection: Date
    let theme: PopoverTheme
    var allowedRange: ClosedRange<Date> = Date.distantPast...Date.distantFuture
    @State private var showingCalendar = false

    var body: some View {
        Button { showingCalendar.toggle() } label: {
            Label(selection.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.cardBg, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.cardBorder))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selection.formatted(date: .abbreviated, time: .omitted))
        .popover(isPresented: $showingCalendar) {
            DatePicker(title, selection: $selection, in: allowedRange, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(theme.accentColor)
                .padding()
                .environment(\.colorScheme, .light)
        }
    }
}
