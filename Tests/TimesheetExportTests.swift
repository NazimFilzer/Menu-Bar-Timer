import Foundation
import AppKit

func testDailyTimesheetExport() {
    print("Running daily timesheet export tests...")
    let day = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 19))!
    let login = TimeFormatter.parseTime("09:00:00", on: day)!
    let first = Sprint(startTime: login, endTime: login.addingTimeInterval(3600), pausedDuration: 600)
    let last = Sprint(startTime: login.addingTimeInterval(7200), endTime: login.addingTimeInterval(10800), pausedDuration: 300)
    let earlierOpen = Sprint(startTime: login.addingTimeInterval(-3600))
    let laterOpen = Sprint(startTime: login.addingTimeInterval(14400), isPaused: true,
                           pauseStartedAt: login.addingTimeInterval(15000))
    let log = DayLog(sprints: [laterOpen, last, earlierOpen, first])
    assertEqual(log.clipboardText, "09:00:00\t12:00:00\t\t75", "Pauses and the hour between sprints count as break")
    assertEqual(log.clipboardText.components(separatedBy: "\n").count, 1)
    let columns = log.clipboardText.components(separatedBy: "\t")
    assertEqual(columns.count, 4)
    assertEqual(columns[2], "", "Lunch remains blank")
    assertEqual(10800 - Double(columns[3])! * 60, log.accumulatedTotal)
    assertEqual(DayLog().clipboardText, "")
    assertEqual(DayLog(sprints: [earlierOpen, laterOpen]).clipboardText, "")

    let roundingCases: [(TimeInterval, String)] = [
        (0, "0"), (20, "0"), (29, "0"), (30, "1"), (89, "1"), (90, "2"), (36000, "600")
    ]
    for (seconds, expected) in roundingCases {
        assertEqual(TimeFormatter.format(breakMinutes: seconds), expected)
    }
    let shortPause = Sprint(startTime: login, endTime: login.addingTimeInterval(3600), pausedDuration: 30)
    assertEqual(DayLog(sprints: [shortPause]).clipboardText, "09:00:00\t10:00:00\t\t1")
    assertEqual(shortPause.duration, 3570, "Only exported minutes round; stored work remains exact")
    let uninterrupted = Sprint(startTime: login, endTime: login.addingTimeInterval(3600))
    assertEqual(DayLog(sprints: [uninterrupted]).clipboardText, "09:00:00\t10:00:00\t\t0")

    // Overlapping manual entries can finish out of start-time order.
    // Pick the maximum end timestamp and never export a negative break.
    let spanning = Sprint(startTime: login, endTime: login.addingTimeInterval(14400))
    assertEqual(DayLog(sprints: [last, spanning]).clipboardText, "09:00:00\t13:00:00\t\t0")

    // A sprint crossing midnight still belongs to its start day.
    let nightStart = TimeFormatter.parseTime("23:00:00", on: day)!
    let overnight = Sprint(startTime: nightStart, endTime: nightStart.addingTimeInterval(7200), pausedDuration: 900)
    assertEqual(DayLog(sprints: [overnight]).clipboardText, "23:00:00\t01:00:00\t\t15")

    // v2 retains subsecond timestamps. Round the complete day's break only once.
    let fractional = Sprint(startTime: login.addingTimeInterval(0.25),
                            endTime: login.addingTimeInterval(3600.75), pausedDuration: 29.9)
    assertEqual(DayLog(sprints: [fractional]).clipboardText, "09:00:00\t10:00:00\t\t0")
    assertEqual(fractional.duration, 3570.6)
    let pauseOne = Sprint(startTime: login, endTime: login.addingTimeInterval(3600), pausedDuration: 20)
    let pauseTwo = Sprint(startTime: login.addingTimeInterval(3600),
                         endTime: login.addingTimeInterval(7200), pausedDuration: 20)
    assertEqual(DayLog(sprints: [pauseTwo, pauseOne]).clipboardText, "09:00:00\t11:00:00\t\t1")
}

