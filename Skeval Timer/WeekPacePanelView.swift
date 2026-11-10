import SwiftUI

/// The Week page's highlight: the pace the rest of the week needs, beside the pace so far.
/// Amber when behind or above the daily goal, green when on schedule, neutral for a missed past week.
struct WeekPacePanelView: View {
    let pace: WeekPace
    let theme: PopoverTheme
    var onChangeSchedule: () -> Void = {}

    private enum Tone { case warning, success, neutral }

    private var tone: Tone {
        switch pace.status {
        case .reached, .met, .ahead, .onSchedule:
            return (pace.neededVersusGoal ?? 0) > 59 ? .warning : .success
        case .behind: return .warning
        case .missed: return .neutral
        }
    }

    private var toneText: Color {
        switch tone {
        case .warning: theme.warningText
        case .success: theme.successText
        case .neutral: theme.textPrimary
        }
    }

    private var toneFill: Color {
        switch tone {
        case .warning: Color.orange.opacity(theme.isLight ? 0.12 : 0.16)
        case .success: theme.successText.opacity(0.12)
        case .neutral: theme.cardBorder.opacity(0.3)
        }
    }

    private var toneStroke: Color {
        switch tone {
        case .warning: Color.orange.opacity(0.45)
        case .success: theme.successText.opacity(0.45)
        case .neutral: theme.cardBorder
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("PACE", systemImage: "gauge.with.needle")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .kerning(0.8)
                    .foregroundColor(theme.textPrimary)
                statusPill
                Spacer(minLength: 0)
            }
            figures
            gauge
            if pace.exceedsCapacity { capacityWarning }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(toneFill, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(toneStroke, lineWidth: 1))
        .help(helpText)
    }

    // MARK: - Pieces

    private var statusPill: some View {
        Text(statusText)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(toneText)
            .padding(.horizontal, 9).padding(.vertical, 3.5)
            .background(toneStroke.opacity(0.35), in: Capsule())
    }

    @ViewBuilder private var figures: some View {
        HStack(alignment: .top, spacing: 28) {
            if let needed = pace.neededPerWorkingDay {
                VStack(alignment: .leading, spacing: 8) {
                    figure(caption: "NEEDED PER WORKDAY", value: duration(roundedUp(needed)), large: true, color: toneText,
                           detail: neededDetail)
                    if let versus = pace.neededVersusGoal { versusChip(versus) }
                }
                paceSoFarFigure(large: false)
            } else if pace.isCurrentWeek && pace.remainingSeconds > 0 {
                figure(caption: "STILL TO WORK", value: duration(pace.remainingSeconds), large: true, color: toneText,
                       detail: "No scheduled workdays left this week. Work on a day off still counts.")
                paceSoFarFigure(large: false)
            } else if pace.isCurrentWeek {
                paceSoFarFigure(large: true)
                figure(caption: "DAILY GOAL", value: goalText, large: false, color: theme.textPrimary,
                       detail: "Anything more is extra this week.")
            } else {
                paceSoFarFigure(large: true)
                figure(caption: "NEEDED", value: pace.plannedPerWorkingDay.map(duration) ?? "—", large: false,
                       color: theme.textPrimary, detail: "per scheduled workday")
            }
        }
    }

    private func paceSoFarFigure(large: Bool) -> some View {
        figure(caption: pace.isCurrentWeek ? "YOUR PACE SO FAR" : "YOUR PACE",
               value: pace.paceSoFar.map(duration) ?? "—", large: large,
               color: large ? toneText : theme.textPrimary,
               detail: pace.workingDaysElapsed > 0 ? "over \(days(pace.workingDaysElapsed, scheduled: true))" : "No scheduled workdays yet")
    }

    private func figure(caption: String, value: String, large: Bool, color: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(caption)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .kerning(0.6)
                .foregroundColor(theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: large ? 32 : 20, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                Text("/ workday")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .opacity(caption == "STILL TO WORK" ? 0 : 1)
            }
            Text(detail)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }

