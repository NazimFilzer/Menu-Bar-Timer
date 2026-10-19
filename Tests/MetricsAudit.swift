import Foundation
import AppKit

private var auditSuiteNames: [String] = []

func cleanUpAuditSettings() {
    for name in auditSuiteNames { UserDefaults.standard.removePersistentDomain(forName: name) }
}

func auditSettings() -> GoalSettings {
    let name = "skeval-audit-\(UUID().uuidString)"
    auditSuiteNames.append(name)
    let defaults = UserDefaults(suiteName: name)!
    return GoalSettings(userDefaults: defaults)
}

func auditDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, calendar: Calendar = .current) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

func testMetricsAudit() {
    print("Running metrics boundary and persistence audit...")
    let settings = auditSettings()
    settings.hourlyRate = 1234.56
    settings.currencySymbol = "$"
    settings.dailyGoalHours = 1.2
    assertEqual(settings.goalLabel, "1h 12m", "Goal labels avoid floating-point minute truncation")
    settings.dailyGoalHours = 8
    assertEqual(TimeFormatter.format(shortDuration: 45), "45s", "Subminute work remains visible")

    // Every day must occur exactly once, including leap years starting on Sunday.
    for year in 2000...2040 {
        let lastDay = auditDate(year, 12, 31)
        let sprint = Sprint(startTime: lastDay, endTime: lastDay.addingTimeInterval(3600))
        let matrix = InsightsAnalytics.generateAnnualHeatmap(
            logs: [TimeFormatter.format(dateKey: lastDay): [sprint]], year: year, settings: settings)
        let cells = matrix.columns.flatMap { $0 }.filter(\.isInSelectedYear)
        let expectedDays = Calendar.current.range(of: .day, in: .year, for: lastDay)!.count
        assertEqual(Set(cells.map(\.id)).count, expectedDays, "Heatmap covers the whole year \(year)")
        assertEqual(matrix.totalYearSeconds, 3600, "December 31 contributes to year \(year)")
    }

    let oldDate = Calendar.current.date(byAdding: .year, value: -8, to: Date())!
    let allTime = DateRangePreset.allTime.dateRange(earliestDate: oldDate)
    assertTrue(allTime.start <= oldDate, "All Time must include records older than five years")

    let day = auditDate(2026, 2, 10)
    let untagged = Sprint(startTime: day, endTime: day.addingTimeInterval(3600))
    let namedUntagged = Sprint(startTime: day.addingTimeInterval(7200), endTime: day.addingTimeInterval(9000), tag: "Untagged")
    let month = MonthlyAnalytics.calculate(logs: [TimeFormatter.format(dateKey: day): [untagged, namedUntagged]],
                                           referenceDate: day, settings: settings)
    assertEqual(month.tagBreakdowns.count, 2, "The literal Untagged tag is separate from no tag")
    assertEqual(Set(month.tagBreakdowns.map(\.id)).count, 2, "Tag chart identities do not collide")
    assertEqual(month.monthOverMonth.formattedPercentageChange, "N/A", "Growth from zero has no percentage denominator")

    let emptySprint = Sprint(startTime: day, endTime: day)
    let period = InsightsAnalytics.calculatePeriodSummary(
        logs: [TimeFormatter.format(dateKey: day): [emptySprint]], startDate: day, endDate: day, settings: settings)
    assertEqual(period.activeDaysCount, 0, "A zero-work record does not count as an active day")

    // Supplied calendars must control day keys, not the machine's time zone.
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!
    let zoneDay = auditDate(2026, 1, 1, hour: 0, calendar: calendar)
    let zoneSprint = Sprint(startTime: zoneDay, endTime: zoneDay.addingTimeInterval(3600))
    let zoneLogs = ["2026-01-01": [zoneSprint]]
    let zoneMonth = MonthlyAnalytics.calculate(logs: zoneLogs, referenceDate: zoneDay, settings: settings, calendar: calendar)
    assertEqual(zoneMonth.days.first?.id, "2026-01-01")
    assertEqual(zoneMonth.days.first?.totalSeconds, 3600, "Month uses supplied calendar")
    let zonePeriod = InsightsAnalytics.calculatePeriodSummary(logs: zoneLogs, startDate: zoneDay, endDate: zoneDay,
                                                            settings: settings, calendar: calendar)
    assertEqual(zonePeriod.totalSeconds, 3600, "Period keys use supplied calendar")
    let reversed = InsightsAnalytics.calculatePeriodSummary(logs: zoneLogs,
        startDate: zoneDay.addingTimeInterval(86400 * 10), endDate: zoneDay, settings: settings, calendar: calendar)
    assertEqual(reversed.totalDaysCount, 11, "Reversed custom dates are normalized safely")
    assertEqual(reversed.totalSeconds, 3600)
    assertEqual(reversed.trendPoints.count, 11)

    var daylightCalendar = Calendar(identifier: .gregorian)
    daylightCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let springDay = auditDate(2026, 3, 8, calendar: daylightCalendar)
    assertTrue(TimeFormatter.parseTime("02:30", on: springDay, calendar: daylightCalendar) == nil,
               "Nonexistent spring-forward times are rejected")
    assertTrue(TimeFormatter.parseTime("03:30", on: springDay, calendar: daylightCalendar) != nil)
    assertTrue(TimeFormatter.parseDateKey("2026-02-30") == nil)
    assertTrue(TimeFormatter.parseDateKey("2026-1-1") == nil)
    assertEqual(AnalyticsMetrics.goalPercent(totalSeconds: 3599, goalSeconds: 3600), 99,
                "Rounding never marks an incomplete goal as reached")
    assertEqual(AnalyticsMetrics.goalPercent(totalSeconds: 3600, goalSeconds: 3600), 100)

    let invalidPause = Sprint(startTime: day, endTime: day.addingTimeInterval(3600), pausedDuration: -600)
    assertEqual(invalidPause.duration, 3600, "Negative legacy pauses cannot inflate work time")
    assertEqual(invalidPause.effectiveEnd, invalidPause.endTime)

    assertEqual(EarningsCalculator.calculate(durationInSeconds: .infinity, hourlyRate: 10), 0)
    assertEqual(EarningsCalculator.calculate(durationInHours: 1, hourlyRate: .infinity), 0)
    assertEqual(EarningsCalculator.format(amount: .infinity, currencySymbol: "$"), "$0")
    settings.hourlyRate = -10
    assertTrue(settings.hourlyRate >= 0, "Negative hourly rates are rejected")
    settings.dailyGoalHours = .infinity
    assertTrue(settings.dailyGoalHours.isFinite, "Infinite goals are rejected before rendering")

    // Real disk round-trip must preserve subsecond net work and pause calculations.
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("skeval-audit-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = DiskDayLogAdapter(fileURL: directory.appendingPathComponent("logs.json"))
    let store = DayLogStore(storage: storage)
    let preciseSprint = Sprint(startTime: day.addingTimeInterval(0.875), endTime: day.addingTimeInterval(3600.125),
                               pausedDuration: 60.375, tag: "precision")
    store.save(sprint: preciseSprint)
    let reloaded = DayLogStore(storage: storage).log(for: day).completedSprints.first!
    assertEqual(reloaded.startTime, preciseSprint.startTime, "Disk preserves fractional start time")
    assertEqual(reloaded.endTime, preciseSprint.endTime, "Disk preserves fractional end time")
    assertEqual(reloaded.duration, preciseSprint.duration, "Relaunch preserves exact net duration")
    var draft = SprintDraft(sprint: preciseSprint)
    draft.tagText = "new tag"
    assertEqual(draft.entry?.pausedDuration, preciseSprint.pausedDuration, "Tag-only editor preserves subminute pauses")
    assertEqual(draft.entry?.netDuration, preciseSprint.duration, "Tag-only editor preserves subsecond duration")
    let longSprint = Sprint(startTime: day, endTime: day.addingTimeInterval(86400 * 3 + 3600), pausedDuration: 300.5)
    let longDraft = SprintDraft(sprint: longSprint)
    assertEqual(longDraft.endDayOffset, 3)
    assertEqual(longDraft.entry?.netDuration, longSprint.duration, "Multi-day edit preserves original duration")
    let clipboardTimes = preciseSprint.clipboardText.components(separatedBy: "\t")
    let clipboardStart = TimeFormatter.parseTime(clipboardTimes[0], on: day)!
    let clipboardEnd = TimeFormatter.parseTime(clipboardTimes[1], on: day)!
    assertEqual(clipboardEnd.timeIntervalSince(clipboardStart), floor(preciseSprint.duration!),
                "Whole-second clipboard values match the displayed whole-second duration")
    assertEqual(month.tagBreakdowns.first?.percentageLabel, "66.7%", "Tag labels retain fractional shares")
    testReportReconciliation()
}

@MainActor
func testLifecycleAudit() {
    print("Running timer lifecycle boundary audit...")
    let store = DayLogStore(storage: InMemoryDayLogAdapter())
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let settings = auditSettings()
    settings.hourlyRate = 100
    let vm = TimerViewModel(engine: engine, store: store, goal: settings)
    let start = auditDate(2026, 2, 10)
    engine.clockIn(at: start)
    engine.handleSystemSleep(at: start.addingTimeInterval(300))
    engine.handleSystemWake(at: start.addingTimeInterval(600))
    assertEqual(engine.currentPauseElapsed, 300, "Wake immediately reports the held duration")
    engine.resolveSleepInterval(countAsWork: true, at: start.addingTimeInterval(900))
    engine.clockOut(at: start.addingTimeInterval(1200))
    let completed = store.log(for: start).completedSprints.first!
    assertEqual(completed.duration, 1200)
    assertEqual(completed.pausedDuration, 0)
    assertEqual(completed.pauseCount, 0, "No pause recorded when held time counts as work")

    // The editor's existing conversion must not erase subminute pauses.
    let exactPause = 75.5
    let original = Sprint(startTime: start, endTime: start.addingTimeInterval(3600), pausedDuration: exactPause)
    let edited = try! vm.updateSprint(originalSprint: original, newDate: start, newStartTime: start,
                                 newEndTime: original.endTime!, newPausedDuration: exactPause, newTag: "edited")
    assertEqual(edited.duration, original.duration, "Tag edit preserves exact work duration")

    for invalidBreak in [-1.0, 3600, .infinity, .nan] {
        let count = store.allLogs().values.flatMap { $0 }.count
        do {
            _ = try vm.addManualSprint(date: start, startTime: start, endTime: start.addingTimeInterval(3600),
                                       pausedDuration: invalidBreak)
            assertTrue(false, "Invalid manual breaks must fail")
        } catch { assertEqual(store.allLogs().values.flatMap { $0 }.count, count, "Invalid inputs do not reach storage") }
    }
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    engine.clockIn(at: yesterday)
    engine.pause(at: Date())
    engine.onTick?(engine.state.currentElapsed)
    assertEqual(vm.totalTodayElapsed, 0, "Overnight live sprint belongs to its start day")
    assertTrue(vm.notifiedMilestones.isEmpty, "Overnight work does not trigger today's milestones")
    engine.reset()

    let night = Calendar.current.date(bySettingHour: 23, minute: 30, second: 0, of: start)!
    store.save(sprint: Sprint(startTime: night))
    engine.reload()
    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: night)!
    vm.recoveryEndDate = nextDay
    vm.recoveryEndText = "01:30"
    vm.saveRecoveryEndTime()
    assertFalse(vm.recoveryMode, "Recovery can finish on a different calendar day")
    assertEqual(store.log(for: night).completedSprints.last?.duration, 7200)

    let delegate = AppDelegate(vm: vm)
    let hotkeyTime = Date()
    delegate.triggerClockToggle(at: hotkeyTime)
    assertTrue(vm.isRunning, "Real clock shortcut handler starts a sprint")
    delegate.triggerClockToggle(at: hotkeyTime.addingTimeInterval(0.1))
    assertTrue(vm.isRunning, "Duplicate Carbon/local shortcut delivery is debounced")
    delegate.triggerPauseToggle(at: hotkeyTime)
    assertTrue(vm.isPaused, "Real pause shortcut handler pauses")
    delegate.triggerPauseToggle(at: hotkeyTime.addingTimeInterval(1))
    assertFalse(vm.isPaused, "Real pause shortcut handler resumes")
    delegate.triggerClockToggle(at: hotkeyTime.addingTimeInterval(2))
    assertFalse(vm.isRunning, "Real clock shortcut handler stops")
    testTimerReconciliation()
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    defer { NSStatusBar.system.removeStatusItem(item) }
    let presenter = StatusBarPresenter(statusItem: item)
    presenter.update(state: .idle, accumulatedTotal: 3600)
    let originalImage = item.button?.image
    presenter.update(state: .idle, accumulatedTotal: 7200)
    assertFalse(originalImage === item.button?.image, "Idle status bar updates when completed totals change")
    assertTrue(item.button?.accessibilityLabel()?.contains("02:00:00") == true)
    assertTrue(LaunchAtLoginHelper.setEnabled(true)?.contains("Applications") == true,
               "A development build reports unavailable login registration without changing OS settings")
}

