import Foundation

/// The Analytics page ranges: a calendar week, month, or year, all time, or a custom range.
enum AnalyticsRangeKind: String, CaseIterable, Identifiable {
    case week, month, year, all

    var id: String { rawValue }
    var title: String { rawValue == "all" ? "All" : rawValue.capitalized }
    /// "This week", "This month", "This year". All time has no current period to return to.
    var currentTitle: String? { self == .all ? nil : "This \(rawValue)" }
}

/// One range on the Analytics page and the period it is compared with.
/// Dates are start-of-day dates; `end` is the last day in the range.
struct AnalyticsRange: Equatable {
    let kind: AnalyticsRangeKind?
    let start: Date
    let end: Date
    let label: String
    /// The period before this one, or nil for All time.
    let previousStart: Date?
    let previousEnd: Date?
    /// How the previous period is named, for example "previous month" or "2025".
    let previousName: String?

    var isCustom: Bool { kind == nil }

    func dates(calendar: Calendar) -> [Date] { Self.days(from: start, to: end, calendar: calendar) }

    func previousDates(calendar: Calendar) -> [Date] {
        guard let previousStart, let previousEnd else { return [] }
        return Self.days(from: previousStart, to: previousEnd, calendar: calendar)
    }

    /// Ranges longer than this are drawn by week, not by day.
    static let dailyBarLimit = 62
    func drawsWeeks(calendar: Calendar) -> Bool { dates(calendar: calendar).count > Self.dailyBarLimit }

    /// - Parameters:
    ///   - offset: 0 for the period containing `today`, -1 for the one before, and so on.
    ///   - earliest: The first day with a completed sprint. All time starts there.
    static func make(_ kind: AnalyticsRangeKind, offset: Int = 0, today: Date, earliest: Date?,
                     calendar: Calendar) -> AnalyticsRange {
        let day = calendar.startOfDay(for: today)
        switch kind {
        case .week:
            let monday = calendar.date(byAdding: .day, value: -((calendar.component(.weekday, from: day) + 5) % 7),
                                       to: day) ?? day
            let start = calendar.date(byAdding: .day, value: offset * 7, to: monday) ?? monday
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            let previous = calendar.date(byAdding: .day, value: -7, to: start) ?? start
            return AnalyticsRange(kind: kind, start: start, end: end, label: weekLabel(start, end, calendar: calendar),
                                  previousStart: previous, previousEnd: calendar.date(byAdding: .day, value: 6, to: previous),
                                  previousName: "previous week")
        case .month:
            let first = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? day
            let start = calendar.date(byAdding: .month, value: offset, to: first) ?? first
            let end = lastDay(of: .month, startingAt: start, calendar: calendar)
            let previous = calendar.date(byAdding: .month, value: -1, to: start) ?? start
            return AnalyticsRange(kind: kind, start: start, end: end,
                                  label: AnalyticsMetrics.label(start, format: "MMMM yyyy", calendar: calendar),
                                  previousStart: previous, previousEnd: lastDay(of: .month, startingAt: previous, calendar: calendar),
                                  previousName: "previous month")
        case .year:
            let first = calendar.date(from: calendar.dateComponents([.year], from: day)) ?? day
            let start = calendar.date(byAdding: .year, value: offset, to: first) ?? first
            let previous = calendar.date(byAdding: .year, value: -1, to: start) ?? start
            return AnalyticsRange(kind: kind, start: start, end: lastDay(of: .year, startingAt: start, calendar: calendar),
                                  label: AnalyticsMetrics.label(start, format: "yyyy", calendar: calendar),
                                  previousStart: previous, previousEnd: lastDay(of: .year, startingAt: previous, calendar: calendar),
                                  previousName: AnalyticsMetrics.label(previous, format: "yyyy", calendar: calendar))
        case .all:
            let start = min(calendar.startOfDay(for: earliest ?? day), day)
            return AnalyticsRange(kind: kind, start: start, end: day,
                                  label: "All time, since \(AnalyticsMetrics.label(start, format: "MMM d, yyyy", calendar: calendar))",
                                  previousStart: nil, previousEnd: nil, previousName: nil)
        }
    }