func testPeriodTimesheetExport() {
    let settings = auditSettings()
    let monday = auditDate(2026, 10, 26)
    let thursday = auditDate(2026, 10, 29)
    let sunday = auditDate(2026, 11, 1, hour: 23)
    let first = Sprint(startTime: monday, endTime: monday.addingTimeInterval(3600), pausedDuration: 600)
    let second = Sprint(startTime: monday.addingTimeInterval(7200), endTime: monday.addingTimeInterval(10800), pausedDuration: 300)
    let later = Sprint(startTime: thursday, endTime: thursday.addingTimeInterval(7200))
    let overnight = Sprint(startTime: sunday, endTime: sunday.addingTimeInterval(7200), pausedDuration: 900)
    let open = Sprint(startTime: auditDate(2026, 10, 28))
    let outside = Sprint(startTime: auditDate(2026, 11, 2), endTime: auditDate(2026, 11, 2, hour: 10))
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    for sprint in [later, second, overnight, open, first, outside] { store.save(sprint: sprint) }
    let originalLogs = storage.loadAll()
    let week = WeeklyAnalytics.calculate(store: store, referenceDate: monday, settings: settings)
    // Reversed input still exports oldest first.
    let exported = DailyTimesheet.clipboardText(days: Array(week.days.reversed()))
    let rows = exported.components(separatedBy: "\n")
    assertEqual(rows.count, 7)
    assertEqual(rows[0], "09:00:00\t12:00:00\t\t75")
    assertEqual(rows[1], "\t\t\t", "An empty date keeps its spreadsheet row")
    assertEqual(rows[2], "\t\t\t", "An open sprint does not contribute to the timesheet")
    assertEqual(rows[3], "09:00:00\t11:00:00\t\t0")
    assertEqual(rows[6], DayLog(sprints: [overnight]).clipboardText, "Cross-midnight work stays on Sunday")
    assertTrue(rows.allSatisfy { $0.components(separatedBy: "\t").count == 4 })
    assertEqual(DailyTimesheet.clipboardText(days: []), "")

    let october = MonthlyAnalytics.calculate(store: store, referenceDate: monday, settings: settings)
    let monthRows = DailyTimesheet.clipboardText(days: october.days).components(separatedBy: "\n")
    assertEqual(monthRows.count, 31)
    assertEqual(monthRows[25], rows[0])
    assertEqual(monthRows[28], rows[3])
    assertEqual(monthRows[30], "\t\t\t", "Trailing empty dates remain blank")
    let analytics = InsightsAnalytics.calculatePeriodSummary(store: store, startDate: monday,
                                                            endDate: sunday, settings: settings)
    assertEqual(analytics.days.map(\.id), week.days.map(\.id))
    assertEqual(DailyTimesheet.clipboardText(days: analytics.days), exported,
                "Analytics copies the same daily rows as Week")
    let reversed = InsightsAnalytics.calculatePeriodSummary(store: store, startDate: sunday,
                                                           endDate: monday, settings: settings)
    assertEqual(reversed.days, analytics.days, "Reversed custom dates produce the same chronological days")
    let monthAnalytics = InsightsAnalytics.calculatePeriodSummary(store: store, startDate: october.monthStartDate,
                                                                endDate: october.monthEndDate, settings: settings)
    assertEqual(DailyTimesheet.clipboardText(days: monthAnalytics.days), monthRows.joined(separator: "\n"))

    let yearEnd = auditDate(2025, 12, 31)
    let yearStart = auditDate(2026, 1, 1)
    let yearEndSprint = Sprint(startTime: yearEnd, endTime: yearEnd.addingTimeInterval(3600), pausedDuration: 300)
    let acrossYears = InsightsAnalytics.calculatePeriodSummary(
        logs: [TimeFormatter.format(dateKey: yearEnd): [yearEndSprint]], startDate: yearEnd,
        endDate: auditDate(2026, 2, 1), settings: settings)
    assertEqual(acrossYears.days.count, 33, "Ranges longer than a month still list individual days")
    assertEqual(acrossYears.days.first?.id, TimeFormatter.format(dateKey: yearEnd))
    assertEqual(acrossYears.days[1].id, TimeFormatter.format(dateKey: yearStart))
    assertEqual(acrossYears.days.last?.id, "2026-02-01")
    let yearRows = DailyTimesheet.clipboardText(days: acrossYears.days).components(separatedBy: "\n")
    assertEqual(yearRows.count, 33)
    assertEqual(yearRows[0], DayLog(sprints: [yearEndSprint]).clipboardText)
    assertTrue(yearRows.dropFirst().allSatisfy { $0 == "\t\t\t" })
    let previousMonth = MonthlyAnalytics.calculate(store: store, monthOffset: -1, referenceDate: monday, settings: settings)
    assertEqual(DailyTimesheet.clipboardText(days: previousMonth.days), "", "A wholly empty period has nothing to copy")
    assertEqual(storage.loadAll(), originalLogs, "Generating summaries never changes stored sprints")
    let reloaded = DayLogStore(storage: storage)
    assertEqual(DailyTimesheet.clipboardText(days: WeeklyAnalytics.calculate(store: reloaded, referenceDate: monday, settings: settings).days), exported)

    // A local calendar day can be 23 or 25 hours. Use elapsed time for break math.
    var dstCalendar = Calendar(identifier: .gregorian)
    dstCalendar.timeZone = TimeZone(identifier: "America/New_York")!
    for (month, day, elapsedHours) in [(3, 8, 23), (11, 1, 25)] {
        let start = dstCalendar.startOfDay(for: auditDate(2026, month, day, calendar: dstCalendar))
        let end = dstCalendar.date(byAdding: .day, value: 1, to: start)!
        let sprint = Sprint(startTime: start, endTime: end, pausedDuration: 1800)
        let key = TimeFormatter.format(dateKey: start, calendar: dstCalendar)
        let summary = MonthlyAnalytics.calculate(logs: [key: [sprint]], referenceDate: start,
                                                 settings: settings, calendar: dstCalendar)
        let lines = DailyTimesheet.clipboardText(days: summary.days).components(separatedBy: "\n")
        assertEqual(end.timeIntervalSince(start), Double(elapsedHours) * 3600)
        assertEqual(lines[day - 1], DayLog(sprints: [sprint]).clipboardText)
        assertEqual(lines[day - 1].components(separatedBy: "\t").last, "30")
        let analytics = InsightsAnalytics.calculatePeriodSummary(
            logs: [key: [sprint]], startDate: start, endDate: end.addingTimeInterval(-1),
            settings: settings, calendar: dstCalendar)
        assertEqual(analytics.days.count, 1, "A DST transition remains one calendar day")
        assertEqual(DailyTimesheet.clipboardText(days: analytics.days), lines[day - 1])
    }
}

