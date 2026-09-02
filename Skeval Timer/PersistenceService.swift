import Foundation

class PersistenceService {
    static let shared = PersistenceService()

    private var logs: [String: [Sprint]] = [:]

    private var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("SkevalTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("logs.json")
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() { load() }

    func todayLog() -> DayLog {
        DayLog(sprints: logs[dateKey(Date())] ?? [])
    }

    func save(sprint: Sprint) {
        let key = dateKey(sprint.startTime)
        var bucket = logs[key] ?? []
        if let idx = bucket.firstIndex(where: { $0.id == sprint.id }) {
            bucket[idx] = sprint
        } else {
            bucket.append(sprint)
        }
        logs[key] = bucket
        persist()
    }

    func delete(sprint: Sprint) {
        let key = dateKey(sprint.startTime)
        logs[key]?.removeAll { $0.id == sprint.id }
        persist()
    }

    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        logs = (try? decoder.decode([String: [Sprint]].self, from: data)) ?? [:]
    }

    private func persist() {
        guard let data = try? encoder.encode(logs) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
