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

    var storageError: String? { storage.errorDescription }

    func todayLog() -> DayLog {
        log(for: Date())
    }

    func log(for date: Date) -> DayLog {
        let key = TimeFormatter.format(dateKey: date)
        return log(for: key)
    }

    func log(for dateKey: String) -> DayLog {
        lock.lock()
        defer { lock.unlock() }
        return DayLog(sprints: logs[dateKey] ?? [])
    }

    func allLogs() -> [String: [Sprint]] {
        lock.lock()
        defer { lock.unlock() }
        return logs
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
        defer { lock.unlock() }
        let newKey = TimeFormatter.format(dateKey: sprint.startTime)
        for (key, bucket) in logs where key != newKey {
            if bucket.contains(where: { $0.id == sprint.id }) {
                var updatedBucket = bucket
                updatedBucket.removeAll { $0.id == sprint.id }
                if updatedBucket.isEmpty {
                    logs.removeValue(forKey: key)
                } else {
                    logs[key] = updatedBucket
                }
            }
        }
        var targetBucket = logs[newKey] ?? []
        if let idx = targetBucket.firstIndex(where: { $0.id == sprint.id }) {
            targetBucket[idx] = sprint
        } else {
            targetBucket.append(sprint)
        }
        targetBucket.sort { $0.startTime < $1.startTime }
        logs[newKey] = targetBucket
        storage.saveAll(logs)
    }

    func delete(sprint: Sprint) {
        delete(sprintId: sprint.id, preferredDate: sprint.startTime)
    }

    func delete(sprintId: UUID, preferredDate: Date? = nil) {
        lock.lock()
        defer { lock.unlock() }
        guard let key = dayKey(containing: sprintId, preferredDate: preferredDate), var bucket = logs[key] else { return }
        bucket.removeAll { $0.id == sprintId }
        logs[key] = bucket.isEmpty ? nil : bucket
        storage.saveAll(logs)
    }

    private func dayKey(containing sprintId: UUID, preferredDate: Date?) -> String? {
        if let date = preferredDate {
            let key = TimeFormatter.format(dateKey: date)
            if logs[key]?.contains(where: { $0.id == sprintId }) == true { return key }
        }
        return logs.first { $0.value.contains { $0.id == sprintId } }?.key
    }
}
