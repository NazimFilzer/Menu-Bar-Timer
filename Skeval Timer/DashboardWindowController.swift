import AppKit
import SwiftUI

@MainActor
final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let vm: TimerViewModel

    var onActivationPolicyChanged: ((NSApplication.ActivationPolicy) -> Void)? = nil

    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }

    init(vm: TimerViewModel) {
        self.vm = vm

        let contentRect = NSRect(x: 0, y: 0, width: 920, height: 620)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 800, height: 550)
        window.title = "Skeval Timer Dashboard"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()

        let hostingView = NSHostingView(rootView: DashboardView(vm: vm))
        window.contentView = hostingView

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDashboard() {
        NSApp.setActivationPolicy(.regular)
        onActivationPolicyChanged?(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideDashboard() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
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
