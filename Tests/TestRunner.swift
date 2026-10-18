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

    // Spreadsheet break minutes round to the nearest integer, with halves up.
    assertEqual(TimeFormatter.format(breakMinutes: 0), "0")
    assertEqual(TimeFormatter.format(breakMinutes: 36000), "600")
    assertEqual(TimeFormatter.format(breakMinutes: 90), "2")
    assertEqual(TimeFormatter.format(breakMinutes: 20), "0")
    assertEqual(TimeFormatter.format(breakMinutes: 29), "0")
    assertEqual(TimeFormatter.format(breakMinutes: 30), "1")
    assertEqual(TimeFormatter.format(breakMinutes: 89), "1")

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
}

func testDayLogStoreWithInMemoryStorage() {
    print("Running DayLogStore & InMemoryDayLogAdapter tests...")

    let inMemory = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: inMemory)

    let now = Date().addingTimeInterval(-7200)
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

    // One daily row: actual bounds, blank lunch, pauses plus inter-sprint gaps.
    let expectedAllText = "\(s1.startLabel)\t\(s2.endLabel)\t\t8"
    assertEqual(updatedLog.clipboardText, expectedAllText)

    let rows = updatedLog.clipboardText.components(separatedBy: "\n")
    assertEqual(rows.count, 1)
    assertEqual(rows[0].components(separatedBy: "\t").count, 4)
    assertEqual(rows[0].components(separatedBy: "\t")[0], s1.startLabel)
    assertEqual(rows[0].components(separatedBy: "\t")[1], s2.endLabel)
    assertEqual(rows[0].components(separatedBy: "\t")[2], "")

    // Empty day log
    let emptyLog = DayLog()
    assertEqual(emptyLog.clipboardText, "")
}

func testDailyTimesheetExport() {
    print("Running daily timesheet export tests...")
    let reference = Date(timeIntervalSince1970: 1791158400)
    let login = TimeFormatter.parseTime("09:00:00", on: reference)!
    let first = Sprint(startTime: login, endTime: login.addingTimeInterval(3600), pausedDuration: 600)
    let last = Sprint(startTime: login.addingTimeInterval(7200), endTime: login.addingTimeInterval(10800), pausedDuration: 300)
    // Open sprints have no logout and must not change the completed day's bounds.
    let earlierOpen = Sprint(startTime: login.addingTimeInterval(-3600))
    let laterOpen = Sprint(startTime: login.addingTimeInterval(14400))
    let log = DayLog(sprints: [laterOpen, last, earlierOpen, first])
    assertEqual(log.clipboardText, "09:00:00\t12:00:00\t\t75")
    assertEqual(DayLog(sprints: [earlierOpen]).clipboardText, "")

    let columns = log.clipboardText.components(separatedBy: "\t")
    let breakSeconds = Double(columns[3])! * 60
    assertEqual(10800 - breakSeconds, log.accumulatedTotal, "Subtracting the exported break must recover recorded net work")

    let uninterrupted = Sprint(startTime: login, endTime: login.addingTimeInterval(3600))
    assertEqual(DayLog(sprints: [uninterrupted]).clipboardText, "09:00:00\t10:00:00\t\t0")
    let shortPause = Sprint(startTime: login, endTime: login.addingTimeInterval(3600), pausedDuration: 30)
    assertEqual(DayLog(sprints: [shortPause]).clipboardText, "09:00:00\t10:00:00\t\t1")

    // Manual entries may overlap. Logout is the maximum end, not the end of
    // the sprint that started last, and the break must never be negative.
    let spanning = Sprint(startTime: login, endTime: login.addingTimeInterval(14400))
    assertEqual(DayLog(sprints: [last, spanning]).clipboardText, "09:00:00\t13:00:00\t\t0")

    // A sprint crossing midnight still belongs to its start day.
    let nightStart = TimeFormatter.parseTime("23:00:00", on: reference)!
    let overnight = Sprint(startTime: nightStart, endTime: nightStart.addingTimeInterval(7200), pausedDuration: 900)
    assertEqual(DayLog(sprints: [overnight]).clipboardText, "23:00:00\t01:00:00\t\t15")

    // Export rounding does not change the precise recorded work duration.
    let secondsPause = Sprint(startTime: login, endTime: login.addingTimeInterval(3600), pausedDuration: 20)
    assertEqual(DayLog(sprints: [secondsPause]).clipboardText, "09:00:00\t10:00:00\t\t0")
    assertEqual(secondsPause.duration, 3580)
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

import Carbon

@MainActor
func testGlobalHotkeys() {
    print("Running Global Hotkey tests...")

    // Verify key codes: C = 8 (0x08), P = 35 (0x23)
    assertEqual(Int(kVK_ANSI_C), 8, "kVK_ANSI_C must be 8")
    assertEqual(Int(kVK_ANSI_P), 35, "kVK_ANSI_P must be 35")

    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store)

    // Simulation of triggerPauseToggle()
    func simulatePauseToggle() {
        if case .paused = engine.state {
            engine.resume()
        } else if case .active = engine.state {
            engine.pause()
        }
    }

    // Idle state: hotkey has no effect
    simulatePauseToggle()
    assertEqual(engine.state, .idle)

    // Start running
    engine.clockIn()
    assertTrue(engine.state.isRunning)
    assertFalse(engine.state.isPaused)

    // Hotkey: Active -> Paused
    simulatePauseToggle()
    assertTrue(engine.state.isPaused)

    // Hotkey: Paused -> Active (Resumed)
    simulatePauseToggle()
    assertFalse(engine.state.isPaused)
    assertTrue(engine.state.isRunning)

    // Clean up
    engine.clockOut()
    assertEqual(engine.state, .idle)
}

