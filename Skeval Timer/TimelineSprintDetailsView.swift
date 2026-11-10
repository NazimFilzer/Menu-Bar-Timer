import SwiftUI

struct TimelineSprintDetailsView: View {
    @Bindable var vm: TimerViewModel
    let sprintID: UUID
    let theme: PopoverTheme
    @Environment(\.dismiss) private var dismiss
    @State private var editingSprint: Sprint?
    @State private var showingRecoveryEnd = false

    private var segment: TimelineSegment? {
        // The details sheet shows seconds, so it follows the 1-second tick (the timeline does not).
        _ = vm.currentElapsed
        _ = vm.currentPauseElapsed
        return vm.dailyTimeline().segments.first { $0.id == sprintID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Sprint details").font(.title2.bold())
                Spacer()
                Button("Close") { dismiss() }
            }
            if let segment {
                details(segment)
            } else {
                Text("This sprint is no longer on the selected day.")
            }
        }
        .padding(24).frame(width: 460)
        .foregroundStyle(theme.textPrimary).background(theme.cardBg)
        .sheet(item: $editingSprint) { sprint in
            EditSprintModalView(sprint: sprint, vm: vm, theme: theme, onDismiss: { editingSprint = nil })
        }
    }

    private func details(_ segment: TimelineSegment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(segment.displayName).font(.headline)
            Text(segment.status.rawValue).foregroundStyle(theme.accentText)
            Text("Start: \(segment.sprint.startTime.formatted(date: .abbreviated, time: .standard))")
            Text("End: \(segment.sprint.endTime?.formatted(date: .abbreviated, time: .standard) ?? "Open")")
            if let work = segment.netWork {
                Text("Work: \(TimeFormatter.format(duration: work))")
            } else { Text("Work time is unresolved.") }
            Text("Paused: \(TimeFormatter.format(duration: segment.paused))")
            Text("Completed pause times are not available.")
                .font(.caption).foregroundStyle(theme.textSecondary)
            if segment.continuesBefore || segment.continuesAfter {
                Text("This sprint's work counts on \(segment.sprint.startTime.formatted(date: .abbreviated, time: .omitted)).")
            }
            actions(segment)
        }
    }

    @ViewBuilder
    private func actions(_ segment: TimelineSegment) -> some View {
        switch segment.status {
        case .completed:
            Button("Edit", systemImage: "pencil") { editingSprint = segment.sprint }
        case .sleep:
            Text("The marked time awaits your choice.").font(.caption)
            HStack {
                Button("Count as Work") { vm.resolveSleep(countAsWork: true) }
                Button("Count as Paused") { vm.resolveSleep(countAsWork: false) }
            }.disabled(!vm.hasPendingSleepResolution)
        case .recovery:
            HStack {
                Button("Resume") { vm.resumeRecovery() }
                Button("Set End Time") { showingRecoveryEnd = true }
            }
            if showingRecoveryEnd { recoveryEndForm }
        case .active, .paused:
            TextField("Sprint tag", text: Binding(get: { vm.currentTag ?? "" }, set: { vm.setTag($0) }))
                .textFieldStyle(.roundedBorder)
            if segment.status == .paused {
                Button("Resume") { vm.resumeTimer() }
            } else {
                Button("Pause") { vm.pause() }
            }
        }
    }

    private var recoveryEndForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            RecoveryDatePicker(selection: $vm.recoveryEndDate, theme: theme)
            TextField("End time, HH:mm or HH:mm:ss", text: $vm.recoveryEndText)
                .textFieldStyle(.roundedBorder)
            if let error = vm.recoveryEndError { Text(error).foregroundStyle(.red) }
            Button("Save end time") { vm.saveRecoveryEndTime() }
        }
    }
}
