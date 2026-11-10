import Foundation

func testAnalyticsReport() {
    print("Running Analytics range and comparison tests...")
    let settings = auditSettings()
    settings.hourlyRate = 1500
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let hour: TimeInterval = 3600
    func day(_ y: Int, _ m: Int, _ d: Int) -> Date { auditDate(y, m, d, hour: 0, calendar: calendar) }
    func logs(_ entries: [(Int, Int, Int, Double)]) -> [String: [Sprint]] {
        var result: [String: [Sprint]] = [:]
        for (y, m, d, hours) in entries {
            let start = auditDate(y, m, d, hour: 7, calendar: calendar)
            result[TimeFormatter.format(dateKey: start, calendar: calendar), default: []]
                .append(Sprint(startTime: start, endTime: start.addingTimeInterval(hours * hour)))
        }
        return result
    }
    let today = auditDate(2026, 11, 10, hour: 14, calendar: calendar) // Tuesday

    // Ranges
    let week = AnalyticsRange.make(.week, today: today, earliest: nil, calendar: calendar)
    assertEqual(week.start, day(2026, 11, 9), "Weeks start on Monday")
    assertEqual(week.end, day(2026, 11, 15))
    assertEqual(week.label, "Nov 9 – 15, 2026")
    assertEqual(week.previousStart, day(2026, 11, 2))
    let lastWeek = AnalyticsRange.make(.week, offset: -1, today: today, earliest: nil, calendar: calendar)
    assertEqual(lastWeek.start, day(2026, 11, 2))
    let month = AnalyticsRange.make(.month, today: today, earliest: nil, calendar: calendar)
    assertEqual(month.end, day(2026, 11, 30))
    assertEqual(month.label, "November 2026")
    assertEqual(month.previousEnd, day(2026, 10, 31))
    let year = AnalyticsRange.make(.year, today: today, earliest: nil, calendar: calendar)
    assertEqual(year.end, day(2026, 12, 31))
    assertEqual(year.previousName, "2025")
    let all = AnalyticsRange.make(.all, today: today, earliest: auditDate(2026, 3, 2, calendar: calendar), calendar: calendar)
    assertEqual(all.start, day(2026, 3, 2), "All time starts on the first recorded day")
    assertEqual(all.end, day(2026, 11, 10))
    assertTrue(all.previousStart == nil, "All time has no previous period")
    let custom = AnalyticsRange.custom(from: day(2026, 10, 10), to: day(2026, 10, 1), calendar: calendar)
    assertEqual(custom.start, day(2026, 10, 1), "Custom ranges accept dates in either order")
    assertEqual(custom.previousEnd, day(2026, 9, 30))
    assertEqual(custom.previousStart, day(2026, 9, 21), "The same number of days right before")
    assertTrue(!month.drawsWeeks(calendar: calendar) && year.drawsWeeks(calendar: calendar))

    // Comparison: a running week is cut to the same days, on every figure.
    let sample = logs([(2026, 11, 2, 8), (2026, 11, 3, 6), (2026, 11, 4, 8), (2026, 11, 5, 8),
                       (2026, 11, 9, 8), (2026, 11, 10, 2)])
    let earliest = day(2026, 11, 2)
    let running = AnalyticsComparison.calculate(range: week, logs: sample, earliest: earliest, today: today,
                                                settings: settings, calendar: calendar)
    assertTrue(running.isPartial)
    assertEqual(running.comparedDays, 2, "Monday and Tuesday against Monday and Tuesday")
    assertEqual(running.current.workedSeconds, 10 * hour)
    assertEqual(running.previous?.workedSeconds, 14 * hour, "Only Nov 2 and 3 of the previous week")
    assertEqual(running.previous?.daysWithWork, 2)
    assertEqual(running.previous?.sprintCount, 2, "Sprints are cut to the same days too")
    assertEqual(running.current.finishedWorkdays, 1, "Today is not finished")
    assertEqual(running.previous?.finishedWorkdays, 1, "The previous side stops at the same finished day")
    assertEqual(running.current.goalMetDays, 1)
    assertEqual(running.previous?.goalMetDays, 1)
    assertEqual(running.current.earnings, 15000)

    let finishedWeek = AnalyticsComparison.calculate(range: lastWeek, logs: sample, earliest: earliest, today: today,
                                                     settings: settings, calendar: calendar)
    assertTrue(!finishedWeek.isPartial)
    assertEqual(finishedWeek.current.workedSeconds, 30 * hour)
    assertEqual(finishedWeek.current.goalMetDays, 3, "8h days met; the 6h day did not")
    assertEqual(finishedWeek.current.finishedWorkdays, 5)
    assertTrue(finishedWeek.previous == nil, "The week before the first sprint has no data, so no comparison")

    // A month with no work after recording started is a real zero, not missing data.
    let gap = logs([(2026, 9, 1, 8), (2026, 11, 2, 8)])
    let october = AnalyticsRange.make(.month, offset: -1, today: today, earliest: nil, calendar: calendar)
    let novemberVsOctober = AnalyticsComparison.calculate(range: month, logs: gap, earliest: day(2026, 9, 1), today: today,
                                                          settings: settings, calendar: calendar)
    assertEqual(novemberVsOctober.previous?.workedSeconds, 0, "October counts as zero once recording started earlier")
    assertEqual(AnalyticsComparison.calculate(range: october, logs: gap, earliest: day(2026, 9, 1), today: today,
                                              settings: settings, calendar: calendar).previous?.workedSeconds, 8 * hour)

    // Short previous months clamp: Mar 31 compares with all of February.
    let march31 = auditDate(2026, 3, 31, hour: 12, calendar: calendar)
    let march = AnalyticsRange.make(.month, today: march31, earliest: nil, calendar: calendar)
    let marchCompare = AnalyticsComparison.calculate(range: march, logs: logs([(2026, 2, 27, 5)]), earliest: day(2026, 1, 1),
                                                     today: march31, settings: settings, calendar: calendar)
    assertEqual(marchCompare.comparedDays, 28, "February has only 28 days to compare")
    assertEqual(marchCompare.previous?.workedSeconds, 5 * hour)

    // Week bars: a partial week at the start of a year gets a goal for its own workdays.
    let yearDays = AnalyticsComparison.bars(year.dates(calendar: calendar), logs: [:], today: today,
                                            settings: settings, calendar: calendar)
    let weeks = AnalyticsBar.make(days: yearDays, previousDays: nil, byWeek: true, settings: settings,
                                  today: today, calendar: calendar)
    assertEqual(weeks.first?.start, day(2026, 1, 1), "The first week bar is clipped to the range")
    assertEqual(weeks.first?.end, day(2026, 1, 4))
    assertEqual(weeks.first?.goalSeconds, 2 * settings.dailyGoalSeconds, "Thu and Fri are its only workdays")
    assertEqual(weeks[1].goalSeconds, 5 * settings.dailyGoalSeconds)
    assertEqual(weeks.reduce(0) { $0 + calendar.dateComponents([.day], from: $1.start, to: $1.end).day! + 1 }, 365,
                "Week bars cover every day once")

    // Day bars line up with the previous period by position.
    let weekDays = AnalyticsComparison.bars(week.dates(calendar: calendar), logs: sample, today: today, settings: settings, calendar: calendar)
    let previousDays = AnalyticsComparison.bars(week.previousDates(calendar: calendar), logs: sample, today: today, settings: settings, calendar: calendar)
    let dayBars = AnalyticsBar.make(days: weekDays, previousDays: previousDays, byWeek: false, settings: settings,
                                    today: today, calendar: calendar)
    assertEqual(dayBars.count, 7)
    assertEqual(dayBars[1].previousSeconds, 6 * hour, "Tuesday sits beside last Tuesday")
    assertTrue(dayBars[5].isDayOff && dayBars[2].isUpcoming && !dayBars[2].metGoal)
    assertTrue(dayBars[0].metGoal)

    // DST: a range across a clock change still has one bar per calendar day.
    var newYork = Calendar(identifier: .gregorian)
    newYork.timeZone = TimeZone(identifier: "America/New_York")!
    let dstToday = auditDate(2026, 11, 3, hour: 12, calendar: newYork)
    let dstWeek = AnalyticsRange.make(.week, today: dstToday, earliest: nil, calendar: newYork)
    assertEqual(dstWeek.dates(calendar: newYork).count, 7, "The week of Nov 1, 2026 DST change has 7 days")
    let dstMonth = AnalyticsRange.make(.month, today: auditDate(2026, 3, 20, calendar: newYork), earliest: nil, calendar: newYork)
    assertEqual(dstMonth.dates(calendar: newYork).count, 31)

    // Cross-tab: the current month's totals match the Month page.
    let monthly = MonthlyAnalytics.calculate(logs: sample, referenceDate: today, settings: settings, calendar: calendar)
    let monthCompare = AnalyticsComparison.calculate(range: month, logs: sample, earliest: earliest, today: today,
                                                     settings: settings, calendar: calendar)
    let monthCalendar = MonthCalendar.make(days: monthly.days, settings: settings, now: today, calendar: calendar)
    assertEqual(monthCompare.current.workedSeconds, monthly.totalSeconds, "Analytics and Month agree on worked time")
    assertEqual(monthCompare.current.earnings, monthly.totalEarnings, "Analytics and Month agree on earnings")
    assertEqual(monthCompare.current.goalMetDays, monthCalendar.metWorkdays, "Analytics and Month agree on goal days")
    assertEqual(monthCompare.current.finishedWorkdays, monthCalendar.finishedWorkdays)
}