func testAppVersion() {
    print("Running AppVersion tests...")
    assertEqual(AppVersion.current, "v1.2", "App version should be tracked as v1.2")
    assertEqual(AppVersion.marketingVersion, "1.2", "Marketing version should be 1.2")
    assertEqual(AppVersion.buildNumber, "3", "Build number should be 3")
}

@MainActor
func testEarningsTracking() {
    print("Running Today's Earnings & Hourly Rate tests...")

    // 1. TimeFormatter rupee formatting
    assertEqual(TimeFormatter.format(rupees: 0), "₹0", "Zero rupees should format as ₹0")
    assertEqual(TimeFormatter.format(rupees: 1000), "₹1,000", "1000 should format with comma")
    assertEqual(TimeFormatter.format(rupees: 3750.2), "₹3,750", "Decimal should round to nearest whole rupee")
    assertEqual(TimeFormatter.format(rupees: 3750.8), "₹3,751", "Decimal .8 should round up")
    assertEqual(TimeFormatter.format(rupees: 100000), "₹1,00,000", "Lakh formatting should use Indian grouping")

    // 2. GoalSettings rates & targets
    let goal = GoalSettings.shared
    let savedRate = goal.hourlyRate
    let savedHours = goal.dailyGoalHours
    defer {
        goal.hourlyRate = savedRate
        goal.dailyGoalHours = savedHours
    }

    goal.dailyGoalHours = 8.0
    goal.hourlyRate = 0.0
    assertFalse(goal.hasHourlyRate, "hasHourlyRate must be false when hourlyRate is 0")
    assertEqual(goal.targetEarnings, 0.0, "targetEarnings must be 0 when rate is 0")

    goal.hourlyRate = 1500.0
    assertTrue(goal.hasHourlyRate, "hasHourlyRate must be true when hourlyRate > 0")
    assertEqual(goal.targetEarnings, 12000.0, "8 hours at 1500/hr = 12000 target earnings")
    assertEqual(goal.targetEarningsLabel, "₹12,000")

    // 3. TimerViewModel calculations with completed + live elapsed
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store)
    let vm = TimerViewModel(engine: engine, store: store)

    // Save a completed sprint of 2 hours (7200 seconds)
    let t0 = Date().addingTimeInterval(-7200)
    let completedSprint = Sprint(startTime: t0, endTime: t0.addingTimeInterval(7200), pausedDuration: 0)
    store.save(sprint: completedSprint)
    vm.todayLog = store.todayLog()

    assertEqual(vm.todayLog.accumulatedTotal, 7200, "Accumulated total should be 2 hours")
    // With rate = 1500: 2h * 1500 = 3000
    assertEqual(vm.todayEarnings, 3000.0, "2 hours at 1500/hr must equal 3000")
    assertEqual(vm.todayEarningsLabel, "₹3,000")

    // Simulate clock in: live running sprint adds 1800s (30m)
    vm.clockIn()
    vm.currentElapsed = 1800 // 30 minutes
    // Total time = 2.5 hours -> 2.5 * 1500 = 3750
    assertEqual(vm.totalTodayElapsed, 9000)
    assertEqual(vm.todayEarnings, 3750.0, "2.5 hours with live ticking must equal 3750")
    assertEqual(vm.todayEarningsLabel, "₹3,750")

    // Overtime test: simulate 10 hours logged (36000s) on 8h goal
    vm.currentElapsed = 28800 // 8h live + 2h completed = 10h total
    assertEqual(vm.totalTodayElapsed, 36000)
    assertEqual(vm.todayEarnings, 15000.0, "10 hours at 1500/hr must equal 15000")
    assertEqual(vm.todayEarningsLabel, "₹15,000")
    assertEqual(vm.progressFraction, 1.0, "Progress fraction must cap at 1.0 on overtime")
    assertTrue(vm.isDailyGoalReached, "Goal must be marked reached")

    // Clean up sprint
    vm.clockOut()

    // Clearing rate reverts to 0 and disables tracking
    goal.hourlyRate = 0.0
    assertFalse(goal.hasHourlyRate)
    assertEqual(vm.todayEarnings, 0.0, "todayEarnings must be 0 when rate is cleared")
}

