import SwiftUI

// Cards for the Analytics page, built from the shared dashboard grammar.

/// The range's totals beside the previous period's, with the change for each.
struct AnalyticsComparisonCard: View {
    let range: AnalyticsRange
    let comparison: AnalyticsComparison
    let goal: GoalSettings
    let theme: PopoverTheme
    let openSettings: () -> Void

    private var previous: AnalyticsTotals? { comparison.previous }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardCardHeader(title: title, icon: "arrow.left.arrow.right", theme: theme) {
                if comparison.isPartial, previous != nil {
                    HStack(spacing: 6) {
                        Text("First \(comparison.comparedDays) day\(comparison.comparedDays == 1 ? "" : "s") of each")
                            .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
                        DashboardInfoButton(text: "This range is still running, so it is compared with the same number of days at the start of the \(range.previousName ?? "previous period"). Completed sprints only; the running sprint counts once you clock out.",
                                            theme: theme, accessibilityTitle: "About this comparison")
                    }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 28) { hero.frame(width: 190, alignment: .leading); rows }
                VStack(alignment: .leading, spacing: 16) { hero; rows }
            }
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private var title: String {
        guard previous != nil, let name = range.previousName else { return "Totals · \(range.label)" }
        return "\(range.label) vs \(name)"
    }

