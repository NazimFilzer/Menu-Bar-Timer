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

    private static let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE"
        return f
    }()

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d"
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy"
        return f
    }()

    private static let lock = NSLock()

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

        var dayBuckets: [DailyBarData] = []
        var totalWeeklySeconds: TimeInterval = 0

        for i in 0..<7 {
            let dayDate = cal.date(byAdding: .day, value: i, to: mondayDate) ?? mondayDate
            let key = TimeFormatter.format(dateKey: dayDate)
            let sprints = logs[key] ?? []
            let dayLog = DayLog(sprints: sprints)
            let duration = dayLog.accumulatedTotal
            totalWeeklySeconds += duration

            let hours = (duration / 3600.0 * 100).rounded() / 100.0
            let earnings = EarningsCalculator.calculate(durationInSeconds: duration, hourlyRate: settings.hourlyRate)
            let formattedEarn = EarningsCalculator.format(amount: earnings, currencySymbol: settings.currencySymbol)
            let formattedDur = TimeFormatter.format(shortDuration: duration)
            let isToday = cal.isDate(dayDate, inSameDayAs: referenceDate)

            let goalSeconds = settings.dailyGoalSeconds
            let progress = goalSeconds > 0 ? min(duration / goalSeconds, 2.0) : 0.0

            lock.lock()
            let dow = dayOfWeekFormatter.string(from: dayDate)
            let mDay = monthDayFormatter.string(from: dayDate)
            let dayNum = dayNumberFormatter.string(from: dayDate)
            lock.unlock()

            let bucket = DailyBarData(
                id: key,
                date: dayDate,
                dayOfWeekLabel: dow,
                dateLabel: mDay,
                dayNumberLabel: dayNum,
                isToday: isToday,
                totalSeconds: duration,
                totalHours: hours,
                earnings: earnings,
                formattedDuration: formattedDur,
                formattedEarnings: formattedEarn,
                goalProgress: progress,
                sprintCount: dayLog.completedSprints.count,
                completedSprints: dayLog.completedSprints
            )
            dayBuckets.append(bucket)
        }

        let isCurrentWeek = dayBuckets.contains { $0.isToday }

        let elapsedDays: Int
        if isCurrentWeek {
            if let todayIdx = dayBuckets.firstIndex(where: { $0.isToday }) {
                elapsedDays = todayIdx + 1
            } else {
                elapsedDays = 7
            }
        } else if weekOffset < 0 {
            elapsedDays = 7
        } else {
            elapsedDays = 0
        }

        let dailyAvgSec: TimeInterval = elapsedDays > 0 ? (totalWeeklySeconds / Double(elapsedDays)) : 0.0
        let dailyAvgHours = (dailyAvgSec / 3600.0 * 10).rounded() / 10.0

        let formattedAvg: String
        if dailyAvgSec > 0 {
            let avgH = Int(dailyAvgSec) / 3600
            let avgM = (Int(dailyAvgSec) % 3600) / 60
            formattedAvg = avgH > 0 ? (avgM > 0 ? "\(avgH)h \(avgM)m" : "\(avgH)h") : "\(avgM)m"
        } else {
            formattedAvg = "0m"
        }

        let totalWeeklyHours = (totalWeeklySeconds / 3600.0 * 100).rounded() / 100.0
        let formattedWeeklyHours = TimeFormatter.format(shortDuration: totalWeeklySeconds)

        let weeklyGoalSec = settings.weeklyGoalSeconds
        let weeklyGoalProg = weeklyGoalSec > 0 ? min(totalWeeklySeconds / weeklyGoalSec, 1.0) : 0.0
        let weeklyGoalPct = weeklyGoalSec > 0 ? Int(round((totalWeeklySeconds / weeklyGoalSec) * 100)) : 0

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

    private static func formatWeekRange(start: Date, end: Date, calendar: Calendar) -> String {
        lock.lock()
        defer { lock.unlock() }

        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)

        let startMonthStr = monthDayFormatter.string(from: start)
        let endMonthStr = monthDayFormatter.string(from: end)
        let endYearStr = yearFormatter.string(from: end)

        if startYear != endYear {
            let startYearStr = yearFormatter.string(from: start)
            return "\(startMonthStr), \(startYearStr) – \(endMonthStr), \(endYearStr)"
        } else if startMonth != endMonth {
            return "\(startMonthStr) – \(endMonthStr), \(endYearStr)"
        } else {
            // Same month, e.g. "Sep 1 – Sep 7, 2026"
            return "\(startMonthStr) – \(endMonthStr), \(endYearStr)"
        }
    }
}
