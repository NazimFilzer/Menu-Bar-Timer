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
    }

    // MARK: - Forwarded Properties

    var currentSprint: Sprint? { state.currentSprint }
    var isRunning: Bool { state.isRunning }
    var isPaused: Bool { state.isPaused }
    var recoveryMode: Bool { state.isRecovery }
    var isTicking: Bool { state.isRunning && !state.isPaused }
    var statusTitle: String { state.statusTitle }

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

    // MARK: - Actions

    func clockIn() {
        lastCopiedId = nil
        engine.clockIn()
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

    func copy(sprint: Sprint) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sprint.clipboardText, forType: .string)
        lastCopiedId = sprint.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.lastCopiedId == sprint.id { self?.lastCopiedId = nil }
        }
    }

    func delete(sprint: Sprint) {
        store.delete(sprint: sprint)
        todayLog = store.todayLog()
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
}
