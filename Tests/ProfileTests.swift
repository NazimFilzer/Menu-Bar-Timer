import Foundation

// MARK: - Helpers

private func temporaryProfileRoot() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("skeval-profile-tests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func profileTestDefaults() -> UserDefaults {
    let name = "skeval-profile-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private func completedSprint(day: Int, hours: Double) -> Sprint {
    let start = auditDate(2026, 11, day, hour: 9)
    return Sprint(startTime: start, endTime: start.addingTimeInterval(hours * 3600))
}

private func encodedLogs(_ logs: [String: [Sprint]]) -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return try! encoder.encode(logs)
}

private func profileError(_ body: () throws -> Void) -> ProfileError? {
    do { try body(); return nil } catch let error as ProfileError { return error } catch { return nil }
}

// MARK: - Registry rules

func testProfileRegistryRules() {
    var registry = ProfileRegistry.initial(name: "Skeval")
    assertEqual(registry.profiles.map(\.name), ["Skeval"], "A registry starts with one active profile")
    assertEqual(registry.active.name, "Skeval")

    let freelance = try! registry.add(name: "  Freelance  ")
    assertEqual(freelance.name, "Freelance", "Profile names are trimmed")
    assertTrue(freelance.colorIndex != registry.profiles[0].colorIndex, "A new profile gets a different colour")
    assertEqual(registry.active.name, "Skeval", "Adding a profile does not switch to it")

    assertEqual(profileError { _ = try registry.add(name: "   ") }, .emptyName, "Empty names are rejected")
    assertEqual(profileError { _ = try registry.add(name: "freelance") }, .duplicateName,
                "Names are unique ignoring capital letters")
    assertEqual(profileError { _ = try registry.add(name: String(repeating: "a", count: 31)) }, .nameTooLong,
                "Names are at most 30 characters")
    assertTrue(profileError { _ = try registry.add(name: String(repeating: "a", count: 30)) } == nil,
               "A 30-character name is allowed")

    try! registry.rename(id: registry.profiles[0].id, to: "Day job")
    assertEqual(registry.profiles[0].name, "Day job", "Any profile can be renamed, including the first")
    assertTrue(profileError { try registry.rename(id: freelance.id, to: "FREELANCE") } == nil,
               "Renaming to a different case of the same name is allowed")
    assertEqual(profileError { try registry.rename(id: freelance.id, to: "day job") }, .duplicateName)

    registry.activate(id: freelance.id)
    assertEqual(registry.active.id, freelance.id, "Activating changes the active profile")
    try! registry.remove(id: freelance.id)
    assertTrue(registry.active.id != freelance.id, "Removing the active profile activates another one")
    assertFalse(registry.profiles.contains { $0.id == freelance.id })

    while registry.profiles.count > 1 { try! registry.remove(id: registry.profiles.last!.id) }
    assertEqual(profileError { try registry.remove(id: registry.profiles[0].id) }, .lastProfile,
                "The last profile cannot be deleted")
}

func testProfileColoursCycleThroughThePalette() {
    var registry = ProfileRegistry.initial(name: "P0")
    for index in 1..<ProfileRegistry.colorCount { _ = try! registry.add(name: "P\(index)") }
    assertEqual(Set(registry.profiles.map(\.colorIndex)).count, ProfileRegistry.colorCount,
                "Every palette colour is used before any repeats")
    let extra = try! registry.add(name: "Extra")
    assertTrue((0..<ProfileRegistry.colorCount).contains(extra.colorIndex), "Colours wrap within the palette")
}

// MARK: - Disk storage and migration

