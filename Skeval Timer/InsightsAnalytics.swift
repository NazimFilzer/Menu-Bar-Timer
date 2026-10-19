import Foundation

struct HeatmapDayCell: Identifiable, Equatable {
    let id: String // yyyy-MM-dd
    let date: Date
    let dayOfWeekIndex: Int // 0 = Mon, 1 = Tue, ..., 6 = Sun
    let weekIndex: Int // 0 .. 52
    let totalSeconds: TimeInterval
    let totalHours: Double
    let sprintCount: Int
    let earnings: Double
    let formattedDuration: String
    let formattedEarnings: String
    let intensityLevel: Int // 0..4
    let isInSelectedYear: Bool
}

struct HeatmapMonthHeader: Equatable {
    let monthName: String
    let columnIndex: Int
}

struct AnnualHeatmapMatrix: Equatable {
    let year: Int
    let columns: [[HeatmapDayCell]] // 53 or 54 calendar weeks, each with 7 rows.
    let monthHeaders: [HeatmapMonthHeader]
    let totalActiveDays: Int
    let totalYearSeconds: TimeInterval
    let totalYearHours: Double
    let formattedYearDuration: String
    let totalYearEarnings: Double
    let formattedYearEarnings: String

}

struct TrendDataPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let label: String
    let totalSeconds: TimeInterval
    let totalHours: Double
    let earnings: Double
    let sprintCount: Int
    let formattedDuration: String
}

struct PeriodSummary: Equatable {
    let startDate: Date
    let endDate: Date
    let dateRangeLabel: String
    let totalSeconds: TimeInterval
    let totalHours: Double
    let formattedTotalHours: String
    let totalEarnings: Double
    let formattedTotalEarnings: String
    let dailyAverageSeconds: TimeInterval
    let dailyAverageHours: Double
    let formattedDailyAverage: String
    let activeDaysCount: Int
    let totalDaysCount: Int
    let totalSprintsCount: Int
    let sprints: [Sprint]
    let trendPoints: [TrendDataPoint]

    var distinctTags: [String] {
        Array(Set(sprints.compactMap { $0.tag?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }
}

enum DateRangePreset: String, CaseIterable, Identifiable {
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case allTime = "All Time"
    case custom = "Custom"

    var id: String { rawValue }

    func dateRange(referenceDate: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian), earliestDate: Date? = nil) -> (start: Date, end: Date) {
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: referenceDate) ?? referenceDate
        switch self {
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
            return (start, end)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
            return (start, end)
        case .thisMonth:
            let comps = calendar.dateComponents([.year, .month], from: referenceDate)
            let start = calendar.date(from: comps) ?? referenceDate
            return (start, end)
        case .thisYear:
            let comps = calendar.dateComponents([.year], from: referenceDate)
            let start = calendar.date(from: comps) ?? referenceDate
            return (start, end)
        case .allTime:
            let start = calendar.startOfDay(for: min(earliestDate ?? referenceDate, referenceDate))
            return (start, end)
        case .custom:
            let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
            return (start, end)
        }
    }
}

enum InsightsAnalytics {

    // MARK: - Period Calculation