@MainActor
func testManualSprintEntry() {
    print("Running Manual Sprint Entry tests...")
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store)
    let vm = TimerViewModel(engine: engine, store: store)

    assertFalse(vm.isManualEntryPresented)

    // Open manual entry
    vm.openManualEntry()
    assertTrue(vm.isManualEntryPresented)

    // Test invalid format validation
    vm.manualStartText = "invalid"
    vm.manualEndText = "10:00:00"
    let success1 = vm.saveManualSprint()
    assertFalse(success1)
    assertEqual(vm.manualEntryError, "Invalid start time (HH:mm:ss)")
    assertTrue(vm.isManualEntryPresented)

    // Test end before start validation
    vm.manualStartText = "11:00:00"
    vm.manualEndText = "10:00:00"
    let success2 = vm.saveManualSprint()
    assertFalse(success2)
    assertEqual(vm.manualEntryError, "End time must be after start time")

    // Test break duration exceeding total time
    vm.manualStartText = "10:00:00"
    vm.manualEndText = "10:30:00"
    vm.manualBreakMinutesText = "45"
    let success3 = vm.saveManualSprint()
    assertFalse(success3)
    assertEqual(vm.manualEntryError, "Break duration exceeds sprint time")

    // Test stepper buttons
    vm.manualStartText = "10:00:00"
    vm.stepManualTime(isStart: true, minutes: 15)
    assertEqual(vm.manualStartText, "10:15:00")
    vm.stepManualTime(isStart: true, minutes: -30)
    assertEqual(vm.manualStartText, "09:45:00")

    // Test valid manual sprint saving with 10 min break
    vm.manualStartText = "09:00:00"
    vm.manualEndText = "10:30:00" // 90 min gross
    vm.manualBreakMinutesText = "10" // 10 min break -> 80 min net (4800s)
    let net = vm.manualComputedNetDuration
    assertEqual(net, 4800.0)

    let success4 = vm.saveManualSprint()
    assertTrue(success4)
    assertFalse(vm.isManualEntryPresented)
    assertEqual(vm.todayLog.completedSprints.count, 1)

    let saved = vm.todayLog.completedSprints.first!
    assertEqual(saved.startLabel, "09:00:00")
    assertEqual(saved.endLabel, "10:30:00")
    assertEqual(saved.pausedDuration, 600.0)
    assertEqual(saved.duration, 4800.0)
    assertEqual(saved.effectiveEndLabel, "10:20:00")
    assertEqual(vm.todayLog.accumulatedTotal, 4800.0)

    // Test clipboard text of manual sprint
    assertEqual(saved.clipboardText, "09:00:00\t10:20:00")

    // Test out-of-order sprint insertion & chronological sorting:
    // Existing sprint: 09:00:00 - 10:30:00 (#1)
    // Now add a later sprint: 14:00:00 - 15:00:00
    vm.manualStartText = "14:00:00"
    vm.manualEndText = "15:00:00"
    vm.manualBreakMinutesText = "0"
    assertTrue(vm.saveManualSprint())

    // Now add an earlier sprint (retroactive): 07:00:00 - 08:00:00
    vm.manualStartText = "07:00:00"
    vm.manualEndText = "08:00:00"
    vm.manualBreakMinutesText = "0"
    assertTrue(vm.saveManualSprint())

    // Sprints must be sorted chronologically in completedSprints:
    // Index 0: 07:00 - 08:00
    // Index 1: 09:00 - 10:30
    // Index 2: 14:00 - 15:00
    assertEqual(vm.todayLog.completedSprints.count, 3)
    assertEqual(vm.todayLog.completedSprints[0].startLabel, "07:00:00")
    assertEqual(vm.todayLog.completedSprints[1].startLabel, "09:00:00")
    assertEqual(vm.todayLog.completedSprints[2].startLabel, "14:00:00")

    // In the UI view (completedSprintsDescending):
    // Top card should be #3 (14:00:00)
    // Middle card should be #2 (09:00:00)
    // Bottom card should be #1 (07:00:00)
    let descending = vm.todayLog.completedSprintsDescending
    assertEqual(descending.count, 3)
    assertEqual(descending[0].index, 3)
    assertEqual(descending[0].sprint.startLabel, "14:00:00")
    assertEqual(descending[1].index, 2)
    assertEqual(descending[1].sprint.startLabel, "09:00:00")
    assertEqual(descending[2].index, 1)
    assertEqual(descending[2].sprint.startLabel, "07:00:00")

    // Test dismiss
    vm.openManualEntry()
    assertTrue(vm.isManualEntryPresented)
    vm.dismissManualEntry()
    assertFalse(vm.isManualEntryPresented)
}

