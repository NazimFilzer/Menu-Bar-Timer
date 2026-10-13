import Foundation

enum SprintEntryError: LocalizedError, Equatable {
    case invalidStart
    case invalidEnd
    case invalidBreak
    case endBeforeStart
    case breakExceedsSprintTime

    var errorDescription: String? {
        switch self {
        case .invalidStart: return "Invalid start time (HH:mm:ss)"
        case .invalidEnd: return "Invalid end time (HH:mm:ss)"
        case .invalidBreak: return "Invalid break minutes"
        case .endBeforeStart: return "End time must be after start time"
        case .breakExceedsSprintTime: return "Break duration exceeds sprint time"
        }
    }
}

/// Validated times shared by the menu bar and dashboard sprint forms.
struct SprintEntry {
    let start: Date
    let end: Date
    let pausedDuration: TimeInterval

    var netDuration: TimeInterval { end.timeIntervalSince(start) - pausedDuration }

    init(start: Date, end: Date, pausedDuration: TimeInterval) throws {
        guard pausedDuration.isFinite, pausedDuration >= 0 else { throw SprintEntryError.invalidBreak }
        guard end > start else { throw SprintEntryError.endBeforeStart }
        guard end.timeIntervalSince(start) > pausedDuration else { throw SprintEntryError.breakExceedsSprintTime }
        self.start = start
        self.end = end
        self.pausedDuration = pausedDuration
    }

    init(date: Date, startText: String, endText: String, breakText: String) throws {
        guard let start = TimeFormatter.parseTime(startText, on: date) else { throw SprintEntryError.invalidStart }
        guard let end = TimeFormatter.parseTime(endText, on: date) else { throw SprintEntryError.invalidEnd }
        guard let minutes = Double(breakText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SprintEntryError.invalidBreak
        }
        try self.init(start: start, end: end, pausedDuration: minutes * 60)
    }
}
