import SwiftUI

struct MonthlyChartView: View {
    let summary: MonthlySummary
    let dailyGoalHours: Double
    let dailyGoalLabel: String
    let theme: PopoverTheme
    @Binding var monthOffset: Int
    @State private var hoveredDay: DailyBarData? = nil
    @State private var selectedDay: DailyBarData? = nil

    private var activeInspectionDay: DailyBarData? {
        hoveredDay ?? selectedDay
    }

    private var maxChartHours: Double {
        let maxLogged = summary.days.map(\.totalHours).max() ?? 0.0
        let baseline = max(maxLogged, dailyGoalHours, 8.0)
        return baseline * 1.2
    }

    var body: some View {
        VStack(spacing: 16) {
            // Navigation & Header Bar
            chartHeaderView

            // Main 28-31 Day Bar Chart Surface
            ZStack(alignment: .top) {
                chartPlotArea

                // Inspection Tooltip overlay when hovering or clicking
                if let inspecting = activeInspectionDay {
                    inspectionTooltip(for: inspecting)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                }
            }
            .frame(height: 230)
        }
        .padding(18)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Header & Month Navigation

    private var chartHeaderView: some View {
        HStack(alignment: .center) {
            // Title & Icon
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.neonTeal)

                Text("MONTHLY ACTIVITY")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .kerning(0.8)

                if summary.isCurrentMonth {
                    Text("CURRENT")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.neonTeal.opacity(0.18))
                        .foregroundColor(theme.neonTeal)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Navigation Controls
            HStack(spacing: 6) {
                if monthOffset != 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            monthOffset = 0
                            hoveredDay = nil
                            selectedDay = nil
                        }
                    }) {
                        Text("Current Month")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.neonTeal.opacity(0.15))
                            .foregroundColor(theme.neonTeal)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Previous Month Arrow
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        monthOffset -= 1
                        hoveredDay = nil
                        selectedDay = nil
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .padding(6)
                        .background(theme.cardBg.opacity(0.8))
                        .foregroundColor(theme.textPrimary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Month Title Label
                Text(summary.monthTitle)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.cardBg.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Next Month Arrow
                Button(action: {
                    if monthOffset < 0 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            monthOffset += 1
                            hoveredDay = nil
                            selectedDay = nil
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .padding(6)
                        .background(theme.cardBg.opacity(0.8))
                        .foregroundColor(monthOffset < 0 ? theme.textPrimary : theme.textSecondary.opacity(0.4))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(monthOffset >= 0)
            }
        }
    }

    // MARK: - Chart Plot Area

    private var chartPlotArea: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let availableHeight = proxy.size.height - 35 // Reserve 35pt for X-axis labels
            let count = max(summary.days.count, 1)
            let spacing: CGFloat = count > 30 ? 4 : 5
            let totalSpacing = CGFloat(count - 1) * spacing
            let rawColumnWidth = (availableWidth - totalSpacing) / CGFloat(count)
            let columnWidth = max(rawColumnWidth, 12)

