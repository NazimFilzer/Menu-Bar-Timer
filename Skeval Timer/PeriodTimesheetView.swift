import SwiftUI

struct PeriodTimesheetView: View {
    @Bindable var vm: TimerViewModel
    let days: [DailyBarData]
    let periodTitle: String
    let defaultDate: Date
    let theme: PopoverTheme

    @State private var selectedDay: DailyBarData?
    @State private var isAddingSprint = false
    @State private var copiedScope: String?

    private var hasCompletedSprints: Bool { days.contains { !$0.completedSprints.isEmpty } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Text(periodTitle)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            ScrollView(.horizontal) {
                table
            }
            Text("Copy All copies the whole period, earliest day first. Empty days paste as blank rows. Columns: Login, Logout, blank Lunch, Break in minutes.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Text("Completed sprints only. Break includes pauses and gaps between sprints.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(18)
        .foregroundStyle(theme.textPrimary)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))
        .onChange(of: days.first?.id) { _, _ in
            copiedScope = nil
        }
        .onChange(of: vm.logRevision) { _, _ in copiedScope = nil }
        .task(id: copiedScope) {
            guard copiedScope != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            copiedScope = nil
        }
        .sheet(isPresented: $isAddingSprint) {
            AddSprintModalView(vm: vm, theme: theme, defaultDate: defaultDate,
                               onDismiss: { isAddingSprint = false })
        }
        .sheet(item: $selectedDay) { day in
            sprintDetails(for: days.first { $0.id == day.id } ?? day)
        }
    }

    private var header: some View {
        HStack {
            Label("DAILY TIMESHEET", systemImage: "calendar")
                .font(.system(size: 12, weight: .bold, design: .rounded))
            Spacer()
            Button(copiedScope == "all" ? "Copied" : "Copy All",
                   systemImage: copiedScope == "all" ? "checkmark" : "doc.on.doc") {
                copy(days, scope: "all")
            }
            .disabled(!hasCompletedSprints)
            .help("Copy every calendar day in \(periodTitle).")
            Button("Add Sprint", systemImage: "plus") { isAddingSprint = true }
        }
    }

    private var table: some View {
        Grid(horizontalSpacing: 20, verticalSpacing: 12) {
            GridRow {
                Text("DATE")
                Text("LOGIN")
                Text("LOGOUT")
                Text("BREAK (MIN)")
                Text("SPRINTS")
                Text("ACTIONS")
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(theme.textSecondary)

            ForEach(days) { day in
                dailyRow(day)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.cardBorder.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func dailyRow(_ day: DailyBarData) -> some View {
        let summary = DailyTimesheet(log: DayLog(sprints: day.completedSprints))
        return GridRow {
            Text(day.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(summary.map { TimeFormatter.format(time: $0.login) } ?? "—")
            Text(summary.map { TimeFormatter.format(time: $0.logout) } ?? "—")
            Text(summary.map { TimeFormatter.format(breakMinutes: $0.breakDuration) } ?? "—")
            Text("\(day.completedSprints.count)")
            HStack(spacing: 10) {
                Button {
                    copy([day], scope: day.id)
                } label: {
                    Image(systemName: copiedScope == day.id ? "checkmark" : "doc.on.doc")
                }
                .disabled(summary == nil)
                .accessibilityLabel("Copy timesheet for \(day.date.formatted(date: .abbreviated, time: .omitted))")
                .help("Copy this day's Login, Logout, blank Lunch, and Break in minutes.")
                Button("Details") { selectedDay = day }
                    .help("View, add, edit, or delete this day's sprints.")
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .monospacedDigit()
    }

    private func sprintDetails(for day: DailyBarData) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(day.date, format: .dateTime.weekday().month().day().year())
                    .font(.headline)
                Spacer()
                Button("Done") { selectedDay = nil }
                    .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                SprintLogTableView(vm: vm, sprints: day.completedSprints.sorted { $0.startTime > $1.startTime },
                                   distinctTags: Array(Set(day.completedSprints.compactMap(\.tag))).sorted(),
                                   defaultDate: day.date, theme: theme, title: "SPRINT HISTORY")
            }
        }
        .padding(20)
        .frame(minWidth: 780, idealHeight: 500)
        .background(theme.bgDark)
    }

    private func copy(_ days: [DailyBarData], scope: String) {
        if vm.copyTimesheet(days: days) { copiedScope = scope }
    }
}
