import Foundation

struct TagAttribution: Identifiable, Equatable {
    var id: String { displayName }
    let tag: String?
    let displayName: String
    let totalSeconds: TimeInterval
    let totalHours: Double
    let earnings: Double
    let percentage: Double
    let formattedDuration: String
    let formattedEarnings: String
    let sprintCount: Int
}

struct MonthOverMonthComparison: Equatable {
    let currentSeconds: TimeInterval
    let priorSeconds: TimeInterval
    let hoursDifference: Double
    let formattedHoursDifference: String
    let percentageChange: Double
    let formattedPercentageChange: String
    let earningsDifference: Double
    let formattedEarningsDifference: String
    let isPositive: Bool
    let isNeutral: Bool
    let summaryText: String
}

struct MonthlySummary: Equatable {
    let monthStartDate: Date
    let monthEndDate: Date
    let monthTitle: String
    let monthOffset: Int
    let isCurrentMonth: Bool
    let days: [DailyBarData]
    let totalSeconds: TimeInterval
    let totalHours: Double
    let formattedTotalHours: String
    let monthlyGoalHours: Double
    let monthlyGoalSeconds: TimeInterval
    let monthlyGoalProgress: Double
    let monthlyGoalPercent: Int
    let totalEarnings: Double
    let formattedTotalEarnings: String
    let targetEarnings: Double
    let formattedTargetEarnings: String
    let earningsProgressLabel: String
    let dailyAverageSeconds: TimeInterval
    let dailyAverageHours: Double
    let formattedDailyAverage: String
    let elapsedDaysCount: Int
    let tagBreakdowns: [TagAttribution]
    let monthOverMonth: MonthOverMonthComparison

    var allMonthSprints: [Sprint] {
        days.flatMap { $0.completedSprints }.sorted(by: { $0.startTime > $1.startTime })
    }

