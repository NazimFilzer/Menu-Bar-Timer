import Foundation

enum EarningsCalculator {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        return f
    }()

    private static let lock = NSLock()

    static func calculate(durationInSeconds: TimeInterval, hourlyRate: Double) -> Double {
        calculate(durationInHours: durationInSeconds / 3600.0, hourlyRate: hourlyRate)
    }

    static func calculate(durationInHours: Double, hourlyRate: Double) -> Double {
        guard durationInHours.isFinite, hourlyRate.isFinite,
              durationInHours > 0, hourlyRate > 0 else { return 0.0 }
        let raw = durationInHours * hourlyRate
        guard (raw * 100).isFinite else { return 0.0 }
        return (raw * 100).rounded() / 100.0
    }

    static func calculate(sprint: Sprint, hourlyRate: Double) -> Double {
        guard let duration = sprint.duration else { return 0.0 }
        return calculate(durationInSeconds: duration, hourlyRate: hourlyRate)
    }

    static func calculate(sprints: [Sprint], hourlyRate: Double) -> Double {
        guard hourlyRate > 0 else { return 0.0 }
        let totalDuration = sprints.compactMap { $0.duration }.reduce(0, +)
        return calculate(durationInSeconds: totalDuration, hourlyRate: hourlyRate)
    }

    static func calculate(sprint: Sprint, settings: GoalSettings) -> Double {
        calculate(sprint: sprint, hourlyRate: settings.hourlyRate)
    }

    static func calculate(sprints: [Sprint], settings: GoalSettings) -> Double {
        calculate(sprints: sprints, hourlyRate: settings.hourlyRate)
    }

    static func format(amount: Double, currencySymbol: String) -> String {
        let cleanAmount = amount.isFinite && (amount * 100).isFinite ? max(0, amount) : 0
        let rounded = (cleanAmount * 100).rounded() / 100.0
        lock.lock()
        defer { lock.unlock() }

        let isInteger = rounded.truncatingRemainder(dividingBy: 1) == 0
        formatter.minimumFractionDigits = isInteger ? 0 : 2
        formatter.maximumFractionDigits = isInteger ? 0 : 2

        let formattedNum = formatter.string(from: NSNumber(value: rounded)) ?? String(format: isInteger ? "%.0f" : "%.2f", rounded)
        return "\(currencySymbol)\(formattedNum)"
    }

    static func formattedEarnings(durationInSeconds: TimeInterval, hourlyRate: Double, currencySymbol: String) -> String {
        let amount = calculate(durationInSeconds: durationInSeconds, hourlyRate: hourlyRate)
        return format(amount: amount, currencySymbol: currencySymbol)
    }

    static func formattedEarnings(sprints: [Sprint], hourlyRate: Double, currencySymbol: String) -> String {
        let amount = calculate(sprints: sprints, hourlyRate: hourlyRate)
        return format(amount: amount, currencySymbol: currencySymbol)
    }

    static func formattedEarnings(sprints: [Sprint], settings: GoalSettings) -> String {
        formattedEarnings(sprints: sprints, hourlyRate: settings.hourlyRate, currencySymbol: settings.currencySymbol)
    }
}
