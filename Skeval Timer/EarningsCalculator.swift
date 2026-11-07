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
}
