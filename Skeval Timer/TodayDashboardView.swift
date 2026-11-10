import SwiftUI

struct TodayDashboardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    let openSettings: () -> Void
    @AppStorage("skevalTodayShowingTimeline") private var showingTimeline = true
    @State private var temporaryTimelineHours: TimelineHours?
    @State private var contentWidth: CGFloat = 780
    private static let twoColumnMinWidth: CGFloat = 660

    private var dateSelection: Binding<Date> {
        Binding(get: { vm.selectedDate }, set: { vm.selectDate($0) })
    }
    private var tags: [String] {
        vm.displayedCompletedSprints.distinctTags
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dateNavigation
                Live { summary }
                historyHeader
                if showingTimeline {
                    DailyTimelineView(vm: vm, theme: theme, temporaryHours: $temporaryTimelineHours)
                } else {
                    SprintLogTableView(vm: vm, sprints: vm.displayedCompletedSprintsDescending.map(\.sprint),
                                       distinctTags: tags, defaultDate: vm.selectedDate,
                                       theme: theme, title: "", usesTimesheetStyle: true)
                }
            }
            .padding(20)
            .foregroundStyle(theme.textPrimary)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        .onChange(of: Calendar.current.startOfDay(for: vm.selectedDate)) {
            temporaryTimelineHours = nil
        }
    }

    // MARK: Summary

    @ViewBuilder private var summary: some View {
        if contentWidth >= Self.twoColumnMinWidth {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    workTimeCard
                    earningsCard
                    if vm.isViewingToday { sprintTag }
                }
                .frame(width: 260)
                DailyGoalCardView(vm: vm, theme: theme)
            }
        } else {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) { workTimeCard; earningsCard }
                DailyGoalCardView(vm: vm, theme: theme)
                if vm.isViewingToday { sprintTag }
            }
        }
    }

    private var workTimeCard: some View {
        MetricCardView(title: "WORK TIME", value: vm.displayedTotalShortLabel,
                       subtitle: vm.isViewingToday ? "Includes the active sprint" : "Completed sprints",
                       icon: "clock", theme: theme)
    }

    private var earningsCard: some View {
        MetricCardView(title: "EARNINGS", value: vm.displayedEarningsLabel,
                       subtitle: vm.goal.hasHourlyRate ? "\(vm.goal.hourlyRateLabel) per hour" : "",
                       icon: "banknote", theme: theme,
                       actionTitle: vm.goal.hasHourlyRate ? nil : "Set hourly rate",
                       action: vm.goal.hasHourlyRate ? nil : openSettings)
    }

    private var historyHeader: some View {
        HStack(spacing: 12) {
            Text("\(vm.selectedDayShortTitle)'s sprints").font(.headline)
            Spacer()
            Picker("Sprint view", selection: $showingTimeline) {
                Text("Timeline").tag(true)
                Text("List").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 200)
            Button(vm.isAllCopied ? "Copied" : "Copy all", systemImage: vm.isAllCopied ? "checkmark" : "doc.on.doc") {
                vm.copyAllDisplayedSprints()
            }
            .disabled(vm.displayedCompletedSprints.isEmpty)
            .accessibilityHint(Self.copyAllHelp)
            .help(Self.copyAllHelp)
        }
    }

    private static let copyAllHelp = "Copy this day's Login, Logout, blank Lunch, and Break (whole minutes) as one spreadsheet row. Break includes pauses and gaps between completed sprints."

    private var dateNavigation: some View {
        HStack(spacing: 12) {
            Button { moveDay(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous day")
                .keyboardShortcut("[", modifiers: .command)
                .help("Previous day, Command [")
            CalendarDatePicker(title: "Day to review", selection: dateSelection, theme: theme,
                               allowedRange: Date.distantPast...Date())
                .font(.subheadline.weight(.medium))
            Button { moveDay(1) } label: { Image(systemName: "chevron.right") }
                .disabled(vm.isViewingToday)
                .accessibilityLabel("Next day")
                .keyboardShortcut("]", modifiers: .command)
                .help("Next day, Command ]")
            if !vm.isViewingToday {
                Button("Back to today") { vm.jumpToToday() }
                    .keyboardShortcut("t", modifiers: [.command, .option])
                    .help("Back to today, Command Option T")
            }
            Spacer()
            Text(vm.headerDateSubtitle).font(.subheadline).foregroundStyle(theme.textSecondary)
        }
        .controlSize(.large)
    }

    private var sprintTag: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(vm.isRunning ? "Sprint tag" : "Next sprint tag", systemImage: "tag")
                .font(.caption.weight(.bold)).foregroundStyle(theme.textSecondary)
            TextField("Optional project or client", text: tagBinding)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(vm.isRunning ? "Current sprint tag" : "Next sprint tag")
            if vm.isPaused {
                Text("Paused for \(vm.currentPauseLabel)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(theme.warningText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
    }

    private var tagBinding: Binding<String> {
        Binding(get: { vm.isRunning ? vm.currentTag ?? "" : vm.pendingTag },
                set: { if vm.isRunning { vm.setTag($0) } else { vm.pendingTag = $0 } })
    }

    private func moveDay(_ offset: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: vm.selectedDate) else { return }
        vm.selectDate(date)
    }
}
