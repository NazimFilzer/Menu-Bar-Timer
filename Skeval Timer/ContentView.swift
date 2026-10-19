import SwiftUI

// Preview host only — not used at runtime.
#if DEBUG && canImport(PreviewsMacros)
#Preview {
    PopoverView(vm: TimerViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Week · Sample Data") {
    SkevalDashboardPreview.view(for: .week)
}

#Preview("Month · Sample Data") {
    SkevalDashboardPreview.view(for: .month)
}

#Preview("Analytics · Sample Data") {
    SkevalDashboardPreview.view(for: .analytics)
}
private enum SkevalDashboardPreview {
    static func view(for destination: DashboardDestination) -> some View {
        let defaults = UserDefaults(suiteName: "skeval.preview.\(UUID().uuidString)")!
        defaults.set(destination.rawValue, forKey: "skevalDashboardDestination")

        let settings = GoalSettings(userDefaults: defaults)
        settings.hourlyRate = 1_800
        settings.dailyGoalHours = 8
        settings.weeklyGoalHours = 35
        settings.monthlyGoalHours = 140

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var logs: [String: [Sprint]] = [:]
        let tags = ["Client", "Design", "Research", "Admin"]

        for dayOffset in 0..<75 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let weekday = calendar.dateComponents([.weekday], from: date).weekday,
                  weekday != 1, weekday != 7 || dayOffset.isMultiple(of: 3),
                  dayOffset == 0 || !dayOffset.isMultiple(of: 9) else { continue }

            let firstNet = TimeInterval((120 + dayOffset % 4 * 10) * 60)
            let secondNet = TimeInterval((150 + dayOffset % 5 * 12) * 60)
            let firstStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            let secondStart = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date) ?? date
            let sprints = [
                Sprint(startTime: firstStart,
                       endTime: firstStart.addingTimeInterval(firstNet + 5 * 60),
                       pausedDuration: 5 * 60,
                       tag: tags[dayOffset % tags.count]),
                Sprint(startTime: secondStart,
                       endTime: secondStart.addingTimeInterval(secondNet + 10 * 60),
                       pausedDuration: 10 * 60,
                       tag: tags[(dayOffset + 1) % tags.count])
            ]
            logs[TimeFormatter.format(dateKey: date, calendar: calendar)] = sprints
        }

        let store = DayLogStore(storage: InMemoryDayLogAdapter(initialLogs: logs))
        let engine = SprintEngine(store: store, observeWorkspace: false)
        let viewModel = TimerViewModel(engine: engine, store: store, goal: settings)

        return DashboardView(vm: viewModel)
            .defaultAppStorage(defaults)
            .preferredColorScheme(.dark)
    }
}
#endif
