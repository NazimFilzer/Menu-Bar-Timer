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
        guard start.timeIntervalSinceReferenceDate.isFinite else { throw SprintEntryError.invalidStart }
        guard end.timeIntervalSinceReferenceDate.isFinite else { throw SprintEntryError.invalidEnd }
        guard pausedDuration.isFinite, pausedDuration >= 0 else { throw SprintEntryError.invalidBreak }
        guard end > start else { throw SprintEntryError.endBeforeStart }
        guard end.timeIntervalSince(start) > pausedDuration else { throw SprintEntryError.breakExceedsSprintTime }
        self.start = start
        self.end = end
        self.pausedDuration = pausedDuration
    }

    init(date: Date, startTime: Date, endTime: Date, pausedDuration: TimeInterval,
         endDayOffset: Int? = nil, calendar: Calendar = .current) throws {
        let start = TimeFormatter.combine(date: date, time: startTime, calendar: calendar)
        let end: Date
        if let offset = endDayOffset {
            guard offset >= 0, let endDate = calendar.date(byAdding: .day, value: offset, to: date) else {
                throw SprintEntryError.invalidEnd
            }
            end = TimeFormatter.combine(date: endDate, time: endTime, calendar: calendar)
        } else {
            end = TimeFormatter.combine(date: date, time: endTime, wrapIfBefore: start, calendar: calendar)
        }
        try self.init(start: start, end: end, pausedDuration: pausedDuration)
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

/// Finds occupied wall-clock intervals across every Day Log. Pause totals do not
/// describe when a pause happened, so they cannot remove time from an interval.
func overlappingSprints(entry: SprintEntry, logs: [String: [Sprint]], excluding id: UUID? = nil,
                        now: Date = Date()) -> [Sprint] {
    logs.values.flatMap { $0 }.filter { sprint in
        let end = sprint.endTime ?? now
        return sprint.id != id && end > sprint.startTime && entry.start < end && sprint.startTime < entry.end
    }.sorted { $0.startTime < $1.startTime }
}

/// Editable values retain exact pause seconds until the user changes the pause.
struct SprintDraft {
    var selectedDate: Date
    var startTime: Date
    var endTime: Date
    var endDayOffset: Int
    var pausedDuration: TimeInterval
    var tagText: String

    var pauseMinutes: Double {
        get { pausedDuration / 60 }
        set { pausedDuration = newValue * 60 }
    }

    var entry: SprintEntry? {
        try? SprintEntry(date: selectedDate, startTime: startTime, endTime: endTime,
                         pausedDuration: pausedDuration, endDayOffset: endDayOffset)
    }

    init(date: Date, calendar: Calendar = .current) {
        selectedDate = date
        startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        endTime = calendar.date(bySettingHour: 11, minute: 30, second: 0, of: date) ?? date
        endDayOffset = 0
        pausedDuration = 0
        tagText = ""
    }

    init(sprint: Sprint, calendar: Calendar = .current) {
        selectedDate = sprint.startTime
        startTime = sprint.startTime
        endTime = sprint.endTime ?? sprint.startTime.addingTimeInterval(3600)
        endDayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: startTime),
                                               to: calendar.startOfDay(for: endTime)).day ?? 0
        pausedDuration = sprint.pausedDuration
        tagText = sprint.tag ?? ""
    }
}
