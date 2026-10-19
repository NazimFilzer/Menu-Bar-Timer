import Foundation

protocol DayLogStorage: AnyObject, Sendable {
    var errorDescription: String? { get }
    func loadAll() -> [String: [Sprint]]
    func saveAll(_ logs: [String: [Sprint]])
}

extension DayLogStorage {
    var errorDescription: String? { nil }
}

final class DiskDayLogAdapter: DayLogStorage, @unchecked Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()
    private var failedToLoad = false
    private var lastError: String?

    var errorDescription: String? {
        lock.lock()
        defer { lock.unlock() }
        return lastError
    }

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
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        do {
            let logs = try decoder.decode([String: [Sprint]].self, from: Data(contentsOf: fileURL))
            failedToLoad = false
            lastError = nil
            return logs
        } catch {
            failedToLoad = true
            lastError = "Saved logs could not be read. The original file has been kept at \(fileURL.path). Restore it before restarting the app."
            return [:]
        }
    }

    func saveAll(_ logs: [String: [Sprint]]) {
        lock.lock()
        defer { lock.unlock() }
        guard !failedToLoad else { return }
        do {
            let data = try encoder.encode(logs)
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Logs could not be saved: \(error.localizedDescription) Your changes are still in this app. Export them before quitting."
        }
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
