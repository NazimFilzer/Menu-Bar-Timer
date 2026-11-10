import Foundation

/// One calendar cell on the Month page.
struct MonthCalendarDay: Identifiable, Equatable {
    enum Status: Equatable {
        /// A finished day that reached the daily goal (scheduled or not).
        case met
        /// A finished scheduled working day close to the goal (at least `nearGoalShare`).
        case belowGoal
        /// A finished scheduled working day with some work, under `nearGoalShare` of the goal.
        case shortOfGoal
        /// A finished scheduled working day with no work.
        case missed
        /// A finished day off with some work. It never counts against the goal.
        case extraTime
        /// A finished day off with no work.
        case dayOff
        /// Today. Still in progress, so it is not judged yet.
        case today
        /// A day after today.
        case upcoming
    }

    var id: String { day.id }
    let day: DailyBarData
    let status: Status
    let isWorkingDay: Bool
    /// Net work as a share of the daily goal, 0...1.
    let goalFraction: Double
}

/// The Month page calendar: Monday-first weeks with `nil` for cells outside the month.
/// Only days inside the month are judged, so the leading days of the previous month never count.
struct MonthCalendar: Equatable {
    let weeks: [[MonthCalendarDay?]]
    /// Finished scheduled working days in the month (today and later are excluded).
    let finishedWorkdays: Int
    /// Finished scheduled working days that reached the daily goal.
    let metWorkdays: Int

    /// Share of the daily goal that still counts as close, for example 6h of 8h.
    static let nearGoalShare = 0.75

    static let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    /// How a day is judged against the daily goal. `date` and `today` must be start-of-day dates.
    /// The Week ledger uses the same rule, so both pages warn about the same days.
    static func status(seconds: TimeInterval, date: Date, isWorkingDay: Bool,
                       goalSeconds goal: TimeInterval, today: Date) -> MonthCalendarDay.Status {
        if date > today { return .upcoming }
        if date == today { return .today }
        if goal > 0 && seconds >= goal { return .met }
        if isWorkingDay {
            if seconds <= 0 { return .missed }
            return seconds >= goal * nearGoalShare ? .belowGoal : .shortOfGoal
        }
        return seconds > 0 ? .extraTime : .dayOff
    }

    static func make(days: [DailyBarData], settings: GoalSettings, now: Date = Date(),
                     calendar: Calendar = Calendar(identifier: .gregorian)) -> MonthCalendar {
        let today = calendar.startOfDay(for: now)
        let goal = settings.dailyGoalSeconds
        let cells = days.map { day -> MonthCalendarDay in
            let date = calendar.startOfDay(for: day.date)
            let working = settings.isWorkingDay(date, calendar: calendar)
            let status = Self.status(seconds: day.totalSeconds, date: date, isWorkingDay: working,
                                goalSeconds: goal, today: today)
            let fraction = goal > 0 ? min(1, day.totalSeconds / goal) : 0
            return MonthCalendarDay(day: day, status: status, isWorkingDay: working, goalFraction: fraction)
        }

        var weeks: [[MonthCalendarDay?]] = []
        var week: [MonthCalendarDay?] = []
        if let first = days.first {
            // Calendar weekday: 1 = Sunday … 7 = Saturday. Monday-first leading blanks.
            let lead = (calendar.component(.weekday, from: first.date) + 5) % 7
            week = Array(repeating: nil, count: lead)
        }
        for cell in cells {
            week.append(cell)
            if week.count == 7 { weeks.append(week); week = [] }
        }
        if !week.isEmpty {
            weeks.append(week + Array(repeating: nil, count: 7 - week.count))
        }

        let finished = cells.filter { $0.isWorkingDay && $0.status != .today && $0.status != .upcoming }
        return MonthCalendar(weeks: weeks, finishedWorkdays: finished.count,
                             metWorkdays: finished.filter { $0.status == .met }.count)
    }
}
