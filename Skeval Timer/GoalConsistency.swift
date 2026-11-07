import Foundation

enum GoalDayStatus: Equatable {
    case met, belowGoal, extraTime, inProgress, excluded, outsideRange
}

struct GoalConsistencyDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let seconds: TimeInterval
    let status: GoalDayStatus
    let isScheduledWorkingDay: Bool

    var countsInRate: Bool { isScheduledWorkingDay }
}

struct GoalConsistencyWeek: Identifiable, Equatable {
    var id: Date { start }
    let start: Date
    let days: [GoalConsistencyDay]
    let countedDays: Int
    var metDays: Int { days.filter { $0.status == .met }.count }
}

struct GoalConsistency: Equatable {
    let weeks: [GoalConsistencyWeek]
    var countedDays: Int { weeks.reduce(0) { $0 + $1.countedDays } }
    var metDays: Int { weeks.reduce(0) { $0 + $1.metDays } }

    static func calculate(logs: [String: [Sprint]], startDate: Date, endDate: Date,
                          settings: GoalSettings, now: Date = Date(),
                          calendar: Calendar = Calendar(identifier: .gregorian)) -> GoalConsistency {
        let start = calendar.startOfDay(for: min(startDate, endDate))
        let end = calendar.startOfDay(for: min(max(startDate, endDate), now))
        guard start <= end else { return GoalConsistency(weeks: []) }
        let offset = (calendar.component(.weekday, from: start) + 5) % 7
        var monday = calendar.date(byAdding: .day, value: -offset, to: start) ?? start
        let rangeStart = monday
        var weeks: [GoalConsistencyWeek] = []
        while monday <= end {
            let weekDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
            let days = weekDays.map { day($0, start: rangeStart, end: end, logs: logs, settings: settings, now: now, calendar: calendar) }
            // Only finished scheduled days count: today is in progress, and days after
            // the range (future days, or past the selected month) have no result yet.
            let counted = days.filter {
                $0.isScheduledWorkingDay && $0.status != .inProgress && $0.status != .outsideRange
            }.count
            weeks.append(GoalConsistencyWeek(start: monday, days: days, countedDays: counted))
            guard let next = calendar.date(byAdding: .day, value: 7, to: monday) else { break }
            monday = next
        }
        return GoalConsistency(weeks: weeks)
    }

    private static func day(_ date: Date, start: Date, end: Date, logs: [String: [Sprint]],
                            settings: GoalSettings, now: Date, calendar: Calendar) -> GoalConsistencyDay {
        let isScheduled = settings.isWorkingDay(date, calendar: calendar)
        guard date >= start, date <= end else {
            return GoalConsistencyDay(date: date, seconds: 0, status: .outsideRange, isScheduledWorkingDay: isScheduled)
        }
        let key = TimeFormatter.format(dateKey: date, calendar: calendar)
        let seconds = DayLog(sprints: logs[key] ?? []).accumulatedTotal
        let status = status(date: date, seconds: seconds, settings: settings, now: now, calendar: calendar)
        return GoalConsistencyDay(date: date, seconds: seconds, status: status, isScheduledWorkingDay: isScheduled)
    }

    private static func status(date: Date, seconds: TimeInterval, settings: GoalSettings,
                               now: Date, calendar: Calendar) -> GoalDayStatus {
        if calendar.isDate(date, inSameDayAs: now) { return .inProgress }
        let isScheduled = settings.isWorkingDay(date, calendar: calendar)
        if seconds >= settings.dailyGoalSeconds {
            return .met
        }
        if isScheduled {
            return .belowGoal
        }
        return seconds > 0 ? .extraTime : .excluded
    }
}
