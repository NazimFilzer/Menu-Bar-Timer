import Foundation

struct WeekComparisonDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let previousDate: Date
    let currentSeconds: TimeInterval
    let previousSeconds: TimeInterval
    let isEstimated: Bool
}

struct WeekComparison: Equatable {
    let days: [WeekComparisonDay]
    let isCurrentWeek: Bool
    let usesClockTime: Bool
    var currentSeconds: TimeInterval { days.reduce(0) { $0 + $1.currentSeconds } }
    var previousSeconds: TimeInterval { days.reduce(0) { $0 + $1.previousSeconds } }
    var difference: TimeInterval { currentSeconds - previousSeconds }
    var isEstimated: Bool { days.contains { $0.isEstimated } }

    static func calculate(logs: [String: [Sprint]], weekStart: Date, now: Date = Date(),
                          compareClockTime: Bool = true, liveSprint: Sprint? = nil,
                          liveElapsed: TimeInterval = 0,
                          calendar: Calendar = Calendar(identifier: .gregorian)) -> WeekComparison {
        let start = calendar.startOfDay(for: weekStart)
        let today = calendar.startOfDay(for: now)
        let elapsed = calendar.dateComponents([.day], from: start, to: today).day ?? -1
        let isCurrent = (0..<7).contains(elapsed)
        guard elapsed >= 0 else { return WeekComparison(days: [], isCurrentWeek: false, usesClockTime: false) }
        let count = min(elapsed + 1, 7)
        let days = (0..<count).compactMap { offset -> WeekComparisonDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start),
                  let previous = calendar.date(byAdding: .day, value: -7, to: date) else { return nil }
            let cut = isCurrent && offset == elapsed && compareClockTime
            let previousCut = cut ? matchingClockTime(now, on: previous, calendar: calendar) : nil
            let current = work(logs: logs, date: date, cutoff: isCurrent ? now : nil, calendar: calendar)
            let prior = work(logs: logs, date: previous, cutoff: previousCut, calendar: calendar)
            let live = liveWork(sprint: liveSprint, elapsed: liveElapsed, date: date, now: now, calendar: calendar)
            return WeekComparisonDay(date: date, previousDate: previous,
                                     currentSeconds: current.seconds + live, previousSeconds: prior.seconds,
                                     isEstimated: current.estimated || prior.estimated)
        }
        return WeekComparison(days: days, isCurrentWeek: isCurrent, usesClockTime: isCurrent && compareClockTime)
    }

    private static func matchingClockTime(_ now: Date, on date: Date, calendar: Calendar) -> Date? {
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0,
                             second: time.second ?? 0, of: date)
    }

    private static func liveWork(sprint: Sprint?, elapsed: TimeInterval, date: Date,
                                 now: Date, calendar: Calendar) -> TimeInterval {
        guard let sprint, sprint.isOpen, sprint.startTime <= now, elapsed.isFinite,
              calendar.isDate(sprint.startTime, inSameDayAs: date) else { return 0 }
        return max(0, elapsed)
    }

    private static func work(logs: [String: [Sprint]], date: Date, cutoff: Date?,
                             calendar: Calendar) -> (seconds: TimeInterval, estimated: Bool) {
        let key = TimeFormatter.format(dateKey: date, calendar: calendar)
        var seconds: TimeInterval = 0
        var estimated = false
        for sprint in logs[key] ?? [] {
            guard let net = sprint.duration, let end = sprint.endTime else { continue }
            guard let cutoff, end > cutoff else { seconds += net; continue }
            guard sprint.startTime < cutoff, let gross = sprint.grossDuration, gross > 0 else { continue }
            seconds += net * cutoff.timeIntervalSince(sprint.startTime) / gross
            estimated = estimated || sprint.hasPause
        }
        return (seconds, estimated)
    }
}
