import SwiftUI

/// Layout B: a compact timer, today's summary, and a separate history date.
struct PopoverView: View {
    @Bindable var vm: TimerViewModel
    @State private var themeManager = ThemeManager.shared
    @State private var isEditingTag = false
    @State private var tagText = ""
    @State private var discardSprint: Sprint?
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingQuit = false

    private var theme: PopoverTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            Live { header }
            Divider().overlay(theme.cardBorder)
            ScrollView {
                VStack(spacing: 10) {
                    PopoverNoticesView(vm: vm, theme: theme)
                    PopoverTimerStripView(vm: vm, theme: theme)
                    PopoverDailySummaryView(vm: vm, theme: theme)
                    PopoverSprintHistoryView(vm: vm, theme: theme)
                }
                .padding(12)
            }
            Divider().overlay(theme.cardBorder)
            HStack {
                Label("Local work history", systemImage: "lock.fill")
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button {
                    isConfirmingQuit = true
                } label: {
                    Label("Quit…", systemImage: "power")
                }
                .buttonStyle(PopoverLinkButtonStyle(color: theme.dangerText))
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 330)
        .background {
            ZStack(alignment: .top) {
                theme.bgDark
                if vm.isRunning {
                    // A soft wash of the theme accent while a sprint is active.
                    RadialGradient(colors: [theme.accentColor.opacity(theme.isLight ? 0.18 : 0.12), .clear],
                                   center: .top, startRadius: 10, endRadius: 260)
                }
            }
            .ignoresSafeArea()
        }
        .foregroundStyle(theme.textPrimary)
        .themeAppearance(theme)
        .sheet(isPresented: $vm.isManualEntryPresented) {
            ManualSprintSheetView(vm: vm, theme: theme).frame(width: 330)
        }
        .alert("Discard this sprint?", isPresented: $isConfirmingDiscard, presenting: discardSprint) { sprint in
            Button("Keep sprint", role: .cancel) { }
            Button("Discard sprint", role: .destructive) {
                // A later state change must not discard a different sprint.
                guard vm.currentSprint?.id == sprint.id else { return }
                vm.reset()
            }
        } message: { sprint in
            Text("This removes the sprint started at \(sprint.startLabel). Its work will not count toward your total or earnings.")
        }
        .alert("Quit Skeval Timer?", isPresented: $isConfirmingQuit) {
            Button("Keep open", role: .cancel) { }
            Button("Quit") { NSApp.terminate(nil) }
        } message: {
            Text("An open sprint will need review when you return. Recorded sprints stay saved on this Mac.")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("SKEVAL TIMER")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .kerning(1.0)
                .lineLimit(1).fixedSize()
            Spacer(minLength: 4)
            Button(action: AppDelegate.openDashboard) {
                Label("Dashboard", systemImage: "macwindow")
            }
            .buttonStyle(PopoverCapsuleButtonStyle(theme: theme))
            .help("Open the dashboard")
            Menu {
                Button("Sprint tag…") {
                    tagText = vm.currentTag ?? vm.pendingTag
                    isEditingTag = true
                }
                Button("Discard sprint…", role: .destructive) {
                    discardSprint = vm.currentSprint
                    isConfirmingDiscard = discardSprint != nil
                }
                .disabled(vm.currentSprint == nil)
                Divider()
                Button("About Skeval Timer") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Skeval Timer",
                        .applicationVersion: AppVersion.marketingVersion
                    ])
                }
                Button("Quit Skeval Timer…") { isConfirmingQuit = true }
            } label: {
                PopoverMoreIcon(theme: theme)
            }
            .popoverMenuStyle()
            .accessibilityLabel("More actions")
            .popover(isPresented: $isEditingTag) { tagEditor }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sprint tag").font(.headline)
            TextField("Client or development, optional", text: $tagText)
                .textFieldStyle(.roundedBorder).accessibilityLabel("Sprint tag")
                .onSubmit(saveTag)
            HStack {
                Button("Cancel") { isEditingTag = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Set tag", action: saveTag)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16).frame(width: 290)
        .foregroundStyle(theme.textPrimary).background(theme.bgDark)
        .themeAppearance(theme)
    }

    private func saveTag() {
        let clean = tagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if vm.currentSprint != nil {
            vm.setTag(clean.isEmpty ? nil : clean)
        } else {
            vm.pendingTag = clean
        }
        isEditingTag = false
    }
}

private struct PopoverNoticesView: View {
    let vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        VStack(spacing: 10) {
            if let error = vm.persistenceError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(theme.warningText)
                    .themedCard(theme)
            }
            if vm.recoveryMode {
                RecoveryBannerView(vm: vm, theme: theme)
            } else if let interval = vm.pendingSleepInterval {
                SleepResolutionBannerView(vm: vm, interval: interval, theme: theme)
            }
        }
    }
}

private struct PopoverTimerStripView: View {
    let vm: TimerViewModel
    let theme: PopoverTheme

