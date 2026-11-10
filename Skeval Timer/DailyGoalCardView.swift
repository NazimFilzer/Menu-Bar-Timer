import SwiftUI

/// Today's answer card: the finish forecast, upcoming breaks, and week pace.
/// For a past day it shows the day's result against the daily goal instead.
/// Worked time and progress live in the Worked card beside it, so each figure shows once.
struct DailyGoalCardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.isViewingToday {
                forecast
            } else {
                result
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    // MARK: Past day

    private var result: some View {
        let worked = vm.displayedAccumulatedTotal
        let goal = vm.goal.dailyGoalSeconds
        return VStack(alignment: .leading, spacing: 8) {
            DashboardCardHeader(title: "Result", icon: "checkmark.seal", theme: theme)
            DashboardFactRow(label: vm.displayedGoalTitle, value: vm.goal.goalLabel, theme: theme)
            DashboardFactRow(label: "Worked", value: TimeFormatter.format(shortDuration: worked), theme: theme)
            if worked >= goal {
                DashboardFactRow(label: "Over goal", value: TimeFormatter.format(shortDuration: worked - goal),
                                 valueColor: theme.successText, emphasized: true, theme: theme)
            } else {
                DashboardFactRow(label: "Short of goal", value: TimeFormatter.format(shortDuration: goal - worked),
                                 valueColor: theme.warningText, emphasized: true, theme: theme)
            }
        }
    }

    // MARK: Finish forecast

    private var forecast: some View {
        // Refresh conditional estimates while idle, when the engine has no ticker.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            // Engine ticks can redraw between timeline updates; do not reuse context.date.
            let forecast = vm.finishForecast(now: Date())
            VStack(alignment: .leading, spacing: 12) {
                DashboardCardHeader(title: "When can I finish?", icon: "clock.badge.checkmark", theme: theme) {
                    paceBadge
                }
                projection(forecast)
                if forecast.status != .goalReached {
                    Divider().overlay(theme.cardBorder)
                    breaksStepper
                }
            }
            .onChange(of: Calendar.current.startOfDay(for: context.date)) { _, _ in
                vm.checkAndHandleDayChange()
            }
        }
        .onAppear { vm.checkAndHandleDayChange() }
    }

    private func projection(_ forecast: FinishForecast) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let finish = forecast.finishDate {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Around").font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                    Text(finish, format: .dateTime.hour().minute())
                        .font(.dashboardHeroTime).monospacedDigit()
                        .foregroundStyle(theme.accentText)
                    if forecast.finishesAfterToday {
                        Text(finish, format: .dateTime.month(.abbreviated).day())
                            .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
                    }
                    DashboardInfoButton(text: assumption(for: forecast.status), theme: theme,
                                        accessibilityTitle: "About this estimate")
                }
                .accessibilityElement(children: .contain)
                Text(condition(for: forecast.status))
                    .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
                if vm.isPaused {
                    Text("Paused for \(vm.currentPauseLabel)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.warningText)
                }
                if forecast.finishesAfterToday {
                    Label("Crosses midnight. A sprint stays credited to its start day.", systemImage: "moon.stars")
                        .font(.dashboardCaption).foregroundStyle(theme.warningText)
                }
            } else if forecast.status == .goalReached {
                Label("Daily goal reached", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.successText)
                Text("No more work is needed today.")
                    .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
            } else {
                Text(headline(for: forecast.status))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(assumption(for: forecast.status))
                    .font(.dashboardCaption).foregroundStyle(theme.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var breaksStepper: some View {
        Stepper(value: $vm.plannedBreakMinutes, in: 0...240, step: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Upcoming breaks").font(.dashboardCaption).foregroundStyle(theme.textSecondary)
                Spacer(minLength: 8)
                Text("\(vm.plannedBreakMinutes) min")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
        }
        .accessibilityLabel("Upcoming break allowance in minutes")
        .accessibilityValue("\(vm.plannedBreakMinutes) minutes")
        .accessibilityHint(Self.breaksHelp)
        .help(Self.breaksHelp)
    }

    private static let breaksHelp = "Add only breaks still ahead, including lunch. Reduce this allowance after taking a break. It does not pause the timer or edit logged work. Resets each day and on app restart."

    // MARK: Pace

    /// Uses the Week page's pace, so both pages show the same words for the same week.
    private var paceBadge: some View {
        let calendar = Calendar(identifier: .gregorian)
        let weekStart = CatchUpPeriod.week.dates(containing: Date(), calendar: calendar).first ?? Date()
        let pace = WeekPace.calculate(logs: vm.store.allLogs(), weekStart: weekStart,
                                      settings: vm.goal, state: vm.state)
        let isBehind = if case .behind = pace.status { true } else { false }
        let color = isBehind ? theme.warningText : theme.successText
        return Label("\(pace.statusLabel) this week",
                     systemImage: isBehind ? "clock.arrow.circlepath" : "checkmark.circle")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .help("Your weekly goal spread over this week's scheduled workdays, compared with all work clocked this week. The Week page shows the details. Change working days and days off in Settings.")
    }

    private func condition(for status: FinishForecast.Status) -> String {
        switch status {
        case .working: return "If you keep working"
        case .startNow: return "If you clock in now"
        case .resumeNow: return "If you resume now"
        default: return assumption(for: status)
        }
    }

    private func headline(for status: FinishForecast.Status) -> String {
        switch status {
        case .goalReached: return "Daily goal reached"
        case .recovery: return "Resolve your recovery sprint first"
        case .sleepHeld: return "Resolve sleep time first"
        case .previousDaySprint: return "Your current sprint belongs to a previous day"
        default: return "Finish-time estimate"
        }
    }

    private func assumption(for status: FinishForecast.Status) -> String {
        let breaks = "Upcoming breaks count only breaks still ahead, including lunch. They don't pause the timer and reset each day."
        switch status {
        case .working: return "If you keep working, with only the upcoming breaks. This is an estimate, not a scheduled clock-out. \(breaks)"
        case .startNow: return "If you clock in now and take only the upcoming breaks. \(breaks)"
        case .resumeNow: return "If you resume now and take only the upcoming breaks. Time already paused is not added again. \(breaks)"
        case .goalReached: return "No more work is needed for today's daily goal. Upcoming breaks do not change this."
        case .recovery: return "Resolve your recovery sprint to forecast today's goal."
        case .sleepHeld: return "The daily estimate is held until you classify sleep."
        case .previousDaySprint: return "Clock out and start a sprint today to forecast today's goal."
        }
    }
}
