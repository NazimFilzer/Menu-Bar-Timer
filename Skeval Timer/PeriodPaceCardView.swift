import SwiftUI

struct PeriodPaceCardView: View {
    @Bindable var vm: TimerViewModel
    let period: CatchUpPeriod
    let theme: PopoverTheme

    var body: some View {
        let forecast = vm.periodPaceForecast(for: period)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("When can I finish up?", systemImage: "clock.badge.checkmark")
                    .font(.headline)
                Spacer()
                Text(period.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            Text(headline(forecast))
                .font(.subheadline).monospacedDigit()
            if let extra = forecast.extraSecondsPerWorkingDay, extra > 0 {
                Text("About \(duration(extra)) above your normal daily goal per remaining workday.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if forecast.exceedsCapacity {
                Text("More work remains than the calendar time on your remaining scheduled days. Overnight or off-day work can still count; consider revising the plan.")
                    .font(.caption).foregroundStyle(.orange)
            }
            Text(targetDescription(forecast))
                .font(.caption).foregroundStyle(theme.textSecondary)
                .help(helpText)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.neonTeal.opacity(0.3), lineWidth: 1))
        .foregroundStyle(theme.textPrimary)
    }

    private func headline(_ forecast: PeriodPaceForecast) -> String {
        if forecast.remainingSeconds == 0 {
            return period == .month
                ? "Monthly goal reached."
                : "Scheduled target reached for \(period.label.lowercased())."
        }
        guard let pace = forecast.secondsPerWorkingDay else {
            return "\(duration(forecast.remainingSeconds)) remaining · no scheduled working days left \(period.label.lowercased())."
        }
        let days = forecast.remainingWorkingDays
        let today = forecast.includesToday ? "including today" : "excluding today"
        return "\(duration(forecast.remainingSeconds)) left · about \(duration(pace))/workday across \(days) remaining \(days == 1 ? "day" : "days") (\(today))."
    }

    private func duration(_ seconds: TimeInterval) -> String {
        TimeFormatter.format(shortDuration: ceil(seconds / 60) * 60)
    }

    private func targetDescription(_ forecast: PeriodPaceForecast) -> String {
        let targetName = period == .month ? "monthly goal" : "scheduled \(period.label.lowercased())"
        return "\(duration(forecast.targetSeconds)) \(targetName) · \(duration(forecast.clockedSeconds)) clocked. Breaks excluded."
    }

    private var helpText: String {
        let calculation = period == .month
            ? "Monthly goal minus work clocked so far, paced across the remaining scheduled workdays."
            : "Daily goal × scheduled working days in this period, minus work clocked so far."
        return "\(calculation) Respects days off and includes the active sprint's net work. Today is included only when scheduled."
    }
}