    static func calculatePeriodSummary(
        logs: [String: [Sprint]],
        startDate: Date,
        endDate: Date,
        settings: GoalSettings = .shared,
        calendar: Calendar? = nil
    ) -> PeriodSummary {
        var cal = calendar ?? Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday start

        let cleanStart = cal.startOfDay(for: min(startDate, endDate))
        let lastDay = cal.startOfDay(for: max(startDate, endDate))
        let cleanEnd = (cal.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay).addingTimeInterval(-1)

        let selectedLogs = logs.filter { includesDay($0.key, start: cleanStart, end: cleanEnd, calendar: cal) }
        let matchingSprints = selectedLogs.values.flatMap { $0 }.filter { !$0.isOpen }
            .sorted { $0.startTime > $1.startTime }
        let totalSec = matchingSprints.reduce(0) { $0 + ($1.duration ?? 0) }
        let activeDaysCount = selectedLogs.values.filter { DayLog(sprints: $0).accumulatedTotal > 0 }.count

        let totalDays = max(1, (cal.dateComponents([.day], from: cleanStart, to: cleanEnd).day ?? 0) + 1)
        let dailyAvgSec = AnalyticsMetrics.average(totalSeconds: totalSec, days: activeDaysCount)
        let dailyAvgHours = (dailyAvgSec / 3600.0 * 10).rounded() / 10.0

        let formattedAvg = TimeFormatter.format(shortDuration: dailyAvgSec)

        let totalHours = (totalSec / 3600.0 * 100).rounded() / 100.0
        let formattedTotalHours = TimeFormatter.format(shortDuration: totalSec)

        let totalEarnings = EarningsCalculator.calculate(durationInSeconds: totalSec, hourlyRate: settings.hourlyRate)
        let formattedTotalEarn = EarningsCalculator.format(amount: totalEarnings, currencySymbol: settings.currencySymbol)

        let rangeLabel = "\(AnalyticsMetrics.label(cleanStart, format: "MMM d, yyyy", calendar: cal)) – \(AnalyticsMetrics.label(cleanEnd, format: "MMM d, yyyy", calendar: cal))"

        // Generate trend data points
        let trendPoints = generateTrendPoints(
            logs: logs,
            start: cleanStart,
            end: cleanEnd,
            settings: settings,
            calendar: cal
        )

        return PeriodSummary(
            startDate: cleanStart,
            endDate: cleanEnd,
            dateRangeLabel: rangeLabel,
            totalSeconds: totalSec,
            totalHours: totalHours,
            formattedTotalHours: formattedTotalHours,
            totalEarnings: totalEarnings,
            formattedTotalEarnings: formattedTotalEarn,
            dailyAverageSeconds: dailyAvgSec,
            dailyAverageHours: dailyAvgHours,
            formattedDailyAverage: formattedAvg,
            activeDaysCount: activeDaysCount,
            totalDaysCount: totalDays,
            totalSprintsCount: matchingSprints.count,
            sprints: matchingSprints,
            trendPoints: trendPoints
        )
    }

    static func calculatePeriodSummary(
        store: DayLogStore,
        startDate: Date,
        endDate: Date,
        settings: GoalSettings = .shared,
        calendar: Calendar? = nil
    ) -> PeriodSummary {
        calculatePeriodSummary(
            logs: store.allLogs(),
            startDate: startDate,
            endDate: endDate,
            settings: settings,
            calendar: calendar
        )
    }

    private static func includesDay(_ key: String, start: Date, end: Date, calendar: Calendar) -> Bool {
        guard let date = TimeFormatter.parseDateKey(key, calendar: calendar) else { return false }
        return (start...end).contains(calendar.startOfDay(for: date))
    }

    // MARK: - Trend Curve Points Generation

    private static func generateTrendPoints(
        logs: [String: [Sprint]],
        start: Date,
        end: Date,
        settings: GoalSettings,
        calendar: Calendar
    ) -> [TrendDataPoint] {
        let dayCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        let bucketSize = dayCount <= 31 ? 1 : 7
        return stride(from: 0, to: dayCount, by: bucketSize).enumerated().compactMap { index, offset in
            guard let bucketStart = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return trendPoint(logs: logs, start: bucketStart, dayCount: min(bucketSize, dayCount - offset),
                              weekIndex: bucketSize == 1 ? nil : index + 1, settings: settings, calendar: calendar)
        }
    }

    private static func trendPoint(logs: [String: [Sprint]], start: Date, dayCount: Int,
                                   weekIndex: Int?, settings: GoalSettings, calendar: Calendar) -> TrendDataPoint {
        let days = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let dayLogs = days.map { DayLog(sprints: logs[TimeFormatter.format(dateKey: $0, calendar: calendar)] ?? []) }
        let duration = dayLogs.reduce(0) { $0 + $1.accumulatedTotal }
        let key = TimeFormatter.format(dateKey: start, calendar: calendar)
        let id = weekIndex.map { "W\($0)_\(key)" } ?? key
        return TrendDataPoint(id: id, date: start,
                              label: AnalyticsMetrics.label(start, format: "MMM d", calendar: calendar),
                              totalSeconds: duration, totalHours: duration / 3600,
                              earnings: EarningsCalculator.calculate(durationInSeconds: duration, hourlyRate: settings.hourlyRate),
                              sprintCount: dayLogs.reduce(0) { $0 + $1.completedSprints.count },
                              formattedDuration: TimeFormatter.format(shortDuration: duration))
    }

    // MARK: - Annual Heatmap

    static func generateAnnualHeatmap(
        logs: [String: [Sprint]],
        year: Int,
        settings: GoalSettings = .shared,
        calendar: Calendar? = nil
    ) -> AnnualHeatmapMatrix {
        var cal = calendar ?? Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday start

        guard let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            fatalError("Could not calculate Jan 1 for year \(year)")
        }

