import SwiftUI

/// Month page: a Monday-first calendar beside the month's summary, pace, and tags, then the timesheet.
struct MonthlyDashboardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @State private var monthOffset: Int = 0

    private var monthlySummary: MonthlySummary {
        _ = vm.logRevision
        return MonthlyAnalytics.calculate(
            logs: vm.store.allLogs(),
            monthOffset: monthOffset,
            referenceDate: Date(),
            settings: vm.goal
        )
    }

    var body: some View {
        let summary = monthlySummary
        let calendar = MonthCalendar.make(days: summary.days, settings: vm.goal)
        VStack(spacing: 18) {
            // Side by side when there is room; stacked in a narrow window.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    calendarCard(summary: summary, calendar: calendar)
                        .frame(minWidth: 500)
                    sideColumn(summary: summary, calendar: calendar)
                        .frame(width: 300)
                }
                VStack(spacing: 18) {
                    calendarCard(summary: summary, calendar: calendar)
                    sideColumn(summary: summary, calendar: calendar)
                }
            }

            PeriodTimesheetView(
                vm: vm,
                days: summary.days,
                periodTitle: summary.monthTitle,
                defaultDate: summary.isCurrentMonth ? Date() : summary.monthStartDate,
                theme: theme,
                hidesUpcomingDays: true
            )
        }
    }

    private func calendarCard(summary: MonthlySummary, calendar: MonthCalendar) -> some View {
        MonthCalendarCardView(vm: vm, summary: summary, calendar: calendar, theme: theme, offset: $monthOffset)
    }

    private func sideColumn(summary: MonthlySummary, calendar: MonthCalendar) -> some View {
        VStack(spacing: 18) {
            MonthWorkedCardView(summary: summary, goal: vm.goal, theme: theme)
            if summary.isCurrentMonth {
                // Pace includes the active sprint, so only this card follows the tick.
                Live {
                    MonthPaceCardView(catchUp: vm.catchUpSummary(for: .month),
                                      pace: vm.periodPaceForecast(for: .month),
                                      calendar: calendar, goal: vm.goal, theme: theme)
                }
            } else {
                MonthResultCardView(summary: summary, calendar: calendar, goal: vm.goal, theme: theme)
            }
            MonthTagCardView(summary: summary, theme: theme)
        }
    }
}

// MARK: - Shared card pieces

private struct MonthCardTitle: View {
    let title: String
    let icon: String
    let theme: PopoverTheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(theme.accentIcon)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .kerning(0.8)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

private extension View {
    func monthCard(_ theme: PopoverTheme, padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))
    }
}

