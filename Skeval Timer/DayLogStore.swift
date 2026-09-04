import Foundation

final class DayLogStore: @unchecked Sendable {
    static let shared = DayLogStore()

    private let storage: DayLogStorage
    private var logs: [String: [Sprint]] = [:]
    private let lock = NSLock()

    init(storage: DayLogStorage = DiskDayLogAdapter()) {
        self.storage = storage
        self.logs = storage.loadAll()
    }

    func todayLog() -> DayLog {
        log(for: Date())
    }

    func log(for date: Date) -> DayLog {
        lock.lock()
        defer { lock.unlock() }
        let key = TimeFormatter.format(dateKey: date)
        return DayLog(sprints: logs[key] ?? [])
    }

    func findOpenSprint() -> (dayKey: String, sprint: Sprint)? {
        lock.lock()
        defer { lock.unlock() }
        for (key, bucket) in logs {
            if let open = bucket.first(where: { $0.isOpen }) {
                return (key, open)
            }
        }
        return nil
    }

    func save(sprint: Sprint) {
        lock.lock()
        let key = TimeFormatter.format(dateKey: sprint.startTime)
        var bucket = logs[key] ?? []
        if let idx = bucket.firstIndex(where: { $0.id == sprint.id }) {
            bucket[idx] = sprint
        } else {
            bucket.append(sprint)
        }
        logs[key] = bucket
        let snapshot = logs
        lock.unlock()

        storage.saveAll(snapshot)
    }

    func delete(sprint: Sprint) {
        lock.lock()
        let key = TimeFormatter.format(dateKey: sprint.startTime)
        guard var bucket = logs[key] else {
            lock.unlock()
            return
        }
        bucket.removeAll { $0.id == sprint.id }
        if bucket.isEmpty {
            logs.removeValue(forKey: key)
        } else {
            logs[key] = bucket
        }
        let snapshot = logs
        lock.unlock()

        storage.saveAll(snapshot)
    }
}
