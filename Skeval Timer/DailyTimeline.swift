import Foundation

struct TimelineHours: Equatable {
    let startHour: Int
    let endHour: Int

    init(startHour: Int = 6, endHour: Int = 24) {
        let valid = (0..<24).contains(startHour) && (1...24).contains(endHour) && startHour < endHour
        self.startHour = valid ? startHour : 6
        self.endHour = valid ? endHour : 24
    }
}

enum TimelineSprintStatus: String {
    case completed = "Completed"
    case active = "Active"
    case paused = "Paused"
    case sleep = "Sleep decision needed"
    case recovery = "Recovery needed"
}

struct TimelineLiveSprint {
    let sprint: Sprint
    let status: TimelineSprintStatus
    let netWork: TimeInterval?
    let paused: TimeInterval
    let unresolvedStart: Date?
}

struct TimelineSegment: Identifiable {
    var id: UUID { sprint.id }
    let sprint: Sprint
    let number: Int
    var displayName: String {
        let name = "Sprint \(number)"
        guard let tag = sprint.tag?.trimmingCharacters(in: .whitespacesAndNewlines), !tag.isEmpty else { return name }
        return "\(name) · \(tag)"
    }
    let interval: DateInterval
    let status: TimelineSprintStatus
    // Whole sprint values. A continuation never changes daily attribution.
    let netWork: TimeInterval?
    let paused: TimeInterval
    let continuesBefore: Bool
    let continuesAfter: Bool
    let unresolvedStart: Date?
    var column = 0
    var columnCount = 1
    /// The running sprint, active or paused. Its span grows until now.
    var isLive: Bool { status == .active || status == .paused }
}

struct DailyTimeline {
    let day: DateInterval
    let visible: DateInterval
    let segments: [TimelineSegment]
    let gaps: [DateInterval]
    let hourMarks: [Date]

    /// - Parameter fitsToWork: Draw only the hours with work: an hour before the first sprint to
    ///   two hours after now (a past day: an hour after the last sprint), at least four hours.
    ///   `hours` then sets the outer limits. Every sprint stays visible either way.
    static func calculate(sprints: [Sprint], live: TimelineLiveSprint? = nil, date: Date,
                          hours: TimelineHours = TimelineHours(), fitsToWork: Bool = false,
                          now: Date = Date(), calendar: Calendar = .current) -> DailyTimeline {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let day = DateInterval(start: start, end: end)
        var records = sprints.filter { !$0.isOpen && $0.id != live?.sprint.id }
        if let live { records.append(live.sprint) }
        records.sort { ($0.startTime, $0.id.uuidString) < ($1.startTime, $1.id.uuidString) }
        var dailyCounts: [Date: Int] = [:]
        let segments = records.compactMap { sprint -> TimelineSegment? in
            let startDay = calendar.startOfDay(for: sprint.startTime)
            dailyCounts[startDay, default: 0] += 1
            return segment(sprint, number: dailyCounts[startDay]!, live: live, day: day, now: now)
        }
        .sorted { ($0.interval.start, $0.id.uuidString) < ($1.interval.start, $1.id.uuidString) }
        let visible = fitsToWork
            ? fittedInterval(day: day, hours: hours, segments: segments, now: now, calendar: calendar)
            : visibleInterval(day: day, hours: hours, segments: segments, calendar: calendar)
        return DailyTimeline(day: day, visible: visible, segments: assignColumns(segments),
                             gaps: untrackedIntervals(segments, start: visible.start, end: min(now, visible.end)),
                             hourMarks: marks(in: visible, calendar: calendar))
    }

    private static func segment(_ sprint: Sprint, number: Int, live: TimelineLiveSprint?, day: DateInterval,
                                now: Date) -> TimelineSegment? {
        let current = live.flatMap { $0.sprint.id == sprint.id ? $0 : nil }
        let actualEnd = sprint.endTime ?? now
        let start = max(sprint.startTime, day.start)
        let end = min(actualEnd, day.end)
        guard start < end else { return nil }
        return TimelineSegment(sprint: sprint, number: number, interval: DateInterval(start: start, end: end),
                               status: current?.status ?? .completed,
                               netWork: current == nil ? sprint.duration : current?.netWork,
                               paused: current?.paused ?? sprint.pausedDuration,
                               continuesBefore: sprint.startTime < day.start,
                               continuesAfter: actualEnd > day.end,
                               unresolvedStart: current?.unresolvedStart)
    }

