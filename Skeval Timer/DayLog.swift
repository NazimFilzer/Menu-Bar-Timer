import Foundation

struct DayLog {
    var sprints: [Sprint]

    init(sprints: [Sprint] = []) { self.sprints = sprints }

    var completedSprints: [Sprint] { sprints.filter { !$0.isOpen } }
    var openSprint: Sprint? { sprints.first { $0.isOpen } }

    var accumulatedTotal: TimeInterval {
        completedSprints.compactMap { $0.duration }.reduce(0, +)
    }

    var accumulatedLabel: String { TimeFormatter.format(clock: accumulatedTotal) }

    var accumulatedShortLabel: String { TimeFormatter.format(shortDuration: accumulatedTotal) }
}
