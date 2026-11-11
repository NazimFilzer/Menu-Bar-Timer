import Foundation

/// Period totals count the running sprint on its start day, like Today and Week.
/// Tag shares, sprint lists, and timesheets stay on completed sprints.
func testLiveWorkTotals() {
    print("Running Live work in period totals tests...")
    let settings = auditSettings()
    settings.hourlyRate = 1000
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    calendar.firstWeekday = 2
    let hour: TimeInterval = 3600
    let monday = auditDate(2026, 11, 9, hour: 7, calendar: calendar)
    let tuesday = auditDate(2026, 11, 10, hour: 7, calendar: calendar)
    let now = auditDate(2026, 11, 10, hour: 14, calendar: calendar)
    func key(_ date: Date) -> String { TimeFormatter.format(dateKey: date, calendar: calendar) }
    let logs: [String: [Sprint]] = [
        key(monday): [Sprint(startTime: monday, endTime: monday.addingTimeInterval(4 * hour), tag: "Client")],
        key(tuesday): [Sprint(startTime: tuesday, endTime: tuesday.addingTimeInterval(4 * hour), tag: "Client")]
    ]
    let live = LiveWork(day: calendar.startOfDay(for: now), seconds: 30 * 60)

    // Month: the total and the live day include the running sprint; tags do not.
    let month = MonthlyAnalytics.calculate(logs: logs, referenceDate: now, settings: settings, calendar: calendar, live: live)
    let completedMonth = MonthlyAnalytics.calculate(logs: logs, referenceDate: now, settings: settings, calendar: calendar)
    assertEqual(month.totalSeconds, 8.5 * hour, "Month total counts the running sprint")
    assertEqual(completedMonth.totalSeconds, 8 * hour, "Without live work the total is completed sprints only")
    let today = month.days.first { calendar.isDate($0.date, inSameDayAs: now) }
    assertEqual(today?.totalSeconds, 4.5 * hour, "The running sprint counts on its start day")
    assertEqual(today?.completedSprints.count, 1, "The running sprint never joins the completed list")
    assertEqual(today?.sprintCount, 1)
    assertEqual(month.tagBreakdowns.first?.percentage, 100, "Tag shares use completed sprints only")
    let monday2 = month.days.first { calendar.isDate($0.date, inSameDayAs: monday) }
    assertEqual(monday2?.totalSeconds, 4 * hour, "Other days are unchanged")

    // A running sprint that started yesterday stays on yesterday, even after midnight.
    let overnight = LiveWork(day: calendar.startOfDay(for: monday), seconds: hour)
    let overnightMonth = MonthlyAnalytics.calculate(logs: logs, referenceDate: now, settings: settings,
                                                    calendar: calendar, live: overnight)
    assertEqual(overnightMonth.days.first { calendar.isDate($0.date, inSameDayAs: monday) }?.totalSeconds, 5 * hour,
                "Live work is credited to the sprint's start day")
    assertEqual(overnightMonth.days.first { calendar.isDate($0.date, inSameDayAs: now) }?.totalSeconds, 4 * hour)

    // A previous month never picks up today's live work.
    let october = MonthlyAnalytics.calculate(logs: logs, monthOffset: -1, referenceDate: now, settings: settings,
                                             calendar: calendar, live: live)
    assertEqual(october.totalSeconds, 0, "Live work only counts in the period that holds its day")

    // Analytics: the current side counts live work; the previous side does not.
    let week = AnalyticsRange.make(.week, today: now, earliest: nil, calendar: calendar)
    let comparison = AnalyticsComparison.calculate(range: week, logs: logs, earliest: monday, today: now,
                                                   settings: settings, calendar: calendar, live: live)
    assertEqual(comparison.current.workedSeconds, 8.5 * hour, "Analytics totals match Week and Today")
    let bars = AnalyticsComparison.bars(week.dates(calendar: calendar), logs: logs, today: now,
                                        settings: settings, calendar: calendar, live: live)
    assertEqual(bars.flatMap(\.completedSprints).count, 2, "CSV and patterns keep completed sprints only")

    // Bad input is ignored rather than corrupting totals.
    let broken = LiveWork(day: calendar.startOfDay(for: now), seconds: .infinity)
    assertEqual(MonthlyAnalytics.calculate(logs: logs, referenceDate: now, settings: settings, calendar: calendar,
                                           live: broken).totalSeconds, 8 * hour)
    let negative = LiveWork(day: calendar.startOfDay(for: now), seconds: -60)
    assertEqual(MonthlyAnalytics.calculate(logs: logs, referenceDate: now, settings: settings, calendar: calendar,
                                           live: negative).totalSeconds, 8 * hour)
}
