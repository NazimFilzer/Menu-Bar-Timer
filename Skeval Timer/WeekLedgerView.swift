import SwiftUI

/// One row per day of the week: work against the daily goal, the timesheet columns,
/// and, for the remaining scheduled workdays, the hours the pace needs.
/// It reads the engine directly and refreshes about once a minute, not on every tick.
struct WeekLedgerView: View {
    @Bindable var vm: TimerViewModel
    let summary: WeeklySummary
    let theme: PopoverTheme

    @State private var detailsDay: DailyBarData?
    @State private var addSprintDate: Date?
    @State private var dayToDelete: DailyBarData?
    @State private var isDeleteAlertPresented = false
    @State private var copiedScope: String?

    private struct Row: Identifiable {
        let day: DailyBarData
        let workedSeconds: TimeInterval
        let isWorkingDay: Bool
        let isFuture: Bool
        let previousSeconds: TimeInterval?
        /// Hours this remaining workday needs; today's bar adds them to the work so far.
        let neededSeconds: TimeInterval?
        let timesheet: DailyTimesheet?
        /// The Month calendar's rule: finished workdays under 75% of the goal get the warning colour.
        let status: MonthCalendarDay.Status
        var id: String { day.id }
        var isShort: Bool { status == .shortOfGoal || status == .missed }
    }

