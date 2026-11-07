import Foundation

func testDailyTimeline() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let day = auditDate(2026, 11, 4, hour: 0, calendar: calendar)
    func date(_ hour: Double) -> Date { day.addingTimeInterval(hour * 3600) }
    func timeline(_ sprints: [Sprint], hours: TimelineHours = TimelineHours(), now: Double = 16,
                  live: TimelineLiveSprint? = nil) -> DailyTimeline {
        DailyTimeline.calculate(sprints: sprints, live: live, date: day, hours: hours,
                                now: date(now), calendar: calendar)
    }
    let first = Sprint(startTime: date(8), endTime: date(9))
    let second = Sprint(startTime: date(10), endTime: date(12), pausedDuration: 900)
    let result = timeline([first, second])
    assertEqual(result.visible.start, date(6))
    assertEqual(result.visible.end, date(24))
    assertEqual(result.segments.count, 2)
    assertEqual(result.segments.map(\.displayName), ["Sprint 1", "Sprint 2"])
    assertEqual(timeline([second, first]).segments.map(\.number), [1, 2], "Numbers follow start time, not storage order")
    var tagged = first
    tagged.tag = "Design"
    assertEqual(timeline([tagged]).segments[0].displayName, "Sprint 1 · Design")
    assertEqual(result.segments[1].interval.duration, 7200, "Pauses do not move actual end time")
    assertEqual(result.segments[1].netWork, 6300)
    assertEqual(result.gaps.map(\.duration), [7200, 3600, 14400])
    assertEqual(result.gaps.last?.end, date(16), "Future time is not untracked time")
    assertEqual(timeline([]).gaps.map(\.duration), [36000])
    assertEqual(timeline([], now: 5).gaps.count, 0)
    let early = Sprint(startTime: date(5.5), endTime: date(6.5))
    let late = Sprint(startTime: date(22), endTime: date(23.25))
    let expanded = timeline([early, late], hours: TimelineHours(startHour: 6, endHour: 18))
    assertEqual(expanded.visible.start, date(5))
    assertEqual(expanded.visible.end, date(24))
    assertEqual(timeline([late], hours: TimelineHours(startHour: 6, endHour: 18)).visible.end, date(24))
    let exact = Sprint(startTime: date(20), endTime: date(22))
    assertEqual(timeline([exact], hours: TimelineHours(startHour: 6, endHour: 18)).visible.end, date(22))
    let night = Sprint(startTime: date(-1), endTime: date(1), pausedDuration: 600)
    let continuation = timeline([night]).segments[0]
    assertTrue(continuation.continuesBefore)
    assertFalse(continuation.continuesAfter)
    assertEqual(continuation.interval.start, day)
    assertEqual(continuation.interval.end, date(1))
    assertEqual(continuation.sprint.startTime, date(-1), "Start-day attribution is retained")
    assertEqual(continuation.netWork, 6600, "Continuation details show the whole sprint's net work")
    let previous = Sprint(startTime: date(-3), endTime: date(-2))
    let nextDay = timeline([first, night, previous])
    assertEqual(nextDay.segments.map(\.number), [2, 1], "A continuation keeps its start-day number; the new day starts at 1")
    let previousDay = DailyTimeline.calculate(sprints: [night, previous], date: date(-1), now: date(16), calendar: calendar)
    assertEqual(previousDay.segments.last?.displayName, nextDay.segments.first?.displayName)
    let crossing = Sprint(startTime: date(23), endTime: date(25))
    assertTrue(timeline([crossing]).segments[0].continuesAfter)
    assertEqual(timeline([crossing]).segments[0].interval.end, date(24))
    let midnightEnd = Sprint(startTime: date(-1), endTime: date(0))
    assertEqual(timeline([midnightEnd]).segments.count, 0, "Half-open day excludes a sprint ending at midnight")
    let overlapping = Sprint(startTime: date(10.5), endTime: date(11.5))
    let columns = timeline([second, overlapping]).segments
    assertEqual(columns.map(\.columnCount), [2, 2])
    assertEqual(Set(columns.map(\.column)), Set([0, 1]))
    let touching = Sprint(startTime: date(12), endTime: date(13))
    assertEqual(timeline([second, touching]).segments.map(\.columnCount), [1, 1])
    let nested = Sprint(startTime: date(10.75), endTime: date(11))
    assertEqual(timeline([second, overlapping, nested]).segments.map(\.columnCount), [3, 3, 3])
    let open = Sprint(startTime: date(14))
    let paused = TimelineLiveSprint(sprint: open, status: .paused, netWork: 3600, paused: 3600, unresolvedStart: nil)
    let live = timeline([open], live: paused)
    assertEqual(live.segments.count, 1, "Persisted open sprint and live sprint appear once")
    assertEqual(timeline([first, second, open], live: paused).segments.last?.number, 3, "The current sprint follows recorded sprints")
    assertEqual(live.segments[0].netWork, 3600)
    assertEqual(live.segments[0].interval.end, date(16))
    assertEqual(timeline([open]).segments.count, 0, "Unresolved persisted records require live state")
    let held = TimelineLiveSprint(sprint: open, status: .sleep, netWork: 3600, paused: 0, unresolvedStart: date(15))
    assertEqual(timeline([open], live: held).segments[0].unresolvedStart, date(15))
    let recovery = TimelineLiveSprint(sprint: open, status: .recovery, netWork: nil, paused: 0, unresolvedStart: date(14))
    assertEqual(timeline([open], live: recovery).segments[0].netWork, nil)
    assertEqual(timeline([first], now: 30).gaps.last?.end, date(24))
    assertEqual(TimelineHours(startHour: 23, endHour: 6), TimelineHours())
    assertEqual(TimelineHours(startHour: -1, endHour: 24), TimelineHours())
    testDailyTimelineVisualColumns()
}

