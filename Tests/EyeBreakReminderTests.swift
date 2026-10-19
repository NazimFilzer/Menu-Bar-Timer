import Foundation

@MainActor
func testEyeBreakReminders() {
    let suite = "skeval-eye-break-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = EyeBreakSettings(userDefaults: defaults)
    assertFalse(settings.isEnabled, "Eye reminders are opt-in")
    assertEqual(settings.intervalMinutes, 20)
    settings.isEnabled = true
    settings.intervalMinutes = 30
    let restored = EyeBreakSettings(userDefaults: defaults)
    assertTrue(restored.isEnabled)
    assertEqual(restored.intervalMinutes, 30)
    settings.intervalMinutes = 0
    assertEqual(settings.intervalMinutes, 30, "Reject unsupported intervals")
    defaults.set(999, forKey: "skevalEyeBreakIntervalMinutes")
    assertEqual(EyeBreakSettings(userDefaults: defaults).intervalMinutes, 20)

    var reminder = EyeBreakReminder()
    reminder.restart(at: 0, settings: settings)
    assertFalse(reminder.isDue(at: 1799, settings: settings))
    assertTrue(reminder.isDue(at: 1800, settings: settings))
    assertFalse(reminder.isDue(at: 1800, settings: settings), "No duplicate notification")
    assertTrue(reminder.isDue(at: 10000, settings: settings), "Late tick sends just one")
    assertFalse(reminder.isDue(at: 10001, settings: settings), "No catch-up burst")
    settings.intervalMinutes = 45
    assertFalse(reminder.isDue(at: 10002, settings: settings), "Configuration restarts interval")
    assertFalse(reminder.isDue(at: 12701, settings: settings))
    assertTrue(reminder.isDue(at: 12702, settings: settings))
    settings.isEnabled = false
    assertFalse(reminder.isDue(at: 20000, settings: settings))
    settings.isEnabled = true
    assertFalse(reminder.isDue(at: 20001, settings: settings))
    assertFalse(reminder.isDue(at: 0, settings: settings), "Backward time resets baseline")

    let store = DayLogStore(storage: InMemoryDayLogAdapter())
    let engine = SprintEngine(store: store, observeWorkspace: false)
    var delivered = 0
    settings.intervalMinutes = 30
    let vm = TimerViewModel(engine: engine, store: store, eyeBreakSettings: settings,
                            deliverEyeBreakNotification: { delivered += 1 })
    let start = Date()
    engine.clockIn(at: start)
    engine.onTick?(1799)
    assertEqual(delivered, 0)
    engine.setTag("Focus")
    vm.checkAndHandleDayChange(now: start.addingTimeInterval(86400))
    // Match the engine's production callback order: state update, then tick.
    engine.onStateChanged?(.active(sprint: engine.state.currentSprint!, elapsed: 1800))
    engine.onTick?(1800)
    assertEqual(delivered, 1)
    engine.onTick?(1800)
    assertEqual(delivered, 1)
    engine.pause(at: start.addingTimeInterval(1801))
    engine.onTick?(10000)
    assertEqual(delivered, 1, "Paused ticks cannot notify")
    engine.resume(at: start.addingTimeInterval(5000))
    engine.onTick?(3600)
    assertEqual(delivered, 1, "Resume starts fresh interval")
    engine.onTick?(3601)
    assertEqual(delivered, 2)
    engine.handleSystemSleep(at: start.addingTimeInterval(6800))
    engine.handleSystemWake(at: start.addingTimeInterval(16800))
    engine.onTick?(20000)
    assertEqual(delivered, 2, "Sleep-held time does not notify")
    engine.resolveSleepInterval(countAsWork: true, at: start.addingTimeInterval(17000))
    let resumedElapsed = engine.state.currentElapsed
    engine.onTick?(resumedElapsed + 1799)
    assertEqual(delivered, 2, "Counting sleep as work does not cause catch-up reminder")
    engine.onTick?(resumedElapsed + 1800)
    assertEqual(delivered, 3)
    vm.updateEyeBreakInterval(45)
    engine.onTick?(vm.currentElapsed + 2699)
    assertEqual(delivered, 3)
    vm.updateEyeBreakEnabled(false)
    engine.onTick?(vm.currentElapsed + 10000)
    assertEqual(delivered, 3)
    vm.updateEyeBreakEnabled(true)
    engine.clockOut(at: start.addingTimeInterval(30000))
    engine.onTick?(100000)
    assertEqual(delivered, 3, "Clocked-out ticks cannot notify")
    engine.clockIn(at: start.addingTimeInterval(31000))
    engine.onTick?(2700)
    assertEqual(delivered, 4, "New sprint has a fresh interval")
    engine.reset()
}
