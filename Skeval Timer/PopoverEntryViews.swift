import SwiftUI

// Existing recovery and manual-entry flows, shared by the compact popover.

struct RecoveryBannerView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Label("Unfinished sprint from \(vm.currentSprint?.startDisplayLabel ?? "")",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.warningText)
                if let sprint = vm.currentSprint, sprint.hasPause {
                    Text("(\(sprint.pausedDisplayLabel) paused)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }
            }

            RecoveryDatePicker(selection: $vm.recoveryEndDate, theme: theme)
                .font(.caption)

            HStack(spacing: 8) {
                Button {
                    vm.resumeRecovery()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(PillButtonStyle(color: theme.accentColor, foregroundColor: theme.actionButtonForeground))

                TextField("HH:mm:ss", text: $vm.recoveryEndText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Recovery end time")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 72)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(theme.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.5), lineWidth: 1))

                Button("Set end time") {
                    vm.saveRecoveryEndTime()
                }
                .buttonStyle(PillButtonStyle(color: theme.cardBg, foregroundColor: theme.textPrimary, border: theme.cardBorder))

            }

            if let err = vm.recoveryEndError {
                Text(err)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.dangerText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.warningText.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Sleep Resolution Banner View

struct SleepResolutionBannerView: View {
    @Bindable var vm: TimerViewModel
    let interval: SleepInterval
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "powersleep")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.textPrimary)

                Text("Mac was asleep: \(interval.formattedWindow)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Text(interval.formattedDuration)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.indigo.opacity(0.2))
                    .foregroundColor(theme.textPrimary)
                    .clipShape(Capsule())
            }

            Text("Your choice also includes time until you decide.")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(theme.textSecondary)

            HStack(spacing: 8) {
                Button(action: {
                    vm.resolveSleep(countAsWork: true)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 9))
                        Text("Count as Work")
                    }
                }
                .buttonStyle(PillButtonStyle(color: theme.accentColor, foregroundColor: theme.actionButtonForeground))

                Button(action: {
                    vm.resolveSleep(countAsWork: false)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 9))
                        Text("Count as Paused")
                    }
                }
                .buttonStyle(PillButtonStyle(color: theme.cardBg, foregroundColor: theme.textPrimary, border: theme.cardBorder))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.indigo.opacity(0.35), lineWidth: 1))
    }
}

struct PillButtonStyle: ButtonStyle {
    let color: Color
    var foregroundColor: Color = .black
    var border: Color = .clear
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.45)
    }
}

// MARK: - Manual Sprint Sheet View (Type C Native Modal)

struct ManualSprintSheetView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    private var earningsDeltaColor: Color {
        theme.successText
    }

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.accentIcon)
                    Text("Add sprint · \(vm.selectedDayShortTitle)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        }

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.dismissManualEntry()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(theme.textSecondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            QuickSlotPickerView(theme: theme) { vm.fillManualQuickSlot(minutes: $0) }
                .frame(maxWidth: .infinity, alignment: .leading)

            DualClockTimePickerView(
                startTime: $vm.manualStartDate,
                endTime: $vm.manualEndDate,
                theme: theme
            )

            VStack(spacing: 7) {
                HStack {
                    Text("BREAK")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 44, alignment: .leading)

                    Spacer()

                    HStack(spacing: 4) {
                        TextField("0", text: $vm.manualBreakMinutesText)
                            .accessibilityLabel("Break minutes")
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(width: 36)
                            .padding(.vertical, 3)
                            .background(theme.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.cardBorder, lineWidth: 1))

                        Text("mins pause")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .padding(8)
            .background(theme.cardBg.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))

            TextField("Optional project or client tag", text: $vm.manualTagText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(theme.textPrimary)
                .padding(8)
                .background(theme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.cardBorder, lineWidth: 1))
                .environment(\.colorScheme, theme.isLight ? .light : .dark)
                .accessibilityLabel("Manual sprint tag")

            if let netDuration = vm.manualComputedNetDuration {
                HStack {
                    HStack(spacing: 4) {
                        Text("Net:")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                        Text(TimeFormatter.format(clock: netDuration))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(earningsDeltaColor)
                    }

                    Spacer()

                    if vm.goal.hasHourlyRate {
                        Text("+\(EarningsCalculator.format(amount: vm.manualComputedEarningsDelta, currencySymbol: vm.goal.currencySymbol))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(earningsDeltaColor)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(earningsDeltaColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(earningsDeltaColor.opacity(0.25), lineWidth: 1))
            } else if let error = vm.manualEntryError {
                Text(error)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.dangerText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            HStack(spacing: 8) {
                Button("Cancel") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.dismissManualEntry()
                    }
                }
                .buttonStyle(PillButtonStyle(color: theme.cardBg, foregroundColor: theme.textSecondary))
                .keyboardShortcut(.cancelAction)
                .frame(maxWidth: .infinity)

                Button("Log Sprint") {
                    guard vm.confirmManualSprintOverlaps() else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        _ = vm.saveManualSprint()
                    }
                }
                .buttonStyle(PillButtonStyle(color: theme.accentColor, foregroundColor: theme.actionButtonForeground))
                .frame(maxWidth: .infinity)
                .disabled(vm.manualComputedNetDuration == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(theme.bgDark)
        .foregroundStyle(theme.textPrimary)
        .themeAppearance(theme)
    }
}
