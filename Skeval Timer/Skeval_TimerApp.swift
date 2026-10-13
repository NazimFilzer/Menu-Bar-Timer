import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications
import Carbon

@main
struct SkevalTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static weak var shared: AppDelegate?

    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var dashboardController: DashboardWindowController!
    let vm = TimerViewModel()
    private var presenter: StatusBarPresenter!

    // Global Carbon hotkeys & local monitor:
    // ⌘+⌥+Shift+C -> Clock In / Out
    // ⌘+⌥+Shift+P -> Pause / Resume
    private var clockHotKeyRef: EventHotKeyRef?
    private var pauseHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var localHotkeyMonitor: Any? = nil
    private var lastClockHotkeyTriggerTime: Date = .distantPast
    private var lastPauseHotkeyTriggerTime: Date = .distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        dashboardController = DashboardWindowController(vm: vm)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Skeval Timer")
            btn.image?.isTemplate = true
            btn.action = #selector(togglePopover)
            btn.target = self
        }

        presenter = StatusBarPresenter(statusItem: statusItem)

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        updatePopoverSize()
        let hostingController = PopoverHostingController(
            rootView: PopoverView(vm: vm)
        )
        popover.contentViewController = hostingController

        registerGlobalHotkeys()
        setupStateObservation()
        setupDayChangeObservers()
        updateStatusItem(force: true)

        let workAction = UNNotificationAction(
            identifier: "COUNT_WORK",
            title: "Count as Work",
            options: .foreground
        )
        let pauseAction = UNNotificationAction(
            identifier: "COUNT_PAUSED",
            title: "Count as Paused",
            options: .foreground
        )
        let sleepCategory = UNNotificationCategory(
            identifier: "SLEEP_RESOLUTION",
            actions: [workAction, pauseAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([sleepCategory])

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeGlobalHotkeys()
    }

    // MARK: - Popover toggle & sizing

    func updatePopoverSize() {
        popover?.contentSize = NSSize(width: 330, height: vm.desiredPopoverHeight)
    }

    @objc func togglePopover() {
        guard let btn = statusItem.button else { return }
        vm.checkAndHandleDayChange()
        updatePopoverSize()
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func setupDayChangeObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDayChange),
            name: .NSCalendarDayChanged,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDayChange),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleDayChange() {
        vm.checkAndHandleDayChange()
        updatePopoverSize()
        updateStatusItem(force: true)
    }

    // MARK: - Global & Local Hotkeys (⌘+⌥+Shift+C & ⌘+⌥+Shift+P)

    private func registerGlobalHotkeys() {
        // 1. Carbon system-wide HotKeys (works globally across macOS without Accessibility permissions)
        let clockHotKeyID = EventHotKeyID(signature: OSType(0x534B4556), id: 1)
        let pauseHotKeyID = EventHotKeyID(signature: OSType(0x534B4556), id: 2)
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData, let event = event else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr {
                    DispatchQueue.main.async {
                        if hotKeyID.id == 1 {
                            delegate.triggerClockToggle()
                        } else if hotKeyID.id == 2 {
                            delegate.triggerPauseToggle()
                        }
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        let modifiers = UInt32(cmdKey | optionKey | shiftKey)
        // ⌘+⌥+Shift+C -> Clock In / Out
        RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            modifiers,
            clockHotKeyID,
            GetApplicationEventTarget(),
            0,
            &clockHotKeyRef
        )

        // ⌘+⌥+Shift+P -> Pause / Resume
        RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            modifiers,
            pauseHotKeyID,
            GetApplicationEventTarget(),
            0,
            &pauseHotKeyRef
        )

        // 2. Local monitor (when Skeval Timer popover is active/focused)
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command, .option, .shift] {
                if event.keyCode == 8 { // C
                    self?.triggerClockToggle()
                    return nil
                } else if event.keyCode == 35 { // P
                    self?.triggerPauseToggle()
                    return nil
                }
            }
            return event
        }
    }

    func triggerClockToggle() {
        let now = Date()
        guard now.timeIntervalSince(lastClockHotkeyTriggerTime) > 0.3 else { return }
        lastClockHotkeyTriggerTime = now

        vm.checkAndHandleDayChange(now: now)
        if vm.recoveryMode { return }
        if vm.isRunning {
            vm.clockOut()
        } else {
            vm.clockIn()
        }
    }

    func triggerPauseToggle() {
        let now = Date()
        guard now.timeIntervalSince(lastPauseHotkeyTriggerTime) > 0.3 else { return }
        lastPauseHotkeyTriggerTime = now

        vm.checkAndHandleDayChange(now: now)
        if vm.recoveryMode { return }
        if vm.isPaused {
            vm.resumeTimer()
        } else if vm.isRunning {
            vm.pause()
        }
    }

    private func removeGlobalHotkeys() {
        if let clockHotKeyRef = clockHotKeyRef {
            UnregisterEventHotKey(clockHotKeyRef)
        }
        if let pauseHotKeyRef = pauseHotKeyRef {
            UnregisterEventHotKey(pauseHotKeyRef)
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        clockHotKeyRef = nil
        pauseHotKeyRef = nil
        eventHandlerRef = nil

        if let m = localHotkeyMonitor { NSEvent.removeMonitor(m) }
        localHotkeyMonitor = nil
    }

    // MARK: - Observation → Status Presenter

    private func setupStateObservation() {
        // Forward engine tick updates directly to status presenter
        let previousTick = vm.engine.onTick
        vm.engine.onTick = { [weak self] elapsed in
            previousTick?(elapsed)
            self?.updateStatusItem(force: false)
        }

        let previousPauseTick = vm.engine.onPauseTick
        vm.engine.onPauseTick = { [weak self] pauseElapsed in
            previousPauseTick?(pauseElapsed)
            self?.updateStatusItem(force: false)
        }

        observeState()
        observePopoverSize()
    }

    private func observeState() {
        // Only tracks things that affect STATUS BAR rendering (not size)
        withObservationTracking {
            _ = vm.state
            _ = vm.todayLog.accumulatedTotal
            _ = ThemeManager.shared.current
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateStatusItem(force: true)
                self.observeState()
            }
        }
    }

    private func observePopoverSize() {
        // Only tracks things that affect POPOVER HEIGHT (not status bar)
        withObservationTracking {
            _ = vm.desiredPopoverHeight
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updatePopoverSize()
                self.observePopoverSize()
            }
        }
    }

    private func updateStatusItem(force: Bool = false) {
        presenter.update(
            state: vm.state,
            accumulatedTotal: vm.todayLog.accumulatedTotal,
            pauseElapsed: vm.currentPauseElapsed,
            theme: ThemeManager.shared.theme,
            force: force
        )
    }

    // MARK: - Dashboard Window Management
    static func openDashboard() {
        if let popover = shared?.popover, popover.isShown {
            popover.performClose(nil)
        }
        shared?.dashboardController.showDashboard()
    }

    static func closeDashboard() {
        shared?.dashboardController.hideDashboard()
    }

    // MARK: - Launch at Login (SMAppService)

    static var isLaunchAtLoginEnabled: Bool {
        LaunchAtLoginHelper.isEnabled
    }

    static func setLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLoginHelper.setEnabled(enabled)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            if response.actionIdentifier == "COUNT_WORK" {
                self.vm.resolveSleep(countAsWork: true)
            } else if response.actionIdentifier == "COUNT_PAUSED" {
                self.vm.resolveSleep(countAsWork: false)
            } else {
                self.togglePopover()
            }
            completionHandler()
        }
    }
}

// MARK: - Popover Container View Controller

@MainActor
final class PopoverHostingController: NSViewController {
    let hostingController: NSHostingController<PopoverView>

    init(rootView: PopoverView) {
        self.hostingController = NSHostingController(rootView: rootView)
        self.hostingController.sizingOptions = []
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView()
        container.autoresizingMask = [.width, .height]
        addChild(hostingController)
        hostingController.view.autoresizingMask = [.width, .height]
        container.addSubview(hostingController.view)
        self.view = container
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        hostingController.view.frame = view.bounds
    }
}
