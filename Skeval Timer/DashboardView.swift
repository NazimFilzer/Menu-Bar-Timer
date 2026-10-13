import SwiftUI

enum DashboardDestination: String, CaseIterable, Identifiable {
    case today, week, month, analytics, settings

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .today: return "clock"
        case .week: return "calendar"
        case .month: return "calendar.badge.clock"
        case .analytics: return "chart.xyaxis.line"
        case .settings: return "gearshape"
        }
    }
    var subtitle: String {
        switch self {
        case .today: return "Your timer, earnings, and daily sprint history"
        case .week: return "Weekly goals and daily work patterns"
        case .month: return "Monthly totals and time by tag"
        case .analytics: return "Trends, date ranges, and CSV reports"
        case .settings: return "Goals, hourly rate, currency, and appearance"
        }
    }
    var shortcut: KeyEquivalent {
        KeyEquivalent(Character(String(Self.allCases.firstIndex(of: self)! + 1)))
    }
}

struct DashboardView: View {
    @Bindable var vm: TimerViewModel
    @AppStorage("skevalDashboardDestination") private var destinationKey = DashboardDestination.today.rawValue
    @State private var themeManager = ThemeManager.shared

    private var theme: PopoverTheme { themeManager.theme }
    private var destination: DashboardDestination {
        DashboardDestination(rawValue: destinationKey) ?? .today
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 195, max: 230)
        } detail: {
            VStack(spacing: 0) {
                DashboardToolbar(vm: vm, destination: destination, theme: theme)
                Divider()
                DashboardResolutionView(vm: vm)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(theme.bgDark)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(theme.neonTeal)
        .preferredColorScheme(theme.isLight ? .light : .dark)
        .onAppear { vm.checkAndHandleDayChange(); vm.refreshLogs() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Skeval Timer")
                .font(.title3.bold())
                .padding(.horizontal, 18)
                .padding(.top, 24)
            Text("Work and earnings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 20)

            List {
                ForEach(DashboardDestination.allCases) { item in
                    Button {
                        destinationKey = item.rawValue
                    } label: {
                        HStack(spacing: 10) {
                            Label(item.title, systemImage: item.icon)
                                .font(.system(size: 14, weight: destination == item ? .semibold : .regular))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer()
                        }
                        .foregroundStyle(destination == item ? theme.textPrimary : theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(destination == item ? theme.neonTeal.opacity(0.16) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(item.shortcut, modifiers: .command)
                    .accessibilityAddTraits(destination == item ? .isSelected : [])
                    .help("Open \(item.title), Command \(String(item.shortcut.character))")
                    .listRowInsets(EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6))
                }
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard shortcuts").font(.caption.bold())
                Text("⌘1–5  Switch views\n⌘N  Add sprint\n⌘⌥⇧C  Clock in / out\n⌘⌥⇧P  Pause / resume")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                Text(AppVersion.current).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .background(theme.cardBg)
    }

    @ViewBuilder private var content: some View {
        switch destination {
        case .today:
            TodayDashboardView(vm: vm, theme: theme) { destinationKey = DashboardDestination.settings.rawValue }
        case .week:
            ScrollView { WeeklyDashboardView(vm: vm, theme: theme).padding(20) }
        case .month:
            ScrollView { MonthlyDashboardView(vm: vm, theme: theme).padding(20) }
        case .analytics:
            AnalyticsDashboardView(vm: vm, theme: theme)
        case .settings:
            DashboardSettingsView(vm: vm, theme: theme)
        }
    }
}

private struct DashboardToolbar: View {
    @Bindable var vm: TimerViewModel
    let destination: DashboardDestination
    let theme: PopoverTheme

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(destination.title).font(.title2.bold()).foregroundStyle(theme.textPrimary)
                Text(destination.subtitle).font(.subheadline).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(vm.statusTitle.capitalized).font(.caption.bold()).foregroundStyle(theme.statusColor(for: vm.state))
                Text(vm.currentElapsedLabel).font(.system(.body, design: .monospaced)).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            if vm.isRunning {
                Button(vm.isPaused ? "Resume" : "Pause", systemImage: vm.isPaused ? "play.fill" : "pause.fill") {
                    if vm.isPaused { vm.resumeTimer() } else { vm.pause() }
                }
                .disabled(vm.hasPendingSleepResolution)
                .help("Pause or resume, Command Option Shift P")
            }
            Button(vm.isRunning ? "Clock out" : "Clock in", systemImage: vm.isRunning ? "stop.fill" : "play.fill") {
                if vm.isRunning { vm.clockOut() } else { vm.clockIn() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.recoveryMode || vm.hasPendingSleepResolution)
            .help("Clock in or out, Command Option Shift C")
        }
        .controlSize(.large)
        .padding(20)
        .background(theme.cardBg)
    }
}

private struct DashboardResolutionView: View {
    @Bindable var vm: TimerViewModel

    var body: some View {
        if vm.recoveryMode {
            VStack(alignment: .leading, spacing: 10) {
                Text("Finish or resume your recovered sprint").font(.headline)
                HStack {
                    TextField("End time, HH:mm:ss", text: $vm.recoveryEndText)
                        .textFieldStyle(.roundedBorder).frame(width: 190)
                        .accessibilityLabel("Recovered sprint end time")
                    Button("Save end time") { vm.saveRecoveryEndTime() }
                    Button("Resume sprint") { vm.resumeRecovery() }
                }
                if let error = vm.recoveryEndError { Text(error).foregroundStyle(.red) }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
        } else if let interval = vm.pendingSleepInterval {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Mac was asleep from \(interval.formattedWindow)").font(.headline)
                Text("The timer is held. Choose how to record these \(interval.formattedDuration).")
                HStack {
                    Button("Count as work") { vm.resolveSleep(countAsWork: true) }
                    Button("Count as paused") { vm.resolveSleep(countAsWork: false) }
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.indigo.opacity(0.12))
        }
    }
}