    private static func boundary(hour: Int, day: DateInterval, calendar: Calendar) -> Date {
        if hour == 24 { return day.end }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day.start) ?? day.start
    }

    private static func visibleInterval(day: DateInterval, hours: TimelineHours,
                                        segments: [TimelineSegment], calendar: Calendar) -> DateInterval {
        var start = boundary(hour: hours.startHour, day: day, calendar: calendar)
        var end = boundary(hour: hours.endHour, day: day, calendar: calendar)
        for segment in segments {
            let firstHour = calendar.dateInterval(of: .hour, for: segment.interval.start)!
            start = min(start, firstHour.start)
            let lastHour = calendar.dateInterval(of: .hour, for: segment.interval.end)!
            let roundedEnd = segment.interval.end == lastHour.start ? lastHour.start : lastHour.end
            end = max(end, roundedEnd)
        }
        return DateInterval(start: max(day.start, start), end: min(day.end, end))
    }

    static let fittedMinimumHours = 4

    private static func fittedInterval(day: DateInterval, hours: TimelineHours, segments: [TimelineSegment],
                                       now: Date, calendar: Calendar) -> DateInterval {
        let limits = visibleInterval(day: day, hours: hours, segments: segments, calendar: calendar)
        let isToday = day.contains(now)
        var starts = segments.map(\.interval.start)
        var ends = segments.map(\.interval.end)
        if isToday { starts.append(now); ends.append(now) }
        guard let first = starts.min(), let last = ends.max() else {
            // A past day with no sprints: the first hours of the visible range.
            let end = calendar.date(byAdding: .hour, value: fittedMinimumHours, to: limits.start) ?? limits.end
            return DateInterval(start: limits.start, end: min(limits.end, end))
        }
        let firstHour = calendar.dateInterval(of: .hour, for: first)!.start
        let lastHourInterval = calendar.dateInterval(of: .hour, for: last)!
        let lastHour = last == lastHourInterval.start ? last : lastHourInterval.end
        var start = calendar.date(byAdding: .hour, value: -1, to: firstHour) ?? firstHour
        var end = calendar.date(byAdding: .hour, value: isToday ? 2 : 1, to: lastHour) ?? lastHour
        start = max(start, limits.start)
        end = min(end, limits.end)
        // Keep a readable minimum: grow later first, then earlier.
        let minimum = TimeInterval(fittedMinimumHours * 3600)
        if end.timeIntervalSince(start) < minimum {
            end = min(limits.end, start.addingTimeInterval(minimum))
            start = max(limits.start, end.addingTimeInterval(-minimum))
        }
        return DateInterval(start: start, end: end)
    }

    private static func marks(in interval: DateInterval, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var date = interval.start
        while date <= interval.end {
            result.append(date)
            date = calendar.date(byAdding: .hour, value: 1, to: date)!
        }
        return result
    }

    private static func untrackedIntervals(_ segments: [TimelineSegment], start: Date, end: Date) -> [DateInterval] {
        guard start < end else { return [] }
        var cursor = start
        var gaps: [DateInterval] = []
        for segment in segments where segment.interval.start < end {
            let next = min(end, segment.interval.start)
            if cursor < next { gaps.append(DateInterval(start: cursor, end: next)) }
            cursor = max(cursor, segment.interval.end)
        }
        if cursor < end { gaps.append(DateInterval(start: cursor, end: end)) }
        return gaps
    }

    static func assignColumns(_ input: [TimelineSegment],
                              occupiedUntil: (TimelineSegment) -> Date = { $0.interval.end }) -> [TimelineSegment] {
        var result = input
        var group: [Int] = []
        var groupEnd = Date.distantPast
        for index in result.indices {
            if result[index].interval.start >= groupEnd {
                finishGroup(group, in: &result)
                group = []
            }
            let occupied = Set(group.filter { occupiedUntil(result[$0]) > result[index].interval.start }
                .map { result[$0].column })
            var column = 0
            while occupied.contains(column) { column += 1 }
            result[index].column = column
            group.append(index)
            groupEnd = max(groupEnd, occupiedUntil(result[index]))
        }
        finishGroup(group, in: &result)
        return result
    }

    private static func finishGroup(_ group: [Int], in segments: inout [TimelineSegment]) {
        let count = (group.map { segments[$0].column }.max() ?? 0) + 1
        for index in group { segments[index].columnCount = count }
    }
}
