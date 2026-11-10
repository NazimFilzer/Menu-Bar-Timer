import Foundation
import Observation

@Observable
class GoalSettings {
    static let shared = GoalSettings(store: ProfileLibrary.shared.settingsStore(for: ProfileLibrary.shared.active.id))

    /// Settings that belong to one profile. Moved into a profile's settings.json on migration.
    static let profileKeys = [
        "skevalTimelineStartHour", "skevalTimelineEndHour", "skevalWorkingWeekdays", "skevalDaysOff",
        "skevalDailyGoalHours", "skevalWeeklyGoalHours", "skevalMonthlyGoalHours",
        "skevalHourlyRate", "skevalCurrencySymbol",
    ]

    @ObservationIgnored private var store: SettingsValueStore
    @ObservationIgnored private var isLoading = false

    private func persist(_ value: Any, forKey key: String) {
        guard !isLoading else { return }
        store.set(value, forKey: key)
    }

    var timelineHours = TimelineHours() {
        didSet {
            persist(timelineHours.startHour, forKey: "skevalTimelineStartHour")
            persist(timelineHours.endHour, forKey: "skevalTimelineEndHour")
        }
    }

    // Calendar weekday numbers: Sunday = 1, Monday = 2, … Saturday = 7.
    var workingWeekdays: Set<Int> = [2, 3, 4, 5, 6] {
        didSet {
            guard !workingWeekdays.isEmpty, workingWeekdays.isSubset(of: Set(1...7)) else {
                workingWeekdays = oldValue
                return
            }
            persist(workingWeekdays.sorted(), forKey: "skevalWorkingWeekdays")
        }
    }

    var daysOff: Set<String> = [] {
        didSet { persist(daysOff.sorted(), forKey: "skevalDaysOff") }
    }

    var dailyGoalHours: Double = 8.0 {
        didSet {
            guard Self.validGoal(dailyGoalHours, maximum: 24) else { dailyGoalHours = oldValue; return }
            persist(dailyGoalHours, forKey: "skevalDailyGoalHours")
        }
    }

    var weeklyGoalHours: Double = 40.0 {
        didSet {
            guard Self.validGoal(weeklyGoalHours, maximum: 168) else { weeklyGoalHours = oldValue; return }
            persist(weeklyGoalHours, forKey: "skevalWeeklyGoalHours")
        }
    }

    var monthlyGoalHours: Double = 160.0 {
        didSet {
            guard Self.validGoal(monthlyGoalHours, maximum: 744) else { monthlyGoalHours = oldValue; return }
            persist(monthlyGoalHours, forKey: "skevalMonthlyGoalHours")
        }
    }

    var hourlyRate: Double = 0.0 {
        didSet {
            guard Self.validRate(hourlyRate) else { hourlyRate = oldValue; return }
            persist(hourlyRate, forKey: "skevalHourlyRate")
        }
    }

    var currencySymbol: String = "₹" {
        didSet { persist(currencySymbol, forKey: "skevalCurrencySymbol") }
    }

    convenience init(userDefaults: UserDefaults) {
        self.init(store: userDefaults)
    }

    init(store: SettingsValueStore) {
        self.store = store
        load()
    }

    /// Shows another profile's settings in place. Switches the backing store first,
    /// so the previous profile's file is never written with the new values.
    func reload(from store: SettingsValueStore) {
        self.store = store
        load()
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        func number(_ key: String) -> Double { (store.object(forKey: key) as? NSNumber)?.doubleValue ?? 0 }
        timelineHours = TimelineHours(
            startHour: (store.object(forKey: "skevalTimelineStartHour") as? NSNumber)?.intValue ?? 6,
            endHour: (store.object(forKey: "skevalTimelineEndHour") as? NSNumber)?.intValue ?? 24
        )
        let storedWeekdays = Set((store.object(forKey: "skevalWorkingWeekdays") as? [NSNumber] ?? []).map(\.intValue))
        workingWeekdays = !storedWeekdays.isEmpty && storedWeekdays.isSubset(of: Set(1...7))
            ? storedWeekdays : [2, 3, 4, 5, 6]
        daysOff = Set(store.object(forKey: "skevalDaysOff") as? [String] ?? [])
        let storedDaily = number("skevalDailyGoalHours")
        dailyGoalHours = Self.validGoal(storedDaily, maximum: 24) ? storedDaily : 8.0

        let storedWeekly = number("skevalWeeklyGoalHours")
        weeklyGoalHours = Self.validGoal(storedWeekly, maximum: 168) ? storedWeekly : 40.0

        let storedMonthly = number("skevalMonthlyGoalHours")
        monthlyGoalHours = Self.validGoal(storedMonthly, maximum: 744) ? storedMonthly : 160.0

        let storedRate = number("skevalHourlyRate")
        hourlyRate = Self.validRate(storedRate) ? storedRate : 0.0

        let storedCurrency = store.object(forKey: "skevalCurrencySymbol") as? String
        currencySymbol = (storedCurrency?.isEmpty == false) ? storedCurrency! : "₹"
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
