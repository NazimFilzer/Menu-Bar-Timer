import Foundation
import Observation

@Observable
class GoalSettings {
    static let shared = GoalSettings(store: ProfileLibrary.shared.settingsStore(for: ProfileLibrary.shared.active.id))

    /// Every setting that belongs to one profile. Migration and "copy settings" walk all cases,
    /// so a new setting only needs a case here.
    enum Key: String, CaseIterable {
        case timelineStartHour = "skevalTimelineStartHour"
        case timelineEndHour = "skevalTimelineEndHour"
        case workingWeekdays = "skevalWorkingWeekdays"
        case daysOff = "skevalDaysOff"
        case dailyGoalHours = "skevalDailyGoalHours"
        case weeklyGoalHours = "skevalWeeklyGoalHours"
        case monthlyGoalHours = "skevalMonthlyGoalHours"
        case hourlyRate = "skevalHourlyRate"
        case currencySymbol = "skevalCurrencySymbol"
    }

    static var profileKeys: [String] { Key.allCases.map(\.rawValue) }

    @ObservationIgnored private var store: SettingsValueStore
    /// App-wide preferences that live beside the profile settings.
    @ObservationIgnored private let appDefaults: UserDefaults
    @ObservationIgnored private var isLoading = false

    private func persist(_ value: Any, forKey key: Key) {
        guard !isLoading else { return }
        store.set(value, forKey: key.rawValue)
    }

    private func stored(_ key: Key) -> Any? { store.object(forKey: key.rawValue) }

    var timelineHours = TimelineHours() {
        didSet {
            persist(timelineHours.startHour, forKey: .timelineStartHour)
            persist(timelineHours.endHour, forKey: .timelineEndHour)
        }
    }

    // Calendar weekday numbers: Sunday = 1, Monday = 2, … Saturday = 7.
    var workingWeekdays: Set<Int> = [2, 3, 4, 5, 6] {
        didSet {
            guard !workingWeekdays.isEmpty, workingWeekdays.isSubset(of: Set(1...7)) else {
                workingWeekdays = oldValue
                return
            }
            persist(workingWeekdays.sorted(), forKey: .workingWeekdays)
        }
    }

    var daysOff: Set<String> = [] {
        didSet { persist(daysOff.sorted(), forKey: .daysOff) }
    }

    var dailyGoalHours: Double = 8.0 {
        didSet {
            guard Self.validGoal(dailyGoalHours, maximum: 24) else { dailyGoalHours = oldValue; return }
            persist(dailyGoalHours, forKey: .dailyGoalHours)
        }
    }

    var weeklyGoalHours: Double = 40.0 {
        didSet {
            guard Self.validGoal(weeklyGoalHours, maximum: 168) else { weeklyGoalHours = oldValue; return }
            persist(weeklyGoalHours, forKey: .weeklyGoalHours)
        }
    }

    var monthlyGoalHours: Double = 160.0 {
        didSet {
            guard Self.validGoal(monthlyGoalHours, maximum: 744) else { monthlyGoalHours = oldValue; return }
            persist(monthlyGoalHours, forKey: .monthlyGoalHours)
        }
    }

    var hourlyRate: Double = 0.0 {
        didSet {
            guard Self.validRate(hourlyRate) else { hourlyRate = oldValue; return }
            persist(hourlyRate, forKey: .hourlyRate)
        }
    }

    var currencySymbol: String = "₹" {
        didSet { persist(currencySymbol, forKey: .currencySymbol) }
    }

    /// Draws today's daily-goal progress as a ring in the menu bar pill. Off by default.
    /// A display choice like the theme, so it is app-wide rather than per profile.
    var showsMenuBarProgress = false {
        didSet { appDefaults.set(showsMenuBarProgress, forKey: "skevalMenuBarProgressRing") }
    }

    convenience init(userDefaults: UserDefaults) {
        self.init(store: userDefaults, appDefaults: userDefaults)
    }

    init(store: SettingsValueStore, appDefaults: UserDefaults = .standard) {
        self.store = store
        self.appDefaults = appDefaults
        load()
        showsMenuBarProgress = appDefaults.bool(forKey: "skevalMenuBarProgressRing")
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
        func number(_ key: Key) -> Double { (stored(key) as? NSNumber)?.doubleValue ?? 0 }
        timelineHours = TimelineHours(
            startHour: (stored(.timelineStartHour) as? NSNumber)?.intValue ?? 6,
            endHour: (stored(.timelineEndHour) as? NSNumber)?.intValue ?? 24
        )
        let storedWeekdays = Set((stored(.workingWeekdays) as? [NSNumber] ?? []).map(\.intValue))
        workingWeekdays = !storedWeekdays.isEmpty && storedWeekdays.isSubset(of: Set(1...7))
            ? storedWeekdays : [2, 3, 4, 5, 6]
        daysOff = Set(stored(.daysOff) as? [String] ?? [])
        let storedDaily = number(.dailyGoalHours)
        dailyGoalHours = Self.validGoal(storedDaily, maximum: 24) ? storedDaily : 8.0

        let storedWeekly = number(.weeklyGoalHours)
        weeklyGoalHours = Self.validGoal(storedWeekly, maximum: 168) ? storedWeekly : 40.0

        let storedMonthly = number(.monthlyGoalHours)
        monthlyGoalHours = Self.validGoal(storedMonthly, maximum: 744) ? storedMonthly : 160.0

        let storedRate = number(.hourlyRate)
        hourlyRate = Self.validRate(storedRate) ? storedRate : 0.0

        let storedCurrency = stored(.currencySymbol) as? String
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