@MainActor
func testPastDaysHistory() {
    print("Running Past Days History & Navigation tests...")

    let inMemory = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: inMemory)
    let engine = SprintEngine(store: store)
    let vm = TimerViewModel(engine: engine, store: store)

    // Initial state: Viewing today
    assertTrue(vm.isViewingToday)
    assertEqual(vm.selectedDayShortTitle, "Today")
    assertEqual(vm.sprintsSectionTitle, "TODAY'S SPRINTS")
    assertEqual(vm.availablePastDates.count, 7)

    // Verify availablePastDates starts today and goes back 6 days
    let cal = Calendar.current
    for (i, d) in vm.availablePastDates.enumerated() {
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day ?? 0
        assertEqual(diff, i, "Day at index \(i) should be \(i) days ago")
    }

    // Set hourly rate
    vm.goal.hourlyRate = 500.0

    // Setup: 1 sprint today (1 hour: 3600s), 2 sprints yesterday (2 hours each: 7200s total)
    let today = Date()
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

    // Today's sprint
    let sTodayStart = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
    let sTodayEnd = cal.date(bySettingHour: 11, minute: 0, second: 0, of: today)!
    let sToday = Sprint(startTime: sTodayStart, endTime: sTodayEnd, pausedDuration: 0)
    store.save(sprint: sToday)

    // Yesterday's sprints
    let sYest1Start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: yesterday)!
    let sYest1End = cal.date(bySettingHour: 11, minute: 0, second: 0, of: yesterday)!
    let sYest1 = Sprint(startTime: sYest1Start, endTime: sYest1End, pausedDuration: 0) // 2h (7200s)

    let sYest2Start = cal.date(bySettingHour: 14, minute: 0, second: 0, of: yesterday)!
    let sYest2End = cal.date(bySettingHour: 16, minute: 0, second: 0, of: yesterday)!
    let sYest2 = Sprint(startTime: sYest2Start, endTime: sYest2End, pausedDuration: 0) // 2h (7200s)

    store.save(sprint: sYest1)
    store.save(sprint: sYest2)

    // Refresh vm today log
    vm.selectDate(today)
    assertEqual(vm.displayedCompletedSprints.count, 1)
    assertEqual(vm.displayedAccumulatedTotal, 3600.0)
    assertEqual(vm.displayedEarnings, 500.0)
    assertEqual(vm.displayedGoalTitle, "Daily Target")

    // Test menu item title
    let yestMenuItem = vm.menuItemTitle(for: yesterday)
    assertTrue(yestMenuItem.contains("Yesterday") && yestMenuItem.contains("(2)"))

    // Navigate to Yesterday
    vm.selectDate(yesterday)
    assertFalse(vm.isViewingToday)
    assertEqual(vm.selectedDayShortTitle, "Yesterday")
    assertEqual(vm.sprintsSectionTitle, "YESTERDAY'S SPRINTS")
    assertEqual(vm.displayedCompletedSprints.count, 2)
    assertEqual(vm.displayedAccumulatedTotal, 14400.0) // 4h
    assertEqual(vm.displayedEarnings, 2000.0) // 4h * 500
    assertEqual(vm.displayedGoalTitle, "Yesterday's Target")
    assertEqual(vm.displayedTotalShortLabel, "4h 0m")

    // Copy All must export the selected historical day's summary to the clipboard.
    let yestClipboard = vm.selectedDayLog.clipboardText
    assertEqual(yestClipboard, "09:00:00\t16:00:00\t\t180")
    vm.copyAllDisplayedSprints()
    assertEqual(NSPasteboard.general.string(forType: .string), yestClipboard)
    assertTrue(vm.isAllCopied)

    // Test saving manual sprint while viewing yesterday
    vm.manualStartText = "17:00:00"
    vm.manualEndText = "18:00:00"
    vm.manualBreakMinutesText = "0"
    let savedYest = vm.saveManualSprint()
    assertTrue(savedYest)

    // Yesterday now has 3 sprints, today still has 1 sprint
    assertEqual(vm.displayedCompletedSprints.count, 3)
    assertEqual(vm.todayLog.completedSprints.count, 1)

    // Test jump to today
    vm.jumpToToday()
    assertTrue(vm.isViewingToday)
    assertEqual(vm.selectedDayShortTitle, "Today")
    assertEqual(vm.sprintsSectionTitle, "TODAY'S SPRINTS")
    assertEqual(vm.displayedCompletedSprints.count, 1)
    assertEqual(vm.displayedAccumulatedTotal, 3600.0)
    assertEqual(vm.displayedEarnings, 500.0)
    assertEqual(vm.displayedGoalTitle, "Daily Target")
    vm.copyAllDisplayedSprints()
    assertEqual(NSPasteboard.general.string(forType: .string), "10:00:00\t11:00:00\t\t0")
}