func testProfileMigrationFromLegacyData() {
    let root = temporaryProfileRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = ["2026-11-02": [completedSprint(day: 2, hours: 3)]]
    try! encodedLogs(legacy).write(to: root.appendingPathComponent("logs.json"))
    let defaults = profileTestDefaults()
    defaults.set(6.5, forKey: "skevalDailyGoalHours")
    defaults.set(25.0, forKey: "skevalHourlyRate")
    defaults.set("$", forKey: "skevalCurrencySymbol")
    defaults.set([2, 3, 4], forKey: "skevalWorkingWeekdays")

    let library = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: defaults)
    assertEqual(library.profiles.map(\.name), ["Skeval"], "Existing data becomes the Skeval profile")
    let store = DayLogStore(storage: library.dayLogStorage(for: library.active.id))
    assertEqual(store.allLogs(), legacy, "Legacy history moves into the Skeval profile")
    let settings = GoalSettings(store: library.settingsStore(for: library.active.id))
    assertEqual(settings.dailyGoalHours, 6.5, "Legacy settings move into the Skeval profile")
    assertEqual(settings.hourlyRate, 25)
    assertEqual(settings.currencySymbol, "$")
    assertEqual(settings.workingWeekdays, [2, 3, 4])

    assertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("logs.json").path),
                "The legacy file no longer sits at the live path")
    let backups = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Backups").path)) ?? []
    assertEqual(backups.filter { $0.hasPrefix("logs-before-profiles") }.count, 1, "The original logs.json is backed up")

    store.save(sprint: completedSprint(day: 3, hours: 1))
    let reopened = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: defaults)
    assertEqual(reopened.profiles.map(\.id), library.profiles.map(\.id), "Migration runs only once")
    assertEqual(DayLogStore(storage: reopened.dayLogStorage(for: reopened.active.id)).allLogs().count, 2,
                "A second launch keeps new history")
}

func testProfileMigrationWithoutLegacyData() {
    let root = temporaryProfileRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let library = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    assertEqual(library.profiles.map(\.name), ["Skeval"], "A fresh install starts with a Skeval profile")
    assertEqual(DayLogStore(storage: library.dayLogStorage(for: library.active.id)).allLogs().count, 0)
    assertEqual(GoalSettings(store: library.settingsStore(for: library.active.id)).dailyGoalHours, 8,
                "A fresh install uses default settings")
}

func testProfileMigrationKeepsCorruptLegacyBytes() {
    let root = temporaryProfileRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let corrupt = Data("{not json".utf8)
    try! corrupt.write(to: root.appendingPathComponent("logs.json"))
    let library = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    let migrated = root.appendingPathComponent("Profiles/\(library.active.id.uuidString)/logs.json")
    assertEqual(try? Data(contentsOf: migrated), corrupt, "An unreadable legacy file is copied byte for byte")
    let store = DayLogStore(storage: library.dayLogStorage(for: library.active.id))
    assertTrue(store.storageError != nil, "The unreadable file is reported, not overwritten")
    store.save(sprint: completedSprint(day: 4, hours: 1))
    assertEqual(try? Data(contentsOf: migrated), corrupt, "Saving does not overwrite the unreadable file")
}

func testProfileLibraryAddRenameDeleteOnDisk() {
    let root = temporaryProfileRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let library = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    let skeval = library.active
    let skevalSettings = GoalSettings(store: library.settingsStore(for: skeval.id))
    skevalSettings.dailyGoalHours = 5
    skevalSettings.hourlyRate = 40

    let copied = try! library.add(name: "Copied", copyingSettingsFrom: skeval.id)
    let fresh = try! library.add(name: "Fresh", copyingSettingsFrom: nil)
    assertEqual(GoalSettings(store: library.settingsStore(for: copied.id)).dailyGoalHours, 5,
                "A new profile can copy the current settings")
    assertEqual(GoalSettings(store: library.settingsStore(for: copied.id)).hourlyRate, 40)
    assertEqual(GoalSettings(store: library.settingsStore(for: fresh.id)).dailyGoalHours, 8,
                "A new profile can start from defaults")
    assertEqual(DayLogStore(storage: library.dayLogStorage(for: copied.id)).allLogs().count, 0,
                "A new profile starts with no history")

    let copiedStore = DayLogStore(storage: library.dayLogStorage(for: copied.id))
    copiedStore.save(sprint: completedSprint(day: 2, hours: 2))
    copiedStore.save(sprint: completedSprint(day: 3, hours: 1.5))
    let summary = library.historySummary(for: copied.id)
    assertEqual(summary.workedSeconds, 3.5 * 3600, "The delete summary counts worked hours")
    assertEqual(summary.days, 2, "The delete summary counts days with work")

    try! library.rename(id: copied.id, to: "Client A")
    library.activate(id: fresh.id)
    let reopened = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    assertEqual(reopened.profiles.map(\.name), ["Skeval", "Client A", "Fresh"], "Names persist")
    assertEqual(reopened.active.id, fresh.id, "Relaunch opens the last active profile")

    try! reopened.remove(id: copied.id)
    assertEqual(reopened.profiles.map(\.name), ["Skeval", "Fresh"], "Deleting removes the profile")
    assertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Profiles/\(copied.id.uuidString)").path),
                "The deleted profile's folder leaves the live location")
    let backups = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Backups").path)) ?? []
    let archived = backups.first { $0.hasPrefix("profile-Client A-") }
    assertTrue(archived != nil, "The deleted profile is moved to Backups")
    if let archived {
        let logs = root.appendingPathComponent("Backups/\(archived)/logs.json")
        assertEqual(DayLogStore(storage: DiskDayLogAdapter(fileURL: logs)).allLogs().count, 2,
                    "The backup keeps the deleted history")
    }
}

