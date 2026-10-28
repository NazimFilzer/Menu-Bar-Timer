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
    @State private var tableWidth: CGFloat = 0

    private var hasCompletedSprints: Bool { days.contains { !$0.completedSprints.isEmpty } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Text(periodTitle)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            ScrollView(.horizontal) {
                table
                    .frame(width: max(tableWidth, 780))
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { tableWidth = $0 }
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
        .onChange(of: days.last?.id) { _, _ in copiedScope = nil }
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
        LazyVStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("DATE").frame(minWidth: 170, maxWidth: .infinity, alignment: .leading)
                Text("LOGIN").frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
                Text("LOGOUT").frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
                Text("BREAK (MIN)").frame(minWidth: 92, maxWidth: .infinity, alignment: .trailing)
                Text("SPRINTS").frame(minWidth: 65, maxWidth: .infinity, alignment: .trailing)
                Text("ACTIONS").frame(width: 140, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.cardBorder.opacity(0.25))

            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                dailyRow(day)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(index.isMultiple(of: 2) ? theme.cardBorder.opacity(0.08) : Color.clear)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(theme.dividerColor.opacity(0.4)).frame(height: 0.5)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))
    }

    private func dailyRow(_ day: DailyBarData) -> some View {
        let summary = DailyTimesheet(log: DayLog(sprints: day.completedSprints))
        return HStack(spacing: 16) {
            Text(day.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(minWidth: 170, maxWidth: .infinity, alignment: .leading)
            Text(summary.map { TimeFormatter.format(time: $0.login) } ?? "—")
                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
            Text(summary.map { TimeFormatter.format(time: $0.logout) } ?? "—")
                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
            Text(summary.map { TimeFormatter.format(breakMinutes: $0.breakDuration) } ?? "—")
                .frame(minWidth: 92, maxWidth: .infinity, alignment: .trailing)
            Text("\(day.completedSprints.count)")
                .foregroundStyle(theme.textSecondary)
                .frame(minWidth: 65, maxWidth: .infinity, alignment: .trailing)
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
            .frame(width: 140, alignment: .trailing)
        }
        .font(.system(size: 12, design: .monospaced))
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
