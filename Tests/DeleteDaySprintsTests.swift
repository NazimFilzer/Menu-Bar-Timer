import Foundation

@MainActor
func testDeleteDaySprints() {
    let calendar = Calendar.current
    let storage = InMemoryDayLogAdapter()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store, goal: auditSettings())

    // These dates include both US daylight-saving transitions when the tests run in New York.
    for (month, day) in [(3, 8), (11, 1)] {
        let date = calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
        let start = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start)!
        let previousDay = calendar.date(byAdding: .day, value: -1, to: start)!
        let crossing = Sprint(startTime: start.addingTimeInterval(-300), endTime: start.addingTimeInterval(300))
        let first = Sprint(startTime: start.addingTimeInterval(3600), endTime: start.addingTimeInterval(7200), pausedDuration: 600)
        let last = Sprint(startTime: nextDay.addingTimeInterval(-1800), endTime: nextDay.addingTimeInterval(1800))
        let neighbor = Sprint(startTime: nextDay.addingTimeInterval(3600), endTime: nextDay.addingTimeInterval(7200))
        [crossing, first, last, neighbor].forEach { store.save(sprint: $0) }

        vm.selectDate(date)
        vm.refreshLogs()
        let revision = vm.logRevision
        vm.deleteCompletedSprints(for: date)
        assertEqual(vm.logRevision, revision + 1)
        assertTrue(vm.selectedDayLog.completedSprints.isEmpty)
        assertEqual(store.log(for: previousDay).completedSprints, [crossing])
        assertEqual(store.log(for: nextDay).completedSprints, [neighbor])
        assertTrue(DayLogStore(storage: storage).log(for: date).sprints.isEmpty)
        assertEqual(WeeklyAnalytics.calculate(logs: store.allLogs(), referenceDate: date, settings: vm.goal).days.first { calendar.isDate($0.date, inSameDayAs: date) }?.sprintCount, 0)
        assertEqual(MonthlyAnalytics.calculate(logs: store.allLogs(), referenceDate: date, settings: vm.goal).days.first { calendar.isDate($0.date, inSameDayAs: date) }?.sprintCount, 0)
        assertEqual(InsightsAnalytics.calculatePeriodSummary(logs: store.allLogs(), startDate: date, endDate: date, settings: vm.goal).days.first?.sprintCount, 0)
        vm.deleteCompletedSprints(for: date)
        assertEqual(vm.logRevision, revision + 1, "Deleting an empty day does not refresh logs")
    }

    let now = calendar.startOfDay(for: Date()).addingTimeInterval(1200)
    let completed = Sprint(startTime: now.addingTimeInterval(-600), endTime: now.addingTimeInterval(-300))
    store.save(sprint: completed)
    engine.clockIn(at: now)
    engine.pause(at: now.addingTimeInterval(10))
    let open = store.log(for: now).openSprint
    vm.refreshLogs()
    vm.deleteCompletedSprints(for: now)
    assertEqual(store.log(for: now).sprints, open.map { [$0] } ?? [])
    assertEqual(DayLogStore(storage: storage).log(for: now).openSprint, open)
    assertEqual(engine.state.currentSprint?.id, open?.id)
    engine.clockOut(at: now.addingTimeInterval(30))
    assertEqual(store.log(for: now).completedSprints.first?.id, open?.id)
}