func testProfileSettingsStaySeparate() {
    let library = ProfileLibrary(storage: InMemoryProfileStorage())
    let other = try! library.add(name: "Other", copyingSettingsFrom: nil)
    let settings = GoalSettings(store: library.settingsStore(for: library.active.id))
    settings.dailyGoalHours = 4
    settings.currencySymbol = "€"
    let otherFile = library.settingsStore(for: other.id)
    let otherBefore = GoalSettings(store: otherFile).dailyGoalHours

    settings.reload(from: otherFile)
    assertEqual(settings.dailyGoalHours, 8, "Reloading shows the other profile's settings")
    assertEqual(settings.currencySymbol, "₹")
    assertEqual(GoalSettings(store: library.settingsStore(for: library.active.id)).dailyGoalHours, 4,
                "Reloading does not overwrite the previous profile's settings")
    settings.dailyGoalHours = 9
    assertEqual(GoalSettings(store: otherFile).dailyGoalHours, 9, "Changes after reloading save to the new profile")
    assertEqual(otherBefore, 8)
    assertEqual(GoalSettings(store: library.settingsStore(for: library.active.id)).currencySymbol, "€")
}

// MARK: - Switching

@MainActor
private func makeProfileViewModel() -> (TimerViewModel, ProfileLibrary, SprintEngine) {
    let library = ProfileLibrary(storage: InMemoryProfileStorage())
    let store = DayLogStore(storage: library.dayLogStorage(for: library.active.id))
    let settings = GoalSettings(store: library.settingsStore(for: library.active.id))
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store, goal: settings, profiles: library,
                            deliverEyeBreakNotification: {})
    return (vm, library, engine)
}

@MainActor
func testProfileSwitchingKeepsHistorySeparate() {
    let (vm, library, _) = makeProfileViewModel()
    let first = library.active
    vm.goal.dailyGoalHours = 3
    vm.store.save(sprint: completedSprint(day: 2, hours: 2)); vm.refreshLogs()
    let second = try! vm.addProfile(name: "Freelance", startFromDefaults: true)
    assertEqual(library.active.id, first.id, "Adding a profile keeps the current one active")

    assertEqual(vm.profileSwitchAvailability, .allowed, "Idle timers can switch")
    assertTrue(vm.switchProfile(to: second.id), "Idle switching is instant")
    assertEqual(library.active.id, second.id)
    assertEqual(vm.store.allLogs().count, 0, "The new profile shows none of the old history")
    assertEqual(vm.goal.dailyGoalHours, 8, "The new profile has its own settings")

    vm.store.save(sprint: completedSprint(day: 5, hours: 1)); vm.refreshLogs()
    assertTrue(vm.switchProfile(to: first.id))
    assertEqual(Array(vm.store.allLogs().keys), ["2026-11-02"], "Switching back shows only the first profile's history")
    assertEqual(vm.goal.dailyGoalHours, 3, "Switching back restores the first profile's settings")
}

@MainActor
func testProfileSwitchRulesWhileTiming() {
    let (vm, library, engine) = makeProfileViewModel()
    let first = library.active
    let second = try! vm.addProfile(name: "Second", startFromDefaults: false)

    vm.clockIn()
    assertEqual(vm.profileSwitchAvailability, .needsClockOut, "A running sprint needs clocking out")
    assertFalse(vm.switchProfile(to: second.id), "Switching without clocking out is refused")
    assertEqual(library.active.id, first.id)
    vm.pause()
    assertEqual(vm.profileSwitchAvailability, .needsClockOut, "A paused sprint needs clocking out")
    assertEqual(profileError { try vm.deleteProfile(id: first.id) }, .profileInUse,
                "The active profile cannot be deleted while a sprint is open")

    assertTrue(vm.switchProfile(to: second.id, clockingOut: true), "Clock Out & Switch works")
    assertEqual(library.active.id, second.id)
    assertTrue(engine.state == .idle, "The sprint is clocked out")
    assertTrue(vm.switchProfile(to: first.id))
    assertEqual(vm.store.allLogs().values.joined().filter { !$0.isOpen }.count, 1,
                "The clocked-out sprint stays in the profile it was timed in")

    vm.clockIn()
    engine.handleSystemSleep(at: Date())
    engine.handleSystemWake(at: Date().addingTimeInterval(120))
    assertEqual(vm.profileSwitchAvailability, .blocked, "A sleep decision hold blocks switching")
    assertFalse(vm.switchProfile(to: second.id, clockingOut: true), "Blocked switches are refused")
    assertEqual(library.active.id, first.id)
}

