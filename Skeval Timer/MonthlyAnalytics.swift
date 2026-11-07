import Foundation

struct TagAttribution: Identifiable, Equatable {
    var id: String { tag.map { "tag:" + $0 } ?? "untagged" }
    let tag: String?
    let displayName: String
    let totalSeconds: TimeInterval
    let totalHours: Double
    let earnings: Double
    let percentage: Double
    let formattedDuration: String
    let formattedEarnings: String
    let sprintCount: Int

    var percentageLabel: String {
        if percentage == 0 && totalSeconds > 0 { return "<0.1%" }
        return percentage.formatted(.number.precision(.fractionLength(0...1))) + "%"
    }
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

    var allDistinctTags: [String] { allMonthSprints.distinctTags }
}

enum MonthlyAnalytics {

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
        let dates = AnalyticsMetrics.monthDates(containing: targetDate, calendar: cal)
        let firstOfMonth = dates.first ?? cal.startOfDay(for: targetDate)
        let lastDayOfMonth = dates.last ?? firstOfMonth
        let monthTitle = AnalyticsMetrics.label(firstOfMonth, format: "MMMM yyyy", calendar: cal)
        let isCurrentMonth = cal.isDate(firstOfMonth, equalTo: referenceDate, toGranularity: .month)
        let dayBuckets = dates.map {
            AnalyticsMetrics.day($0, logs: logs, referenceDate: referenceDate, settings: settings, calendar: cal)
        }
        let totalMonthlySeconds = dayBuckets.reduce(0) { $0 + $1.totalSeconds }
        let allCompletedSprintsInMonth = dayBuckets.flatMap(\.completedSprints)
        let elapsedDays = elapsedDayCount(isCurrentMonth: isCurrentMonth, monthOffset: monthOffset,
                                         referenceDate: referenceDate, totalDays: dates.count, calendar: cal)
        let dailyAvgSec = AnalyticsMetrics.average(totalSeconds: totalMonthlySeconds, days: elapsedDays)
        let dailyAvgHours = (dailyAvgSec / 3600.0 * 10).rounded() / 10.0
        let formattedAvg = TimeFormatter.format(shortDuration: dailyAvgSec)

        let totalMonthlyHours = (totalMonthlySeconds / 3600.0 * 100).rounded() / 100.0
        let formattedMonthlyHours = TimeFormatter.format(shortDuration: totalMonthlySeconds)

        let monthlyGoalSec = settings.monthlyGoalSeconds
        let monthlyGoalProg = monthlyGoalSec > 0 ? min(totalMonthlySeconds / monthlyGoalSec, 1.0) : 0.0
        let monthlyGoalPct = monthlyGoalSec > 0 ? AnalyticsMetrics.goalPercent(totalSeconds: totalMonthlySeconds, goalSeconds: monthlyGoalSec) : 0

        let totalEarn = EarningsCalculator.calculate(durationInSeconds: totalMonthlySeconds, hourlyRate: settings.hourlyRate)
        let formattedEarn = EarningsCalculator.format(amount: totalEarn, currencySymbol: settings.currencySymbol)

        let targetEarn = settings.monthlyGoalHours * settings.hourlyRate
        let formattedTargetEarn = EarningsCalculator.format(amount: targetEarn, currencySymbol: settings.currencySymbol)
        let earningsProgress = "\(formattedEarn) / \(formattedTargetEarn)"

        // Tag attribution breakdown
        let tagBreakdowns = calculateTagBreakdown(sprints: allCompletedSprintsInMonth, totalSeconds: totalMonthlySeconds, hourlyRate: settings.hourlyRate, currencySymbol: settings.currencySymbol)

        // Month-over-month comparison. The current month is compared with the same
        // number of days at the start of last month, like the Week page does.
        let priorDate = cal.date(byAdding: .month, value: -1, to: firstOfMonth) ?? firstOfMonth
        let priorDates = AnalyticsMetrics.monthDates(containing: priorDate, calendar: cal)
        let comparedPriorDates = isCurrentMonth ? Array(priorDates.prefix(elapsedDays)) : priorDates
        let priorTotalSeconds = comparedPriorDates.reduce(0.0) {
            $0 + DayLog(sprints: logs[TimeFormatter.format(dateKey: $1, calendar: cal)] ?? []).accumulatedTotal
        }

