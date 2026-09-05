import Foundation
import AppKit

// MARK: - Mini Test Assertion Framework

var totalTests = 0
var passedTests = 0

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    totalTests += 1
    if actual == expected {
        passedTests += 1
    } else {
        print("❌ FAIL: \(message) - Expected: <\(expected)>, Got: <\(actual)> at \(file):\(line)")
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    assertEqual(condition, true, message, file: file, line: line)
}

func assertFalse(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    assertEqual(condition, false, message, file: file, line: line)
}

// MARK: - Tests

func testTimeFormatter() {
    print("Running TimeFormatter tests...")

    // Duration formatting
    assertEqual(TimeFormatter.format(duration: nil), "in progress")
    assertEqual(TimeFormatter.format(duration: 45), "45s")
    assertEqual(TimeFormatter.format(duration: 75), "1m 15s")
    assertEqual(TimeFormatter.format(duration: 3665), "1h 01m")
    assertEqual(TimeFormatter.format(duration: 7200), "2h 00m")

    // Short duration
    assertEqual(TimeFormatter.format(shortDuration: 0), "0m")
    assertEqual(TimeFormatter.format(shortDuration: 1800), "30m")
    assertEqual(TimeFormatter.format(shortDuration: 3660), "1h 1m")

    // Clock formatting
    assertEqual(TimeFormatter.format(clock: 0), "00:00:00")
    assertEqual(TimeFormatter.format(clock: 3665), "01:01:05")

    // Short clock
    assertEqual(TimeFormatter.format(shortClock: 45), "0:45")
    assertEqual(TimeFormatter.format(shortClock: 3665), "1:01:05")

    // Parsing time
    let ref = Date(timeIntervalSince1970: 1700000000)
    let parsed = TimeFormatter.parseTime("14:30:00", on: ref)
    assertTrue(parsed != nil, "Should parse valid time string")

    let cal = Calendar.current
    let comps = cal.dateComponents([.hour, .minute, .second], from: parsed!)
    assertEqual(comps.hour, 14)
    assertEqual(comps.minute, 30)
    assertEqual(comps.second, 0)

    // Invalid parse
    assertTrue(TimeFormatter.parseTime("invalid", on: ref) == nil)
    assertTrue(TimeFormatter.parseTime("25:00", on: ref) == nil)

    // Date and time combination
    let sampleDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 4))!
    let time10am = cal.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 10, minute: 30, second: 0))!
    let combined = TimeFormatter.combine(date: sampleDate, time: time10am, calendar: cal)
    let combinedComps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: combined)
    assertEqual(combinedComps.year, 2026)
    assertEqual(combinedComps.month, 9)
    assertEqual(combinedComps.day, 4)
    assertEqual(combinedComps.hour, 10)
    assertEqual(combinedComps.minute, 30)
    assertEqual(combinedComps.second, 0)

    // Midnight wraparound in combine
    let startNight = cal.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 23, minute: 30))!
    let endMorningTime = cal.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 1, minute: 15))!
    let combinedWrapped = TimeFormatter.combine(date: sampleDate, time: endMorningTime, wrapIfBefore: startNight, calendar: cal)
    let wrappedComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: combinedWrapped)
    assertEqual(wrappedComps.day, 5, "Should wrap to next day when end is earlier than start")
    assertEqual(wrappedComps.hour, 1)
    assertEqual(wrappedComps.minute, 15)
    assertEqual(combinedWrapped.timeIntervalSince(startNight), 6300, "23:30 to 01:15 next day is 1h 45m = 6300s")
}

func testDayLogStoreWithInMemoryStorage() {
    print("Running DayLogStore & InMemoryDayLogAdapter tests...")

    let inMemory = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: inMemory)

    let now = Date()
    let s1 = Sprint(startTime: now, endTime: now.addingTimeInterval(1800), pausedDuration: 0)
    let s2 = Sprint(startTime: now.addingTimeInterval(2000), endTime: now.addingTimeInterval(3800), pausedDuration: 300)
    let sOpen = Sprint(startTime: now.addingTimeInterval(4000))

    store.save(sprint: s1)
    store.save(sprint: s2)
    store.save(sprint: sOpen)

    let dayLog = store.todayLog()
    assertEqual(dayLog.sprints.count, 3)
    assertEqual(dayLog.completedSprints.count, 2)
    assertEqual(dayLog.openSprint?.id, sOpen.id)

    // Verify pause properties on Sprint
    assertFalse(s1.hasPause)
    assertTrue(s2.hasPause)
    assertEqual(s2.pausedLabel, "5m 00s")
    assertEqual(s2.grossDuration, 1800)
    assertEqual(s2.duration, 1500)

    // Accumulated total: 1800 + (1800 - 300) = 3300
    assertEqual(dayLog.accumulatedTotal, 3300)
    assertEqual(dayLog.accumulatedLabel, "00:55:00")

    // Daily pause total: 0 + 300 = 300
    assertEqual(dayLog.totalPausedDuration, 300)
    assertEqual(dayLog.totalPausedLabel, "5m")

    // Verify descending order: s2 (index 2) first, then s1 (index 1)
    let desc = dayLog.completedSprintsDescending
    assertEqual(desc.count, 2)
    assertEqual(desc[0].index, 2)
    assertEqual(desc[0].sprint.id, s2.id)
    assertEqual(desc[1].index, 1)
    assertEqual(desc[1].sprint.id, s1.id)

    // Delete sprint
    store.delete(sprint: sOpen)
    let updatedLog = store.todayLog()
    assertEqual(updatedLog.sprints.count, 2)
    assertTrue(updatedLog.openSprint == nil)
}

@MainActor
func testSprintEngine() {
    print("Running SprintEngine tests...")

    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store)

    assertEqual(engine.state, .idle)

    // Clock In
    let t0 = Date()
    engine.clockIn(at: t0)
    assertTrue(engine.state.isRunning)
    assertFalse(engine.state.isPaused)
    assertEqual(engine.state.currentSprint?.startTime, t0)

    // Pause
    let t1 = t0.addingTimeInterval(120)
    engine.pause(at: t1)
    assertTrue(engine.state.isPaused)
    assertTrue(engine.state.isRunning)
    assertEqual(engine.currentPauseElapsed, 0)

    // Resume
    let t2 = t1.addingTimeInterval(60) // 60 seconds of pause
    engine.resume(at: t2)
    assertFalse(engine.state.isPaused)
    assertTrue(engine.state.isRunning)
    assertEqual(engine.totalCurrentSprintPaused, 60)

    // Clock Out
    let t3 = t2.addingTimeInterval(180) // 180 seconds more active work
    var completedSprint: Sprint? = nil
    engine.onSprintCompleted = { s in completedSprint = s }
    engine.clockOut(at: t3)

    assertEqual(engine.state, .idle)
    assertTrue(completedSprint != nil)

    // Total elapsed wall clock: 120 + 60 + 180 = 360 seconds
    // Paused duration: 60 seconds
    // Net duration: 300 seconds
    assertEqual(completedSprint?.pausedDuration, 60)
    assertEqual(completedSprint?.duration, 300)

    // Effective end time should be t3 - 60s
    let expectedEffectiveEnd = t3.addingTimeInterval(-60)
    assertEqual(completedSprint?.effectiveEnd, expectedEffectiveEnd)

    // Verify clipboard text
    let startStr = TimeFormatter.format(time: t0)
    let endStr = TimeFormatter.format(time: expectedEffectiveEnd)
    assertEqual(completedSprint?.clipboardText, "\(startStr)\t\(endStr)")

    // Recovery test
    let openSprint = Sprint(startTime: t0)
    store.save(sprint: openSprint)
    engine.reload()

    assertEqual(engine.state, .recovery(sprint: openSprint))

    // Save recovery end time
    let validEnd = TimeFormatter.format(time: t0.addingTimeInterval(3600))
    do {
        try engine.saveRecoveryEndTime(validEnd)
        assertEqual(engine.state, .idle)
    } catch {
        assertTrue(false, "Should not fail valid recovery end time: \(error)")
    }
}

