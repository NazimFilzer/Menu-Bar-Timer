import Foundation

struct Sprint: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    // Total seconds the sprint was paused (excluded from net work duration)
    var pausedDuration: TimeInterval

    init(id: UUID = UUID(), startTime: Date, endTime: Date? = nil, pausedDuration: TimeInterval = 0) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.pausedDuration = pausedDuration
    }

    // Backward-compat decode: old JSON has no pausedDuration key → default 0
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
        pausedDuration = (try? c.decodeIfPresent(TimeInterval.self, forKey: .pausedDuration)) ?? 0
    }

    var isOpen: Bool { endTime == nil }

    // Net work time = wall-clock span minus paused seconds
    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return max(0, end.timeIntervalSince(startTime) - pausedDuration)
    }

    var durationLabel: String {
        guard let d = duration else { return "in progress" }
        let h = Int(d) / 3600
        let m = (Int(d) % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        let s = Int(d) % 60
        if m > 0 { return "\(m)m \(String(format: "%02d", s))s" }
        return "\(s)s"
    }

    var startLabel: String { Sprint.fmt(startTime) }
    var endLabel: String { endTime.map { Sprint.fmt($0) } ?? "--:--:--" }
    var clipboardText: String { "\(startLabel)\t\(endLabel)" }

    static func fmt(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}
