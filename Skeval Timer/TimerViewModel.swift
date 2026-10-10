import Foundation
import AppKit
import Observation
import UserNotifications

// MARK: - Version Tracking

enum AppVersion {
    static let current = "v1.2"
    static let marketingVersion = "1.2"
    static let buildNumber = "3"
}

@Observable
@MainActor
class TimerViewModel {

    // MARK: - Observed state
    private(set) var state: SprintState = .idle
    var currentElapsed: TimeInterval = 0
    var currentPauseElapsed: TimeInterval = 0
    var todayLog: DayLog = DayLog()
    var selectedDate: Date = Date()
    var selectedDayLog: DayLog = DayLog()
    var lastCopiedId: UUID? = nil
    var isAllCopied: Bool = false

    // Recovery inputs
    var recoveryEndText: String = ""
    var recoveryEndError: String? = nil

    // Manual sprint entry inputs
    var isManualEntryPresented: Bool = false
    var manualStartText: String = ""
    var manualEndText: String = ""
    var manualBreakMinutesText: String = "0"
    var manualEntryError: String? = nil

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
        self.selectedDayLog = self.todayLog
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
            if self.isViewingToday {
                self.selectedDayLog = self.todayLog
            }
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
            if self.isViewingToday {
                self.selectedDayLog = self.todayLog
            }
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

