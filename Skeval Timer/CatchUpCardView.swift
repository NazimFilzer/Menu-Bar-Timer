import SwiftUI

struct CatchUpCardView: View {
    let summary: CatchUpSummary
    let dailyGoalLabel: String
    let theme: PopoverTheme

    private var accent: Color { summary.isBehind ? .orange : theme.neonTeal }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(periodTitle, systemImage: "target")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .kerning(0.8)
                Spacer()
                Text(summary.period.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(accent.opacity(0.12), in: Capsule())
            }
            Label(summary.headline, systemImage: summary.isBehind ? "clock.arrow.circlepath" : "checkmark.circle")
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
            HStack(spacing: 6) {
                Text(summary.period == .day ? "Daily goal: \(summary.expectedLabel)" : "Expected through today: \(summary.expectedLabel)")
                Text("·")
                Text("Clocked so far: \(summary.clockedLabel)")
                Spacer()
                Text("\(summary.workingDaysElapsed) working days · \(dailyGoalLabel)/day")
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(theme.textSecondary)
            .monospacedDigit()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.3), lineWidth: 1))
        .help(helpText)
    }

    private var periodTitle: String {
        switch summary.period {
        case .day: "DAILY CATCH-UP"
        case .week: "WEEKLY PACE"
        case .month: "MONTHLY PACE"
        }
    }

    private var helpText: String {
        let calculation = summary.period == .day
            ? "Today's daily goal minus work clocked today."
            : "Daily goal × scheduled working days through today, minus all work clocked in this period."
        return "\(calculation) Includes the active sprint and excludes breaks. Change working days and days off in Settings."
    }
}
