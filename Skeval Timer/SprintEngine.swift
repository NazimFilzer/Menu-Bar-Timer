import Foundation
import AppKit

enum SprintState: Equatable {
    case idle
    case active(sprint: Sprint, elapsed: TimeInterval)
    case paused(sprint: Sprint, elapsed: TimeInterval)
    case recovery(sprint: Sprint)

    var isRunning: Bool {
        switch self {
        case .active, .paused:
            return true
        case .idle, .recovery:
            return false
        }
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var isRecovery: Bool {
        if case .recovery = self { return true }
        return false
    }

    var currentSprint: Sprint? {
        switch self {
        case .active(let s, _), .paused(let s, _), .recovery(let s):
            return s
        case .idle:
            return nil
        }
    }

    var currentElapsed: TimeInterval {
        switch self {
        case .active(_, let e), .paused(_, let e):
            return e
        case .idle, .recovery:
            return 0
        }
    }

    var statusTitle: String {
        switch self {
        case .recovery: return "RECOVERY"
        case .paused: return "PAUSED"
        case .active: return "ACTIVE"
        case .idle: return "IDLE"
        }
    }
}

enum RecoveryError: LocalizedError, Equatable {
    case invalidFormat
    case mustBeAfterStart(String)
    case breakExceedsSprintTime

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Use HH:mm or HH:mm:ss"
        case .mustBeAfterStart(let start):
            return "Must be after \(start)"
        case .breakExceedsSprintTime:
            return "Break duration exceeds sprint time"
        }
    }
}

@MainActor
final class SprintEngine {
    private let store: DayLogStore
    private(set) var state: SprintState = .idle {
        didSet {
            if state != oldValue {
                onStateChanged?(state)
            }
        }
    }

    var onStateChanged: ((SprintState) -> Void)?
    var onTick: ((TimeInterval) -> Void)?
    var onPauseTick: ((TimeInterval) -> Void)?
    var onSprintCompleted: ((Sprint) -> Void)?
    var onSleepIntervalDetected: ((SleepInterval) -> Void)?

    private(set) var currentPauseElapsed: TimeInterval = 0
    private(set) var sleepStartedAt: Date? = nil
    private(set) var pendingSleepInterval: SleepInterval? = nil

    var totalCurrentSprintPaused: TimeInterval {
        totalPausedDuration + currentPauseElapsed
    }

    private var ticker: Timer? = nil
    private var elapsedAtPauseStart: TimeInterval = 0
    private var pauseStartedAt: Date? = nil
    private var totalPausedDuration: TimeInterval = 0
    private var pauseCount: Int = 0
    private var willSleepObserver: Any? = nil
    private var didWakeObserver: Any? = nil

    init(store: DayLogStore? = nil, observeWorkspace: Bool = true) {
        self.store = store ?? DayLogStore.shared
        reload()
        if observeWorkspace {
            setupWorkspaceObservers()
        }
    }

