import Foundation

struct DayLog {
    var sprints: [Sprint]

    init(sprints: [Sprint] = []) { self.sprints = sprints }

    var completedSprints: [Sprint] { sprints.filter { !$0.isOpen } }
    var openSprint: Sprint? { sprints.first { $0.isOpen } }

    var accumulatedTotal: TimeInterval {
        completedSprints.compactMap { $0.duration }.reduce(0, +)
    }

    var accumulatedLabel: String { formatSeconds(accumulatedTotal) }

    var accumulatedShortLabel: String {
        let t = accumulatedTotal
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "0m"
    }

    private func formatSeconds(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