@MainActor
func testAppThemes() {
    print("Running AppTheme tests...")

    assertEqual(AppTheme.allCases.count, 8)
    assertEqual(AppTheme.neon.displayName, "Neon")
    assertEqual(AppTheme.sepia.displayName, "Sepia")
    assertEqual(AppTheme.nord.displayName, "Nord")
    assertEqual(AppTheme.midnight.displayName, "Midnight")
    assertEqual(AppTheme.matcha.displayName, "Matcha")
    assertEqual(AppTheme.forest.displayName, "Forest")
    assertEqual(AppTheme.sunset.displayName, "Sunset")
    assertEqual(AppTheme.abyss.displayName, "Abyss")

    // Verify Sepia theme attributes
    let sepia = PopoverTheme.sepia
    assertEqual(sepia.name, "Sepia")
    assertEqual(sepia.isLight, false)
    assertEqual(sepia.neonTeal, sepia.accentColor)

    // Verify Matcha Light theme attributes
    let matcha = PopoverTheme.matcha
    assertEqual(matcha.name, "Matcha")
    assertEqual(matcha.isLight, true)
    assertEqual(matcha.actionButtonForeground, .white)

    // Verify ThemeManager defaults and updates
    let manager = ThemeManager.shared
    manager.current = .matcha
    assertEqual(manager.current, .matcha)
    assertEqual(manager.theme.name, "Matcha")
    assertTrue(manager.theme.isLight)

    manager.current = .neon
    assertEqual(manager.current, .neon)
    assertEqual(manager.theme.name, "Neon")
    assertFalse(manager.theme.isLight)
}

@MainActor
func testRapidPauseResumeCycles() {
    print("Running Rapid Pause/Resume Cycle tests...")
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store)

    let t0 = Date()
    engine.clockIn(at: t0)
    assertTrue(engine.state.isRunning)
    assertFalse(engine.state.isPaused)

    // Simulate 10 rapid successive pause/resume toggles
    var cur = t0
    for i in 1...10 {
        cur = cur.addingTimeInterval(5)
        engine.pause(at: cur)
        assertTrue(engine.state.isPaused, "Should be paused at cycle \(i)")

        cur = cur.addingTimeInterval(2)
        engine.resume(at: cur)
        assertTrue(engine.state.isRunning, "Should be running at cycle \(i)")
        assertFalse(engine.state.isPaused, "Should not be paused at cycle \(i)")
        assertEqual(engine.totalCurrentSprintPaused, Double(i * 2), "Accumulated paused duration should equal \(i * 2)")
    }

    // Final clock out
    cur = cur.addingTimeInterval(10)
    var finished: Sprint? = nil
    engine.onSprintCompleted = { s in finished = s }
    engine.clockOut(at: cur)

    assertEqual(engine.state, .idle)
    assertTrue(finished != nil)
    assertEqual(finished?.pausedDuration, 20) // 10 cycles * 2s
    // Total gross elapsed: 10 * (5 + 2) + 10 = 80s
    // Net duration: 80 - 20 = 60s
    assertEqual(finished?.duration, 60)
}

@MainActor
func testCrashRecoveryAndPausePersistence() {
    print("Running Crash Recovery & Pause Persistence tests...")
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine1 = SprintEngine(store: store)

    let t0 = Date()
    engine1.clockIn(at: t0)

    // Run active for 100s, then pause
    let t1 = t0.addingTimeInterval(100)
    engine1.pause(at: t1)

    // Simulate unexpected crash/quit while paused:
    // Create brand new SprintEngine with the same underlying store
    let engine2 = SprintEngine(store: store)
    assertTrue(engine2.state.isRecovery, "Should enter recovery mode after crash")
    guard case .recovery(let openSprint) = engine2.state else {
        assertTrue(false, "Engine should be in recovery state")
        return
    }
    assertTrue(openSprint.isPaused, "Recovered sprint should remember it was paused")
    assertEqual(openSprint.pauseStartedAt, t1, "Recovered sprint should preserve pauseStartedAt")
    assertEqual(openSprint.pauseCount, 1, "Recovered sprint should preserve pauseCount")

    // Resume from recovery 60s later:
    let t2 = t1.addingTimeInterval(60)
    engine2.resumeRecovery(at: t2)
    assertFalse(engine2.state.isPaused, "Should resume in active state")
    assertTrue(engine2.state.isRunning, "Should be running after recovery resume")
    assertEqual(engine2.totalCurrentSprintPaused, 60, "Paused time during crash should be credited as pausedDuration")
    assertEqual(engine2.state.currentElapsed, 100, "Net active work elapsed should be 100s")

    // Run active for 200s more, then clock out
    let t3 = t2.addingTimeInterval(200)
    var finished: Sprint? = nil
    engine2.onSprintCompleted = { s in finished = s }
    engine2.clockOut(at: t3)

    assertEqual(finished?.pausedDuration, 60)
    assertEqual(finished?.duration, 300) // 100s + 200s
    assertEqual(finished?.effectiveEnd, t3.addingTimeInterval(-60))

    // Cross-midnight recovery test
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date().addingTimeInterval(-86400)
    let yesterdayOpenSprint = Sprint(startTime: yesterday)
    store.save(sprint: yesterdayOpenSprint)
    let engine3 = SprintEngine(store: store)
    assertTrue(engine3.state.isRecovery, "Should recover open sprint even across midnight")
    assertEqual(engine3.state.currentSprint?.id, yesterdayOpenSprint.id)

    // Backward-compatibility JSON decode test
    let legacyJSON = """
    {
        "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
        "startTime": "2026-09-04T00:00:00Z"
    }
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try? decoder.decode(Sprint.self, from: legacyJSON)
    assertTrue(decoded != nil, "Legacy JSON should decode successfully")
    assertEqual(decoded?.pausedDuration, 0)
    assertEqual(decoded?.isPaused, false)
    assertEqual(decoded?.pauseStartedAt, nil)
    assertEqual(decoded?.pauseCount, 0)
}

func testSprintTaggingAndBackwardCompatibility() {
    print("Running Sprint Tagging & Backward Compatibility tests...")

    // 1. Legacy JSON without tag field decodes with tag == nil
    let legacyJSON = """
    {
        "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
        "startTime": "2026-09-04T00:00:00Z"
    }
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decodedLegacy = try? decoder.decode(Sprint.self, from: legacyJSON)
    assertTrue(decodedLegacy != nil, "Legacy JSON should decode without error")
    assertEqual(decodedLegacy?.tag, nil, "Legacy sprint should have nil tag")

    // 2. Modern JSON with tag decodes properly
    let taggedJSON = """
    {
        "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
        "startTime": "2026-09-04T00:00:00Z",
        "tag": "#dev"
    }
    """.data(using: .utf8)!
    let decodedTagged = try? decoder.decode(Sprint.self, from: taggedJSON)
    assertTrue(decodedTagged != nil, "Tagged JSON should decode without error")
    assertEqual(decodedTagged?.tag, "#dev", "Decoded sprint should have #dev tag")

    // 3. Modern Sprint with tag encodes and decodes round-trip
    let original = Sprint(startTime: Date(), tag: "#client")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(original) else {
        assertTrue(false, "Failed to encode tagged sprint")
        return
    }
    let roundTrip = try? decoder.decode(Sprint.self, from: data)
    assertEqual(roundTrip?.tag, "#client", "Round-trip should preserve tag")

    // 4. Tag persistence in DayLogStore with InMemoryDayLogAdapter
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let sprintToSave = Sprint(startTime: Date(), tag: "#research")
    store.save(sprint: sprintToSave)
    let loaded = store.todayLog().sprints.first(where: { $0.id == sprintToSave.id })
    assertEqual(loaded?.tag, "#research", "DayLogStore should persist and retrieve tag")
}

@MainActor
func testSprintEngineTagging() {
    print("Running SprintEngine Tagging tests...")
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store)

    let t0 = Date()
    engine.clockIn(at: t0, tag: "#client")
    assertEqual(engine.state.currentSprint?.tag, "#client", "Clock in with tag should set tag")
    assertEqual(store.findOpenSprint()?.sprint.tag, "#client", "DayLogStore open sprint should have tag")

    // Update tag while active
    engine.setTag("#dev")
    assertEqual(engine.state.currentSprint?.tag, "#dev", "setTag while active should update tag")
    assertEqual(store.findOpenSprint()?.sprint.tag, "#dev", "DayLogStore should persist updated tag while active")

    // Pause and update tag while paused
    let t1 = t0.addingTimeInterval(60)
    engine.pause(at: t1)
    engine.setTag("#admin")
    assertEqual(engine.state.currentSprint?.tag, "#admin", "setTag while paused should update tag")
    assertEqual(store.findOpenSprint()?.sprint.tag, "#admin", "DayLogStore should persist updated tag while paused")

    // Clock out and verify completed sprint retains tag
    let t2 = t1.addingTimeInterval(30)
    var finished: Sprint? = nil
    engine.onSprintCompleted = { s in finished = s }
    engine.clockOut(at: t2)

    assertEqual(finished?.tag, "#admin", "Completed sprint should have the final tag")
    let persisted = store.todayLog().sprints.first(where: { $0.id == finished?.id })
    assertEqual(persisted?.tag, "#admin", "Persisted completed sprint in store should have tag")
}

