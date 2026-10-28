import Foundation
import AppKit
import Observation
import UserNotifications

// MARK: - Version Tracking

enum AppVersion {
    static let current = "v2.0"
    static let marketingVersion = "2.0"
    static let buildNumber = "4"
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
    var logRevision: Int = 0
    private(set) var persistenceError: String?
    var pendingTag: String = ""
    // Upcoming breaks only; a day rollover starts a fresh plan.
    var plannedBreakMinutes: Int = 0
    var manualTagText: String = ""

    // Recovery inputs
    var recoveryEndText: String = ""
    var recoveryEndDate: Date = Date()
    var recoveryEndError: String? = nil

    // Manual sprint entry inputs
    var isManualEntryPresented: Bool = false
    var manualStartText: String = ""
    var manualEndText: String = ""
    var manualBreakMinutesText: String = "0"
    var manualEntryError: String? = nil

    var goal = GoalSettings.shared
    let eyeBreakSettings: EyeBreakSettings
    private var eyeBreakReminder = EyeBreakReminder()
    private let deliverEyeBreakNotification: () -> Void

    let engine: SprintEngine
    let store: DayLogStore

    private(set) var notifiedMilestones: Set<Int> = []
    private var lastNotifiedDayKey: String = TimeFormatter.format(dateKey: Date())
    private var lastActiveDayKey: String = TimeFormatter.format(dateKey: Date())

    func checkAndHandleDayChange(now: Date = Date()) {
        let dayKey = TimeFormatter.format(dateKey: now)
        guard dayKey != lastActiveDayKey else { return }
        lastActiveDayKey = dayKey
        plannedBreakMinutes = 0
        lastNotifiedDayKey = dayKey
        notifiedMilestones.removeAll()
        selectedDate = now
        todayLog = store.log(for: now)
        selectedDayLog = todayLog
        logRevision += 1
    }

    // MARK: - Init

    init(engine: SprintEngine? = nil, store: DayLogStore? = nil, goal: GoalSettings? = nil,
         eyeBreakSettings: EyeBreakSettings? = nil, deliverEyeBreakNotification: (() -> Void)? = nil) {
        self.eyeBreakSettings = eyeBreakSettings ?? .shared
        self.deliverEyeBreakNotification = deliverEyeBreakNotification ?? Self.sendEyeBreakNotification
        let effectiveStore = store ?? DayLogStore.shared
        self.store = effectiveStore
        self.goal = goal ?? .shared
        let effectiveEngine = engine ?? SprintEngine(store: effectiveStore)
        self.engine = effectiveEngine

        self.todayLog = effectiveStore.todayLog()
        self.persistenceError = effectiveStore.storageError
        self.selectedDayLog = self.todayLog
        self.pendingSleepInterval = effectiveEngine.pendingSleepInterval
        self.state = effectiveEngine.state
        self.currentElapsed = effectiveEngine.state.currentElapsed
        self.currentPauseElapsed = effectiveEngine.currentPauseElapsed
        self.recoveryEndDate = effectiveEngine.state.currentSprint?.startTime ?? Date()

        let goalSec = self.goal.dailyGoalSeconds
        if goalSec > 0 {
            let initialPct = Int((self.todayLog.accumulatedTotal / goalSec) * 100)
            for m in [50, 75, 100] where initialPct >= m {
                self.notifiedMilestones.insert(m)
            }
        }

        eyeBreakReminder.restart(at: currentElapsed, settings: self.eyeBreakSettings)
        setupEngineCallbacks()
    }

