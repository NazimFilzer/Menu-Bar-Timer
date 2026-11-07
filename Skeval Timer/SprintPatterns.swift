import Foundation

struct SprintDurationBucket: Identifiable, Equatable {
    var id: Int { lowerMinutes }
    let lowerMinutes: Int
    let upperMinutes: Int?
    let label: String
    let count: Int
}

struct SprintPatterns: Equatable {
    let count: Int
    let medianSeconds: TimeInterval
    let meanSeconds: TimeInterval
    let longestSeconds: TimeInterval
    let pausedSprintCount: Int
    let meanPausedSeconds: TimeInterval
    let meanPauseCount: Double
    let buckets: [SprintDurationBucket]

    static func calculate(sprints: [Sprint]) -> SprintPatterns {
        let completed = sprints.filter { !$0.isOpen }
        let durations = completed.compactMap(\.duration).sorted()
        let count = durations.count
        let total = durations.reduce(0, +)
        let median: TimeInterval
        if count == 0 {
            median = 0
        } else if count.isMultiple(of: 2) {
            median = (durations[count / 2 - 1] + durations[count / 2]) / 2
        } else {
            median = durations[count / 2]
        }
        let bounds = [0, 15, 30, 45, 60, 90]
        let labels = ["Under 15m", "15 to <30m", "30 to <45m", "45 to <60m", "60 to <90m", "90m or more"]
        let buckets = bounds.indices.map { index in
            let lower = bounds[index]
            let upper = index + 1 < bounds.count ? bounds[index + 1] : nil
            let upperSeconds = upper.map { Double($0 * 60) } ?? .infinity
            let matches = durations.filter { $0 >= Double(lower * 60) && $0 < upperSeconds }
            return SprintDurationBucket(lowerMinutes: lower, upperMinutes: upper, label: labels[index], count: matches.count)
        }
        return SprintPatterns(count: count, medianSeconds: median,
                              meanSeconds: AnalyticsMetrics.average(totalSeconds: total, days: count),
                              longestSeconds: durations.last ?? 0,
                              pausedSprintCount: completed.filter { $0.hasPause || $0.pauseCount > 0 }.count,
                              meanPausedSeconds: AnalyticsMetrics.average(totalSeconds: completed.reduce(0) { $0 + $1.pausedDuration }, days: count),
                              meanPauseCount: AnalyticsMetrics.average(totalSeconds: completed.reduce(0) { $0 + Double(max(0, $1.pauseCount)) }, days: count),
                              buckets: buckets)
    }
}