@MainActor
func testPopoverHeightAndSizing() {
    print("Running Popover Height & Dynamic Sizing tests...")
    let inMemory = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: inMemory)
    let engine = SprintEngine(store: store)
    let vm = TimerViewModel(engine: engine, store: store)

    // 1. Initial empty state: no sprints, not expanded, no recovery -> stable 590 to prevent UI compaction
    assertEqual(vm.displayedCompletedSprints.count, 0)
    assertFalse(vm.isSettingsExpanded)
    assertFalse(vm.recoveryMode)
    assertEqual(vm.desiredPopoverHeight, 590.0, "Empty state without sprints should be 590 to prevent UI compaction")

    // 2. Settings expanded without sprints -> 780
    vm.isSettingsExpanded = true
    assertEqual(vm.desiredPopoverHeight, 780.0, "Empty state with settings expanded should be 780")
    vm.isSettingsExpanded = false

    // 3. Add sprint today -> stable 590
    let today = Date()
    let sToday = Sprint(startTime: today, endTime: today.addingTimeInterval(3600), pausedDuration: 0)
    store.save(sprint: sToday)
    vm.todayLog = store.todayLog()
    vm.selectDate(today)

    assertEqual(vm.displayedCompletedSprints.count, 1)
    assertEqual(vm.desiredPopoverHeight, 590.0, "State with completed sprints should be 590")

    // 4. Settings expanded with sprints -> 780
    vm.isSettingsExpanded = true
    assertEqual(vm.desiredPopoverHeight, 780.0, "State with sprints and settings expanded should be 780")
    vm.isSettingsExpanded = false

    // 5. Past days navigation sizing test
    // Yesterday has 0 sprints, Today has 1 sprint
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    vm.selectDate(yesterday)
    assertEqual(vm.displayedCompletedSprints.count, 0)
    assertEqual(vm.desiredPopoverHeight, 590.0, "Viewing yesterday with 0 sprints should size stably to 590")

    vm.selectDate(today)
    assertEqual(vm.displayedCompletedSprints.count, 1)
    assertEqual(vm.desiredPopoverHeight, 590.0, "Returning to today with 1 sprint should size to 590")
}