@MainActor
func testDeletingTheActiveProfileSwitchesFirst() {
    let (vm, library, _) = makeProfileViewModel()
    let first = library.active
    let second = try! vm.addProfile(name: "Second", startFromDefaults: true)
    vm.store.save(sprint: completedSprint(day: 2, hours: 2)); vm.refreshLogs()
    try! vm.deleteProfile(id: first.id)
    assertEqual(library.profiles.map(\.id), [second.id], "The active profile is deleted")
    assertEqual(library.active.id, second.id, "Deleting the active profile switches to another one")
    assertEqual(vm.store.allLogs().count, 0, "The store now shows the remaining profile")
    assertEqual(profileError { try vm.deleteProfile(id: second.id) }, .lastProfile)
}

@MainActor
func testProfileSwitchResetsDayState() {
    let (vm, library, _) = makeProfileViewModel()
    let second = try! vm.addProfile(name: "Second", startFromDefaults: true)
    vm.selectDate(auditDate(2026, 11, 2))
    vm.plannedBreakMinutes = 30
    vm.pendingTag = "client"
    let revision = vm.logRevision
    assertTrue(vm.switchProfile(to: second.id))
    assertTrue(Calendar.current.isDateInToday(vm.selectedDate), "Switching returns to today")
    assertEqual(vm.plannedBreakMinutes, 0, "Planned breaks belong to the previous profile")
    assertEqual(vm.pendingTag, "", "The pending tag is cleared")
    assertTrue(vm.logRevision > revision, "Views reload after switching")
    assertEqual(vm.activeProfileName, "Second")
    _ = library
}

@MainActor
func testCSVFileNamesIncludeProfile() {
    assertEqual(CSVExporter.fileName("skeval-sprints-2026-11-10.csv", profileName: "Client A"),
                "skeval-Client A-sprints-2026-11-10.csv", "Exports name the profile")
    assertEqual(CSVExporter.fileName("skeval-sprints-export.csv", profileName: "A/B: C"),
                "skeval-A-B- C-sprints-export.csv", "Unsafe file name characters are replaced")
    assertEqual(CSVExporter.fileName("skeval-sprints-export.csv", profileName: nil),
                "skeval-sprints-export.csv", "Without a profile the name is unchanged")
}

func testUnreadableRegistryIsRebuiltFromFolders() {
    let root = temporaryProfileRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let library = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    let second = try! library.add(name: "Second", copyingSettingsFrom: nil)
    DayLogStore(storage: library.dayLogStorage(for: second.id)).save(sprint: completedSprint(day: 2, hours: 1))
    try! Data("garbage".utf8).write(to: root.appendingPathComponent("profiles.json"))

    let rebuilt = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    assertEqual(Set(rebuilt.profiles.map(\.id)), Set([library.profiles[0].id, second.id]),
                "An unreadable registry is rebuilt from the profile folders, not re-migrated")
    assertEqual(DayLogStore(storage: rebuilt.dayLogStorage(for: second.id)).allLogs().count, 1,
                "Rebuilt profiles keep their history")
    let backups = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Backups").path)) ?? []
    assertTrue(backups.contains { $0.hasPrefix("profiles-unreadable") }, "The unreadable registry is kept")
}