    private var controlsHeld: Bool { vm.recoveryMode || vm.hasPendingSleepResolution }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                PopoverSectionTitle(sprintTitle, systemImage: "timer", theme: theme)
                Spacer(minLength: 4)
                Label(vm.statusTitle.capitalized, systemImage: statusSymbol)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.statusText(for: vm.state))
            }
            Live {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.currentSprint == nil ? "00:00:00" : vm.currentElapsedLabel)
                        .font(.system(size: 34, weight: .light, design: .monospaced))
                        .foregroundStyle(timerColor)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityLabel("Sprint work time")
                    if vm.isPaused && !vm.hasPendingSleepResolution {
                        Label("Paused for \(vm.currentPauseLabel)", systemImage: "pause.circle.fill")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.warningText)
                    } else if vm.currentSprint == nil {
                        Text("Ready to start your next sprint")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                if vm.isRunning {
                    Button {
                        vm.isPaused ? vm.resumeTimer() : vm.pause()
                    } label: {
                        Label(vm.isPaused ? "Resume" : "Pause", systemImage: vm.isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(PopoverActionButtonStyle(theme: theme, kind: vm.isPaused ? .resume : .pause))
                    .help("Pause or resume, ⌘⌥⇧P")
                    Button(action: vm.clockOut) {
                        Label("Clock out", systemImage: "stop.fill")
                    }
                    .buttonStyle(PopoverActionButtonStyle(theme: theme, kind: .stop))
                    .help("Clock out and copy sprint times, ⌘⌥⇧C")
                } else {
                    Button(action: { vm.clockIn() }) {
                        Label("Clock in", systemImage: "play.fill")
                    }
                    .buttonStyle(PopoverActionButtonStyle(theme: theme, kind: .start))
                    .help("Clock in, ⌘⌥⇧C")
                }
            }
            .disabled(controlsHeld)
        }
        .themedCard(theme, padding: 14, radius: 12)
    }

    private var timerColor: Color {
        if vm.isPaused { return theme.warningText }
        return vm.isRunning ? theme.accentText : theme.textPrimary
    }

    private var sprintTitle: String {
        guard let sprint = vm.currentSprint else { return "Timer" }
        let day = Calendar.current.isDateInToday(sprint.startTime)
            ? "Today" : TimeFormatter.format(shortDayTitle: sprint.startTime)
        return "Sprint · \(day)"
    }

    private var statusSymbol: String {
        if controlsHeld { return "exclamationmark.circle" }
        if vm.isPaused { return "pause.circle.fill" }
        return vm.isRunning ? "play.circle.fill" : "circle"
    }
}

private struct PopoverActionButtonStyle: ButtonStyle {
    enum Kind { case start, pause, resume, stop }
    let theme: PopoverTheme
    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.warningText.opacity(0.35), lineWidth: kind == .pause ? 1 : 0))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private var foreground: Color {
        switch kind {
        case .start: theme.actionButtonForeground
        case .pause: theme.warningText
        case .resume: .black
        case .stop: .white
        }
    }

    private var background: Color {
        switch kind {
        case .start: theme.accentColor
        case .pause: .orange.opacity(theme.isLight ? 0.16 : 0.18)
        case .resume: .orange
        case .stop: theme.dangerFill
        }
    }
}

// MARK: - Shared popover components

/// Dashboard-style section title: uppercase, tracked, secondary, with an accent symbol.
struct PopoverSectionTitle: View {
    let title: String
    let systemImage: String
    let theme: PopoverTheme

    init(_ title: String, systemImage: String, theme: PopoverTheme) {
        self.title = title
        self.systemImage = systemImage
        self.theme = theme
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.accentIcon)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase).kerning(0.8)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Text-only action in the theme color. Native `.link` buttons ignore the theme when the app is inactive.
struct PopoverLinkButtonStyle: ButtonStyle {
    let color: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}

/// Accent-tinted capsule, used for the Dashboard button.
struct PopoverCapsuleButtonStyle: ButtonStyle {
    let theme: PopoverTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.accentText)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(theme.accentColor.opacity(configuration.isPressed ? 0.28 : 0.16), in: Capsule())
            .overlay(Capsule().stroke(theme.accentColor.opacity(0.45), lineWidth: 1))
            .contentShape(Capsule())
            .fixedSize()
    }
}

/// Full-width soft accent button, used for timesheet copy.
struct PopoverSoftButtonStyle: ButtonStyle {
    let theme: PopoverTheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(isEnabled ? theme.accentText : theme.textSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(theme.accentColor.opacity(configuration.isPressed ? 0.26 : 0.14),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.accentColor.opacity(0.4), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? 1 : 0.55)
    }
}

/// Small square icon button, used for the break −/+ controls.
struct PopoverIconButtonStyle: ButtonStyle {
    let theme: PopoverTheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(theme.textPrimary)
            .frame(width: 22, height: 20)
            .background(theme.bgDark.opacity(configuration.isPressed ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.cardBorder, lineWidth: 1))
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.35)
    }
}

/// The visible ellipsis for "more actions" menus.
struct PopoverMoreIcon: View {
    let theme: PopoverTheme

    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(theme.textSecondary)
            .frame(width: 24, height: 22)
            .background(theme.cardBg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.cardBorder, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// A themed capsule label for menus, with a chevron.
struct PopoverChipLabel: View {
    let title: String
    let theme: PopoverTheme
    var highlighted = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(highlighted ? theme.warningText : theme.textPrimary)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(theme.bgDark, in: Capsule())
        .overlay(Capsule().stroke(highlighted ? theme.warningText.opacity(0.5) : theme.cardBorder, lineWidth: 1))
        .contentShape(Capsule())
    }
}

extension View {
    /// Draws a menu with its own SwiftUI label rather than a native bezel.
    func popoverMenuStyle() -> some View {
        menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
    }
}
