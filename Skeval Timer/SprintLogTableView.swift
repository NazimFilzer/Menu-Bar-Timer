import SwiftUI
import AppKit

enum TagFilter: Equatable {
    case all
    case untagged
    case tag(String)

    func matches(sprint: Sprint) -> Bool {
        switch self {
        case .all:
            return true
        case .untagged:
            return sprint.tag == nil || sprint.tag!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tag(let filterTag):
            guard let tag = sprint.tag?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            return tag.caseInsensitiveCompare(filterTag) == .orderedSame
        }
    }
}

struct SprintLogTableView: View {
    @Bindable var vm: TimerViewModel
    let allSprints: [Sprint]
    let distinctTags: [String]
    let defaultDate: Date
    let title: String
    let theme: PopoverTheme

    init(vm: TimerViewModel, summary: WeeklySummary, theme: PopoverTheme, title: String = "SPRINT LOGS & HISTORY") {
        self.vm = vm
        self.allSprints = summary.allWeekSprints
        self.distinctTags = summary.allDistinctTags
        self.defaultDate = summary.isCurrentWeek ? Date() : summary.weekStartDate
        self.theme = theme
        self.title = title
    }

    init(vm: TimerViewModel, monthlySummary: MonthlySummary, theme: PopoverTheme, title: String = "MONTHLY SPRINT LOGS") {
        self.vm = vm
        self.allSprints = monthlySummary.allMonthSprints
        self.distinctTags = monthlySummary.allDistinctTags
        self.defaultDate = monthlySummary.isCurrentMonth ? Date() : monthlySummary.monthStartDate
        self.theme = theme
        self.title = title
    }

    init(vm: TimerViewModel, sprints: [Sprint], distinctTags: [String], defaultDate: Date, theme: PopoverTheme, title: String) {
        self.vm = vm
        self.allSprints = sprints
        self.distinctTags = distinctTags
        self.defaultDate = defaultDate
        self.theme = theme
        self.title = title
    }

    @State private var searchQuery: String = ""
    @State private var selectedTagFilter: TagFilter = .all
    @State private var isAddModalPresented: Bool = false
    @State private var editingSprint: Sprint? = nil
    @State private var sprintToDelete: Sprint? = nil
    @State private var isDeleteAlertPresented: Bool = false
    @State private var copiedSprintId: UUID? = nil

