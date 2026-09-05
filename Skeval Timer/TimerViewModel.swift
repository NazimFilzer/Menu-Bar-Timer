import Foundation
import AppKit
import Observation
import UserNotifications

@Observable
@MainActor
class TimerViewModel {

    // MARK: - Observed state
    private(set) var state: SprintState = .idle
    var currentElapsed: TimeInterval = 0
    var currentPauseElapsed: TimeInterval = 0
    var todayLog: DayLog = DayLog()
    var lastCopiedId: UUID? = nil
    var logRevision: Int = 0
    var pendingTag: String = ""

    // Recovery inputs
    var recoveryEndText: String = ""
    var recoveryEndError: String? = nil

    var goal = GoalSettings.shared
    var isSettingsExpanded: Bool = false

    let engine: SprintEngine
    let store: DayLogStore

    private var notifiedMilestones: Set<Int> = []
    private var lastNotifiedDayKey: String = TimeFormatter.format(dateKey: Date())

    // MARK: - Init

    init(engine: SprintEngine? = nil, store: DayLogStore? = nil) {
        let effectiveStore = store ?? DayLogStore.shared
        self.store = effectiveStore
        let effectiveEngine = engine ?? SprintEngine(store: effectiveStore)
        self.engine = effectiveEngine

        self.todayLog = effectiveStore.todayLog()
        self.state = effectiveEngine.state
        self.currentElapsed = effectiveEngine.state.currentElapsed
        self.currentPauseElapsed = effectiveEngine.currentPauseElapsed

        let goalSec = goal.dailyGoalSeconds
        if goalSec > 0 {
            let initialPct = Int((self.todayLog.accumulatedTotal / goalSec) * 100)
            for m in [50, 75, 100] where initialPct >= m {
                self.notifiedMilestones.insert(m)
            }
        }

        setupEngineCallbacks()
    }

    private func setupEngineCallbacks() {
        engine.onStateChanged = { [weak self] newState in
            guard let self else { return }
            self.state = newState
            self.currentElapsed = newState.currentElapsed
            if !newState.isPaused {
                self.currentPauseElapsed = 0
            }
            self.todayLog = self.store.todayLog()
            if !newState.isRecovery {
                self.recoveryEndText = ""
                self.recoveryEndError = nil
            }
        }

        engine.onTick = { [weak self] elapsed in
            guard let self else { return }
            self.currentElapsed = elapsed
            self.checkMilestoneNotifications()
        }

        engine.onPauseTick = { [weak self] pauseElapsed in
            self?.currentPauseElapsed = pauseElapsed
        }

        engine.onSprintCompleted = { [weak self] sprint in
            guard let self else { return }
            self.todayLog = self.store.todayLog()
            self.copy(sprint: sprint)
            self.checkMilestoneNotifications()
        }

        engine.onSleepIntervalDetected = { [weak self] interval in
            self?.sendSleepNotification(interval: interval)
        }
    }

    // MARK: - Forwarded Properties

    var currentSprint: Sprint? { state.currentSprint }
    var isRunning: Bool { state.isRunning }
    var isPaused: Bool { state.isPaused }
    var recoveryMode: Bool { state.isRecovery }
    var isTicking: Bool { state.isRunning && !state.isPaused }
    var pendingSleepInterval: SleepInterval? { engine.pendingSleepInterval }
    var hasPendingSleepResolution: Bool { engine.pendingSleepInterval != nil }
    var statusTitle: String {
        if hasPendingSleepResolution { return "SLEEP HELD" }
        return state.statusTitle
    }

    var currentElapsedLabel: String {
        TimeFormatter.format(clock: currentElapsed)
    }

    var currentPauseLabel: String {
        TimeFormatter.format(clock: currentPauseElapsed)
    }

    var totalSprintPausedLabel: String {
        TimeFormatter.format(duration: engine.totalCurrentSprintPaused)
    }

    var hasMultiplePauses: Bool {
        engine.totalCurrentSprintPaused > currentPauseElapsed + 1
    }

    var menuBarTitle: String {
        if isPaused { return TimeFormatter.format(shortClock: currentPauseElapsed) }
        if isRunning { return TimeFormatter.format(shortClock: currentElapsed) }
        let acc = todayLog.accumulatedTotal
        return acc > 0 ? todayLog.accumulatedShortLabel : ""
    }

    var progressFraction: Double {
        let g = goal.dailyGoalSeconds
        guard g > 0 else { return 0 }
        return min(todayLog.accumulatedTotal / g, 1.0)
    }

    var progressLabel: String {
        "\(todayLog.accumulatedShortLabel) / \(goal.goalLabel)"
    }

    var currentTag: String? {
        state.currentSprint?.tag
    }

    var todayEarnings: Double {
        EarningsCalculator.calculate(sprints: todayLog.completedSprints, settings: goal)
    }

    var todayEarningsLabel: String {
        EarningsCalculator.formattedEarnings(sprints: todayLog.completedSprints, settings: goal)
    }

    // MARK: - Actions

    func clockIn(tag: String? = nil) {
        lastCopiedId = nil
        let cleanExplicit = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPending = pendingTag.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTag: String?
        if let cleanExplicit = cleanExplicit, !cleanExplicit.isEmpty {
            effectiveTag = cleanExplicit
        } else if !cleanPending.isEmpty {
            effectiveTag = cleanPending
        } else {
            effectiveTag = nil
        }
        pendingTag = ""
        engine.clockIn(tag: effectiveTag)
        todayLog = store.todayLog()
    }