func testGoalSettingsExpansion() {
    print("Running GoalSettings Expansion tests...")
    let suiteName = "test_skeval_goals_\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        assertTrue(false, "Failed to create isolated UserDefaults suite")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    // 1. Assert default values
    let settings = GoalSettings(userDefaults: defaults)
    assertEqual(settings.dailyGoalHours, 8.0, "Default daily goal should be 8h")
    assertEqual(settings.weeklyGoalHours, 40.0, "Default weekly goal should be 40h")
    assertEqual(settings.monthlyGoalHours, 160.0, "Default monthly goal should be 160h")
    assertEqual(settings.hourlyRate, 0.0, "Default hourly rate should be 0.0")
    assertEqual(settings.currencySymbol, "₹", "Default currency symbol should be ₹")
    assertEqual(settings.weeklyGoalSeconds, 40.0 * 3600, "Weekly goal seconds should match 40h")
    assertEqual(settings.monthlyGoalSeconds, 160.0 * 3600, "Monthly goal seconds should match 160h")

    // 2. Modify values and verify persistence
    settings.weeklyGoalHours = 35.0
    settings.monthlyGoalHours = 140.0
    settings.hourlyRate = 1200.0
    settings.currencySymbol = "$"

    let reloaded = GoalSettings(userDefaults: defaults)
    assertEqual(reloaded.weeklyGoalHours, 35.0, "Reloaded weekly goal should match")
    assertEqual(reloaded.monthlyGoalHours, 140.0, "Reloaded monthly goal should match")
    assertEqual(reloaded.hourlyRate, 1200.0, "Reloaded hourly rate should match")
    assertEqual(reloaded.currencySymbol, "$", "Reloaded currency symbol should match")
    assertEqual(reloaded.weeklyGoalSeconds, 35.0 * 3600, "Reloaded weekly goal seconds should match")
    assertEqual(reloaded.monthlyGoalSeconds, 140.0 * 3600, "Reloaded monthly goal seconds should match")
}

func testEarningsCalculator() {
    print("Running EarningsCalculator tests...")

    // 1. Exact calculation from seconds
    let e1 = EarningsCalculator.calculate(durationInSeconds: 7200, hourlyRate: 500)
    assertEqual(e1, 1000.0, "2 hours at 500/hr should be 1000")

    // 2. Exact calculation from hours
    let e2 = EarningsCalculator.calculate(durationInHours: 2.0, hourlyRate: 500)
    assertEqual(e2, 1000.0, "2.0 hours at 500/hr should be 1000")

    // 3. Fractional calculation
    let e3 = EarningsCalculator.calculate(durationInSeconds: 5400, hourlyRate: 100)
    assertEqual(e3, 150.0, "1.5 hours at 100/hr should be 150")

    // 4. Edge cases (zero / negative)
    assertEqual(EarningsCalculator.calculate(durationInSeconds: 0, hourlyRate: 500), 0.0, "0s should earn 0")
    assertEqual(EarningsCalculator.calculate(durationInSeconds: 3600, hourlyRate: 0), 0.0, "0 rate should earn 0")
    assertEqual(EarningsCalculator.calculate(durationInSeconds: -3600, hourlyRate: 500), 0.0, "Negative duration should earn 0")
    assertEqual(EarningsCalculator.calculate(durationInSeconds: 3600, hourlyRate: -500), 0.0, "Negative rate should earn 0")

    // 5. Calculation for Sprint
    let t0 = Date()
    let completedSprint = Sprint(startTime: t0, endTime: t0.addingTimeInterval(7200), pausedDuration: 0)
    assertEqual(EarningsCalculator.calculate(sprint: completedSprint, hourlyRate: 500), 1000.0, "Completed sprint earnings should match")

    let sprintWithPause = Sprint(startTime: t0, endTime: t0.addingTimeInterval(7200), pausedDuration: 1800)
    assertEqual(EarningsCalculator.calculate(sprint: sprintWithPause, hourlyRate: 500), 750.0, "Sprint with 30m pause should calculate net earnings")

    let openSprint = Sprint(startTime: t0)
    assertEqual(EarningsCalculator.calculate(sprint: openSprint, hourlyRate: 500), 0.0, "Open sprint without endTime should return 0")

    // 6. Calculation for array of sprints
    let sprints = [completedSprint, sprintWithPause]
    assertEqual(EarningsCalculator.calculate(sprints: sprints, hourlyRate: 500), 1750.0, "Array of sprints should sum net earnings")

    // 7. Settings integration
    let suiteName = "test_earnings_\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = GoalSettings(userDefaults: defaults)
    settings.hourlyRate = 500.0
    settings.currencySymbol = "₹"
    assertEqual(EarningsCalculator.calculate(sprints: sprints, settings: settings), 1750.0, "GoalSettings calculation should match")

    // 8. Formatting
    assertEqual(EarningsCalculator.format(amount: 1000, currencySymbol: "₹"), "₹1,000", "Whole thousands should format with grouping")
    assertEqual(EarningsCalculator.format(amount: 24000, currencySymbol: "₹"), "₹24,000", "24,000 should match spec")
    assertEqual(EarningsCalculator.format(amount: 0, currencySymbol: "₹"), "₹0", "0 should format as ₹0")
    assertEqual(EarningsCalculator.format(amount: 150.50, currencySymbol: "$"), "$150.50", "Cents should format with 2 decimals")
    assertEqual(EarningsCalculator.format(amount: 150.25, currencySymbol: "€"), "€150.25", "Euros should format with decimals")

    // 9. Formatted helpers
    assertEqual(EarningsCalculator.formattedEarnings(durationInSeconds: 7200, hourlyRate: 500, currencySymbol: "₹"), "₹1,000")
    assertEqual(EarningsCalculator.formattedEarnings(sprints: sprints, settings: settings), "₹1,750")
}

@MainActor
func testTimerViewModelTaggingAndEarnings() {
    print("Running TimerViewModel Tagging & Earnings tests...")
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store)
    let vm = TimerViewModel(engine: engine, store: store)
    vm.goal.hourlyRate = 1000.0
    vm.goal.currencySymbol = "₹"

    assertEqual(vm.todayEarnings, 0.0, "Initial today earnings should be 0")
    assertEqual(vm.todayEarningsLabel, "₹0", "Initial today earnings label should be ₹0")

    let t0 = Date()
    vm.engine.clockIn(at: t0, tag: "#dev")
    vm.todayLog = store.todayLog()
    assertEqual(vm.currentTag, "#dev", "ViewModel should expose current sprint tag")

    vm.setTag("#client")
    assertEqual(vm.currentTag, "#client", "ViewModel setTag should update current sprint tag")

    let t1 = t0.addingTimeInterval(3600)
    vm.engine.clockOut(at: t1)
    vm.todayLog = store.todayLog()

    assertEqual(vm.todayEarnings, 1000.0, "1 hour at 1000/hr should yield 1000 earnings")
    assertEqual(vm.todayEarningsLabel, "₹1,000", "1 hour at 1000/hr should format as ₹1,000")

    // Test pendingTag pre-clockIn
    vm.pendingTag = "#urgent"
    assertEqual(vm.pendingTag, "#urgent")
    vm.clockIn()
    assertEqual(vm.currentTag, "#urgent", "Pending tag should be applied on clockIn")
    assertEqual(vm.pendingTag, "", "Pending tag should be cleared after clockIn")
    vm.clockOut()
}

