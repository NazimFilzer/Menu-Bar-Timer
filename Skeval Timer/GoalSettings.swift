import Foundation
import Observation

@Observable
class GoalSettings {
    static let shared = GoalSettings()

    private let userDefaults: UserDefaults

    var dailyGoalHours: Double = 8.0 {
        didSet { userDefaults.set(dailyGoalHours, forKey: "skevalDailyGoalHours") }
    }

    var weeklyGoalHours: Double = 40.0 {
        didSet { userDefaults.set(weeklyGoalHours, forKey: "skevalWeeklyGoalHours") }
    }

    var monthlyGoalHours: Double = 160.0 {
        didSet { userDefaults.set(monthlyGoalHours, forKey: "skevalMonthlyGoalHours") }
    }

    var hourlyRate: Double = 0.0 {
        didSet { userDefaults.set(hourlyRate, forKey: "skevalHourlyRate") }
    }

    var currencySymbol: String = "₹" {
        didSet { userDefaults.set(currencySymbol, forKey: "skevalCurrencySymbol") }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let storedDaily = userDefaults.double(forKey: "skevalDailyGoalHours")
        dailyGoalHours = storedDaily > 0 ? storedDaily : 8.0

        let storedWeekly = userDefaults.double(forKey: "skevalWeeklyGoalHours")
        weeklyGoalHours = storedWeekly > 0 ? storedWeekly : 40.0

        let storedMonthly = userDefaults.double(forKey: "skevalMonthlyGoalHours")
        monthlyGoalHours = storedMonthly > 0 ? storedMonthly : 160.0

        let storedRate = userDefaults.double(forKey: "skevalHourlyRate")
        hourlyRate = storedRate >= 0 ? storedRate : 0.0

        let storedCurrency = userDefaults.string(forKey: "skevalCurrencySymbol")
        currencySymbol = (storedCurrency != nil && !storedCurrency!.isEmpty) ? storedCurrency! : "₹"
    }

    var dailyGoalSeconds: TimeInterval { dailyGoalHours * 3600 }
    var weeklyGoalSeconds: TimeInterval { weeklyGoalHours * 3600 }
    var monthlyGoalSeconds: TimeInterval { monthlyGoalHours * 3600 }

    var goalLabel: String {
        let h = Int(dailyGoalHours)
        let m = Int((dailyGoalHours - Double(h)) * 60)
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var weeklyGoalLabel: String {
        let h = Int(weeklyGoalHours)
        let m = Int((weeklyGoalHours - Double(h)) * 60)
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var monthlyGoalLabel: String {
        let h = Int(monthlyGoalHours)
        let m = Int((monthlyGoalHours - Double(h)) * 60)
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
