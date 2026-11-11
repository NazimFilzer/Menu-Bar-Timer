import Foundation

/// The popover's one-line picture of today: sprints as blocks, the current pause, and a dashed
/// block out to the finish forecast. Positions are fractions of a window fitted to the work.
///
/// Sprints store their total paused time, not when each pause happened, so only the pause that
/// is happening now can be placed. Completed sprints draw as one block.
struct DayRibbon: Equatable {
    enum Kind: Equatable { case work, pause, forecast }

    struct Block: Equatable {
        let start: Double
        let end: Double
        let kind: Kind
    }

    struct Mark: Equatable {
        let position: Double
        let date: Date
    }

    let window: DateInterval
    let blocks: [Block]
    /// Where "now" sits, when it falls inside the window.
    let now: Double?
    let marks: [Mark]

    static let minimumSpan: TimeInterval = 4 * 3600

    static func make(sprints: [DateInterval], pauseStart: Date?, finish: Date?, now: Date,
                     day: DateInterval, calendar: Calendar = .current) -> DayRibbon {
        let inDay = sprints.compactMap { $0.intersection(with: day) }.filter { $0.duration > 0 }
        let clock = min(max(now, day.start), day.end)
        let forecastEnd = finish.map { min(max($0, clock), day.end) }

        // Fit whole hours around the work, now, and the forecast, inside today.
        let earliest = ([clock] + inDay.map(\.start)).min()!
        let latest = ([clock] + inDay.map(\.end) + [forecastEnd].compactMap { $0 }).max()!
        var start = floorHour(earliest, calendar: calendar)
        var end = ceilHour(latest, calendar: calendar)
        if end.timeIntervalSince(start) < minimumSpan {
            end = min(day.end, start.addingTimeInterval(minimumSpan))
            if end.timeIntervalSince(start) < minimumSpan {
                start = max(day.start, end.addingTimeInterval(-minimumSpan))
            }
        }
        start = max(start, day.start)
        end = min(end, day.end)
        let window = DateInterval(start: start, end: max(end, start.addingTimeInterval(60)))

        func position(_ date: Date) -> Double {
            min(1, max(0, date.timeIntervalSince(window.start) / window.duration))
        }
        var blocks = inDay.map { Block(start: position($0.start), end: position($0.end), kind: .work) }
        if let pauseStart, pauseStart < clock {
            blocks.append(Block(start: position(max(pauseStart, day.start)), end: position(clock), kind: .pause))
        }
        if let forecastEnd, forecastEnd > clock {
            blocks.append(Block(start: position(clock), end: position(forecastEnd), kind: .forecast))
        }

        // At most five hour labels: every 2, 3, 4, or 6 hours.
        let hours = window.duration / 3600
        let step = [2, 3, 4, 6].first { hours / Double($0) <= 4 } ?? 6
        var marks: [Mark] = []
        var mark = start
        while mark <= window.end {
            if calendar.component(.hour, from: mark) % step == 0 || mark == start {
                marks.append(Mark(position: position(mark), date: mark))
            }
            guard let next = calendar.date(byAdding: .hour, value: 1, to: mark) else { break }
            mark = next
        }
        // Keep labels from colliding with the first one.
        marks = marks.enumerated().filter { index, item in
            index == 0 || item.position - marks[0].position >= Double(step) / hours * 0.9
        }.map(\.element)

        let nowPosition = (window.start...window.end).contains(now) ? position(now) : nil
        return DayRibbon(window: window, blocks: blocks, now: nowPosition, marks: marks)
    }

    private static func floorHour(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .hour, for: date)?.start ?? date
    }

    private static func ceilHour(_ date: Date, calendar: Calendar) -> Date {
        let floor = floorHour(date, calendar: calendar)
        return floor == date ? date : (calendar.date(byAdding: .hour, value: 1, to: floor) ?? date)
    }
}
