import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @Bindable var vm: TimerViewModel
    @State private var settingsExpanded = false
    @State private var launchAtLogin = AppDelegate.isLaunchAtLoginEnabled

    // Sleek Dark Theme Color Palette
    private let bgDark        = Color(red: 0.05, green: 0.06, blue: 0.09)
    private let cardBg        = Color(red: 0.10, green: 0.12, blue: 0.16)
    private let cardBorder    = Color(white: 0.20, opacity: 0.4)
    private let neonTeal      = Color(red: 0.22, green: 0.85, blue: 0.65)
    private let softRed       = Color(red: 0.98, green: 0.35, blue: 0.38)
    private let textPrimary   = Color(white: 0.95)
    private let textSecondary = Color(white: 0.55)

    var body: some View {
        ZStack {
            // Background with subtle glow when running
            bgDark.ignoresSafeArea()
            
            if vm.isRunning {
                RadialGradient(
                    gradient: Gradient(colors: [neonTeal.opacity(0.12), Color.clear]),
                    center: .top,
                    startRadius: 10,
                    endRadius: 280
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            VStack(spacing: 0) {
                headerRow
                
                Divider().background(Color(white: 0.16))

                if vm.recoveryMode {
                    recoveryBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                clockSection
                
                Divider().background(Color(white: 0.16))

                progressSection
                
                Divider().background(Color(white: 0.16))

                actionSection
                
                Divider().background(Color(white: 0.16))

                sprintHistorySection

                Divider().background(Color(white: 0.16))

                settingsSection
            }
        }
        .frame(width: 320)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("SKEVAL TIMER")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                        .kerning(1.2)
                    
                    Text("MVP")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(neonTeal.opacity(0.2))
                        .foregroundColor(neonTeal)
                        .clipShape(Capsule())
                }

                Text(todayString())
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()

            // Glowing Live Dot Indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: dotColor.opacity(0.9), radius: vm.isRunning ? 8 : 0)
                
                Text(stateLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(dotColor)
                    .textCase(.uppercase)
                    .kerning(0.8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(cardBg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(cardBorder, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Recovery Banner

    private var recoveryBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unfinished sprint from \(vm.currentSprint?.startLabel ?? "")",
                  systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.orange)

            HStack(spacing: 8) {
                Button("Resume ▶") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        vm.resumeRecovery()
                    }
                }
                .buttonStyle(PillButtonStyle(color: neonTeal))

                TextField("HH:mm:ss", text: $vm.recoveryEndText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary)
                    .frame(width: 72)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.5), lineWidth: 1))

                Button("Save") {
                    withAnimation { vm.saveRecoveryEndTime() }
                }
                .buttonStyle(PillButtonStyle(color: Color(white: 0.7)))

                Spacer()

                Button(action: { withAnimation { vm.dismissRecovery() } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            if let err = vm.recoveryEndError {
                Text(err)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(softRed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - Clock Section

    private var clockSection: some View {
        VStack(spacing: 4) {
            Text(vm.isRunning ? vm.currentElapsedLabel : "00:00:00")
                .font(.system(size: 44, weight: .light, design: .monospaced))
                .foregroundColor(vm.isPaused ? Color.orange : (vm.isRunning ? neonTeal : textPrimary))
                .shadow(color: vm.isPaused ? Color.orange.opacity(0.4) : (vm.isRunning ? neonTeal.opacity(0.5) : Color.clear), radius: 10, y: 2)
                .animation(.easeInOut(duration: 0.2), value: vm.currentElapsedLabel)

            if vm.isPaused {
                Label("Sprint paused", systemImage: "pause.circle.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
                    .transition(.opacity)
            } else if vm.todayLog.accumulatedTotal > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "sum")
                        .font(.system(size: 10, weight: .bold))
                    Text("Today's Total: \(vm.todayLog.accumulatedLabel)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundColor(textSecondary)
                .padding(.top, 2)
            } else {
                Text("Ready to start your next sprint")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(textSecondary)
            }
        }
        .padding(.vertical, 16)
        .animation(.easeInOut(duration: 0.25), value: vm.isPaused)
    }

    // MARK: - Daily Goal Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Daily Goal Target")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(textSecondary)
                    .textCase(.uppercase)
                    .kerning(0.8)
                Spacer()
                Text(vm.progressLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(vm.progressFraction >= 1.0 ? neonTeal : textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [neonTeal.opacity(0.8), neonTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(vm.progressFraction), height: 6)
                        .shadow(color: neonTeal.opacity(0.6), radius: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.progressFraction)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Clock In card
                VStack(alignment: .leading, spacing: 3) {
                    Text("START TIME")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(textSecondary)
                        .kerning(0.6)
                    Text(vm.currentSprint?.startLabel ?? "--:--:--")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(vm.currentSprint != nil ? neonTeal : textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))

                // Clock Out card
                VStack(alignment: .leading, spacing: 3) {
                    Text("END TIME")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(textSecondary)
                        .kerning(0.6)
                    Text(vm.currentSprint?.endLabel ?? "--:--:--")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
            }

            // Pause / Resume row — only visible when a sprint is active
            if vm.isRunning {
                HStack(spacing: 8) {
                    Button(action: pauseResumeAction) {
                        HStack(spacing: 6) {
                            Image(systemName: vm.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(vm.isPaused ? "RESUME" : "PAUSE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .kerning(0.4)
                        }
                        .foregroundColor(vm.isPaused ? .black : .orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            vm.isPaused
                                ? LinearGradient(colors: [Color.orange.opacity(0.9), Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.orange.opacity(0.12), Color.orange.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(vm.isPaused ? 0 : 0.4), lineWidth: 1))
                    }
                    .buttonStyle(PressedScaleButtonStyle())
                    .disabled(vm.recoveryMode)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Big Clock In / Clock Out Button
            Button(action: mainAction) {
                HStack(spacing: 8) {
                    Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 13, weight: .black))
                    Text(vm.isRunning ? "CLOCK OUT & COPY" : "CLOCK IN")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .kerning(0.5)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: vm.isRunning
                            ? [Color(red: 1.0, green: 0.45, blue: 0.45), softRed]
                            : [Color(red: 0.35, green: 0.95, blue: 0.75), neonTeal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: (vm.isRunning ? softRed : neonTeal).opacity(0.45), radius: 8, y: 3)
            }
            .buttonStyle(PressedScaleButtonStyle())
            .disabled(vm.recoveryMode)

            if vm.currentSprint != nil {
                Button(action: { withAnimation { vm.reset() } }) {
                    Label("Discard current sprint", systemImage: "xmark.circle")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: vm.isRunning)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: vm.isPaused)
    }

    // MARK: - Sprint History Section

    private var sprintHistorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(neonTeal)
                    Text("TODAY'S SPRINTS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                        .kerning(0.8)
                }

                Spacer()

                Text("\(vm.todayLog.completedSprints.count) completed")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if vm.todayLog.completedSprints.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 20))
                        .foregroundColor(textSecondary.opacity(0.5))
                    Text("No sprints logged for today yet")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(cardBg.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 6) {
                        ForEach(Array(vm.todayLog.completedSprints.enumerated()), id: \.element.id) { idx, sprint in
                            SprintCardRow(
                                index: idx + 1,
                                sprint: sprint,
                                isCopied: vm.lastCopiedId == sprint.id,
                                neonTeal: neonTeal,
                                softRed: softRed,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                onCopy: { vm.copy(sprint: sprint) },
                                onDelete: { withAnimation { vm.delete(sprint: sprint) } }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 0) {
            // Header toggle row
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { settingsExpanded.toggle() } }) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11))
                            .foregroundColor(textSecondary)
                        Text("SETTINGS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)
                            .kerning(0.8)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(textSecondary)
                        .rotationEffect(.degrees(settingsExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if settingsExpanded {
                VStack(alignment: .leading, spacing: 14) {

                    // Daily Goal Slider
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Daily Goal")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(textPrimary)
                            Spacer()
                            Text(vm.goal.goalLabel)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(neonTeal)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(neonTeal.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        Slider(value: $vm.goal.dailyGoalHours, in: 1...16, step: 0.5)
                            .tint(neonTeal)
                            .controlSize(.small)
                        HStack {
                            Text("1h")
                            Spacer()
                            Text("16h")
                        }
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundColor(textSecondary)
                    }

                    Divider().background(Color(white: 0.18))

                    // Launch at Login
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(textPrimary)
                            Text("Start Skeval Timer when you log in")
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundColor(textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(neonTeal)
                            .onChange(of: launchAtLogin) { _, newValue in
                                AppDelegate.setLaunchAtLogin(newValue)
                            }
                    }

                    Divider().background(Color(white: 0.18))

                    // Hotkey hint
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 10))
                            .foregroundColor(textSecondary)
                        Text("Global hotkey:")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundColor(textSecondary)
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach(["⌘", "⇧", "C"], id: \.self) { key in
                                Text(key)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(textPrimary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(cardBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
                            }
                        }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Helpers

    private var stateLabel: String {
        if vm.recoveryMode { return "RECOVERY" }
        if vm.isPaused { return "PAUSED" }
        if vm.isRunning { return "ACTIVE" }
        return "IDLE"
    }

    private var dotColor: Color {
        if vm.recoveryMode { return .orange }
        if vm.isPaused { return Color(red: 1.0, green: 0.65, blue: 0.0) }
        return vm.isRunning ? neonTeal : textSecondary
    }

    private func mainAction() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            vm.isRunning ? vm.clockOut() : vm.clockIn()
        }
    }

    private func pauseResumeAction() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            vm.isPaused ? vm.resumeTimer() : vm.pause()
        }
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM yyyy"
        return f.string(from: Date())
    }
}

// MARK: - Sprint Card Row Component

private struct SprintCardRow: View {
    let index: Int
    let sprint: Sprint
    let isCopied: Bool
    let neonTeal: Color
    let softRed: Color
    let textPrimary: Color
    let textSecondary: Color
    let cardBg: Color
    let cardBorder: Color
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("#\(index)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(neonTeal)
                .frame(width: 24, alignment: .center)
                .padding(.vertical, 4)
                .background(neonTeal.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(sprint.startLabel)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(textPrimary)
                    Text("→")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(textSecondary)
                    Text(sprint.endLabel)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(textPrimary)
                }

                Text(sprint.durationLabel)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(textSecondary)
            }

            Spacer()

            // Copy Button with Animated Feedback
            Button(action: onCopy) {
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 11, weight: .bold))
                    Text(isCopied ? "COPIED" : "COPY")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundColor(isCopied ? .black : neonTeal)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isCopied ? neonTeal : neonTeal.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 11))
                    .foregroundColor(softRed.opacity(0.7))
                    .padding(6)
                    .background(softRed.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
    }
}

// MARK: - Button Press Animation Style

private struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Pill Button Style

private struct PillButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .clipShape(Capsule())
    }
}

#Preview {
    PopoverView(vm: TimerViewModel())
        .preferredColorScheme(.dark)
}
