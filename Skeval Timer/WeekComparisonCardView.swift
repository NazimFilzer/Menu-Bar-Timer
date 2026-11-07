import SwiftUI

struct WeekComparisonCardView: View {
    let comparison: WeekComparison
    let theme: PopoverTheme
    @Binding var compareClockTime: Bool
    @State private var showingNumbers = false

    private var maximum: TimeInterval {
        max(1, comparison.days.map { max($0.currentSeconds, $0.previousSeconds) }.max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(comparison.isCurrentWeek ? "Same point last week" : "Compared with the previous week")
                .font(.headline)
            Text(narrative).font(.title3).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            if comparison.isCurrentWeek {
                Toggle("Compare last week's matching day at the same clock time", isOn: $compareClockTime)
                    .toggleStyle(.checkbox).font(.caption)
                Text(comparison.usesClockTime
                     ? "Earlier days count in full. The matching day last week ends at the current local time."
                     : "Today is still in progress. Last week's matching day counts in full.")
                    .font(.caption).foregroundStyle(theme.textSecondary)
            }
            ForEach(comparison.days) { day in
                dayBars(day)
            }
            HStack(spacing: 18) {
                Label("Selected week", systemImage: "circle.fill").foregroundStyle(theme.neonTeal)
                Label("Previous week", systemImage: "circle.fill").foregroundStyle(theme.textSecondary)
            }
            .font(.caption)
            if comparison.isEstimated {
                Text("Estimate. Paused time is spread evenly within sprints that cross the comparison time. Exact pause times are not stored.")
                    .font(.caption).foregroundStyle(theme.textSecondary)
            }
            DisclosureGroup("Show the numbers", isExpanded: $showingNumbers) {
                comparisonTable
            }
            .font(.caption)
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private var narrative: String {
        let current = TimeFormatter.format(shortDuration: comparison.currentSeconds)
        let previous = TimeFormatter.format(shortDuration: comparison.previousSeconds)
        let gap = TimeFormatter.format(shortDuration: abs(comparison.difference))
        if comparison.difference == 0 { return "You recorded \(current) in each compared period." }
        let direction = comparison.difference > 0 ? "more" : "less"
        return "You recorded \(current), compared with \(previous) last week. That is \(gap) \(direction) work."
    }

    private func dayBars(_ day: WeekComparisonDay) -> some View {
        HStack(spacing: 12) {
            Text(day.date, format: .dateTime.weekday(.abbreviated)).frame(width: 34, alignment: .leading)
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(theme.neonTeal)
                        .frame(width: geometry.size.width * min(1, day.currentSeconds / maximum), height: 5)
                    Capsule().fill(theme.textSecondary.opacity(0.5))
                        .frame(width: geometry.size.width * min(1, day.previousSeconds / maximum), height: 5)
                }
            }
            .frame(height: 13)
            Text("\(TimeFormatter.format(shortDuration: day.currentSeconds)) / \(TimeFormatter.format(shortDuration: day.previousSeconds))")
                .monospacedDigit().frame(width: 150, alignment: .trailing)
        }
        .font(.caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)): selected week \(TimeFormatter.format(shortDuration: day.currentSeconds)), previous week \(TimeFormatter.format(shortDuration: day.previousSeconds))")
    }

    private var comparisonTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
            GridRow {
                Text("Selected date"); Text("Work"); Text("Previous date"); Text("Work")
            }.fontWeight(.semibold)
            ForEach(comparison.days) { day in
                GridRow {
                    Text(day.date, format: .dateTime.month().day())
                    Text(TimeFormatter.format(shortDuration: day.currentSeconds))
                    Text(day.previousDate, format: .dateTime.month().day())
                    Text(TimeFormatter.format(shortDuration: day.previousSeconds))
                }
            }
        }
        .monospacedDigit().padding(.top, 8)
    }
}