func testReportReconciliation() {
    let settings = auditSettings()
    settings.hourlyRate = 999.99
    settings.currencySymbol = "€"
    for offset in [-8, 0, 9] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: offset * 3600)!
        let reference = auditDate(2024, 3, 17, calendar: calendar)
        var logs: [String: [Sprint]] = [:]
        var oracle: [String: Double] = [:]
        for i in -70...20 {
            let day = calendar.date(byAdding: .day, value: i, to: reference)!
            let c = calendar.dateComponents([.year, .month, .day], from: day)
            let key = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
            let gross = Double((i + 71) * 73 + 60)
            let pause = Double((i + 71) % 7) * 5.25
            let sprint = Sprint(startTime: day, endTime: day.addingTimeInterval(gross), pausedDuration: pause)
            logs[key] = [sprint, Sprint(startTime: day.addingTimeInterval(20000))]
            oracle[key] = gross - pause
        }
        let week = WeeklyAnalytics.calculate(logs: logs, referenceDate: reference, settings: settings, calendar: calendar)
        let weekExpected = week.days.reduce(0.0) { $0 + (oracle[$1.id] ?? 0) }
        assertEqual(week.totalSeconds, weekExpected, "Weekly total reconciles with independent net times")
        assertEqual(week.totalEarnings, (weekExpected / 3600 * 999.99 * 100).rounded() / 100)
        assertEqual(week.allWeekSprints.count, 7, "Open sprints are excluded from reports")
        let month = MonthlyAnalytics.calculate(logs: logs, referenceDate: reference, settings: settings, calendar: calendar)
        let monthExpected = month.days.reduce(0.0) { $0 + (oracle[$1.id] ?? 0) }
        assertEqual(month.totalSeconds, monthExpected)
        let period = InsightsAnalytics.calculatePeriodSummary(logs: logs, startDate: month.monthStartDate,
            endDate: month.monthEndDate, settings: settings, calendar: calendar)
        assertEqual(period.totalSeconds, monthExpected, "Month and period reports reconcile")
        assertEqual(period.totalEarnings, month.totalEarnings)
        assertEqual(period.trendPoints.reduce(0) { $0 + $1.totalSeconds }, monthExpected, "Trend buckets reconcile with total")
        let year = InsightsAnalytics.generateAnnualHeatmap(logs: logs, year: 2024, settings: settings, calendar: calendar)
        assertEqual(year.totalYearSeconds, oracle.values.reduce(0, +))
        for day in month.days {
            assertEqual(day.totalSeconds, oracle[day.id] ?? 0)
            assertEqual(day.earnings, ((oracle[day.id] ?? 0) / 3600 * 999.99 * 100).rounded() / 100)
        }
        let exportedRows = CSVExporter.generateCSV(sprints: period.sprints).components(separatedBy: "\r\n").dropFirst().filter { !$0.isEmpty }
        assertEqual(exportedRows.count, period.totalSprintsCount, "Export includes each completed period record once")
    }
}