func testDailyTimelineVisualColumns() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let day = auditDate(2026, 11, 4, hour: 0, calendar: calendar)
    func date(_ hour: Int, _ minute: Int) -> Date {
        day.addingTimeInterval(Double(hour * 60 + minute) * 60)
    }
    let sprints = [
        Sprint(startTime: date(8, 4), endTime: date(9, 51), pausedDuration: 25 * 60),
        Sprint(startTime: date(9, 59), endTime: date(10, 8)),
        Sprint(startTime: date(10, 12), endTime: date(11, 1)),
        Sprint(startTime: date(11, 4), endTime: date(11, 11)),
        Sprint(startTime: date(11, 15), endTime: date(11, 49)),
        Sprint(startTime: date(13, 0), endTime: date(14, 0))
    ]
    let timeline = DailyTimeline.calculate(sprints: sprints, date: day, now: date(16, 0), calendar: calendar)
    let arranged = DailyTimelineLayout.arrange(timeline.segments)
    assertEqual(arranged.map(\.columnCount), [1, 2, 2, 2, 2, 1],
                "Short blocks share the existing width when their screen heights collide")
    assertEqual(arranged.map(\.column), [0, 0, 1, 0, 1, 0])
    assertEqual(arranged.map(\.interval), timeline.segments.map(\.interval), "Layout retains exact clock positions")
    assertEqual(arranged.map(\.netWork), timeline.segments.map(\.netWork), "Layout does not change net work")
    assertEqual(arranged.map(\.paused), timeline.segments.map(\.paused), "Layout does not change paused totals")
    assertEqual(DailyTimelineLayout.arrange(arranged).map(\.column), arranged.map(\.column),
                "Column placement is stable when recalculated")
    assertTimelineBlocksDoNotOverlap(arranged)

    let dense = (0..<5).map { minute in
        Sprint(startTime: date(10, minute), endTime: date(10, minute).addingTimeInterval(30))
    }
    let denseTimeline = DailyTimeline.calculate(sprints: dense, date: day, now: date(16, 0), calendar: calendar)
    let denseLayout = DailyTimelineLayout.arrange(denseTimeline.segments)
    assertEqual(denseLayout.map(\.columnCount), Array(repeating: 5, count: 5))
    assertTimelineBlocksDoNotOverlap(denseLayout)

    let chain = [Sprint(startTime: date(10, 0), endTime: date(10, 1)),
                 Sprint(startTime: date(10, 10), endTime: date(10, 11)),
                 Sprint(startTime: date(10, 21), endTime: date(10, 22))]
    let chainTimeline = DailyTimeline.calculate(sprints: chain, date: day, now: date(16, 0), calendar: calendar)
    let chainLayout = DailyTimelineLayout.arrange(chainTimeline.segments)
    assertEqual(chainLayout.map(\.column), [0, 1, 0], "Reuse a column once its earlier block clears")
    assertEqual(chainLayout.map(\.columnCount), [2, 2, 2])
    assertTimelineBlocksDoNotOverlap(chainLayout)

    let liveSprint = Sprint(startTime: date(11, 15))
    for status in [TimelineSprintStatus.active, .paused, .sleep, .recovery] {
        let live = TimelineLiveSprint(sprint: liveSprint, status: status, netWork: 60, paused: 0,
                                      unresolvedStart: nil)
        let current = DailyTimeline.calculate(sprints: Array(sprints.prefix(4)), live: live, date: day,
                                             now: date(11, 16), calendar: calendar)
        let currentLayout = DailyTimelineLayout.arrange(current.segments)
        assertEqual(currentLayout.suffix(2).map(\.columnCount), [2, 2],
                    "A short current sprint must clear the previous completed block")
        assertTimelineBlocksDoNotOverlap(currentLayout)
    }

    // An imported overlapping sprint can sit behind the active sprint's external label.
    let live = TimelineLiveSprint(sprint: Sprint(startTime: date(10, 0)), status: .active,
                                  netWork: 60, paused: 0, unresolvedStart: nil)
    let imported = Sprint(startTime: date(10, 10), endTime: date(10, 30))
    let withLabel = DailyTimeline.calculate(sprints: [imported], live: live, date: day,
                                           now: date(10, 1), calendar: calendar)
    let labelLayout = DailyTimelineLayout.arrange(withLabel.segments)
    assertEqual(labelLayout.map(\.columnCount), [2, 2], "External active labels reserve space too")
    assertTimelineBlocksDoNotOverlap(labelLayout)

    let touching = [Sprint(startTime: date(10, 0), endTime: date(11, 0)),
                    Sprint(startTime: date(11, 0), endTime: date(12, 0))]
    let touchingTimeline = DailyTimeline.calculate(sprints: touching, date: day, now: date(16, 0), calendar: calendar)
    assertEqual(DailyTimelineLayout.arrange(touchingTimeline.segments).map(\.columnCount), [1, 1],
                "Full-size blocks that touch in time keep full width")

    let overlapping = [touching[0], Sprint(startTime: date(11, 0).addingTimeInterval(-30), endTime: date(12, 0))]
    let overlappingTimeline = DailyTimeline.calculate(sprints: overlapping, date: day,
                                                     now: date(16, 0), calendar: calendar)
    assertEqual(DailyTimelineLayout.arrange(overlappingTimeline.segments).map(\.columnCount), [2, 2],
                "Actual overlapping times use columns even when the block gap could hide the overlap")
}

