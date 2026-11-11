import AppKit
import SwiftUI

@MainActor
final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let vm: TimerViewModel
    private let setActivationPolicy: @MainActor (NSApplication.ActivationPolicy) -> Void
    private let activateApplication: @MainActor () -> Void

    var onActivationPolicyChanged: ((NSApplication.ActivationPolicy) -> Void)? = nil
    /// Builds the window's SwiftUI content. It exists only while the window is shown,
    /// because hidden SwiftUI views still update on every timer tick.
    lazy var makeContent: () -> NSView = { [unowned self] in NSHostingView(rootView: DashboardView(vm: vm)) }
    private var content: NSView?

    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }

    init(
        vm: TimerViewModel,
        setActivationPolicy: @escaping @MainActor (NSApplication.ActivationPolicy) -> Void = {
            NSApplication.shared.setActivationPolicy($0)
        },
        activateApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    ) {
        self.vm = vm
        self.setActivationPolicy = setActivationPolicy
        self.activateApplication = activateApplication

        let contentRect = NSRect(x: 0, y: 0, width: 1140, height: 780)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 1000, height: 650)
        window.title = "Skeval Timer Dashboard"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SkevalDashboard")
        if !window.setFrameUsingName("SkevalDashboard") { window.center() }

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDashboard() {
        setActivationPolicy(.regular)
        onActivationPolicyChanged?(.regular)
        if content == nil {
            content = makeContent()
            window?.contentView = content
        }
        window?.makeKeyAndOrderFront(nil)
        activateApplication()
    }

    func hideDashboard() {
        window?.orderOut(nil)
        content = nil
        window?.contentView = nil
        setActivationPolicy(.accessory)
        onActivationPolicyChanged?(.accessory)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideDashboard()
        return false // Preserve window instance in memory for fast reopening
    }

    func windowWillClose(_ notification: Notification) {
        hideDashboard()
    }
}