    deinit {
        if let o = willSleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
        }
        if let o = didWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
        }
    }

    func reload() {
        stopTicker()
        sleepStartedAt = nil
        pendingSleepInterval = nil
        if let (_, open) = store.findOpenSprint() {
            totalPausedDuration = open.pausedDuration
            pauseStartedAt = open.pauseStartedAt
            pauseCount = open.pauseCount
            currentPauseElapsed = 0
            state = .recovery(sprint: open)
        } else {
            resetPauseState()
            state = .idle
        }
    }

    func clockIn(at now: Date = Date(), tag: String? = nil) {
        guard case .idle = state else { return }
        let sprint = Sprint(startTime: now, tag: tag)
        resetPauseState()
        store.save(sprint: sprint)
        state = .active(sprint: sprint, elapsed: 0)
        startTicker()
    }

    func setTag(_ tag: String?) {
        switch state {
        case .active(var sprint, let elapsed):
            sprint.tag = tag
            store.save(sprint: sprint)
            state = .active(sprint: sprint, elapsed: elapsed)
        case .paused(var sprint, let elapsed):
            sprint.tag = tag
            store.save(sprint: sprint)
            state = .paused(sprint: sprint, elapsed: elapsed)
        case .recovery(var sprint):
            sprint.tag = tag
            store.save(sprint: sprint)
            state = .recovery(sprint: sprint)
        case .idle:
            break
        }
    }

    func clockOut(at now: Date = Date()) {
        guard let sprint = state.currentSprint, sprint.isOpen else { return }
        var updated = sprint

        if state.isPaused, let pausedAt = pauseStartedAt {
            totalPausedDuration += max(0, now.timeIntervalSince(pausedAt))
        }
        if pendingSleepInterval != nil { pauseCount += 1 }
        pendingSleepInterval = nil
        sleepStartedAt = nil

        updated.endTime = now
        updated.pausedDuration = totalPausedDuration
        updated.isPaused = false
        updated.pauseStartedAt = nil
        updated.pauseCount = pauseCount

        stopTicker()
        resetPauseState()
        store.save(sprint: updated)
        state = .idle

        onSprintCompleted?(updated)
    }

    func pause(at now: Date = Date()) {
        guard case .active(var sprint, _) = state else { return }
        stopTicker()
        let exactElapsed = max(0, now.timeIntervalSince(sprint.startTime) - totalPausedDuration)
        elapsedAtPauseStart = exactElapsed
        pauseStartedAt = now
        currentPauseElapsed = 0
        pauseCount += 1

        sprint.isPaused = true
        sprint.pauseStartedAt = now
        sprint.pausedDuration = totalPausedDuration
        sprint.pauseCount = pauseCount
        store.save(sprint: sprint)

        state = .paused(sprint: sprint, elapsed: exactElapsed)
        startPauseTicker(startedAt: now)
    }

    func resume(at now: Date = Date()) {
        guard pendingSleepInterval == nil, sleepStartedAt == nil,
              case .paused(var sprint, _) = state else { return }
        stopTicker()
        if let pausedAt = pauseStartedAt {
            totalPausedDuration += max(0, now.timeIntervalSince(pausedAt))
        }
        pauseStartedAt = nil
        currentPauseElapsed = 0

        sprint.isPaused = false
        sprint.pauseStartedAt = nil
        sprint.pausedDuration = totalPausedDuration
        sprint.pauseCount = pauseCount
        store.save(sprint: sprint)

        state = .active(sprint: sprint, elapsed: elapsedAtPauseStart)
        startTicker()
    }

    func reset() {
        if let sprint = state.currentSprint, sprint.isOpen {
            store.delete(sprint: sprint)
        }
        stopTicker()
        resetPauseState()
        sleepStartedAt = nil
        pendingSleepInterval = nil
        state = .idle
    }

    func resumeRecovery(at now: Date = Date()) {
        guard case .recovery(var sprint) = state else { return }
        if sprint.isPaused, let pStart = sprint.pauseStartedAt {
            totalPausedDuration += max(0, now.timeIntervalSince(pStart))
            sprint.isPaused = false
            sprint.pauseStartedAt = nil
        }
        sprint.pausedDuration = totalPausedDuration
        sprint.pauseCount = pauseCount
        store.save(sprint: sprint)

        pauseStartedAt = nil
        currentPauseElapsed = 0

        let gross = max(0, now.timeIntervalSince(sprint.startTime))
        let elapsed = max(0, gross - totalPausedDuration)
        state = .active(sprint: sprint, elapsed: elapsed)
        startTicker()
    }

    func saveRecoveryEndTime(_ text: String) throws {
        guard case .recovery(var sprint) = state else { return }
        guard let end = TimeFormatter.parseTime(text, on: sprint.startTime) else {
            throw RecoveryError.invalidFormat
        }
        guard end > sprint.startTime else {
            throw RecoveryError.mustBeAfterStart(TimeFormatter.format(time: sprint.startTime))
        }

        var recoveredPausedDuration = totalPausedDuration
        if sprint.isPaused, let pStart = sprint.pauseStartedAt, end > pStart {
            recoveredPausedDuration += max(0, end.timeIntervalSince(pStart))
        }

        guard end.timeIntervalSince(sprint.startTime) > recoveredPausedDuration else {
            throw RecoveryError.breakExceedsSprintTime
        }

        sprint.endTime = end
        sprint.pausedDuration = recoveredPausedDuration
        sprint.isPaused = false
        sprint.pauseStartedAt = nil
        sprint.pauseCount = pauseCount

        store.save(sprint: sprint)
        resetPauseState()
        state = .idle

        onSprintCompleted?(sprint)
    }

    func dismissRecovery() {
        guard case .recovery(let sprint) = state else { return }
        store.delete(sprint: sprint)
        resetPauseState()
        state = .idle
    }

    // MARK: - Sleep and Wake Resolution

    func handleSystemSleep(at now: Date = Date()) {
        guard case .active(var sprint, _) = state else { return }
        let elapsed = max(0, now.timeIntervalSince(sprint.startTime) - totalPausedDuration)
        stopTicker()
        elapsedAtPauseStart = elapsed
        sleepStartedAt = now
        pauseStartedAt = now
        currentPauseElapsed = 0

        sprint.isPaused = true
        sprint.pauseStartedAt = now
        sprint.pausedDuration = totalPausedDuration
        store.save(sprint: sprint)

        state = .paused(sprint: sprint, elapsed: elapsed)
    }

    func handleSystemWake(at now: Date = Date()) {
        guard let sleepStart = sleepStartedAt else { return }
        let wakeTime = max(sleepStart, now)
        let interval = SleepInterval(sleepStartedAt: sleepStart, wakeAt: wakeTime)
        pendingSleepInterval = interval
        sleepStartedAt = nil

        onSleepIntervalDetected?(interval)
    }

    func resolveSleepInterval(countAsWork: Bool, at now: Date = Date()) {
        guard let interval = pendingSleepInterval,
              case .paused(var sprint, _) = state else {
            return
        }

        stopTicker()
        pendingSleepInterval = nil
        pauseStartedAt = nil
        currentPauseElapsed = 0

        // The timer stays held after waking until the user makes a choice.
        let decisionPause = max(0, now.timeIntervalSince(interval.wakeAt))
        totalPausedDuration += decisionPause
        if !countAsWork {
            totalPausedDuration += interval.duration
            pauseCount += 1
        }
        sprint.isPaused = false
        sprint.pauseStartedAt = nil
        sprint.pausedDuration = totalPausedDuration
        sprint.pauseCount = pauseCount
        store.save(sprint: sprint)
        let elapsed = max(0, now.timeIntervalSince(sprint.startTime) - totalPausedDuration)
        state = .active(sprint: sprint, elapsed: elapsed)
        startTicker()
    }

    private func setupWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        willSleepObserver = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.handleSystemSleep()
                }
            } else {
                DispatchQueue.main.async {
                    self?.handleSystemSleep()
                }
            }
        }
        didWakeObserver = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.handleSystemWake()
                }
            } else {
                DispatchQueue.main.async {
                    self?.handleSystemWake()
                }
            }
        }
    }

    // MARK: - Internal Ticker

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard case .active(let sprint, _) = self.state else { return }
                let elapsed = max(0, Date().timeIntervalSince(sprint.startTime) - self.totalPausedDuration)
                self.state = .active(sprint: sprint, elapsed: elapsed)
                self.onTick?(elapsed)
            }
        }
    }

    private func startPauseTicker(startedAt: Date) {
        stopTicker()
        pauseStartedAt = startedAt
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard case .paused = self.state, let start = self.pauseStartedAt else { return }
                let pauseElapsed = max(0, Date().timeIntervalSince(start))
                self.currentPauseElapsed = pauseElapsed
                self.onPauseTick?(pauseElapsed)
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func resetPauseState() {
        elapsedAtPauseStart = 0
        pauseStartedAt = nil
        totalPausedDuration = 0
        currentPauseElapsed = 0
        pauseCount = 0
    }
}
