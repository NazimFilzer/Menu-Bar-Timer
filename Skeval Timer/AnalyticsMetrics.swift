import Foundation

/// Shared calendar and arithmetic rules for daily, weekly, monthly, and period reports.
enum AnalyticsMetrics {
    private static var formatters: [String: DateFormatter] = [:]
    private static let lock = NSLock()

    static func label(_ date: Date, format: String, calendar: Calendar) -> String {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(calendar.identifier)|\(calendar.timeZone.identifier)|\(format)"
        let formatter: DateFormatter
        if let cached = formatters[key] {
            formatter = cached
        } else {
            formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format
            formatters[key] = formatter
        }
        return formatter.string(from: date)
    }

    static func day(_ date: Date, logs: [String: [Sprint]], referenceDate: Date,
                    settings: GoalSettings, calendar: Calendar) -> DailyBarData {
        let key = TimeFormatter.format(dateKey: date, calendar: calendar)
        let log = DayLog(sprints: logs[key] ?? [])
        let duration = log.accumulatedTotal
        let earnings = EarningsCalculator.calculate(durationInSeconds: duration, hourlyRate: settings.hourlyRate)
        return DailyBarData(
            id: key, date: date,
            dayOfWeekLabel: label(date, format: "EEE", calendar: calendar),
            dateLabel: label(date, format: "MMM d", calendar: calendar),
            dayNumberLabel: label(date, format: "d", calendar: calendar),
            isToday: calendar.isDate(date, inSameDayAs: referenceDate),
            totalSeconds: duration, totalHours: duration / 3600,
            earnings: earnings, formattedDuration: TimeFormatter.format(shortDuration: duration),
            formattedEarnings: EarningsCalculator.format(amount: earnings, currencySymbol: settings.currencySymbol),
            goalProgress: min(duration / settings.dailyGoalSeconds, 2),
            sprintCount: log.completedSprints.count, completedSprints: log.completedSprints)
    }

    static func average(totalSeconds: TimeInterval, days: Int) -> TimeInterval {
        days > 0 ? totalSeconds / Double(days) : 0
    }

    static func goalPercent(totalSeconds: TimeInterval, goalSeconds: TimeInterval) -> Int {
        // Never announce achievement before the actual target is reached.
        guard goalSeconds > 0 else { return 0 }
        let percent = Int((totalSeconds / goalSeconds * 100).rounded())
        return totalSeconds < goalSeconds ? min(percent, 99) : percent
    }

    static func monthDates(containing date: Date, calendar: Calendar) -> [Date] {
        guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
    }
}
