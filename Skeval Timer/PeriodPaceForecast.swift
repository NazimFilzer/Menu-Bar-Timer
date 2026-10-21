import Foundation

/// Remaining net work distributed across the period's remaining scheduled working days.
struct PeriodPaceForecast: Equatable {
    let period: CatchUpPeriod
    let targetSeconds: TimeInterval
    let clockedSeconds: TimeInterval
    let remainingWorkingDays: Int
    let includesToday: Bool
    let dailyGoalSeconds: TimeInterval
    let remainingCalendarSeconds: TimeInterval

    var remainingSeconds: TimeInterval { max(0, targetSeconds - clockedSeconds) }
    var secondsPerWorkingDay: TimeInterval? {
        guard remainingWorkingDays > 0 else { return nil }
        return remainingSeconds / Double(remainingWorkingDays)
    }
    var extraSecondsPerWorkingDay: TimeInterval? {
        secondsPerWorkingDay.map { max(0, $0 - dailyGoalSeconds) }
    }
    var exceedsCapacity: Bool { remainingSeconds > remainingCalendarSeconds }

    static func calculate(
        logs: [String: [Sprint]], period: CatchUpPeriod, settings: GoalSettings,
        state: SprintState, now: Date = Date(), calendar: Calendar = .current
    ) -> PeriodPaceForecast {
        let today = calendar.startOfDay(for: now)
        let scheduled = period.dates(containing: now, calendar: calendar).filter {
            settings.isWorkingDay($0, calendar: calendar)
        }
        let remainingDates = scheduled.filter { $0 >= today }
        let credited = CatchUpAnalytics.calculate(
            logs: logs, period: period, referenceDate: now, settings: settings,
            liveSprint: state.isRunning ? state.currentSprint : nil,
            liveElapsed: state.currentElapsed, calendar: calendar
        ).clockedSeconds
        let target = targetSeconds(for: period, settings: settings, scheduledWorkingDays: scheduled.count)
        // Calendar increments preserve 23/25-hour working days across DST.
        let capacity = remainingDates.reduce(0.0) { total, date in
            let end = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            return total + max(0, end.timeIntervalSince(max(date, now)))
        }
        return PeriodPaceForecast(
            period: period, targetSeconds: target,
            clockedSeconds: credited, remainingWorkingDays: remainingDates.count,
            includesToday: remainingDates.contains(today), dailyGoalSeconds: settings.dailyGoalSeconds,
            remainingCalendarSeconds: capacity
        )
    }

    private static func targetSeconds(for period: CatchUpPeriod, settings: GoalSettings,
                                      scheduledWorkingDays: Int) -> TimeInterval {
        switch period {
        case .day, .week:
            return Double(scheduledWorkingDays) * settings.dailyGoalSeconds
        case .month:
            return settings.monthlyGoalSeconds
        }
    }
}
