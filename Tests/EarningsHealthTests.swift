import Foundation

@MainActor
func testEarningsReadStability() {
    print("Running decimal earnings stability and update stress tests...")
    let suite = "skeval-earnings-health-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = GoalSettings(userDefaults: defaults)
    settings.hourlyRate = 1234.56
    let storage = EarningsHealthStorage()
    let store = DayLogStore(storage: storage)
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store, goal: settings)
    engine.clockIn()
    defer { engine.reset() }
    let writes = storage.writes
    let revision = vm.logRevision
    let state = engine.state
    // Re-read the same displayed value as SwiftUI does during rendering.
    vm.currentElapsed = 1
    for _ in 0..<10_000 {
        assertEqual(vm.todayEarningsLabel, "₹0.34")
        assertEqual(vm.displayedEarningsLabel, "₹0.34")
    }
    // Sample a day's elapsed time without accumulating rounded tick amounts.
    for seconds in stride(from: 0, through: 86_400, by: 10) {
        vm.currentElapsed = Double(seconds)
        let expected = Double(seconds) * 1234.56 / 3600
        assertTrue(abs(vm.displayedEarnings - expected) < 0.0000001,
                   "Earnings derive from elapsed time, without cumulative rounding drift")
        assertEqual(vm.displayedEarningsLabel,
                    EarningsCalculator.format(amount: expected, currencySymbol: "₹"))
    }
    assertEqual(engine.state, state, "Reading earnings must not feed back into the engine")
    assertEqual(vm.logRevision, revision, "Reading earnings must not refresh logs")
    assertEqual(storage.writes, writes, "Rendering earnings must not write to disk")
}

@MainActor
func testTickerCleanup() {
    print("Running active and paused timer disposal tests...")
    for paused in [false, true] {
        let store = DayLogStore(storage: InMemoryDayLogAdapter())
        var engine: SprintEngine? = SprintEngine(store: store, observeWorkspace: false)
        engine!.clockIn()
        if paused { engine!.pause() }
        // Inspect the actual run-loop resource without adding a production test API.
        let timer = Mirror(reflecting: engine!).children.first { $0.label == "ticker" }?.value as? Timer
        assertTrue(timer?.isValid == true, "A running engine owns a valid timer")
        weak var releasedEngine = engine
        engine = nil
        assertTrue(releasedEngine == nil, "The timer must not retain its engine")
        assertTrue(timer?.isValid == false, "Disposing the engine must invalidate its run-loop timer")
    }
}

private final class EarningsHealthStorage: DayLogStorage, @unchecked Sendable {
    private let storage = InMemoryDayLogAdapter()
    private(set) var writes = 0

    func loadAll() -> [String: [Sprint]] { storage.loadAll() }
    func saveAll(_ logs: [String: [Sprint]]) {
        writes += 1
        storage.saveAll(logs)
    }
}