@MainActor
func testRecoverySprintBlocksProfileSwitch() {
    let library = ProfileLibrary(storage: InMemoryProfileStorage(
        legacyLogs: ["2026-11-02": [Sprint(startTime: auditDate(2026, 11, 2))]]))
    let second = try! library.add(name: "Second", copyingSettingsFrom: nil)
    let store = DayLogStore(storage: library.dayLogStorage(for: library.active.id))
    let engine = SprintEngine(store: store, observeWorkspace: false)
    let vm = TimerViewModel(engine: engine, store: store, goal: GoalSettings(store: InMemorySettingsStore()),
                            profiles: library, deliverEyeBreakNotification: {})
    assertTrue(vm.recoveryMode, "An open sprint found on launch is a Recovery Sprint")
    assertEqual(vm.profileSwitchAvailability, .blocked, "A Recovery Sprint blocks switching")
    assertFalse(vm.switchProfile(to: second.id, clockingOut: true), "Clock Out & Switch cannot skip recovery")
    vm.dismissRecovery()
    assertEqual(vm.profileSwitchAvailability, vm.isRunning ? .needsClockOut : .allowed,
                "Resolving recovery lifts the block")
}

func testUnreadableSettingsFileIsKept() {
    let root = temporaryProfileRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("settings.json")
    try! Data("{broken".utf8).write(to: url)
    let settings = GoalSettings(store: JSONSettingsFile(url: url))
    assertEqual(settings.dailyGoalHours, 8, "Unreadable settings fall back to defaults")
    settings.dailyGoalHours = 6
    let files = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
    assertEqual(files.filter { $0.hasPrefix("settings-unreadable-") }.count, 1, "The unreadable file is kept aside")
    assertEqual(GoalSettings(store: JSONSettingsFile(url: url)).dailyGoalHours, 6, "New changes save normally")
}

private func writeRegistry(_ registry: ProfileRegistry, to root: URL) {
    try! JSONEncoder().encode(registry).write(to: root.appendingPathComponent("profiles.json"))
}

func testInterruptedMigrationFinishesOnNextLaunch() {
    let root = temporaryProfileRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = ["2026-11-02": [completedSprint(day: 2, hours: 3)]]
    try! encodedLogs(legacy).write(to: root.appendingPathComponent("logs.json"))
    // State after a crash between writing the registry and copying the history.
    var registry = ProfileRegistry.initial(name: "Skeval")
    registry.setLegacyImportTarget(registry.activeID)
    writeRegistry(registry, to: root)

    let library = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    assertEqual(library.active.id, registry.activeID, "The interrupted registry is kept")
    assertEqual(DayLogStore(storage: library.dayLogStorage(for: library.active.id)).allLogs(), legacy,
                "The next launch finishes copying the history")
    assertTrue(library.migrationWarning == nil)
    assertTrue(library.registry.legacyImportTarget == nil, "A finished migration is not retried")
    assertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("logs.json").path),
                "The original moves to Backups once copied")
}

func testMissingRegistryIsRebuiltNotRemigrated() {
    let root = temporaryProfileRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = ["2026-11-02": [completedSprint(day: 2, hours: 3)]]
    try! encodedLogs(legacy).write(to: root.appendingPathComponent("logs.json"))
    let first = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    try! FileManager.default.removeItem(at: root.appendingPathComponent("profiles.json"))

    let reopened = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    assertEqual(reopened.profiles.map(\.id), [first.active.id], "A missing registry is rebuilt from the folders")
    assertEqual(reopened.active.name, "Skeval")
    assertEqual(DayLogStore(storage: reopened.dayLogStorage(for: reopened.active.id)).allLogs(), legacy,
                "The rebuilt profile still shows the history")
}

func testDifferingLegacyHistoryIsKeptWithWarning() {
    let root = temporaryProfileRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let library = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    let id = library.active.id
    DayLogStore(storage: library.dayLogStorage(for: id)).save(sprint: completedSprint(day: 5, hours: 1))
    let legacy = ["2026-11-02": [completedSprint(day: 2, hours: 3)]]
    try! encodedLogs(legacy).write(to: root.appendingPathComponent("logs.json"))
    var registry = library.registry
    registry.setLegacyImportTarget(id)
    writeRegistry(registry, to: root)

    let reopened = ProfileLibrary(storage: DiskProfileStorage(root: root), legacyDefaults: profileTestDefaults())
    assertTrue(reopened.migrationWarning != nil, "Differing histories are reported")
    assertEqual(Array(DayLogStore(storage: reopened.dayLogStorage(for: id)).allLogs().keys), ["2026-11-05"],
                "The profile's own history is never overwritten")
    assertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("logs.json").path),
               "The earlier history stays in place")
}
