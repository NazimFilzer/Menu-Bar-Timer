import SwiftUI

/// Today page: the day navigator, the Worked card beside the finish forecast, then one sprint card
/// that owns the timeline or list, the sprint tag, and every sprint action.
struct TodayDashboardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    let openSettings: () -> Void
    @AppStorage("skevalTodayShowingTimeline") private var showingTimeline = true
    @State private var temporaryTimelineHours: TimelineHours?
    @State private var contentWidth: CGFloat = 780
    @State private var showingAddSprint = false
    @State private var showingHours = false
    @State private var exportError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let twoColumnMinWidth: CGFloat = 660

    private var dateSelection: Binding<Date> {
        Binding(get: { vm.selectedDate }, set: { vm.selectDate($0) })
    }

    var body: some View {
        ScrollViewReader { page in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    dateNavigation
                    summary
                    sprintCard(page)
                }
                .padding(20)
                .foregroundStyle(theme.textPrimary)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        .onChange(of: Calendar.current.startOfDay(for: vm.selectedDate)) {
            temporaryTimelineHours = nil
        }
        .sheet(isPresented: $showingAddSprint) {
            AddSprintModalView(vm: vm, theme: theme, defaultDate: vm.selectedDate,
                               onDismiss: { showingAddSprint = false })
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(exportError ?? "") }
    }

    // MARK: Navigator

    private var dateNavigation: some View {
        DashboardPeriodNavigator(periodName: "day", canGoForward: !vm.isViewingToday,
                                 resetTitle: vm.isViewingToday ? nil : "Today",
                                 resetShortcut: KeyboardShortcut("t", modifiers: [.command, .option]), theme: theme,
                                 move: moveDay, reset: { vm.jumpToToday() }) {
            CalendarDatePicker(title: "Day to review", selection: dateSelection, theme: theme,
                               allowedRange: Date.distantPast...Date())
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
    }

    private func moveDay(_ offset: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: vm.selectedDate) else { return }
        vm.selectDate(date)
    }

    // MARK: Summary

    @ViewBuilder private var summary: some View {
        if contentWidth >= Self.twoColumnMinWidth {
            HStack(alignment: .top, spacing: 16) {
                Live { workedCard }
                    .frame(width: 280)
                Live { DailyGoalCardView(vm: vm, theme: theme) }
            }
            // Both cards take the taller card's height.
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: 16) {
                Live { workedCard }
                Live { DailyGoalCardView(vm: vm, theme: theme) }
            }
        }
    }

    private var workedCard: some View {
        let reached = vm.isDisplayedGoalReached
        let worked = vm.displayedAccumulatedTotal
        let goal = vm.goal.dailyGoalSeconds
        return VStack(alignment: .leading, spacing: 12) {
            DashboardCardHeader(title: "Worked", icon: "clock.fill", theme: theme)
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.displayedTotalShortLabel)
                    .font(.dashboardHero)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("of \(vm.goal.goalLabel) daily goal")
                    .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
            }
            if vm.goal.hasHourlyRate {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(vm.displayedEarningsLabel)
                        .font(.dashboardMoney).foregroundStyle(theme.successText)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("at \(vm.goal.hourlyRateLabel)/h")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            } else {
                Button("Set hourly rate", action: openSettings)
                    .buttonStyle(.link)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            VStack(alignment: .leading, spacing: 6) {
                DashboardProgressBar(fraction: vm.displayedProgressFraction, isComplete: reached,
                                     theme: theme, accessibilityTitle: "Daily goal")
                HStack {
                    Text(progressCaption(worked: worked, goal: goal, reached: reached))
                        .foregroundStyle(reached ? theme.successText : theme.textSecondary)
                    Spacer()
                    Text("\(vm.displayedProgressPercent)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(reached ? theme.successText : theme.accentText)
                }
                .font(.dashboardCaption)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private func progressCaption(worked: TimeInterval, goal: TimeInterval, reached: Bool) -> String {
        if reached { return "Daily goal reached" }
        let left = TimeFormatter.format(shortDuration: max(0, goal - worked))
        return vm.isViewingToday ? "\(left) left" : "\(left) short"
    }

    // MARK: Sprints

    private func sprintCard(_ page: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardCardHeader(title: vm.sprintsSectionTitle, icon: "list.bullet.rectangle", theme: theme) {
                sprintActions(page)
            }
            if showingTimeline {
                DailyTimelineView(vm: vm, theme: theme, temporaryHours: $temporaryTimelineHours)
            } else {
                SprintLogTableView(vm: vm, sprints: vm.displayedCompletedSprintsDescending.map(\.sprint),
                                   distinctTags: vm.displayedCompletedSprints.distinctTags,
                                   defaultDate: vm.selectedDate, theme: theme, title: "",
                                   usesTimesheetStyle: true, isEmbedded: true)
            }
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private func sprintActions(_ page: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            if vm.isViewingToday { SprintTagChip(vm: vm, theme: theme) }
            Picker("Sprint view", selection: $showingTimeline) {
                Text("Timeline").tag(true)
                Text("List").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
            Button(vm.isAllCopied ? "Copied" : "Copy all", systemImage: vm.isAllCopied ? "checkmark" : "doc.on.doc") {
                vm.copyAllDisplayedSprints()
            }
            .disabled(vm.displayedCompletedSprints.isEmpty)
            .accessibilityHint(Self.copyAllHelp)
            .help(Self.copyAllHelp)
            Button("Add sprint", systemImage: "plus") { showingAddSprint = true }
                .keyboardShortcut("n", modifiers: .command)
                .help("Add a completed sprint to \(vm.selectedDayShortTitle.lowercased()), Command N")
            moreMenu(page)
        }
        .controlSize(.small)
    }

    private func moreMenu(_ page: ScrollViewProxy) -> some View {
        Menu {
            if showingTimeline {
                Button("Visible hours…") { showingHours = true }
                if vm.isViewingToday {
                    Button("Scroll to now") {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                            page.scrollTo(DailyTimelineView.nowAnchor, anchor: .center)
                        }
                    }
                }
                Divider()
            }
            Button("Export CSV…") { exportDay() }
                .disabled(vm.displayedCompletedSprints.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More sprint actions")
        .help("Visible hours, scroll to now, and CSV export")
        .popover(isPresented: $showingHours, arrowEdge: .bottom) {
            TimelineHoursEditor(vm: vm, temporaryHours: $temporaryTimelineHours, theme: theme)
        }
    }

    private func exportDay() {
        let day = TimeFormatter.format(dateKey: vm.selectedDate, calendar: .current)
        CSVExporter.promptSavePanel(sprints: vm.displayedCompletedSprints,
                                    suggestedName: "skeval-sprints-\(day).csv",
                                    profileName: vm.activeProfileName,
                                    onFailure: { exportError = $0 })
    }

    private static let copyAllHelp = "Copy this day's Login, Logout, blank Lunch, and Break (whole minutes) as one spreadsheet row. Break includes pauses and gaps between completed sprints."
}

/// The running or next sprint's tag, as a chip in the sprint card header. Click to edit it.
private struct SprintTagChip: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @State private var editing = false

    private var tag: String {
        (vm.isRunning ? vm.currentTag ?? "" : vm.pendingTag).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var subject: String { vm.isRunning ? "Sprint tag" : "Next sprint tag" }

    var body: some View {
        Button { editing = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "tag.fill").font(.system(size: 9, weight: .bold))
                Text(tag.isEmpty ? (vm.isRunning ? "Tag sprint" : "Tag next sprint") : "#\(tag)")
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tag.isEmpty ? theme.textSecondary : theme.accentText)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tag.isEmpty ? Color.clear : theme.accentColor.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(tag.isEmpty ? theme.cardBorder : theme.accentColor.opacity(0.35),
                                      style: StrokeStyle(lineWidth: 1, dash: tag.isEmpty ? [3, 2] : [])))
            .frame(maxWidth: 180)
            .fixedSize()
        }
        .buttonStyle(.plain)
        .help(vm.isRunning ? "Tag the running sprint with a project or client" : "Tag the next sprint you clock in")
        .accessibilityLabel(tag.isEmpty ? subject : "\(subject), \(tag)")
        .accessibilityHint("Edit the tag")
        .popover(isPresented: $editing, arrowEdge: .bottom) { editor }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(subject).font(.headline)
            TextField("Optional project or client", text: binding)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { editing = false }
                .accessibilityLabel(vm.isRunning ? "Current sprint tag" : "Next sprint tag")
            HStack {
                Button("Clear") { binding.wrappedValue = "" }
                    .disabled(tag.isEmpty)
                Spacer()
                Button("Done") { editing = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }

    private var binding: Binding<String> {
        Binding(get: { vm.isRunning ? vm.currentTag ?? "" : vm.pendingTag },
                set: { if vm.isRunning { vm.setTag($0) } else { vm.pendingTag = $0 } })
    }
}
