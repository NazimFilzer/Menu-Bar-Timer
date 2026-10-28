import Foundation

/// The spreadsheet summary of a day's completed sprints.
struct DailyTimesheet {
    let login: Date
    let logout: Date
    let breakDuration: TimeInterval

    init?(log: DayLog) {
        let completed = log.completedSprints
        guard let login = completed.first?.startTime,
              let logout = completed.compactMap(\.endTime).max() else { return nil }
        self.login = login
        self.logout = logout
        let worked = completed.compactMap(\.duration).reduce(0, +)
        // Includes pauses within sprints and gaps between sprints.
        self.breakDuration = max(0, logout.timeIntervalSince(login) - worked)
    }

    var clipboardText: String {
        [TimeFormatter.format(time: login), TimeFormatter.format(time: logout), "",
         TimeFormatter.format(breakMinutes: breakDuration)].joined(separator: "\t")
    }

    static func clipboardText(days: [DailyBarData]) -> String {
        guard days.contains(where: { !$0.completedSprints.isEmpty }) else { return "" }
        return days.sorted { $0.date < $1.date }.map { day in
            DailyTimesheet(log: DayLog(sprints: day.completedSprints))?.clipboardText ?? "\t\t\t"
        }.joined(separator: "\n")
    }
}
