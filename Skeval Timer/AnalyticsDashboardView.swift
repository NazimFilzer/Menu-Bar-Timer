import SwiftUI

struct AnalyticsDashboardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    @State private var selectedPreset: DateRangePreset = .last30Days
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var hoveredHeatmapCell: HeatmapDayCell? = nil
    @State private var hoveredTrendPoint: TrendDataPoint? = nil
    @State private var exportSuccessMessage: String? = nil

    private var activeDateRange: (start: Date, end: Date) {
        if selectedPreset == .custom {
            return (customStartDate, customEndDate)
        } else {
            return selectedPreset.dateRange()
        }
    }

    private var periodSummary: PeriodSummary {
        _ = vm.logRevision
        let range = activeDateRange
        return InsightsAnalytics.calculatePeriodSummary(
            store: vm.store,
            startDate: range.start,
            endDate: range.end,
            settings: vm.goal
        )
    }

    private var annualHeatmap: AnnualHeatmapMatrix {
        _ = vm.logRevision
        return InsightsAnalytics.generateAnnualHeatmap(
            store: vm.store,
            year: selectedYear,
            settings: vm.goal
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Filter & Action Bar
                topFilterAndActionBar

                // Period Summary Cards Row (Total Hours, Total Earnings, Daily Average, Total Sprints)
                periodSummaryCardsRow

                // Long-Term Productivity Trend Curve Chart
                trendLineChartCard

                // GitHub-Style Annual Contribution Heatmap (52 Weeks)
                annualHeatmapCard

                // Sprints in Selected Period Table
                SprintLogTableView(
                    vm: vm,
                    sprints: periodSummary.sprints,
                    distinctTags: periodSummary.distinctTags,
                    defaultDate: periodSummary.endDate,
                    theme: theme,
                    title: "SPRINTS IN SELECTED PERIOD (\(periodSummary.sprints.count))"
                )
            }
            .padding(20)
        }
    }

    // MARK: - Top Filter & Action Bar

    private var topFilterAndActionBar: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                // Preset Segmented Control
                HStack(spacing: 3) {
                    ForEach(DateRangePreset.allCases) { preset in
                        let isSelected = selectedPreset == preset
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedPreset = preset
                            }
                        }) {
                            Text(preset.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSelected ? theme.neonTeal.opacity(0.2) : Color.clear)
                                .foregroundColor(isSelected ? theme.neonTeal : theme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(theme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))

                Spacer()

                // Export to CSV Button
                Button(action: {
                    exportCurrentPeriodCSV()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Export to CSV")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(theme.neonTeal)
                    .foregroundColor(theme.actionButtonForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .shadow(color: theme.neonTeal.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            // Custom Date Range Inputs if "Custom" is selected
            if selectedPreset == .custom {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Text("From:")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                        DatePicker("", selection: $customStartDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    HStack(spacing: 6) {
                        Text("To:")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                        DatePicker("", selection: $customEndDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    Spacer()

                    Text(periodSummary.dateRangeLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.neonTeal)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.cardBg.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))
            }

            // Success feedback notification banner if exported
            if let msg = exportSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(msg)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .transition(.opacity)
            }
        }
    }

    private func exportCurrentPeriodCSV() {
        CSVExporter.promptSavePanel(sprints: periodSummary.sprints) { success, url in
            if success, let path = url?.lastPathComponent {
                withAnimation {
                    exportSuccessMessage = "Successfully exported \(periodSummary.sprints.count) sprints to \(path)"
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation {
                        exportSuccessMessage = nil
                    }
                }
            }
        }
    }

    // MARK: - Period Summary Cards Row

    private var periodSummaryCardsRow: some View {
        HStack(spacing: 16) {
            // 1. Total Hours
            SummaryCard(
                title: "TOTAL LOGGED",
                value: periodSummary.formattedTotalHours,
                subtitle: "\(periodSummary.activeDaysCount) active days / \(periodSummary.totalDaysCount) days",
                icon: "clock.fill",
                theme: theme
            )

            // 2. Total Earnings
            SummaryCard(
                title: "TOTAL EARNINGS",
                value: periodSummary.formattedTotalEarnings,
                subtitle: "Rate: \(EarningsCalculator.format(amount: vm.goal.hourlyRate, currencySymbol: vm.goal.currencySymbol))/hr",
                icon: "banknote.fill",
                theme: theme
            )

            // 3. Daily Average
            SummaryCard(
                title: "DAILY AVERAGE",
                value: periodSummary.formattedDailyAverage,
                subtitle: "Per active working day",
                icon: "chart.line.uptrend.xyaxis",
                theme: theme
            )

            // 4. Sprints Count
            SummaryCard(
                title: "COMPLETED SPRINTS",
                value: "\(periodSummary.totalSprintsCount)",
                subtitle: "\(periodSummary.distinctTags.count) distinct tags used",
                icon: "timer",
                theme: theme
            )
        }
    }

    // MARK: - Trend Line Chart Card

    private var trendLineChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.neonTeal)

                    Text("PRODUCTIVITY TREND LINE")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .kerning(0.8)
                }

                Spacer()

                Text(periodSummary.dateRangeLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
            }

            if periodSummary.trendPoints.isEmpty || periodSummary.totalSeconds == 0 {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "chart.line.flattrend.xyaxis")
                            .font(.system(size: 28))
                            .foregroundColor(theme.textSecondary.opacity(0.4))
                        Text("No completed sprints in this date range")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                // Interactive Curve Surface
                ZStack(alignment: .top) {
                    trendCurvePlotSurface

                    if let point = hoveredTrendPoint {
                        trendInspectionTooltip(for: point)
                    }
                }
                .frame(height: 180)
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

    private var trendCurvePlotSurface: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height - 25 // 25pt for X labels
            let points = periodSummary.trendPoints
            let maxHours = max(points.map(\.totalHours).max() ?? 1.0, 1.0) * 1.15

            let count = max(points.count, 2)
            let stepX = width / CGFloat(count - 1)

            // Calculate coordinates
            let coords: [CGPoint] = points.enumerated().map { idx, pt in
                let x = CGFloat(idx) * stepX
                let y = height * CGFloat(1.0 - (pt.totalHours / maxHours))
                return CGPoint(x: x, y: max(y, 4))
            }

            ZStack(alignment: .bottomLeading) {
                // Area fill under curve
                Path { path in
                    guard let first = coords.first else { return }
                    path.move(to: CGPoint(x: first.x, y: height))
                    path.addLine(to: first)
                    for pt in coords.dropFirst() {
                        path.addLine(to: pt)
                    }
                    if let last = coords.last {
                        path.addLine(to: CGPoint(x: last.x, y: height))
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [theme.neonTeal.opacity(0.3), theme.neonTeal.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line path
                Path { path in
                    guard let first = coords.first else { return }
                    path.move(to: first)
                    for pt in coords.dropFirst() {
                        path.addLine(to: pt)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [theme.neonTeal, theme.neonTeal.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )

                // Data Points
                ForEach(Array(points.enumerated()), id: \.element.id) { idx, pt in
                    let coord = coords[idx]
                    let isHovered = hoveredTrendPoint?.id == pt.id

                    Circle()
                        .fill(isHovered ? Color.white : theme.neonTeal)
                        .frame(width: isHovered ? 8 : 5, height: isHovered ? 8 : 5)
                        .shadow(color: theme.neonTeal, radius: isHovered ? 6 : 2)
                        .position(coord)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                hoveredTrendPoint = hovering ? pt : nil
                            }
                        }
                }

                // X-Axis Labels (first, middle, last)
                HStack {
                    if let first = points.first {
                        Text(first.label)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                    }
                    Spacer()
                    if points.count > 2 {
                        let mid = points[points.count / 2]
                        Text(mid.label)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                    }
                    Spacer()
                    if let last = points.last {
                        Text(last.label)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                .offset(y: height + 6)
            }
        }
    }

    private func trendInspectionTooltip(for point: TrendDataPoint) -> some View {
        HStack(spacing: 10) {
            Text(point.label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            Divider().frame(height: 18).background(theme.dividerColor)

            Text(point.formattedDuration)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.neonTeal)

            if vm.goal.hourlyRate > 0 {
                Divider().frame(height: 18).background(theme.dividerColor)

                Text(EarningsCalculator.format(amount: point.earnings, currencySymbol: vm.goal.currencySymbol))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
            }

            Text("• \(point.sprintCount) sprint\(point.sprintCount == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.bgDark.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.neonTeal.opacity(0.4), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }

    // MARK: - GitHub-Style Annual Contribution Heatmap (52 Weeks)

    private var annualHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with Year Switcher
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.neonTeal)

                    Text("ANNUAL ACTIVITY HEATMAP")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .kerning(0.8)

                    Text("\(annualHeatmap.totalActiveDays) active days")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.neonTeal.opacity(0.18))
                        .foregroundColor(theme.neonTeal)
                        .clipShape(Capsule())
                }

                Spacer()

                // Year Switcher: < 2026 >
                HStack(spacing: 6) {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedYear -= 1
                            hoveredHeatmapCell = nil
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .padding(5)
                            .background(theme.cardBg.opacity(0.8))
                            .foregroundColor(theme.textPrimary)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Text("\(selectedYear)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .frame(minWidth: 44)

                    Button(action: {
                        let currentYear = Calendar.current.component(.year, from: Date())
                        if selectedYear < currentYear {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedYear += 1
                                hoveredHeatmapCell = nil
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .padding(5)
                            .background(theme.cardBg.opacity(0.8))
                            .foregroundColor(selectedYear < Calendar.current.component(.year, from: Date()) ? theme.textPrimary : theme.textSecondary.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedYear >= Calendar.current.component(.year, from: Date()))
                }
            }

            // Heatmap Grid Surface
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Month Headers Row (Aligned with columns)
                    heatmapMonthHeadersRow

                    // Days Grid (7 rows, 52-53 columns) + Day of Week labels on left
                    HStack(alignment: .top, spacing: 6) {
                        // Day of week labels (Mon, Wed, Fri)
                        VStack(spacing: 2.5) {
                            Text("Mon").font(.system(size: 8, weight: .semibold, design: .rounded)).foregroundColor(theme.textSecondary).frame(height: 10)
                            Text("").frame(height: 10)
                            Text("Wed").font(.system(size: 8, weight: .semibold, design: .rounded)).foregroundColor(theme.textSecondary).frame(height: 10)
                            Text("").frame(height: 10)
                            Text("Fri").font(.system(size: 8, weight: .semibold, design: .rounded)).foregroundColor(theme.textSecondary).frame(height: 10)
                            Text("").frame(height: 10)
                            Text("").frame(height: 10)
                        }

                        // 52-53 Week Columns
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 2.5) {
                                ForEach(Array(annualHeatmap.columns.enumerated()), id: \.offset) { colIdx, weekCells in
                                    VStack(spacing: 2.5) {
                                        ForEach(weekCells) { cell in
                                            heatmapCellView(cell: cell)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Hover Tooltip Overlay
                if let cell = hoveredHeatmapCell {
                    heatmapTooltip(for: cell)
                }
            }

            // Bottom Legend & Totals Footnote
            HStack {
                Text("\(annualHeatmap.formattedYearDuration) logged in \(selectedYear) • \(annualHeatmap.formattedYearEarnings) earned")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)

                Spacer()

                // Heatmap Intensity Legend: Less -> More
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary)

                    ForEach(0..<5) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(for: level))
                            .frame(width: 9, height: 9)
                    }

                    Text("More")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
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

    private var heatmapMonthHeadersRow: some View {
        HStack(spacing: 0) {
            // Indent for day of week labels
            Spacer().frame(width: 26)

            HStack(spacing: 0) {
                ForEach(annualHeatmap.monthHeaders, id: \.columnIndex) { header in
                    Text(header.monthName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(height: 12)
    }

    private func heatmapCellView(cell: HeatmapDayCell) -> some View {
        let isHovered = hoveredHeatmapCell?.id == cell.id

        return RoundedRectangle(cornerRadius: 2)
            .fill(heatmapColor(for: cell.intensityLevel))
            .frame(width: 10, height: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isHovered ? Color.white : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    hoveredHeatmapCell = hovering ? cell : nil
                }
            }
    }

    private func heatmapColor(for level: Int) -> Color {
        switch level {
        case 0:
            return theme.cardBorder.opacity(0.35)
        case 1:
            return theme.neonTeal.opacity(0.3)
        case 2:
            return theme.neonTeal.opacity(0.55)
        case 3:
            return theme.neonTeal.opacity(0.8)
        case 4:
            return theme.neonTeal
        default:
            return theme.cardBorder.opacity(0.35)
        }
    }

    private func heatmapTooltip(for cell: HeatmapDayCell) -> some View {
        HStack(spacing: 8) {
            Text(cell.id)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)

            Divider().frame(height: 16).background(theme.dividerColor)

            if cell.totalSeconds > 0 {
                Text(cell.formattedDuration)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.neonTeal)

                Text("(\(cell.sprintCount) sprint\(cell.sprintCount == 1 ? "" : "s"))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)

                if vm.goal.hourlyRate > 0 {
                    Text("• \(cell.formattedEarnings)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                }
            } else {
                Text("No sprints logged")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.bgDark.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.neonTeal.opacity(0.4), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        .offset(y: -28)
    }
}

// Reusable Summary Card
private struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .kerning(0.8)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.neonTeal)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
    }
}
