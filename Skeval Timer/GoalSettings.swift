import Foundation
import Observation

@Observable
class GoalSettings {
    static let shared = GoalSettings()

    private let userDefaults: UserDefaults

    // Calendar weekday numbers: Sunday = 1, Monday = 2, … Saturday = 7.
    var workingWeekdays: Set<Int> = [2, 3, 4, 5, 6] {
        didSet {
            guard !workingWeekdays.isEmpty, workingWeekdays.isSubset(of: Set(1...7)) else {
                workingWeekdays = oldValue
                return
            }
            userDefaults.set(workingWeekdays.sorted(), forKey: "skevalWorkingWeekdays")
        }
    }

    var daysOff: Set<String> = [] {
        didSet { userDefaults.set(daysOff.sorted(), forKey: "skevalDaysOff") }
    }

    var dailyGoalHours: Double = 8.0 {
        didSet {
            guard Self.validGoal(dailyGoalHours, maximum: 24) else { dailyGoalHours = oldValue; return }
            userDefaults.set(dailyGoalHours, forKey: "skevalDailyGoalHours")
        }
    }

    var weeklyGoalHours: Double = 40.0 {
        didSet {
            guard Self.validGoal(weeklyGoalHours, maximum: 168) else { weeklyGoalHours = oldValue; return }
            userDefaults.set(weeklyGoalHours, forKey: "skevalWeeklyGoalHours")
        }
    }

    var monthlyGoalHours: Double = 160.0 {
        didSet {
            guard Self.validGoal(monthlyGoalHours, maximum: 744) else { monthlyGoalHours = oldValue; return }
            userDefaults.set(monthlyGoalHours, forKey: "skevalMonthlyGoalHours")
        }
    }

    var hourlyRate: Double = 0.0 {
        didSet {
            guard Self.validRate(hourlyRate) else { hourlyRate = oldValue; return }
            userDefaults.set(hourlyRate, forKey: "skevalHourlyRate")
        }
    }

    var currencySymbol: String = "₹" {
        didSet { userDefaults.set(currencySymbol, forKey: "skevalCurrencySymbol") }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let storedWeekdays = Set(userDefaults.array(forKey: "skevalWorkingWeekdays") as? [Int] ?? [])
        workingWeekdays = !storedWeekdays.isEmpty && storedWeekdays.isSubset(of: Set(1...7))
            ? storedWeekdays : [2, 3, 4, 5, 6]
        daysOff = Set(userDefaults.stringArray(forKey: "skevalDaysOff") ?? [])
        let storedDaily = userDefaults.double(forKey: "skevalDailyGoalHours")
        dailyGoalHours = Self.validGoal(storedDaily, maximum: 24) ? storedDaily : 8.0

        let storedWeekly = userDefaults.double(forKey: "skevalWeeklyGoalHours")
        weeklyGoalHours = Self.validGoal(storedWeekly, maximum: 168) ? storedWeekly : 40.0

        let storedMonthly = userDefaults.double(forKey: "skevalMonthlyGoalHours")
        monthlyGoalHours = Self.validGoal(storedMonthly, maximum: 744) ? storedMonthly : 160.0

        let storedRate = userDefaults.double(forKey: "skevalHourlyRate")
        hourlyRate = Self.validRate(storedRate) ? storedRate : 0.0

        let storedCurrency = userDefaults.string(forKey: "skevalCurrencySymbol")
        currencySymbol = (storedCurrency != nil && !storedCurrency!.isEmpty) ? storedCurrency! : "₹"
    }

    private static func validGoal(_ hours: Double, maximum: Double) -> Bool {
        hours.isFinite && (1.0 / 60.0...maximum).contains(hours)
    }

    func isWorkingDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        workingWeekdays.contains(calendar.component(.weekday, from: date))
            && !daysOff.contains(TimeFormatter.format(dateKey: date, calendar: calendar))
    }

    private static func validRate(_ rate: Double) -> Bool {
        rate.isFinite && (0...1_000_000_000).contains(rate)
    }

    var dailyGoalSeconds: TimeInterval { dailyGoalHours * 3600 }
    var weeklyGoalSeconds: TimeInterval { weeklyGoalHours * 3600 }
    var monthlyGoalSeconds: TimeInterval { monthlyGoalHours * 3600 }

    var goalLabel: String {
        Self.goalLabel(hours: dailyGoalHours)
    }

    var weeklyGoalLabel: String {
        Self.goalLabel(hours: weeklyGoalHours)
    }

    var monthlyGoalLabel: String {
        Self.goalLabel(hours: monthlyGoalHours)
    }

    private static func goalLabel(hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
    var hasHourlyRate: Bool { hourlyRate > 0 }
    var targetEarnings: Double { dailyGoalHours * hourlyRate }
    var targetEarningsLabel: String {
        EarningsCalculator.format(amount: targetEarnings, currencySymbol: currencySymbol)
    }
    var hourlyRateLabel: String {
        EarningsCalculator.format(amount: hourlyRate, currencySymbol: currencySymbol)
    }
}