    private var hero: some View {
        let current = comparison.current
        return VStack(alignment: .leading, spacing: 4) {
            Text(TimeFormatter.format(shortDuration: current.workedSeconds))
                .font(.dashboardHero).lineLimit(1).minimumScaleFactor(0.6)
            Text("worked").font(.dashboardCaption).foregroundStyle(theme.textSecondary)
            if goal.hasHourlyRate {
                Text(money(current.earnings))
                    .font(.dashboardMoney).foregroundStyle(theme.successText)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.top, 6)
            } else {
                Button("Set hourly rate", action: openSettings)
                    .buttonStyle(.link)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.top, 6)
            }
            if let previous {
                change(current.workedSeconds - previous.workedSeconds, format: duration)
                    .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var rows: some View {
        let current = comparison.current
        return VStack(spacing: 0) {
            if previous != nil {
                HStack(spacing: 12) {
                    Spacer().frame(width: 110)
                    sectionLabel("This range")
                    sectionLabel(range.previousName ?? "")
                    Spacer().frame(width: 82)
                }
                .padding(.bottom, 4)
            }
            row("Worked", current.workedSeconds, previous?.workedSeconds, format: duration)
            if goal.hasHourlyRate {
                row("Earned", current.earnings, previous?.earnings, format: money)
            }
            row("Days with work", Double(current.daysWithWork), previous.map { Double($0.daysWithWork) }, format: count)
            row("Daily goal met", Double(current.goalMetDays), previous.map { Double($0.goalMetDays) },
                format: count, detail: "of \(current.finishedWorkdays)",
                previousDetail: previous.map { "of \($0.finishedWorkdays)" })
            row("Sprints", Double(current.sprintCount), previous.map { Double($0.sprintCount) }, format: count)
        }
    }

    private func row(_ label: String, _ value: Double, _ prior: Double?, format: @escaping (Double) -> String,
                     detail: String? = nil, previousDetail: String? = nil) -> some View {
        let scale = max(value, prior ?? 0, 1)
        return HStack(spacing: 12) {
            Text(label).font(.dashboardCaption).foregroundStyle(theme.textSecondary)
                .frame(width: 110, alignment: .leading)
            if prior == nil {
                // Nothing to compare with: a plain label and value row.
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(format(value)).font(.system(size: 13, weight: .bold, design: .monospaced))
                    if let detail {
                        Text(detail).font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            } else {
                cell(value, scale: scale, text: format(value), detail: detail, fill: theme.accentColor, emphasized: true)
            }
            if let prior {
                cell(prior, scale: scale, text: format(prior), detail: previousDetail,
                     fill: theme.textSecondary.opacity(0.3), emphasized: false)
                change(value - prior, format: format)
                    .frame(width: 82, alignment: .trailing)
            }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.cardBorder.opacity(0.5)).frame(height: 0.5) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(prior.map { "\(format(value)), \(range.previousName ?? "previous"): \(format($0))" } ?? format(value))
    }

    private func cell(_ value: Double, scale: Double, text: String, detail: String?, fill: Color,
                      emphasized: Bool) -> some View {
        HStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.cardBorder.opacity(0.35))
                    if value > 0 {
                        Capsule().fill(fill).frame(width: max(6, proxy.size.width * value / scale))
                    }
                }
            }
            .frame(height: 8)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(text)
                    .font(.system(size: 12, weight: emphasized ? .bold : .semibold, design: .monospaced))
                    .foregroundStyle(emphasized ? theme.textPrimary : theme.textSecondary)
                if let detail {
                    Text(detail).font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .lineLimit(1)
            .frame(width: 104, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private func change(_ difference: Double, format: (Double) -> String) -> some View {
        let same = abs(difference) < 0.5
        let up = difference > 0
        let color = same ? theme.textSecondary : (up ? theme.successText : theme.warningText)
        return Text(same ? "Same" : "\(up ? "↑" : "↓") \(format(abs(difference)))")
            .font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded)).kerning(0.9)
            .foregroundStyle(theme.textSecondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func duration(_ seconds: Double) -> String { TimeFormatter.format(shortDuration: seconds) }
    private func count(_ value: Double) -> String { "\(Int(value.rounded()))" }
    private func money(_ amount: Double) -> String { EarningsCalculator.format(amount: amount, currencySymbol: goal.currencySymbol) }
}

/// Hours by day or week, with the goal line, days off, and the previous period behind day bars.
struct AnalyticsHoursChart: View {
    let bars: [AnalyticsBar]
    let byWeek: Bool
    let previousName: String?
    let theme: PopoverTheme
    private let height: CGFloat = 190
    private let axisWidth: CGFloat = 34

    /// The most common goal, drawn as the line; partial weeks are judged against their own goal.
    private var referenceGoal: TimeInterval {
        let goals = bars.map(\.goalSeconds).filter { $0 > 0 }
        let counts = Dictionary(grouping: goals, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key ?? 0
    }
    private var scale: TimeInterval {
        max(referenceGoal * 1.25, bars.map(\.seconds).max() ?? 0, bars.compactMap(\.previousSeconds).max() ?? 0, 3600)
    }
    private var showsPrevious: Bool { bars.contains { ($0.previousSeconds ?? 0) > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardCardHeader(title: byWeek ? "Hours by week" : "Hours by day", icon: "chart.bar.fill", theme: theme)
            chart
            labels
            legend
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private var chart: some View {
        let goal = referenceGoal
        return ZStack(alignment: .bottomLeading) {
            ForEach([0, goal / 2, goal], id: \.self) { mark in
                gridLine(mark)
            }
            HStack(alignment: .bottom, spacing: bars.count > 40 ? 2 : 3) {
                ForEach(bars) { bar in column(bar) }
            }
            .padding(.leading, axisWidth)
            if goal > 0 {
                goalLine(goal)
            }
        }
        .frame(height: height)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.cardBorder).frame(height: 1).padding(.leading, axisWidth) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(byWeek ? "Hours by week" : "Hours by day")
    }

    private func column(_ bar: AnalyticsBar) -> some View {
        ZStack(alignment: .bottom) {
            if bar.isDayOff && !byWeek {
                RoundedRectangle(cornerRadius: 3).fill(theme.textSecondary.opacity(theme.isLight ? 0.07 : 0.1))
            }
            if let previous = bar.previousSeconds, previous > 0 {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textSecondary.opacity(0.22))
                    .frame(height: height * previous / scale)
                    .padding(.horizontal, 3)
            }
            if bar.seconds > 0 {
                UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                    .fill(bar.metGoal ? theme.successText : theme.accentColor.opacity(0.75))
                    .frame(height: max(2, height * bar.seconds / scale))
            } else if bar.isUpcoming {
                Capsule().fill(theme.cardBorder).frame(height: 2).padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .help(tooltip(bar))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dateText(bar))
        .accessibilityValue(valueText(bar))
    }

    private func gridLine(_ mark: TimeInterval) -> some View {
        HStack(spacing: 6) {
            Text(hourLabel(mark))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .frame(width: axisWidth - 6, alignment: .trailing)
            Rectangle().fill(theme.cardBorder.opacity(0.5)).frame(height: 0.5)
        }
        .frame(height: 12)
        .offset(y: -(height * mark / scale) + 6)
        .accessibilityHidden(true)
    }

    private func goalLine(_ goal: TimeInterval) -> some View {
        Line().stroke(theme.accentText.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .frame(height: 1.5)
            .overlay(alignment: .trailing) {
                Text("\(hourLabel(goal)) \(byWeek ? "weekly" : "daily") goal")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, 4)
                    .background(theme.cardBg)
                    .fixedSize()
                    .offset(y: -10)
            }
        .padding(.leading, axisWidth)
        .offset(y: -(height * goal / scale))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var labels: some View {
        HStack(spacing: bars.count > 40 ? 2 : 3) {
            ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                Text(axisLabel(bar, index: index))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, axisWidth)
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            swatch(theme.successText, "Met \(byWeek ? "weekly" : "daily") goal")
            swatch(theme.accentColor.opacity(0.75), "Below goal")
            if !byWeek { swatch(theme.textSecondary.opacity(theme.isLight ? 0.07 : 0.1), "Day off") }
            if showsPrevious, let previousName { swatch(theme.textSecondary.opacity(0.22), previousName.prefix(1).uppercased() + previousName.dropFirst()) }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(theme.textSecondary)
        .padding(.leading, axisWidth)
    }

    private func swatch(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private func axisLabel(_ bar: AnalyticsBar, index: Int) -> String {
        let calendar = Calendar(identifier: .gregorian)
        if byWeek {
            let previousMonth = index > 0 ? calendar.component(.month, from: bars[index - 1].start) : -1
            return calendar.component(.month, from: bar.start) != previousMonth
                ? AnalyticsMetrics.label(bar.start, format: "MMM", calendar: calendar) : ""
        }
        if bars.count <= 7 { return AnalyticsMetrics.label(bar.start, format: "EEE d", calendar: calendar) }
        let day = calendar.component(.day, from: bar.start)
        return index == 0 || day % 5 == 1 ? "\(day)" : ""
    }

    private func dateText(_ bar: AnalyticsBar) -> String {
        let calendar = Calendar(identifier: .gregorian)
        if byWeek {
            return "\(AnalyticsMetrics.label(bar.start, format: "MMM d", calendar: calendar)) – \(AnalyticsMetrics.label(bar.end, format: "MMM d", calendar: calendar))"
        }
        return AnalyticsMetrics.label(bar.start, format: "EEE, MMM d", calendar: calendar)
    }

    private func valueText(_ bar: AnalyticsBar) -> String {
        if bar.isUpcoming { return "Upcoming" }
        if bar.seconds == 0 { return bar.isDayOff ? "Day off" : "No work" }
        var text = "\(TimeFormatter.format(shortDuration: bar.seconds)), \(bar.metGoal ? "goal met" : "below goal")"
        if let previous = bar.previousSeconds, let previousName {
            text += ". \(previousName): \(TimeFormatter.format(shortDuration: previous))"
        }
        return text
    }

    private func tooltip(_ bar: AnalyticsBar) -> String { "\(dateText(bar)): \(valueText(bar))" }

    private func hourLabel(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        return hours.rounded() == hours ? "\(Int(hours))h" : TimeFormatter.format(shortDuration: seconds)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { $0.move(to: CGPoint(x: rect.minX, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
    }
}

/// Every day of a year or all time, Monday-first columns, coloured by the Month page's daily goal rules.
struct AnalyticsEveryDayCard: View {
    let days: [DailyBarData]
    let totals: AnalyticsTotals
    let settings: GoalSettings
    let theme: PopoverTheme
    private let spacing: CGFloat = 3
    @State private var width: CGFloat = 780

    private struct Cell: Identifiable {
        let id: String
        let day: DailyBarData?
        let status: MonthCalendarDay.Status?
    }

    private var columns: [[Cell]] {
        let calendar = Calendar(identifier: .gregorian)
        guard let first = days.first else { return [] }
        let lead = (calendar.component(.weekday, from: first.date) + 5) % 7
        let today = calendar.startOfDay(for: Date())
        var cells = (0..<lead).map { Cell(id: "lead-\($0)", day: nil, status: nil) }
        cells += days.map { day in
            let date = calendar.startOfDay(for: day.date)
            let status = MonthCalendar.status(seconds: day.totalSeconds, date: date,
                                              isWorkingDay: settings.isWorkingDay(date, calendar: calendar),
                                              goalSeconds: settings.dailyGoalSeconds, today: today)
            return Cell(id: day.id, day: day, status: status)
        }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
    }

    var body: some View {
        let weeks = columns
        VStack(alignment: .leading, spacing: 12) {
            DashboardCardHeader(title: "Every day", icon: "square.grid.3x3.fill", theme: theme) {
                Text("\(totals.goalMetDays) of \(totals.finishedWorkdays) workdays met \(settings.goalLabel)")
                    .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
            }
            let size = cellSize(weeks.count)
            VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: spacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                            Text(monthLabel(weeks, index))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.textSecondary)
                                .fixedSize()
                                .frame(width: size, alignment: .leading)
                        }
                    }
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: spacing) {
                                ForEach(week) { cell in square(cell).frame(width: size, height: size) }
                            }
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            legend
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    /// Cells fill the card's width, from 6 to 16 points.
    private func cellSize(_ count: Int) -> CGFloat {
        max(6, min(16, (width - CGFloat(count - 1) * spacing) / CGFloat(max(1, count))))
    }

    @ViewBuilder private func square(_ cell: Cell) -> some View {
        if let day = cell.day, let status = cell.status {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill(status, seconds: day.totalSeconds))
                .overlay {
                    if status == .dayOff {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    }
                }
                .opacity(status == .upcoming ? 0.4 : 1)
                .help("\(AnalyticsMetrics.label(day.date, format: "EEE, MMM d, yyyy", calendar: Calendar(identifier: .gregorian))): \(description(status, day))")
                .accessibilityElement()
                .accessibilityLabel(AnalyticsMetrics.label(day.date, format: "EEE, MMM d, yyyy", calendar: Calendar(identifier: .gregorian)))
                .accessibilityValue(description(status, day))
        } else {
            Color.clear
        }
    }

    private func fill(_ status: MonthCalendarDay.Status, seconds: TimeInterval) -> Color {
        let goal = max(1, settings.dailyGoalSeconds)
        switch status {
        case .met: return theme.successText
        case .belowGoal, .shortOfGoal, .extraTime, .today:
            guard seconds > 0 else { return theme.cardBorder.opacity(0.5) }
            return theme.accentColor.opacity(0.25 + 0.6 * min(1, seconds / goal))
        case .missed, .upcoming: return theme.cardBorder.opacity(0.5)
        case .dayOff: return .clear
        }
    }

    private func description(_ status: MonthCalendarDay.Status, _ day: DailyBarData) -> String {
        switch status {
        case .upcoming: return "Upcoming"
        case .dayOff: return "Day off"
        case .missed: return "No work"
        case .met: return "\(day.formattedDuration), goal met"
        default: return day.totalSeconds > 0 ? day.formattedDuration : "No work"
        }
    }

    /// The month name goes on the column that holds the 1st, or on the first column of the range.
    private func monthLabel(_ weeks: [[Cell]], _ index: Int) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let days = weeks[index].compactMap(\.day)
        if let first = days.first(where: { calendar.component(.day, from: $0.date) == 1 }) {
            return AnalyticsMetrics.label(first.date, format: "MMM", calendar: calendar)
        }
        guard index == 0, let date = days.first?.date else { return "" }
        return AnalyticsMetrics.label(date, format: "MMM", calendar: calendar)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            item(theme.successText, "Met \(settings.goalLabel)")
            item(theme.accentColor.opacity(0.6), "Below goal, by hours")
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3).strokeBorder(theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: 10, height: 10)
                Text("Day off")
            }
            item(theme.cardBorder.opacity(0.5), "Workday, no work")
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(theme.textSecondary)
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }
}

/// Time and earnings per tag for the range.
struct AnalyticsTagCard: View {
    let tags: [TagAttribution]
    let showsEarnings: Bool
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardCardHeader(title: "Time by tag", icon: "tag.fill", theme: theme)
            if tags.isEmpty {
                Text("No completed sprints in this range.")
                    .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
            }
            ForEach(tags) { tag in
                HStack(spacing: 10) {
                    Text(tag.displayName).font(.dashboardCaption).foregroundStyle(theme.textPrimary).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(tag.formattedDuration).font(.system(size: 12, weight: .bold, design: .monospaced))
                    Text(tag.percentageLabel).font(.dashboardCaption).foregroundStyle(theme.textSecondary)
                        .frame(width: 42, alignment: .trailing)
                    if showsEarnings {
                        Text(tag.formattedEarnings).font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.successText)
                            .frame(minWidth: 80, alignment: .trailing)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .modifier(WorkInsightsCardStyle(theme: theme))
    }
}

/// Year and All time end in one row per month instead of hundreds of daily rows.
struct AnalyticsMonthlyTotalsCard: View {
    let days: [DailyBarData]
    let settings: GoalSettings
    let exportSprints: [Sprint]
    let profileName: String?
    let theme: PopoverTheme
    @State private var exportMessage: String?
    @State private var exportError: String?

    private struct MonthRow: Identifiable {
        let id: Date
        let totals: AnalyticsTotals
    }

    private var months: [MonthRow] {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()
        let grouped = Dictionary(grouping: days) {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date)) ?? $0.date
        }
        return grouped.map { MonthRow(id: $0.key, totals: AnalyticsTotals.calculate(days: $0.value, settings: settings,
                                                                                    today: today, calendar: calendar)) }
            .sorted { $0.id > $1.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardCardHeader(title: "Monthly totals", icon: "tablecells", theme: theme) {
                Menu {
                    Button("Export CSV…", action: export).disabled(exportSprints.isEmpty)
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("More actions")
                    .help("Export CSV")
            }
            if let exportMessage {
                Label(exportMessage, systemImage: "checkmark.circle.fill")
                    .font(.dashboardCaption).foregroundStyle(theme.successText)
            }
            VStack(spacing: 0) {
                header
                ForEach(months) { month in
                    HStack(spacing: 12) {
                        Text(AnalyticsMetrics.label(month.id, format: "MMM yyyy", calendar: Calendar(identifier: .gregorian)))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(TimeFormatter.format(shortDuration: month.totals.workedSeconds))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        if settings.hasHourlyRate {
                            Text(EarningsCalculator.format(amount: month.totals.earnings, currencySymbol: settings.currencySymbol))
                                .foregroundStyle(theme.successText)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Text("\(month.totals.goalMetDays) of \(month.totals.finishedWorkdays)")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Rectangle().fill(theme.cardBorder.opacity(0.5)).frame(height: 0.5) }
                    .accessibilityElement(children: .combine)
                }
            }
            Text("Open a month on the Month page for its daily timesheet.")
                .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
        .task(id: exportMessage) {
            guard exportMessage != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            exportMessage = nil
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(exportError ?? "") }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("MONTH").frame(maxWidth: .infinity, alignment: .leading)
            Text("WORKED").frame(maxWidth: .infinity, alignment: .trailing)
            if settings.hasHourlyRate { Text("EARNED").frame(maxWidth: .infinity, alignment: .trailing) }
            Text("DAILY GOAL MET").frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(theme.cardBorder.opacity(0.25))
    }

    private func export() {
        let sprints = exportSprints
        CSVExporter.promptSavePanel(sprints: sprints, profileName: profileName, onComplete: { success, url in
            if success, let name = url?.lastPathComponent {
                exportMessage = "Exported \(sprints.count) sprint\(sprints.count == 1 ? "" : "s") to \(name)"
            }
        }, onFailure: { exportError = $0 })
    }
}
