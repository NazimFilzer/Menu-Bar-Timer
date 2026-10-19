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
}