    /// A custom range is compared with the same number of days right before it.
    static func custom(from first: Date, to last: Date, calendar: Calendar) -> AnalyticsRange {
        let start = calendar.startOfDay(for: min(first, last))
        let end = calendar.startOfDay(for: max(first, last))
        let length = days(from: start, to: end, calendar: calendar).count
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        let previousStart = calendar.date(byAdding: .day, value: -(length - 1), to: previousEnd) ?? previousEnd
        let label = "\(AnalyticsMetrics.label(start, format: "MMM d, yyyy", calendar: calendar)) – \(AnalyticsMetrics.label(end, format: "MMM d, yyyy", calendar: calendar))"
        return AnalyticsRange(kind: nil, start: start, end: end, label: label,
                              previousStart: previousStart, previousEnd: previousEnd, previousName: "previous \(length) days")
    }

    private static func weekLabel(_ start: Date, _ end: Date, calendar: Calendar) -> String {
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        let left = AnalyticsMetrics.label(start, format: "MMM d", calendar: calendar)
        let right = AnalyticsMetrics.label(end, format: sameMonth ? "d, yyyy" : "MMM d, yyyy", calendar: calendar)
        return "\(left) – \(right)"
    }

    private static func lastDay(of component: Calendar.Component, startingAt start: Date, calendar: Calendar) -> Date {
        let next = calendar.date(byAdding: component, value: 1, to: start) ?? start
        return calendar.date(byAdding: .day, value: -1, to: next) ?? start
    }

    static func days(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var date = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while date <= last {
            result.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }
}

/// Completed-sprint totals for a run of days, the same rules as the Week and Month pages.
struct AnalyticsTotals: Equatable {
    let workedSeconds: TimeInterval
    let earnings: Double
    let daysWithWork: Int
    /// Finished scheduled workdays that reached the daily goal (the Month page rule).
    let goalMetDays: Int
    /// Scheduled workdays before today.
    let finishedWorkdays: Int
    let sprintCount: Int

    static func calculate(days: [DailyBarData], settings: GoalSettings, today: Date,
                          calendar: Calendar) -> AnalyticsTotals {
        let day = calendar.startOfDay(for: today)
        let worked = days.reduce(0) { $0 + $1.totalSeconds }
        var finished = 0
        var met = 0
        for bar in days {
            let date = calendar.startOfDay(for: bar.date)
            let working = settings.isWorkingDay(date, calendar: calendar)
            let status = MonthCalendar.status(seconds: bar.totalSeconds, date: date, isWorkingDay: working,
                                              goalSeconds: settings.dailyGoalSeconds, today: day)
            guard working, status != .today, status != .upcoming else { continue }
            finished += 1
            if status == .met { met += 1 }
        }
        return AnalyticsTotals(workedSeconds: worked,
                               earnings: EarningsCalculator.calculate(durationInSeconds: worked, hourlyRate: settings.hourlyRate),
                               daysWithWork: days.filter { $0.totalSeconds > 0 }.count,
                               goalMetDays: met, finishedWorkdays: finished,
                               sprintCount: days.reduce(0) { $0 + $1.completedSprints.count })
    }
}

/// A range's totals beside the previous period's.
struct AnalyticsComparison: Equatable {
    let current: AnalyticsTotals
    /// Nil when there is no previous period (All time) or it ends before the first recorded sprint.
    let previous: AnalyticsTotals?
    /// The range contains today, so the previous period is cut to the same number of days.
    let isPartial: Bool
    let comparedDays: Int