    private func setupEngineCallbacks() {
        engine.onStateChanged = { [weak self] newState in
            self?.handleStateChange(newState)
        }

        engine.onTick = { [weak self] elapsed in
            guard let self else { return }
            self.currentElapsed = elapsed
            if self.isTicking && self.eyeBreakReminder.isDue(at: elapsed, settings: self.eyeBreakSettings) {
                self.deliverEyeBreakNotification()
            }
            self.checkAndHandleDayChange()
            self.checkMilestoneNotifications()
        }

        engine.onPauseTick = { [weak self] pauseElapsed in
            self?.currentPauseElapsed = pauseElapsed
            self?.checkAndHandleDayChange()
        }

        engine.onSprintCompleted = { [weak self] sprint in
            guard let self else { return }
            self.checkAndHandleDayChange()
            self.refreshLogs()
            self.copy(sprint: sprint)
            self.checkMilestoneNotifications()
        }
        engine.onSleepIntervalDetected = { [weak self] interval in
            self?.pendingSleepInterval = interval
            self?.sendSleepNotification(interval: interval)
        }
    }

    private func handleStateChange(_ newState: SprintState) {
        let sprintChanged = state.currentSprint != newState.currentSprint
        // Reset on activity transitions, not every elapsed-time or tag update.
        let activityChanged = state.isPaused != newState.isPaused
            || state.isRunning != newState.isRunning
            || state.isRecovery != newState.isRecovery
            || state.currentSprint?.id != newState.currentSprint?.id
        if activityChanged {
            eyeBreakReminder.restart(at: newState.currentElapsed, settings: eyeBreakSettings)
        }
        if newState.isRecovery && !state.isRecovery {
            recoveryEndDate = newState.currentSprint?.startTime ?? Date()
        }
        state = newState
        pendingSleepInterval = engine.pendingSleepInterval
        currentElapsed = newState.currentElapsed
        if !newState.isPaused { currentPauseElapsed = 0 }
        if sprintChanged { refreshLogs() }
        if !newState.isRecovery {
            recoveryEndText = ""
            recoveryEndError = nil
        }
    }

    // MARK: - Forwarded Properties

