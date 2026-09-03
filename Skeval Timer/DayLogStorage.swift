import Foundation

protocol DayLogStorage: AnyObject, Sendable {
    func loadAll() -> [String: [Sprint]]
    func saveAll(_ logs: [String: [Sprint]])
}

final class DiskDayLogAdapter: DayLogStorage, @unchecked Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let dir = support.appendingPathComponent("SkevalTimer", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("logs.json")
        }

        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        self.encoder = e

        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    func loadAll() -> [String: [Sprint]] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? decoder.decode([String: [Sprint]].self, from: data)) ?? [:]
    }

    func saveAll(_ logs: [String: [Sprint]]) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? encoder.encode(logs) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class InMemoryDayLogAdapter: DayLogStorage, @unchecked Sendable {
    private var logs: [String: [Sprint]]
    private let lock = NSLock()

    init(initialLogs: [String: [Sprint]] = [:]) {
        self.logs = initialLogs
    }

    func loadAll() -> [String: [Sprint]] {
        lock.lock()
        defer { lock.unlock() }
        return logs
    }

    func saveAll(_ logs: [String: [Sprint]]) {
        lock.lock()
        defer { lock.unlock() }
        self.logs = logs
    }
}
