import SwiftUI

struct TodayDashboardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    let openSettings: () -> Void

    private var dateSelection: Binding<Date> {
        Binding(get: { vm.selectedDate }, set: { vm.selectDate($0) })
    }
    private var tags: [String] {
        Array(Set(vm.displayedCompletedSprints.compactMap(\.tag))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dateNavigation
                if vm.isViewingToday { sprintTag }
                metrics
                dailyGoal
                if vm.isViewingToday {
                    CatchUpCardView(summary: vm.catchUpSummary(for: .week),
                                    dailyGoalLabel: vm.goal.goalLabel, theme: theme)
                }
                if !vm.goal.hasHourlyRate {
                    HStack {
                        Label("Set your hourly rate to track earnings.", systemImage: "banknote")
                        Spacer()
                        Button("Set hourly rate", action: openSettings)
                    }
                    .font(.subheadline).padding(16)
                    .background(theme.cardBg).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                HStack {
                    Text("\(vm.selectedDayShortTitle)'s sprints").font(.headline)
                    Spacer()
                    Button(vm.isAllCopied ? "Copied" : "Copy all", systemImage: vm.isAllCopied ? "checkmark" : "doc.on.doc") {
                        vm.copyAllDisplayedSprints()
                    }
                    .disabled(vm.displayedCompletedSprints.isEmpty)
                    .help("Copy this day's Login, Logout, blank Lunch, and Break (whole minutes) as one spreadsheet row. Break includes pauses and gaps between completed sprints.")
                }
                SprintLogTableView(vm: vm, sprints: vm.displayedCompletedSprintsDescending.map(\.sprint),
                                   distinctTags: tags, defaultDate: vm.selectedDate,
                                   theme: theme, title: "SPRINT HISTORY")
            }
            .padding(20)
            .foregroundStyle(theme.textPrimary)
        }
    }

    private var dateNavigation: some View {
        HStack(spacing: 12) {
            Button { moveDay(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous day")
                .help("Previous day")
            DatePicker("Review day", selection: dateSelection, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .accessibilityLabel("Day to review")
            Button { moveDay(1) } label: { Image(systemName: "chevron.right") }
                .disabled(vm.isViewingToday)
                .accessibilityLabel("Next day")
                .help("Next day")
            if !vm.isViewingToday {
                Button("Back to today") { vm.jumpToToday() }
            }
            Spacer()
            Text(vm.headerDateSubtitle).font(.subheadline).foregroundStyle(theme.textSecondary)
        }
        .controlSize(.large)
    }

    private var sprintTag: some View {
        HStack(spacing: 12) {
            Label(vm.isRunning ? "Sprint tag" : "Next sprint tag", systemImage: "tag")
            TextField("Optional project or client", text: tagBinding)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(vm.isRunning ? "Current sprint tag" : "Next sprint tag")
                .frame(maxWidth: 260)
            Spacer()
            if vm.isPaused {
                Text("Paused for \(vm.currentPauseLabel)")
                    .font(.system(.subheadline, design: .monospaced))
            }
        }
        .font(.subheadline)
    }

    private var tagBinding: Binding<String> {
        Binding(get: { vm.isRunning ? vm.currentTag ?? "" : vm.pendingTag },
                set: { if vm.isRunning { vm.setTag($0) } else { vm.pendingTag = $0 } })
    }

    private var metrics: some View {
        HStack(spacing: 16) {
            MetricCardView(title: "WORK TIME", value: vm.displayedTotalShortLabel,
                           subtitle: vm.isViewingToday ? "Includes the active sprint" : "Completed sprints",
                           icon: "clock", theme: theme)
            MetricCardView(title: "EARNINGS", value: vm.displayedEarningsLabel,
                           subtitle: vm.goal.hasHourlyRate ? "\(vm.goal.hourlyRateLabel) per hour" : "Set your hourly rate",
                           icon: "banknote", theme: theme)
            MetricCardView(title: "DAILY TARGET", value: vm.goal.goalLabel,
                           subtitle: vm.goal.hasHourlyRate ? vm.targetEarningsLabel : "Your daily work goal",
                           icon: "target", theme: theme)
        }
        .accessibilityElement(children: .contain)
    }

    private var dailyGoal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(vm.displayedGoalTitle).font(.headline)
                Spacer()
                Text(vm.displayedProgressLabel).font(.subheadline).monospacedDigit()
            }
            ProgressView(value: vm.displayedProgressFraction)
                .tint(theme.neonTeal)
                .accessibilityLabel("Daily goal progress")
                .accessibilityValue("\(Int(vm.displayedProgressFraction * 100)) percent")
            Text(vm.isDisplayedGoalReached ? "Daily goal reached" : "\(TimeFormatter.format(shortDuration: max(0, vm.goal.dailyGoalSeconds - vm.displayedAccumulatedTotal))) remaining")
                .font(.subheadline).foregroundStyle(theme.textSecondary)
        }
        .padding(18).background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func moveDay(_ offset: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: vm.selectedDate) else { return }
        vm.selectDate(date)
    }
}
