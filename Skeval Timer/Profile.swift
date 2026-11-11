import Foundation
import Observation

/// A fully separate set of time tracking with its own history and settings. See ADR 0004.
struct Profile: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var colorIndex: Int
}

enum ProfileError: Error, Equatable, LocalizedError {
    case emptyName
    case nameTooLong
    case duplicateName
    case lastProfile
    case profileInUse
    case unknownProfile
    case profilesUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Enter a profile name."
        case .nameTooLong: return "Use \(ProfileRegistry.maxNameLength) characters or fewer."
        case .duplicateName: return "Another profile already has this name."
        case .lastProfile: return "The last profile cannot be deleted."
        case .profileInUse: return "Clock out before deleting the active profile."
        case .unknownProfile: return "This profile no longer exists."
        case .profilesUnavailable: return "Profiles are not available here."
        }
    }
}

/// The list of profiles and which one is active. Pure rules; persistence lives in `ProfileStorage`.
struct ProfileRegistry: Codable, Equatable {
    static let maxNameLength = 30
    static let colorCount = 8
    static let firstProfileName = "Skeval"

    private(set) var profiles: [Profile]
    private(set) var activeID: UUID
    /// The profile that receives pre-profile history, until that history is safely moved in.
    private(set) var legacyImportTarget: UUID?

    static func initial(name: String, id: UUID = UUID()) -> ProfileRegistry {
        ProfileRegistry(profiles: [Profile(id: id, name: name, colorIndex: 0)], activeID: id)
    }

    mutating func setLegacyImportTarget(_ id: UUID?) {
        legacyImportTarget = id.flatMap { profile(id: $0)?.id }
    }

    var active: Profile { profiles.first { $0.id == activeID } ?? profiles[0] }

    func profile(id: UUID) -> Profile? { profiles.first { $0.id == id } }

    func validatedName(_ name: String, excluding id: UUID? = nil) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProfileError.emptyName }
        guard trimmed.count <= Self.maxNameLength else { throw ProfileError.nameTooLong }
        let taken = profiles.contains { $0.id != id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
        guard !taken else { throw ProfileError.duplicateName }
        return trimmed
    }

    @discardableResult
    mutating func add(name: String, id: UUID = UUID()) throws -> Profile {
        let profile = Profile(id: id, name: try validatedName(name), colorIndex: nextColorIndex())
        profiles.append(profile)
        return profile
    }

    mutating func rename(id: UUID, to name: String) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { throw ProfileError.unknownProfile }
        profiles[index].name = try validatedName(name, excluding: id)
    }

    mutating func remove(id: UUID) throws {
        guard profiles.contains(where: { $0.id == id }) else { throw ProfileError.unknownProfile }
        guard profiles.count > 1 else { throw ProfileError.lastProfile }
        profiles.removeAll { $0.id == id }
        if activeID == id { activeID = profiles[0].id }
    }

    mutating func activate(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeID = id
    }

    /// The least-used palette colour, lowest index first.
    private func nextColorIndex() -> Int {
        let usage = Dictionary(grouping: profiles, by: { $0.colorIndex % Self.colorCount }).mapValues(\.count)
        return (0..<Self.colorCount).min { (usage[$0] ?? 0, $0) < (usage[$1] ?? 0, $1) } ?? 0
    }
}

struct ProfileHistorySummary: Equatable {
    var workedSeconds: TimeInterval
    var days: Int
}

// MARK: - Library

/// Owns the profile registry and hands out each profile's storage. Use from the main thread.
@Observable
final class ProfileLibrary {
    static let shared = ProfileLibrary(storage: DiskProfileStorage.live(), legacyDefaults: .standard)

    @ObservationIgnored private let storage: ProfileStorage
    private(set) var registry: ProfileRegistry
    /// Set when pre-profile history could not be moved into its profile. Shown with storage errors.
    private(set) var migrationWarning: String?