/// A label and value on one line, used for the structured pace and result rows.
private struct MonthFactRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil
    var emphasized = false
    var detail: String? = nil
    var detailColor: Color? = nil
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: emphasized ? 16 : 13, weight: .bold, design: .monospaced))
                    .foregroundColor(valueColor ?? theme.textPrimary)
            }
            if let detail {
                Text(detail)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(detailColor ?? theme.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MonthSectionLabel: View {
    let text: String
    let theme: PopoverTheme

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(theme.textSecondary)
            .kerning(0.6)
            .padding(.top, 2)
    }
}

/// Whole minutes, rounded up, so the plan never undershoots.
private func monthDuration(_ seconds: TimeInterval) -> String {
    TimeFormatter.format(shortDuration: ceil(max(0, seconds) / 60) * 60)
}

private struct MonthStatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(color.opacity(0.14))
            .foregroundColor(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Calendar

private struct MonthCalendarCardView: View {
    let vm: TimerViewModel
    let summary: MonthlySummary
    let calendar: MonthCalendar
    let theme: PopoverTheme
    @Binding var offset: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cellHeight: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(MonthCalendar.weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(calendar.weeks.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { column in
                            if let cell = calendar.weeks[index][column] {
                                dayCell(cell)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
            legend
        }
        .monthCard(theme)
    }

    // MARK: Header and month navigation

    private var header: some View {
        HStack(alignment: .center) {
            MonthCardTitle(title: summary.monthTitle.uppercased(), icon: "calendar", theme: theme)
            if summary.isCurrentMonth {
                Text("CURRENT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accentColor.opacity(0.18))
                    .foregroundColor(theme.accentText)
                    .clipShape(Capsule())
            }
            Spacer()
            HStack(spacing: 6) {
                if offset != 0 {
                    Button { move(to: 0) } label: {
                        Text("Current Month")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.accentColor.opacity(0.15))
                            .foregroundColor(theme.accentText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                navButton("chevron.left", label: "Previous month", enabled: true) { move(to: offset - 1) }
                navButton("chevron.right", label: "Next month", enabled: offset < 0) { move(to: offset + 1) }
            }
        }
    }

    private func navButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .padding(6)
                .background(theme.cardBg.opacity(0.8))
                .foregroundColor(enabled ? theme.textPrimary : theme.textSecondary.opacity(0.4))
                .clipShape(Circle())
                .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func move(to newOffset: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { offset = newOffset }
    }

    // MARK: Day cell

    private func dayCell(_ cell: MonthCalendarDay) -> some View {
        let isToday = cell.status == .today
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8).fill(background(cell))
            if cell.goalFraction > 0 {
                // The fill rises with the share of the daily goal.
                Rectangle()
                    .fill(fill(cell))
                    .frame(height: cellHeight * cell.goalFraction)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(cell.day.dayNumberLabel)
                        .font(.system(size: 11, weight: isToday ? .heavy : .semibold, design: .rounded))
                        .foregroundColor(isToday ? theme.accentText : theme.textSecondary)
                    if isToday {
                        Text("Today")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(theme.accentText)
                    }
                    Spacer(minLength: 0)
                    if cell.status == .met {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(theme.successText)
                    }
                }
                Spacer(minLength: 0)
                value(cell)
            }
            .padding(7)
        }
        .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(border(cell))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .help(helpText(cell))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cell.day.date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(helpText(cell))
    }

    @ViewBuilder
    private func value(_ cell: MonthCalendarDay) -> some View {
        let font = Font.system(size: 12, weight: .bold, design: .monospaced)
        switch cell.status {
        case .today:
            // Includes the active sprint. Only this text follows the tick.
            Live {
                Text(vm.totalTodayElapsed > 0 ? TimeFormatter.format(hoursAndMinutes: vm.totalTodayElapsed) : "—")
                    .font(font).foregroundColor(theme.accentText)
            }
        case .met:
            Text(cell.day.formattedDuration).font(font).foregroundColor(theme.successText)
        case .belowGoal:
            Text(cell.day.formattedDuration).font(font).foregroundColor(theme.textPrimary)
        case .shortOfGoal:
            Text(cell.day.formattedDuration).font(font).foregroundColor(theme.warningText)
        case .extraTime:
            Text("+\(cell.day.formattedDuration)").font(font).foregroundColor(theme.accentText)
        case .missed:
            Text("—").font(font).foregroundColor(theme.warningText)
        case .dayOff:
            Text("Off").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(theme.textSecondary)
        case .upcoming:
            EmptyView()
        }
    }

    /// Short days use a plain orange fill and border, which stays amber on every theme.
    /// Their numbers use `warningText`, the theme's contrast-checked orange for text.
    static func shortFill(_ theme: PopoverTheme) -> Color { Color.orange.opacity(theme.isLight ? 0.2 : 0.24) }

    private func fill(_ cell: MonthCalendarDay) -> Color {
        switch cell.status {
        case .met: return theme.successText.opacity(0.16)
        case .shortOfGoal: return Self.shortFill(theme)
        default: return theme.accentColor.opacity(0.22)
        }
    }

    private func background(_ cell: MonthCalendarDay) -> Color {
        switch cell.status {
        case .upcoming: return .clear
        case .dayOff, .extraTime: return theme.bgDark.opacity(0.7)
        default: return cell.isWorkingDay ? theme.cardBg : theme.bgDark.opacity(0.7)
        }
    }

    @ViewBuilder
    private func border(_ cell: MonthCalendarDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        switch cell.status {
        case .today:
            shape.stroke(theme.accentColor, lineWidth: 2)
        case .met:
            shape.stroke(theme.successText.opacity(0.45), lineWidth: 1)
        case .shortOfGoal, .missed:
            shape.stroke(Color.orange.opacity(0.5), lineWidth: 1)
        case .upcoming, .dayOff:
            shape.stroke(theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        default:
            shape.stroke(theme.cardBorder, lineWidth: 1)
        }
    }

    private func helpText(_ cell: MonthCalendarDay) -> String {
        let day = cell.day
        let sprints = "\(day.sprintCount) sprint\(day.sprintCount == 1 ? "" : "s")"
        switch cell.status {
        case .upcoming: return "Upcoming \(cell.isWorkingDay ? "workday" : "day off")."
        case .today: return "Today, in progress. Completed so far: \(day.formattedDuration) · \(sprints)."
        case .dayOff: return "Day off. No work recorded."
        case .missed: return "Workday with no work recorded."
        case .shortOfGoal: return "\(day.formattedDuration) · \(day.formattedEarnings) · \(sprints). Only \(Int(cell.goalFraction * 100))% of the daily goal."
        case .met: return "\(day.formattedDuration) · \(day.formattedEarnings) · \(sprints). Daily goal met."
        case .belowGoal: return "\(day.formattedDuration) · \(day.formattedEarnings) · \(sprints). \(Int(cell.goalFraction * 100))% of the daily goal."
        case .extraTime: return "Day off with \(day.formattedDuration) of extra work · \(day.formattedEarnings) · \(sprints)."
        }
    }

    // MARK: Legend

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("Goal met", fill: theme.successText.opacity(0.16), stroke: theme.successText.opacity(0.45))
            legendItem("Close to goal", fill: theme.accentColor.opacity(0.22), stroke: theme.cardBorder)
            legendItem("Under \(Int(MonthCalendar.nearGoalShare * 100))%", fill: Self.shortFill(theme),
                       stroke: Color.orange.opacity(0.5))
            legendItem("Day off", fill: theme.bgDark.opacity(0.7), stroke: theme.cardBorder, dashed: true)
            legendItem("Upcoming", fill: .clear, stroke: theme.cardBorder, dashed: true)
            Text("— no work").foregroundColor(theme.warningText)
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundColor(theme.textSecondary)
    }

    private func legendItem(_ text: String, fill: Color, stroke: Color, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(stroke, style: StrokeStyle(lineWidth: 1, dash: dashed ? [2, 2] : [])))
                .frame(width: 11, height: 11)
            Text(text)
        }
    }
}

// MARK: - Worked

private struct MonthWorkedCardView: View {
    let summary: MonthlySummary
    let goal: GoalSettings
    let theme: PopoverTheme

    private var reached: Bool { summary.monthlyGoalPercent >= 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonthCardTitle(title: "WORKED", icon: "clock.fill", theme: theme)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.formattedTotalHours)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("of \(goal.monthlyGoalLabel) monthly goal")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }
            if goal.hasHourlyRate {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(summary.formattedTotalEarnings)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.successText)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("at \(goal.hourlyRateLabel)/h")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.cardBorder.opacity(0.35))
                        Capsule()
                            .fill(reached ? theme.successText : theme.accentColor)
                            .frame(width: summary.totalSeconds > 0 ? max(8, proxy.size.width * summary.monthlyGoalProgress) : 0)
                    }
                }
                .frame(height: 8)
                .accessibilityElement()
                .accessibilityLabel("Monthly goal")
                .accessibilityValue("\(summary.monthlyGoalPercent) percent")
                HStack {
                    Text(reached ? "Monthly goal reached"
                         : "\(TimeFormatter.format(shortDuration: max(0, summary.monthlyGoalSeconds - summary.totalSeconds))) left")
                        .foregroundColor(reached ? theme.successText : theme.textSecondary)
                    Spacer()
                    Text("\(summary.monthlyGoalPercent)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(reached ? theme.successText : theme.accentText)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            // Only compare when the earlier month has work; "no prior work" is not a comparison.
            if summary.monthOverMonth.priorSeconds > 0 && !summary.monthOverMonth.isNeutral {
                let mom = summary.monthOverMonth
                Label(mom.summaryText, systemImage: mom.isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(mom.isPositive ? theme.successText : theme.warningText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .monthCard(theme)
    }
}

// MARK: - Pace (current month)

private struct MonthPaceCardView: View {
    let catchUp: CatchUpSummary
    let pace: PeriodPaceForecast
    let calendar: MonthCalendar
    let goal: GoalSettings
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonthCardTitle(title: "PACE", icon: "speedometer", theme: theme)
                Spacer()
                statusPill
            }

            MonthSectionLabel(text: "SCHEDULE TO DATE", theme: theme)
            MonthFactRow(label: "Expected by today", value: catchUp.expectedLabel, theme: theme)
            MonthFactRow(label: "Clocked", value: catchUp.clockedLabel, theme: theme)
            if catchUp.isBehind {
                MonthFactRow(label: "Behind", value: monthDuration(catchUp.remainingSeconds),
                             valueColor: theme.warningText, theme: theme)
            } else if catchUp.aheadSeconds > 0 {
                MonthFactRow(label: "Ahead", value: monthDuration(catchUp.aheadSeconds),
                             valueColor: theme.successText, theme: theme)
            }

            Divider().overlay(theme.cardBorder)

            MonthSectionLabel(text: "TO REACH \(goal.monthlyGoalLabel.uppercased())", theme: theme)
            if pace.remainingSeconds == 0 {
                Label("Monthly goal reached", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.successText)
            } else {
                MonthFactRow(label: "Left", value: monthDuration(pace.remainingSeconds), theme: theme)
                MonthFactRow(label: "Workdays left",
                             value: "\(pace.remainingWorkingDays)",
                             detail: pace.remainingWorkingDays > 0
                                ? (pace.includesToday ? "including today" : "from tomorrow") : nil,
                             theme: theme)
                if let perDay = pace.secondsPerWorkingDay {
                    let extra = pace.extraSecondsPerWorkingDay ?? 0
                    MonthFactRow(label: "Needed per workday", value: monthDuration(perDay),
                                 valueColor: theme.accentText, emphasized: true,
                                 detail: extra > 0
                                    ? "\(monthDuration(extra)) more than your \(goal.goalLabel) day"
                                    : "Within your \(goal.goalLabel) day",
                                 detailColor: extra > 0 ? theme.warningText : theme.successText,
                                 theme: theme)
                } else {
                    Text("No scheduled workdays left this month.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(theme.warningText)
                }
                if pace.exceedsCapacity {
                    Label("More work is left than the remaining workdays can hold. Work a day off or lower the goal.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(theme.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().overlay(theme.cardBorder)

            MonthFactRow(label: "Workdays met",
                         value: "\(calendar.metWorkdays) of \(calendar.finishedWorkdays)",
                         detail: "Finished workdays at \(goal.goalLabel) or more",
                         theme: theme)
        }
        .monthCard(theme)
        .help("Expected by today: daily goal × scheduled workdays through today. Needed per workday: monthly goal minus clocked work, spread over the remaining scheduled workdays. Both include the active sprint and exclude breaks. Change working days and days off in Settings.")
    }

    private var statusPill: some View {
        if pace.remainingSeconds == 0 {
            return MonthStatusPill(text: "Goal reached", color: theme.successText)
        }
        if catchUp.isBehind {
            return MonthStatusPill(text: "Behind schedule", color: theme.warningText)
        }
        if catchUp.aheadSeconds > 0 {
            return MonthStatusPill(text: "Ahead of schedule", color: theme.successText)
        }
        return MonthStatusPill(text: "On schedule", color: theme.accentText)
    }
}

// MARK: - Result (past months)

private struct MonthResultCardView: View {
    let summary: MonthlySummary
    let calendar: MonthCalendar
    let goal: GoalSettings
    let theme: PopoverTheme

    var body: some View {
        let difference = summary.totalSeconds - summary.monthlyGoalSeconds
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonthCardTitle(title: "RESULT", icon: "flag.checkered", theme: theme)
                Spacer()
                MonthStatusPill(text: difference >= 0 ? "Goal reached" : "Goal missed",
                                color: difference >= 0 ? theme.successText : theme.warningText)
            }
            MonthFactRow(label: "Monthly goal", value: goal.monthlyGoalLabel, theme: theme)
            MonthFactRow(label: "Worked", value: summary.formattedTotalHours, theme: theme)
            MonthFactRow(label: difference >= 0 ? "Over goal" : "Short of goal",
                         value: monthDuration(abs(difference)),
                         valueColor: difference >= 0 ? theme.successText : theme.warningText,
                         emphasized: true, theme: theme)
            Divider().overlay(theme.cardBorder)
            MonthFactRow(label: "Workdays met",
                         value: "\(calendar.metWorkdays) of \(calendar.finishedWorkdays)",
                         detail: "Scheduled workdays that reached \(goal.goalLabel)", theme: theme)
            MonthFactRow(label: "Average per worked day", value: summary.formattedDailyAverage, theme: theme)
        }
        .monthCard(theme)
    }
}

// MARK: - Tags

private struct MonthTagCardView: View {
    let summary: MonthlySummary
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MonthCardTitle(title: "TIME BY TAG", icon: "tag.fill", theme: theme)
                Spacer()
                Text("\(summary.tagBreakdowns.count) tag\(summary.tagBreakdowns.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }
            if summary.tagBreakdowns.isEmpty {
                Text("No sprints in \(summary.monthTitle) yet.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            } else {
                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        ForEach(Array(summary.tagBreakdowns.enumerated()), id: \.element.id) { index, item in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(index))
                                .frame(width: max(2, (proxy.size.width - CGFloat(summary.tagBreakdowns.count - 1) * 2)
                                                  * CGFloat(item.percentage / 100)))
                        }
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
                .accessibilityHidden(true)
                VStack(spacing: 7) {
                    ForEach(Array(summary.tagBreakdowns.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 8) {
                            Circle().fill(color(index)).frame(width: 8, height: 8)
                            Text(item.displayName)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.formattedDuration)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(theme.textPrimary)
                            Text(item.percentageLabel)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .help("\(item.displayName): \(item.formattedDuration), \(item.formattedEarnings), \(item.sprintCount) sprint\(item.sprintCount == 1 ? "" : "s").")
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .monthCard(theme)
    }

    /// Theme accent first, then distinct hues. Used only for dots and bars, never for text.
    private func color(_ index: Int) -> Color {
        let palette: [Color] = [theme.accentColor, .indigo, theme.successText, .purple, .pink, .teal, .brown, .gray]
        return palette[index % palette.count]
    }
}
