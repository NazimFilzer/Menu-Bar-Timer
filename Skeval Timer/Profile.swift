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

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Enter a profile name."
        case .nameTooLong: return "Use \(ProfileRegistry.maxNameLength) characters or fewer."
        case .duplicateName: return "Another profile already has this name."
        case .lastProfile: return "The last profile cannot be deleted."
        case .profileInUse: return "Clock out before deleting the active profile."
        case .unknownProfile: return "This profile no longer exists."
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

    static func initial(name: String, id: UUID = UUID()) -> ProfileRegistry {
        ProfileRegistry(profiles: [Profile(id: id, name: name, colorIndex: 0)], activeID: id)
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

/// Owns the profile registry and hands out each profile's storage.
@Observable
final class ProfileLibrary {
    static let shared = ProfileLibrary(storage: DiskProfileStorage.live(), legacyDefaults: .standard)

    @ObservationIgnored private let storage: ProfileStorage
    private(set) var registry: ProfileRegistry

    /// Loads the registry, or moves the original history and settings into a "Skeval" profile on first launch.
    init(storage: ProfileStorage, legacyDefaults: UserDefaults? = nil) {
        self.storage = storage
        if let existing = storage.loadRegistry() {
            registry = existing
            return
        }
        let first = ProfileRegistry.initial(name: ProfileRegistry.firstProfileName)
        let imported = storage.importLegacyData(into: first.activeID)
        if let legacyDefaults {
            Self.copySettings(from: legacyDefaults, to: storage.settingsStore(for: first.activeID))
        }
        // The registry marks the migration as done, so it is written before the original moves.
        // If the copy failed, the original stays where it is instead of moving to Backups.
        storage.saveRegistry(first)
        if imported { storage.finishLegacyImport() }
        registry = first
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
    /// Copies pre-profile history into the given profile. The original stays until `finishLegacyImport`.
    /// Returns false when existing history could not be copied.
    func importLegacyData(into id: UUID) -> Bool
    func finishLegacyImport()
    func archive(_ profile: Profile)
}

/// `SkevalTimer/profiles.json` plus `SkevalTimer/Profiles/<id>/{logs.json, settings.json}`.
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
        guard let data = try? Data(contentsOf: registryURL) else { return nil }
        if let registry = try? JSONDecoder().decode(ProfileRegistry.self, from: data), !registry.profiles.isEmpty {
            return registry
        }
        // Keep the unreadable registry and rebuild it from the profile folders.
        moveToBackups(registryURL, name: "profiles-unreadable")
        let ids = ((try? fileManager.contentsOfDirectory(atPath: root.appendingPathComponent("Profiles").path)) ?? [])
            .compactMap(UUID.init(uuidString:)).sorted { $0.uuidString < $1.uuidString }
        guard let first = ids.first else { return nil }
        var rebuilt = ProfileRegistry.initial(name: "Profile 1", id: first)
        for (offset, id) in ids.dropFirst().enumerated() { _ = try? rebuilt.add(name: "Profile \(offset + 2)", id: id) }
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

    func importLegacyData(into id: UUID) -> Bool {
        let directory = folder(for: id)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: legacyLogsURL.path) else { return true }
        // Raw bytes: an unreadable file must still arrive intact.
        let destination = directory.appendingPathComponent("logs.json")
        try? fileManager.removeItem(at: destination)
        do {
            try fileManager.copyItem(at: legacyLogsURL, to: destination)
            return true
        } catch {
            NSLog("Skeval Timer could not copy %@ into the first profile: %@", legacyLogsURL.path, error.localizedDescription)
            return false
        }
    }

    func finishLegacyImport() {
        moveToBackups(legacyLogsURL, name: "logs-before-profiles", pathExtension: "json")
    }

    func archive(_ profile: Profile) {
        dayLogAdapters[profile.id] = nil
        settingsFiles[profile.id] = nil
        let safeName = CSVExporter.safeFileComponent(profile.name)
        moveToBackups(folder(for: profile.id), name: "profile-\(safeName)")
    }

    private func moveToBackups(_ url: URL, name: String, pathExtension: String? = nil) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        var target = backupsURL.appendingPathComponent("\(name)-\(formatter.string(from: Date()))")
        if let pathExtension { target.appendPathExtension(pathExtension) }
        while fileManager.fileExists(atPath: target.path) {
            target = target.deletingPathExtension().appendingPathExtension("1")
            if let pathExtension { target.appendPathExtension(pathExtension) }
        }
        try? fileManager.moveItem(at: url, to: target)
    }
}

/// Keeps profiles in memory for tests and the Preview app.
final class InMemoryProfileStorage: ProfileStorage {
    private var registry: ProfileRegistry?
    private var dayLogs: [UUID: InMemoryDayLogAdapter] = [:]
    private var settings: [UUID: InMemorySettingsStore] = [:]
    private let legacyLogs: [String: [Sprint]]
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

    func importLegacyData(into id: UUID) -> Bool {
        dayLogs[id] = InMemoryDayLogAdapter(initialLogs: legacyLogs)
        return true
    }

    func finishLegacyImport() {}

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
        let data = try? Data(contentsOf: url)
        values = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
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
