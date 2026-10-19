import Foundation
import Observation

@Observable
final class EyeBreakSettings {
    static let shared = EyeBreakSettings()
    static let intervals = [20, 30, 45]
    private let userDefaults: UserDefaults

    var isEnabled: Bool = false {
        didSet { userDefaults.set(isEnabled, forKey: "skevalEyeBreakEnabled") }
    }
    var intervalMinutes: Int = 20 {
        didSet {
            guard Self.intervals.contains(intervalMinutes) else {
                intervalMinutes = oldValue
                return
            }
            userDefaults.set(intervalMinutes, forKey: "skevalEyeBreakIntervalMinutes")
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isEnabled = userDefaults.bool(forKey: "skevalEyeBreakEnabled")
        let stored = userDefaults.integer(forKey: "skevalEyeBreakIntervalMinutes")
        intervalMinutes = Self.intervals.contains(stored) ? stored : 20
    }
}

/// Counts only elapsed time observed during an active sprint. No background timer,
/// persisted deadlines, or catch-up notifications are needed.
struct EyeBreakReminder {
    private var baseline: TimeInterval = 0
    private var interval: TimeInterval = 0
    private var wasEnabled = false

    mutating func restart(at elapsed: TimeInterval, settings: EyeBreakSettings) {
        baseline = elapsed
        interval = TimeInterval(settings.intervalMinutes * 60)
        wasEnabled = settings.isEnabled
    }

    mutating func isDue(at elapsed: TimeInterval, settings: EyeBreakSettings) -> Bool {
        let configuredInterval = TimeInterval(settings.intervalMinutes * 60)
        guard settings.isEnabled, wasEnabled, interval == configuredInterval,
              elapsed >= baseline else {
            restart(at: elapsed, settings: settings)
            return false
        }
        guard elapsed - baseline >= interval else { return false }
        // Start the next interval now instead of emitting missed reminders in a burst.
        baseline = elapsed
        return true
    }
}
