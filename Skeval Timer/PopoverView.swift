import SwiftUI
import ServiceManagement

// MARK: - Main Popover View

struct PopoverView: View {
    @Bindable var vm: TimerViewModel
    @State private var launchAtLogin = AppDelegate.isLaunchAtLoginEnabled
    @State private var themeManager = ThemeManager.shared

    private var theme: PopoverTheme { themeManager.theme }

    var body: some View {
        ZStack {
            theme.bgDark.ignoresSafeArea()

            if vm.isRunning {
                RadialGradient(
                    gradient: Gradient(colors: [theme.neonTeal.opacity(0.12), Color.clear]),
                    center: .top,
                    startRadius: 10,
                    endRadius: 280
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            VStack(spacing: 0) {
                PopoverHeaderView(vm: vm, theme: theme)

                Divider().background(theme.dividerColor)

                if vm.recoveryMode {
                    RecoveryBannerView(vm: vm, theme: theme)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ClockSectionView(vm: vm, theme: theme)

                Divider().background(theme.dividerColor)

                DailyGoalProgressView(vm: vm, theme: theme)

                Divider().background(theme.dividerColor)

                ActionSectionView(vm: vm, theme: theme)

                Divider().background(theme.dividerColor)

                SprintHistorySectionView(vm: vm, theme: theme)

                Divider().background(theme.dividerColor)

                SettingsSectionView(
                    vm: vm,
                    theme: theme,
                    launchAtLogin: $launchAtLogin,
                    themeManager: themeManager
                )
            }
        }
        .frame(width: 330)
        .focusEffectDisabled()
        .preferredColorScheme(theme.isLight ? .light : .dark)
    }
}

// MARK: - Header View

private struct PopoverHeaderView: View {
    let vm: TimerViewModel
    let theme: PopoverTheme

    private var dotColor: Color {
        theme.statusColor(for: vm.state)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("SKEVAL TIMER")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .kerning(1.2)

                    Text("MVP")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(theme.neonTeal.opacity(0.2))
                        .foregroundColor(theme.neonTeal)
                        .clipShape(Capsule())
                }

                Text(TimeFormatter.format(headerDate: Date()))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: dotColor.opacity(0.9), radius: vm.isRunning ? 8 : 0)

                Text(vm.statusTitle)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(dotColor)
                    .textCase(.uppercase)
                    .kerning(0.8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.cardBg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.cardBorder, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Recovery Banner View

private struct RecoveryBannerView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
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
                .buttonStyle(PillButtonStyle(color: theme.accentColor, foregroundColor: theme.actionButtonForeground))
                .focusable(false)

                TextField("HH:mm:ss", text: $vm.recoveryEndText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 72)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(theme.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                    .focusable(false)

                Button("Save") {
                    withAnimation { vm.saveRecoveryEndTime() }
                }
                .buttonStyle(PillButtonStyle(color: Color(white: 0.7)))
                .focusable(false)

                Spacer()

                Button(action: { withAnimation { vm.dismissRecovery() } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            if let err = vm.recoveryEndError {
                Text(err)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.softRed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
    }
}

// MARK: - Clock Section View

private struct ClockSectionView: View {
    let vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        VStack(spacing: 5) {
            Text(vm.isRunning ? vm.currentElapsedLabel : "00:00:00")
                .font(.system(size: 44, weight: .light, design: .monospaced))
                .foregroundColor(vm.isPaused ? Color.orange : (vm.isRunning ? theme.neonTeal : theme.textPrimary))
                .shadow(color: vm.isPaused ? Color.orange.opacity(0.4) : (vm.isRunning ? theme.neonTeal.opacity(0.5) : Color.clear), radius: 10, y: 2)
                .animation(.easeInOut(duration: 0.2), value: vm.currentElapsedLabel)

            if vm.isPaused {
                VStack(spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("PAUSED FOR \(vm.currentPauseLabel)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.75, blue: 0.2), Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.orange.opacity(0.4), radius: 4, y: 1)

                    if vm.hasMultiplePauses {
                        Text("Total break this sprint: \(vm.totalSprintPausedLabel)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color.orange.opacity(0.85))
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if vm.todayLog.accumulatedTotal > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "sum")
                        .font(.system(size: 10, weight: .bold))
                    Text("Today's Total: \(vm.todayLog.accumulatedLabel)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundColor(theme.textSecondary)
                .padding(.top, 2)
            } else {
                Text("Ready to start your next sprint")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.vertical, 16)
        .animation(.easeInOut(duration: 0.25), value: vm.isPaused)
    }
}

// MARK: - Daily Goal Progress View

private struct DailyGoalProgressView: View {
    let vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Daily Goal Target")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .textCase(.uppercase)
                    .kerning(0.8)
                Spacer()
                Text(vm.progressLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(vm.progressFraction >= 1.0 ? theme.neonTeal : theme.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.isLight ? Color(white: 0.85) : Color(white: 0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [theme.neonTeal.opacity(0.8), theme.neonTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(vm.progressFraction), height: 6)
                        .shadow(color: theme.neonTeal.opacity(0.6), radius: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.progressFraction)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Timestamp Card (Reusable Component)

private struct TimestampCard: View {
    let title: String
    let value: String
    var isHighlighted: Bool = false
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(theme.textSecondary)
                .kerning(0.6)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(isHighlighted ? theme.neonTeal : theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))
    }
}

// MARK: - Action Section View

private struct ActionSectionView: View {
    let vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TimestampCard(
                    title: "START TIME",
                    value: vm.currentSprint?.startLabel ?? "--:--:--",
                    isHighlighted: vm.currentSprint != nil,
                    theme: theme
                )

                TimestampCard(
                    title: "END TIME",
                    value: vm.currentSprint?.endLabel ?? "--:--:--",
                    isHighlighted: false,
                    theme: theme
                )
            }

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

            Button(action: mainAction) {
                HStack(spacing: 8) {
                    Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 13, weight: .black))
                    Text(vm.isRunning ? "CLOCK OUT & COPY" : "CLOCK IN")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .kerning(0.5)
                }
                .foregroundColor(vm.isRunning ? .white : theme.actionButtonForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: vm.isRunning
                            ? [Color(red: 1.0, green: 0.45, blue: 0.45), theme.softRed]
                            : [theme.accentColor.opacity(0.85), theme.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: (vm.isRunning ? theme.softRed : theme.accentColor).opacity(0.45), radius: 8, y: 3)
            }
            .buttonStyle(PressedScaleButtonStyle())
            .focusable(false)
            .disabled(vm.recoveryMode)

            if vm.currentSprint != nil {
                Button(action: { withAnimation { vm.reset() } }) {
                    Label("Discard current sprint", systemImage: "xmark.circle")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: vm.isRunning)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: vm.isPaused)
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
}

// MARK: - Sprint History Section View

private struct SprintHistorySectionView: View {
    let vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(theme.neonTeal)
                    Text("TODAY'S SPRINTS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .kerning(0.8)
                }

                Spacer()

                HStack(spacing: 5) {
                    Text("\(vm.todayLog.completedSprints.count) completed")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textSecondary)

                    if vm.todayLog.totalPausedDuration > 0 {
                        Text("•")
                            .font(.system(size: 9))
                            .foregroundColor(theme.textSecondary.opacity(0.5))
                        HStack(spacing: 3) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 7))
                            Text("\(vm.todayLog.totalPausedLabel) breaks")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(Color.orange.opacity(0.85))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if vm.todayLog.completedSprints.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 20))
                        .foregroundColor(theme.textSecondary.opacity(0.5))
                    Text("No sprints logged for today yet")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(theme.cardBg.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 5) {
                        ForEach(vm.todayLog.completedSprintsDescending, id: \.sprint.id) { item in
                            SprintCardRow(
                                index: item.index,
                                sprint: item.sprint,
                                isCopied: vm.lastCopiedId == item.sprint.id,
                                theme: theme,
                                onCopy: { vm.copy(sprint: item.sprint) },
                                onDelete: { withAnimation { vm.delete(sprint: item.sprint) } }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: 340)
            }
        }
        .padding(.bottom, 12)
    }
}

// MARK: - Sprint Card Row (Theme Clump Resolved)

private struct SprintCardRow: View {
    let index: Int
    let sprint: Sprint
    let isCopied: Bool
    let theme: PopoverTheme
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("#\(index)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(theme.neonTeal)
                .frame(width: 22, height: 22)
                .background(theme.neonTeal.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 4) {
                    Text(sprint.startLabel)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                    Text("→")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                    Text(sprint.endLabel)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                }

                HStack(spacing: 5) {
                    Text(sprint.hasPause ? "\(sprint.durationLabel) net" : sprint.durationLabel)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textSecondary)

                    if sprint.hasPause {
                        HStack(spacing: 2.5) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 6))
                            Text(TimeFormatter.format(shortDuration: sprint.pausedDuration))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())

                        Text("·")
                            .font(.system(size: 8))
                            .foregroundColor(theme.textSecondary.opacity(0.5))

                        Text("Copied: \(sprint.effectiveEndLabel)")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundColor(theme.textSecondary.opacity(0.8))
                    }
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isCopied ? .black : theme.neonTeal)
                        .frame(width: 22, height: 22)
                        .background(isCopied ? theme.neonTeal : theme.neonTeal.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(isCopied ? "Copied" : (sprint.hasPause ? "Actual end: \(sprint.endLabel) · Spreadsheet end: \(sprint.effectiveEndLabel) (\(sprint.pausedLabel) pause deducted)" : "Copy"))

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(theme.softRed.opacity(0.75))
                        .frame(width: 22, height: 22)
                        .background(theme.softRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Delete sprint")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(theme.cardBorder, lineWidth: 1))
    }
}

// MARK: - Settings Section View

private struct SettingsSectionView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @Binding var launchAtLogin: Bool
    @Bindable var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { vm.isSettingsExpanded.toggle() } }) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary)
                        Text("SETTINGS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                            .kerning(0.8)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .rotationEffect(.degrees(vm.isSettingsExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .focusable(false)

            if vm.isSettingsExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Theme")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Text(theme.isLight ? "Light Mode" : "Dark Mode")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(theme.textSecondary)
                        }

