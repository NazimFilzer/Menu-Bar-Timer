import AppKit

func testDayRibbon() {
    print("Running Day ribbon tests...")
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: hour, minute: minute))!
    }
    let day = DateInterval(start: at(0), end: calendar.date(byAdding: .day, value: 1, to: at(0))!)
    let sprints = [DateInterval(start: at(6), end: at(8, 10)), DateInterval(start: at(8, 30), end: at(10, 45)),
                   DateInterval(start: at(13, 30), end: at(14))]

    let ribbon = DayRibbon.make(sprints: sprints, pauseStart: nil, finish: at(17, 30), now: at(14),
                                day: day, calendar: calendar)
    assertEqual(ribbon.window.start, at(6), "The window starts at the first sprint's hour")
    assertEqual(ribbon.window.end, at(18), "The window ends at the forecast's hour")
    assertEqual(ribbon.blocks.filter { $0.kind == .work }.count, 3)
    assertEqual(ribbon.blocks.first?.start, 0)
    let forecast = ribbon.blocks.first { $0.kind == .forecast }
    assertEqual(forecast?.start, 8.0 / 12.0, "The forecast starts at now")
    assertEqual(forecast?.end, 11.5 / 12.0, "and ends at the finish")
    assertEqual(ribbon.now, 8.0 / 12.0)
    assertTrue(ribbon.marks.count <= 5, "At most five hour labels")
    assertEqual(ribbon.marks.first?.date, at(6))

    // A pause happening now is drawn from its start to now.
    let paused = DayRibbon.make(sprints: [DateInterval(start: at(9), end: at(10))], pauseStart: at(9, 40), finish: nil,
                                now: at(10), day: day, calendar: calendar)
    let pause = paused.blocks.first { $0.kind == .pause }
    assertTrue(pause != nil && pause!.end > pause!.start, "The current pause has its own block")
    assertTrue(paused.window.duration >= DayRibbon.minimumSpan, "Short days still show at least four hours")

    // No work yet: a four-hour window around now, nothing drawn but the forecast.
    let empty = DayRibbon.make(sprints: [], pauseStart: nil, finish: at(17), now: at(9), day: day, calendar: calendar)
    assertEqual(empty.window.start, at(9))
    assertEqual(empty.window.end, at(17))
    assertEqual(empty.blocks.map(\.kind), [.forecast])

    // A forecast past midnight stops at the end of today, and the window never leaves today.
    let late = DayRibbon.make(sprints: [DateInterval(start: at(20), end: at(22))], pauseStart: nil,
                              finish: at(23).addingTimeInterval(3 * 3600), now: at(22), day: day, calendar: calendar)
    assertEqual(late.window.end, day.end, "The ribbon stops at midnight")
    assertEqual(late.blocks.last?.end, 1)
    assertTrue(late.window.start >= day.start)

    // Late at night with little work: the four hours extend backwards, not past midnight.
    let night = DayRibbon.make(sprints: [DateInterval(start: at(23), end: at(23, 30))], pauseStart: nil, finish: nil,
                               now: at(23, 30), day: day, calendar: calendar)
    assertEqual(night.window.end, day.end)
    assertEqual(night.window.duration, DayRibbon.minimumSpan)

    // An overnight sprint from yesterday is clipped to today.
    let overnight = DayRibbon.make(sprints: [DateInterval(start: at(0).addingTimeInterval(-3600), end: at(2))],
                                   pauseStart: nil, finish: nil, now: at(2), day: day, calendar: calendar)
    assertEqual(overnight.window.start, at(0))
    assertEqual(overnight.blocks.first?.start, 0)
}

