import AppKit
import SwiftUI

/// Runs with a real AppKit event loop and disposable data, without global hotkeys.
@main
@MainActor
struct RuntimeHealthMain {
    private static var failures = 0
    private static var checks = 0

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in
            await checkLiveEarnings()
            print("Runtime health: \(checks - failures) / \(checks) checks passed.")
            exit(failures == 0 ? 0 : 1)
        }
        app.run()
    }

    private static func expect(_ condition: Bool, _ message: String) {
        checks += 1
        if !condition {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    private static func waitForTicks() async {
        try? await Task.sleep(for: .seconds(2.3))
    }

    private static func checkLiveEarnings() async {
        let suite = "skeval-runtime-health-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = GoalSettings(userDefaults: defaults)
        settings.hourlyRate = 1234.56
        settings.dailyGoalHours = 24
        let store = DayLogStore(storage: InMemoryDayLogAdapter())
        let engine = SprintEngine(store: store, observeWorkspace: false)
        let vm = TimerViewModel(engine: engine, store: store, goal: settings)
        // Render both earnings consumers while real callbacks update the model.
        let dashboard = NSHostingView(rootView: TodayDashboardView(vm: vm, theme: .citrus, openSettings: {}))
        dashboard.frame = NSRect(x: 0, y: 0, width: 1100, height: 780)
        let popover = NSHostingView(rootView: PopoverView(vm: vm))
        popover.frame = NSRect(x: 0, y: 0, width: 330, height: 590)
        var activeTicks = 0
        var pauseTicks = 0
        let previousTick = engine.onTick
        engine.onTick = { elapsed in
            previousTick?(elapsed)
            activeTicks += 1
            _ = vm.displayedEarningsLabel
        }
        let previousPauseTick = engine.onPauseTick
        engine.onPauseTick = { elapsed in
            previousPauseTick?(elapsed)
            pauseTicks += 1
        }

        engine.clockIn()
        await waitForTicks()
        expect((1...3).contains(activeTicks), "Exactly one active timer should drive updates")
        expect(vm.currentElapsed >= 1, "The actual timer must advance elapsed time")
        expect(vm.todayEarningsLabel != "₹0", "Decimal earnings must advance with real ticks")
        let revision = vm.logRevision
        dashboard.layoutSubtreeIfNeeded()
        popover.layoutSubtreeIfNeeded()
        expect(vm.logRevision == revision, "Rendering must not refresh persisted logs")

        engine.pause()
        let pausedEarnings = vm.todayEarningsLabel
        let ticksBeforePause = activeTicks
        await waitForTicks()
        expect(activeTicks == ticksBeforePause, "Active updates must stop during pause")
        expect((1...3).contains(pauseTicks), "Exactly one pause timer should drive updates")
        expect(vm.todayEarningsLabel == pausedEarnings, "Earnings must stay frozen while paused")

        for _ in 0..<100 {
            engine.resume()
            engine.pause()
        }
        engine.resume()
        let ticksBeforeResume = activeTicks
        let pausesBeforeResume = pauseTicks
        await waitForTicks()
        expect((1...3).contains(activeTicks - ticksBeforeResume), "Rapid toggles must not multiply timers")
        expect(pauseTicks == pausesBeforeResume, "Old pause timers must stop after resume")
        expect(vm.todayEarnings > 0 && vm.todayEarnings.isFinite, "Live earnings must stay finite")

        engine.clockOut()
        let endedEarnings = vm.todayEarningsLabel
        expect(store.todayLog().completedSprints.count == 1, "Clock-out must persist one sprint")
        let endedTicks = activeTicks
        await waitForTicks()
        expect(activeTicks == endedTicks, "Clock-out must stop all active ticks")
        expect(vm.todayEarningsLabel == endedEarnings, "Completed earnings must remain stable")
        expect(vm.persistenceError == nil, "No storage error should occur")
        print("Checked live decimal earnings, dashboard and popover rendering, pause/resume, 100 rapid toggles, and clock-out.")
    }
}
