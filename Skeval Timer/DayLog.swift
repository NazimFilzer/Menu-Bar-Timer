import Foundation

struct DayLog {
    var sprints: [Sprint]

    init(sprints: [Sprint] = []) { self.sprints = sprints }

    var completedSprints: [Sprint] { sprints.filter { !$0.isOpen }.sorted { $0.startTime < $1.startTime } }
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

    var clipboardText: String {
        let completed = completedSprints
        guard let login = completed.first?.startTime,
              let logout = completed.compactMap(\.endTime).max() else { return "" }
        let worked = completed.compactMap(\.duration).reduce(0, +)
        // Everything between the first login and last logout that wasn't work,
        // including pauses within sprints and gaps between sprints.
        let breakDuration = max(0, logout.timeIntervalSince(login) - worked)
        return [
            TimeFormatter.format(time: login),
            TimeFormatter.format(time: logout),
            "",
            TimeFormatter.format(breakMinutes: breakDuration)
        ].joined(separator: "\t")
    }
}