    func setTag(_ tag: String?) {
        engine.setTag(tag)
        todayLog = store.todayLog()
    }

    func clockOut() {
        engine.clockOut()
        todayLog = store.todayLog()
    }

    func pause() {
        engine.pause()
    }

    func resumeTimer() {
        engine.resume()
    }

    func reset() {
        engine.reset()
        recoveryEndText = ""
        recoveryEndError = nil
        notifiedMilestones = []
        todayLog = store.todayLog()
    }

    func resumeRecovery() {
        engine.resumeRecovery()
        todayLog = store.todayLog()
    }

    func saveRecoveryEndTime() {
        do {
            try engine.saveRecoveryEndTime(recoveryEndText)
            recoveryEndText = ""
            recoveryEndError = nil
            todayLog = store.todayLog()
        } catch {
            recoveryEndError = error.localizedDescription
        }
    }

    func dismissRecovery() {
        engine.dismissRecovery()
        recoveryEndText = ""
        recoveryEndError = nil
        todayLog = store.todayLog()
    }

    func resolveSleep(countAsWork: Bool) {
        engine.resolveSleepInterval(countAsWork: countAsWork)
        todayLog = store.todayLog()
    }

    func copy(sprint: Sprint) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sprint.clipboardText, forType: .string)
        lastCopiedId = sprint.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.lastCopiedId == sprint.id { self?.lastCopiedId = nil }
        }
    }

    func addManualSprint(
        date: Date,
        startTime: Date,
        endTime: Date,
        pausedDuration: TimeInterval = 0,
        tag: String? = nil
    ) -> Sprint {
        let finalStart = TimeFormatter.combine(date: date, time: startTime)
        let finalEnd = TimeFormatter.combine(date: date, time: endTime, wrapIfBefore: finalStart)

        let cleanTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTag = (cleanTag?.isEmpty == false) ? cleanTag : nil

        let sprint = Sprint(
            startTime: finalStart,
            endTime: finalEnd,
            pausedDuration: max(0, pausedDuration),
            isPaused: false,
            pauseStartedAt: nil,
            pauseCount: pausedDuration > 0 ? 1 : 0,
            tag: effectiveTag
        )

        store.save(sprint: sprint)
        todayLog = store.todayLog()
        logRevision += 1
        return sprint
    }

    func updateSprint(
        originalSprint: Sprint,
        newDate: Date,
        newStartTime: Date,
        newEndTime: Date,
        newPausedDuration: TimeInterval,
        newTag: String?
    ) -> Sprint {
        let finalStart = TimeFormatter.combine(date: newDate, time: newStartTime)
        let finalEnd = TimeFormatter.combine(date: newDate, time: newEndTime, wrapIfBefore: finalStart)

        let cleanTag = newTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTag = (cleanTag?.isEmpty == false) ? cleanTag : nil

        let updatedSprint = Sprint(
            id: originalSprint.id,
            startTime: finalStart,
            endTime: finalEnd,
            pausedDuration: max(0, newPausedDuration),
            isPaused: originalSprint.isPaused,
            pauseStartedAt: originalSprint.pauseStartedAt,
            pauseCount: newPausedDuration > 0 ? max(originalSprint.pauseCount, 1) : 0,
            tag: effectiveTag
        )

        store.save(sprint: updatedSprint)
        todayLog = store.todayLog()
        logRevision += 1
        return updatedSprint
    }

    func delete(sprint: Sprint) {
        store.delete(sprint: sprint)
        todayLog = store.todayLog()
        logRevision += 1
    }

    // MARK: - Milestone Notifications

    private func checkMilestoneNotifications() {
        let goalSec = goal.dailyGoalSeconds
        guard goalSec > 0 else { return }

        let todayKey = TimeFormatter.format(dateKey: Date())
        if todayKey != lastNotifiedDayKey {
            lastNotifiedDayKey = todayKey
            notifiedMilestones.removeAll()
        }

        let totalElapsed = todayLog.accumulatedTotal + (isRunning ? currentElapsed : 0)
        let pct = Int((totalElapsed / goalSec) * 100)
        let milestones = [50, 75, 100]
        for m in milestones where pct >= m && !notifiedMilestones.contains(m) {
            notifiedMilestones.insert(m)
            sendNotification(milestone: m, totalSeconds: totalElapsed)
        }
    }

    private func sendNotification(milestone: Int, totalSeconds: TimeInterval) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = milestone == 100 ? "🎉 Daily Goal Reached!" : "Skeval Timer — \(milestone)% of Daily Goal"
        let acc = TimeFormatter.format(clock: totalSeconds)
        let goalLabel = goal.goalLabel
        content.body = milestone == 100
            ? "You've logged \(acc) today. Great work!"
            : "\(acc) logged out of \(goalLabel) today."
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "skeval.milestone.\(milestone)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    private func sendSleepNotification(interval: SleepInterval) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Mac Woke From Sleep"
        content.body = "Asleep from \(interval.formattedWindow) (\(interval.formattedDuration)). Count as work or paused?"
        content.sound = .default
        content.categoryIdentifier = "SLEEP_RESOLUTION"
        let req = UNNotificationRequest(
            identifier: "skeval.sleep.resolution",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }
}