@MainActor
func testSleepAndWakeResolution() {
    print("Running Sleep and Wake Resolution tests...")

    // 1. SleepInterval model invariants
    let t0 = Date(timeIntervalSince1970: 1725450000) // Fixed baseline
    let t1 = t0.addingTimeInterval(3600) // 1 hour later
    let interval = SleepInterval(sleepStartedAt: t0, wakeAt: t1)
    assertEqual(interval.duration, 3600.0, "SleepInterval duration should be 3600s")
    assertEqual(interval.formattedWindow, "\(TimeFormatter.format(time: t0)) – \(TimeFormatter.format(time: t1))", "Formatted window should match time range")
    assertEqual(interval.formattedDuration, TimeFormatter.format(duration: 3600), "Formatted duration should match 1h 00m")

    // Clamping inverted timestamps
    let inverted = SleepInterval(sleepStartedAt: t1, wakeAt: t0)
    assertEqual(inverted.duration, 0.0, "Inverted sleep interval duration should clamp to 0")

    // 2. Idle engine ignores system sleep
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let idleEngine = SprintEngine(store: store, observeWorkspace: false)
    idleEngine.handleSystemSleep(at: t0)
    assertEqual(idleEngine.sleepStartedAt, nil, "Idle engine should not capture sleepStartedAt")
    assertEqual(idleEngine.state, SprintState.idle, "Idle engine should remain idle")

    // 3. Active sprint transitions to held paused on sleep and suspends ticks
    let engine = SprintEngine(store: store, observeWorkspace: false)
    engine.clockIn(at: t0)
    let sleepTime = t0.addingTimeInterval(1800) // 30 mins in
    engine.handleSystemSleep(at: sleepTime)

    assertEqual(engine.sleepStartedAt, sleepTime, "handleSystemSleep should record sleepStartedAt")
    assertTrue(engine.state.isPaused, "State should transition to paused")
    assertEqual(engine.state.currentElapsed, 1800.0, "Elapsed at sleep start should be preserved")
    assertEqual(store.findOpenSprint()?.sprint.isPaused, true, "Persisted sprint should be marked paused during sleep")

    // 4. System wake calculates SleepInterval and notifies
    let wakeTime = sleepTime.addingTimeInterval(3600) // 1 hour of sleep
    var capturedInterval: SleepInterval? = nil
    engine.onSleepIntervalDetected = { inv in capturedInterval = inv }

    engine.handleSystemWake(at: wakeTime)
    assertEqual(engine.sleepStartedAt, nil, "sleepStartedAt should be cleared after wake")
    assertEqual(engine.pendingSleepInterval?.duration, 3600.0, "pendingSleepInterval duration should be 3600s")
    assertEqual(capturedInterval?.duration, 3600.0, "onSleepIntervalDetected should receive the sleep interval")
    assertTrue(engine.state.isPaused, "State should remain in held paused state until resolved")

    // 5. Resolving as "Count as Work"
    // 30 mins work + 60 mins sleep as work = 90 mins (5400s)
    let resolveTime = wakeTime
    engine.resolveSleepInterval(countAsWork: true, at: resolveTime)
    assertEqual(engine.pendingSleepInterval, nil, "pendingSleepInterval should be cleared on resolution")
    assertEqual(engine.state.isPaused, false, "Engine should resume active after resolution")
    assertEqual(engine.state.currentElapsed, 5400.0, "Elapsed should include sleep duration as work")
    assertEqual(store.findOpenSprint()?.sprint.pausedDuration, 0.0, "pausedDuration should not be incremented when counted as work")

    // Clock out and verify duration
    let endWork = resolveTime.addingTimeInterval(600) // +10 mins
    var completedWorkSprint: Sprint? = nil
    engine.onSprintCompleted = { s in completedWorkSprint = s }
    engine.clockOut(at: endWork)
    assertEqual(completedWorkSprint?.duration, 6000.0, "Net duration should be 30m + 60m + 10m = 100m (6000s)")
    assertEqual(completedWorkSprint?.pausedDuration, 0.0, "Sprint should have 0 paused duration")

    // 6. Resolving as "Count as Paused"
    let engine2 = SprintEngine(store: store, observeWorkspace: false)
    let tStart = Date(timeIntervalSince1970: 1725460000)
    engine2.clockIn(at: tStart)
    let tSleep = tStart.addingTimeInterval(1200) // 20m in
    engine2.handleSystemSleep(at: tSleep)

    let tWake = tSleep.addingTimeInterval(1800) // 30m sleep
    engine2.handleSystemWake(at: tWake)
    assertEqual(engine2.pendingSleepInterval?.duration, 1800.0, "pendingSleepInterval duration should be 1800s")

    // Resolve as paused
    engine2.resolveSleepInterval(countAsWork: false, at: tWake)
    assertEqual(engine2.pendingSleepInterval, nil, "pendingSleepInterval should be cleared")
    assertEqual(engine2.state.isPaused, false, "Engine should resume active")
    assertEqual(engine2.state.currentElapsed, 1200.0, "Elapsed work time should NOT include sleep duration")
    assertEqual(store.findOpenSprint()?.sprint.pausedDuration, 1800.0, "pausedDuration should be 1800s")

    let tEnd2 = tWake.addingTimeInterval(600) // +10 mins
    var completedPausedSprint: Sprint? = nil
    engine2.onSprintCompleted = { s in completedPausedSprint = s }
    engine2.clockOut(at: tEnd2)
    assertEqual(completedPausedSprint?.duration, 1800.0, "Net work duration should be 20m + 10m = 30m (1800s)")
    assertEqual(completedPausedSprint?.pausedDuration, 1800.0, "pausedDuration should be 30m (1800s)")

    // 7. Clocking out with unresolved sleep interval defaults safely to paused
    let engine3 = SprintEngine(store: store, observeWorkspace: false)
    let tStart3 = Date(timeIntervalSince1970: 1725470000)
    engine3.clockIn(at: tStart3)
    let tSleep3 = tStart3.addingTimeInterval(900) // 15m in
    engine3.handleSystemSleep(at: tSleep3)
    let tWake3 = tSleep3.addingTimeInterval(2700) // 45m sleep
    engine3.handleSystemWake(at: tWake3)

    var unresCompleted: Sprint? = nil
    engine3.onSprintCompleted = { s in unresCompleted = s }
    engine3.clockOut(at: tWake3)
    assertEqual(engine3.pendingSleepInterval, nil, "Clocking out should clear pending sleep interval")
    assertEqual(unresCompleted?.pausedDuration, 2700.0, "Unresolved sleep should default to paused duration to prevent phantom hours")
    assertEqual(unresCompleted?.duration, 900.0, "Duration should reflect only pre-sleep work")

    // 8. NSWorkspace notification center dispatch
    let engine4 = SprintEngine(store: store, observeWorkspace: true)
    let tStart4 = Date()
    engine4.clockIn(at: tStart4)
    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
    assertTrue(engine4.state.isPaused, "willSleepNotification should pause active sprint")
    assertTrue(engine4.sleepStartedAt != nil, "willSleepNotification should set sleepStartedAt")

    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    assertTrue(engine4.pendingSleepInterval != nil, "didWakeNotification should generate pendingSleepInterval")
    engine4.resolveSleepInterval(countAsWork: true)
    assertEqual(engine4.pendingSleepInterval, nil, "Resolving clears pendingSleepInterval")
    engine4.clockOut()

    // 9. TimerViewModel integration with sleep resolution
    let engine5 = SprintEngine(store: store, observeWorkspace: false)
    let vm5 = TimerViewModel(engine: engine5, store: store)
    let tStart5 = Date(timeIntervalSince1970: 1725480000)
    vm5.clockIn()
    assertFalse(vm5.hasPendingSleepResolution, "hasPendingSleepResolution should initially be false")
    assertEqual(vm5.statusTitle, "ACTIVE", "statusTitle should be ACTIVE")

    let tSleep5 = tStart5.addingTimeInterval(600)
    engine5.handleSystemSleep(at: tSleep5)
    let tWake5 = tSleep5.addingTimeInterval(1200)
    engine5.handleSystemWake(at: tWake5)

    assertTrue(vm5.hasPendingSleepResolution, "hasPendingSleepResolution should be true after wake")
    assertEqual(vm5.pendingSleepInterval?.duration, 1200.0, "pendingSleepInterval should match 1200s")
    assertEqual(vm5.statusTitle, "SLEEP HELD", "statusTitle should be SLEEP HELD when sleep resolution is pending")

    vm5.resolveSleep(countAsWork: true)
    assertFalse(vm5.hasPendingSleepResolution, "hasPendingSleepResolution should be false after resolve")
    assertEqual(vm5.statusTitle, "ACTIVE", "statusTitle should return to ACTIVE")
    vm5.clockOut()
}

@MainActor
func testDashboardWindowControllerLifecycle() {
    print("Running DashboardWindowController Lifecycle tests...")
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store)

    let controller = DashboardWindowController(vm: vm)
    assertTrue(controller.window != nil, "Dashboard window should be created")
    assertFalse(controller.isWindowVisible, "Dashboard window should initially be hidden")

    var recordedPolicy: NSApplication.ActivationPolicy? = nil
    controller.onActivationPolicyChanged = { policy in
        recordedPolicy = policy
    }

    // Show dashboard -> transitions to regular policy and makes window visible
    controller.showDashboard()
    assertTrue(controller.isWindowVisible, "Window should be visible after showDashboard")
    assertEqual(recordedPolicy, .regular, "Activation policy should transition to .regular")
    assertEqual(NSApp.activationPolicy(), .regular, "NSApp activation policy should be .regular")

    // Hide dashboard -> transitions back to accessory policy and hides window
    controller.hideDashboard()
    assertFalse(controller.isWindowVisible, "Window should be hidden after hideDashboard")
    assertEqual(recordedPolicy, .accessory, "Activation policy should transition to .accessory")
    assertEqual(NSApp.activationPolicy(), .accessory, "NSApp activation policy should be .accessory")

    // Show again and trigger windowShouldClose -> resets to accessory and keeps window alive
    controller.showDashboard()
    assertTrue(controller.isWindowVisible, "Window should be visible again")
    let shouldClose = controller.windowShouldClose(controller.window!)
    assertFalse(shouldClose, "windowShouldClose should return false to prevent window destruction")
    assertFalse(controller.isWindowVisible, "Window should be ordered out on close request")
    assertEqual(recordedPolicy, .accessory, "Activation policy should return to .accessory on window close")
    assertEqual(NSApp.activationPolicy(), .accessory, "NSApp policy should return to .accessory")
}

