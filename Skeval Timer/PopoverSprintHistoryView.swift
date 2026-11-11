import SwiftUI

struct PopoverSprintHistoryView: View {
    let vm: TimerViewModel
    let theme: PopoverTheme
    @State private var pendingDelete: Sprint?
    @State private var isConfirmingDelete = false
    @State private var deletedSprint: Sprint?
    @State private var detailSprint: Sprint?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PopoverSectionTitle("Recent sprints", systemImage: "clock.arrow.circlepath", theme: theme)
                Spacer(minLength: 4)
                datePicker
            }
            if vm.displayedCompletedSprints.isEmpty {
                HStack(spacing: 10) {
                    ThemeArtView(art: .mug, theme: theme, size: 52)
                    Text("No completed sprints for this day. Add a sprint you already finished, or clock in to start.")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.displayedCompletedSprintsDescending.prefix(2)), id: \.sprint.id) { item in
                        sprintRow(item.sprint)
                        if item.sprint.id != vm.displayedCompletedSprintsDescending.prefix(2).last?.sprint.id {
                            Divider().overlay(theme.cardBorder)
                        }
                    }
                }
            }
            if !vm.isViewingToday {
                PopoverTimesheetCopyButton(vm: vm, date: vm.selectedDate, theme: theme)
            }
            if let deletedSprint {
                HStack {
                    Text("Sprint deleted").foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button("Undo") {
                        vm.restoreDeletedSprint(deletedSprint)
                        self.deletedSprint = nil
                    }
                    .buttonStyle(PopoverLinkButtonStyle(color: theme.accentText))
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            HStack {
                Button { vm.openManualEntry() } label: {
                    Label("Add sprint", systemImage: "plus.circle.fill")
                }
                .help("Add a completed sprint for \(vm.selectedDayShortTitle.lowercased())")
                Spacer()
                Button(action: AppDelegate.openDashboard) {
                    Label("All history", systemImage: "arrow.up.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
            }
            .buttonStyle(PopoverLinkButtonStyle(color: theme.accentText))
            .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .themedCard(theme, padding: 14, radius: 12)
        .alert("Delete this sprint?", isPresented: $isConfirmingDelete, presenting: pendingDelete) { sprint in
            Button("Keep sprint", role: .cancel) { }
            Button("Delete sprint", role: .destructive) {
                vm.delete(sprint: sprint)
                deletedSprint = sprint
            }
        } message: { sprint in
            Text("This removes the \(sprint.startDisplayLabel) to \(sprint.endDisplayLabel) sprint from \(TimeFormatter.format(shortDayTitle: sprint.startTime)). It contains \(sprint.durationDisplayLabel) of net work.")
        }
        .popover(item: $detailSprint) { sprint in
            sprintDetails(sprint)
        }
    }

    private var datePicker: some View {
        Menu {
            ForEach(vm.availablePastDates, id: \.self) { date in
                Button { vm.selectDate(date) } label: {
                    if Calendar.current.isDate(date, inSameDayAs: vm.selectedDate) {
                        Label(vm.menuItemTitle(for: date), systemImage: "checkmark")
                    } else {
                        Text(vm.menuItemTitle(for: date))
                    }
                }
            }
        } label: {
            PopoverChipLabel(title: vm.selectedDayShortTitle, theme: theme, highlighted: !vm.isViewingToday)
        }
        .popoverMenuStyle()
        .accessibilityLabel("History date")
        .help("Change the history date. Timer controls and today's totals stay on Today.")
    }

    private func sprintRow(_ sprint: Sprint) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(sprint.startDisplayLabel) – \(sprint.endDisplayLabel)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    if let tag = sprint.tag {
                        Text(tag)
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.accentText)
                            .padding(.horizontal, 6).padding(.vertical, 1.5)
                            .background(theme.accentColor.opacity(0.15), in: Capsule())
                            .lineLimit(1)
                    }
                }
                Text(sprint.hasPause ? "\(sprint.durationDisplayLabel) net · \(sprint.pausedDisplayLabel) paused" : "\(sprint.durationDisplayLabel) net")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(theme.textSecondary)
                if vm.lastCopiedId == sprint.id {
                    Text("Copied sprint times").font(.caption).foregroundStyle(theme.successText)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Menu {
                Button("Sprint details") { detailSprint = sprint }
                Button("Copy sprint times") { vm.copy(sprint: sprint) }
                Divider()
                Button("Delete sprint…", role: .destructive) {
                    pendingDelete = sprint
                    isConfirmingDelete = true
                }
            } label: {
                PopoverMoreIcon(theme: theme)
            }
            .popoverMenuStyle()
            .accessibilityLabel("Actions for sprint starting \(sprint.startDisplayLabel)")
        }
        .padding(.vertical, 10)
    }

    private func sprintDetails(_ sprint: Sprint) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sprint details").font(.headline)
            Text(TimeFormatter.format(relativeHeaderDate: sprint.startTime))
                .font(.caption).foregroundStyle(theme.textSecondary)
            LabeledContent("Start", value: sprint.startLabel)
            LabeledContent("Actual end", value: sprint.endLabel)
            LabeledContent("Paused", value: sprint.pausedLabel)
            LabeledContent("Net work", value: sprint.durationLabel)
            LabeledContent("Effective end", value: sprint.effectiveEndLabel)
            if let tag = sprint.tag { LabeledContent("Tag", value: tag) }
            Text("Individual sprint copy uses the effective end. The daily timesheet uses the actual Logout.")
                .font(.caption).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Done") { detailSprint = nil }
                .keyboardShortcut(.cancelAction)
        }
        .font(.system(size: 12)).monospacedDigit()
        .padding(16).frame(width: 300)
        .foregroundStyle(theme.textPrimary).background(theme.bgDark)
        .themeAppearance(theme)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.title
            configuration.icon.font(.system(size: 9, weight: .bold))
        }
    }
}