private func assertTimelineBlocksDoNotOverlap(_ segments: [TimelineSegment]) {
    for (index, first) in segments.enumerated() {
        for second in segments.dropFirst(index + 1) where first.column == second.column {
            let separation = DailyTimelineLayout.height(second.interval.start.timeIntervalSince(first.interval.start))
            assertTrue(separation >= DailyTimelineLayout.occupiedHeight(for: first),
                       "Blocks in the same column must have room for their labels")
        }
    }
}

func testDailyTimelineDST() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    for (month, day, expectedHours) in [(3, 8, 23), (11, 1, 25)] {
        let start = auditDate(2026, month, day, hour: 0, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let sprint = Sprint(startTime: start, endTime: end)
        let result = DailyTimeline.calculate(sprints: [sprint], date: start,
                                             hours: TimelineHours(startHour: 0, endHour: 24),
                                             now: end, calendar: calendar)
        assertEqual(result.visible.duration, Double(expectedHours * 3600))
        assertEqual(result.hourMarks.count, expectedHours + 1)
        assertEqual(result.segments[0].netWork, Double(expectedHours * 3600))
        assertEqual(result.gaps.count, 0)
        let arranged = DailyTimelineLayout.arrange(result.segments)
        assertEqual(arranged[0].interval, result.segments[0].interval, "Layout retains DST clock spans")
        assertEqual(arranged[0].columnCount, 1)
        let six = DailyTimeline.calculate(sprints: [], date: start, now: end, calendar: calendar)
        assertEqual(calendar.component(.hour, from: six.visible.start), 6)
    }
}

