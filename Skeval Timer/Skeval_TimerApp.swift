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
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let vm = TimerViewModel()
    private var presenter: StatusBarPresenter!

    // Global Carbon hotkey & local monitor (⌘+⌥+Shift+C)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var localHotkeyMonitor: Any? = nil
    private var lastHotkeyTriggerTime: Date = .distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

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
        let hostingController = NSHostingController(
            rootView: PopoverView(vm: vm).preferredColorScheme(.dark)
        )
        hostingController.sizingOptions = []
        popover.contentViewController = hostingController

        registerGlobalHotkey()
        setupStateObservation()
        updateStatusItem(force: true)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeGlobalHotkey()
    }

    // MARK: - Popover toggle & sizing

    func updatePopoverSize() {
        let hasSprints = !vm.todayLog.completedSprints.isEmpty
        let height: CGFloat
        if vm.isSettingsExpanded {
            height = hasSprints ? 640 : 570
        } else {
            height = hasSprints ? 590 : 430
        }
        popover?.contentSize = NSSize(width: 330, height: height)
    }

    @objc func togglePopover() {
        guard let btn = statusItem.button else { return }
        updatePopoverSize()
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Global & Local Hotkey  ⌘ + ⌥ + Shift + C

    private func registerGlobalHotkey() {
        // 1. Carbon system-wide HotKey (works globally across macOS without Accessibility permissions)
        let hotKeyID = EventHotKeyID(signature: OSType(0x534B4556), id: 1)
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    delegate.triggerClockToggle()
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        let modifiers = UInt32(cmdKey | optionKey | shiftKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        // 2. Local monitor (when Skeval Timer popover is active/focused)
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // keyCode 8 = C,  ⌘+⌥+Shift+C
            if flags == [.command, .option, .shift] && event.keyCode == 8 {
                self?.triggerClockToggle()
                return nil // Consume event
            }
            return event
        }
    }

    func triggerClockToggle() {
        let now = Date()
        guard now.timeIntervalSince(lastHotkeyTriggerTime) > 0.3 else { return }
        lastHotkeyTriggerTime = now

        if vm.recoveryMode { return }
        if vm.isRunning {
            vm.clockOut()
        } else {
            vm.clockIn()
        }
    }

    private func removeGlobalHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        hotKeyRef = nil
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

        observeState()
        observePopoverSize()
    }

    private func observeState() {
        // Only tracks things that affect STATUS BAR rendering (not size)
        withObservationTracking {
            _ = vm.state
            _ = vm.todayLog.accumulatedTotal
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
            _ = vm.todayLog.completedSprints.count
            _ = vm.isSettingsExpanded
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
            force: force
        )
    }

    // MARK: - Launch at Login (SMAppService)

    static var isLaunchAtLoginEnabled: Bool {
        guard Bundle.main.bundlePath.hasPrefix("/Applications") else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[LaunchAtLogin] Notice: SMAppService requires app to be in /Applications. \(error)")
        }
    }
}