    var body: some View {
        _ = vm.logRevision
        _ = vm.timelineRevision
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let state = vm.engine.state
        let logs = vm.store.allLogs()
        let pace = WeekPace.calculate(logs: logs, weekStart: summary.weekStartDate, settings: vm.goal,
                                      state: state, now: now, calendar: calendar)
        let comparison = WeekComparison.calculate(
            logs: logs, weekStart: summary.weekStartDate, now: now, compareClockTime: true,
            liveSprint: state.isRunning ? state.currentSprint : nil, liveElapsed: state.currentElapsed,
            calendar: calendar)
        let rows = makeRows(state: state, pace: pace, comparison: comparison, now: now, calendar: calendar)
        let scale = max(vm.goal.dailyGoalSeconds,
                        rows.map { $0.workedSeconds + ($0.day.isToday ? $0.neededSeconds ?? 0 : 0) }.max() ?? 0,
                        rows.compactMap(\.neededSeconds).max() ?? 0,
                        rows.compactMap(\.previousSeconds).max() ?? 0) * 1.1

        return VStack(alignment: .leading, spacing: 0) {
            header.padding(.bottom, 12)
            columnHeader
            ForEach(rows) { row in
                rowView(row, scale: scale)
                Divider().overlay(theme.dividerColor.opacity(0.5))
            }
            footer(comparison: comparison, pace: pace).padding(.top, 10)
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
        .onChange(of: summary.weekStartDate) { _, _ in copiedScope = nil }
        .onChange(of: vm.logRevision) { _, _ in copiedScope = nil }
        .task(id: copiedScope) {
            guard copiedScope != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            copiedScope = nil
        }
        .sheet(item: $detailsDay) { day in details(for: summary.days.first { $0.id == day.id } ?? day) }
        .sheet(isPresented: Binding(get: { addSprintDate != nil }, set: { if !$0 { addSprintDate = nil } })) {
            AddSprintModalView(vm: vm, theme: theme, defaultDate: addSprintDate ?? defaultDate,
                               onDismiss: { addSprintDate = nil })
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

    private var defaultDate: Date { summary.isCurrentWeek ? Date() : summary.weekStartDate }

    private func makeRows(state: SprintState, pace: WeekPace, comparison: WeekComparison,
                          now: Date, calendar: Calendar) -> [Row] {
        let today = calendar.startOfDay(for: now)
        let previous = Dictionary(comparison.days.map { (calendar.startOfDay(for: $0.date), $0.previousSeconds) },
                                  uniquingKeysWith: { first, _ in first })
        return summary.days.map { day in
            let date = calendar.startOfDay(for: day.date)
            let live = state.isRunning && state.currentSprint.map { calendar.isDate($0.startTime, inSameDayAs: day.date) } == true
                ? max(0, state.currentElapsed) : 0
            let working = vm.goal.isWorkingDay(day.date, calendar: calendar)
            // Today shows what it still needs on top of its work so far; later workdays show their total.
            let remaining = date == today ? pace.neededMoreToday : pace.neededPerWorkingDay
            let needed = pace.isCurrentWeek && working && date >= today ? remaining.map { ceil($0 / 60) * 60 } : nil
            return Row(day: day, workedSeconds: day.totalSeconds + live, isWorkingDay: working,
                       isFuture: date > today, previousSeconds: previous[date], neededSeconds: needed,
                       timesheet: DailyTimesheet(log: DayLog(sprints: day.completedSprints)),
                       status: MonthCalendar.status(seconds: day.totalSeconds + live, date: date, isWorkingDay: working,
                                                    goalSeconds: vm.goal.dailyGoalSeconds, today: today))
        }
    }

    // MARK: - Header and footer

    private var header: some View {
        HStack(spacing: 8) {
            Label("WEEK LEDGER", systemImage: "list.bullet.rectangle")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .kerning(0.8)
            Spacer()
            if let copiedScope, copiedScope != "all" {
                Label("Copied \(copiedScope)", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.successText)
            }
            Button(copiedScope == "all" ? "Copied" : "Copy All",
                   systemImage: copiedScope == "all" ? "checkmark" : "doc.on.doc") {
                if vm.copyTimesheet(days: summary.days) { copiedScope = "all" }
            }
            .disabled(!summary.days.contains { !$0.completedSprints.isEmpty })
            .help("Copies every day of \(summary.weekRangeLabel), earliest first: Login, Logout, blank Lunch, Break in minutes. Empty days paste as blank rows. Completed sprints only; Break includes pauses and gaps between sprints.")
            Button("Add Sprint", systemImage: "plus") { addSprintDate = defaultDate }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 12) {
            Text("DAY").frame(width: 74, alignment: .leading)
            Text("WORK VS \(vm.goal.goalLabel.uppercased()) GOAL").frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
            Text("WORK").frame(width: 78, alignment: .trailing)
            Text("LOGIN – LOGOUT").frame(width: 150, alignment: .leading)
            Text("BREAK").frame(width: 50, alignment: .trailing)
            Text("TAG").frame(width: 120, alignment: .leading)
            Color.clear.frame(width: 28, height: 1)
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.cardBorder).frame(height: 1) }
        .accessibilityHidden(true)
    }

    private func footer(comparison: WeekComparison, pace: WeekPace) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !comparison.days.isEmpty {
                Text(comparisonSentence(comparison))
                    .help(comparison.isEstimated
                          ? "Estimate. Paused time is spread evenly within sprints that cross the comparison time."
                          : "Completed work plus the active sprint, compared with the matching days last week\(comparison.isCurrentWeek ? " up to the current time" : "").")
            }
            Text(pace.neededPerWorkingDay != nil
                 ? "Thin line: last week. Dashed amber bars: what each remaining workday needs. Orange bars: under \(Int(MonthCalendar.nearGoalShare * 100))% of the daily goal."
                 : "Thin line under each bar: the same day last week. Orange bars: under \(Int(MonthCalendar.nearGoalShare * 100))% of the daily goal.")
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(theme.textSecondary)
    }

    private func comparisonSentence(_ comparison: WeekComparison) -> String {
        let previous = duration(comparison.previousSeconds)
        guard comparison.isCurrentWeek else { return "Previous week: \(previous)." }
        let gap = comparison.difference
        let change = abs(gap) < 60 ? "the same as this week" : "\(duration(abs(gap))) \(gap > 0 ? "more" : "less") this week"
        return "At this point last week: \(previous), \(change)\(comparison.isEstimated ? " (estimate)" : "")."
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowView(_ row: Row, scale: TimeInterval) -> some View {
        let day = row.day
        if row.isFuture && !row.isWorkingDay && row.workedSeconds == 0 {
            HStack(spacing: 12) {
                Text(shortDay(day)).frame(width: 74, alignment: .leading)
                Text("Day off")
                Spacer()
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 6).padding(.vertical, 9)
        } else {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(shortDay(day)).font(.system(size: 12, weight: day.isToday ? .bold : .medium, design: .rounded))
                        if day.isToday {
                            Text("Today").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(theme.accentText)
                        }
                    }
                    .frame(width: 74, alignment: .leading)
                    bar(row, scale: scale).frame(minWidth: 150, maxWidth: .infinity)
                    workText(row).frame(width: 78, alignment: .trailing)
                    Text(row.timesheet.map { "\(TimeFormatter.format(time: $0.login)) – \(TimeFormatter.format(time: $0.logout))" }
                         ?? (row.neededSeconds != nil && row.workedSeconds == 0 ? "needed" : ""))
                        .foregroundStyle(row.timesheet == nil ? theme.textSecondary : theme.textPrimary)
                        .frame(width: 150, alignment: .leading)
                    Text(row.timesheet.map { "\(TimeFormatter.format(breakMinutes: $0.breakDuration))m" } ?? "")
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 50, alignment: .trailing)
                    tags(day).frame(width: 120, alignment: .leading)
                }
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText(row))
                .help(helpText(row))
                actions(day).frame(width: 28)
            }
            .padding(.horizontal, 6).padding(.vertical, 8)
            .background(day.isToday ? theme.neonTeal.opacity(0.12) : row.isShort ? Color.orange.opacity(theme.isLight ? 0.07 : 0.09) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .opacity(!row.isWorkingDay && row.workedSeconds == 0 ? 0.6 : 1)
        }
    }

    private func bar(_ row: Row, scale: TimeInterval) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let x = { (seconds: TimeInterval) in width * CGFloat(min(seconds / max(scale, 1), 1)) }
            let met = row.workedSeconds >= vm.goal.dailyGoalSeconds && vm.goal.dailyGoalSeconds > 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(theme.cardBorder.opacity(0.35)).frame(height: 12)
                if let needed = row.neededSeconds {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.orange.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: x(row.workedSeconds + needed), height: 12)
                }
                if row.workedSeconds > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(row.day.isToday ? theme.neonTeal : met ? theme.successText
                              : row.status == .shortOfGoal ? Color.orange.opacity(0.8) : theme.neonTeal.opacity(0.5))
                        .frame(width: max(x(row.workedSeconds), 3), height: 12)
                }
                Rectangle().fill(theme.accentIcon).frame(width: 1.5, height: 20).offset(x: x(vm.goal.dailyGoalSeconds) - 0.75)
                if let previous = row.previousSeconds, previous > 0 {
                    Capsule().fill(theme.textSecondary.opacity(0.4)).frame(width: x(previous), height: 3).offset(y: 10)
                }
            }
            .frame(height: proxy.size.height)
        }
        .frame(height: 24)
    }

    @ViewBuilder
    private func workText(_ row: Row) -> some View {
        let met = row.workedSeconds >= vm.goal.dailyGoalSeconds && vm.goal.dailyGoalSeconds > 0
        if row.workedSeconds > 0 {
            HStack(spacing: 3) {
                if met { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(theme.successText) }
                Text(duration(row.workedSeconds)).fontWeight(.semibold)
                    .foregroundStyle(row.status == .shortOfGoal ? theme.warningText : theme.textPrimary)
            }
        } else if let needed = row.neededSeconds {
            Text(duration(needed)).fontWeight(.semibold).foregroundStyle(theme.warningText)
        } else {
            Text(row.isWorkingDay ? "—" : "off").foregroundStyle(row.status == .missed ? theme.warningText : theme.textSecondary)
        }
    }

    /// Always returns a container, so the column keeps its width on days without tags.
    private func tags(_ day: DailyBarData) -> some View {
        let tags = day.completedSprints.distinctTags
        return ZStack(alignment: .leading) {
            Color.clear.frame(height: 1)
            if let first = tags.first {
            HStack(spacing: 4) {
                Text("#\(first)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.accentText)
                    .lineLimit(1)
                    .padding(.horizontal, 7).padding(.vertical, 2.5)
                    .background(theme.neonTeal.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(theme.neonTeal.opacity(0.35), lineWidth: 1))
                if tags.count > 1 {
                    Text("+\(tags.count - 1)").font(.caption2).foregroundStyle(theme.textSecondary)
                }
            }
            .help(tags.map { "#\($0)" }.joined(separator: ", "))
            }
        }
    }

    private func actions(_ day: DailyBarData) -> some View {
        let name = shortDay(day)
        let hasSprints = !day.completedSprints.isEmpty
        return Menu {
            Button("Copy \(name) Row", systemImage: "doc.on.doc") {
                if vm.copyTimesheet(days: [day]) { copiedScope = name }
            }
            .disabled(!hasSprints)
            Button("Details…", systemImage: "list.bullet") { detailsDay = day }
            Button("Add Sprint on \(name)…", systemImage: "plus") { addSprintDate = day.date }
            Divider()
            Button("Delete \(name) Sprints…", systemImage: "trash", role: .destructive) {
                dayToDelete = day
                isDeleteAlertPresented = true
            }
            .disabled(!hasSprints)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Actions for \(day.date.formatted(date: .abbreviated, time: .omitted))")
        .help("Copy this day's row, see its sprints, add a sprint, or delete its sprints.")
    }

    private func details(for day: DailyBarData) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(day.date, format: .dateTime.weekday().month().day().year()).font(.headline)
                Spacer()
                Button("Done") { detailsDay = nil }.keyboardShortcut(.cancelAction)
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

    // MARK: - Text

    private func shortDay(_ day: DailyBarData) -> String { "\(day.dayOfWeekLabel) \(day.dayNumberLabel)" }
    private func duration(_ seconds: TimeInterval) -> String { TimeFormatter.format(shortDuration: seconds) }

    private func earnings(_ seconds: TimeInterval) -> String {
        EarningsCalculator.format(amount: EarningsCalculator.calculate(durationInSeconds: seconds, hourlyRate: vm.goal.hourlyRate),
                                  currencySymbol: vm.goal.currencySymbol)
    }

    private func helpText(_ row: Row) -> String {
        var parts = [row.day.dateLabel]
        if row.workedSeconds > 0 || row.neededSeconds == nil {
            parts.append("\(duration(row.workedSeconds)) worked")
            if vm.goal.hasHourlyRate { parts.append("\(earnings(row.workedSeconds)) earned") }
        }
        if let needed = row.neededSeconds { parts.append("needs \(duration(needed))\(row.day.isToday ? " more today" : "")") }
        let goal = vm.goal.dailyGoalSeconds
        if goal > 0 && row.workedSeconds > 0 { parts.append("\(Int(min(row.workedSeconds / goal, 9.99) * 100))% of the daily goal") }
        if let timesheet = row.timesheet {
            parts.append("\(TimeFormatter.format(time: timesheet.login)) – \(TimeFormatter.format(time: timesheet.logout)), break \(TimeFormatter.format(breakMinutes: timesheet.breakDuration))m")
        }
        let sprints = row.day.completedSprints.count
        if sprints > 0 { parts.append("\(sprints) sprint\(sprints == 1 ? "" : "s")") }
        if let previous = row.previousSeconds {
            let gap = row.workedSeconds - previous
            let change = abs(gap) < 60 ? "same" : "\(gap > 0 ? "+" : "−")\(duration(abs(gap)))"
            parts.append("last week \(duration(previous)) (\(change))")
        }
        var text = parts.joined(separator: " · ")
        switch row.status {
        case .shortOfGoal: text += "\nUnder \(Int(MonthCalendar.nearGoalShare * 100))% of the daily goal."
        case .missed: text += "\nWorkday with no work recorded."
        case .dayOff where row.workedSeconds == 0: text += "\nDay off."
        default: break
        }
        return text
    }

    private func accessibilityText(_ row: Row) -> String {
        var parts = [row.day.date.formatted(date: .complete, time: .omitted)]
        if row.workedSeconds > 0 { parts.append("worked \(duration(row.workedSeconds))") }
        else if !row.isWorkingDay { parts.append("day off") }
        if vm.goal.hasHourlyRate && row.workedSeconds > 0 { parts.append("earned \(earnings(row.workedSeconds))") }
        if let timesheet = row.timesheet {
            parts.append("login \(TimeFormatter.format(time: timesheet.login)), logout \(TimeFormatter.format(time: timesheet.logout)), break \(TimeFormatter.format(breakMinutes: timesheet.breakDuration)) minutes")
        }
        if let needed = row.neededSeconds { parts.append("needs \(duration(needed))") }
        if let previous = row.previousSeconds { parts.append("last week \(duration(previous))") }
        let tags = row.day.completedSprints.distinctTags
        if !tags.isEmpty { parts.append("tags \(tags.joined(separator: ", "))") }
        return parts.joined(separator: ", ")
    }
}