                        let themeColumns = [
                            GridItem(.flexible(), spacing: 5),
                            GridItem(.flexible(), spacing: 5),
                            GridItem(.flexible(), spacing: 5),
                            GridItem(.flexible(), spacing: 5)
                        ]

                        LazyVGrid(columns: themeColumns, spacing: 5) {
                            ForEach(AppTheme.allCases) { appTheme in
                                let isSelected = themeManager.current == appTheme
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        themeManager.current = appTheme
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(appTheme.theme.accentColor)
                                            .frame(width: 6.5, height: 6.5)

                                        Text(appTheme.displayName)
                                            .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                            .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5.5)
                                    .background(isSelected ? appTheme.theme.cardBg : theme.cardBg.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? appTheme.theme.accentColor : theme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                            }
                        }
                    }

                    Divider().background(theme.dividerColor)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Daily Goal")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Text(vm.goal.goalLabel)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.neonTeal)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(theme.neonTeal.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        Slider(value: $vm.goal.dailyGoalHours, in: 1...16, step: 0.5)
                            .tint(theme.neonTeal)
                            .controlSize(.small)
                            .focusable(false)
                        HStack {
                            Text("1h")
                            Spacer()
                            Text("16h")
                        }
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                    }

                    Divider().background(theme.dividerColor)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.textPrimary)
                            Text("Start Skeval Timer when you log in")
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(theme.neonTeal)
                            .focusable(false)
                            .onChange(of: launchAtLogin) { _, newValue in
                                AppDelegate.setLaunchAtLogin(newValue)
                            }
                    }

                    Divider().background(theme.dividerColor)

                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 10))
                            .foregroundColor(theme.textSecondary)
                        Text("Global hotkey:")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach(["⌘", "⌥", "⇧", "C"], id: \.self) { key in
                                Text(key)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(theme.textPrimary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(theme.cardBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.cardBorder, lineWidth: 1))
                            }
                        }
                    }

                    Divider().background(theme.dividerColor)

                    Button(action: { NSApp.terminate(nil) }) {
                        HStack {
                            Image(systemName: "power")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Quit Skeval Timer")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                            Spacer()
                            Text("⌘Q")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.textSecondary)
                        }
                        .foregroundColor(theme.softRed)
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Button Styles

private struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .focusable(false)
    }
}

private struct PillButtonStyle: ButtonStyle {
    let color: Color
    var foregroundColor: Color = .black
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .clipShape(Capsule())
            .focusable(false)
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    PopoverView(vm: TimerViewModel())
        .preferredColorScheme(.dark)
}
#endif
