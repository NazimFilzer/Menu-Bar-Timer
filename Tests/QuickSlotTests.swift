import Foundation

func testQuickSlotFinder() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
    func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 11, second: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))!
    }
    func slot(_ minutes: Int, on day: Date, _ logs: [String: [Sprint]], now: Date) -> SprintEntry? {
        SprintEntry.latestFreeSlot(minutes: minutes, on: day, in: logs, now: now, calendar: cal)
    }
    let now = at(13, 9, 0, second: 42)

    let empty = slot(10, on: now, [:], now: now)
    assertEqual(empty?.start, at(13, 8, 50), "Empty day: slot ends at now, floored to the minute")
    assertEqual(empty?.end, at(13, 9, 0))
    assertEqual(empty?.pausedDuration, 0)

    // 8:30–9:00 busy, 8:10–8:20 busy: a 10-min gap fits 8:20–8:30, a 20-min one must go before 8:10.
    let logs = ["d": [Sprint(startTime: at(13, 8, 30), endTime: at(13, 9, 0)),
                      Sprint(startTime: at(13, 8, 10), endTime: at(13, 8, 20))]]
    assertEqual(slot(10, on: now, logs, now: now)?.start, at(13, 8, 20), "Fits the latest gap")
    assertEqual(slot(20, on: now, logs, now: now)?.end, at(13, 8, 10), "Too-small gaps are skipped")

    let active = ["d": [Sprint(startTime: at(13, 8, 0))]]
    assertEqual(slot(30, on: now, active, now: now)?.end, at(13, 8, 0), "A running sprint pushes the slot before its start")

    let overnight = ["12": [Sprint(startTime: at(12, 22, 0), endTime: at(13, 2, 0))]]
    let early = at(13, 2, 30)
    assertTrue(slot(60, on: early, overnight, now: early) == nil, "Overnight sprint in yesterday's bucket blocks the morning")
    assertEqual(slot(30, on: early, overnight, now: early)?.start, at(13, 2, 0))

    let full = ["d": [Sprint(startTime: at(13, 0, 0), endTime: at(13, 9, 0))]]
    assertTrue(slot(10, on: now, full, now: now) == nil, "A full day has no slot")
    assertTrue(slot(0, on: now, [:], now: now) == nil, "Zero minutes is rejected")

    let past = slot(90, on: at(10, 12), [:], now: now)
    assertEqual(past?.end, at(10, 23, 59), "Past day: slot ends at 23:59")
    assertTrue(slot(10, on: at(14, 12), [:], now: now) == nil, "Future day has no slot")

    // 2026-03-29: Berlin springs forward 02:00 → 03:00.
    let dstNow = at(29, 3, 20, month: 3)
    let dst = slot(50, on: dstNow, [:], now: dstNow)
    assertEqual(dst?.end, dstNow, "DST day: ends at now")
    assertEqual(dst.map { $0.end.timeIntervalSince($0.start) }, 3000, "DST day: real 50 minutes")
    if let dst {
        let roundTrip = try? SprintEntry(date: dstNow, startTime: dst.start, endTime: dst.end,
                                         pausedDuration: 0, endDayOffset: 0, calendar: cal)
        assertEqual(roundTrip?.start, dst.start, "DST slot survives the form round trip")
        assertEqual(roundTrip?.end, dst.end)
    }
    let gap = SprintEntry.findOverlaps(with: slot(10, on: now, logs, now: now)!, in: logs, now: now)
    assertTrue(gap.isEmpty, "Generated slots never conflict")
}
