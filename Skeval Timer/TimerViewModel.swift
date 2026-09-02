import Foundation
import AppKit
import Observation
import UserNotifications

@Observable
@MainActor
class TimerViewModel {

    // MARK: - Observed state
    var currentSprint: Sprint? = nil
    var currentElapsed: TimeInterval = 0
    var todayLog: DayLog = DayLog()
    var lastCopiedId: UUID? = nil
    var isPaused: Bool = false

    // Recovery
    var recoveryMode: Bool = false
    var recoveryEndText: String = ""
    var recoveryEndError: String? = nil

    var goal = GoalSettings.shared

    private var ticker: Timer? = nil
    private let db = PersistenceService.shared
    // Milestones already notified this day (50, 75, 100)
    private var notifiedMilestones: Set<Int> = []
    // Pause tracking (not persisted; managed in-session only)
    private var pauseAccumulated: TimeInterval = 0   // elapsed frozen at pause moment
    private var pauseStartedAt: Date? = nil           // wall-clock time we paused
    private var totalPausedDuration: TimeInterval = 0 // sum of all pause spans this sprint

    // MARK: - Init

    init() { reload() }

    private func reload() {
        todayLog = db.todayLog()
        if let open = todayLog.openSprint {
            currentSprint = open
            currentElapsed = Date().timeIntervalSince(open.startTime)
            recoveryMode = true
        }
    }

    // MARK: - Primary actions

    func clockIn() {
        let sprint = Sprint(startTime: Date())
        currentSprint = sprint
        currentElapsed = 0
        lastCopiedId = nil
        isPaused = false
        pauseAccumulated = 0
        pauseStartedAt = nil
        totalPausedDuration = 0
        db.save(sprint: sprint)
        todayLog = db.todayLog()
        startTicker()
    }

    func clockOut() {
        guard var sprint = currentSprint, sprint.isOpen else { return }
        // If still paused when clocking out, finalise the current pause span
        if isPaused, let pausedAt = pauseStartedAt {
            totalPausedDuration += Date().timeIntervalSince(pausedAt)
        }
        sprint.endTime = Date()
        sprint.pausedDuration = totalPausedDuration
        stopTicker()
        isPaused = false
        pauseAccumulated = 0
        pauseStartedAt = nil
        totalPausedDuration = 0
        db.save(sprint: sprint)
        todayLog = db.todayLog()
        copy(sprint: sprint)
        currentSprint = nil
        currentElapsed = 0
        checkMilestoneNotifications()
    }

    func reset() {
        if let sprint = currentSprint, sprint.isOpen {
            db.delete(sprint: sprint)
        }
        stopTicker()
        currentSprint = nil
        currentElapsed = 0
        lastCopiedId = nil
        isPaused = false
        pauseAccumulated = 0
        pauseStartedAt = nil
        totalPausedDuration = 0
        recoveryMode = false
        recoveryEndText = ""
        recoveryEndError = nil
        notifiedMilestones = []
        todayLog = db.todayLog()
    }

    // MARK: - Pause / Resume

    func pause() {
        guard currentSprint != nil, !isPaused, !recoveryMode else { return }
        stopTicker()
        pauseAccumulated = currentElapsed
        pauseStartedAt = Date()
        isPaused = true
    }

    func resumeTimer() {
        guard currentSprint != nil, isPaused else { return }
        if let pausedAt = pauseStartedAt {
            totalPausedDuration += Date().timeIntervalSince(pausedAt)
        }
        pauseStartedAt = nil
        isPaused = false
        startTicker()
    }

    // MARK: - Recovery actions

    func resumeRecovery() {
        guard let sprint = currentSprint else { return }
        recoveryMode = false
        isPaused = false
        pauseAccumulated = 0
        pauseStartedAt = nil
        totalPausedDuration = 0
        currentElapsed = Date().timeIntervalSince(sprint.startTime)
        startTicker()
    }

    func saveRecoveryEndTime() {
        guard var sprint = currentSprint else { return }
        guard let end = parseTime(recoveryEndText, on: sprint.startTime) else {
            recoveryEndError = "Use HH:mm or HH:mm:ss"
            return
        }
        guard end > sprint.startTime else {
            recoveryEndError = "Must be after \(Sprint.fmt(sprint.startTime))"
            return
        }
        sprint.endTime = end
        db.save(sprint: sprint)
        todayLog = db.todayLog()
        currentSprint = nil
        currentElapsed = 0
        recoveryMode = false
        recoveryEndText = ""
        recoveryEndError = nil
        checkMilestoneNotifications()
    }

    func dismissRecovery() {
        if let sprint = currentSprint { db.delete(sprint: sprint) }
        currentSprint = nil
        currentElapsed = 0
        isPaused = false
        pauseAccumulated = 0
        pauseStartedAt = nil
        totalPausedDuration = 0
        recoveryMode = false
        recoveryEndText = ""
        recoveryEndError = nil
        todayLog = db.todayLog()
    }

    // MARK: - Sprint list actions

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
        db.delete(sprint: sprint)
        todayLog = db.todayLog()
    }

    // MARK: - Computed labels

    // Sprint exists and is not in recovery (may be paused or ticking)
    var isRunning: Bool { currentSprint != nil && !recoveryMode }
    // Sprint exists, not in recovery, and actively ticking
    var isTicking: Bool { isRunning && !isPaused }

    var currentElapsedLabel: String { hhmmss(currentElapsed) }

    var menuBarTitle: String {
        if isRunning { return shortClock(currentElapsed) }
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

    // MARK: - Helpers

    private func startTicker() {
        stopTicker()
        let base = pauseAccumulated
        let resumedAt = Date()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.currentSprint != nil, !self.isPaused else { return }
            // elapsed = pre-pause accumulated + time since we (re)started
            self.currentElapsed = base + Date().timeIntervalSince(resumedAt)
        }
    }

    private func stopTicker() { ticker?.invalidate(); ticker = nil }

    // MARK: - Milestone Notifications

    private func checkMilestoneNotifications() {
        let goalSec = goal.dailyGoalSeconds
        guard goalSec > 0 else { return }
        let pct = Int((todayLog.accumulatedTotal / goalSec) * 100)
        let milestones = [50, 75, 100]
        for m in milestones where pct >= m && !notifiedMilestones.contains(m) {
            notifiedMilestones.insert(m)
            sendNotification(milestone: m)
        }
    }

    private func sendNotification(milestone: Int) {
        let content = UNMutableNotificationContent()
        content.title = milestone == 100 ? "🎉 Daily Goal Reached!" : "Skeval Timer — \(milestone)% of Daily Goal"
        let acc = todayLog.accumulatedLabel
        let goal = goal.goalLabel
        content.body = milestone == 100
            ? "You've logged \(acc) today. Great work!"
            : "\(acc) logged out of \(goal) today."
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "skeval.milestone.\(milestone)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    private func hhmmss(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600, m = (Int(t) % 3600) / 60, s = Int(t) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func shortClock(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600, m = (Int(t) % 3600) / 60, s = Int(t) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private func parseTime(_ text: String, on reference: Date) -> Date? {
        let parts = text.trimmingCharacters(in: .whitespaces)
            .split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        var c = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        c.hour = parts[0]; c.minute = parts[1]; c.second = parts.count >= 3 ? parts[2] : 0
        return Calendar.current.date(from: c)
    }
}
