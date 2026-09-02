import Foundation
import Observation

@Observable
class GoalSettings {
    static let shared = GoalSettings()

    var dailyGoalHours: Double = 8.0 {
        didSet { UserDefaults.standard.set(dailyGoalHours, forKey: "skevalDailyGoalHours") }
    }

    private init() {
        let stored = UserDefaults.standard.double(forKey: "skevalDailyGoalHours")
        dailyGoalHours = stored > 0 ? stored : 8.0
    }

    var dailyGoalSeconds: TimeInterval { dailyGoalHours * 3600 }

    var goalLabel: String {
        let h = Int(dailyGoalHours)
        let m = Int((dailyGoalHours - Double(h)) * 60)
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
