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

struct AnnualHeatmapMatrix: Equatable {
    let year: Int
    let columns: [[HeatmapDayCell]] // Array of 52..53 columns (weeks), each with 7 rows (days)
    let monthHeaders: [(monthName: String, columnIndex: Int)]
    let totalActiveDays: Int
    let totalYearSeconds: TimeInterval
    let totalYearHours: Double
    let formattedYearDuration: String
    let totalYearEarnings: Double
    let formattedYearEarnings: String

    static func == (lhs: AnnualHeatmapMatrix, rhs: AnnualHeatmapMatrix) -> Bool {
        lhs.year == rhs.year &&
        lhs.columns.count == rhs.columns.count &&
        lhs.totalActiveDays == rhs.totalActiveDays &&
        lhs.totalYearSeconds == rhs.totalYearSeconds
    }
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

    func dateRange(referenceDate: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
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
            // 5 years back to now
            let start = calendar.date(byAdding: .year, value: -5, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
            return (start, end)
        case .custom:
            let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
            return (start, end)
        }
    }
}

enum InsightsAnalytics {

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let monthAbbrFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f
    }()

    private static let lock = NSLock()

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

        let cleanStart = cal.startOfDay(for: startDate)
        let cleanEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        // Collect all completed sprints strictly within [cleanStart, cleanEnd]
        var matchingSprints: [Sprint] = []
        var activeDates: Set<String> = []
        var totalSec: TimeInterval = 0

        // Iterate through day keys in sorted order
        let sortedKeys = logs.keys.sorted()
        for key in sortedKeys {
            guard let keyDate = TimeFormatter.parseDateKey(key) else { continue }
            let dayStart = cal.startOfDay(for: keyDate)
            if dayStart >= cleanStart && dayStart <= cleanEnd {
                let sprints = logs[key] ?? []
                let dayLog = DayLog(sprints: sprints)
                for s in dayLog.completedSprints {
                    matchingSprints.append(s)
                    totalSec += s.duration ?? 0
                    activeDates.insert(key)
                }
            }
        }

        matchingSprints.sort(by: { $0.startTime > $1.startTime })

        let totalDays = max(1, (cal.dateComponents([.day], from: cleanStart, to: cleanEnd).day ?? 0) + 1)
        let activeDaysCount = activeDates.count
        let elapsedDivisor = max(1, activeDaysCount > 0 ? activeDaysCount : totalDays)

        let dailyAvgSec = totalSec > 0 ? (totalSec / Double(elapsedDivisor)) : 0.0
        let dailyAvgHours = (dailyAvgSec / 3600.0 * 10).rounded() / 10.0

        let formattedAvg: String
        if dailyAvgSec > 0 {
            let avgH = Int(dailyAvgSec) / 3600
            let avgM = (Int(dailyAvgSec) % 3600) / 60
            formattedAvg = avgH > 0 ? (avgM > 0 ? "\(avgH)h \(avgM)m" : "\(avgH)h") : "\(avgM)m"
        } else {
            formattedAvg = "0m"
        }

        let totalHours = (totalSec / 3600.0 * 100).rounded() / 100.0
        let formattedTotalHours = TimeFormatter.format(shortDuration: totalSec)

        let totalEarnings = EarningsCalculator.calculate(durationInSeconds: totalSec, hourlyRate: settings.hourlyRate)
        let formattedTotalEarn = EarningsCalculator.format(amount: totalEarnings, currencySymbol: settings.currencySymbol)

        lock.lock()
        let rangeLabel = "\(shortDateFormatter.string(from: cleanStart)) – \(fullDateFormatter.string(from: cleanEnd))"
        lock.unlock()

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

    // MARK: - Trend Curve Points Generation

    private static func generateTrendPoints(
        logs: [String: [Sprint]],
        start: Date,
        end: Date,
        settings: GoalSettings,
        calendar: Calendar
    ) -> [TrendDataPoint] {
        let daysBetween = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1

        var points: [TrendDataPoint] = []

        if daysBetween <= 31 {
            // Daily resolution
            for i in 0..<daysBetween {
                guard let d = calendar.date(byAdding: .day, value: i, to: start) else { continue }
                let key = TimeFormatter.format(dateKey: d)
                let sprints = logs[key] ?? []
                let dayLog = DayLog(sprints: sprints)
                let dur = dayLog.accumulatedTotal
                let hrs = (dur / 3600.0 * 10).rounded() / 10.0
                let earn = EarningsCalculator.calculate(durationInSeconds: dur, hourlyRate: settings.hourlyRate)

                lock.lock()
                let label = shortDateFormatter.string(from: d)
                lock.unlock()

                points.append(TrendDataPoint(
                    id: key,
                    date: d,
                    label: label,
                    totalSeconds: dur,
                    totalHours: hrs,
                    earnings: earn,
                    sprintCount: dayLog.completedSprints.count,
                    formattedDuration: TimeFormatter.format(shortDuration: dur)
                ))
            }
        } else {
            // Weekly resolution (buckets of 7 days)
            var cur = start
            var weekIndex = 1
            while cur <= end {
                let nextWeek = calendar.date(byAdding: .day, value: 7, to: cur) ?? end
                let weekEnd = calendar.date(byAdding: .day, value: -1, to: nextWeek) ?? cur
                let effectiveWeekEnd = min(weekEnd, end)

                var weekSec: TimeInterval = 0
                var weekSprintsCount = 0

                var checkDate = cur
                while checkDate <= effectiveWeekEnd {
                    let key = TimeFormatter.format(dateKey: checkDate)
                    let dayLog = DayLog(sprints: logs[key] ?? [])
                    weekSec += dayLog.accumulatedTotal
                    weekSprintsCount += dayLog.completedSprints.count
                    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
                    checkDate = nextDay
                }

                let hrs = (weekSec / 3600.0 * 10).rounded() / 10.0
                let earn = EarningsCalculator.calculate(durationInSeconds: weekSec, hourlyRate: settings.hourlyRate)

                lock.lock()
                let label = shortDateFormatter.string(from: cur)
                lock.unlock()

                points.append(TrendDataPoint(
                    id: "W\(weekIndex)_\(TimeFormatter.format(dateKey: cur))",
                    date: cur,
                    label: label,
                    totalSeconds: weekSec,
                    totalHours: hrs,
                    earnings: earn,
                    sprintCount: weekSprintsCount,
                    formattedDuration: TimeFormatter.format(shortDuration: weekSec)
                ))

                weekIndex += 1
                cur = nextWeek
            }
        }

        return points
    }

    // MARK: - 52-Week Annual Heatmap Matrix

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

        var columns: [[HeatmapDayCell]] = []
        var monthHeaders: [(monthName: String, columnIndex: Int)] = []
        var seenMonths: Set<Int> = []

        var curWeekMonday = firstHeatmapMonday
        var activeDays = 0
        var totalSec: TimeInterval = 0

        // Build 53 columns (weeks), each with 7 days (Mon=0, Tue=1, ..., Sun=6)
        for colIdx in 0..<53 {
            var weekCells: [HeatmapDayCell] = []
            var isAnyDayInYear = false

            for dayIdx in 0..<7 {
                guard let cellDate = cal.date(byAdding: .day, value: dayIdx, to: curWeekMonday) else { continue }
                let cellYear = cal.component(.year, from: cellDate)
                let cellMonth = cal.component(.month, from: cellDate)
                let isInYear = (cellYear == year)
                if isInYear { isAnyDayInYear = true }

                let key = TimeFormatter.format(dateKey: cellDate)
                let daySprints = logs[key] ?? []
                let dayLog = DayLog(sprints: daySprints)
                let dur = dayLog.accumulatedTotal
                let hrs = (dur / 3600.0 * 10).rounded() / 10.0
                let earn = EarningsCalculator.calculate(durationInSeconds: dur, hourlyRate: settings.hourlyRate)
                let formattedDur = TimeFormatter.format(shortDuration: dur)
                let formattedEarn = EarningsCalculator.format(amount: earn, currencySymbol: settings.currencySymbol)

                if isInYear && dur > 0 {
                    activeDays += 1
                    totalSec += dur
                }

                let intensity = intensityLevel(forSeconds: dur)

                let cell = HeatmapDayCell(
                    id: key,
                    date: cellDate,
                    dayOfWeekIndex: dayIdx,
                    weekIndex: colIdx,
                    totalSeconds: dur,
                    totalHours: hrs,
                    sprintCount: dayLog.completedSprints.count,
                    earnings: earn,
                    formattedDuration: formattedDur,
                    formattedEarnings: formattedEarn,
                    intensityLevel: intensity,
                    isInSelectedYear: isInYear
                )
                weekCells.append(cell)

                // Track month label on the first day of that month inside this column
                if isInYear && !seenMonths.contains(cellMonth) {
                    seenMonths.insert(cellMonth)
                    lock.lock()
                    let mName = monthAbbrFormatter.string(from: cellDate)
                    lock.unlock()
                    monthHeaders.append((monthName: mName, columnIndex: colIdx))
                }
            }

            columns.append(weekCells)

            guard let nextMonday = cal.date(byAdding: .day, value: 7, to: curWeekMonday) else { break }
            curWeekMonday = nextMonday

            // Stop if we've crossed out of the year and already have 52 or 53 weeks
            if colIdx >= 51 && !isAnyDayInYear {
                break
            }
        }

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