@MainActor
func testAutomaticDayRollover() {
    print("Running Automatic Day Rollover tests...")
    let inMemory = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: inMemory)
    let engine = SprintEngine(store: store)
    let vm = TimerViewModel(engine: engine, store: store)

    let today = Date()
    let cal = Calendar.current
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

    // 1. User was viewing yesterday
    vm.selectDate(yesterday)
    assertFalse(vm.isViewingToday)
    assertEqual(vm.selectedDayShortTitle, "Yesterday")

    // 2. Starting timer via clockIn() must automatically advance view to Today
    vm.clockIn()
    assertTrue(vm.isViewingToday, "Clocking in must automatically switch view to today")
    assertTrue(vm.isRunning)
    vm.clockOut()

    // 3. Day rollover detection via checkAndHandleDayChange
    let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
    vm.checkAndHandleDayChange(now: tomorrow)
    assertEqual(TimeFormatter.format(dateKey: vm.selectedDate), TimeFormatter.format(dateKey: tomorrow), "Advancing to tomorrow must update selectedDate")
}

@MainActor
func testTimeAndPauseMathVerification() {
    print("Running Time, Pause, and Break Math Invariant tests...")
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store)

    // 1. Exact fractional-second pause and zero-drift verification
    let t0 = Date()
    engine.clockIn(at: t0)

    let t1 = t0.addingTimeInterval(10.75) // Active: 10.75s
    engine.pause(at: t1)
    assertEqual(engine.state.currentElapsed, 10.75, "Elapsed at pause must match exact fractional work time")
    assertEqual(engine.totalCurrentSprintPaused, 0.0, "Pause just started, accumulated pause is 0")

    let t2 = t1.addingTimeInterval(2.50) // Pause 1: 2.50s
    engine.resume(at: t2)
    assertEqual(engine.totalCurrentSprintPaused, 2.50, "Paused duration must record exact 2.50s")
    assertEqual(engine.state.currentElapsed, 10.75, "Elapsed after resume must equal active time before pause")

    let t3 = t2.addingTimeInterval(7.15) // Active 2: 7.15s (gross 10.75 + 2.50 + 7.15 = 20.40s)
    engine.pause(at: t3)
    let expectedElapsedAtPause2 = 10.75 + 7.15
    assertEqual(round(engine.state.currentElapsed * 100) / 100, round(expectedElapsedAtPause2 * 100) / 100, "Second pause must preserve exact sum of active intervals (17.90s)")

    let t4 = t3.addingTimeInterval(3.70) // Pause 2: 3.70s (total pause 2.50 + 3.70 = 6.20s)
    engine.resume(at: t4)
    assertEqual(round(engine.totalCurrentSprintPaused * 100) / 100, 6.20, "Total paused duration must equal sum of pauses (6.20s)")

    let t5 = t4.addingTimeInterval(5.90) // Active 3: 5.90s (total wall clock: 30.00s)
    var completed: Sprint? = nil
    engine.onSprintCompleted = { completed = $0 }
    engine.clockOut(at: t5)

    assertTrue(completed != nil)
    // Gross: 30.0s. Paused: 6.2s. Net work: 23.8s.
    assertEqual(round((completed?.pausedDuration ?? 0) * 100) / 100, 6.20)
    assertEqual(round((completed?.duration ?? 0) * 100) / 100, 23.80)
    let expectedEffectiveEnd = t5.addingTimeInterval(-6.20)
    assertEqual(completed?.effectiveEnd, expectedEffectiveEnd)

    // 2. EffectiveEnd clamping invariant: effectiveEnd never precedes startTime
    let clampedSprint = Sprint(startTime: t0, endTime: t0.addingTimeInterval(100), pausedDuration: 150)
    assertEqual(clampedSprint.duration, 0.0, "Duration must clamp to 0 when pause exceeds gross duration")
    assertEqual(clampedSprint.effectiveEnd, t0, "EffectiveEnd must clamp to startTime when pause exceeds duration")

    // 3. Recovery validation: break duration exceeding sprint time must throw
    let openSprintWithPauses = Sprint(startTime: t0, pausedDuration: 600)
    store.save(sprint: openSprintWithPauses)
    engine.reload()
    guard case .recovery = engine.state else {
        assertTrue(false, "Engine must be in recovery")
        return
    }
    // Enter end time only 300s after start (5 min end, but 10 min pauses recorded)
    let invalidRecoveryEnd = TimeFormatter.format(time: t0.addingTimeInterval(300))
    var threwExpectedError = false
    do {
        try engine.saveRecoveryEndTime(invalidRecoveryEnd)
    } catch RecoveryError.breakExceedsSprintTime {
        threwExpectedError = true
    } catch {
        // other error
    }
    assertTrue(threwExpectedError, "Recovery must throw breakExceedsSprintTime when end time <= pause duration")
    engine.dismissRecovery()

    // 4. Manual entry validation: invalid break minutes text
    let vm = TimerViewModel(engine: engine, store: store)
    vm.openManualEntry()
    vm.manualStartText = "10:00:00"
    vm.manualEndText = "11:00:00"
    vm.manualBreakMinutesText = "-10" // negative break minutes
    assertFalse(vm.saveManualSprint(), "Negative break minutes must fail save")
    assertEqual(vm.manualEntryError, "Invalid break minutes")

    vm.manualBreakMinutesText = "abc" // non-numeric
    assertFalse(vm.saveManualSprint(), "Non-numeric break minutes must fail save")
    assertEqual(vm.manualEntryError, "Invalid break minutes")

    vm.manualBreakMinutesText = "15" // valid 15 min
    assertTrue(vm.saveManualSprint(), "Valid 15 min break must succeed")
    let savedManual = vm.todayLog.completedSprints.first { $0.startLabel == "10:00:00" }
    assertEqual(savedManual?.pausedDuration, 900.0)
    assertEqual(savedManual?.pauseCount, 1)
    assertEqual(savedManual?.duration, 2700.0)
}

// MARK: - Main Runner

@main
struct TestMain {
    static func main() async {
        print("========================================")
        print("Skeval Timer Architecture Verification")
        print("========================================")

        testAppVersion()
        testTimeFormatter()
        testDayLogStoreWithInMemoryStorage()
        testDailyTimesheetExport()
        await MainActor.run {
            testSprintEngine()
            testRapidPauseResumeCycles()
            testCrashRecoveryAndPausePersistence()
            testAppThemes()
            testGlobalHotkeys()
            testEarningsTracking()
            testManualSprintEntry()
            testPastDaysHistory()
            testPopoverHeightAndSizing()
            testAutomaticDayRollover()
            testTimeAndPauseMathVerification()
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
