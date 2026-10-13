import Foundation

private final class DelayedFirstSave: DayLogStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var logs: [String: [Sprint]] = [:]
    private var saveCount = 0
    let firstSaveStarted = DispatchSemaphore(value: 0)
    let releaseFirstSave = DispatchSemaphore(value: 0)

    func loadAll() -> [String: [Sprint]] {
        lock.lock()
        defer { lock.unlock() }
        return logs
    }

    func saveAll(_ logs: [String: [Sprint]]) {
        lock.lock()
        saveCount += 1
        let isFirst = saveCount == 1
        lock.unlock()
        if isFirst {
            firstSaveStarted.signal()
            _ = releaseFirstSave.wait(timeout: .now() + 2)
        }
        lock.lock()
        self.logs = logs
        lock.unlock()
    }
}

func testPersistenceAudit() {
    print("Running persistence failure and concurrency audit...")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("skeval-storage-audit-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("logs.json")
    let malformed = Data("{ damaged user logs".utf8)
    try! malformed.write(to: file)
    let adapter = DiskDayLogAdapter(fileURL: file)
    let store = DayLogStore(storage: adapter)
    let day = auditDate(2026, 3, 17)
    store.save(sprint: Sprint(startTime: day, endTime: day.addingTimeInterval(3600)))
    assertEqual(try! Data(contentsOf: file), malformed, "Invalid existing logs must not be overwritten silently")
    assertTrue(store.storageError != nil, "Unreadable logs expose a visible error")
    let missingParent = directory.appendingPathComponent("missing")
    let failedAdapter = DiskDayLogAdapter(fileURL: missingParent.appendingPathComponent("logs.json"))
    let failedStore = DayLogStore(storage: failedAdapter)
    failedStore.save(sprint: Sprint(startTime: day, endTime: day.addingTimeInterval(3600)))
    assertTrue(failedStore.storageError != nil, "Failed writes expose an error")
    assertEqual(failedStore.log(for: day).completedSprints.count, 1, "Failed writes retain work in memory")
    try! FileManager.default.createDirectory(at: missingParent, withIntermediateDirectories: true)
    failedStore.save(sprint: Sprint(startTime: day.addingTimeInterval(7200), endTime: day.addingTimeInterval(10800)))
    assertTrue(failedStore.storageError == nil, "A successful retry clears the save warning")
    assertEqual(DayLogStore(storage: failedAdapter).log(for: day).completedSprints.count, 2)

    // Force writes to finish in reverse order to detect a stale persisted snapshot.
    let delayed = DelayedFirstSave()
    let concurrentStore = DayLogStore(storage: delayed)
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global().async {
        concurrentStore.save(sprint: Sprint(startTime: day, endTime: day.addingTimeInterval(3600)))
        group.leave()
    }
    assertEqual(delayed.firstSaveStarted.wait(timeout: .now() + 2), .success)
    group.enter()
    DispatchQueue.global().async {
        concurrentStore.save(sprint: Sprint(startTime: day.addingTimeInterval(7200), endTime: day.addingTimeInterval(10800)))
        group.leave()
    }
    // A short timeout gives the second writer a chance without blocking a serialized writer.
    _ = group.wait(timeout: .now() + 0.1)
    delayed.releaseFirstSave.signal()
    assertEqual(group.wait(timeout: .now() + 2), .success)
    assertEqual(DayLogStore(storage: delayed).log(for: day).completedSprints.count, 2,
                "Concurrent saves preserve the newest complete snapshot")
}
