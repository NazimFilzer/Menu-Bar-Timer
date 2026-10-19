import Foundation

func testCatchUpAnalytics() {
    let settings = auditSettings()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let monday = auditDate(2026, 10, 12, calendar: calendar)
    let tuesday = auditDate(2026, 10, 13, calendar: calendar)
    let friday = auditDate(2026, 10, 16, calendar: calendar)
    let saturday = auditDate(2026, 10, 17, calendar: calendar)
    let sunday = auditDate(2026, 10, 18, calendar: calendar)
    let mondayKey = TimeFormatter.format(dateKey: monday, calendar: calendar)
    let tuesdayKey = TimeFormatter.format(dateKey: tuesday, calendar: calendar)
    let first = Sprint(startTime: monday, endTime: monday.addingTimeInterval(4 * 3600 + 600), pausedDuration: 600)
    let second = Sprint(startTime: tuesday, endTime: tuesday.addingTimeInterval(2 * 3600))
    var logs = [mondayKey: [first], tuesdayKey: [second]]

    func summary(_ date: Date, period: CatchUpPeriod = .week,
                 liveSprint: Sprint? = nil, liveElapsed: TimeInterval = 0) -> CatchUpSummary {
        CatchUpAnalytics.calculate(logs: logs, period: period, referenceDate: date,
                                   settings: settings, liveSprint: liveSprint,
                                   liveElapsed: liveElapsed, calendar: calendar)
    }

    let dayTwo = summary(tuesday)
    assertEqual(dayTwo.workingDaysElapsed, 2)
    assertEqual(dayTwo.expectedSeconds, 16 * 3600)
    assertEqual(dayTwo.clockedSeconds, 6 * 3600, "Breaks don't count toward catching up")
    assertEqual(dayTwo.remainingSeconds, 10 * 3600)
    assertEqual(dayTwo.headline, "10h left to catch up today")
    assertEqual(summary(monday).clockedSeconds, 4 * 3600, "Future days cannot reduce today's shortfall")
    assertEqual(summary(friday).expectedSeconds, 40 * 3600)
    assertEqual(summary(saturday).expectedSeconds, 40 * 3600, "Weekends do not add expected hours")
    assertEqual(summary(sunday).expectedSeconds, 40 * 3600)

    let open = Sprint(startTime: tuesday)
    logs[tuesdayKey]?.append(open)
    assertEqual(summary(tuesday, liveSprint: open, liveElapsed: 3600).remainingSeconds, 9 * 3600)
    assertEqual(summary(tuesday).clockedSeconds, 6 * 3600, "Unresolved recovery does not count")
    assertEqual(summary(tuesday, liveSprint: first, liveElapsed: 3600).clockedSeconds, 6 * 3600,
                "Completed sprints cannot be double-counted as active")
    let oldOpen = Sprint(startTime: calendar.date(byAdding: .day, value: -7, to: monday)!)
    assertEqual(summary(tuesday, liveSprint: oldOpen, liveElapsed: 3600).clockedSeconds, 6 * 3600)
    assertEqual(summary(tuesday, liveSprint: open, liveElapsed: -1).clockedSeconds, 6 * 3600)

    let caughtUp = summary(tuesday, liveSprint: open, liveElapsed: 10 * 3600)
    assertEqual(caughtUp.remainingSeconds, 0)
    assertEqual(caughtUp.headline, "On track")
    let ahead = summary(tuesday, liveSprint: open, liveElapsed: 12 * 3600)
    assertEqual(ahead.remainingSeconds, 0)
    assertEqual(ahead.aheadSeconds, 2 * 3600)
    assertEqual(ahead.headline, "2h ahead")

    settings.daysOff.insert(mondayKey)
    assertEqual(summary(tuesday).expectedSeconds, 8 * 3600, "A day off removes that day's expected hours")
    assertEqual(summary(tuesday).clockedSeconds, 6 * 3600, "Work logged on a day off still counts")
    settings.daysOff.remove(mondayKey)
    settings.workingWeekdays.insert(7)
    assertEqual(summary(saturday).expectedSeconds, 48 * 3600, "Custom working Saturdays add a daily goal")
    settings.workingWeekdays = [2, 3, 4, 5, 6]
    settings.workingWeekdays = []
    assertEqual(settings.workingWeekdays, [2, 3, 4, 5, 6], "At least one working day is required")
    assertEqual(summary(auditDate(2026, 11, 1, calendar: calendar), period: .month).expectedSeconds, 0)
    assertEqual(summary(auditDate(2026, 11, 2, calendar: calendar), period: .month).expectedSeconds, 8 * 3600)
    assertEqual(summary(auditDate(2026, 11, 2, calendar: calendar)).clockedSeconds, 0, "New week resets the catch-up period")
    assertEqual(summary(tuesday, period: .month).workingDaysElapsed, 9)
    assertEqual(summary(tuesday, period: .month).expectedSeconds, 72 * 3600)
    settings.dailyGoalHours = 7.5
    assertEqual(summary(tuesday).expectedSeconds, 15 * 3600, "Fractional daily goals are supported")

    let suite = "skeval-schedule-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let original = GoalSettings(userDefaults: defaults)
    original.workingWeekdays = [1, 2, 3]
    original.daysOff = [mondayKey]
    let reloaded = GoalSettings(userDefaults: defaults)
    assertEqual(reloaded.workingWeekdays, [1, 2, 3], "Work schedule persists")
    assertEqual(reloaded.daysOff, [mondayKey], "Days off persist")
    defaults.set([0, 9], forKey: "skevalWorkingWeekdays")
    assertEqual(GoalSettings(userDefaults: defaults).workingWeekdays, [2, 3, 4, 5, 6], "Invalid stored schedules use weekdays")
}

@MainActor
func testLiveCatchUpViewModel() {
    let store = DayLogStore(storage: InMemoryDayLogAdapter())
    let settings = auditSettings()
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store, goal: settings)
    let now = Date()
    let start = now.addingTimeInterval(-1800)
    engine.clockIn(at: start)
    engine.pause(at: now)
    assertEqual(vm.catchUpSummary(for: .week, now: now).clockedSeconds, 1800, "Paused active work remains credited")
    engine.clockOut(at: now)
    assertEqual(vm.catchUpSummary(for: .week, now: now).clockedSeconds, 1800, "Clocking out doesn't double-count time")
    let sprint = store.log(for: start).completedSprints.first!
    vm.delete(sprint: sprint)
    assertEqual(vm.catchUpSummary(for: .week, now: now).clockedSeconds, 0, "Deleting a sprint immediately updates catch-up")
}
