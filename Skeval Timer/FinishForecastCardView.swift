import SwiftUI

struct FinishForecastCardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        // Refresh conditional estimates while idle, when the engine has no ticker.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            // Engine ticks can redraw between timeline updates; do not reuse context.date.
            let forecast = vm.finishForecast(now: Date())
            VStack(alignment: .leading, spacing: 14) {
                Label("WHEN CAN I FINISH?", systemImage: "clock.badge.checkmark")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .kerning(0.8)
                dailyProjection(forecast)
                Stepper(value: $vm.plannedBreakMinutes, in: 0...240, step: 5) {
                    Text("Upcoming breaks: \(vm.plannedBreakMinutes) min")
                        .font(.subheadline).monospacedDigit()
                }
                .accessibilityLabel("Upcoming break allowance in minutes")
                .help("Add only breaks still ahead, including lunch. Reduce this allowance after taking a break. It does not pause the timer or edit logged work. Resets each day and on app restart.")
                Divider()
                weeklyPace(forecast)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.neonTeal.opacity(0.3), lineWidth: 1))
            .foregroundStyle(theme.textPrimary)
            .onChange(of: Calendar.current.startOfDay(for: context.date)) { _, _ in
                vm.checkAndHandleDayChange()
            }
        }
        .onAppear { vm.checkAndHandleDayChange() }
    }

    private func dailyProjection(_ forecast: FinishForecast) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let finish = forecast.finishDate {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Around")
                    Text(finish, format: .dateTime.hour().minute())
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.neonTeal).monospacedDigit()
                    if forecast.finishesAfterToday {
                        Text(finish, format: .dateTime.month(.abbreviated).day())
                    }
                }
                .accessibilityElement(children: .combine)
                Text("\(duration(forecast.remainingToday)) net work left toward your daily goal · \(vm.plannedBreakMinutes) min upcoming breaks")
                    .font(.subheadline)
                if forecast.finishesAfterToday {
                    Text("This estimate crosses midnight. A sprint stays credited to its start day; new sprints after midnight count toward the next day.")
                        .font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text(headline(for: forecast.status))
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
            }
            Text(assumption(for: forecast.status))
                .font(.caption).foregroundStyle(theme.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func weeklyPace(_ forecast: FinishForecast) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Spread catch-up across this week").font(.subheadline.weight(.semibold))
            Text(weeklyHeadline(forecast)).font(.subheadline).monospacedDigit()
            if let extra = forecast.extraSecondsPerWorkingDay, extra > 0 {
                Text("About \(duration(extra)) above your normal daily goal per remaining workday.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if forecast.exceedsWeeklyCapacity {
                Text("More work remains than the calendar time on your remaining scheduled days. Overnight or off-day work can still count; consider revising the plan.")
                    .font(.caption).foregroundStyle(.orange)
            }
            Text("Remaining net work, not extra hours. Uses your daily work schedule—not the separate weekly goal. Breaks excluded.")
                .font(.caption).foregroundStyle(theme.textSecondary)
                .help("Daily goal × scheduled working days this week, minus work clocked so far. Respects days off. Today's workday is included only when scheduled.")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func weeklyHeadline(_ forecast: FinishForecast) -> String {
        if forecast.weeklyRemaining == 0 { return "This week's scheduled target is reached." }
        guard let pace = forecast.weeklySecondsPerDay else {
            return "\(duration(forecast.weeklyRemaining)) remaining · no scheduled working days left this week."
        }
        let days = forecast.remainingWorkingDays
        let today = forecast.includesToday ? "including today" : "excluding today"
        return "\(duration(forecast.weeklyRemaining)) left · about \(duration(pace))/workday across \(days) remaining \(days == 1 ? "day" : "days") (\(today))."
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
        case .recovery: return "Unresolved recovery time is excluded from both projections."
        case .sleepHeld: return "The daily estimate is held until you classify sleep. Weekly pace may change after resolution."
        case .previousDaySprint: return "Clock out and start a sprint today to forecast today's goal. The current sprint still contributes to its start week's catch-up."
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        // Round projections up to a minute so the displayed pace never understates work.
        TimeFormatter.format(shortDuration: ceil(seconds / 60) * 60)
    }
}