    private static let tableDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private var untaggedCount: Int {
        allSprints.filter { $0.tag == nil || $0.tag!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private var filteredSprints: [Sprint] {
        allSprints.filter { sprint in
            if !selectedTagFilter.matches(sprint: sprint) {
                return false
            }

            // Search query filtering
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !query.isEmpty {
                let dateStr = Self.tableDateFormatter.string(from: sprint.startTime).lowercased()
                let startStr = sprint.startLabel.lowercased()
                let endStr = sprint.endLabel.lowercased()
                let durStr = sprint.durationLabel.lowercased()
                let tagStr = (sprint.tag ?? "").lowercased()

                let matches = dateStr.contains(query) ||
                              startStr.contains(query) ||
                              endStr.contains(query) ||
                              durStr.contains(query) ||
                              tagStr.contains(query) ||
                              ("#" + tagStr).contains(query)
                if !matches { return false }
            }

            return true
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header: Title, Count Badge & Add Sprint Button
            headerRow

            // Search & Tag Filter Bar
            filterBar

            // Sprints Data Table or Empty State
            if filteredSprints.isEmpty {
                emptyStateView
            } else {
                tableSurface
            }
        }
        .padding(18)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        // Add Sprint Modal Sheet
        .sheet(isPresented: $isAddModalPresented) {
            AddSprintModalView(
                vm: vm,
                theme: theme,
                defaultDate: defaultDate,
                onDismiss: { isAddModalPresented = false }
            )
        }
        // Edit Sprint Modal Sheet
        .sheet(item: $editingSprint) { sprint in
            EditSprintModalView(
                sprint: sprint,
                vm: vm,
                theme: theme,
                onDismiss: { editingSprint = nil }
            )
        }
        // Delete Confirmation Dialog
        .confirmationDialog(
            "Delete Sprint?",
            isPresented: $isDeleteAlertPresented,
            titleVisibility: .visible,
            presenting: sprintToDelete
        ) { sprint in
            Button("Delete Sprint", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.delete(sprint: sprint)
                }
                sprintToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                sprintToDelete = nil
            }
        } message: { sprint in
            let dateStr = Self.tableDateFormatter.string(from: sprint.startTime)
            Text("Are you sure you want to delete the sprint on \(dateStr) (\(sprint.startLabel) – \(sprint.endLabel))? This cannot be undone.")
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.neonTeal)

                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .kerning(0.8)

                Text("\(allSprints.count) sprint\(allSprints.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(theme.neonTeal.opacity(0.12))
                    .foregroundColor(theme.neonTeal)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(theme.neonTeal.opacity(0.3), lineWidth: 1))
            }

            Spacer()

            HStack(spacing: 8) {
                // Export Filtered CSV Button
                Button(action: {
                    CSVExporter.promptSavePanel(
                        sprints: filteredSprints,
                        suggestedName: "skeval-sprints-export.csv"
                    )
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 11, weight: .bold))
                        Text("Export CSV")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(theme.cardBorder.opacity(0.35))
                    .foregroundColor(theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Export currently filtered sprints to RFC-4180 CSV")

                // "+ Add Sprint" Button
                Button(action: { isAddModalPresented = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add Sprint")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.neonTeal)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: theme.neonTeal.opacity(0.3), radius: 4, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Search & Filter Bar

    private var filterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Search Input
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)

                    TextField("Search by tag, date, time...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(theme.textPrimary)

                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.cardBg.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )

                if selectedTagFilter != .all || !searchQuery.isEmpty {
                    Button(action: {
                        selectedTagFilter = .all
                        searchQuery = ""
                    }) {
                        Text("Reset Filters")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(theme.cardBorder.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Tag Filter Chips
            if !distinctTags.isEmpty || untaggedCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // "All" chip
                        tagFilterChip(
                            title: "All (\(allSprints.count))",
                            isSelected: selectedTagFilter == .all,
                            onTap: { selectedTagFilter = .all }
                        )

                        // Unique tags chips
                        ForEach(distinctTags, id: \.self) { tag in
                            let count = allSprints.filter { $0.tag?.caseInsensitiveCompare(tag) == .orderedSame }.count
                            tagFilterChip(
                                title: "#\(tag) (\(count))",
                                isSelected: selectedTagFilter == .tag(tag),
                                onTap: {
                                    if selectedTagFilter == .tag(tag) {
                                        selectedTagFilter = .all
                                    } else {
                                        selectedTagFilter = .tag(tag)
                                    }
                                }
                            )
                        }

                        // Untagged chip
                        if untaggedCount > 0 {
                            tagFilterChip(
                                title: "Untagged (\(untaggedCount))",
                                isSelected: selectedTagFilter == .untagged,
                                onTap: {
                                    if selectedTagFilter == .untagged {
                                        selectedTagFilter = .all
                                    } else {
                                        selectedTagFilter = .untagged
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func tagFilterChip(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(isSelected ? theme.neonTeal.opacity(0.2) : theme.cardBorder.opacity(0.25))
                .foregroundColor(isSelected ? theme.neonTeal : theme.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? theme.neonTeal.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Table Surface

    private var tableSurface: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 8) {
                Text("DATE")
                    .frame(width: 95, alignment: .leading)
                Text("START")
                    .frame(width: 65, alignment: .leading)
                Text("END")
                    .frame(width: 65, alignment: .leading)
                Text("PAUSED")
                    .frame(width: 65, alignment: .leading)
                Text("NET DURATION")
                    .frame(width: 90, alignment: .leading)
                Text("TAG")
                    .frame(minWidth: 80, alignment: .leading)
                Spacer()
                Text("ACTIONS")
                    .frame(width: 85, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(theme.textSecondary)
            .kerning(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.cardBorder.opacity(0.2))

            Divider().background(theme.dividerColor)

            // Rows
            ForEach(Array(filteredSprints.enumerated()), id: \.element.id) { index, sprint in
                sprintRowView(sprint: sprint, isEven: index % 2 == 0)

                if index < filteredSprints.count - 1 {
                    Divider().background(theme.dividerColor.opacity(0.4))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    private func sprintRowView(sprint: Sprint, isEven: Bool) -> some View {
        HStack(spacing: 8) {
            // Date
            Text(Self.tableDateFormatter.string(from: sprint.startTime))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .frame(width: 95, alignment: .leading)

            // Start Time
            Text(sprint.startLabel)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .frame(width: 65, alignment: .leading)

            // End Time
            Text(sprint.endLabel)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .frame(width: 65, alignment: .leading)

            // Paused Duration
            Text(sprint.hasPause ? sprint.pausedLabel : "—")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(sprint.hasPause ? theme.neonTeal.opacity(0.8) : theme.textSecondary.opacity(0.6))
                .frame(width: 65, alignment: .leading)

            // Net Duration
            Text(sprint.durationLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .frame(width: 90, alignment: .leading)

            // Tag
            if let tag = sprint.tag?.trimmingCharacters(in: .whitespacesAndNewlines), !tag.isEmpty {
                HStack(spacing: 2) {
                    Text("#\(tag)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.neonTeal)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.neonTeal.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.neonTeal.opacity(0.3), lineWidth: 1))
                .frame(minWidth: 80, alignment: .leading)
            } else {
                Text("—")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.textSecondary.opacity(0.5))
                    .frame(minWidth: 80, alignment: .leading)
            }

            Spacer()

            // Actions: Copy, Edit, Delete
            HStack(spacing: 4) {
                // Copy button
                Button(action: { copySprint(sprint) }) {
                    Image(systemName: copiedSprintId == sprint.id ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(copiedSprintId == sprint.id ? Color.green : theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(copiedSprintId == sprint.id ? Color.green.opacity(0.15) : theme.cardBorder.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Copy sprint to clipboard (start\\teffectiveEnd)")

                // Edit button
                Button(action: { editingSprint = sprint }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(theme.neonTeal)
                        .frame(width: 24, height: 24)
                        .background(theme.neonTeal.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Edit sprint timestamps and tag")

                // Delete button
                Button(action: {
                    sprintToDelete = sprint
                    isDeleteAlertPresented = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(Color.red.opacity(0.85))
                        .frame(width: 24, height: 24)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Delete sprint log")
            }
            .frame(width: 85, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isEven ? Color.clear : theme.cardBorder.opacity(0.08))
    }

    private func copySprint(_ sprint: Sprint) {
        vm.copy(sprint: sprint)
        copiedSprintId = sprint.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if copiedSprintId == sprint.id {
                copiedSprintId = nil
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: allSprints.isEmpty ? "calendar.badge.clock" : "magnifyingglass")
                .font(.system(size: 26))
                .foregroundColor(theme.neonTeal.opacity(0.6))
                .padding(.top, 10)

            Text(allSprints.isEmpty ? "No Sprints Recorded This Week" : "No Sprints Found")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            Text(allSprints.isEmpty
                 ? "Completed sprints for this week will show up here. You can also manually add a sprint above."
                 : "No sprints matched your current search and tag filters.")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if !allSprints.isEmpty {
                Button(action: {
                    searchQuery = ""
                    selectedTagFilter = .all
                }) {
                    Text("Clear All Filters")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.neonTeal.opacity(0.15))
                        .foregroundColor(theme.neonTeal)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(theme.cardBorder.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Reusable Sprint Form Fields

struct SprintFormFieldsView: View {
    @Binding var selectedDate: Date
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var pauseMinutes: Int
    @Binding var tagText: String
    let theme: PopoverTheme

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Date:")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 90, alignment: .leading)

                DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                    .labelsHidden()
                Spacer()
            }

            HStack {
                Text("Start Time:")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 90, alignment: .leading)

                DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                Spacer()
            }

            HStack {
                Text("End Time:")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 90, alignment: .leading)

                DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                Spacer()
            }

            HStack {
                Text("Pause Duration:")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 90, alignment: .leading)

                Stepper("\(pauseMinutes) min", value: $pauseMinutes, in: 0...480, step: 5)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Spacer()
            }

            HStack {
                Text("Tag (Optional):")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 90, alignment: .leading)

                HStack(spacing: 4) {
                    Text("#")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.neonTeal)
                    TextField("e.g. client, dev, meeting", text: $tagText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(theme.cardBorder.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(14)
        .background(theme.cardBorder.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Reusable Sprint Duration Preview Card

struct SprintDurationPreviewCard: View {
    let netDuration: TimeInterval
    let estimatedEarnings: Double
    let hourlyRate: Double
    let currencySymbol: String
    let isValid: Bool
    let theme: PopoverTheme

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NET WORK DURATION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .kerning(0.6)
                    Text(TimeFormatter.format(shortDuration: netDuration))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isValid ? theme.textPrimary : Color.red)
                }

                Spacer()

                if hourlyRate > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ESTIMATED EARNINGS")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                            .kerning(0.6)
                        Text(EarningsCalculator.format(amount: estimatedEarnings, currencySymbol: currencySymbol))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.neonTeal)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))

            if !isValid {
                Text("End time must be after start time, and pause must be less than duration.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color.red)
            }
        }
    }
}

// MARK: - Add Sprint Modal View

struct AddSprintModalView: View {
    let vm: TimerViewModel
    let theme: PopoverTheme
    let defaultDate: Date
    let onDismiss: () -> Void

    @State private var selectedDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var pauseMinutes: Int = 0
    @State private var tagText: String = ""

    init(vm: TimerViewModel, theme: PopoverTheme, defaultDate: Date, onDismiss: @escaping () -> Void) {
        self.vm = vm
        self.theme = theme
        self.defaultDate = defaultDate
        self.onDismiss = onDismiss

        let cal = Calendar.current
        let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate) ?? defaultDate
        let end = cal.date(bySettingHour: 11, minute: 30, second: 0, of: defaultDate) ?? defaultDate.addingTimeInterval(9000)

        _selectedDate = State(initialValue: defaultDate)
        _startTime = State(initialValue: start)
        _endTime = State(initialValue: end)
    }

    private var grossDuration: TimeInterval {
        let s = TimeFormatter.combine(date: selectedDate, time: startTime)
        let e = TimeFormatter.combine(date: selectedDate, time: endTime, wrapIfBefore: s)
        return max(0, e.timeIntervalSince(s))
    }

    private var netDuration: TimeInterval {
        max(0, grossDuration - TimeInterval(pauseMinutes * 60))
    }

    private var isValid: Bool {
        grossDuration > 0 && TimeInterval(pauseMinutes * 60) < grossDuration
    }

    private var estimatedEarnings: Double {
        EarningsCalculator.calculate(durationInSeconds: netDuration, hourlyRate: vm.goal.hourlyRate)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(theme.neonTeal)
                    Text("Add Historical Sprint")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Divider().background(theme.dividerColor)

            SprintFormFieldsView(
                selectedDate: $selectedDate,
                startTime: $startTime,
                endTime: $endTime,
                pauseMinutes: $pauseMinutes,
                tagText: $tagText,
                theme: theme
            )

            SprintDurationPreviewCard(
                netDuration: netDuration,
                estimatedEarnings: estimatedEarnings,
                hourlyRate: vm.goal.hourlyRate,
                currencySymbol: vm.goal.currencySymbol,
                isValid: isValid,
                theme: theme
            )

            HStack(spacing: 10) {
                Button("Cancel", action: onDismiss)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.cardBorder.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Spacer()

                Button(action: saveSprint) {
                    Text("Add Sprint")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isValid ? theme.neonTeal : Color.gray.opacity(0.3))
                        .foregroundColor(isValid ? .black : theme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(theme.bgDark)
    }

    private func saveSprint() {
        guard isValid else { return }
        let cleanTag = tagText.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        _ = vm.addManualSprint(
            date: selectedDate,
            startTime: startTime,
            endTime: endTime,
            pausedDuration: TimeInterval(pauseMinutes * 60),
            tag: cleanTag.isEmpty ? nil : cleanTag
        )
        onDismiss()
    }
}

// MARK: - Edit Sprint Modal View

struct EditSprintModalView: View {
    let sprint: Sprint
    let vm: TimerViewModel
    let theme: PopoverTheme
    let onDismiss: () -> Void

    @State private var selectedDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var pauseMinutes: Int
    @State private var tagText: String

    init(sprint: Sprint, vm: TimerViewModel, theme: PopoverTheme, onDismiss: @escaping () -> Void) {
        self.sprint = sprint
        self.vm = vm
        self.theme = theme
        self.onDismiss = onDismiss

        _selectedDate = State(initialValue: sprint.startTime)
        _startTime = State(initialValue: sprint.startTime)
        _endTime = State(initialValue: sprint.endTime ?? sprint.startTime.addingTimeInterval(3600))
        _pauseMinutes = State(initialValue: Int(sprint.pausedDuration / 60))
        _tagText = State(initialValue: sprint.tag ?? "")
    }

    private var grossDuration: TimeInterval {
        let s = TimeFormatter.combine(date: selectedDate, time: startTime)
        let e = TimeFormatter.combine(date: selectedDate, time: endTime, wrapIfBefore: s)
        return max(0, e.timeIntervalSince(s))
    }

    private var netDuration: TimeInterval {
        max(0, grossDuration - TimeInterval(pauseMinutes * 60))
    }

    private var isValid: Bool {
        grossDuration > 0 && TimeInterval(pauseMinutes * 60) < grossDuration
    }

    private var estimatedEarnings: Double {
        EarningsCalculator.calculate(durationInSeconds: netDuration, hourlyRate: vm.goal.hourlyRate)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(theme.neonTeal)
                    Text("Edit Sprint Log")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Divider().background(theme.dividerColor)

            SprintFormFieldsView(
                selectedDate: $selectedDate,
                startTime: $startTime,
                endTime: $endTime,
                pauseMinutes: $pauseMinutes,
                tagText: $tagText,
                theme: theme
            )

            SprintDurationPreviewCard(
                netDuration: netDuration,
                estimatedEarnings: estimatedEarnings,
                hourlyRate: vm.goal.hourlyRate,
                currencySymbol: vm.goal.currencySymbol,
                isValid: isValid,
                theme: theme
            )

            HStack(spacing: 10) {
                Button("Cancel", action: onDismiss)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.cardBorder.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Spacer()

                Button(action: saveChanges) {
                    Text("Save Changes")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isValid ? theme.neonTeal : Color.gray.opacity(0.3))
                        .foregroundColor(isValid ? .black : theme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(theme.bgDark)
    }

    private func saveChanges() {
        guard isValid else { return }
        let cleanTag = tagText.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        _ = vm.updateSprint(
            originalSprint: sprint,
            newDate: selectedDate,
            newStartTime: startTime,
            newEndTime: endTime,
            newPausedDuration: TimeInterval(pauseMinutes * 60),
            newTag: cleanTag.isEmpty ? nil : cleanTag
        )
        onDismiss()
    }
}
