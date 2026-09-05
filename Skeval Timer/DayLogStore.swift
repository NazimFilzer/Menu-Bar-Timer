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
        let snapshot = logs
        lock.unlock()

        storage.saveAll(snapshot)
    }

    func delete(sprint: Sprint) {
        delete(sprintId: sprint.id, preferredDate: sprint.startTime)
    }

    func delete(sprintId: UUID, preferredDate: Date? = nil) {
        lock.lock()
        var found = false
        if let pref = preferredDate {
            let key = TimeFormatter.format(dateKey: pref)
            if var bucket = logs[key], let idx = bucket.firstIndex(where: { $0.id == sprintId }) {
                bucket.remove(at: idx)
                if bucket.isEmpty {
                    logs.removeValue(forKey: key)
                } else {
                    logs[key] = bucket
                }
                found = true
            }
        }
        if !found {
            for (key, bucket) in logs {
                if let idx = bucket.firstIndex(where: { $0.id == sprintId }) {
                    var updated = bucket
                    updated.remove(at: idx)
                    if updated.isEmpty {
                        logs.removeValue(forKey: key)
                    } else {
                        logs[key] = updated
                    }
                    break
                }
            }
        }
        let snapshot = logs
        lock.unlock()

        storage.saveAll(snapshot)
    }
}
