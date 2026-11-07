import SwiftUI

/// Bar chart of daily work for the Week (7 bars) and Month (28–31 narrow bars) pages.
struct ActivityChartView: View {
    struct Style {
        let title: String
        let icon: String
        let currentLabel: String
        let plotHeight: CGFloat
        /// Narrow bars for a whole month: smaller corners and labels, hidden when too tight.
        let compact: Bool

        static let week = Style(title: "WEEKLY ACTIVITY", icon: "chart.bar.fill",
                                currentLabel: "Current Week", plotHeight: 220, compact: false)
        static let month = Style(title: "MONTHLY ACTIVITY", icon: "calendar",
                                 currentLabel: "Current Month", plotHeight: 230, compact: true)
    }

    let style: Style
    let days: [DailyBarData]
    let isCurrent: Bool
    let rangeLabel: String
    let dailyGoalHours: Double
    let dailyGoalLabel: String
    let theme: PopoverTheme
    @Binding var offset: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredDay: DailyBarData? = nil
    @State private var selectedDay: DailyBarData? = nil

    private var activeInspectionDay: DailyBarData? {
        hoveredDay ?? selectedDay
    }

    private var maxChartHours: Double {
        let maxLogged = days.map(\.totalHours).max() ?? 0.0
        let baseline = max(maxLogged, dailyGoalHours, 8.0)
        return baseline * 1.2
    }

    private var barCorner: CGFloat { style.compact ? 4 : 6 }

    var body: some View {
        VStack(spacing: 16) {
            chartHeaderView

            ZStack(alignment: .top) {
                chartPlotArea

                // Inspection tooltip when hovering or clicking a bar
                if let inspecting = activeInspectionDay {
                    inspectionTooltip(for: inspecting)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                }
            }
            .frame(height: style.plotHeight)
        }
        .padding(18)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Header & Navigation

    private var chartHeaderView: some View {
        HStack(alignment: .center) {
            HStack(spacing: 7) {
                Image(systemName: style.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.neonTeal)

                Text(style.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .kerning(0.8)

                if isCurrent {
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

            HStack(spacing: 6) {
                if offset != 0 {
                    Button(action: { move(to: 0) }) {
                        Text(style.currentLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.neonTeal.opacity(0.15))
                            .foregroundColor(theme.neonTeal)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { move(to: offset - 1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .padding(6)
                        .background(theme.cardBg.opacity(0.8))
                        .foregroundColor(theme.textPrimary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Text(rangeLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.cardBg.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button(action: { if offset < 0 { move(to: offset + 1) } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .padding(6)
                        .background(theme.cardBg.opacity(0.8))
                        .foregroundColor(offset < 0 ? theme.textPrimary : theme.textSecondary.opacity(0.4))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(offset >= 0)
            }
        }
    }

    private func move(to newOffset: Int) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
            offset = newOffset
            hoveredDay = nil
            selectedDay = nil
        }
    }

    // MARK: - Chart Plot Area

    private var chartPlotArea: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let availableHeight = proxy.size.height - 35 // Reserve 35pt for X-axis labels
            let count = max(days.count, 1)
            let spacing: CGFloat = style.compact ? (count > 30 ? 4 : 5) : 12
            let rawColumnWidth = (availableWidth - CGFloat(count - 1) * spacing) / CGFloat(count)
            let columnWidth = max(rawColumnWidth, style.compact ? 12 : 36)

            ZStack(alignment: .bottomLeading) {
                goalReferenceLineView(chartHeight: availableHeight, chartWidth: availableWidth)

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(days) { day in
                        barColumn(day: day, columnWidth: columnWidth, chartHeight: availableHeight)
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
        let minimumBar: CGFloat = style.compact ? 5 : 6
        let barHeight = max(chartHeight * CGFloat(heightFraction), day.totalSeconds > 0 ? minimumBar : 0.0)
        let isMetGoal = day.totalHours >= dailyGoalHours && dailyGoalHours > 0
        let isHovered = hoveredDay?.id == day.id || selectedDay?.id == day.id

        return Button {
            selectedDay = selectedDay?.id == day.id ? nil : day
        } label: {
            VStack(spacing: style.compact ? 5 : 6) {
                hoursLabel(day: day, columnWidth: columnWidth)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: barCorner)
                        .fill(theme.cardBg.opacity(0.5))
                        .frame(width: columnWidth, height: chartHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: barCorner)
                                .stroke(theme.cardBorder.opacity(isHovered ? 0.8 : (style.compact ? 0.2 : 0.25)), lineWidth: 1)
                        )

                    if barHeight > 0 {
                        RoundedRectangle(cornerRadius: barCorner)
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
                                radius: style.compact ? (isHovered ? 5 : 2) : (isHovered ? 6 : 3),
                                x: 0,
                                y: 0
                            )
                    }
                }
                .frame(width: columnWidth, height: chartHeight)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                        hoveredDay = hovering ? day : nil
                    }
                }

                dayLabel(day: day, columnWidth: columnWidth)
            }
            .frame(width: columnWidth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TimeFormatter.format(headerDate: day.date))
        .accessibilityValue("\(day.formattedDuration), \(day.formattedEarnings)")
        .accessibilityAddTraits(selectedDay?.id == day.id ? .isSelected : [])
    }

    @ViewBuilder
    private func hoursLabel(day: DailyBarData, columnWidth: CGFloat) -> some View {
        let color = day.isToday ? theme.neonTeal : (day.totalSeconds > 0 ? theme.textPrimary : theme.textSecondary.opacity(0.5))
        if !style.compact {
            Text(day.totalSeconds > 0 ? day.formattedDuration : "—")
                .font(.system(size: 9, weight: day.isToday ? .bold : .medium, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } else if columnWidth >= 22 {
            Text(day.totalSeconds > 0 ? day.formattedDuration : "")
                .font(.system(size: 8, weight: day.isToday ? .bold : .medium, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Spacer().frame(height: 10)
        }
    }

    private func dayLabel(day: DailyBarData, columnWidth: CGFloat) -> some View {
        let corner: CGFloat = style.compact ? 4 : 5
        return VStack(spacing: style.compact ? 1 : 2) {
            if style.compact {
                Text(day.dayNumberLabel)
                    .font(.system(size: 9, weight: day.isToday ? .heavy : .semibold, design: .monospaced))
                    .foregroundColor(day.isToday ? theme.neonTeal : theme.textPrimary)
                if columnWidth >= 20 {
                    Text(String(day.dayOfWeekLabel.prefix(1)))
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                        .foregroundColor(day.isToday ? theme.neonTeal : theme.textSecondary)
                }
            } else {
                Text(day.dayOfWeekLabel)
                    .font(.system(size: 10, weight: day.isToday ? .heavy : .semibold, design: .rounded))
                    .foregroundColor(day.isToday ? theme.neonTeal : theme.textPrimary)
                Text(day.dayNumberLabel)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(day.isToday ? theme.neonTeal : theme.textSecondary)
            }
        }
        .padding(.vertical, style.compact ? 2 : 3)
        .padding(.horizontal, style.compact ? 2 : 6)
        .background(day.isToday ? theme.neonTeal.opacity(0.18) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .stroke(day.isToday ? theme.neonTeal.opacity(0.5) : Color.clear, lineWidth: 1)
        )
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

                let sprints = "\(day.sprintCount) sprint\(day.sprintCount == 1 ? "" : "s")"
                Text(style.compact ? "\(day.dayOfWeekLabel) • \(sprints)" : "\(sprints) logged")
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