func testWeeklyAnalytics() {
    print("Running WeeklyAnalytics tests...")

    let suiteName = "test_skeval_weekly_\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = GoalSettings(userDefaults: defaults)
    settings.dailyGoalHours = 8.0
    settings.weeklyGoalHours = 40.0
    settings.hourlyRate = 1000.0
    settings.currencySymbol = "₹"

    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2 // Monday
    cal.timeZone = TimeZone.current

    // Reference Date: Friday, Sep 4, 2026 14:00:00
    var comp = DateComponents()
    comp.year = 2026
    comp.month = 9
    comp.day = 4
    comp.hour = 14
    comp.minute = 0
    comp.second = 0
    let refDate = cal.date(from: comp)!

    // 1. Empty logs test
    let emptySummary = WeeklyAnalytics.calculate(
        logs: [:],
        weekOffset: 0,
        referenceDate: refDate,
        settings: settings,
        calendar: cal
    )
    assertEqual(emptySummary.days.count, 7, "Weekly summary must contain exactly 7 day buckets")
    assertEqual(emptySummary.totalSeconds, 0.0, "Empty logs should have 0 total seconds")
    assertEqual(emptySummary.totalHours, 0.0, "Empty logs should have 0 total hours")
    assertEqual(emptySummary.formattedTotalHours, "0m", "Empty logs should format as 0m")
    assertEqual(emptySummary.totalEarnings, 0.0, "Empty logs should have 0 earnings")
    assertEqual(emptySummary.targetEarnings, 40000.0, "40h at 1000/hr target earnings should be 40,000")
    assertEqual(emptySummary.formattedTargetEarnings, "₹40,000", "Target earnings formatted as ₹40,000")
    assertEqual(emptySummary.weeklyGoalPercent, 0, "Empty progress should be 0%")
    assertEqual(emptySummary.weeklyGoalProgress, 0.0, "Empty progress fraction should be 0.0")
    assertTrue(emptySummary.isCurrentWeek, "Reference date falls in current week")
    assertEqual(emptySummary.elapsedDaysCount, 5, "Friday is day 5 (elapsed days = 5)")
    assertEqual(emptySummary.formattedDailyAverage, "0m", "Daily average should be 0m")

    // Verify 7 day labels: Mon, Tue, Wed, Thu, Fri, Sat, Sun
    let expectedDOW = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for i in 0..<7 {
        assertEqual(emptySummary.days[i].dayOfWeekLabel, expectedDOW[i], "Day \(i) DOW label should match")
        assertEqual(emptySummary.days[i].totalSeconds, 0.0)
    }
    // Verify Friday is marked as today
    assertTrue(emptySummary.days[4].isToday, "Friday (index 4) should be isToday")
    assertFalse(emptySummary.days[0].isToday, "Monday (index 0) should not be isToday")

    // 2. Sprint aggregation across multiple days
    // Mon: 2026-08-31, Wed: 2026-09-02, Fri: 2026-09-04
    let monDate = cal.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 10))!
    let wedDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 11))!
    let friDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 9))!

    let sMon = Sprint(startTime: monDate, endTime: monDate.addingTimeInterval(7200), pausedDuration: 0) // 2h (7200s)
    let sWed = Sprint(startTime: wedDate, endTime: wedDate.addingTimeInterval(14400), pausedDuration: 1800) // 4h gross - 30m pause = 3.5h (12600s)
    let sFri1 = Sprint(startTime: friDate, endTime: friDate.addingTimeInterval(3600), pausedDuration: 0) // 1h (3600s)
    let sFri2 = Sprint(startTime: friDate.addingTimeInterval(4000), endTime: friDate.addingTimeInterval(11200), pausedDuration: 0) // 2h (7200s)

    // Outside sprints: previous Sunday (2026-08-30) and next Monday (2026-09-07)
    let prevSunDate = cal.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 15))!
    let nextMonDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 10))!
    let sPrevSun = Sprint(startTime: prevSunDate, endTime: prevSunDate.addingTimeInterval(7200), pausedDuration: 0)
    let sNextMon = Sprint(startTime: nextMonDate, endTime: nextMonDate.addingTimeInterval(7200), pausedDuration: 0)

    let logs: [String: [Sprint]] = [
        "2026-08-30": [sPrevSun],
        "2026-08-31": [sMon],
        "2026-09-02": [sWed],
        "2026-09-04": [sFri1, sFri2],
        "2026-09-07": [sNextMon]
    ]

    let summary = WeeklyAnalytics.calculate(
        logs: logs,
        weekOffset: 0,
        referenceDate: refDate,
        settings: settings,
        calendar: cal
    )

    // Total seconds = 7200 (Mon) + 12600 (Wed) + 10800 (Fri) = 30600s = 8.5 hours
    assertEqual(summary.totalSeconds, 30600.0, "Weekly total seconds should be 30600")
    assertEqual(summary.totalHours, 8.5, "Weekly total hours should be 8.5")
    assertEqual(summary.formattedTotalHours, "8h 30m", "Formatted weekly hours should be 8h 30m")
    assertEqual(summary.totalEarnings, 8500.0, "8.5h at 1000/hr should be ₹8,500")
    assertEqual(summary.formattedTotalEarnings, "₹8,500", "Formatted earnings should be ₹8,500")
    assertEqual(summary.earningsProgressLabel, "₹8,500 / ₹40,000", "Earnings progress label should match")
    assertEqual(summary.weeklyGoalPercent, 21, "8.5 / 40 = 21.25% rounded to 21%")

    // Daily average: 30600s / 5 days = 6120s = 1h 42m (1.7h)
    assertEqual(summary.dailyAverageSeconds, 6120.0, "Daily average seconds should be 6120")
    assertEqual(summary.dailyAverageHours, 1.7, "Daily average hours should be 1.7")
    assertEqual(summary.formattedDailyAverage, "1h 42m", "Formatted daily average should be 1h 42m")

    // Check individual day buckets
    // Monday
    assertEqual(summary.days[0].totalSeconds, 7200.0)
    assertEqual(summary.days[0].totalHours, 2.0)
    assertEqual(summary.days[0].earnings, 2000.0)
    assertEqual(summary.days[0].formattedEarnings, "₹2,000")
    assertEqual(summary.days[0].sprintCount, 1)
    assertEqual(summary.days[0].goalProgress, 0.25) // 2 / 8 = 0.25

    // Tuesday (empty)
    assertEqual(summary.days[1].totalSeconds, 0.0)
    assertEqual(summary.days[1].sprintCount, 0)

    // Wednesday
    assertEqual(summary.days[2].totalSeconds, 12600.0)
    assertEqual(summary.days[2].totalHours, 3.5)
    assertEqual(summary.days[2].earnings, 3500.0)
    assertEqual(summary.days[2].formattedEarnings, "₹3,500")
    assertEqual(summary.days[2].sprintCount, 1)

    // Friday
    assertEqual(summary.days[4].totalSeconds, 10800.0)
    assertEqual(summary.days[4].totalHours, 3.0)
    assertEqual(summary.days[4].sprintCount, 2)
    assertTrue(summary.days[4].isToday)

    // 3. Historical week navigation: weekOffset = -1 (Aug 24 – Aug 30)
    let pastSummary = WeeklyAnalytics.calculate(
        logs: logs,
        weekOffset: -1,
        referenceDate: refDate,
        settings: settings,
        calendar: cal
    )
    assertFalse(pastSummary.isCurrentWeek, "Past week should not be current week")
    assertEqual(pastSummary.weekOffset, -1, "Week offset should be -1")
    assertEqual(pastSummary.totalSeconds, 7200.0, "Past week includes Sunday Aug 30 sprint (7200s)")
    assertEqual(pastSummary.totalHours, 2.0)
    assertEqual(pastSummary.elapsedDaysCount, 7, "Past week elapsed days count should be 7")
    // Sunday in that past week (index 6) has the 2h sprint
    assertEqual(pastSummary.days[6].totalSeconds, 7200.0)
    assertEqual(pastSummary.days[6].dayOfWeekLabel, "Sun")

    // 4. Exceeding daily and weekly goals
    let sHuge = Sprint(startTime: friDate, endTime: friDate.addingTimeInterval(36000), pausedDuration: 0) // 10h
    let hugeLogs: [String: [Sprint]] = ["2026-09-04": [sHuge]]
    let hugeSummary = WeeklyAnalytics.calculate(
        logs: hugeLogs,
        weekOffset: 0,
        referenceDate: refDate,
        settings: settings,
        calendar: cal
    )
    assertEqual(hugeSummary.days[4].goalProgress, 1.25, "10h / 8h daily goal should be 1.25")

    // Weekly goal exceeded: 50h
    settings.weeklyGoalHours = 8.0
    let exceededSummary = WeeklyAnalytics.calculate(
        logs: ["2026-09-04": [sHuge]],
        weekOffset: 0,
        referenceDate: refDate,
        settings: settings,
        calendar: cal
    )
    assertEqual(exceededSummary.weeklyGoalProgress, 1.0, "Clamped weekly progress fraction should be 1.0")
    assertEqual(exceededSummary.weeklyGoalPercent, 125, "10h / 8h weekly goal should be 125%")

    // 5. Zero hourly rate safety
    settings.hourlyRate = 0.0
    let zeroRateSummary = WeeklyAnalytics.calculate(
        logs: logs,
        weekOffset: 0,
        referenceDate: refDate,
        settings: settings,
        calendar: cal
    )
    assertEqual(zeroRateSummary.totalEarnings, 0.0, "Zero rate should produce 0 earnings")
    assertEqual(zeroRateSummary.formattedTotalEarnings, "₹0", "Zero rate should format as ₹0")
    assertEqual(zeroRateSummary.targetEarnings, 0.0, "Zero rate target earnings should be 0")

    // 6. DayLogStore integration
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    store.save(sprint: sMon)
    store.save(sprint: sWed)
    store.save(sprint: sFri1)

    let storeSummary = WeeklyAnalytics.calculate(
        store: store,
        weekOffset: 0,
        referenceDate: refDate,
        settings: settings,
        calendar: cal
    )
    assertEqual(storeSummary.days.count, 7)
    assertEqual(storeSummary.days[0].totalSeconds, 7200.0)
    assertEqual(storeSummary.days[2].totalSeconds, 12600.0)
    assertEqual(storeSummary.days[4].totalSeconds, 3600.0)
}

