import Foundation

func testPeriodPaceForecast() {
    let settings = auditSettings()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let now = auditDate(2026, 10, 21, calendar: calendar)
    let workDates = [1, 2, 5, 6, 7, 8, 9, 12].map {
        auditDate(2026, 10, $0, calendar: calendar)
    }
    let logs = Dictionary(uniqueKeysWithValues: workDates.map { date in
        (TimeFormatter.format(dateKey: date, calendar: calendar),
         [Sprint(startTime: date, endTime: date.addingTimeInterval(8 * 3600))])
    })
    let open = Sprint(startTime: now.addingTimeInterval(-2 * 3600))
    func monthly(_ state: SprintState = .idle, date: Date? = nil) -> PeriodPaceForecast {
        PeriodPaceForecast.calculate(logs: logs, period: .month, settings: settings,
                                     state: state, now: date ?? now, calendar: calendar)
    }

    let idle = monthly()
    assertEqual(idle.targetSeconds, 160 * 3600, "Monthly pacing uses the configured monthly goal")
    assertEqual(idle.clockedSeconds, 64 * 3600)
    assertEqual(idle.remainingSeconds, 96 * 3600)
    assertEqual(idle.remainingWorkingDays, 8, "Includes October 21 and excludes the October 31 weekend")
    assertEqual(idle.secondsPerWorkingDay, 12 * 3600)
    assertEqual(idle.extraSecondsPerWorkingDay, 4 * 3600)
    assertTrue(idle.includesToday)
    let active = monthly(.active(sprint: open, elapsed: 2 * 3600))
    assertEqual(active.clockedSeconds, 66 * 3600)
    assertEqual(active.secondsPerWorkingDay, 11.75 * 3600)
    assertEqual(monthly(.paused(sprint: open, elapsed: 2 * 3600)), active,
                "Paused work remains credited without accruing pause time")
    assertEqual(monthly(.recovery(sprint: open)), idle, "Unresolved recovery contributes no live work")
    assertEqual(monthly(.active(sprint: open, elapsed: .infinity)), idle)
    let previousMonth = Sprint(startTime: auditDate(2026, 9, 30, calendar: calendar))
    assertEqual(monthly(.active(sprint: previousMonth, elapsed: 2 * 3600)), idle,
                "An overnight sprint stays attributed to its start month")
    let future = Sprint(startTime: auditDate(2026, 10, 22, calendar: calendar))
    assertEqual(monthly(.active(sprint: future, elapsed: 2 * 3600)), idle,
                "Future-dated work cannot reduce the present forecast")

    settings.monthlyGoalHours = 20
    assertEqual(monthly().targetSeconds, 20 * 3600, "Monthly pacing follows changes to the monthly goal")
    assertEqual(monthly().remainingSeconds, 0, "Already exceeding the monthly goal needs no more work")
    settings.monthlyGoalHours = 160
    settings.daysOff = [TimeFormatter.format(dateKey: now, calendar: calendar)]
    assertEqual(monthly().targetSeconds, 160 * 3600)
    assertEqual(monthly().remainingWorkingDays, 7)
    assertFalse(monthly().includesToday)
    settings.daysOff = [TimeFormatter.format(dateKey: workDates[0], calendar: calendar)]
    assertEqual(monthly().clockedSeconds, idle.clockedSeconds, "Work on a day off remains credited")
    assertEqual(monthly().secondsPerWorkingDay, 12 * 3600)
    settings.daysOff = []

    let endOfMonth = monthly(date: auditDate(2026, 10, 31, calendar: calendar))
    assertEqual(endOfMonth.remainingWorkingDays, 0)
    assertEqual(endOfMonth.secondsPerWorkingDay, nil, "No working days left must not divide by zero")
    assertTrue(endOfMonth.exceedsCapacity)
    let nextMonth = monthly(date: auditDate(2026, 11, 1, calendar: calendar))
    assertEqual(nextMonth.clockedSeconds, 0, "Monthly pacing resets at the month boundary")
    assertEqual(nextMonth.targetSeconds, 160 * 3600)
    assertEqual(nextMonth.remainingWorkingDays, 21)
    assertFalse(nextMonth.includesToday, "November 1 is a Sunday")
    let reached = monthly(.active(sprint: open, elapsed: 120 * 3600))
    assertEqual(reached.remainingSeconds, 0)
    assertEqual(reached.secondsPerWorkingDay, 0)
    assertEqual(reached.extraSecondsPerWorkingDay, 0)

    settings.workingWeekdays = Set(1...7)
    let leapDay = monthly(date: auditDate(2028, 2, 29, calendar: calendar))
    assertEqual(leapDay.targetSeconds, 160 * 3600, "Leap-day month still uses the configured monthly goal")
    assertEqual(leapDay.remainingWorkingDays, 1)

    settings.workingWeekdays = [1]
    settings.dailyGoalHours = 24
    settings.monthlyGoalHours = 24
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    for (month, day, exceedsCapacity) in [(3, 8, true), (11, 1, false)] {
        let date = auditDate(2026, month, day, hour: 0, calendar: calendar)
        settings.daysOff = Set(CatchUpPeriod.month.dates(containing: date, calendar: calendar)
            .filter { !calendar.isDate($0, inSameDayAs: date) }
            .map { TimeFormatter.format(dateKey: $0, calendar: calendar) })
        let dst = monthly(date: date)
        assertEqual(dst.targetSeconds, 24 * 3600)
        assertEqual(dst.remainingWorkingDays, 1)
        assertEqual(dst.exceedsCapacity, exceedsCapacity, "Monthly capacity respects 23/25-hour DST days")
    }
}

@MainActor
func testPeriodPaceViewModel() {
    let settings = auditSettings()
    let store = DayLogStore(storage: InMemoryDayLogAdapter())
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store, goal: settings)
    let now = Date()
    let start = Calendar.current.startOfDay(for: now)
    engine.clockIn(at: start)
    engine.pause(at: start.addingTimeInterval(1800))
    let paused = vm.periodPaceForecast(for: .month, now: now)
    assertEqual(paused.clockedSeconds, 1800)
    engine.clockOut(at: start.addingTimeInterval(3600))
    assertEqual(vm.periodPaceForecast(for: .month, now: now).clockedSeconds, 1800,
                "Clocking out does not double-count monthly work")
    vm.delete(sprint: store.log(for: start).completedSprints[0])
    assertEqual(vm.periodPaceForecast(for: .month, now: now).clockedSeconds, 0,
                "Deleting a sprint refreshes monthly pacing")
}
