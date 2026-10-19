import Foundation

enum CatchUpPeriod: String {
    case week, month

    var label: String { self == .week ? "This week" : "This month" }

    func dates(containing date: Date, calendar: Calendar) -> [Date] {
        if self == .month { return AnalyticsMetrics.monthDates(containing: date, calendar: calendar) }
        let today = calendar.startOfDay(for: date)
        let daysFromMonday = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }
}

struct CatchUpSummary: Equatable {
    let period: CatchUpPeriod
    let workingDaysElapsed: Int
    let expectedSeconds: TimeInterval
    let clockedSeconds: TimeInterval

    var remainingSeconds: TimeInterval { max(0, expectedSeconds - clockedSeconds) }
    var aheadSeconds: TimeInterval { max(0, clockedSeconds - expectedSeconds) }
    var isBehind: Bool { remainingSeconds > 0 }
    var expectedLabel: String { Self.durationLabel(expectedSeconds) }
    var clockedLabel: String { Self.durationLabel(clockedSeconds) }

    var headline: String {
        if isBehind { return "\(Self.durationLabel(remainingSeconds)) left to catch up today" }
        if aheadSeconds > 0 { return "\(Self.durationLabel(aheadSeconds)) ahead" }
        if workingDaysElapsed == 0 { return "No work target yet" }
        return "On track"
    }

    var compactLabel: String {
        if isBehind { return "\(Self.durationLabel(remainingSeconds)) to catch up" }
        return headline
    }

    private static func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 && minutes.isMultiple(of: 60) { return "\(minutes / 60)h" }
        return TimeFormatter.format(shortDuration: seconds)
    }
}

/// Targets include today's full daily goal. Work on days off still counts toward catching up.
enum CatchUpAnalytics {
    static func calculate(
        logs: [String: [Sprint]], period: CatchUpPeriod, referenceDate: Date = Date(),
        settings: GoalSettings, liveSprint: Sprint? = nil, liveElapsed: TimeInterval = 0,
        calendar: Calendar = .current
    ) -> CatchUpSummary {
        let today = calendar.startOfDay(for: referenceDate)
        let dates = period.dates(containing: referenceDate, calendar: calendar).filter { $0 <= today }
        let keys = Set(dates.map { TimeFormatter.format(dateKey: $0, calendar: calendar) })
        let workingDays = dates.filter { settings.isWorkingDay($0, calendar: calendar) }.count
        let completedSeconds = keys.reduce(0.0) {
            $0 + DayLog(sprints: logs[$1] ?? []).accumulatedTotal
        }
        let activeSeconds = activeDuration(sprint: liveSprint, elapsed: liveElapsed, keys: keys, calendar: calendar)
        return CatchUpSummary(period: period, workingDaysElapsed: workingDays,
                              expectedSeconds: Double(workingDays) * settings.dailyGoalSeconds,
                              clockedSeconds: completedSeconds + activeSeconds)
    }

    private static func activeDuration(sprint: Sprint?, elapsed: TimeInterval,
                                       keys: Set<String>, calendar: Calendar) -> TimeInterval {
        guard let sprint, sprint.isOpen,
              keys.contains(TimeFormatter.format(dateKey: sprint.startTime, calendar: calendar)),
              elapsed.isFinite else { return 0 }
        return max(0, elapsed)
    }
}
