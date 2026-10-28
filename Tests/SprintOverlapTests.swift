import Foundation

func testSprintOverlaps() {
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    func date(_ hours: Double) -> Date { base.addingTimeInterval(hours * 3600) }
    func entry(_ start: Double, _ end: Double) -> SprintEntry {
        try! SprintEntry(start: date(start), end: date(end), pausedDuration: 0)
    }
    let existing = Sprint(startTime: date(1), endTime: date(3), pausedDuration: 1800)
    let logs = ["previous-day": [existing]]
    func matches(_ start: Double, _ end: Double) -> [Sprint] {
        overlappingSprints(entry: entry(start, end), logs: logs, now: date(10))
    }
    assertTrue(matches(0, 1).isEmpty, "Touching the start is not an overlap")
    assertTrue(matches(3, 4).isEmpty, "Touching the end is not an overlap")
    assertEqual(matches(0, 2), [existing], "Partial overlap")
    assertEqual(matches(2, 4), [existing], "Partial overlap at the end")
    assertEqual(matches(0, 4), [existing], "Entry contains existing sprint")
    assertEqual(matches(1.5, 2), [existing], "Pause totals do not remove occupied time")
    assertTrue(overlappingSprints(entry: entry(1, 3), logs: logs, excluding: existing.id).isEmpty,
               "Editing excludes the original ID")

    let long = Sprint(startTime: date(-48), endTime: date(26))
    let overnight = Sprint(startTime: date(-2), endTime: date(2))
    let active = Sprint(startTime: date(2))
    let paused = Sprint(startTime: date(2), isPaused: true, pauseStartedAt: date(3))
    let buckets = ["older": [long, overnight], "today": [active, paused]]
    let conflicts = overlappingSprints(entry: entry(1, 4), logs: buckets, now: date(3))
    assertEqual(Set(conflicts.map(\.id)), Set([long.id, overnight.id, active.id, paused.id]),
                "Multi-day, overnight and unfinished entries in different buckets conflict")
    assertTrue(overlappingSprints(entry: entry(3, 4), logs: ["today": [active, paused]], now: date(3)).isEmpty,
               "Open sprints end at the time of the check")
    assertTrue(overlappingSprints(entry: entry(0, 1), logs: ["future": [Sprint(startTime: date(5))]], now: date(3)).isEmpty,
               "An open sprint has no occupied interval before it starts")
}