    /// Loads the registry, or creates a "Skeval" profile for the original history and settings on first launch.
    init(storage: ProfileStorage, legacyDefaults: UserDefaults? = nil) {
        self.storage = storage
        if let existing = storage.loadRegistry() {
            registry = existing
        } else {
            var first = ProfileRegistry.initial(name: ProfileRegistry.firstProfileName)
            first.setLegacyImportTarget(first.activeID)
            if let legacyDefaults {
                Self.copySettings(from: legacyDefaults, to: storage.settingsStore(for: first.activeID))
            }
            // Written before any history moves, so a crash part-way resumes below on the next launch.
            storage.saveRegistry(first)
            registry = first
        }
        moveLegacyHistoryIfNeeded()
    }

    /// Moves pre-profile history into its profile. Runs every launch until it succeeds, so an
    /// interrupted or failed first launch finishes later instead of leaving the profile empty.
    private func moveLegacyHistoryIfNeeded() {
        guard let target = registry.legacyImportTarget else { return }
        switch storage.importLegacyData(into: target) {
        case .done:
            var updated = registry
            updated.setLegacyImportTarget(nil)
            commit(updated)
        case .failed(let message):
            migrationWarning = message
        }
    }

    var profiles: [Profile] { registry.profiles }
    var active: Profile { registry.active }

    func dayLogStorage(for id: UUID) -> DayLogStorage { storage.dayLogStorage(for: id) }
    func settingsStore(for id: UUID) -> SettingsValueStore { storage.settingsStore(for: id) }

    @discardableResult
    func add(name: String, copyingSettingsFrom source: UUID?) throws -> Profile {
        var updated = registry
        let profile = try updated.add(name: name)
        if let source {
            Self.copySettings(from: storage.settingsStore(for: source), to: storage.settingsStore(for: profile.id))
        }
        commit(updated)
        return profile
    }

    func rename(id: UUID, to name: String) throws {
        var updated = registry
        try updated.rename(id: id, to: name)
        commit(updated)
    }

    func activate(id: UUID) {
        var updated = registry
        updated.activate(id: id)
        commit(updated)
    }

    /// Removes the profile and moves its folder to Backups. Switch away from the active profile first.
    func remove(id: UUID) throws {
        guard let profile = registry.profile(id: id) else { throw ProfileError.unknownProfile }
        var updated = registry
        try updated.remove(id: id)
        commit(updated)
        storage.archive(profile)
    }

    func historySummary(for id: UUID) -> ProfileHistorySummary {
        let logs = storage.dayLogStorage(for: id).loadAll()
        let days = logs.values.map { DayLog(sprints: $0) }.filter { !$0.completedSprints.isEmpty }
        return ProfileHistorySummary(workedSeconds: days.map(\.accumulatedTotal).reduce(0, +), days: days.count)
    }

    private static func copySettings(from source: SettingsValueStore, to destination: SettingsValueStore) {
        for key in GoalSettings.profileKeys {
            if let value = source.object(forKey: key) { destination.set(value, forKey: key) }
        }
    }

    private func commit(_ updated: ProfileRegistry) {
        guard updated != registry else { return }
        storage.saveRegistry(updated)
        registry = updated
    }
}

// MARK: - Storage seam

protocol ProfileStorage: AnyObject {
    func loadRegistry() -> ProfileRegistry?
    func saveRegistry(_ registry: ProfileRegistry)
    /// Returns the same instance for the same id.
    func dayLogStorage(for id: UUID) -> DayLogStorage
    func settingsStore(for id: UUID) -> SettingsValueStore
    /// Moves pre-profile history into the given profile, keeping the original in Backups.
    /// Never overwrites history the profile already has.
    func importLegacyData(into id: UUID) -> LegacyImportResult
    func archive(_ profile: Profile)
}

enum LegacyImportResult: Equatable {
    case done
    case failed(String)
}

/// Makes user text safe inside a file name by replacing `/`, `:`, and `\\` with dashes.
enum FileNameComponent {
    static func safe(_ name: String) -> String {
        String(name.map { "/:\\".contains($0) ? "-" : $0 })
    }
}