@MainActor
func testSprintLogCRUDAndStoreConsistency() {
    print("Running SprintLog CRUD & Store Consistency tests...")

    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store)
    let vm = TimerViewModel(engine: engine, store: store)

    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2 // Monday start

    let refDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 12))! // Fri, Sep 4
    let monDate = cal.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 9))! // Mon, Aug 31
    let wedDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 14))! // Wed, Sep 2

    // 1. Manual sprint creation
    let initialRev = vm.logRevision
    let s1Start = cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 9, minute: 0))!
    let s1End = cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 11, minute: 30))!
    let s1 = vm.addManualSprint(
        date: wedDate,
        startTime: s1Start,
        endTime: s1End,
        pausedDuration: 900, // 15m pause
        tag: "feature-crud"
    )

    assertEqual(s1.duration, 8100.0, "Net duration should be 2.5h - 15m = 8100s")
    assertEqual(s1.pausedDuration, 900.0, "Paused duration should be 900s")
    assertEqual(s1.tag, "feature-crud", "Tag should be trimmed and set")
    assertTrue(vm.logRevision > initialRev, "logRevision should increment after addManualSprint")

    let wedKey = TimeFormatter.format(dateKey: wedDate)
    let wedLog = store.log(for: wedKey)
    assertEqual(wedLog.sprints.count, 1)
    assertEqual(wedLog.completedSprints.count, 1)
    assertEqual(wedLog.accumulatedTotal, 8100.0)

    // 2. Add second sprint on Monday
    let s2Start = cal.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 10, minute: 0))!
    let s2End = cal.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12, minute: 0))!
    let s2 = vm.addManualSprint(
        date: monDate,
        startTime: s2Start,
        endTime: s2End,
        pausedDuration: 0,
        tag: "dev"
    )
    assertEqual(s2.duration, 7200.0)
    assertEqual(s2.tag, "dev")

    // 3. Weekly Summary sprint accessors
    var summary = WeeklyAnalytics.calculate(
        store: store,
        weekOffset: 0,
        referenceDate: refDate,
        settings: vm.goal,
        calendar: cal
    )
    assertEqual(summary.allWeekSprints.count, 2, "Should have 2 sprints in the week")
    assertEqual(summary.allWeekSprints[0].id, s1.id, "Newest sprint (Sep 2) should be first")
    assertEqual(summary.allWeekSprints[1].id, s2.id, "Older sprint (Aug 31) should be second")
    assertEqual(summary.allDistinctTags, ["dev", "feature-crud"], "Distinct tags should be sorted")

    // 4. Sprint Editing: Modifying timestamps, tag, and paused duration
    let editRev = vm.logRevision
    let s1NewStart = cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 8, minute: 30))!
    let s1NewEnd = cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12, minute: 0))!
    let updatedS1 = vm.updateSprint(
        originalSprint: s1,
        newDate: wedDate,
        newStartTime: s1NewStart,
        newEndTime: s1NewEnd,
        newPausedDuration: 1800, // 30m pause
        newTag: "client-review"
    )

    assertEqual(updatedS1.id, s1.id, "Sprint ID should be preserved")
    assertEqual(updatedS1.duration, 10800.0, "3.5h - 30m = 3h = 10800s")
    assertEqual(updatedS1.pausedDuration, 1800.0)
    assertEqual(updatedS1.tag, "client-review")
    assertTrue(vm.logRevision > editRev, "logRevision should increment after updateSprint")

    let updatedWedLog = store.log(for: wedKey)
    assertEqual(updatedWedLog.accumulatedTotal, 10800.0)

    // 5. Cross-Day Date Edit: Move s2 from Monday (Aug 31) to Thursday (Sep 3)
    let thuDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 15))!
    let thuStart = cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 15, minute: 0))!
    let thuEnd = cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 17, minute: 0))!

    let movedS2 = vm.updateSprint(
        originalSprint: s2,
        newDate: thuDate,
        newStartTime: thuStart,
        newEndTime: thuEnd,
        newPausedDuration: 0,
        newTag: "qa-testing"
    )

    let monKey = TimeFormatter.format(dateKey: monDate)
    let thuKey = TimeFormatter.format(dateKey: thuDate)

    let emptyMonLog = store.log(for: monKey)
    assertEqual(emptyMonLog.sprints.count, 0, "Old day bucket should be emptied after sprint moved")

    let newThuLog = store.log(for: thuKey)
    assertEqual(newThuLog.sprints.count, 1, "New day bucket should contain moved sprint")
    assertEqual(newThuLog.sprints[0].id, s2.id)
    assertEqual(newThuLog.sprints[0].tag, "qa-testing")

    // Total sprints across all logs should remain exactly 2 (no duplicates!)
    let allLogs = store.allLogs()
    let totalSprintCount = allLogs.values.reduce(0) { $0 + $1.count }
    assertEqual(totalSprintCount, 2, "Store should contain exactly 2 sprints after move")

    // 6. Sprint Deletion with reactive totals update
    let delRev = vm.logRevision
    vm.delete(sprint: updatedS1)
    assertTrue(vm.logRevision > delRev, "logRevision should increment after delete")

    let wedLogAfterDel = store.log(for: wedKey)
    assertEqual(wedLogAfterDel.sprints.count, 0, "Deleted sprint should no longer be in store")

    summary = WeeklyAnalytics.calculate(
        store: store,
        weekOffset: 0,
        referenceDate: refDate,
        settings: vm.goal,
        calendar: cal
    )
    assertEqual(summary.allWeekSprints.count, 1, "Only 1 sprint remaining after deletion")
    assertEqual(summary.allWeekSprints[0].id, s2.id)
    assertEqual(summary.totalSeconds, 7200.0, "Weekly total should immediately update to remaining sprint")

    // 7. Delete final sprint and ensure store cleans up
    vm.delete(sprint: movedS2)
    let finalAllLogs = store.allLogs()
    assertEqual(finalAllLogs.values.reduce(0) { $0 + $1.count }, 0, "All sprints deleted")
}

