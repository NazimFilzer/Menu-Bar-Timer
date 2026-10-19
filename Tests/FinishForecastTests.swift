import Foundation

func testFinishForecast() {
    let settings = auditSettings()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let monday = auditDate(2026, 10, 12, hour: 0, calendar: calendar)
    let now = auditDate(2026, 10, 13, hour: 14, calendar: calendar)
    let todayKey = TimeFormatter.format(dateKey: now, calendar: calendar)
    let mondayKey = TimeFormatter.format(dateKey: monday, calendar: calendar)
    let completed = Sprint(startTime: now.addingTimeInterval(-4 * 3600),
                           endTime: now.addingTimeInterval(-3600), pausedDuration: 3600)
    let earlier = Sprint(startTime: monday, endTime: monday.addingTimeInterval(4 * 3600))
    let open = Sprint(startTime: now.addingTimeInterval(-3600))
    var logs = [todayKey: [completed, open], mondayKey: [earlier]]
    func forecast(_ state: SprintState = .idle, breaks: Int = 0, held: Bool = false,
                  date: Date? = nil) -> FinishForecast {
        FinishForecast.calculate(logs: logs, settings: settings, state: state,
                                 sleepHeld: held, plannedBreakMinutes: breaks,
                                 now: date ?? now, calendar: calendar)
    }

    let idle = forecast()
    assertEqual(idle.status, .startNow)
    assertEqual(idle.remainingToday, 6 * 3600, "Completed time excludes pauses and open records")
    assertEqual(idle.finishDate, now.addingTimeInterval(6 * 3600))
    assertEqual(idle.weeklyRemaining, 34 * 3600)
    assertEqual(idle.remainingWorkingDays, 4)
    assertEqual(idle.weeklySecondsPerDay, 8.5 * 3600)
    assertEqual(idle.extraSecondsPerWorkingDay, 1800)
    assertTrue(idle.includesToday)
    assertFalse(idle.finishesAfterToday)

    let active = forecast(.active(sprint: open, elapsed: 3600), breaks: 30)
    assertEqual(active.status, .working)
    assertEqual(active.remainingToday, 5 * 3600)
    assertEqual(active.finishDate, now.addingTimeInterval(5.5 * 3600))
    assertEqual(active.weeklyRemaining, 33 * 3600)
    assertEqual(active.plannedBreak, 1800)
    let paused = forecast(.paused(sprint: open, elapsed: 3600), breaks: 30)
    assertEqual(paused.status, .resumeNow)
    assertEqual(paused.finishDate, active.finishDate, "Taken pauses are not added again")
    let later = forecast(.paused(sprint: open, elapsed: 3600), breaks: 30, date: now.addingTimeInterval(600))
    assertEqual(later.finishDate, active.finishDate?.addingTimeInterval(600), "Paused conditional finish drifts with wall time")
    let ticking = forecast(.active(sprint: open, elapsed: 3660), breaks: 30, date: now.addingTimeInterval(60))
    assertEqual(ticking.finishDate, active.finishDate, "Uninterrupted work keeps its projected finish")
    let held = forecast(.paused(sprint: open, elapsed: 3600), held: true)
    assertEqual(held.status, .sleepHeld)
    assertEqual(held.finishDate, nil)
    assertEqual(held.weeklyRemaining, active.weeklyRemaining, "Known pre-sleep work still counts")
    let recovery = forecast(.recovery(sprint: open))
    assertEqual(recovery.status, .recovery)
    assertEqual(recovery.finishDate, nil)
    assertEqual(recovery.remainingToday, idle.remainingToday)
    assertEqual(recovery.weeklyRemaining, idle.weeklyRemaining)
    let reached = forecast(.active(sprint: open, elapsed: 7 * 3600), breaks: 30)
    assertEqual(reached.status, .goalReached)
    assertEqual(reached.remainingToday, 0)
    assertEqual(reached.finishDate, nil, "Breaks cannot delay an already-reached goal")
    assertEqual(forecast(breaks: -1).plannedBreak, 0)
    assertEqual(forecast(breaks: Int.max).plannedBreak, 4 * 3600)
    assertEqual(forecast(.active(sprint: open, elapsed: .infinity)).remainingToday, idle.remainingToday)

    let overnight = Sprint(startTime: monday.addingTimeInterval(23 * 3600))
    let priorDay = forecast(.active(sprint: overnight, elapsed: 3600))
    assertEqual(priorDay.status, .previousDaySprint)
    assertEqual(priorDay.finishDate, nil)
    assertEqual(priorDay.remainingToday, idle.remainingToday)
    assertEqual(priorDay.weeklyRemaining, 33 * 3600, "Same-week prior-day live work reduces weekly target only")
    assertEqual(forecast(.paused(sprint: overnight, elapsed: 3600)).status, .previousDaySprint)
    let previousWeek = Sprint(startTime: monday.addingTimeInterval(-3600))
    assertEqual(forecast(.active(sprint: previousWeek, elapsed: 3600)).weeklyRemaining, idle.weeklyRemaining)
    let late = auditDate(2026, 10, 13, hour: 23, calendar: calendar)
    assertTrue(forecast(date: late).finishesAfterToday)
    assertEqual(forecast(date: late).finishDate, late.addingTimeInterval(6 * 3600))
    settings.weeklyGoalHours = 12
    assertEqual(forecast().weeklyRemaining, idle.weeklyRemaining, "Pace uses daily schedule, not weekly goal")
    settings.daysOff = [todayKey]
    assertEqual(forecast().remainingWorkingDays, 3)
    assertEqual(forecast().weeklyRemaining, 26 * 3600, "A day off removes expected hours but not credited work")
    assertFalse(forecast().includesToday)
    settings.daysOff = []
    let saturday = auditDate(2026, 10, 17, calendar: calendar)
    assertEqual(forecast(date: saturday).remainingWorkingDays, 0)
    assertEqual(forecast(date: saturday).weeklySecondsPerDay, nil)
    assertTrue(forecast(date: saturday).exceedsWeeklyCapacity)
    settings.workingWeekdays.insert(7)
    assertEqual(forecast(date: saturday).remainingWorkingDays, 1)
    settings.workingWeekdays = [2, 3, 4, 5, 6]
    let fridayLate = auditDate(2026, 10, 16, hour: 23, calendar: calendar)
    assertTrue(forecast(date: fridayLate).exceedsWeeklyCapacity, "Warning refers only to scheduled-day clock time")
    logs = [:]
    settings.daysOff = Set(CatchUpPeriod.week.dates(containing: now, calendar: calendar).map {
        TimeFormatter.format(dateKey: $0, calendar: calendar)
    })
    assertEqual(forecast().weeklyRemaining, 0)
    assertEqual(forecast().weeklySecondsPerDay, nil)
    assertFalse(forecast().exceedsWeeklyCapacity)

    settings.daysOff = []
    settings.workingWeekdays = [1]
    settings.dailyGoalHours = 24
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let spring = auditDate(2026, 3, 8, hour: 0, calendar: calendar)
    assertTrue(forecast(date: spring).exceedsWeeklyCapacity, "Spring-forward Sunday contains 23 calendar hours")
    assertEqual(forecast(date: spring).finishDate, spring.addingTimeInterval(24 * 3600))
    assertTrue(forecast(date: spring).finishesAfterToday)
    let fall = auditDate(2026, 11, 1, hour: 0, calendar: calendar)
    assertFalse(forecast(date: fall).exceedsWeeklyCapacity, "Fall-back Sunday contains 25 calendar hours")
    assertFalse(forecast(date: fall).finishesAfterToday)
}

