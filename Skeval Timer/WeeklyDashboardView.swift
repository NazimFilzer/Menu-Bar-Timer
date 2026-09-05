import SwiftUI

struct WeeklyDashboardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @State private var weekOffset: Int = 0

    private var weeklySummary: WeeklySummary {
        _ = vm.logRevision
        return WeeklyAnalytics.calculate(
            store: vm.store,
            weekOffset: weekOffset,
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
            // Personal Greeting Card
            greetingCardView

            // 3 Key Metric Cards Row
            metricsRowView

            // Weekly Target Progress Bar Card
            weeklyTargetProgressCardView

            // Interactive 7-Day Bar Chart
            WeeklyChartView(
                summary: weeklySummary,
                dailyGoalHours: vm.goal.dailyGoalHours,
                dailyGoalLabel: vm.goal.goalLabel,
                theme: theme,
                weekOffset: $weekOffset
            )

            // Interactive Sprint Log CRUD Table
            SprintLogTableView(
                vm: vm,
                summary: weeklySummary,
                theme: theme
            )
        }
    }

    // MARK: - Greeting Card

    private var greetingCardView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Text(weeklySubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            // Quick live sprint status pill
            if vm.isRunning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(theme.statusColor(for: vm.state))
                        .frame(width: 8, height: 8)
                    Text("Sprint in Progress: \(vm.currentElapsedLabel)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.neonTeal)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.neonTeal.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.neonTeal.opacity(0.4), lineWidth: 1))
            }
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

    private var weeklySubtitle: String {
        if weeklySummary.weeklyGoalPercent >= 100 {
            return "🎉 Fantastic work! You've achieved 100% of your weekly goal."
        } else if weeklySummary.totalSeconds > 0 {
            return "You've logged \(weeklySummary.formattedTotalHours) this week (\(weeklySummary.weeklyGoalPercent)% of your target)."
        } else {
            return "Start a sprint to log your progress toward your \(vm.goal.weeklyGoalLabel) weekly goal."
        }
    }

    // MARK: - Metric Cards Row

    private var metricsRowView: some View {
        HStack(spacing: 16) {
            // 1. Today's Hours
            MetricCardView(
                title: "TODAY'S HOURS",
                value: vm.todayLog.accumulatedShortLabel,
                subtitle: "Daily Target: \(vm.goal.goalLabel)",
                icon: "clock.fill",
                theme: theme
            )

            // 2. Today's Earnings
            MetricCardView(
                title: "TODAY'S EARNINGS",
                value: vm.todayEarningsLabel,
                subtitle: "\(vm.todayLog.completedSprints.count) sprint\(vm.todayLog.completedSprints.count == 1 ? "" : "s") logged",
                icon: "banknote.fill",
                theme: theme
            )

            // 3. Current Week's Daily Average
            MetricCardView(
                title: "DAILY AVERAGE",
                value: weeklySummary.formattedDailyAverage,
                subtitle: weeklySummary.isCurrentWeek ? "Current week average" : "Historical week average",
                icon: "chart.line.uptrend.xyaxis",
                theme: theme
            )
        }
    }

    // MARK: - Weekly Target Progress Bar Card

    private var weeklyTargetProgressCardView: some View {
        VStack(spacing: 12) {
            // Top Header & Badges
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.neonTeal)

                    Text("WEEKLY GOAL PROGRESS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .kerning(0.8)
                }

                Spacer()

                // Percentage Badge
                HStack(spacing: 4) {
                    Text("\(weeklySummary.weeklyGoalPercent)%")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    Text("of \(vm.goal.weeklyGoalLabel) goal")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(weeklySummary.weeklyGoalPercent >= 100 ? Color.green.opacity(0.18) : theme.neonTeal.opacity(0.15))
                .foregroundColor(weeklySummary.weeklyGoalPercent >= 100 ? Color.green : theme.neonTeal)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            weeklySummary.weeklyGoalPercent >= 100 ? Color.green.opacity(0.4) : theme.neonTeal.opacity(0.3),
                            lineWidth: 1
                        )
                )
            }

            // Metric values: Hours & Earnings
            HStack {
                // Hours progress
                VStack(alignment: .leading, spacing: 2) {
                    Text("LOGGED HOURS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .kerning(0.6)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(weeklySummary.formattedTotalHours)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                        Text("/ \(vm.goal.weeklyGoalLabel)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Spacer()

                // Earnings progress
                VStack(alignment: .trailing, spacing: 2) {
                    Text("EARNINGS PROGRESS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .kerning(0.6)

                    Text(weeklySummary.earningsProgressLabel)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.neonTeal)
                }
            }

            // Visual Dual Gradient Progress Bar
            GeometryReader { proxy in
                let width = proxy.size.width
                let progressWidth = width * CGFloat(weeklySummary.weeklyGoalProgress)

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(theme.cardBorder.opacity(0.35))
                        .frame(height: 10)

                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: weeklySummary.weeklyGoalPercent >= 100
                                    ? [Color(red: 0.15, green: 0.82, blue: 0.65), Color(red: 0.08, green: 0.58, blue: 0.45)]
                                    : [theme.neonTeal, theme.neonTeal.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(progressWidth, weeklySummary.totalSeconds > 0 ? 10 : 0), height: 10)
                        .shadow(
                            color: theme.neonTeal.opacity(weeklySummary.weeklyGoalPercent >= 100 ? 0.6 : 0.3),
                            radius: 4,
                            x: 0,
                            y: 0
                        )
                }
            }
            .frame(height: 10)

            // Bottom status footnote
            HStack {
                if weeklySummary.weeklyGoalPercent >= 100 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text("Weekly Goal Achieved")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.green)
                } else {
                    let remainingSeconds = max(weeklySummary.weeklyGoalSeconds - weeklySummary.totalSeconds, 0)
                    Text("\(TimeFormatter.format(shortDuration: remainingSeconds)) remaining to hit goal")
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
}
