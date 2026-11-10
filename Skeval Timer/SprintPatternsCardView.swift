import SwiftUI

/// Net sprint lengths and pauses for the selected range. Length groups with no sprints are hidden.
struct SprintPatternsCardView: View {
    let summary: SprintPatterns
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardCardHeader(title: "Sprint patterns", icon: "hourglass", theme: theme) {
                DashboardInfoButton(text: "Durations exclude paused time. Pause averages use all completed sprints. A long sprint does not prove uninterrupted work.",
                                    theme: theme, accessibilityTitle: "About sprint patterns")
            }
            if summary.count == 0 {
                Text("No completed sprints in this range.")
                    .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
            } else {
                VStack(spacing: 0) {
                    DashboardFactRow(label: "Median sprint", value: duration(summary.medianSeconds), theme: theme)
                    DashboardFactRow(label: "Mean", value: duration(summary.meanSeconds), theme: theme)
                    DashboardFactRow(label: "Longest", value: duration(summary.longestSeconds), theme: theme)
                }
                Text("LENGTH")
                    .font(.system(size: 9, weight: .bold, design: .rounded)).kerning(0.9)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 4)
                ForEach(summary.buckets.filter { $0.count > 0 }) { bucket in
                    HStack(spacing: 10) {
                        Text(bucket.label).frame(width: 90, alignment: .leading)
                        DashboardProgressBar(fraction: Double(bucket.count) / Double(summary.count),
                                             theme: theme, accessibilityTitle: bucket.label)
                        Text("\(bucket.count)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .frame(width: 34, alignment: .trailing)
                    }
                    .font(.dashboardCaption)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(bucket.label)
                    .accessibilityValue("\(bucket.count) of \(summary.count) sprints")
                }
                Divider().overlay(theme.cardBorder)
                DashboardFactRow(label: "Sprints with a pause", value: pauseRate,
                                 detail: pauseDetail, theme: theme)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private var pauseRate: String {
        (Double(summary.pausedSprintCount) / Double(max(1, summary.count)))
            .formatted(.percent.precision(.fractionLength(0)))
    }

    /// Older sprints record paused time but not how many pauses, so the count shows only when recorded.
    private var pauseDetail: String? {
        guard summary.pausedSprintCount > 0 else { return nil }
        let paused = "average \(duration(summary.meanPausedSeconds)) paused"
        guard summary.meanPauseCount > 0 else { return paused }
        return "\(paused) · \(summary.meanPauseCount.formatted(.number.precision(.fractionLength(1)))) pauses per sprint"
    }

    private func duration(_ seconds: TimeInterval) -> String { TimeFormatter.format(shortDuration: seconds) }
}
