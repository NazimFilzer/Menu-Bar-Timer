import Foundation

func testMonthCalendarStartsOnMondayAndCountsOnlyItsOwnDays() {
    print("Running Month calendar tests...")
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let settings = auditSettings() // Mon–Fri, 8h daily goal by default
    settings.dailyGoalHours = 8
    func sprint(_ day: Int, hours: Double, month: Int = 11) -> (String, [Sprint]) {
        let start = auditDate(2026, month, day, hour: 7, calendar: cal)
        return (TimeFormatter.format(dateKey: start, calendar: cal),
                [Sprint(startTime: start, endTime: start.addingTimeInterval(hours * 3600))])
    }
    // November 2026 starts on a Sunday. October work in the leading week must not count.
    let logs = Dictionary(uniqueKeysWithValues: [
        sprint(30, hours: 9, month: 10), // Fri Oct 30, outside the month
        sprint(2, hours: 8.5),           // Mon, met
        sprint(3, hours: 5),             // Tue, short of goal (under 75%)
        sprint(5, hours: 6),             // Thu, close to goal (exactly 75%)
        sprint(7, hours: 2),             // Sat, extra time on a day off
        sprint(10, hours: 3),            // Tue, today
    ])
    let now = auditDate(2026, 11, 10, hour: 15, calendar: cal)
    let month = MonthlyAnalytics.calculate(logs: logs, referenceDate: now, settings: settings, calendar: cal)
    let result = MonthCalendar.make(days: month.days, settings: settings, now: now, calendar: cal)

    assertEqual(result.weeks.count, 6, "Nov 2026 spans six Monday-first weeks (Sun Nov 1 … Mon Nov 30)")
    assertTrue(result.weeks.allSatisfy { $0.count == 7 }, "Every week row has seven cells")
    assertTrue(result.weeks[0][0..<6].allSatisfy { $0 == nil }, "Mon–Sat before Nov 1 are blank, not October days")
    assertEqual(result.weeks[0][6]?.day.dayNumberLabel, "1", "Sunday Nov 1 sits in the last column")
    assertEqual(result.weeks[5][0]?.day.dayNumberLabel, "30", "Monday Nov 30 starts the last row")
    assertTrue(result.weeks[5][1...].allSatisfy { $0 == nil }, "Cells after Nov 30 are blank")

    func status(_ day: Int) -> MonthCalendarDay.Status? {
        result.weeks.joined().compactMap { $0 }.first { $0.day.dayNumberLabel == "\(day)" }?.status
    }
    assertEqual(status(1), .dayOff, "Unworked Sunday is a day off")
    assertEqual(status(2), .met)
    assertEqual(status(3), .shortOfGoal, "5h of 8h is under 75% of the daily goal")
    assertEqual(status(5), .belowGoal, "6h of 8h is exactly 75% and counts as close")
    assertEqual(status(4), .missed, "A past workday with no work is missed")
    assertEqual(status(7), .extraTime, "Work on a day off is extra time")
    assertEqual(status(10), .today)
    assertEqual(status(11), .upcoming)

    // Finished workdays: Nov 2–6 and Nov 9. Today and later are not judged.
    assertEqual(result.finishedWorkdays, 6, "Only this month's finished workdays count (no October days)")
    assertEqual(result.metWorkdays, 1)

    settings.daysOff = [TimeFormatter.format(dateKey: auditDate(2026, 11, 4, calendar: cal), calendar: cal)]
    let withDayOff = MonthCalendar.make(days: month.days, settings: settings, now: now, calendar: cal)
    assertEqual(withDayOff.finishedWorkdays, 5, "A marked day off leaves the workday count")
    settings.daysOff = []

    // A past month is fully judged; a month starting on Monday has no leading blanks.
    let june = MonthlyAnalytics.calculate(logs: [:], referenceDate: auditDate(2026, 6, 15, calendar: cal),
                                          settings: settings, calendar: cal)
    let past = MonthCalendar.make(days: june.days, settings: settings, now: now, calendar: cal)
    assertEqual(past.weeks[0][0]?.day.dayNumberLabel, "1", "June 2026 starts on Monday in the first column")
    assertEqual(past.finishedWorkdays, 22)
    assertEqual(past.metWorkdays, 0)
    assertTrue(past.weeks.joined().compactMap { $0 }.allSatisfy { $0.status != .upcoming && $0.status != .today })
}
