import Foundation

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

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Use HH:mm or HH:mm:ss"
        case .mustBeAfterStart(let start):
            return "Must be after \(start)"
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
    var onSprintCompleted: ((Sprint) -> Void)?

    private var ticker: Timer? = nil
    private var elapsedAtPauseStart: TimeInterval = 0
    private var pauseStartedAt: Date? = nil
    private var totalPausedDuration: TimeInterval = 0
    private var activeResumedAt: Date? = nil

    init(store: DayLogStore? = nil) {
        self.store = store ?? DayLogStore.shared
        reload()
    }

    func reload() {
        stopTicker()
        let today = store.todayLog()
        if let open = today.openSprint {
            elapsedAtPauseStart = 0
            pauseStartedAt = nil
            totalPausedDuration = 0
            state = .recovery(sprint: open)
        } else {
            state = .idle
        }
    }

    func clockIn(at now: Date = Date()) {
        let sprint = Sprint(startTime: now)
        elapsedAtPauseStart = 0
        pauseStartedAt = nil
        totalPausedDuration = 0
        store.save(sprint: sprint)
        state = .active(sprint: sprint, elapsed: 0)
        startTicker(resumedAt: now, baseElapsed: 0)
    }

    func clockOut(at now: Date = Date()) {
        guard let sprint = state.currentSprint, sprint.isOpen else { return }
        var updated = sprint

        if state.isPaused, let pausedAt = pauseStartedAt {
            totalPausedDuration += now.timeIntervalSince(pausedAt)
        }

        updated.endTime = now
        updated.pausedDuration = totalPausedDuration

        stopTicker()
        resetPauseState()
        store.save(sprint: updated)
        state = .idle

        onSprintCompleted?(updated)
    }

    func pause(at now: Date = Date()) {
        guard case .active(let sprint, let elapsed) = state else { return }
        stopTicker()
        elapsedAtPauseStart = elapsed
        pauseStartedAt = now
        state = .paused(sprint: sprint, elapsed: elapsed)
    }

    func resume(at now: Date = Date()) {
        guard case .paused(let sprint, _) = state else { return }
        if let pausedAt = pauseStartedAt {
            totalPausedDuration += now.timeIntervalSince(pausedAt)
        }
        pauseStartedAt = nil
        state = .active(sprint: sprint, elapsed: elapsedAtPauseStart)
        startTicker(resumedAt: now, baseElapsed: elapsedAtPauseStart)
    }

    func reset() {
        if let sprint = state.currentSprint, sprint.isOpen {
            store.delete(sprint: sprint)
        }
        stopTicker()
        resetPauseState()
        state = .idle
    }

    func resumeRecovery(at now: Date = Date()) {
        guard case .recovery(let sprint) = state else { return }
        resetPauseState()
        let elapsed = max(0, now.timeIntervalSince(sprint.startTime))
        state = .active(sprint: sprint, elapsed: elapsed)
        startTicker(resumedAt: now, baseElapsed: elapsed)
    }

    func saveRecoveryEndTime(_ text: String) throws {
        guard case .recovery(var sprint) = state else { return }
        guard let end = TimeFormatter.parseTime(text, on: sprint.startTime) else {
            throw RecoveryError.invalidFormat
        }
        guard end > sprint.startTime else {
            throw RecoveryError.mustBeAfterStart(TimeFormatter.format(time: sprint.startTime))
        }

        sprint.endTime = end
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

    // MARK: - Internal Ticker

    private func startTicker(resumedAt: Date, baseElapsed: TimeInterval) {
        stopTicker()
        activeResumedAt = resumedAt
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard case .active(let sprint, _) = self.state, let start = self.activeResumedAt else { return }
                let elapsed = baseElapsed + Date().timeIntervalSince(start)
                self.state = .active(sprint: sprint, elapsed: elapsed)
                self.onTick?(elapsed)
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        activeResumedAt = nil
    }

    private func resetPauseState() {
        elapsedAtPauseStart = 0
        pauseStartedAt = nil
        totalPausedDuration = 0
    }
}
