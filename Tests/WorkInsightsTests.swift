import Foundation

func testGoalConsistencyIncludesWeekendWork() {
    let settings = auditSettings()
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let monday = auditDate(2026, 10, 26, calendar: cal)
    let saturday = auditDate(2026, 10, 31, calendar: cal)
    let sunday = auditDate(2026, 11, 1, calendar: cal)
    let now = auditDate(2026, 11, 2, calendar: cal)
    let workedSaturday = Sprint(startTime: saturday, endTime: saturday.addingTimeInterval(9 * 3600), pausedDuration: 3600)
    let workedSunday = Sprint(startTime: sunday, endTime: sunday.addingTimeInterval(3 * 3600))
    let seededLogs = [TimeFormatter.format(dateKey: saturday, calendar: cal): [workedSaturday],
                      TimeFormatter.format(dateKey: sunday, calendar: cal): [workedSunday]]
    let store = DayLogStore(storage: InMemoryDayLogAdapter(initialLogs: seededLogs))
    let before = store.allLogs()
    func calculate(_ end: Date = sunday) -> GoalConsistency {
        GoalConsistency.calculate(logs: store.allLogs(), startDate: monday, endDate: end,
                                  settings: settings, now: now, calendar: cal)
    }
    let result = calculate()
    assertEqual(result.countedDays, 5, "Scheduled working weekdays form the rate denominator; weekend work is extra time")
    assertEqual(result.metDays, 1, "Saturday reaches eight net hours after its pause and counts as an extra met goal")
    assertEqual(result.weeks[0].countedDays, 5, "Week denominator is five scheduled weekdays")
    assertEqual(result.weeks[0].days[5].status, .met)
    assertEqual(result.weeks[0].days[6].status, .extraTime, "Sunday partial work is extra time, not belowGoal")
    settings.daysOff = [TimeFormatter.format(dateKey: saturday, calendar: cal)]
    assertEqual(calculate().countedDays, 5, "Work on a marked day off is extra time and does not inflate scheduled working days")
    assertEqual(calculate(now).countedDays, 5, "Today (Monday, in progress) and later days are not in the rate yet")
    assertEqual(calculate(now).weeks.last?.countedDays, 0, "A week with only today so far has no finished days")
    assertEqual(calculate(now).weeks.last?.days.first?.status, .inProgress)
    assertEqual(store.allLogs(), before, "Report calculations never change stored sprints")

    let empty = GoalConsistency.calculate(logs: [:], startDate: monday, endDate: sunday,
                                          settings: settings, now: now, calendar: cal)
    assertEqual(empty.countedDays, 5, "Unworked weekends do not create missed goals")
    assertEqual(empty.weeks[0].days[5].status, .excluded)
    settings.daysOff = []
    settings.workingWeekdays = Set(1...7)
    assertEqual(GoalConsistency.calculate(logs: [:], startDate: monday, endDate: sunday,
                                         settings: settings, now: now, calendar: cal).countedDays, 7)
    let partial = GoalConsistency.calculate(logs: before, startDate: saturday, endDate: sunday,
                                            settings: settings, now: now, calendar: cal)
    assertEqual(partial.countedDays, 7, "A 7-day scheduled week retains its full scheduled count")
    assertEqual(partial.weeks[0].days[0].status, .belowGoal, "Week 1 starts on Monday Oct 26 and includes the full week")
    assertEqual(partial.weeks[0].days[5].status, .met, "Saturday in Week 1 shows its recorded met goal")
    let future = now.addingTimeInterval(7 * 86400)
    assertTrue(GoalConsistency.calculate(logs: before, startDate: future, endDate: future,
                                        settings: settings, now: now, calendar: cal).weeks.isEmpty)
}

func testSprintPatternsUseNetCompletedWork() {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let lengths: [TimeInterval] = [0, 15, 30, 45, 60, 90].map { $0 * 60 }
    let sprints = lengths.map { Sprint(startTime: start, endTime: start.addingTimeInterval($0 + 300),
                                       pausedDuration: 300, pauseCount: 1) }
    let result = SprintPatterns.calculate(sprints: sprints + [Sprint(startTime: start)])
    assertEqual(result.count, 6, "Open sprints do not enter completed sprint patterns")
    assertEqual(result.medianSeconds, 37.5 * 60)
    assertEqual(result.meanSeconds, 40 * 60)
    assertEqual(result.longestSeconds, 90 * 60)
    assertEqual(result.buckets.map(\.count), [1, 1, 1, 1, 1, 1], "Exact bucket boundaries count once")
    assertEqual(result.pausedSprintCount, 6)
    assertEqual(result.meanPausedSeconds, 300)
    assertEqual(result.meanPauseCount, 1)
    assertEqual(SprintPatterns.calculate(sprints: Array(sprints.prefix(3))).medianSeconds, 15 * 60)
    let empty = SprintPatterns.calculate(sprints: [])
    assertEqual(empty.count, 0)
    assertEqual(empty.medianSeconds, 0)
    assertEqual(empty.meanSeconds, 0)
    assertEqual(empty.buckets.map(\.count), [0, 0, 0, 0, 0, 0])
    // Old records can contain paused duration without a stored pause count.
    let legacy = Sprint(startTime: start, endTime: start.addingTimeInterval(600), pausedDuration: 120)
    assertEqual(SprintPatterns.calculate(sprints: [legacy]).pausedSprintCount, 1)
}

