import Foundation

struct SleepInterval: Equatable, Codable {
    let sleepStartedAt: Date
    let wakeAt: Date

    init(sleepStartedAt: Date, wakeAt: Date) {
        self.sleepStartedAt = sleepStartedAt
        self.wakeAt = max(sleepStartedAt, wakeAt)
    }

    var duration: TimeInterval {
        max(0, wakeAt.timeIntervalSince(sleepStartedAt))
    }

    var formattedWindow: String {
        "\(TimeFormatter.format(time: sleepStartedAt)) – \(TimeFormatter.format(time: wakeAt))"
    }

    var formattedDuration: String {
        TimeFormatter.format(duration: duration)
    }
}