            ZStack(alignment: .bottomLeading) {
                // Background Grid & Daily Goal Reference Line
                goalReferenceLineView(chartHeight: availableHeight, chartWidth: availableWidth)

                // 28-31 Day Bars
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(summary.days) { day in
                        barColumn(
                            day: day,
                            columnWidth: columnWidth,
                            chartHeight: availableHeight
                        )
                    }
                }
                .frame(width: availableWidth, height: proxy.size.height, alignment: .bottom)
            }
        }
    }

    // MARK: - Goal Reference Line

    private func goalReferenceLineView(chartHeight: CGFloat, chartWidth: CGFloat) -> some View {
        let goalFraction = maxChartHours > 0 ? (dailyGoalHours / maxChartHours) : 0
        let yOffset = chartHeight * CGFloat(1.0 - goalFraction)

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: yOffset))
                path.addLine(to: CGPoint(x: chartWidth, y: yOffset))
            }
            .stroke(
                theme.neonTeal.opacity(0.45),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )

            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 8))
                Text("Daily Goal: \(dailyGoalLabel)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundColor(theme.neonTeal)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.cardBg.opacity(0.9))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.neonTeal.opacity(0.3), lineWidth: 0.8))
            .offset(x: max(chartWidth - 115, 0), y: max(yOffset - 18, 0))
        }
        .frame(height: chartHeight)
    }

    // MARK: - Individual Bar Column

    private func barColumn(day: DailyBarData, columnWidth: CGFloat, chartHeight: CGFloat) -> some View {
        let heightFraction = maxChartHours > 0 ? min(day.totalHours / maxChartHours, 1.0) : 0
        let barHeight = max(chartHeight * CGFloat(heightFraction), day.totalSeconds > 0 ? 5.0 : 0.0)
        let isMetGoal = day.totalHours >= dailyGoalHours && dailyGoalHours > 0
        let isHovered = hoveredDay?.id == day.id || selectedDay?.id == day.id

        return VStack(spacing: 5) {
            // Hours / indicator on top if space permits
            if columnWidth >= 22 {
                Text(day.totalSeconds > 0 ? day.formattedDuration : "")
                    .font(.system(size: 8, weight: day.isToday ? .bold : .medium, design: .monospaced))
                    .foregroundColor(day.isToday ? theme.neonTeal : (day.totalSeconds > 0 ? theme.textPrimary : theme.textSecondary.opacity(0.5)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Spacer().frame(height: 10)
            }

            // Bar Track & Fill
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.cardBg.opacity(0.5))
                    .frame(width: columnWidth, height: chartHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(theme.cardBorder.opacity(isHovered ? 0.8 : 0.2), lineWidth: 1)
                    )

                if barHeight > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: barGradientColors(isToday: day.isToday, isMetGoal: isMetGoal, isHovered: isHovered),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: columnWidth, height: barHeight)
                        .shadow(
                            color: day.isToday ? theme.neonTeal.opacity(0.4) : (isMetGoal ? Color.teal.opacity(0.3) : Color.clear),
                            radius: isHovered ? 5 : 2,
                            x: 0,
                            y: 0
                        )
                }
            }
            .frame(width: columnWidth, height: chartHeight)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredDay = hovering ? day : nil
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    if selectedDay?.id == day.id {
                        selectedDay = nil
                    } else {
                        selectedDay = day
                    }
                }
            }

            // X-Axis Day Number Label
            VStack(spacing: 1) {
                Text(day.dayNumberLabel)
                    .font(.system(size: 9, weight: day.isToday ? .heavy : .semibold, design: .monospaced))
                    .foregroundColor(day.isToday ? theme.neonTeal : theme.textPrimary)

                if columnWidth >= 20 {
                    Text(String(day.dayOfWeekLabel.prefix(1)))
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                        .foregroundColor(day.isToday ? theme.neonTeal : theme.textSecondary)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
            .background(day.isToday ? theme.neonTeal.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(day.isToday ? theme.neonTeal.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .frame(width: columnWidth)
    }

    private func barGradientColors(isToday: Bool, isMetGoal: Bool, isHovered: Bool) -> [Color] {
        if isToday {
            return [theme.neonTeal, theme.neonTeal.opacity(0.75)]
        } else if isMetGoal {
            return [Color(red: 0.15, green: 0.82, blue: 0.65), Color(red: 0.08, green: 0.58, blue: 0.45)]
        } else if isHovered {
            return [theme.neonTeal.opacity(0.9), theme.neonTeal.opacity(0.5)]
        } else {
            return [theme.neonTeal.opacity(0.65), theme.neonTeal.opacity(0.35)]
        }
    }

    // MARK: - Inspection Tooltip

    private func inspectionTooltip(for day: DailyBarData) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(day.dateLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)

                    if day.isToday {
                        Text("Today")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(theme.neonTeal.opacity(0.2))
                            .foregroundColor(theme.neonTeal)
                            .clipShape(Capsule())
                    }
                }

                Text("\(day.dayOfWeekLabel) • \(day.sprintCount) sprint\(day.sprintCount == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }

            Divider().frame(height: 24).background(theme.dividerColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("LOGGED")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .kerning(0.6)
                Text(day.formattedDuration)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.neonTeal)
            }

            Divider().frame(height: 24).background(theme.dividerColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("EARNINGS")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .kerning(0.6)
                Text(day.formattedEarnings)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
            }

            if dailyGoalHours > 0 {
                Divider().frame(height: 24).background(theme.dividerColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("GOAL")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .kerning(0.6)
                    let pct = Int(round(day.goalProgress * 100))
                    Text("\(pct)%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(pct >= 100 ? Color.green : theme.textPrimary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.bgDark.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.neonTeal.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
        .padding(.top, 4)
    }
}