    var currentSprint: Sprint? { state.currentSprint }
    var isRunning: Bool { state.isRunning }
    var isPaused: Bool { state.isPaused }
    var recoveryMode: Bool { state.isRecovery }
    var isTicking: Bool { state.isRunning && !state.isPaused }
    private(set) var pendingSleepInterval: SleepInterval?
    var hasPendingSleepResolution: Bool { pendingSleepInterval != nil }
    var statusTitle: String { hasPendingSleepResolution ? "SLEEP HELD" : state.statusTitle }
    var currentTag: String? { currentSprint?.tag }

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
        todayLog.accumulatedTotal + liveSprintElapsed(on: Date())
    }

    func liveSprintElapsed(on date: Date) -> TimeInterval {
        guard isRunning, let sprint = currentSprint,
              Calendar.current.isDate(sprint.startTime, inSameDayAs: date) else { return 0 }
        return currentElapsed
    }

    var totalTodayShortLabel: String {
        TimeFormatter.format(shortDuration: totalTodayElapsed)
    }

    func catchUpSummary(for period: CatchUpPeriod, now: Date = Date()) -> CatchUpSummary {
        _ = logRevision
        return CatchUpAnalytics.calculate(
            logs: store.allLogs(), period: period, referenceDate: now, settings: goal,
            liveSprint: isRunning ? currentSprint : nil, liveElapsed: currentElapsed
        )
    }

    func finishForecast(now: Date = Date(), calendar: Calendar = .current) -> FinishForecast {
        _ = logRevision
        return FinishForecast.calculate(
            logs: store.allLogs(), settings: goal, state: state,
            sleepHeld: hasPendingSleepResolution || engine.sleepStartedAt != nil,
            plannedBreakMinutes: plannedBreakMinutes,
            now: now, calendar: calendar
        )
    }

    func periodPaceForecast(for period: CatchUpPeriod, now: Date = Date(),
                            calendar: Calendar = .current) -> PeriodPaceForecast {
        _ = logRevision
        return PeriodPaceForecast.calculate(
            logs: store.allLogs(), period: period, settings: goal, state: state,
            now: now, calendar: calendar
        )
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
        EarningsCalculator.format(amount: todayEarnings, currencySymbol: goal.currencySymbol)
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

    func jumpToToday(now: Date = Date()) {
        selectDate(now)
    }

    var desiredPopoverHeight: CGFloat {
        var height: CGFloat = 590
        if recoveryMode { height += 120 }
        if hasPendingSleepResolution { height += 90 }
        if persistenceError != nil { height += 80 }
        return height
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
        EarningsCalculator.format(amount: displayedEarnings, currencySymbol: goal.currencySymbol)
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

    func clockIn(tag: String? = nil) {
        guard !isRunning, !recoveryMode else { return }
        checkAndHandleDayChange()
        jumpToToday()
        lastCopiedId = nil
        isAllCopied = false
        let effectiveTag = cleanTag(tag) ?? cleanTag(pendingTag)
        pendingTag = ""
        engine.clockIn(tag: effectiveTag)
        refreshLogs()
    }

    private func cleanTag(_ tag: String?) -> String? {
        guard let text = tag?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    func setTag(_ tag: String?) {
        engine.setTag(cleanTag(tag))
        refreshLogs()
    }

    func resolveSleep(countAsWork: Bool) {
        engine.resolveSleepInterval(countAsWork: countAsWork)
        pendingSleepInterval = engine.pendingSleepInterval
        refreshLogs()
    }

    func refreshLogs() {
        todayLog = store.todayLog()
        selectedDayLog = store.log(for: selectedDate)
        persistenceError = store.storageError
        logRevision += 1
    }

    func clockOut() {
        engine.clockOut()
        refreshLogs()
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
        refreshLogs()
    }

    func resumeRecovery() {
        engine.resumeRecovery()
        refreshLogs()
    }

    func saveRecoveryEndTime() {
        do {
            try engine.saveRecoveryEndTime(recoveryEndText, on: recoveryEndDate)
            recoveryEndText = ""
            recoveryEndError = nil
            refreshLogs()
        } catch {
            recoveryEndError = error.localizedDescription
        }
    }

    func dismissRecovery() {
        engine.dismissRecovery()
        recoveryEndText = ""
        recoveryEndError = nil
        refreshLogs()
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

    func addManualSprint(
        date: Date,
        startTime: Date,
        endTime: Date,
        pausedDuration: TimeInterval = 0,
        tag: String? = nil,
        endDayOffset: Int? = nil
    ) throws -> Sprint {
        let entry = try SprintEntry(date: date, startTime: startTime, endTime: endTime,
                                    pausedDuration: pausedDuration, endDayOffset: endDayOffset)

        let cleanTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTag = (cleanTag?.isEmpty == false) ? cleanTag : nil

        let sprint = Sprint(
            startTime: entry.start,
            endTime: entry.end,
            pausedDuration: entry.pausedDuration,
            isPaused: false,
            pauseStartedAt: nil,
            pauseCount: pausedDuration > 0 ? 1 : 0,
            tag: effectiveTag
        )

        store.save(sprint: sprint)
        refreshLogs()
        return sprint
    }

    func updateSprint(
        originalSprint: Sprint,
        newDate: Date,
        newStartTime: Date,
        newEndTime: Date,
        newPausedDuration: TimeInterval,
        newTag: String?,
        endDayOffset: Int? = nil
    ) throws -> Sprint {
        guard !originalSprint.isOpen else { throw SprintEntryError.invalidEnd }
        let entry = try SprintEntry(date: newDate, startTime: newStartTime, endTime: newEndTime,
                                    pausedDuration: newPausedDuration, endDayOffset: endDayOffset)

        let cleanTag = newTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTag = (cleanTag?.isEmpty == false) ? cleanTag : nil

        let updatedSprint = Sprint(
            id: originalSprint.id,
            startTime: entry.start,
            endTime: entry.end,
            pausedDuration: entry.pausedDuration,
            isPaused: false,
            pauseStartedAt: nil,
            pauseCount: newPausedDuration > 0 ? max(originalSprint.pauseCount, 1) : 0,
            tag: effectiveTag
        )

        store.save(sprint: updatedSprint)
        refreshLogs()
        return updatedSprint
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

    @discardableResult
    func copyTimesheet(days: [DailyBarData]) -> Bool {
        let text = DailyTimesheet.clipboardText(days: days)
        guard !text.isEmpty else { return false }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastCopiedId = nil
        isAllCopied = false
        return true
    }

    func delete(sprint: Sprint) {
        store.delete(sprint: sprint)
        refreshLogs()
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

    private func manualEntry() throws -> SprintEntry {
        try SprintEntry(date: selectedDate, startText: manualStartText,
                        endText: manualEndText, breakText: manualBreakMinutesText)
    }

    var manualComputedNetDuration: TimeInterval? {
        try? manualEntry().netDuration
    }

    var manualComputedEarningsDelta: Double {
        EarningsCalculator.calculate(durationInSeconds: manualComputedNetDuration ?? 0, hourlyRate: goal.hourlyRate)
    }

    func confirmOverlaps(for entry: SprintEntry, excluding id: UUID? = nil) -> Bool {
        let now = Date()
        let conflicts = overlappingSprints(entry: entry, logs: store.allLogs(), excluding: id, now: now)
        guard !conflicts.isEmpty else { return true }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let details = conflicts.map { sprint in
            let end = sprint.endTime.map { formatter.string(from: $0) } ?? "ongoing (through \(formatter.string(from: now)))"
            return "• \(formatter.string(from: sprint.startTime)) - \(end)"
        }.joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = "Overlapping Sprints"
        alert.informativeText = "This Sprint overlaps with:\n\n\(details)\n\nSave it anyway?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Save Anyway")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func confirmManualSprintOverlaps() -> Bool {
        guard let entry = try? manualEntry() else { return false }
        return confirmOverlaps(for: entry)
    }

    @discardableResult
    func saveManualSprint() -> Bool {
        do {
            let entry = try manualEntry()
            let sprint = Sprint(startTime: entry.start, endTime: entry.end,
                                pausedDuration: entry.pausedDuration,
                                pauseCount: entry.pausedDuration > 0 ? 1 : 0,
                                tag: cleanTag(manualTagText))
            store.save(sprint: sprint)
            refreshLogs()
            if isViewingToday { checkMilestoneNotifications() }
            copy(sprint: sprint)
            isManualEntryPresented = false
            manualStartText = ""
            manualEndText = ""
            manualTagText = ""
            manualBreakMinutesText = "0"
            manualEntryError = nil
            return true
        } catch {
            manualEntryError = error.localizedDescription
            return false
        }
    }

    // MARK: - Eye-break Notifications

    func updateEyeBreakEnabled(_ enabled: Bool) {
        eyeBreakSettings.isEnabled = enabled
        eyeBreakReminder.restart(at: currentElapsed, settings: eyeBreakSettings)
    }

    func updateEyeBreakInterval(_ minutes: Int) {
        eyeBreakSettings.intervalMinutes = minutes
        eyeBreakReminder.restart(at: currentElapsed, settings: eyeBreakSettings)
    }

    private static func sendEyeBreakNotification() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time for an eye break"
        content.body = "Look away from your screen at something at least 20 feet (6 metres) away for 20 seconds. Blink naturally."
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "skeval.eye-break", content: content, trigger: nil
        ))
    }

    // MARK: - Milestone Notifications

    private func checkMilestoneNotifications() {
        let goalSec = self.goal.dailyGoalSeconds
        guard goalSec > 0 else { return }

        let todayKey = TimeFormatter.format(dateKey: Date())
        if todayKey != lastNotifiedDayKey {
            lastNotifiedDayKey = todayKey
            notifiedMilestones.removeAll()
        }

        let totalElapsed = totalTodayElapsed
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