        // Find the Monday of the week containing Jan 1
        let jan1Weekday = cal.component(.weekday, from: jan1)
        let daysFromMonday = (jan1Weekday + 5) % 7
        let firstHeatmapMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: jan1) ?? jan1

        let lastDay = cal.date(from: DateComponents(year: year, month: 12, day: 31))!
        let columnCount = (cal.dateComponents([.day], from: firstHeatmapMonday, to: lastDay).day ?? 0) / 7 + 1
        let columns = (0..<columnCount).map { column in
            (0..<7).compactMap { row -> HeatmapDayCell? in
                guard let date = cal.date(byAdding: .day, value: column * 7 + row, to: firstHeatmapMonday) else { return nil }
                return heatmapCell(date: date, row: row, column: column, year: year,
                                   logs: logs, settings: settings, calendar: cal)
            }
        }
        let yearCells = columns.flatMap { $0 }.filter(\.isInSelectedYear)
        let activeDays = yearCells.filter { $0.totalSeconds > 0 }.count
        let totalSec = yearCells.reduce(0) { $0 + $1.totalSeconds }
        let monthHeaders = heatmapHeaders(cells: yearCells, calendar: cal)

        let totalHrs = (totalSec / 3600.0 * 100).rounded() / 100.0
        let formattedYearDur = TimeFormatter.format(shortDuration: totalSec)
        let totalYearEarn = EarningsCalculator.calculate(durationInSeconds: totalSec, hourlyRate: settings.hourlyRate)
        let formattedYearEarn = EarningsCalculator.format(amount: totalYearEarn, currencySymbol: settings.currencySymbol)

        return AnnualHeatmapMatrix(
            year: year,
            columns: columns,
            monthHeaders: monthHeaders,
            totalActiveDays: activeDays,
            totalYearSeconds: totalSec,
            totalYearHours: totalHrs,
            formattedYearDuration: formattedYearDur,
            totalYearEarnings: totalYearEarn,
            formattedYearEarnings: formattedYearEarn
        )
    }

    static func generateAnnualHeatmap(
        store: DayLogStore,
        year: Int,
        settings: GoalSettings = .shared,
        calendar: Calendar? = nil
    ) -> AnnualHeatmapMatrix {
        generateAnnualHeatmap(
            logs: store.allLogs(),
            year: year,
            settings: settings,
            calendar: calendar
        )
    }

    private static func heatmapCell(date: Date, row: Int, column: Int, year: Int,
                                    logs: [String: [Sprint]], settings: GoalSettings, calendar: Calendar) -> HeatmapDayCell {
        let key = TimeFormatter.format(dateKey: date, calendar: calendar)
        let log = DayLog(sprints: logs[key] ?? [])
        let duration = log.accumulatedTotal
        let earnings = EarningsCalculator.calculate(durationInSeconds: duration, hourlyRate: settings.hourlyRate)
        return HeatmapDayCell(id: key, date: date, dayOfWeekIndex: row, weekIndex: column,
                              totalSeconds: duration, totalHours: duration / 3600,
                              sprintCount: log.completedSprints.count, earnings: earnings,
                              formattedDuration: TimeFormatter.format(shortDuration: duration),
                              formattedEarnings: EarningsCalculator.format(amount: earnings, currencySymbol: settings.currencySymbol),
                              intensityLevel: intensityLevel(forSeconds: duration),
                              isInSelectedYear: calendar.component(.year, from: date) == year)
    }

    private static func heatmapHeaders(cells: [HeatmapDayCell], calendar: Calendar) -> [HeatmapMonthHeader] {
        var seenMonths = Set<Int>()
        return cells.compactMap { cell in
            let month = calendar.component(.month, from: cell.date)
            guard seenMonths.insert(month).inserted else { return nil }
            return HeatmapMonthHeader(monthName: AnalyticsMetrics.label(cell.date, format: "MMM", calendar: calendar), columnIndex: cell.weekIndex)
        }
    }

    // MARK: - Intensity Tier Mapping
    // 0: 0 mins
    // 1: 1 min .. < 2 hours (1 .. 7199s)
    // 2: 2 hours .. < 5 hours (7200 .. 17999s)
    // 3: 5 hours .. < 8 hours (18000 .. 28799s)
    // 4: 8+ hours (28800s+)
    static func intensityLevel(forSeconds seconds: TimeInterval) -> Int {
        if seconds <= 0 { return 0 }
        if seconds < 7200 { return 1 }
        if seconds < 18000 { return 2 }
        if seconds < 28800 { return 3 }
        return 4
    }
}