func testMonthlyAnalytics() {
    print("Running MonthlyAnalytics tests...")
    let suiteName = "test_skeval_monthly_\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = GoalSettings(userDefaults: defaults)
    settings.dailyGoalHours = 8.0
    settings.monthlyGoalHours = 160.0
    settings.hourlyRate = 1000.0
    settings.currencySymbol = "₹"

    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2
    cal.timeZone = TimeZone.current

    let refDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12))!

    // 1. Empty logs test
    let emptySummary = MonthlyAnalytics.calculate(
        logs: [:],
        monthOffset: 0,
        referenceDate: refDate,
        settings: settings,
        calendar: cal
    )
    assertEqual(emptySummary.days.count, 30, "September has 30 days")
    assertEqual(emptySummary.monthTitle, "September 2026")
    assertTrue(emptySummary.isCurrentMonth)
    assertEqual(emptySummary.totalSeconds, 0.0)
    assertEqual(emptySummary.totalHours, 0.0)
    assertEqual(emptySummary.totalEarnings, 0.0)
    assertEqual(emptySummary.targetEarnings, 160000.0)
    assertEqual(emptySummary.monthlyGoalPercent, 0)
    assertEqual(emptySummary.monthlyGoalProgress, 0.0)
    assertEqual(emptySummary.elapsedDaysCount, 15, "Sep 15 should have 15 elapsed days")
    assertEqual(emptySummary.formattedDailyAverage, "0m")

    // Check leap year February 2024 (29 days)
    let feb2024Date = cal.date(from: DateComponents(year: 2024, month: 2, day: 10))!
    let feb2024Summary = MonthlyAnalytics.calculate(logs: [:], monthOffset: 0, referenceDate: feb2024Date, settings: settings, calendar: cal)
    assertEqual(feb2024Summary.days.count, 29, "February 2024 is a leap year with 29 days")

    // Check non-leap February 2023 (28 days)
    let feb2023Date = cal.date(from: DateComponents(year: 2023, month: 2, day: 10))!
    let feb2023Summary = MonthlyAnalytics.calculate(logs: [:], monthOffset: 0, referenceDate: feb2023Date, settings: settings, calendar: cal)
    assertEqual(feb2023Summary.days.count, 28, "February 2023 is non-leap with 28 days")

    // 2. Sprint aggregation in month
    let d1 = cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 10))!
    let d2 = cal.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 14))!
    let d3 = cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 9))!

    let s1 = Sprint(startTime: d1, endTime: d1.addingTimeInterval(14400), pausedDuration: 0, tag: "#dev") // 4h
    let s2 = Sprint(startTime: d2, endTime: d2.addingTimeInterval(21600), pausedDuration: 0, tag: "#client") // 6h
    let s3 = Sprint(startTime: d3, endTime: d3.addingTimeInterval(36000), pausedDuration: 0, tag: "#dev") // 10h

    let logs: [String: [Sprint]] = [
        "2026-09-02": [s1],
        "2026-09-10": [s2],
        "2026-09-15": [s3]
    ]

    let summary = MonthlyAnalytics.calculate(
        logs: logs,
        monthOffset: 0,
        referenceDate: refDate,
        settings: settings,
        calendar: cal
    )

    assertEqual(summary.totalSeconds, 72000.0)
    assertEqual(summary.totalHours, 20.0)
    assertEqual(summary.formattedTotalHours, "20h 0m")
    assertEqual(summary.totalEarnings, 20000.0)
    assertEqual(summary.formattedTotalEarnings, "₹20,000")
    assertEqual(summary.monthlyGoalPercent, 13, "20h / 160h = 12.5% -> 13%")
    assertEqual(summary.monthlyGoalProgress, 20.0 / 160.0)

    // Daily average: 72000s / 15 elapsed days = 4800s = 1h 20m
    assertEqual(summary.dailyAverageSeconds, 4800.0)
    assertEqual(summary.formattedDailyAverage, "1h 20m")

    // Check specific day bucket
    let sep15Bucket = summary.days[14]
    assertEqual(sep15Bucket.dayNumberLabel, "15")
    assertEqual(sep15Bucket.totalHours, 10.0)
    assertTrue(sep15Bucket.isToday)
    assertEqual(sep15Bucket.goalProgress, 1.25, "10h / 8h daily goal = 1.25")
}

func testTagBreakdownAndAttribution() {
    print("Running Tag Breakdown & Attribution tests...")
    let suiteName = "test_skeval_tagbreakdown_\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = GoalSettings(userDefaults: defaults)
    settings.hourlyRate = 1000.0
    settings.currencySymbol = "₹"

    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2
    let refDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 20))!

    let d = refDate
    let sDev = Sprint(startTime: d, endTime: d.addingTimeInterval(216000), pausedDuration: 0, tag: "#dev") // 60h
    let sClient = Sprint(startTime: d, endTime: d.addingTimeInterval(108000), pausedDuration: 0, tag: "#client") // 30h
    let sUntagged = Sprint(startTime: d, endTime: d.addingTimeInterval(36000), pausedDuration: 0, tag: nil) // 10h

    let logs: [String: [Sprint]] = ["2026-09-20": [sDev, sClient, sUntagged]]
    let summary = MonthlyAnalytics.calculate(logs: logs, monthOffset: 0, referenceDate: refDate, settings: settings, calendar: cal)

    assertEqual(summary.tagBreakdowns.count, 3)

    let t0 = summary.tagBreakdowns[0]
    assertEqual(t0.displayName, "#dev")
    assertEqual(t0.totalHours, 60.0)
    assertEqual(t0.percentage, 60.0)
    assertEqual(t0.earnings, 60000.0)
    assertEqual(t0.formattedEarnings, "₹60,000")

    let t1 = summary.tagBreakdowns[1]
    assertEqual(t1.displayName, "#client")
    assertEqual(t1.totalHours, 30.0)
    assertEqual(t1.percentage, 30.0)
    assertEqual(t1.earnings, 30000.0)

    let t2 = summary.tagBreakdowns[2]
    assertEqual(t2.displayName, "Untagged")
    assertEqual(t2.totalHours, 10.0)
    assertEqual(t2.percentage, 10.0)
    assertEqual(t2.earnings, 10000.0)
}

func testMonthOverMonthComparison() {
    print("Running Month-over-Month Comparison tests...")
    let suiteName = "test_skeval_mom_\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = GoalSettings(userDefaults: defaults)
    settings.hourlyRate = 1000.0
    settings.currencySymbol = "₹"

    let cal = Calendar(identifier: .gregorian)
    let refDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 15))!

    // Case 1: Positive comparison (August: 100h, September: 120h -> +20h (+20%))
    let augDate = cal.date(from: DateComponents(year: 2026, month: 8, day: 10))!
    let sepDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 10))!
    let sAug = Sprint(startTime: augDate, endTime: augDate.addingTimeInterval(360000), pausedDuration: 0) // 100h
    let sSep = Sprint(startTime: sepDate, endTime: sepDate.addingTimeInterval(432000), pausedDuration: 0) // 120h

    let logsPos: [String: [Sprint]] = [
        "2026-08-10": [sAug],
        "2026-09-10": [sSep]
    ]
    let summaryPos = MonthlyAnalytics.calculate(logs: logsPos, monthOffset: 0, referenceDate: refDate, settings: settings, calendar: cal)
    let momPos = summaryPos.monthOverMonth
    assertTrue(momPos.isPositive)
    assertFalse(momPos.isNeutral)
    assertEqual(momPos.hoursDifference, 20.0)
    assertEqual(momPos.percentageChange, 20.0)
    assertEqual(momPos.earningsDifference, 20000.0)
    assertEqual(momPos.formattedEarningsDifference, "+₹20,000")
    assertEqual(momPos.summaryText, "+20.0h (+20%) vs last month")

    // Case 2: Negative comparison (September: 80h vs August: 100h -> -20h (-20%))
    let sSepNeg = Sprint(startTime: sepDate, endTime: sepDate.addingTimeInterval(288000), pausedDuration: 0) // 80h
    let logsNeg: [String: [Sprint]] = [
        "2026-08-10": [sAug],
        "2026-09-10": [sSepNeg]
    ]
    let summaryNeg = MonthlyAnalytics.calculate(logs: logsNeg, monthOffset: 0, referenceDate: refDate, settings: settings, calendar: cal)
    let momNeg = summaryNeg.monthOverMonth
    assertFalse(momNeg.isPositive)
    assertFalse(momNeg.isNeutral)
    assertEqual(momNeg.hoursDifference, -20.0)
    assertEqual(momNeg.percentageChange, -20.0)
    assertEqual(momNeg.earningsDifference, -20000.0)
    assertEqual(momNeg.formattedEarningsDifference, "-₹20,000")

    // Case 3: Zero prior month (August: 0h, September: 120h -> handles division by zero)
    let logsZeroPrior: [String: [Sprint]] = [
        "2026-09-10": [sSep]
    ]
    let summaryZero = MonthlyAnalytics.calculate(logs: logsZeroPrior, monthOffset: 0, referenceDate: refDate, settings: settings, calendar: cal)
    let momZero = summaryZero.monthOverMonth
    assertTrue(momZero.isPositive)
    assertEqual(momZero.hoursDifference, 120.0)
    assertEqual(momZero.percentageChange, 100.0)

    // Case 4: Both months 0h -> neutral
    let summaryEmpty = MonthlyAnalytics.calculate(logs: [:], monthOffset: 0, referenceDate: refDate, settings: settings, calendar: cal)
    assertTrue(summaryEmpty.monthOverMonth.isNeutral)
    assertEqual(summaryEmpty.monthOverMonth.percentageChange, 0.0)
}

