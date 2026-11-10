import Foundation

/// Pace for one Monday-first week against the Weekly Goal setting: work so far, where the
/// schedule expects you by today, and what each remaining scheduled workday needs.
/// The goal is spread evenly over the week's scheduled workdays; days off are excluded.
struct WeekPace: Equatable {
    enum Status: Equatable {
        case behind(TimeInterval)
        case ahead(TimeInterval)
        case onSchedule
        case reached
        case missed(TimeInterval)
        case met
    }

    let isCurrentWeek: Bool
    /// The Weekly Goal setting.
    let targetSeconds: TimeInterval
    let scheduledWorkingDays: Int
    /// Completed net work plus the active sprint when it started this week.
    let workedSeconds: TimeInterval
    /// Today's part of `workedSeconds`. Zero for past weeks.
    let workedTodaySeconds: TimeInterval
    /// Current week: the goal's share for scheduled workdays through today. Past week: the whole goal.
    let expectedSeconds: TimeInterval
    let workingDaysElapsed: Int
    let remainingWorkingDays: Int
    let includesToday: Bool
    let dailyGoalSeconds: TimeInterval
    let exceedsCapacity: Bool

    var remainingSeconds: TimeInterval { max(0, targetSeconds - workedSeconds) }

    /// Total net work each remaining scheduled workday needs. Today counts its work so far,
    /// so every remaining day, today included, gets the same total. When today already passed
    /// that share, the rest is spread over the later days. Nil for past weeks, a reached goal,
    /// or when no scheduled workdays remain.
    var neededPerWorkingDay: TimeInterval? {
        guard isCurrentWeek, remainingSeconds > 0, remainingWorkingDays > 0 else { return nil }
        guard includesToday else { return remainingSeconds / Double(remainingWorkingDays) }
        let even = (remainingSeconds + workedTodaySeconds) / Double(remainingWorkingDays)
        if workedTodaySeconds <= even || remainingWorkingDays == 1 { return even }
        return remainingSeconds / Double(remainingWorkingDays - 1)
    }

    /// What today still needs on top of today's work so far. Nil when today is not scheduled.
    var neededMoreToday: TimeInterval? {
        guard includesToday, let needed = neededPerWorkingDay else { return nil }
        return max(0, needed - workedTodaySeconds)
    }

    /// Needed pace minus the daily goal: positive means longer days than usual.
    var neededVersusGoal: TimeInterval? { neededPerWorkingDay.map { $0 - dailyGoalSeconds } }

    /// Work so far divided by the scheduled workdays so far.
    /// The weekly goal spread evenly over the scheduled workdays.
    var plannedPerWorkingDay: TimeInterval? {
        scheduledWorkingDays > 0 ? targetSeconds / Double(scheduledWorkingDays) : nil
    }

    var paceSoFar: TimeInterval? {
        workingDaysElapsed > 0 ? workedSeconds / Double(workingDaysElapsed) : nil
    }

    var status: Status {
        if isCurrentWeek {
            if workedSeconds >= targetSeconds { return .reached }
            // Under a minute either way reads as on schedule, never "0m behind".
            let difference = workedSeconds - expectedSeconds
            if difference <= -60 { return .behind(-difference) }
            return difference >= 60 ? .ahead(difference) : .onSchedule
        }
        return workedSeconds >= targetSeconds ? .met : .missed(targetSeconds - workedSeconds)
    }

    /// The pace in words, shared by the Week page and Today's week pace badge.
    var statusLabel: String {
        let duration = { (seconds: TimeInterval) in TimeFormatter.format(shortDuration: seconds) }
        return switch status {
        case .behind(let s): "\(duration(s)) behind schedule"
        case .ahead(let s): "\(duration(s)) ahead of schedule"
        case .onSchedule: "On schedule"
        case .reached: "Weekly goal reached"
        case .missed(let s): "Missed by \(duration(s))"
        case .met: "Weekly goal met"
        }
    }

    static func calculate(
        logs: [String: [Sprint]], weekStart: Date, settings: GoalSettings,
        state: SprintState, now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> WeekPace {
        let dates = CatchUpPeriod.week.dates(containing: weekStart, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let scheduled = dates.filter { settings.isWorkingDay($0, calendar: calendar) }
        let target = settings.weeklyGoalSeconds
        // Future-dated work in the current week does not count yet, as in the catch-up target.
        let counted = dates.contains(today) ? dates.filter { $0 <= today } : dates
        let keys = Set(counted.map { TimeFormatter.format(dateKey: $0, calendar: calendar) })
        let completed = keys.reduce(0.0) { $0 + DayLog(sprints: logs[$1] ?? []).accumulatedTotal }
        let live = liveWork(state: state, keys: keys, calendar: calendar)
        let worked = completed + live
        let todayKey = TimeFormatter.format(dateKey: today, calendar: calendar)
        let liveToday = state.currentSprint.map { calendar.isDate($0.startTime, inSameDayAs: today) } == true ? live : 0
        let workedToday = DayLog(sprints: logs[todayKey] ?? []).accumulatedTotal + liveToday

        guard dates.contains(today) else {
            return WeekPace(
                isCurrentWeek: false, targetSeconds: target, scheduledWorkingDays: scheduled.count,
                workedSeconds: worked, workedTodaySeconds: 0, expectedSeconds: target, workingDaysElapsed: scheduled.count,
                remainingWorkingDays: 0, includesToday: false,
                dailyGoalSeconds: settings.dailyGoalSeconds, exceedsCapacity: false
            )
        }

        let elapsed = scheduled.filter { $0 <= today }.count
        let remaining = scheduled.filter { $0 >= today }
        let share = scheduled.isEmpty ? 0 : target / Double(scheduled.count)
        // Capacity per remaining workday: the daily goal, or less when little of the day is left.
        let capacity = remaining.reduce(0.0) { total, date in
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            return total + min(settings.dailyGoalSeconds, max(0, dayEnd.timeIntervalSince(max(date, now))))
        }
        return WeekPace(
            isCurrentWeek: true, targetSeconds: target, scheduledWorkingDays: scheduled.count,
            workedSeconds: worked, workedTodaySeconds: workedToday, expectedSeconds: share * Double(elapsed), workingDaysElapsed: elapsed,
            remainingWorkingDays: remaining.count, includesToday: remaining.contains(today),
            dailyGoalSeconds: settings.dailyGoalSeconds, exceedsCapacity: max(0, target - worked) > capacity
        )
    }

    /// An open sprint belongs to the day it started, even after midnight on Sunday.
    private static func liveWork(state: SprintState, keys: Set<String>, calendar: Calendar) -> TimeInterval {
        guard state.isRunning, let sprint = state.currentSprint, sprint.isOpen,
              keys.contains(TimeFormatter.format(dateKey: sprint.startTime, calendar: calendar)),
              state.currentElapsed.isFinite else { return 0 }
        return max(0, state.currentElapsed)
    }
}