    var totalCurrentSprintPaused: TimeInterval {
        engine.totalCurrentSprintPaused
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

    var totalTodayElapsed: TimeInterval {
        todayLog.accumulatedTotal + (isRunning ? currentElapsed : 0)
    }

    var totalTodayShortLabel: String {
        TimeFormatter.format(shortDuration: totalTodayElapsed)
    }

    var progressFraction: Double {
        let g = goal.dailyGoalSeconds
        guard g > 0 else { return 0 }
        return min(totalTodayElapsed / g, 1.0)
    }

    var progressLabel: String {
        "\(totalTodayShortLabel) / \(goal.goalLabel)"
    }

    var todayEarnings: Double {
        guard goal.hasHourlyRate else { return 0.0 }
        let hours = totalTodayElapsed / 3600.0
        return hours * goal.hourlyRate
    }

    var todayEarningsLabel: String {
        TimeFormatter.format(rupees: todayEarnings)
    }

    var targetEarningsLabel: String {
        goal.targetEarningsLabel
    }

    var isDailyGoalReached: Bool {
        let g = goal.dailyGoalSeconds
        return g > 0 && totalTodayElapsed >= g
    }

    // MARK: - Past Days History Navigation

    var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var selectedDayShortTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) {
            return "Today"
        } else if cal.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            return TimeFormatter.format(shortDayTitle: selectedDate)
        }
    }

    var headerDateSubtitle: String {
        TimeFormatter.format(relativeHeaderDate: selectedDate)
    }

    var sprintsSectionTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) {
            return "TODAY'S SPRINTS"
        } else if cal.isDateInYesterday(selectedDate) {
            return "YESTERDAY'S SPRINTS"
        } else {
            return "\(TimeFormatter.format(shortDayTitle: selectedDate).uppercased())'S SPRINTS"
        }
    }

    var displayedCompletedSprints: [Sprint] {
        selectedDayLog.completedSprints
    }

    var displayedCompletedSprintsDescending: [(index: Int, sprint: Sprint)] {
        selectedDayLog.completedSprintsDescending
    }

    var availablePastDates: [Date] {
        let cal = Calendar.current
        let today = Date()
        return (0..<7).compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today)
        }
    }

    func menuItemTitle(for date: Date) -> String {
        let title = TimeFormatter.format(menuItemTitle: date)
        let count = store.log(for: date).completedSprints.count
        return count > 0 ? "\(title) (\(count))" : title
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        todayLog = store.todayLog()
        if isViewingToday {
            selectedDayLog = todayLog
        } else {
            selectedDayLog = store.log(for: date)
        }
    }

    func jumpToToday() {
        selectDate(Date())
    }

    var displayedAccumulatedTotal: TimeInterval {
        if isViewingToday {
            return totalTodayElapsed
        } else {
            return selectedDayLog.accumulatedTotal
        }
    }

    var displayedTotalShortLabel: String {
        TimeFormatter.format(shortDuration: displayedAccumulatedTotal)
    }

    var displayedProgressFraction: Double {
        let g = goal.dailyGoalSeconds
        guard g > 0 else { return 0 }
        return min(displayedAccumulatedTotal / g, 1.0)
    }

    var displayedProgressLabel: String {
        "\(displayedTotalShortLabel) / \(goal.goalLabel)"
    }

    var displayedEarnings: Double {
        guard goal.hasHourlyRate else { return 0.0 }
        let hours = displayedAccumulatedTotal / 3600.0
        return hours * goal.hourlyRate
    }

    var displayedEarningsLabel: String {
        TimeFormatter.format(rupees: displayedEarnings)
    }

    var displayedGoalTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) {
            return "Daily Target"
        } else if cal.isDateInYesterday(selectedDate) {
            return "Yesterday's Target"
        } else {
            return "\(TimeFormatter.format(shortDayTitle: selectedDate)) Target"
        }
    }

    var isDisplayedGoalReached: Bool {
        let g = goal.dailyGoalSeconds
        return g > 0 && displayedAccumulatedTotal >= g
    }

    // MARK: - Actions

    func clockIn() {
        lastCopiedId = nil
        isAllCopied = false
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
        isAllCopied = false
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
        isAllCopied = false
        lastCopiedId = sprint.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.lastCopiedId == sprint.id { self?.lastCopiedId = nil }
        }
    }

    func copyAllDisplayedSprints() {
        guard !selectedDayLog.completedSprints.isEmpty else { return }
        let text = selectedDayLog.clipboardText
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastCopiedId = nil
        isAllCopied = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.isAllCopied = false
        }
    }

    func copyAllTodaySprints() {
        copyAllDisplayedSprints()
    }

    func delete(sprint: Sprint) {
        store.delete(sprint: sprint)
        todayLog = store.todayLog()
        if isViewingToday {
            selectedDayLog = todayLog
        } else {
            selectedDayLog = store.log(for: selectedDate)
        }
    }

    // MARK: - Manual Sprint Entry

    func openManualEntry() {
        if manualEndText.isEmpty {
            if isViewingToday {
                manualEndText = TimeFormatter.format(time: Date())
            } else if let last = selectedDayLog.completedSprints.last, let end = last.endTime {
                manualEndText = TimeFormatter.format(time: end)
            } else {
                manualEndText = "10:00:00"
            }
        }
        if manualStartText.isEmpty {
            if let last = selectedDayLog.completedSprints.last {
                manualStartText = last.endLabel
            } else if isViewingToday {
                manualStartText = TimeFormatter.format(time: Date().addingTimeInterval(-3600))
            } else {
                manualStartText = "09:00:00"
            }
        }
        manualBreakMinutesText = "0"
        manualEntryError = nil
        isManualEntryPresented = true
    }

    func dismissManualEntry() {
        isManualEntryPresented = false
        manualEntryError = nil
    }

    func stepManualTime(isStart: Bool, minutes: Int) {
        let reference = selectedDate
        let currentText = isStart ? manualStartText : manualEndText
        let baseDate = TimeFormatter.parseTime(currentText, on: reference) ?? reference
        let newDate = baseDate.addingTimeInterval(TimeInterval(minutes * 60))
        let formatted = TimeFormatter.format(time: newDate)
        if isStart {
            manualStartText = formatted
        } else {
            manualEndText = formatted
        }
        manualEntryError = nil
    }

    var manualComputedNetDuration: TimeInterval? {
        let reference = selectedDate
        guard let start = TimeFormatter.parseTime(manualStartText, on: reference),
              let end = TimeFormatter.parseTime(manualEndText, on: reference) else {
            return nil
        }
        let breakMin = Double(manualBreakMinutesText.trimmingCharacters(in: .whitespaces)) ?? 0
        let net = end.timeIntervalSince(start) - (breakMin * 60)
        guard net > 0 else { return nil }
        return net
    }

    var manualComputedEarningsDelta: Double {
        guard let net = manualComputedNetDuration, goal.hasHourlyRate else { return 0 }
        return (net / 3600.0) * goal.hourlyRate
    }

    @discardableResult
    func saveManualSprint() -> Bool {
        let reference = selectedDate
        guard let start = TimeFormatter.parseTime(manualStartText, on: reference) else {
            manualEntryError = "Invalid start time (HH:mm:ss)"
            return false
        }
        guard let end = TimeFormatter.parseTime(manualEndText, on: reference) else {
            manualEntryError = "Invalid end time (HH:mm:ss)"
            return false
        }
        guard end > start else {
            manualEntryError = "End time must be after start time"
            return false
        }

        let breakMin = max(0, Double(manualBreakMinutesText.trimmingCharacters(in: .whitespaces)) ?? 0)
        let pausedDuration = breakMin * 60
        guard end.timeIntervalSince(start) > pausedDuration else {
            manualEntryError = "Break duration exceeds sprint time"
            return false
        }

        let sprint = Sprint(
            startTime: start,
            endTime: end,
            pausedDuration: pausedDuration
        )

        store.save(sprint: sprint)
        todayLog = store.todayLog()
        if isViewingToday {
            selectedDayLog = todayLog
            checkMilestoneNotifications()
        } else {
            selectedDayLog = store.log(for: selectedDate)
        }
        copy(sprint: sprint)

        isManualEntryPresented = false
        manualStartText = ""
        manualEndText = ""
        manualBreakMinutesText = "0"
        manualEntryError = nil
        return true
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
