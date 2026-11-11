import SwiftUI

/// Week page: the selected week's navigator, its totals beside the Pace panel, then the day ledger.
/// Every card follows the week chosen in the navigator.
struct WeeklyDashboardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @State private var weekOffset: Int = 0
    @AppStorage("skevalDashboardDestination") private var destinationKey = DashboardDestination.week.rawValue

    private var weeklySummary: WeeklySummary {
        _ = vm.logRevision
        return WeeklyAnalytics.calculate(
            logs: vm.store.allLogs(),
            weekOffset: weekOffset,
            referenceDate: Date(),
            settings: vm.goal
        )
    }

    var body: some View {
        let summary = weeklySummary
        VStack(alignment: .leading, spacing: 16) {
            periodBar(summary: summary)
            // Totals and pace include the active sprint, so only this strip follows the tick.
            Live { summaryStrip(summary: summary) }
            WeekLedgerView(vm: vm, summary: summary, theme: theme)
        }
    }

    // MARK: - Week navigator

    private func periodBar(summary: WeeklySummary) -> some View {
        DashboardPeriodNavigator(periodName: "week", canGoForward: weekOffset < 0,
                                 resetTitle: weekOffset == 0 ? nil : "This week", theme: theme,
                                 move: { weekOffset = min(0, weekOffset + $0) }, reset: { weekOffset = 0 }) {
            DashboardPeriodLabel(text: summary.weekRangeLabel, theme: theme)
        }
    }

    // MARK: - Totals + pace

    private func summaryStrip(summary: WeeklySummary) -> some View {
        let pace = WeekPace.calculate(logs: vm.store.allLogs(), weekStart: summary.weekStartDate,
                                      settings: vm.goal, state: vm.state)
        return HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                total(title: "WORKED", value: TimeFormatter.format(shortDuration: pace.workedSeconds),
                      detail: "of \(vm.goal.weeklyGoalLabel) weekly goal")
                if vm.goal.hasHourlyRate {
                    total(title: "EARNED", value: money(pace.workedSeconds),
                          detail: "of \(money(vm.goal.weeklyGoalSeconds))")
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        label("EARNED")
                        Button("Set hourly rate") { destinationKey = DashboardDestination.settings.rawValue }
                            .buttonStyle(.link)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                }
            }
            .frame(minWidth: 150, alignment: .leading)
            .padding(.top, 4)

            WeekPacePanelView(pace: pace, theme: theme) {
                destinationKey = DashboardDestination.settings.rawValue
            }
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private func total(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(title)
            Text(value)
                .font(.dashboardHero)
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(theme.textPrimary)
            Text(detail)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textSecondary)
        }
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .kerning(0.8)
            .foregroundStyle(theme.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func money(_ seconds: TimeInterval) -> String {
        EarningsCalculator.format(
            amount: EarningsCalculator.calculate(durationInSeconds: seconds, hourlyRate: vm.goal.hourlyRate),
            currencySymbol: vm.goal.currencySymbol)
    }
}