@MainActor
func testDailyTimelineViewModelAndSettings() {
    let suite = "skeval-timeline-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = GoalSettings(userDefaults: defaults)
    assertEqual(settings.timelineHours, TimelineHours())
    settings.timelineHours = TimelineHours(startHour: 8, endHour: 20)
    assertEqual(GoalSettings(userDefaults: defaults).timelineHours, TimelineHours(startHour: 8, endHour: 20))
    defaults.set(99, forKey: "skevalTimelineStartHour")
    assertEqual(GoalSettings(userDefaults: defaults).timelineHours, TimelineHours())
    let store = DayLogStore(storage: InMemoryDayLogAdapter())
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store, goal: settings)
    let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(8 * 3600)
    let now = start.addingTimeInterval(2 * 3600)
    vm.selectDate(start)
    engine.clockIn(at: start)
    engine.pause(at: start.addingTimeInterval(3600))
    let paused = vm.dailyTimeline(now: now).segments[0]
    assertEqual(paused.status, .paused)
    assertEqual(paused.netWork, 3600)
    engine.resume(at: now)
    engine.handleSystemSleep(at: now.addingTimeInterval(3600))
    engine.handleSystemWake(at: now.addingTimeInterval(7200))
    let held = vm.dailyTimeline(now: now.addingTimeInterval(7500)).segments[0]
    assertEqual(held.status, .sleep)
    assertEqual(held.unresolvedStart, now.addingTimeInterval(3600))
    assertEqual(held.paused, 3600, "Unresolved sleep is not labeled as confirmed paused time")
    engine.resolveSleepInterval(countAsWork: false, at: now.addingTimeInterval(7500))
    assertEqual(vm.dailyTimeline(now: now.addingTimeInterval(7500)).segments[0].status, .active)
    engine.clockOut(at: now.addingTimeInterval(7800))
    let completed = vm.dailyTimeline(now: now.addingTimeInterval(7800)).segments[0]
    assertEqual(completed.status, .completed)
    assertEqual(completed.paused, 7500)
    let reopened = DayLogStore(storage: InMemoryDayLogAdapter(initialLogs: store.allLogs()))
    assertEqual(reopened.allLogs(), store.allLogs())
}

@MainActor
func testDailyTimelineReadsOnlyNearbyDays() {
    let suite = "skeval-timeline-nearby-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let store = DayLogStore(storage: InMemoryDayLogAdapter())
    // Old history, an overnight sprint from yesterday, and two sprints today.
    for daysAgo in 2...40 {
        let s = cal.date(byAdding: .day, value: -daysAgo, to: today)!.addingTimeInterval(9 * 3600)
        store.save(sprint: Sprint(startTime: s, endTime: s.addingTimeInterval(3600)))
    }
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
    store.save(sprint: Sprint(startTime: yesterday.addingTimeInterval(10 * 3600), endTime: yesterday.addingTimeInterval(11 * 3600)))
    let overnight = Sprint(startTime: yesterday.addingTimeInterval(22 * 3600), endTime: today.addingTimeInterval(3600))
    store.save(sprint: overnight)
    for hour in [9.0, 13.0] {
        store.save(sprint: Sprint(startTime: today.addingTimeInterval(hour * 3600), endTime: today.addingTimeInterval((hour + 1) * 3600)))
    }
    let vm = TimerViewModel(engine: SprintEngine(store: store, observeWorkspace: false), store: store,
                            goal: GoalSettings(userDefaults: defaults))
    vm.selectDate(today)
    let now = today.addingTimeInterval(20 * 3600)
    let fast = vm.dailyTimeline(now: now)
    let full = DailyTimeline.calculate(sprints: store.allLogs().values.flatMap { $0 }, date: today,
                                       hours: vm.goal.timelineHours, now: now, calendar: cal)
    assertEqual(fast.segments.map(\.id), full.segments.map(\.id), "Nearby days give the same sprints as full history")
    assertEqual(fast.segments.map(\.number), full.segments.map(\.number), "Sprint numbers match full history")
    assertEqual(fast.segments.first?.id, overnight.id, "Yesterday's overnight sprint continues into today")
    assertEqual(fast.segments.first?.number, 2, "The overnight sprint keeps its number from its start day")
    assertTrue(fast.segments.first?.continuesBefore == true)
    assertEqual(fast.segments.count, 3)
    assertEqual(fast.gaps, full.gaps, "Untracked gaps are unchanged")
}
