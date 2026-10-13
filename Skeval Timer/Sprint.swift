import Foundation

struct Sprint: Identifiable, Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, pausedDuration, isPaused, pauseStartedAt, pauseCount, tag
        case startTimeReferenceSeconds, endTimeReferenceSeconds, pauseStartedAtReferenceSeconds
    }
    let id: UUID
    var startTime: Date
    var endTime: Date?
    // Total seconds the sprint was paused (excluded from net work duration)
    var pausedDuration: TimeInterval
    var isPaused: Bool
    var pauseStartedAt: Date?
    var pauseCount: Int
    var tag: String?

    init(id: UUID = UUID(), startTime: Date, endTime: Date? = nil, pausedDuration: TimeInterval = 0, isPaused: Bool = false, pauseStartedAt: Date? = nil, pauseCount: Int = 0, tag: String? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.pausedDuration = Self.safePause(pausedDuration)
        self.isPaused = isPaused
        self.pauseStartedAt = pauseStartedAt
        self.pauseCount = pauseCount
        self.tag = tag
    }

    // Backward-compat decode: old JSON has no pausedDuration key → default 0
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startTime = try Self.preciseDate(c, key: .startTimeReferenceSeconds) ?? c.decode(Date.self, forKey: .startTime)
        endTime = try Self.preciseDate(c, key: .endTimeReferenceSeconds) ?? c.decodeIfPresent(Date.self, forKey: .endTime)
        pausedDuration = Self.safePause((try? c.decodeIfPresent(TimeInterval.self, forKey: .pausedDuration)) ?? 0)
        isPaused = (try? c.decodeIfPresent(Bool.self, forKey: .isPaused)) ?? false
        pauseStartedAt = Self.preciseDate(c, key: .pauseStartedAtReferenceSeconds) ?? (try? c.decodeIfPresent(Date.self, forKey: .pauseStartedAt))
        pauseCount = (try? c.decodeIfPresent(Int.self, forKey: .pauseCount)) ?? 0
        tag = try? c.decodeIfPresent(String.self, forKey: .tag)
    }

    // Keep the original date fields readable by older releases, and retain full
    // Date precision in optional fields because ISO-8601 JSON strips fractions.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(startTime, forKey: .startTime)
        try c.encodeIfPresent(endTime, forKey: .endTime)
        try c.encode(Self.safePause(pausedDuration), forKey: .pausedDuration)
        try c.encode(isPaused, forKey: .isPaused)
        try c.encodeIfPresent(pauseStartedAt, forKey: .pauseStartedAt)
        try c.encode(pauseCount, forKey: .pauseCount)
        try c.encodeIfPresent(tag, forKey: .tag)
        try c.encode(startTime.timeIntervalSinceReferenceDate, forKey: .startTimeReferenceSeconds)
        try c.encodeIfPresent(endTime?.timeIntervalSinceReferenceDate, forKey: .endTimeReferenceSeconds)
        try c.encodeIfPresent(pauseStartedAt?.timeIntervalSinceReferenceDate, forKey: .pauseStartedAtReferenceSeconds)
    }

    private static func preciseDate(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard let seconds = try? container.decode(Double.self, forKey: key), seconds.isFinite else { return nil }
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    private static func safePause(_ duration: TimeInterval) -> TimeInterval {
        duration.isFinite ? max(0, duration) : 0
    }

    var isOpen: Bool { endTime == nil }

    // Net work time = wall-clock span minus paused seconds
    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return max(0, end.timeIntervalSince(startTime) - Self.safePause(pausedDuration))
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
    var pauseStartedLabel: String { pauseStartedAt.map { TimeFormatter.format(time: $0) } ?? "--:--:--" }

    // Effective end = real endTime − pausedDuration
    // This ensures the spreadsheet computes (effectiveEnd − startTime) == net work duration
    var effectiveEnd: Date? {
        guard let end = endTime else { return nil }
        let calculated = end.addingTimeInterval(-Self.safePause(pausedDuration))
        return max(startTime, calculated)
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
