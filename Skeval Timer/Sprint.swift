import Foundation

struct Sprint: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    // Total seconds the sprint was paused (excluded from net work duration)
    var pausedDuration: TimeInterval
    var isPaused: Bool
    var pauseStartedAt: Date?
    var pauseCount: Int

    init(id: UUID = UUID(), startTime: Date, endTime: Date? = nil, pausedDuration: TimeInterval = 0, isPaused: Bool = false, pauseStartedAt: Date? = nil, pauseCount: Int = 0) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.pausedDuration = pausedDuration
        self.isPaused = isPaused
        self.pauseStartedAt = pauseStartedAt
        self.pauseCount = pauseCount
    }

    // Backward-compat decode: old JSON has no pausedDuration key → default 0
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
        pausedDuration = (try? c.decodeIfPresent(TimeInterval.self, forKey: .pausedDuration)) ?? 0
        isPaused = (try? c.decodeIfPresent(Bool.self, forKey: .isPaused)) ?? false
        pauseStartedAt = try? c.decodeIfPresent(Date.self, forKey: .pauseStartedAt)
        pauseCount = (try? c.decodeIfPresent(Int.self, forKey: .pauseCount)) ?? 0
    }

    var isOpen: Bool { endTime == nil }

    // Net work time = wall-clock span minus paused seconds
    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return max(0, end.timeIntervalSince(startTime) - pausedDuration)
    }

    var durationLabel: String {
        TimeFormatter.format(duration: duration)
    }

    var hasPause: Bool { pausedDuration > 0 }
    var pausedLabel: String { TimeFormatter.format(duration: pausedDuration) }

    var grossDuration: TimeInterval? {
        guard let end = endTime else { return nil }
        return max(0, end.timeIntervalSince(startTime))
    }

    var grossDurationLabel: String {
        TimeFormatter.format(duration: grossDuration)
    }

    var startLabel: String { TimeFormatter.format(time: startTime) }
    var endLabel: String { endTime.map { TimeFormatter.format(time: $0) } ?? "--:--:--" }

    // Effective end = real endTime − pausedDuration
    // This ensures the spreadsheet computes (effectiveEnd − startTime) == net work duration
    var effectiveEnd: Date? {
        guard let end = endTime else { return nil }
        return end.addingTimeInterval(-pausedDuration)
    }

    var effectiveEndLabel: String {
        effectiveEnd.map { TimeFormatter.format(time: $0) } ?? "--:--:--"
    }

    var clipboardText: String {
        guard let effEnd = effectiveEnd else { return "\(startLabel)\t--:--:--" }
        return TimeFormatter.clipboardRow(start: startTime, effectiveEnd: effEnd)
    }

    static func fmt(_ date: Date) -> String {
        TimeFormatter.format(time: date)
    }
}