@MainActor
func testFinishForecastViewModel() {
    let settings = auditSettings()
    let store = DayLogStore(storage: InMemoryDayLogAdapter())
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store, goal: settings)
    let now = Date()
    let start = Calendar.current.startOfDay(for: now)
    engine.clockIn(at: start)
    engine.pause(at: start.addingTimeInterval(1800))
    vm.plannedBreakMinutes = 20
    let paused = vm.finishForecast(now: now)
    assertEqual(paused.status, .resumeNow)
    assertEqual(paused.remainingToday, settings.dailyGoalSeconds - 1800)
    assertEqual(paused.plannedBreak, 1200)
    engine.clockOut(at: start.addingTimeInterval(3600))
    assertEqual(vm.finishForecast(now: now).remainingToday, paused.remainingToday, "Clock-out doesn't double-count")
    let sprint = store.log(for: start).completedSprints.first!
    vm.delete(sprint: sprint)
    assertEqual(vm.finishForecast(now: now).remainingToday, settings.dailyGoalSeconds, "CRUD refreshes projection")
    settings.dailyGoalHours = 7
    assertEqual(vm.finishForecast(now: now).remainingToday, 7 * 3600, "Goal edits refresh projection")
    engine.clockIn(at: start)
    engine.handleSystemSleep(at: start.addingTimeInterval(1800))
    assertEqual(vm.finishForecast(now: now).status, .sleepHeld, "Sleep is held even before wake")
    assertEqual(vm.finishForecast(now: now).finishDate, nil)
    engine.handleSystemWake(at: start.addingTimeInterval(2400))
    assertEqual(vm.finishForecast(now: now).status, .sleepHeld, "Wake waits for classification")
    engine.resolveSleepInterval(countAsWork: false, at: start.addingTimeInterval(3000))
    assertEqual(vm.finishForecast(now: now).status, .working)
    assertEqual(vm.finishForecast(now: now).remainingToday, 7 * 3600 - 1800)
    engine.clockOut(at: start.addingTimeInterval(3000))
    vm.checkAndHandleDayChange(now: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
    assertEqual(vm.plannedBreakMinutes, 0, "Break allowance resets on day rollover")
}
