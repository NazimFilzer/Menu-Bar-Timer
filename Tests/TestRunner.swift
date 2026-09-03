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
            testAppThemes()
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
