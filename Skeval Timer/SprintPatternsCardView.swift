import SwiftUI

struct SprintPatternsCardView: View {
    let summary: SprintPatterns
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sprint patterns").font(.headline)
            Text("\(summary.count) completed sprints in the selected period")
                .font(.caption).foregroundStyle(theme.textSecondary)
            if summary.count == 0 {
                Text("Record a completed sprint to see its duration and pause patterns.")
                    .font(.subheadline)
            } else {
                HStack(spacing: 30) {
                    metric("Median net sprint", seconds: summary.medianSeconds)
                    metric("Mean", seconds: summary.meanSeconds)
                    metric("Longest", seconds: summary.longestSeconds)
                }
                ForEach(summary.buckets) { bucket in
                    HStack(spacing: 12) {
                        Text(bucket.label).frame(width: 90, alignment: .leading)
                        ProgressView(value: Double(bucket.count), total: Double(summary.count))
                            .tint(theme.neonTeal)
                            .accessibilityLabel(bucket.label)
                            .accessibilityValue("\(bucket.count) of \(summary.count) sprints")
                        Text("\(bucket.count)").monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                    .font(.caption)
                }
                Text("\(pauseRate) had a pause · Mean paused time: \(TimeFormatter.format(shortDuration: summary.meanPausedSeconds)) · \(summary.meanPauseCount.formatted(.number.precision(.fractionLength(1)))) pauses per sprint")
                    .font(.caption).monospacedDigit()
                Text("Durations exclude paused time. Pause averages use all completed sprints. A long sprint does not prove uninterrupted work.")
                    .font(.caption).foregroundStyle(theme.textSecondary)
            }
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private var pauseRate: String {
        (Double(summary.pausedSprintCount) / Double(max(1, summary.count)))
            .formatted(.percent.precision(.fractionLength(0)))
    }

    private func metric(_ title: String, seconds: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(TimeFormatter.format(shortDuration: seconds)).font(.title2.weight(.semibold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(theme.textSecondary)
        }
    }
}