@MainActor
func testTimerReconciliation() {
    let store = DayLogStore(storage: InMemoryDayLogAdapter())
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let base = auditDate(2026, 3, 17)
    for index in 0..<100 {
        let start = base.addingTimeInterval(Double(index) * 86400)
        engine.clockIn(at: start)
        var wallSeconds = 0.0
        var expectedPaused = 0.0
        for pauseIndex in 0..<5 {
            wallSeconds += Double(37 + index + pauseIndex) + 0.125
            engine.pause(at: start.addingTimeInterval(wallSeconds))
            assertEqual(engine.state.currentElapsed, wallSeconds - expectedPaused)
            let pause = Double((index + pauseIndex) % 11) + 0.375
            wallSeconds += pause
            expectedPaused += pause
            engine.resume(at: start.addingTimeInterval(wallSeconds))
            assertEqual(engine.state.currentElapsed, wallSeconds - expectedPaused)
        }
        wallSeconds += 60.5
        engine.clockOut(at: start.addingTimeInterval(wallSeconds))
        let completed = store.log(for: start).completedSprints.first!
        assertEqual(completed.pausedDuration, expectedPaused)
        assertEqual(completed.duration, wallSeconds - expectedPaused)
        assertEqual(completed.pauseCount, 5)
        assertEqual(completed.effectiveEnd!.timeIntervalSince(completed.startTime), completed.duration!)
    }
}