func testEarningsTrend() {
    print("Running Earnings trend tests...")
    let settings = auditSettings()
    settings.hourlyRate = 1000
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let today = auditDate(2026, 11, 3, hour: 15, calendar: calendar)
    func logs(_ entries: [(Int, Int, Double)]) -> [String: [Sprint]] {
        var result: [String: [Sprint]] = [:]
        for (m, d, hours) in entries {
            let start = auditDate(2026, m, d, hour: 9, calendar: calendar)
            result[TimeFormatter.format(dateKey: start, calendar: calendar), default: []]
                .append(Sprint(startTime: start, endTime: start.addingTimeInterval(hours * 3600)))
        }
        return result
    }
    let sample = logs([(10, 1, 8), (10, 2, 6), (10, 31, 4), (11, 2, 5), (11, 3, 2)])
    let month = AnalyticsRange.make(.month, today: today, earliest: nil, calendar: calendar)
    let days = AnalyticsComparison.bars(month.dates(calendar: calendar), logs: sample, today: today,
                                        settings: settings, calendar: calendar)
    let previous = AnalyticsComparison.bars(month.previousDates(calendar: calendar), logs: sample, today: today,
                                            settings: settings, calendar: calendar)
    let trend = EarningsTrend.make(days: days, previousDays: previous, today: today, calendar: calendar)
    assertEqual(trend.current, [0, 5000, 7000], "Running totals stop at today")
    assertEqual(trend.total, 7000)
    assertEqual(trend.previous?.count, 31, "The ghost line covers the whole previous month")
    assertEqual(trend.previousBySameDay, 14000, "October had earned 14,000 by the 3rd")
    assertEqual(trend.previousTotal, 18000)
    assertEqual(trend.dayCount, 31, "Both lines share the longer month's axis")

    // A live sprint counts, like the Totals card.
    let live = LiveWork(day: calendar.startOfDay(for: today), seconds: 1800)
    let liveDays = AnalyticsComparison.bars(month.dates(calendar: calendar), logs: sample, today: today,
                                            settings: settings, calendar: calendar, live: live)
    assertEqual(EarningsTrend.make(days: liveDays, previousDays: nil, today: today, calendar: calendar).total, 7500)

    // No previous period, and empty input.
    let none = EarningsTrend.make(days: days, previousDays: nil, today: today, calendar: calendar)
    assertTrue(none.previous == nil && none.previousBySameDay == nil)
    let empty = EarningsTrend.make(days: [], previousDays: [], today: today, calendar: calendar)
    assertEqual(empty.total, 0)
    assertTrue(empty.previous == nil, "An empty previous period draws no ghost line")
    let quiet = AnalyticsComparison.bars(month.previousDates(calendar: calendar), logs: [:], today: today,
                                         settings: settings, calendar: calendar)
    assertTrue(EarningsTrend.make(days: days, previousDays: quiet, today: today, calendar: calendar).previous == nil,
               "A previous period with no earnings draws no ghost line")
    assertEqual(empty.dayCount, 1)
}

@MainActor
func testMenuBarProgressRing() {
    print("Running Menu bar progress ring tests...")
    let suite = "skeval-ring-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = GoalSettings(userDefaults: defaults)
    assertFalse(settings.showsMenuBarProgress, "The ring is off by default")
    settings.showsMenuBarProgress = true
    assertTrue(GoalSettings(userDefaults: defaults).showsMenuBarProgress, "The ring setting persists")

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    defer { NSStatusBar.system.removeStatusItem(item) }
    let presenter = StatusBarPresenter(statusItem: item)
    let plain = presenter.makePillImage(text: "00:30:00", state: .running)
    let ring = presenter.makePillImage(text: "00:30:00", state: .running, progress: 0.5)
    assertEqual(ring.size.width - plain.size.width, 4, "The ring takes 4 points more than the dot")
    presenter.update(state: .idle, accumulatedTotal: 3600, goalProgress: 0.564)
    assertTrue(item.button?.accessibilityLabel()?.contains("56 percent of daily goal") == true,
               "VoiceOver hears the whole percent, rounded down")
    presenter.update(state: .idle, accumulatedTotal: 3600, goalProgress: .nan)
    assertTrue(item.button?.accessibilityLabel()?.contains("0 percent") == true, "Bad input draws an empty ring")
    presenter.update(state: .idle, accumulatedTotal: 3600)
    assertFalse(item.button?.accessibilityLabel()?.contains("percent") == true, "With the ring off, no percent")
}

/// Every palette has every piece of theme art, so a new theme can't ship with blank headers.
func testThemeArtCoverage() {
    print("Running Theme art coverage tests...")
    let cases: [ThemeArt] = [.sun, .flag, .calendar, .bars, .stopwatch, .trophy, .mug]
    let folder = URL(fileURLWithPath: "Skeval Timer/Assets.xcassets/Art3D")
    var missing: [String] = []
    for app in AppTheme.allCases {
        for dark in [false, true] {
            let theme = app.theme(dark: dark)
            for art in cases {
                let name = "art-\(art.rawValue)-\(theme.name.lowercased())-\(theme.isLight ? "light" : "dark")"
                let file = folder.appendingPathComponent("\(name).imageset/\(name).png")
                if !FileManager.default.fileExists(atPath: file.path) { missing.append(name) }
            }
        }
    }
    assertTrue(missing.isEmpty, "Missing theme art (run scripts/render-app-art.sh): \(missing.prefix(5))")
    assertEqual(DashboardDestination.settings.art, nil, "Settings has no header art")
    assertEqual(DashboardDestination.today.art, .sun)
}
