import AppKit
import SwiftUI

/// A separate app with in-memory logs and its own preferences for reviewing native UI.
@MainActor
final class PreviewController: NSObject {
    let vm: TimerViewModel
    let dashboard: DashboardWindowController
    let delegate: AppDelegate
    private var quickWindow: NSWindow?

    init(timelinePreview: Bool = false) {
        UserDefaults.standard.set(timelinePreview ? "today" : "week", forKey: "skevalDashboardDestination")
        UserDefaults.standard.set(true, forKey: "skevalTodayShowingTimeline")
        let defaults = UserDefaults(suiteName: "skeval-catchup-preview-settings")!
        defaults.removePersistentDomain(forName: "skeval-catchup-preview-settings")
        let settings = GoalSettings(userDefaults: defaults)
        settings.hourlyRate = 1500
        let store = DayLogStore(storage: InMemoryDayLogAdapter())
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let timelineDay = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekStart = CatchUpPeriod.week.dates(containing: today, calendar: calendar).first!
        if timelinePreview {
            Self.saveTimelineSprints(store: store, day: timelineDay)
        } else {
            for date in AnalyticsMetrics.monthDates(containing: today, calendar: calendar) where date <= today {
                guard settings.isWorkingDay(date, calendar: calendar) else { continue }
                let start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date)!
                let hours: Double = date < weekStart ? 5 : (date == weekStart ? 4 : 2)
                store.save(sprint: Sprint(startTime: start, endTime: start.addingTimeInterval(hours * 3600 + 600),
                                          pausedDuration: 600, tag: date == weekStart ? "Client" : "Development"))
            }
        }
        let engine = SprintEngine(store: store, observeWorkspace: false)
        vm = TimerViewModel(engine: engine, store: store, goal: settings)
        if timelinePreview { vm.selectDate(timelineDay) }
        dashboard = DashboardWindowController(vm: vm)
        delegate = AppDelegate(vm: vm)
        super.init()
        delegate.dashboardController = dashboard
        AppDelegate.shared = delegate
        dashboard.window?.title = "Skeval v2 preview · Sample data"
        if timelinePreview {
            dashboard.window?.title = "Timeline columns preview · Sample data"
            dashboard.window?.contentView = NSHostingView(rootView:
                DailyTimelineView(vm: vm, theme: ThemeManager.shared.theme,
                                  temporaryHours: .constant(TimelineHours(startHour: 8, endHour: 14)))
                    .padding(20))
        }
    }

    private static func saveTimelineSprints(store: DayLogStore, day: Date) {
        // The two short-sprint pairs reproduce the reported screen overlap.
        let minutes = [(6 * 60, 6 * 60 + 45), (7 * 60, 7 * 60 + 50),
                       (8 * 60 + 4, 9 * 60 + 51), (9 * 60 + 59, 10 * 60 + 8),
                       (10 * 60 + 12, 11 * 60 + 1), (11 * 60 + 4, 11 * 60 + 11),
                       (11 * 60 + 15, 11 * 60 + 49)]
        for (index, span) in minutes.enumerated() {
            store.save(sprint: Sprint(startTime: day.addingTimeInterval(Double(span.0) * 60),
                                      endTime: day.addingTimeInterval(Double(span.1) * 60),
                                      pausedDuration: index == 2 ? 25 * 60 : 0))
        }
    }

    func show() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let actions = NSMenu()
        let quick = NSMenuItem(title: "Show menu bar preview", action: #selector(showQuickControls), keyEquivalent: "p")
        quick.target = self
        actions.addItem(quick)
        actions.addItem(.separator())
        actions.addItem(withTitle: "Quit Preview", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = actions
        menu.addItem(appItem)
        NSApplication.shared.mainMenu = menu
        dashboard.showDashboard()
    }

    @objc private func showQuickControls() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 330, height: vm.desiredPopoverHeight),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Menu bar preview · Sample data"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PopoverView(vm: vm))
        quickWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

@main
@MainActor
struct PreviewMain {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        let preview = PreviewController(timelinePreview: CommandLine.arguments.contains("--timeline"))
        preview.show()
        withExtendedLifetime(preview) { application.run() }
    }
}