    var allDistinctTags: [String] {
        Array(Set(allMonthSprints.compactMap { $0.tag?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }
}

enum MonthlyAnalytics {

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

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

    private static let lock = NSLock()

    static func calculate(
        logs: [String: [Sprint]],
        monthOffset: Int = 0,
        referenceDate: Date = Date(),
        settings: GoalSettings = .shared,
        calendar: Calendar? = nil
    ) -> MonthlySummary {
        var cal = calendar ?? Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday start

        let targetDate = cal.date(byAdding: .month, value: monthOffset, to: referenceDate) ?? referenceDate
        let targetComps = cal.dateComponents([.year, .month], from: targetDate)
        guard let firstOfMonth = cal.date(from: targetComps) else {
            fatalError("Could not calculate first day of month for \(targetDate)")
        }

        guard let daysRange = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            fatalError("Could not calculate days in month for \(firstOfMonth)")
        }
        let totalDaysInMonth = daysRange.count
        let lastDayOfMonth = cal.date(byAdding: .day, value: totalDaysInMonth - 1, to: firstOfMonth) ?? firstOfMonth

        lock.lock()
        let monthTitle = monthYearFormatter.string(from: firstOfMonth)
        lock.unlock()

        let currentComps = cal.dateComponents([.year, .month], from: referenceDate)
        let isCurrentMonth = (targetComps.year == currentComps.year && targetComps.month == currentComps.month)

        var dayBuckets: [DailyBarData] = []
        var totalMonthlySeconds: TimeInterval = 0
        var allCompletedSprintsInMonth: [Sprint] = []

        for day in 1...totalDaysInMonth {
            guard let dayDate = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { continue }
            let key = TimeFormatter.format(dateKey: dayDate)
            let sprints = logs[key] ?? []
            let dayLog = DayLog(sprints: sprints)
            let duration = dayLog.accumulatedTotal
            totalMonthlySeconds += duration
            allCompletedSprintsInMonth.append(contentsOf: dayLog.completedSprints)

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

        let elapsedDays: Int
        if isCurrentMonth {
            let refDay = cal.component(.day, from: referenceDate)
            elapsedDays = max(1, min(refDay, totalDaysInMonth))
        } else if monthOffset < 0 {
            elapsedDays = totalDaysInMonth
        } else {
            elapsedDays = 0
        }

        let dailyAvgSec: TimeInterval = elapsedDays > 0 ? (totalMonthlySeconds / Double(elapsedDays)) : 0.0
        let dailyAvgHours = (dailyAvgSec / 3600.0 * 10).rounded() / 10.0

        let formattedAvg: String
        if dailyAvgSec > 0 {
            let avgH = Int(dailyAvgSec) / 3600
            let avgM = (Int(dailyAvgSec) % 3600) / 60
            formattedAvg = avgH > 0 ? (avgM > 0 ? "\(avgH)h \(avgM)m" : "\(avgH)h") : "\(avgM)m"
        } else {
            formattedAvg = "0m"
        }

        let totalMonthlyHours = (totalMonthlySeconds / 3600.0 * 100).rounded() / 100.0
        let formattedMonthlyHours = TimeFormatter.format(shortDuration: totalMonthlySeconds)

        let monthlyGoalSec = settings.monthlyGoalSeconds
        let monthlyGoalProg = monthlyGoalSec > 0 ? min(totalMonthlySeconds / monthlyGoalSec, 1.0) : 0.0
        let monthlyGoalPct = monthlyGoalSec > 0 ? Int(round((totalMonthlySeconds / monthlyGoalSec) * 100)) : 0

        let totalEarn = EarningsCalculator.calculate(durationInSeconds: totalMonthlySeconds, hourlyRate: settings.hourlyRate)
        let formattedEarn = EarningsCalculator.format(amount: totalEarn, currencySymbol: settings.currencySymbol)

        let targetEarn = settings.monthlyGoalHours * settings.hourlyRate
        let formattedTargetEarn = EarningsCalculator.format(amount: targetEarn, currencySymbol: settings.currencySymbol)
        let earningsProgress = "\(formattedEarn) / \(formattedTargetEarn)"

        // Tag attribution breakdown
        let tagBreakdowns = calculateTagBreakdown(sprints: allCompletedSprintsInMonth, totalSeconds: totalMonthlySeconds, hourlyRate: settings.hourlyRate, currencySymbol: settings.currencySymbol)

        // Month-over-month comparison
        let priorMonthOffset = monthOffset - 1
        let priorDate = cal.date(byAdding: .month, value: priorMonthOffset, to: referenceDate) ?? referenceDate
        let priorComps = cal.dateComponents([.year, .month], from: priorDate)
        let priorFirst = cal.date(from: priorComps) ?? priorDate
        let priorDaysCount = cal.range(of: .day, in: .month, for: priorFirst)?.count ?? 30

        var priorTotalSeconds: TimeInterval = 0
        for pDay in 1...priorDaysCount {
            guard let pDate = cal.date(byAdding: .day, value: pDay - 1, to: priorFirst) else { continue }
            let pKey = TimeFormatter.format(dateKey: pDate)
            let pSprints = logs[pKey] ?? []
            priorTotalSeconds += DayLog(sprints: pSprints).accumulatedTotal
        }

        let mom = calculateMonthOverMonth(
            currentSeconds: totalMonthlySeconds,
            priorSeconds: priorTotalSeconds,
            hourlyRate: settings.hourlyRate,
            currencySymbol: settings.currencySymbol
        )

        return MonthlySummary(
            monthStartDate: firstOfMonth,
            monthEndDate: lastDayOfMonth,
            monthTitle: monthTitle,
            monthOffset: monthOffset,
            isCurrentMonth: isCurrentMonth,
            days: dayBuckets,
            totalSeconds: totalMonthlySeconds,
            totalHours: totalMonthlyHours,
            formattedTotalHours: formattedMonthlyHours,
            monthlyGoalHours: settings.monthlyGoalHours,
            monthlyGoalSeconds: monthlyGoalSec,
            monthlyGoalProgress: monthlyGoalProg,
            monthlyGoalPercent: monthlyGoalPct,
            totalEarnings: totalEarn,
            formattedTotalEarnings: formattedEarn,
            targetEarnings: targetEarn,
            formattedTargetEarnings: formattedTargetEarn,
            earningsProgressLabel: earningsProgress,
            dailyAverageSeconds: dailyAvgSec,
            dailyAverageHours: dailyAvgHours,
            formattedDailyAverage: formattedAvg,
            elapsedDaysCount: elapsedDays,
            tagBreakdowns: tagBreakdowns,
            monthOverMonth: mom
        )
    }

    static func calculate(
        store: DayLogStore,
        monthOffset: Int = 0,
        referenceDate: Date = Date(),
        settings: GoalSettings = .shared,
        calendar: Calendar? = nil
    ) -> MonthlySummary {
        calculate(
            logs: store.allLogs(),
            monthOffset: monthOffset,
            referenceDate: referenceDate,
            settings: settings,
            calendar: calendar
        )
    }

    private static func calculateTagBreakdown(
        sprints: [Sprint],
        totalSeconds: TimeInterval,
        hourlyRate: Double,
        currencySymbol: String
    ) -> [TagAttribution] {
        var groupDict: [String: (tag: String?, seconds: TimeInterval, count: Int)] = [:]

        for sprint in sprints {
            let cleanTag = sprint.tag?.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = (cleanTag != nil && !cleanTag!.isEmpty) ? cleanTag! : "Untagged"
            let originalTag = (cleanTag != nil && !cleanTag!.isEmpty) ? cleanTag : nil
            let dur = sprint.duration ?? 0

            if var entry = groupDict[key] {
                entry.seconds += dur
                entry.count += 1
                groupDict[key] = entry
            } else {
                groupDict[key] = (tag: originalTag, seconds: dur, count: 1)
            }
        }

        var results: [TagAttribution] = []
        for (displayName, val) in groupDict {
            let pct = totalSeconds > 0 ? (val.seconds / totalSeconds * 1000.0).rounded() / 10.0 : 0.0
            let hours = (val.seconds / 3600.0 * 10).rounded() / 10.0
            let earn = EarningsCalculator.calculate(durationInSeconds: val.seconds, hourlyRate: hourlyRate)
            let formattedDur = TimeFormatter.format(shortDuration: val.seconds)
            let formattedEarn = EarningsCalculator.format(amount: earn, currencySymbol: currencySymbol)

            results.append(TagAttribution(
                tag: val.tag,
                displayName: displayName,
                totalSeconds: val.seconds,
                totalHours: hours,
                earnings: earn,
                percentage: pct,
                formattedDuration: formattedDur,
                formattedEarnings: formattedEarn,
                sprintCount: val.count
            ))
        }

        return results.sorted {
            if $0.totalSeconds != $1.totalSeconds {
                return $0.totalSeconds > $1.totalSeconds
            }
            return $0.displayName < $1.displayName
        }
    }

    private static func calculateMonthOverMonth(
        currentSeconds: TimeInterval,
        priorSeconds: TimeInterval,
        hourlyRate: Double,
        currencySymbol: String
    ) -> MonthOverMonthComparison {
        let secDiff = currentSeconds - priorSeconds
        let hoursDiff = ((secDiff / 3600.0) * 10).rounded() / 10.0
        let isPos = secDiff > 0
        let isNeu = secDiff == 0

        let pctChange: Double
        if priorSeconds > 0 {
            pctChange = ((secDiff / priorSeconds) * 1000.0).rounded() / 10.0
        } else if currentSeconds > 0 {
            pctChange = 100.0
        } else {
            pctChange = 0.0
        }

        let earnDiff = ((secDiff / 3600.0) * hourlyRate * 100).rounded() / 100.0
        let formattedEarnDiff = (secDiff < 0 ? "-" : "+") + EarningsCalculator.format(amount: abs(earnDiff), currencySymbol: currencySymbol)

        let hoursPrefix = isPos ? "+" : (secDiff < 0 ? "" : "")
        let formattedHoursDiff = "\(hoursPrefix)\(hoursDiff)h"

        let pctPrefix = isPos ? "+" : (secDiff < 0 ? "" : "")
        let formattedPct = "\(pctPrefix)\(Int(round(pctChange)))%"

        let summaryText: String
        if isNeu {
            summaryText = "Same as last month (0%)"
        } else if isPos {
            summaryText = "+\(hoursDiff)h (+\(Int(round(pctChange)))%) vs last month"
        } else {
            summaryText = "\(hoursDiff)h (\(Int(round(pctChange)))%) vs last month"
        }

        return MonthOverMonthComparison(
            currentSeconds: currentSeconds,
            priorSeconds: priorSeconds,
            hoursDifference: hoursDiff,
            formattedHoursDifference: formattedHoursDiff,
            percentageChange: pctChange,
            formattedPercentageChange: formattedPct,
            earningsDifference: earnDiff,
            formattedEarningsDifference: formattedEarnDiff,
            isPositive: isPos,
            isNeutral: isNeu,
            summaryText: summaryText
        )
    }
}