/// `SkevalTimer/profiles.json` plus `SkevalTimer/Profiles/<id>/{logs.json, settings.json}`.
/// Main thread only, like `ProfileLibrary`: the adapter caches are not locked.
/// The `DiskDayLogAdapter`s it hands out lock themselves.
final class DiskProfileStorage: ProfileStorage {
    private let root: URL
    private let fileManager = FileManager.default
    private var dayLogAdapters: [UUID: DiskDayLogAdapter] = [:]
    private var settingsFiles: [UUID: JSONSettingsFile] = [:]

    static func live() -> DiskProfileStorage {
        // Test and Preview builds set this so they can never migrate or write real history.
        if ProcessInfo.processInfo.environment["SKEVAL_NO_LIVE_DATA"] != nil {
            fatalError("Live profile storage was opened in a run that must use in-memory data.")
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return DiskProfileStorage(root: support.appendingPathComponent("SkevalTimer", isDirectory: true))
    }

    init(root: URL) {
        self.root = root
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private var registryURL: URL { root.appendingPathComponent("profiles.json") }
    private var legacyLogsURL: URL { root.appendingPathComponent("logs.json") }
    private var backupsURL: URL { root.appendingPathComponent("Backups", isDirectory: true) }
    private func folder(for id: UUID) -> URL {
        root.appendingPathComponent("Profiles", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func loadRegistry() -> ProfileRegistry? {
        if let data = try? Data(contentsOf: registryURL) {
            if let registry = try? JSONDecoder().decode(ProfileRegistry.self, from: data), !registry.profiles.isEmpty {
                return registry
            }
            moveToBackups(registryURL, name: "profiles-unreadable")
        }
        // Missing or unreadable: rebuild from the profile folders rather than starting an empty migration.
        let ids = ((try? fileManager.contentsOfDirectory(atPath: root.appendingPathComponent("Profiles").path)) ?? [])
            .compactMap(UUID.init(uuidString:)).sorted { $0.uuidString < $1.uuidString }
        guard let first = ids.first else { return nil }
        var rebuilt = ProfileRegistry.initial(name: ProfileRegistry.firstProfileName, id: first)
        for (offset, id) in ids.dropFirst().enumerated() { _ = try? rebuilt.add(name: "Profile \(offset + 2)", id: id) }
        if fileManager.fileExists(atPath: legacyLogsURL.path) { rebuilt.setLegacyImportTarget(first) }
        saveRegistry(rebuilt)
        return rebuilt
    }

    func saveRegistry(_ registry: ProfileRegistry) {
        guard let data = try? JSONEncoder().encode(registry) else { return }
        try? data.write(to: registryURL, options: .atomic)
    }

    func dayLogStorage(for id: UUID) -> DayLogStorage {
        if let existing = dayLogAdapters[id] { return existing }
        let directory = folder(for: id)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let adapter = DiskDayLogAdapter(fileURL: directory.appendingPathComponent("logs.json"))
        dayLogAdapters[id] = adapter
        return adapter
    }

    func settingsStore(for id: UUID) -> SettingsValueStore {
        if let existing = settingsFiles[id] { return existing }
        let directory = folder(for: id)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = JSONSettingsFile(url: directory.appendingPathComponent("settings.json"))
        settingsFiles[id] = file
        return file
    }

    func importLegacyData(into id: UUID) -> LegacyImportResult {
        guard fileManager.fileExists(atPath: legacyLogsURL.path) else { return .done }
        let directory = folder(for: id)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("logs.json")
        if fileManager.fileExists(atPath: destination.path) {
            // Already copied by an interrupted launch: finish by backing up the original.
            guard fileManager.contentsEqual(atPath: destination.path, andPath: legacyLogsURL.path) else {
                return .failed("Earlier history at \(legacyLogsURL.path) was not moved into this profile because the profile already has its own history. Both files are kept.")
            }
        } else {
            // Raw bytes, so an unreadable file still arrives intact; renamed into place so a crash never leaves half a copy.
            let partial = directory.appendingPathComponent("logs.json.partial")
            try? fileManager.removeItem(at: partial)
            do {
                try fileManager.copyItem(at: legacyLogsURL, to: partial)
                try fileManager.moveItem(at: partial, to: destination)
            } catch {
                return .failed("Earlier history could not be moved into this profile (\(error.localizedDescription)). It is still at \(legacyLogsURL.path); the app retries on the next launch.")
            }
        }
        moveToBackups(legacyLogsURL, name: "logs-before-profiles", pathExtension: "json")
        return .done
    }

    func archive(_ profile: Profile) {
        dayLogAdapters[profile.id] = nil
        settingsFiles[profile.id] = nil
        let safeName = FileNameComponent.safe(profile.name)
        moveToBackups(folder(for: profile.id), name: "profile-\(safeName)")
    }

    private func moveToBackups(_ url: URL, name: String, pathExtension: String? = nil) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let base = "\(name)-\(formatter.string(from: Date()))"
        func candidate(_ attempt: Int) -> URL {
            let stem = attempt == 0 ? base : "\(base)-\(attempt)"
            return backupsURL.appendingPathComponent(pathExtension.map { "\(stem).\($0)" } ?? stem)
        }
        var attempt = 0
        while fileManager.fileExists(atPath: candidate(attempt).path) { attempt += 1 }
        let target = candidate(attempt)
        try? fileManager.moveItem(at: url, to: target)
    }
}

/// Keeps profiles in memory for tests and the Preview app.
final class InMemoryProfileStorage: ProfileStorage {
    private var registry: ProfileRegistry?
    private var dayLogs: [UUID: InMemoryDayLogAdapter] = [:]
    private var settings: [UUID: InMemorySettingsStore] = [:]
    private let legacyLogs: [String: [Sprint]]
    private var legacyImported = false
    private(set) var archived: [Profile] = []

    init(legacyLogs: [String: [Sprint]] = [:]) {
        self.legacyLogs = legacyLogs
    }

    func loadRegistry() -> ProfileRegistry? { registry }
    func saveRegistry(_ registry: ProfileRegistry) { self.registry = registry }

    func dayLogStorage(for id: UUID) -> DayLogStorage {
        if let existing = dayLogs[id] { return existing }
        let adapter = InMemoryDayLogAdapter()
        dayLogs[id] = adapter
        return adapter
    }

    func settingsStore(for id: UUID) -> SettingsValueStore {
        if let existing = settings[id] { return existing }
        let store = InMemorySettingsStore()
        settings[id] = store
        return store
    }

    func importLegacyData(into id: UUID) -> LegacyImportResult {
        if !legacyImported {
            dayLogs[id] = InMemoryDayLogAdapter(initialLogs: legacyLogs)
            legacyImported = true
        }
        return .done
    }

    func archive(_ profile: Profile) {
        archived.append(profile)
        dayLogs[profile.id] = nil
        settings[profile.id] = nil
    }
}

// MARK: - Settings seam

/// The key-value calls `GoalSettings` needs. `UserDefaults` conforms as-is.
protocol SettingsValueStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: SettingsValueStore {}

final class InMemorySettingsStore: SettingsValueStore {
    private var values: [String: Any] = [:]
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

/// A profile's `settings.json`, rewritten atomically on every change.
final class JSONSettingsFile: SettingsValueStore {
    private let url: URL
    private var values: [String: Any]

    init(url: URL) {
        self.url = url
        guard let data = try? Data(contentsOf: url) else { values = [:]; return }
        if let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            values = decoded
            return
        }
        // Keep an unreadable file beside the new one instead of overwriting it on the next change.
        values = [:]
        let kept = url.deletingLastPathComponent()
            .appendingPathComponent("settings-unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: kept)
    }

    func object(forKey key: String) -> Any? { values[key] }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? data.write(to: url, options: .atomic)
    }
}