func testInsightsPeriodSummaryAndDateRangeFiltering() {
    print("Running Insights Period Summary & Date Range Filtering tests...")
    let suiteName = "test_skeval_insights_\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = GoalSettings(userDefaults: defaults)
    settings.hourlyRate = 500.0
    settings.currencySymbol = "$"

    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2

    let d1 = cal.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 10))! // Before range
    let d2 = cal.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 10))!  // In range
    let d3 = cal.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 14))!  // In range
    let d4 = cal.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))! // After range

    let s1 = Sprint(startTime: d1, endTime: d1.addingTimeInterval(7200), pausedDuration: 0, tag: "#old")
    let s2 = Sprint(startTime: d2, endTime: d2.addingTimeInterval(14400), pausedDuration: 0, tag: "#core") // 4h
    let s3 = Sprint(startTime: d3, endTime: d3.addingTimeInterval(7200), pausedDuration: 0, tag: "#fix")  // 2h
    let s4 = Sprint(startTime: d4, endTime: d4.addingTimeInterval(7200), pausedDuration: 0, tag: "#future")

    let logs: [String: [Sprint]] = [
        "2026-08-15": [s1],
        "2026-09-01": [s2],
        "2026-09-05": [s3],
        "2026-09-25": [s4]
    ]

    let rangeStart = cal.date(from: DateComponents(year: 2026, month: 9, day: 1))!
    let rangeEnd = cal.date(from: DateComponents(year: 2026, month: 9, day: 10))!

    let period = InsightsAnalytics.calculatePeriodSummary(
        logs: logs,
        startDate: rangeStart,
        endDate: rangeEnd,
        settings: settings,
        calendar: cal
    )

    assertEqual(period.sprints.count, 2)
    assertEqual(period.totalSeconds, 21600.0)
    assertEqual(period.totalHours, 6.0)
    assertEqual(period.formattedTotalHours, "6h 0m")
    assertEqual(period.totalEarnings, 3000.0)
    assertEqual(period.formattedTotalEarnings, "$3,000")
    assertEqual(period.activeDaysCount, 2)
    assertEqual(period.totalDaysCount, 10)
    assertEqual(period.dailyAverageHours, 3.0)
    assertEqual(period.formattedDailyAverage, "3h")
    assertEqual(period.distinctTags, ["#core", "#fix"])

    assertTrue(!period.trendPoints.isEmpty)
    assertEqual(period.trendPoints.count, 10, "Daily resolution for 10-day period")
}

func testAnnualContributionHeatmap() {
    print("Running Annual Contribution Heatmap tests...")
    let suiteName = "test_skeval_heatmap_\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = GoalSettings(userDefaults: defaults)
    settings.hourlyRate = 1000.0

    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2

    // Intensity level mapping
    assertEqual(InsightsAnalytics.intensityLevel(forSeconds: 0), 0)
    assertEqual(InsightsAnalytics.intensityLevel(forSeconds: 1800), 1)  // 30m
    assertEqual(InsightsAnalytics.intensityLevel(forSeconds: 10800), 2) // 3h
    assertEqual(InsightsAnalytics.intensityLevel(forSeconds: 21600), 3) // 6h
    assertEqual(InsightsAnalytics.intensityLevel(forSeconds: 32400), 4) // 9h

    let d1 = cal.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 10))! // 2h
    let d2 = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 10))! // 6h
    let s1 = Sprint(startTime: d1, endTime: d1.addingTimeInterval(7200), pausedDuration: 0)
    let s2 = Sprint(startTime: d2, endTime: d2.addingTimeInterval(21600), pausedDuration: 0)

    let logs: [String: [Sprint]] = [
        "2026-01-05": [s1],
        "2026-06-15": [s2]
    ]

    let matrix = InsightsAnalytics.generateAnnualHeatmap(logs: logs, year: 2026, settings: settings, calendar: cal)
    assertEqual(matrix.year, 2026)
    assertTrue(matrix.columns.count >= 52 && matrix.columns.count <= 53)
    for col in matrix.columns {
        assertEqual(col.count, 7, "Each week column has 7 days")
    }
    assertEqual(matrix.totalActiveDays, 2)
    assertEqual(matrix.totalYearSeconds, 28800.0)
    assertEqual(matrix.totalYearHours, 8.0)
    assertEqual(matrix.totalYearEarnings, 8000.0)
    assertTrue(matrix.monthHeaders.count >= 12, "Should have month headers for the year")
}

func testRFC4180CSVExport() {
    print("Running RFC-4180 CSV Export tests...")

    // 1. Escaping rules
    assertEqual(CSVExporter.escapeRFC4180("Simple"), "Simple")
    assertEqual(CSVExporter.escapeRFC4180("With,Comma"), "\"With,Comma\"")
    assertEqual(CSVExporter.escapeRFC4180("With\"Quote"), "\"With\"\"Quote\"")
    assertEqual(CSVExporter.escapeRFC4180("With\nNewline"), "\"With\nNewline\"")
    assertEqual(CSVExporter.escapeRFC4180("Complex, \"Tag\" with\nline"), "\"Complex, \"\"Tag\"\" with\nline\"")

    // 2. Full CSV document generation
    let t0 = Date(timeIntervalSince1970: 1700000000)
    let t1 = t0.addingTimeInterval(3600) // 1h
    let t2 = t0.addingTimeInterval(7200) // 2h

    let s1 = Sprint(startTime: t0, endTime: t1, pausedDuration: 0, tag: "#dev")
    let s2 = Sprint(startTime: t1, endTime: t2, pausedDuration: 900, tag: "#client, urgent")

    let csv = CSVExporter.generateCSV(sprints: [s1, s2])
    let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }

    assertEqual(lines.count, 3, "Header + 2 rows")
    assertEqual(lines[0], "Date,Start,End,Duration,Tag")

    assertTrue(lines[1].contains("#dev"))
    assertTrue(lines[1].contains("01:00:00"))

    assertTrue(lines[2].contains("\"#client, urgent\""))
    assertTrue(lines[2].contains("00:45:00"))

    let emptyCSV = CSVExporter.generateCSV(sprints: [])
    assertEqual(emptyCSV, "Date,Start,End,Duration,Tag\r\n")
}

func testTagFilterMatching() {
    print("Running TagFilter tests...")
    let sDev = Sprint(startTime: Date(), tag: "#dev")
    let sClient = Sprint(startTime: Date(), tag: "#client")
    let sUntagged = Sprint(startTime: Date(), tag: nil)
    let sEmpty = Sprint(startTime: Date(), tag: "   ")

    let allFilter = TagFilter.all
    let devFilter = TagFilter.tag("#dev")
    let clientFilter = TagFilter.tag("#CLIENT") // test case insensitivity
    let untaggedFilter = TagFilter.untagged

    assertTrue(allFilter.matches(sprint: sDev))
    assertTrue(allFilter.matches(sprint: sClient))
    assertTrue(allFilter.matches(sprint: sUntagged))
    assertTrue(allFilter.matches(sprint: sEmpty))

    assertTrue(devFilter.matches(sprint: sDev))
    assertFalse(devFilter.matches(sprint: sClient))
    assertFalse(devFilter.matches(sprint: sUntagged))

    assertTrue(clientFilter.matches(sprint: sClient), "Tag matching should be case insensitive")
    assertFalse(clientFilter.matches(sprint: sDev))

    assertFalse(untaggedFilter.matches(sprint: sDev))
    assertFalse(untaggedFilter.matches(sprint: sClient))
    assertTrue(untaggedFilter.matches(sprint: sUntagged))
    assertTrue(untaggedFilter.matches(sprint: sEmpty), "Whitespace-only tag matches untagged filter")
}

// MARK: - Main Runner

@main
struct TestMain {
    static func main() async {
        print("========================================")
        print("Skeval Timer Architecture Verification")
        print("========================================")

        testTimeFormatter()
        testDayLogStoreWithInMemoryStorage()
        testSprintTaggingAndBackwardCompatibility()
        testGoalSettingsExpansion()
        testEarningsCalculator()
        testWeeklyAnalytics()
        testMonthlyAnalytics()
        testTagBreakdownAndAttribution()
        testMonthOverMonthComparison()
        testInsightsPeriodSummaryAndDateRangeFiltering()
        testAnnualContributionHeatmap()
        testRFC4180CSVExport()
        testTagFilterMatching()
        await MainActor.run {
            testSprintEngine()
            testSprintEngineTagging()
            testRapidPauseResumeCycles()
            testCrashRecoveryAndPausePersistence()
            testAppThemes()
            testTimerViewModelTaggingAndEarnings()
            testSleepAndWakeResolution()
            testDashboardWindowControllerLifecycle()
            testSprintLogCRUDAndStoreConsistency()
        }

        print("----------------------------------------")
        print("Results: \(passedTests) / \(totalTests) assertions passed.")
        if passedTests == totalTests {
            print("✅ All architecture tests passed successfully!")
        } else {
            print("❌ Some tests failed!")
            exit(1)
        }
    }
}