func testWeekComparisonBoundaries() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let now = auditDate(2026, 11, 1, hour: 12, calendar: cal) // Sunday
    let monday = auditDate(2026, 10, 26, hour: 0, calendar: cal)
    let saturday = auditDate(2026, 10, 31, hour: 22, calendar: cal)
    let priorSunday = auditDate(2026, 10, 25, hour: 10, calendar: cal)
    let prior = Sprint(startTime: priorSunday, endTime: priorSunday.addingTimeInterval(4 * 3600),
                       pausedDuration: 3600, pauseCount: 1)
    let overnight = Sprint(startTime: saturday, endTime: saturday.addingTimeInterval(3 * 3600))
    let live = Sprint(startTime: now.addingTimeInterval(-3600))
    let seededLogs = Dictionary(grouping: [prior, overnight, live]) {
        TimeFormatter.format(dateKey: $0.startTime, calendar: cal)
    }
    let store = DayLogStore(storage: InMemoryDayLogAdapter(initialLogs: seededLogs))
    func comparison(_ cut: Bool = true, liveSprint: Sprint? = live) -> WeekComparison {
        WeekComparison.calculate(logs: store.allLogs(), weekStart: monday, now: now,
                                 compareClockTime: cut, liveSprint: liveSprint, liveElapsed: 1800, calendar: cal)
    }
    let cut = comparison()
    assertEqual(cut.days.count, 7, "Sunday comparison includes the whole calendar week")
    assertEqual(cut.currentSeconds, 3.5 * 3600, "Weekend work and live net work count")
    assertEqual(cut.days[5].currentSeconds, 3 * 3600, "Overnight work stays on its start day")
    assertEqual(cut.previousSeconds, 1.5 * 3600, "A cut through a paused sprint prorates net work")
    assertTrue(cut.isEstimated)
    assertEqual(comparison(false).previousSeconds, 3 * 3600)
    assertFalse(comparison(false).isEstimated)
    assertEqual(comparison(liveSprint: nil).currentSeconds, 3 * 3600, "Recovery can be excluded by the caller")
    let future = cal.date(byAdding: .day, value: 7, to: monday)!
    assertTrue(WeekComparison.calculate(logs: [:], weekStart: future, now: now, calendar: cal).days.isEmpty)
    let historical = WeekComparison.calculate(logs: store.allLogs(), weekStart: monday,
                                              now: now.addingTimeInterval(8 * 86400), calendar: cal)
    assertFalse(historical.isCurrentWeek)
    assertEqual(historical.currentSeconds, 3 * 3600, "Historical comparisons exclude unresolved sprints")
}

func testWorkInsightsCalendarTransitions() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/New_York")!
    let settings = auditSettings()
    settings.workingWeekdays = Set(1...7)
    for (year, month, day) in [(2026, 3, 8), (2026, 11, 1), (2027, 1, 3)] {
        let sunday = auditDate(year, month, day, hour: 12, calendar: cal)
        let monday = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: sunday))!
        let priorSunday = cal.date(byAdding: .day, value: -7, to: sunday)!
        let sprint = Sprint(startTime: priorSunday.addingTimeInterval(-3600), endTime: priorSunday.addingTimeInterval(3600))
        let logs = [TimeFormatter.format(dateKey: priorSunday, calendar: cal): [sprint]]
        let comparison = WeekComparison.calculate(logs: logs, weekStart: monday, now: sunday, calendar: cal)
        assertEqual(comparison.days.count, 7)
        assertEqual(comparison.previousSeconds, 3600, "Clock cuts follow local time across DST and years")
        let goal = GoalConsistency.calculate(logs: [:], startDate: monday, endDate: sunday,
                                             settings: settings, now: sunday, calendar: cal)
        assertEqual(goal.weeks.count, 1)
        assertEqual(goal.weeks.first?.days.count, 7, "Calendar stepping keeps all seven days in the week")
        assertEqual(goal.countedDays, 6, "Six finished scheduled days; Sunday (today) is still in progress")
    }
}

func testTagsMatchIgnoringCase() {
    let settings = auditSettings()
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let day1 = auditDate(2026, 10, 5, calendar: cal)
    let day2 = auditDate(2026, 10, 6, calendar: cal)
    let sprints = [Sprint(startTime: day1, endTime: day1.addingTimeInterval(3600), tag: "Dev"),
                   Sprint(startTime: day2, endTime: day2.addingTimeInterval(7200), tag: " dev "),
                   Sprint(startTime: day2.addingTimeInterval(9000), endTime: day2.addingTimeInterval(9000 + 1800), tag: "  ")]
    var logs: [String: [Sprint]] = [:]
    for sprint in sprints { logs[TimeFormatter.format(dateKey: sprint.startTime, calendar: cal), default: []].append(sprint) }
    let month = MonthlyAnalytics.calculate(logs: logs, referenceDate: day2, settings: settings, calendar: cal)
    assertEqual(month.tagBreakdowns.map(\.displayName), ["Dev", "Untagged"], "Dev and dev are one tag; blank is untagged")
    assertEqual(month.tagBreakdowns.first?.totalSeconds, 3 * 3600, "Both spellings add up under the first spelling")
    assertEqual(month.allDistinctTags, ["Dev"], "Tag chips match the filter's case-insensitive rule")
    assertEqual(month.tagBreakdowns.first.map { tag in sprints.filter { TagFilter.tag(tag.displayName).matches(sprint: $0) }.count }, 2,
                "Filter and breakdown count the same sprints")
}
