import Foundation

/// Cumulative earnings through a range, beside the previous period as a ghost line.
/// Both sides use the current hourly rate, like every other earnings figure in the app.
struct EarningsTrend: Equatable {
    /// Running totals, one per day, through today (a finished range: through its last day).
    let current: [Double]
    /// Running totals for the whole previous period, or nil when there is none.
    let previous: [Double]?
    /// The day count both lines are drawn against, so they share one x-axis.
    let dayCount: Int

    var total: Double { current.last ?? 0 }

    /// What the previous period had earned by the same day, for the side-by-side figure.
    var previousBySameDay: Double? {
        guard let previous, !current.isEmpty, !previous.isEmpty else { return nil }
        return previous[min(current.count, previous.count) - 1]
    }

    var previousTotal: Double? { previous?.last }

    static func make(days: [DailyBarData], previousDays: [DailyBarData]?, today: Date,
                     calendar: Calendar = .current) -> EarningsTrend {
        let end = calendar.startOfDay(for: today)
        let elapsed = days.filter { calendar.startOfDay(for: $0.date) <= end }
        // A previous period with no earnings draws no ghost line and no "₹0" figures.
        let previous = previousDays.flatMap { days -> [Double]? in
            let totals = running(days.map(\.earnings))
            return (totals.last ?? 0) > 0 ? totals : nil
        }
        return EarningsTrend(current: running(elapsed.map(\.earnings)), previous: previous,
                             dayCount: max(days.count, previousDays?.count ?? 0, 1))
    }

    private static func running(_ values: [Double]) -> [Double] {
        var total = 0.0
        return values.map { value in
            total += value.isFinite ? max(0, value) : 0
            return total
        }
    }
}