        let mom = calculateMonthOverMonth(
            currentSeconds: totalMonthlySeconds,
            priorSeconds: priorTotalSeconds,
            hourlyRate: settings.hourlyRate,
            currencySymbol: settings.currencySymbol,
            priorLabel: isCurrentMonth ? "same days last month" : "last month"
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

    private static func elapsedDayCount(isCurrentMonth: Bool, monthOffset: Int, referenceDate: Date,
                                        totalDays: Int, calendar: Calendar) -> Int {
        if isCurrentMonth { return calendar.component(.day, from: referenceDate) }
        return monthOffset < 0 ? totalDays : 0
    }

    private static func calculateTagBreakdown(
        sprints: [Sprint],
        totalSeconds: TimeInterval,
        hourlyRate: Double,
        currencySymbol: String
    ) -> [TagAttribution] {
        // Case-insensitive like the tag filter; the first spelling in the month is shown.
        let grouped = Dictionary(grouping: sprints) { $0.cleanTag?.lowercased() }
        let results = grouped.map { key, sprints in
            let tag = key == nil ? nil : sprints.first?.cleanTag
            let seconds = sprints.reduce(0) { $0 + ($1.duration ?? 0) }
            let pct = totalSeconds > 0 ? (seconds / totalSeconds * 1000).rounded() / 10 : 0
            let earnings = EarningsCalculator.calculate(durationInSeconds: seconds, hourlyRate: hourlyRate)
            return TagAttribution(tag: tag, displayName: tag ?? "Untagged", totalSeconds: seconds,
                                  totalHours: (seconds / 3600 * 10).rounded() / 10, earnings: earnings,
                                  percentage: pct, formattedDuration: TimeFormatter.format(shortDuration: seconds),
                                  formattedEarnings: EarningsCalculator.format(amount: earnings, currencySymbol: currencySymbol),
                                  sprintCount: sprints.count)
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
        currencySymbol: String,
        priorLabel: String
    ) -> MonthOverMonthComparison {
        let secDiff = currentSeconds - priorSeconds
        let hoursDiff = ((secDiff / 3600.0) * 10).rounded() / 10.0
        let isPos = secDiff > 0
        let isNeu = secDiff == 0

        let pctChange: Double
        if priorSeconds > 0 {
            pctChange = ((secDiff / priorSeconds) * 1000.0).rounded() / 10.0
        } else {
            pctChange = 0.0
        }

        let earnDiff = ((EarningsCalculator.calculate(durationInSeconds: currentSeconds, hourlyRate: hourlyRate)
                         - EarningsCalculator.calculate(durationInSeconds: priorSeconds, hourlyRate: hourlyRate)) * 100).rounded() / 100
        let formattedEarnDiff = (secDiff < 0 ? "-" : "+") + EarningsCalculator.format(amount: abs(earnDiff), currencySymbol: currencySymbol)

        let hoursPrefix = isPos ? "+" : ""
        let formattedHoursDiff = "\(hoursPrefix)\(hoursDiff)h"

        let pctPrefix = hoursPrefix
        let formattedPct = priorSeconds == 0 && currentSeconds > 0 ? "N/A" : "\(pctPrefix)\(Int(round(pctChange)))%"

        let summaryText = comparisonText(hoursDifference: hoursDiff, percentage: formattedPct,
                                         hasPriorWork: priorSeconds > 0, isNeutral: isNeu, prefix: hoursPrefix,
                                         priorLabel: priorLabel)

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
    private static func comparisonText(hoursDifference: Double, percentage: String, hasPriorWork: Bool,
                                       isNeutral: Bool, prefix: String, priorLabel: String) -> String {
        if isNeutral { return "Same as \(priorLabel) (0%)" }
        if !hasPriorWork { return "\(prefix)\(hoursDifference)h vs \(priorLabel) (no prior work)" }
        return "\(prefix)\(hoursDifference)h (\(percentage)) vs \(priorLabel)"
    }

}
