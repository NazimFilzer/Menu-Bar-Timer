import SwiftUI

struct GoalConsistencyCardView: View {
    let summary: GoalConsistency
    let dailyGoalLabel: String
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily goal consistency").font(.headline)
            Text(rateLabel).font(.subheadline).monospacedDigit()
            ScrollView(.horizontal) {
                LazyVStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Week / start date").frame(width: 112, alignment: .leading)
                        ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                            Text(day).frame(width: 56)
                        }
                        Text("Met").frame(width: 50)
                        Text("Rate").frame(width: 50)
                    }
                    .foregroundStyle(theme.textSecondary)
                    ForEach(summary.weeks.indices, id: \.self) { index in
                        weekRow(summary.weeks[index], number: index + 1)
                    }
                }
                .font(.caption)
            }
            Text("✓ Goal met. Numbers show net work hours below the goal. 0 means no work recorded. — means an unworked day off. · means outside the selected period.")
                .font(.caption).foregroundStyle(theme.textSecondary)
            Text("Each week is measured against your scheduled working days. Saturday, Sunday, and days off count as extra time and never count against your consistency rate.")
                .font(.caption).foregroundStyle(theme.textSecondary)
            Text("Today is in progress and does not count in the rate.")
                .font(.caption).foregroundStyle(theme.textSecondary)
            Text("Weeks start on Monday. Week 1 contains the first day of the selected month.")
                .font(.caption).foregroundStyle(theme.textSecondary)
            Text("Past days use your current daily goal of \(dailyGoalLabel) and your current working schedule.")
                .font(.caption).foregroundStyle(theme.textSecondary)
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private var rateLabel: String {
        guard summary.countedDays > 0 else { return "No finished working days in this period." }
        return "\(summary.metDays) of \(summary.countedDays) days met the goal · \(rate(met: summary.metDays, total: summary.countedDays))"
    }

    private func rate(met: Int, total: Int) -> String {
        guard total > 0 else { return "—" }
        return (Double(met) / Double(total)).formatted(.percent.precision(.fractionLength(0)))
    }

    private func weekRow(_ week: GoalConsistencyWeek, number: Int) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Week \(number)").fontWeight(.semibold)
                Text("Starts \(week.start.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption2).foregroundStyle(theme.textSecondary)
            }
            .frame(width: 112, alignment: .leading)
            ForEach(week.days) { day in
                Text(cellLabel(day))
                    .frame(width: 56, height: 28)
                    .background(cellColor(day).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(day.status == .inProgress ? theme.neonTeal : Color.clear))
                    .help(detail(day))
                    .accessibilityLabel(detail(day))
            }
            Text("\(week.metDays)/\(week.countedDays)").frame(width: 50)
            Text(rate(met: week.metDays, total: week.countedDays)).frame(width: 50)
        }
        .monospacedDigit()
    }

    private func cellLabel(_ day: GoalConsistencyDay) -> String {
        switch day.status {
        case .met: return "✓"
        case .belowGoal, .extraTime:
            // Do not round an unmet goal up to the goal's hour value.
            return (floor(day.seconds / 360) / 10).formatted(.number.precision(.fractionLength(1)))
        case .inProgress: return "Today"
        case .excluded: return "—"
        case .outsideRange: return "·"
        }
    }

    private func cellColor(_ day: GoalConsistencyDay) -> Color {
        switch day.status {
        case .met: return .green
        case .belowGoal: return .orange
        case .extraTime: return theme.neonTeal
        default: return theme.textSecondary
        }
    }

    private func detail(_ day: GoalConsistencyDay) -> String {
        let date = day.date.formatted(date: .complete, time: .omitted)
        let work = TimeFormatter.format(shortDuration: day.seconds)
        switch day.status {
        case .met:
            let extra = day.isScheduledWorkingDay ? "" : " (extra time)"
            return "\(date): \(work), goal met\(extra)."
        case .belowGoal: return "\(date): \(work), below goal."
        case .extraTime: return "\(date): \(work), extra time on a day off."
        case .inProgress: return "\(date): today is in progress. Excluded from the rate."
        case .excluded: return "\(date): no recorded work on a day off. Excluded from the rate."
        case .outsideRange: return "\(date): outside the selected period."
        }
    }
}
