import Foundation

struct DailyBarData: Identifiable, Equatable {
    let id: String // yyyy-MM-dd
    let date: Date
    let dayOfWeekLabel: String // "Mon", "Tue", etc.
    let dateLabel: String // "Sep 4"
    let dayNumberLabel: String // "4"
    let isToday: Bool
    let totalSeconds: TimeInterval
    let totalHours: Double
    let earnings: Double
    let formattedDuration: String
    let formattedEarnings: String
    let goalProgress: Double
    let sprintCount: Int
    let completedSprints: [Sprint]
}

struct WeeklySummary: Equatable {
    let weekStartDate: Date
    let weekEndDate: Date
    let weekRangeLabel: String
    let isCurrentWeek: Bool
    let weekOffset: Int
    let days: [DailyBarData]
    let totalSeconds: TimeInterval
    let totalHours: Double
    let formattedTotalHours: String
    let weeklyGoalHours: Double
    let weeklyGoalSeconds: TimeInterval
    let weeklyGoalProgress: Double
    let weeklyGoalPercent: Int
    let totalEarnings: Double
    let formattedTotalEarnings: String
    let targetEarnings: Double
    let formattedTargetEarnings: String
    let earningsProgressLabel: String
    let dailyAverageSeconds: TimeInterval
    let dailyAverageHours: Double
    let formattedDailyAverage: String
    let elapsedDaysCount: Int

    var allWeekSprints: [Sprint] {
        days.flatMap { $0.completedSprints }.sorted(by: { $0.startTime > $1.startTime })
    }

    var allDistinctTags: [String] {
        Array(Set(allWeekSprints.compactMap { $0.tag?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }
}

enum WeeklyAnalytics {

    static func calculate(
        logs: [String: [Sprint]],
        weekOffset: Int = 0,
        referenceDate: Date = Date(),
        settings: GoalSettings = .shared,
        calendar: Calendar? = nil
    ) -> WeeklySummary {
        var cal = calendar ?? Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday start

        let targetDate = cal.date(byAdding: .weekOfYear, value: weekOffset, to: referenceDate) ?? referenceDate
        let startOfTargetDay = cal.startOfDay(for: targetDate)
        let weekday = cal.component(.weekday, from: startOfTargetDay)
        let daysFromMonday = (weekday + 5) % 7
        let mondayDate = cal.date(byAdding: .day, value: -daysFromMonday, to: startOfTargetDay) ?? startOfTargetDay
        let sundayDate = cal.date(byAdding: .day, value: 6, to: mondayDate) ?? mondayDate

        let dayBuckets = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: mondayDate) }
            .map { AnalyticsMetrics.day($0, logs: logs, referenceDate: referenceDate, settings: settings, calendar: cal) }
        let totalWeeklySeconds = dayBuckets.reduce(0) { $0 + $1.totalSeconds }
        let isCurrentWeek = dayBuckets.contains { $0.isToday }
        let elapsedDays = elapsedDayCount(days: dayBuckets, weekOffset: weekOffset)
        let dailyAvgSec = AnalyticsMetrics.average(totalSeconds: totalWeeklySeconds, days: elapsedDays)
        let dailyAvgHours = (dailyAvgSec / 3600.0 * 10).rounded() / 10.0
        let formattedAvg = TimeFormatter.format(shortDuration: dailyAvgSec)

        let totalWeeklyHours = (totalWeeklySeconds / 3600.0 * 100).rounded() / 100.0
        let formattedWeeklyHours = TimeFormatter.format(shortDuration: totalWeeklySeconds)

        let weeklyGoalSec = settings.weeklyGoalSeconds
        let weeklyGoalProg = weeklyGoalSec > 0 ? min(totalWeeklySeconds / weeklyGoalSec, 1.0) : 0.0
        let weeklyGoalPct = weeklyGoalSec > 0 ? AnalyticsMetrics.goalPercent(totalSeconds: totalWeeklySeconds, goalSeconds: weeklyGoalSec) : 0

        let totalEarn = EarningsCalculator.calculate(durationInSeconds: totalWeeklySeconds, hourlyRate: settings.hourlyRate)
        let formattedEarn = EarningsCalculator.format(amount: totalEarn, currencySymbol: settings.currencySymbol)

        let targetEarn = settings.weeklyGoalHours * settings.hourlyRate
        let formattedTargetEarn = EarningsCalculator.format(amount: targetEarn, currencySymbol: settings.currencySymbol)

        let earningsProgress = "\(formattedEarn) / \(formattedTargetEarn)"

        let rangeLabel = formatWeekRange(start: mondayDate, end: sundayDate, calendar: cal)

        return WeeklySummary(
            weekStartDate: mondayDate,
            weekEndDate: sundayDate,
            weekRangeLabel: rangeLabel,
            isCurrentWeek: isCurrentWeek,
            weekOffset: weekOffset,
            days: dayBuckets,
            totalSeconds: totalWeeklySeconds,
            totalHours: totalWeeklyHours,
            formattedTotalHours: formattedWeeklyHours,
            weeklyGoalHours: settings.weeklyGoalHours,
            weeklyGoalSeconds: weeklyGoalSec,
            weeklyGoalProgress: weeklyGoalProg,
            weeklyGoalPercent: weeklyGoalPct,
            totalEarnings: totalEarn,
            formattedTotalEarnings: formattedEarn,
            targetEarnings: targetEarn,
            formattedTargetEarnings: formattedTargetEarn,
            earningsProgressLabel: earningsProgress,
            dailyAverageSeconds: dailyAvgSec,
            dailyAverageHours: dailyAvgHours,
            formattedDailyAverage: formattedAvg,
            elapsedDaysCount: elapsedDays
        )
    }

    static func calculate(
        store: DayLogStore,
        weekOffset: Int = 0,
        referenceDate: Date = Date(),
        settings: GoalSettings = .shared,
        calendar: Calendar? = nil
    ) -> WeeklySummary {
        calculate(
            logs: store.allLogs(),
            weekOffset: weekOffset,
            referenceDate: referenceDate,
            settings: settings,
            calendar: calendar
        )
    }

    private static func elapsedDayCount(days: [DailyBarData], weekOffset: Int) -> Int {
        if let todayIndex = days.firstIndex(where: { $0.isToday }) { return todayIndex + 1 }
        return weekOffset < 0 ? 7 : 0
    }

    private static func formatWeekRange(start: Date, end: Date, calendar: Calendar) -> String {
        let startFormat = calendar.component(.year, from: start) == calendar.component(.year, from: end) ? "MMM d" : "MMM d, yyyy"
        return "\(AnalyticsMetrics.label(start, format: startFormat, calendar: calendar)) – \(AnalyticsMetrics.label(end, format: "MMM d, yyyy", calendar: calendar))"
    }
}
