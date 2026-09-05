import SwiftUI

struct MonthlyDashboardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @State private var monthOffset: Int = 0

    private var monthlySummary: MonthlySummary {
        _ = vm.logRevision
        return MonthlyAnalytics.calculate(
            store: vm.store,
            monthOffset: monthOffset,
            referenceDate: Date(),
            settings: vm.goal
        )
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12:
            timeGreeting = "Good morning"
        case 12..<17:
            timeGreeting = "Good afternoon"
        case 17..<22:
            timeGreeting = "Good evening"
        default:
            timeGreeting = "Good night"
        }

        let fullName = NSFullUserName()
        let userName = NSUserName()
        let displayName = !fullName.isEmpty ? fullName.components(separatedBy: " ").first ?? fullName : userName
        if !displayName.isEmpty {
            return "\(timeGreeting), \(displayName) 👋"
        } else {
            return "\(timeGreeting) 👋"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            // Personal Greeting Card with Month-over-Month Pill
            monthlyGreetingCardView

            // 3 Key Metric Cards Row (MTD Total Hours, MTD Earnings, Daily Average)
            metricsRowView

            // Monthly Goal Progress Bar Card
            monthlyGoalProgressCardView

            // 28–31 Day Interactive Bar Chart
            MonthlyChartView(
                summary: monthlySummary,
                dailyGoalHours: vm.goal.dailyGoalHours,
                dailyGoalLabel: vm.goal.goalLabel,
                theme: theme,
                monthOffset: $monthOffset
            )

            // Tag Breakdown Distribution Card
            tagBreakdownCardView

            // Monthly Sprints Log Table
            SprintLogTableView(
                vm: vm,
                monthlySummary: monthlySummary,
                theme: theme,
                title: "MONTHLY SPRINT LOGS"
            )
        }
    }

    // MARK: - Greeting Card & MoM Pill

    private var monthlyGreetingCardView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Text(monthlySubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            // Month-over-Month Comparison Pill
            monthOverMonthPillView
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    private var monthlySubtitle: String {
        if monthlySummary.monthlyGoalPercent >= 100 {
            return "🎉 Outstanding milestone! You've achieved 100% of your monthly goal for \(monthlySummary.monthTitle)."
        } else if monthlySummary.totalSeconds > 0 {
            return "You've logged \(monthlySummary.formattedTotalHours) in \(monthlySummary.monthTitle) (\(monthlySummary.monthlyGoalPercent)% of target)."
        } else {
            return "Start a sprint to track progress toward your \(vm.goal.monthlyGoalLabel) monthly goal."
        }
    }

    private var monthOverMonthPillView: some View {
        let mom = monthlySummary.monthOverMonth
        let tintColor: Color = mom.isPositive ? Color.green : (mom.isNeutral ? theme.textSecondary : Color.orange)
        let iconName: String = mom.isPositive ? "arrow.up.right" : (mom.isNeutral ? "equal" : "arrow.down.right")

        return HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))

            Text(mom.summaryText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))

            if vm.goal.hourlyRate > 0 && !mom.isNeutral {
                Text("(\(mom.formattedEarningsDifference))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tintColor.opacity(0.14))
        .foregroundColor(tintColor)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tintColor.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Metric Cards Row

    private var metricsRowView: some View {
        HStack(spacing: 16) {
            // 1. MTD Total Hours
            MetricCardView(
                title: "MTD TOTAL HOURS",
                value: monthlySummary.formattedTotalHours,
                subtitle: "Monthly Target: \(vm.goal.monthlyGoalLabel)",
                icon: "clock.fill",
                theme: theme
            )

            // 2. MTD Calculated Earnings
            MetricCardView(
                title: "MTD EARNINGS",
                value: monthlySummary.formattedTotalEarnings,
                subtitle: "\(monthlySummary.allMonthSprints.count) sprint\(monthlySummary.allMonthSprints.count == 1 ? "" : "s") in \(monthlySummary.monthTitle)",
                icon: "banknote.fill",
                theme: theme
            )

            // 3. Daily Average for Month
            MetricCardView(
                title: "DAILY AVERAGE",
                value: monthlySummary.formattedDailyAverage,
                subtitle: monthlySummary.isCurrentMonth ? "Month-to-date average" : "Full month average",
                icon: "chart.line.uptrend.xyaxis",
                theme: theme
            )
        }
    }

    // MARK: - Monthly Goal Progress Bar Card

    private var monthlyGoalProgressCardView: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.neonTeal)

                    Text("MONTHLY GOAL PROGRESS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .kerning(0.8)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("\(monthlySummary.monthlyGoalPercent)%")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    Text("of \(vm.goal.monthlyGoalLabel) goal")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(monthlySummary.monthlyGoalPercent >= 100 ? Color.green.opacity(0.18) : theme.neonTeal.opacity(0.15))
                .foregroundColor(monthlySummary.monthlyGoalPercent >= 100 ? Color.green : theme.neonTeal)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            monthlySummary.monthlyGoalPercent >= 100 ? Color.green.opacity(0.4) : theme.neonTeal.opacity(0.3),
                            lineWidth: 1
                        )
                )
            }

            // Metric values: Hours & Earnings
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LOGGED HOURS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .kerning(0.6)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(monthlySummary.formattedTotalHours)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                        Text("/ \(vm.goal.monthlyGoalLabel)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("EARNINGS PROGRESS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .kerning(0.6)

                    Text(monthlySummary.earningsProgressLabel)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.neonTeal)
                }
            }

            // Dual Gradient Progress Bar
            GeometryReader { proxy in
                let width = proxy.size.width
                let progressWidth = width * CGFloat(monthlySummary.monthlyGoalProgress)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.cardBorder.opacity(0.35))
                        .frame(height: 10)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: monthlySummary.monthlyGoalPercent >= 100
                                    ? [Color(red: 0.15, green: 0.82, blue: 0.65), Color(red: 0.08, green: 0.58, blue: 0.45)]
                                    : [theme.neonTeal, theme.neonTeal.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(progressWidth, monthlySummary.totalSeconds > 0 ? 10 : 0), height: 10)
                        .shadow(
                            color: theme.neonTeal.opacity(monthlySummary.monthlyGoalPercent >= 100 ? 0.6 : 0.3),
                            radius: 4,
                            x: 0,
                            y: 0
                        )
                }
            }
            .frame(height: 10)

            // Bottom status footnote
            HStack {
                if monthlySummary.monthlyGoalPercent >= 100 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text("Monthly Goal Achieved")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.green)
                } else {
                    let remainingSec = max(monthlySummary.monthlyGoalSeconds - monthlySummary.totalSeconds, 0)
                    Text("\(TimeFormatter.format(shortDuration: remainingSec)) remaining to hit monthly goal")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                if vm.goal.hourlyRate > 0 {
                    Text("Rate: \(EarningsCalculator.format(amount: vm.goal.hourlyRate, currencySymbol: vm.goal.currencySymbol))/hr")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(18)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Tag Breakdown Card

    private var tagBreakdownCardView: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.neonTeal)

                    Text("TAG DISTRIBUTION & BREAKDOWN")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .kerning(0.8)
                }

                Spacer()

                Text("\(monthlySummary.tagBreakdowns.count) tag\(monthlySummary.tagBreakdowns.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }

            if monthlySummary.tagBreakdowns.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 24))
                            .foregroundColor(theme.textSecondary.opacity(0.4))
                        Text("No tagged sprints in \(monthlySummary.monthTitle)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                // Proportional Multi-Color Segmented Bar
                proportionalTagStatusBar

                // Tag List Rows
                VStack(spacing: 8) {
                    ForEach(Array(monthlySummary.tagBreakdowns.enumerated()), id: \.element.id) { index, item in
                        tagRowView(item: item, color: tagPaletteColor(index: index))
                    }
                }
            }
        }
        .padding(18)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    private var proportionalTagStatusBar: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let totalSec = max(monthlySummary.totalSeconds, 1.0)

            HStack(spacing: 2) {
                ForEach(Array(monthlySummary.tagBreakdowns.enumerated()), id: \.element.id) { index, item in
                    let fraction = CGFloat(item.totalSeconds / totalSec)
                    let segWidth = max(fraction * (totalWidth - CGFloat(monthlySummary.tagBreakdowns.count - 1) * 2), 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(tagPaletteColor(index: index))
                        .frame(width: segWidth, height: 10)
                }
            }
        }
        .frame(height: 10)
    }

    private func tagRowView(item: TagAttribution, color: Color) -> some View {
        HStack(spacing: 12) {
            // Color dot & Tag Name Pill
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(item.displayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
            }
            .frame(width: 140, alignment: .leading)

            // Progress Bar representing share
            GeometryReader { proxy in
                let width = proxy.size.width
                let fillWidth = max(width * CGFloat(item.percentage / 100.0), 3)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.cardBorder.opacity(0.3))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: fillWidth, height: 6)
                }
            }
            .frame(height: 6)

            // Percentage Share
            Text("\(Int(round(item.percentage)))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 45, alignment: .trailing)

            // Duration
            Text(item.formattedDuration)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .frame(width: 65, alignment: .trailing)

            // Earnings
            if vm.goal.hourlyRate > 0 {
                Text(item.formattedEarnings)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.neonTeal)
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
    }

    private func tagPaletteColor(index: Int) -> Color {
        let palette: [Color] = [
            theme.neonTeal,
            Color.cyan,
            Color.indigo,
            Color.purple,
            Color.mint,
            Color.teal,
            Color.blue,
            Color.orange
        ]
        return palette[index % palette.count]
    }
}
