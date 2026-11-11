import SwiftUI

struct PeriodTimesheetView: View {
    @Bindable var vm: TimerViewModel
    let days: [DailyBarData]
    let periodTitle: String
    let defaultDate: Date
    let theme: PopoverTheme
    /// Hide days after today from the table. Copy all still copies every day in the period.
    var hidesUpcomingDays = false
    /// Offer a "Show empty days" filter. Copy all still copies every day, empty ones as blank rows.
    var offersEmptyDayFilter = false
    /// Sprints for the header's Export CSV item; nil hides the item.
    var exportSprints: [Sprint]? = nil

    @State private var selectedDay: DailyBarData?
    @State private var dayToDelete: DailyBarData?
    @State private var isDeleteAlertPresented = false
    @State private var isAddingSprint = false
    @State private var copiedScope: String?
    @State private var tableWidth: CGFloat = 0
    @State private var showsEmptyDays = false
    @State private var exportMessage: String?
    @State private var exportError: String?

    private var visibleDays: [DailyBarData] {
        guard hidesUpcomingDays || offersEmptyDayFilter else { return days }
        let today = Calendar.current.startOfDay(for: Date())
        return days.filter { day in
            (!hidesUpcomingDays || Calendar.current.startOfDay(for: day.date) <= today)
                && (!offersEmptyDayFilter || showsEmptyDays || !day.completedSprints.isEmpty)
        }
    }

    private var hasCompletedSprints: Bool { days.contains { !$0.completedSprints.isEmpty } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let exportMessage {
                Label(exportMessage, systemImage: "checkmark.circle.fill")
                    .font(.dashboardCaption).foregroundStyle(theme.successText)
            }
            ScrollView(.horizontal) {
                table
                    .frame(width: max(tableWidth, 820))
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { tableWidth = $0 }
            if visibleDays.isEmpty {
                Text("No sprints in \(periodTitle).")
                    .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
            } else if days.count > visibleDays.count {
                Text(hiddenDaysCaption)
                    .font(.dashboardCaption)
                    .foregroundStyle(theme.textSecondary)
            }
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
        .task(id: exportMessage) {
            guard exportMessage != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            exportMessage = nil
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(exportError ?? "") }
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
        .alert("Delete sprints for this day?", isPresented: $isDeleteAlertPresented, presenting: dayToDelete) { day in
            Button("Delete Sprints", role: .destructive) {
                vm.deleteCompletedSprints(for: day.date)
                dayToDelete = nil
            }
            Button("Cancel", role: .cancel) { dayToDelete = nil }
        } message: { day in
            Text("Delete all completed sprints for \(day.date.formatted(date: .long, time: .omitted))? This cannot be undone. An open sprint will remain.")
        }
    }

    private var header: some View {
        DashboardCardHeader(title: "Daily timesheet", icon: "calendar", theme: theme) {
            HStack(spacing: 8) {
                if offersEmptyDayFilter {
                    Toggle("Show empty days", isOn: $showsEmptyDays)
                        .toggleStyle(.checkbox)
                        .font(.dashboardCaption)
                }
                Button(copiedScope == "all" ? "Copied" : "Copy all",
                       systemImage: copiedScope == "all" ? "checkmark" : "doc.on.doc") {
                    copy(days, scope: "all")
                }
                .disabled(!hasCompletedSprints)
                .help("Copy every calendar day in \(periodTitle), earliest first. Empty days paste as blank rows.")
                Button("Add sprint", systemImage: "plus") { isAddingSprint = true }
                if exportSprints != nil {
                    Menu {
                        Button("Export CSV…", action: export)
                            .disabled(exportSprints?.isEmpty ?? true)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("More timesheet actions")
                    .help("Export CSV")
                }
                DashboardInfoButton(text: Self.copyHelp, theme: theme, accessibilityTitle: "About the timesheet")
            }
            .controlSize(.small)
        }
    }

    private static let copyHelp = "Copy all copies the whole period, earliest day first. Empty days paste as blank rows. Columns: Login, Logout, blank Lunch, Break in minutes. Completed sprints only. Break includes pauses and gaps between sprints."

    private var hiddenDaysCaption: String {
        let hidden = days.count - visibleDays.count
        let reason = offersEmptyDayFilter && !showsEmptyDays ? "empty or upcoming" : "upcoming"
        return "\(hidden) \(reason) day\(hidden == 1 ? " is" : "s are") hidden. Copy all still includes them."
    }

    private func export() {
        guard let sprints = exportSprints else { return }
        CSVExporter.promptSavePanel(sprints: sprints, profileName: vm.activeProfileName, onComplete: { success, url in
            if success, let name = url?.lastPathComponent {
                exportMessage = "Exported \(sprints.count) sprint\(sprints.count == 1 ? "" : "s") to \(name)"
            }
        }, onFailure: { exportError = $0 })
    }

    private var table: some View {
        LazyVStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("DATE").frame(minWidth: 170, maxWidth: .infinity, alignment: .leading)
                Text("LOGIN").frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
                Text("LOGOUT").frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
                Text("WORK TIME").frame(minWidth: 100, maxWidth: .infinity, alignment: .trailing)
                Text("PAUSED").frame(minWidth: 100, maxWidth: .infinity, alignment: .trailing)
                Text("ACTIONS").frame(width: 180, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.cardBorder.opacity(0.25))

            ForEach(Array(visibleDays.enumerated()), id: \.element.id) { index, day in
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
            // The timesheet row uses completed sprints only, so it matches the Login and Logout beside it.
            Text(summary == nil ? "—" : TimeFormatter.format(clock: DayLog(sprints: day.completedSprints).accumulatedTotal))
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .trailing)
            Text(summary == nil ? "—" : TimeFormatter.format(shortDuration: day.completedSprints.reduce(0) { $0 + $1.pausedDuration }))
                .foregroundStyle(theme.textSecondary)
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .trailing)
                .help("Total paused time within completed sprints. Gaps between sprints are excluded.")
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
                Button(role: .destructive) {
                    dayToDelete = day
                    isDeleteAlertPresented = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(day.completedSprints.isEmpty)
                .accessibilityLabel("Delete completed sprints for \(day.date.formatted(date: .abbreviated, time: .omitted))")
                .help("Delete all completed sprints for this day.")
            }
            .frame(width: 180, alignment: .trailing)
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
                                   distinctTags: day.completedSprints.distinctTags,
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
