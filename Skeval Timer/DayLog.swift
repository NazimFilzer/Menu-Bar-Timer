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

    var totalPausedDuration: TimeInterval {
        completedSprints.map(\.pausedDuration).reduce(0, +)
    }

    var totalPausedLabel: String { TimeFormatter.format(shortDuration: totalPausedDuration) }

    var completedSprintsDescending: [(index: Int, sprint: Sprint)] {
        completedSprints.enumerated().map { ($0.offset + 1, $0.element) }.reversed()
    }
}