    /// A running range is compared with the same number of days at the start of the previous period,
    /// like the Month page. On the previous side, the day matching today counts as unfinished,
    /// so both sides judge the same number of finished days against the daily goal.
    static func calculate(range: AnalyticsRange, logs: [String: [Sprint]], earliest: Date?, today: Date,
                          settings: GoalSettings, calendar: Calendar, live: LiveWork? = nil) -> AnalyticsComparison {
        let day = calendar.startOfDay(for: today)
        let dates = range.dates(calendar: calendar)
        let current = AnalyticsTotals.calculate(days: bars(dates, logs: logs, today: day, settings: settings,
                                                           calendar: calendar, live: live),
                                                settings: settings, today: day, calendar: calendar)
        let previousDates = range.previousDates(calendar: calendar)
        guard let previousEnd = previousDates.last, let earliest,
              previousEnd >= calendar.startOfDay(for: earliest) else {
            return AnalyticsComparison(current: current, previous: nil, isPartial: false, comparedDays: dates.count)
        }
        let elapsed = dates.firstIndex(of: day).map { $0 + 1 }
        let compared = Array(previousDates.prefix(elapsed ?? previousDates.count))
        // The previous side's "today" is its last compared day, so that day is not judged as finished.
        let previousToday = elapsed == nil ? day : (compared.last ?? day)
        let previous = AnalyticsTotals.calculate(
            days: bars(compared, logs: logs, today: previousToday, settings: settings, calendar: calendar),
            settings: settings, today: previousToday, calendar: calendar)
        return AnalyticsComparison(current: current, previous: previous, isPartial: elapsed != nil,
                                   comparedDays: compared.count)
    }

    static func bars(_ dates: [Date], logs: [String: [Sprint]], today: Date, settings: GoalSettings,
                     calendar: Calendar, live: LiveWork? = nil) -> [DailyBarData] {
        dates.map { AnalyticsMetrics.day($0, logs: logs, referenceDate: today, settings: settings, calendar: calendar,
                                         live: live) }
    }
}

/// One bar of the Analytics hours chart: a day, or a Monday-first week clipped to the range.
struct AnalyticsBar: Identifiable, Equatable {
    var id: Date { start }
    let start: Date
    let end: Date
    let seconds: TimeInterval
    /// The daily goal, or for a week the daily goal times its scheduled workdays in the range.
    let goalSeconds: TimeInterval
    /// The same position in the previous period, for day bars.
    let previousSeconds: TimeInterval?
    let isDayOff: Bool
    let isUpcoming: Bool

    var metGoal: Bool { goalSeconds > 0 && seconds >= goalSeconds && !isUpcoming }

    static func make(days: [DailyBarData], previousDays: [DailyBarData]?, byWeek: Bool, settings: GoalSettings,
                     today: Date, calendar: Calendar) -> [AnalyticsBar] {
        let day = calendar.startOfDay(for: today)
        if !byWeek {
            return days.enumerated().map { index, bar in
                let date = calendar.startOfDay(for: bar.date)
                let working = settings.isWorkingDay(date, calendar: calendar)
                let previous = previousDays.flatMap { index < $0.count ? $0[index].totalSeconds : nil }
                return AnalyticsBar(start: date, end: date, seconds: bar.totalSeconds,
                                    goalSeconds: settings.dailyGoalSeconds, previousSeconds: previous,
                                    isDayOff: !working, isUpcoming: date > day)
            }
        }
        var result: [AnalyticsBar] = []
        var group: [DailyBarData] = []
        func flush() {
            guard let first = group.first, let last = group.last else { return }
            let workdays = group.filter { settings.isWorkingDay(calendar.startOfDay(for: $0.date), calendar: calendar) }.count
            result.append(AnalyticsBar(start: calendar.startOfDay(for: first.date), end: calendar.startOfDay(for: last.date),
                                       seconds: group.reduce(0) { $0 + $1.totalSeconds },
                                       goalSeconds: Double(workdays) * settings.dailyGoalSeconds, previousSeconds: nil,
                                       isDayOff: workdays == 0, isUpcoming: calendar.startOfDay(for: first.date) > day))
            group = []
        }
        for bar in days {
            if calendar.component(.weekday, from: bar.date) == 2 { flush() }
            group.append(bar)
        }
        flush()
        return result
    }
}