    private func versusChip(_ versus: TimeInterval) -> some View {
        let goal = goalText
        let text = abs(versus) < 60 ? "Matches your \(goal) daily goal"
            : versus > 0
                ? "Requires \(duration(roundedUp(versus))) extra per workday"
                : "Requires \(duration(roundedUp(abs(versus)))) less per workday"
        return Text(text)
            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
            .foregroundColor(versus > 59 ? theme.warningText : theme.textPrimary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(theme.cardBg, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(theme.cardBorder, lineWidth: 1))
    }

    /// Track = pace so far. Markers: the daily goal (label above) and the needed pace (label below).
    private var gauge: some View {
        let needed = pace.neededPerWorkingDay
        let top = max(needed ?? 0, pace.paceSoFar ?? 0, pace.dailyGoalSeconds, 1) * 1.18
        return GeometryReader { proxy in
            let width = proxy.size.width
            let x = { (value: TimeInterval) in width * CGFloat(min(value / top, 1)) }
            ZStack(alignment: .topLeading) {
                Capsule().fill(theme.cardBg)
                    .overlay(Capsule().stroke(theme.cardBorder, lineWidth: 1))
                    .frame(width: width, height: 8).position(x: width / 2, y: 22)
                Capsule().fill(theme.neonTeal)
                    .frame(width: x(pace.paceSoFar ?? 0), height: 8)
                    .position(x: x(pace.paceSoFar ?? 0) / 2, y: 22)
                marker(at: x(pace.dailyGoalSeconds), width: width, color: theme.accentIcon,
                       label: "\(goalText) daily goal", labelColor: theme.accentText, above: true)
                if let needed {
                    marker(at: x(needed), width: width, color: tone == .success ? theme.successText : Color.orange,
                           label: "needed \(duration(roundedUp(needed)))", labelColor: toneText, above: false)
                }
            }
        }
        .frame(height: 46)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func marker(at x: CGFloat, width: CGFloat, color: Color, label: String, labelColor: Color, above: Bool) -> some View {
        Rectangle().fill(color).frame(width: 2.5, height: 18).position(x: x, y: 22)
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(labelColor)
            .fixedSize()
            .position(x: min(max(x, 44), max(width - 44, 44)), y: above ? 5 : 40)
    }

    private var capacityWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("\(duration(pace.remainingSeconds)) doesn't fit in \(days(pace.remainingWorkingDays)) at \(goalText). Work longer days or a day off.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Change schedule…", action: onChangeSchedule)
                .buttonStyle(.link)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundColor(theme.warningText)
    }

    // MARK: - Text

    private var statusText: String { pace.statusLabel }

    private var neededDetail: String {
        let left = "for the \(days(pace.remainingWorkingDays)) left"
        guard let more = pace.neededMoreToday else { return "\(left), not counting today" }
        let today = more < 60 ? "today's share is done" : "\(duration(roundedUp(more))) more today"
        return "\(left), today included · \(today)"
    }

    private var helpText: String {
        let schedule = "Weekly goal: \(duration(pace.targetSeconds)), spread evenly over \(days(pace.scheduledWorkingDays, scheduled: true)). Days off are excluded; work on a day off still counts."
        guard pace.isCurrentWeek else { return "\(schedule) Your pace is the work recorded divided by the week's scheduled workdays." }
        return "\(schedule) Needed per workday gives each remaining scheduled workday the same total. Today counts the work you have already done, including the active sprint's net work."
    }

    private func duration(_ seconds: TimeInterval) -> String { TimeFormatter.format(shortDuration: seconds) }
    /// The daily goal reads "8h", like the rest of the app, when it is a whole number of hours.
    private var goalText: String {
        let minutes = Int(pace.dailyGoalSeconds.rounded()) / 60
        return minutes >= 60 && minutes.isMultiple(of: 60) ? "\(minutes / 60)h" : duration(pace.dailyGoalSeconds)
    }
    private func roundedUp(_ seconds: TimeInterval) -> TimeInterval { ceil(seconds / 60) * 60 }
    private func days(_ count: Int, scheduled: Bool = false) -> String {
        "\(count) \(scheduled ? "scheduled " : "")workday\(count == 1 ? "" : "s")"
    }
}
