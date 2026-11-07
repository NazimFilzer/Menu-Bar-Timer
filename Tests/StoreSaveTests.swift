import Foundation

private final class HeldSaveAdapter: DayLogStorage, @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    private let memory = InMemoryDayLogAdapter()

    func loadAll() -> [String: [Sprint]] { memory.loadAll() }

    func saveAll(_ logs: [String: [Sprint]]) {
        entered.signal()
        _ = release.wait(timeout: .now() + 5)
        memory.saveAll(logs)
    }
}

func testStoreReadsDuringSave() {
    let adapter = HeldSaveAdapter()
    let store = DayLogStore(storage: adapter)
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let sprint = Sprint(startTime: start, endTime: start.addingTimeInterval(60))
    let saved = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        store.save(sprint: sprint)
        saved.signal()
    }
    assertTrue(adapter.entered.wait(timeout: .now() + 2) == .success)
    let read = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        _ = store.log(for: start)
        read.signal()
    }
    let readFinished = read.wait(timeout: .now() + 1) == .success
    adapter.release.signal()
    assertTrue(saved.wait(timeout: .now() + 2) == .success)
    assertTrue(readFinished, "A slow save must not block reads of in-memory logs")
    assertEqual(store.log(for: start).completedSprints, [sprint])

    let memory = InMemoryDayLogAdapter()
    let concurrentStore = DayLogStore(storage: memory)
    DispatchQueue.concurrentPerform(iterations: 30) { index in
        let date = start.addingTimeInterval(Double(index) * 120)
        concurrentStore.save(sprint: Sprint(startTime: date, endTime: date.addingTimeInterval(60)))
    }
    assertEqual(memory.loadAll(), concurrentStore.allLogs(), "Concurrent saves persist the latest complete snapshot")
    assertEqual(memory.loadAll().values.flatMap { $0 }.count, 30)
}
