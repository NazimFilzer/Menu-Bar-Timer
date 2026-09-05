import Foundation

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

// MARK: - Main Runner

@main
struct TestMain {
    static func main() async {
        print("========================================")
        print("Skeval Timer Architecture Verification")
        print("========================================")

        testTimeFormatter()
        testDayLogStoreWithInMemoryStorage()
        await MainActor.run {
            testSprintEngine()
            testRapidPauseResumeCycles()
            testCrashRecoveryAndPausePersistence()
            testAppThemes()
            testGlobalHotkeys()
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