@MainActor
func testDailyTimesheetClipboard() {
    let store = DayLogStore(storage: InMemoryDayLogAdapter())
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store, goal: auditSettings())
    let today = Calendar.current.startOfDay(for: Date())
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let oldLogin = TimeFormatter.parseTime("09:00:00", on: yesterday)!
    let login = TimeFormatter.parseTime("10:00:00", on: today)!
    store.save(sprint: Sprint(startTime: oldLogin, endTime: oldLogin.addingTimeInterval(3600), pausedDuration: 90))
    store.save(sprint: Sprint(startTime: login, endTime: login.addingTimeInterval(3600), pausedDuration: 600))

    // Dashboard, popover button, and context menu use this same action.
    vm.selectDate(yesterday)
    vm.copyAllDisplayedSprints()
    assertEqual(NSPasteboard.general.string(forType: .string), "09:00:00\t10:00:00\t\t2")
    assertTrue(vm.isAllCopied)
    vm.selectDate(today)
    vm.copyAllDisplayedSprints()
    assertEqual(NSPasteboard.general.string(forType: .string), "10:00:00\t11:00:00\t\t10")

    let emptyDay = Calendar.current.date(byAdding: .day, value: -2, to: today)!
    vm.selectDate(emptyDay)
    vm.copyAllDisplayedSprints()
    assertEqual(NSPasteboard.general.string(forType: .string), "10:00:00\t11:00:00\t\t10", "Empty days leave the clipboard intact")

    let week = WeeklyAnalytics.calculate(store: store, referenceDate: yesterday, settings: vm.goal)
    assertTrue(vm.copyTimesheet(days: week.days))
    let copiedWeek = NSPasteboard.general.string(forType: .string)
    assertEqual(copiedWeek, DailyTimesheet.clipboardText(days: week.days))
    let month = MonthlyAnalytics.calculate(store: store, referenceDate: today, settings: vm.goal)
    assertTrue(vm.copyTimesheet(days: month.days))
    assertEqual(NSPasteboard.general.string(forType: .string), DailyTimesheet.clipboardText(days: month.days))
    let copiedMonth = NSPasteboard.general.string(forType: .string)
    assertFalse(vm.copyTimesheet(days: []))
    assertEqual(NSPasteboard.general.string(forType: .string), copiedMonth, "An empty period leaves the clipboard intact")
    let day = month.days.first { $0.id == TimeFormatter.format(dateKey: today) }!
    assertTrue(vm.copyTimesheet(days: [day]))
    assertEqual(NSPasteboard.general.string(forType: .string), "10:00:00\t11:00:00\t\t10")
}
