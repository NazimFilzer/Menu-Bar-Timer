import Foundation

/// Read-only projections; never credits work, schedules a sprint, or changes goals.
struct FinishForecast {
    enum Status: Equatable {
        case working, startNow, resumeNow, goalReached, recovery, sleepHeld, previousDaySprint
    }

    let status: Status
    let remainingToday: TimeInterval
    let plannedBreak: TimeInterval
    let finishDate: Date?
    let finishesAfterToday: Bool
    let weeklyRemaining: TimeInterval
    let remainingWorkingDays: Int
    let includesToday: Bool
    let weeklySecondsPerDay: TimeInterval?
    let exceedsWeeklyCapacity: Bool
    let extraSecondsPerWorkingDay: TimeInterval?

    static func calculate(
        logs: [String: [Sprint]], settings: GoalSettings, state: SprintState,
        sleepHeld: Bool = false, plannedBreakMinutes: Int = 0,
        now: Date = Date(), calendar: Calendar = .current
    ) -> FinishForecast {
        let todayKey = TimeFormatter.format(dateKey: now, calendar: calendar)
        let liveSprint = state.isRunning ? state.currentSprint : nil
        let liveSeconds = state.currentElapsed.isFinite ? max(0, state.currentElapsed) : 0
        let liveToday = liveSprint.map { calendar.isDate($0.startTime, inSameDayAs: now) } == true
        let creditedToday = DayLog(sprints: logs[todayKey] ?? []).accumulatedTotal + (liveToday ? liveSeconds : 0)
        let remaining = max(0, settings.dailyGoalSeconds - creditedToday)
        let plannedBreak = Double(min(240, max(0, plannedBreakMinutes))) * 60
        let status = forecastStatus(state: state, sleepHeld: sleepHeld,
                                    remaining: remaining, liveToday: liveToday)
        let canProject = [.working, .startNow, .resumeNow].contains(status)
        let finish = canProject ? now.addingTimeInterval(remaining + plannedBreak) : nil

        let weeklyPace = PeriodPaceForecast.calculate(
            logs: logs, period: .week, settings: settings, state: state, now: now, calendar: calendar
        )
        return FinishForecast(
            status: status, remainingToday: remaining, plannedBreak: plannedBreak,
            finishDate: finish,
            finishesAfterToday: finish.map { !calendar.isDate($0, inSameDayAs: now) } ?? false,
            weeklyRemaining: weeklyPace.remainingSeconds, remainingWorkingDays: weeklyPace.remainingWorkingDays,
            includesToday: weeklyPace.includesToday, weeklySecondsPerDay: weeklyPace.secondsPerWorkingDay,
            exceedsWeeklyCapacity: weeklyPace.exceedsCapacity,
            extraSecondsPerWorkingDay: weeklyPace.extraSecondsPerWorkingDay
        )
    }

    private static func forecastStatus(state: SprintState, sleepHeld: Bool,
                                       remaining: TimeInterval, liveToday: Bool) -> Status {
        if state.isRecovery { return .recovery }
        if sleepHeld { return .sleepHeld }
        if remaining == 0 { return .goalReached }
        return workStatus(state: state, liveToday: liveToday)
    }

    private static func workStatus(state: SprintState, liveToday: Bool) -> Status {
        if state.isRunning && !liveToday { return .previousDaySprint }
        if state.isPaused { return .resumeNow }
        return state.isRunning ? .working : .startNow
    }
}
