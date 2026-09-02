import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications

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

    // 1 Hz pill update – only redraws when the displayed second or pause state changes
    private var pillTimer: Timer? = nil
    private var lastPillSecond: Int = -1
    private var lastPillPaused: Bool = false

    // Global & local hotkey monitors (⌘+Shift+C)
    private var globalHotkeyMonitor: Any? = nil
    private var localHotkeyMonitor: Any? = nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Skeval Timer")
            btn.image?.isTemplate = true
            btn.action = #selector(togglePopover)
            btn.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        updatePopoverSize()
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(vm: vm).preferredColorScheme(.dark)
        )

        registerGlobalHotkey()
        observeState()
        updateStatusItem()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeGlobalHotkey()
    }

    // MARK: - Popover toggle & sizing

    private func updatePopoverSize() {
        let hasSprints = !vm.todayLog.completedSprints.isEmpty
        let height: CGFloat = hasSprints ? 620 : 440
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

    // MARK: - Global & Local Hotkey  ⌘ + Shift + C

    private func registerGlobalHotkey() {
        // 1. Global monitor (when Skeval Timer is in background)
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkey(event: event)
        }

        // 2. Local monitor (when Skeval Timer popover is active/focused)
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleHotkey(event: event) == true {
                return nil // Consume event
            }
            return event
        }
    }

    @discardableResult
    private func handleHotkey(event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // keyCode 8 = C,  ⌘+Shift+C
        if flags == [.command, .shift] && event.keyCode == 8 {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.vm.recoveryMode { return }
                if self.vm.isRunning {
                    self.vm.clockOut()
                } else {
                    self.vm.clockIn()
                }
            }
            return true
        }
        return false
    }

    private func removeGlobalHotkey() {
        if let m = globalHotkeyMonitor { NSEvent.removeMonitor(m) }
        if let m = localHotkeyMonitor { NSEvent.removeMonitor(m) }
        globalHotkeyMonitor = nil
        localHotkeyMonitor = nil
    }

    // MARK: - Observation → status item

    private func observeState() {
        withObservationTracking {
            _ = vm.isRunning
            _ = vm.isPaused
            _ = vm.menuBarTitle
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateStatusItem()
                self.observeState()
            }
        }
    }

    private func updateStatusItem() {
        updatePopoverSize()
        guard let btn = statusItem.button else { return }
        btn.title = ""
        if vm.isRunning {
            if pillTimer == nil { startPillTimer() }
            renderPillIfNeeded(force: true)
        } else {
            stopPillTimer()
            let idleText = vm.todayLog.accumulatedTotal > 0 ? vm.todayLog.accumulatedLabel : "00:00:00"
            btn.image = makePillImage(text: idleText, state: .idle)
            btn.image?.isTemplate = false
        }
    }

    // MARK: - 1 Hz Pill Timer (energy-efficient)

    private func startPillTimer() {
        stopPillTimer()
        lastPillSecond = -1
        lastPillPaused = false
        // Fire immediately once, then every second
        renderPillIfNeeded(force: true)
        pillTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.renderPillIfNeeded(force: false) }
        }
    }

    private func stopPillTimer() {
        pillTimer?.invalidate()
        pillTimer = nil
        lastPillSecond = -1
        lastPillPaused = false
    }

    private func renderPillIfNeeded(force: Bool = false) {
        guard let btn = statusItem.button else { return }
        let elapsed = Int(vm.currentElapsed)
        let paused = vm.isPaused
        if !force && elapsed == lastPillSecond && paused == lastPillPaused { return }
        lastPillSecond = elapsed
        lastPillPaused = paused
        let text = vm.currentElapsedLabel
        let state: PillState = paused ? .paused : .running
        btn.title = ""
        btn.image = makePillImage(text: text, state: state)
        btn.image?.isTemplate = false
    }

    // MARK: - Pill Image Rendering (Idle = Grey, Active = Red, Paused = Yellow)

    private enum PillState {
        case running
        case paused
        case idle
    }

    private func makePillImage(text: String, state: PillState) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        let textColor: NSColor = (state == .paused) ? .black : .white
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let textSize = (text as NSString).size(withAttributes: textAttrs)

        let dotSize: CGFloat = 6
        let gap: CGFloat = 5
        let paddingX: CGFloat = 8
        let pillHeight: CGFloat = 19
        let pillWidth = paddingX + dotSize + gap + ceil(textSize.width) + paddingX

        let size = NSSize(width: pillWidth, height: pillHeight)
        let img = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let pillRect = CGRect(x: 1, y: 1, width: pillWidth - 2, height: pillHeight - 2)
            let cornerRadius = pillRect.height / 2

            // Background capsule color by state
            let pillColor: NSColor
            switch state {
            case .running:
                pillColor = NSColor(red: 0.95, green: 0.22, blue: 0.24, alpha: 0.95) // Red
            case .paused:
                pillColor = NSColor(red: 1.0, green: 0.68, blue: 0.0, alpha: 0.95)  // Amber/Yellow
            case .idle:
                pillColor = NSColor(white: 0.30, alpha: 0.95)                        // Sleek Grey
            }

            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.setFillColor(pillColor.cgColor)
            ctx.addPath(pillPath)
            ctx.fillPath()

            switch state {
            case .paused:
                // Black pause bars icon inside yellow pill
                let barW: CGFloat = 2
                let barH: CGFloat = 7
                let barY = (pillHeight - barH) / 2
                let bar1X = paddingX
                let bar2X = paddingX + barW + 2
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fill(CGRect(x: bar1X, y: barY, width: barW, height: barH))
                ctx.fill(CGRect(x: bar2X, y: barY, width: barW, height: barH))
            case .running:
                // White active recording dot inside red pill
                let dotY = (pillHeight - dotSize) / 2
                let dotRect = CGRect(x: paddingX, y: dotY, width: dotSize, height: dotSize)
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.addEllipse(in: dotRect)
                ctx.fillPath()
            case .idle:
                // Subtle grey/white dot inside idle grey pill
                let dotY = (pillHeight - dotSize) / 2
                let dotRect = CGRect(x: paddingX, y: dotY, width: dotSize, height: dotSize)
                ctx.setFillColor(NSColor(white: 0.75, alpha: 0.8).cgColor)
                ctx.addEllipse(in: dotRect)
                ctx.fillPath()
            }

            // Clock text inside pill
            let textX = paddingX + dotSize + gap
            let textY = (pillHeight - textSize.height) / 2 + 0.5
            (text as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: textAttrs)

            return true
        }
        img.isTemplate = false
        return img
    }

    // MARK: - Launch at Login (SMAppService)

    static var isLaunchAtLoginEnabled: Bool {
        guard Bundle.main.bundlePath.hasPrefix("/Applications") else { return false }
        return (try? SMAppService.mainApp.status == .enabled) ?? false
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
