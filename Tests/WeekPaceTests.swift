import Foundation

func testWeekPace() {
    print("Running WeekPace tests...")
    let settings = auditSettings()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let hour: TimeInterval = 3600
    func day(_ d: Int, month: Int = 11) -> Date { auditDate(2026, month, d, hour: 0, calendar: calendar) }
    func work(_ d: Int, _ hours: Double, month: Int = 11, at startHour: Int = 7) -> (String, Sprint) {
        let start = auditDate(2026, month, d, hour: startHour, calendar: calendar)
        return (TimeFormatter.format(dateKey: start, calendar: calendar),
                Sprint(startTime: start, endTime: start.addingTimeInterval(hours * hour)))
    }
    func logs(_ entries: [(String, Sprint)]) -> [String: [Sprint]] {
        Dictionary(grouping: entries, by: \.0).mapValues { $0.map(\.1) }
    }
    let monday = day(9), now = auditDate(2026, 11, 10, hour: 14, calendar: calendar)
    func pace(_ l: [String: [Sprint]], week: Date = monday, state: SprintState = .idle, at: Date? = nil) -> WeekPace {
        WeekPace.calculate(logs: l, weekStart: week, settings: settings, state: state, now: at ?? now, calendar: calendar)
    }

    // Behind: Mon 4h, Tue 2h at 14:00 on Tuesday.
    let sample = logs([work(9, 4), work(10, 2)])
    let behind = pace(sample)
    assertTrue(behind.isCurrentWeek)
    assertEqual(behind.targetSeconds, 40 * hour, "The Weekly Goal setting")
    assertEqual(behind.plannedPerWorkingDay, 8 * hour, "40h spread over five scheduled workdays")
    assertEqual(behind.workedSeconds, 6 * hour)
    assertEqual(behind.expectedSeconds, 16 * hour, "Monday and Tuesday are expected by today")
    assertEqual(behind.status, .behind(10 * hour), "Behind schedule is expected minus worked, not the remaining goal")
    assertEqual(behind.remainingSeconds, 34 * hour)
    assertEqual(behind.remainingWorkingDays, 4, "Tuesday to Friday, including today")
    assertTrue(behind.includesToday)
    assertEqual(behind.workedTodaySeconds, 2 * hour)
    assertEqual(behind.neededPerWorkingDay, 9 * hour, "36h left after Monday over four days, today's 2h included")
    assertEqual(behind.neededMoreToday, 7 * hour, "Today's 9h share minus the 2h already worked")
    assertEqual(behind.neededVersusGoal, 1 * hour)
    assertEqual(behind.paceSoFar, 3 * hour, "6h over two scheduled workdays")
    assertTrue(behind.exceedsCapacity, "34h does not fit in four 8h workdays")

    // Ahead and reached.
    let ahead = pace(logs([work(9, 9.5), work(10, 7)]))
    assertEqual(ahead.status, .ahead(0.5 * hour))
    assertFalse(ahead.exceedsCapacity)
    assertEqual(pace(logs([work(9, 8), work(10, 8)])).status, .onSchedule)
    assertEqual(pace(logs([work(9, 8), work(10, 8 - 30.0 / 3600)])).status, .onSchedule, "30 seconds behind is on schedule")
    assertEqual(pace(logs([work(9, 8), work(10, 8 + 30.0 / 3600)])).status, .onSchedule, "30 seconds ahead is on schedule")
    assertEqual(pace(logs([work(9, 8), work(10, 7)])).status, .behind(hour))
    let reached = pace(logs([work(9, 20), work(10, 20, at: 0)]))
    assertEqual(reached.status, .reached)
    assertEqual(reached.neededPerWorkingDay, nil, "A reached target needs no more work")

    // The active sprint counts; a paused one keeps its net work.
    let open = Sprint(startTime: auditDate(2026, 11, 10, hour: 12, calendar: calendar))
    let active = pace(sample, state: .active(sprint: open, elapsed: hour))
    assertEqual(active.workedSeconds, 7 * hour)
    assertEqual(active.workedTodaySeconds, 3 * hour, "The active sprint counts toward today")
    assertEqual(active.neededPerWorkingDay, 9 * hour)
    assertEqual(active.neededMoreToday, 6 * hour)

    // Today already passed its share: nothing more today, the rest spreads over later days.
    let longToday = pace(logs([work(9, 4), work(10, 12)]))
    assertEqual(longToday.neededPerWorkingDay, 8 * hour, "24h left over Wednesday to Friday")
    assertEqual(longToday.neededMoreToday, 0)
    assertEqual(pace(sample, state: .paused(sprint: open, elapsed: hour)), active,
                "Paused work stays credited without counting pause time")
    assertEqual(pace(sample, state: .recovery(sprint: open)), behind, "Recovery adds no live work")

    // Today is a day off: the weekly goal spreads over the four other workdays.
    settings.daysOff = [TimeFormatter.format(dateKey: day(10), calendar: calendar)]
    let todayOff = pace(sample)
    assertEqual(todayOff.targetSeconds, 40 * hour, "A day off does not change the Weekly Goal")
    assertEqual(todayOff.plannedPerWorkingDay, 10 * hour)
    assertFalse(todayOff.includesToday)
    assertEqual(todayOff.remainingWorkingDays, 3)
    assertEqual(todayOff.workingDaysElapsed, 1)
    assertEqual(todayOff.expectedSeconds, 10 * hour)
    assertEqual(todayOff.workedSeconds, 6 * hour, "Work on a day off still counts")
    assertEqual(todayOff.status, .behind(4 * hour))
    assertEqual(todayOff.neededPerWorkingDay, 34 * hour / 3)
    assertEqual(todayOff.neededMoreToday, nil, "Today is not scheduled")

    // Monday is a day off: its work counts, but pace so far divides by Tuesday only.
    settings.daysOff = [TimeFormatter.format(dateKey: monday, calendar: calendar)]
    let mondayOff = pace(sample)
    assertEqual(mondayOff.workedSeconds, 6 * hour)
    assertEqual(mondayOff.paceSoFar, 6 * hour)
    assertEqual(mondayOff.status, .behind(4 * hour))
    settings.daysOff = []

    // A Weekly Goal that differs from five daily goals drives every figure.
    settings.weeklyGoalHours = 30
    let lighter = pace(sample)
    assertEqual(lighter.targetSeconds, 30 * hour)
    assertEqual(lighter.plannedPerWorkingDay, 6 * hour)
    assertEqual(lighter.expectedSeconds, 12 * hour, "Two of five workdays at 6h")
    assertEqual(lighter.status, .behind(6 * hour))
    assertEqual(lighter.neededPerWorkingDay, 6.5 * hour)
    assertEqual(lighter.neededMoreToday, 4.5 * hour)
    assertEqual(lighter.neededVersusGoal, -1.5 * hour, "Compared with the 8h daily goal")
    assertFalse(lighter.exceedsCapacity)
    settings.weeklyGoalHours = 40

    // Work dated after today does not count yet.
    assertEqual(pace(logs([work(9, 4), work(10, 2), work(12, 3)])).workedSeconds, 6 * hour)

    // Past weeks are measured against their whole schedule.
    let lastWeek = logs((2...6).map { work($0, 5) })
    let missed = pace(lastWeek, week: day(2))
    assertFalse(missed.isCurrentWeek)
    assertEqual(missed.status, .missed(15 * hour))
    assertEqual(missed.paceSoFar, 5 * hour)
    assertEqual(missed.plannedPerWorkingDay, 8 * hour)
    assertEqual(missed.workedTodaySeconds, 0)
    assertEqual(missed.neededPerWorkingDay, nil, "Past weeks have no remaining days")
    assertFalse(missed.exceedsCapacity)
    assertEqual(pace(logs((2...6).map { work($0, 8) }), week: day(2)).status, .met)
    assertEqual(pace(lastWeek, week: day(4)), missed, "Any date in the week selects the same week")

    // A sprint started late on Sunday belongs to that week, even after midnight.
    let overnight = Sprint(startTime: auditDate(2026, 11, 8, hour: 23, calendar: calendar))
    let afterMidnight = auditDate(2026, 11, 9, hour: 1, calendar: calendar)
    let running = SprintState.active(sprint: overnight, elapsed: 2 * hour)
    assertEqual(pace(lastWeek, week: day(2), state: running, at: afterMidnight).workedSeconds, 27 * hour)
    assertEqual(pace(lastWeek, week: monday, state: running, at: afterMidnight).workedSeconds, 0,
                "The new week does not get Sunday's sprint")

    // The week of the US daylight-saving change keeps all seven days.
    var newYork = Calendar(identifier: .gregorian)
    newYork.timeZone = TimeZone(identifier: "America/New_York")!
    let dstStart = auditDate(2026, 10, 26, hour: 0, calendar: newYork)
    let sunday = auditDate(2026, 11, 1, hour: 9, calendar: newYork)
    let dstLogs = [TimeFormatter.format(dateKey: sunday, calendar: newYork):
                   [Sprint(startTime: sunday, endTime: sunday.addingTimeInterval(hour))]]
    let dst = WeekPace.calculate(logs: dstLogs, weekStart: dstStart, settings: settings, state: .idle,
                                 now: auditDate(2026, 11, 10, calendar: newYork), calendar: newYork)
    assertEqual(dst.workedSeconds, hour, "Sunday 1 November is still in the week")
    assertEqual(dst.targetSeconds, 40 * hour)
}
