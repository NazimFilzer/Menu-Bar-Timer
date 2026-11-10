import SwiftUI

/// One card for the day's goal: progress, time left, finish forecast, upcoming breaks, and week pace.
/// It replaces the separate goal, catch-up, and finish-forecast cards, so the goal shows once.
struct DailyGoalCardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(vm.displayedGoalTitle.uppercased()) · \(vm.goal.goalLabel)")
                    .font(.caption.weight(.bold)).kerning(0.8)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text("\(vm.displayedProgressPercent)%").font(.subheadline).monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
            }
            ProgressView(value: vm.displayedProgressFraction)
                .tint(vm.isDisplayedGoalReached ? .green : theme.neonTeal)
                .accessibilityLabel("Daily goal progress")
                .accessibilityValue("\(vm.displayedProgressPercent) percent")
            remainingLine
            if vm.isViewingToday {
                Divider().overlay(theme.cardBorder)
                forecast
                paceRow
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))
        .foregroundStyle(theme.textPrimary)
    }

    @ViewBuilder private var remainingLine: some View {
        if vm.isDisplayedGoalReached {
            Label("Daily goal reached", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(theme.successText)
        } else {
            let left = max(0, vm.goal.dailyGoalSeconds - vm.displayedAccumulatedTotal)
            Text("\(TimeFormatter.format(shortDuration: left)) remaining").font(.headline)
        }
    }

    // MARK: Finish forecast

    private var forecast: some View {
        // Refresh conditional estimates while idle, when the engine has no ticker.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            // Engine ticks can redraw between timeline updates; do not reuse context.date.
            let forecast = vm.finishForecast(now: Date())
            VStack(alignment: .leading, spacing: 8) {
                Label("WHEN CAN I FINISH?", systemImage: "clock.badge.checkmark")
                    .font(.caption.weight(.bold)).kerning(0.8)
                    .foregroundStyle(theme.textSecondary)
                projection(forecast)
                breaksStepper
            }
            .onChange(of: Calendar.current.startOfDay(for: context.date)) { _, _ in
                vm.checkAndHandleDayChange()
            }
        }
        .onAppear { vm.checkAndHandleDayChange() }
    }

    private func projection(_ forecast: FinishForecast) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let finish = forecast.finishDate {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Around")
                    Text(finish, format: .dateTime.hour().minute())
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.accentText).monospacedDigit()
                    if forecast.finishesAfterToday {
                        Text(finish, format: .dateTime.month(.abbreviated).day())
                    }
                }
                .accessibilityElement(children: .combine)
                if forecast.finishesAfterToday {
                    Label("This estimate crosses midnight. A sprint stays credited to its start day.",
                          systemImage: "moon.stars")
                        .font(.caption).foregroundStyle(theme.warningText)
                }
            } else {
                Text(headline(for: forecast.status)).font(.title3.weight(.semibold))
            }
            Text(assumption(for: forecast.status))
                .font(.caption).foregroundStyle(theme.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var breaksStepper: some View {
        VStack(alignment: .leading, spacing: 2) {
            Stepper(value: $vm.plannedBreakMinutes, in: 0...240, step: 5) {
                Text("Upcoming breaks: \(vm.plannedBreakMinutes) min").font(.subheadline).monospacedDigit()
            }
            .accessibilityLabel("Upcoming break allowance in minutes")
            .accessibilityHint(Self.breaksHelp)
            .help(Self.breaksHelp)
            // The same words as the tooltip, so keyboard and VoiceOver users see them too.
            Text("Count only breaks still ahead. This does not pause the timer. It resets each day.")
                .font(.caption).foregroundStyle(theme.textSecondary)
        }
    }

    private static let breaksHelp = "Add only breaks still ahead, including lunch. Reduce this allowance after taking a break. It does not pause the timer or edit logged work. Resets each day and on app restart."

    // MARK: Pace

    private var paceRow: some View {
        let week = vm.catchUpSummary(for: .week)
        let label = "Week pace: \(week.compactLabel)"
        return HStack {
            Label(label, systemImage: week.isBehind ? "clock.arrow.circlepath" : "checkmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(week.isBehind ? theme.warningText : theme.accentText)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background((week.isBehind ? theme.warningText : theme.accentText).opacity(0.12), in: Capsule())
            Spacer()
        }
        .help("Daily goal × scheduled working days through today, minus all work clocked this week. Change working days and days off in Settings.")
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
        switch status {
        case .working: return "If you keep working, with only the upcoming breaks above. This is an estimate, not a scheduled clock-out."
        case .startNow: return "If you clock in now and take only the upcoming breaks above."
        case .resumeNow: return "If you resume now and take only the upcoming breaks above. Time already paused is not added again."
        case .goalReached: return "No more work is needed for today's daily goal. Upcoming breaks do not change this."
        case .recovery: return "Resolve your recovery sprint to forecast today's goal."
        case .sleepHeld: return "The daily estimate is held until you classify sleep."
        case .previousDaySprint: return "Clock out and start a sprint today to forecast today's goal."
        }
    }
}
