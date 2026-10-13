import SwiftUI

struct AnalyticsDashboardView: View {
    @Bindable var vm: TimerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let theme: PopoverTheme

    @State private var selectedPreset: DateRangePreset = .last30Days
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var selectedYear: Int = Calendar(identifier: .gregorian).component(.year, from: Date())
    @State private var hoveredHeatmapCell: HeatmapDayCell? = nil
    @State private var hoveredTrendPoint: TrendDataPoint? = nil
    @State private var exportSuccessMessage: String? = nil
    @State private var exportError = ""
    @State private var isExportErrorPresented = false

    private var activeDateRange: (start: Date, end: Date) {
        if selectedPreset == .custom {
            return (customStartDate, customEndDate)
        } else {
            let earliest = vm.store.allLogs().values.flatMap { $0 }
                .filter { !$0.isOpen }.map(\.startTime).min()
            return selectedPreset.dateRange(earliestDate: earliest)
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
        let summary = periodSummary
        let matrix = annualHeatmap
        ScrollView {
            VStack(spacing: 20) {
                // Top Filter & Action Bar
                topFilterAndActionBar(summary: summary)

                // Period Summary Cards Row (Total Hours, Total Earnings, Daily Average, Total Sprints)
                periodSummaryCardsRow(summary: summary)

                // Long-Term Productivity Trend Curve Chart
                trendLineChartCard(summary: summary)

                // GitHub-Style Annual Contribution Heatmap (52 Weeks)
                annualHeatmapCard(matrix: matrix)

                // Sprints in Selected Period Table
                SprintLogTableView(
                    vm: vm,
                    sprints: summary.sprints,
                    distinctTags: summary.distinctTags,
                    defaultDate: summary.endDate,
                    theme: theme,
                    title: "SPRINTS IN SELECTED PERIOD (\(summary.sprints.count))"
                )
            }
            .padding(20)
        }
        .alert("Export failed", isPresented: $isExportErrorPresented) {
            Button("OK", role: .cancel) { }
        } message: { Text(exportError) }
    }

    // MARK: - Top Filter & Action Bar

    private func topFilterAndActionBar(summary: PeriodSummary) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                // Preset Segmented Control
                HStack(spacing: 3) {
                    ForEach(DateRangePreset.allCases) { preset in
                        let isSelected = selectedPreset == preset
                        Button(action: {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
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
                    exportCurrentPeriodCSV(summary: summary)
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
                        DatePicker("Report start date", selection: $customStartDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    HStack(spacing: 6) {
                        Text("To:")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                        DatePicker("Report end date", selection: $customEndDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    Spacer()

                    Text(summary.dateRangeLabel)
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

    private func exportCurrentPeriodCSV(summary: PeriodSummary) {
        let exportedSprints = summary.sprints
        CSVExporter.promptSavePanel(sprints: exportedSprints, onComplete: { success, url in
            if success, let path = url?.lastPathComponent {
                withAnimation {
                    exportSuccessMessage = "Exported \(exportedSprints.count) sprints to \(path)"
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation {
                        exportSuccessMessage = nil
                    }
                }
            }
        }, onFailure: { error in
            exportError = error
            isExportErrorPresented = true
        })
    }

    // MARK: - Period Summary Cards Row

    private func periodSummaryCardsRow(summary: PeriodSummary) -> some View {
        HStack(spacing: 16) {
            // 1. Total Hours
            SummaryCard(
                title: "TOTAL LOGGED",
                value: summary.formattedTotalHours,
                subtitle: "\(summary.activeDaysCount) active days / \(summary.totalDaysCount) days",
                icon: "clock.fill",
                theme: theme
            )

            // 2. Total Earnings
            SummaryCard(
                title: "TOTAL EARNINGS",
                value: summary.formattedTotalEarnings,
                subtitle: "Rate: \(EarningsCalculator.format(amount: vm.goal.hourlyRate, currencySymbol: vm.goal.currencySymbol))/hr",
                icon: "banknote.fill",
                theme: theme
            )

            // 3. Daily Average
            SummaryCard(
                title: "DAILY AVERAGE",
                value: summary.formattedDailyAverage,
                subtitle: "Per active working day",
                icon: "chart.line.uptrend.xyaxis",
                theme: theme
            )

            // 4. Sprints Count
            SummaryCard(
                title: "COMPLETED SPRINTS",
                value: "\(summary.totalSprintsCount)",
                subtitle: "\(summary.distinctTags.count) distinct tags used",
                icon: "timer",
                theme: theme
            )
        }
    }

    // MARK: - Trend Line Chart Card

    private func trendLineChartCard(summary: PeriodSummary) -> some View {
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

                Text(summary.dateRangeLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
            }

            if summary.trendPoints.isEmpty || summary.totalSeconds == 0 {
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
                    trendCurvePlotSurface(summary: summary)

                    if let point = hoveredTrendPoint {
                        trendInspectionTooltip(for: point)
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Productivity trend, \(summary.dateRangeLabel)")
                .accessibilityValue("\(summary.formattedTotalHours), \(summary.formattedTotalEarnings), \(summary.totalSprintsCount) completed sprints")

                DisclosureGroup("Trend data") {
                    trendDataRows(summary: summary)
                }
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
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

    private func trendCurvePlotSurface(summary: PeriodSummary) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height - 25 // 25pt for X labels
            let points = summary.trendPoints
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
                trendArea(coordinates: coords, height: height)
                .fill(
                    LinearGradient(
                        colors: [theme.neonTeal.opacity(0.3), theme.neonTeal.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line path
                trendLine(coordinates: coords)
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
                    trendMarker(point: pt).position(coord)
                }

                // X-Axis Labels (first, middle, last)
                trendLabels(points: points)
                .offset(y: height + 6)
            }
        }
    }

    private func trendDataRows(summary: PeriodSummary) -> some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            Text(summary.totalDaysCount > 31 ? "Intervals of up to 7 days, starting on each date below." : "Daily totals.")
            ForEach(summary.trendPoints) { point in
                HStack {
                    Text(TimeFormatter.format(dateKey: point.date)).monospacedDigit()
                    Spacer()
                    Text(point.formattedDuration)
                    Text(EarningsCalculator.format(amount: point.earnings, currencySymbol: vm.goal.currencySymbol))
                    Text("\(point.sprintCount) sprints")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(TimeFormatter.format(dateKey: point.date))
                .accessibilityValue("\(point.formattedDuration), \(EarningsCalculator.format(amount: point.earnings, currencySymbol: vm.goal.currencySymbol)), \(point.sprintCount) sprints")
            }
        }
        .padding(.top, 8)
    }

    private func trendArea(coordinates: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            guard let first = coordinates.first, let last = coordinates.last else { return }
            path.move(to: CGPoint(x: first.x, y: height))
            path.addLines(coordinates)
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.closeSubpath()
        }
    }

    private func trendLine(coordinates: [CGPoint]) -> Path {
        Path { $0.addLines(coordinates) }
    }

    private func trendMarker(point: TrendDataPoint) -> some View {
        let hovered = hoveredTrendPoint?.id == point.id
        let size: CGFloat = hovered ? 8 : 5
        return Circle()
            .fill(hovered ? Color.white : theme.neonTeal)
            .frame(width: size, height: size)
            .shadow(color: theme.neonTeal, radius: hovered ? 6 : 2)
            .onHover { hoveredTrendPoint = $0 ? point : nil }
            .accessibilityElement()
            .accessibilityLabel(point.label)
            .accessibilityValue("\(point.formattedDuration), \(EarningsCalculator.format(amount: point.earnings, currencySymbol: vm.goal.currencySymbol)), \(point.sprintCount) sprints")
    }

    private func trendLabels(points: [TrendDataPoint]) -> some View {
        HStack {
            if let first = points.first { trendLabel(first.label) }
            Spacer()
            if points.count > 2 { trendLabel(points[points.count / 2].label) }
            Spacer()
            if let last = points.last { trendLabel(last.label) }
        }
    }

    private func trendLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(theme.textSecondary)
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

    // MARK: - Annual Contribution Heatmap

    private func annualHeatmapCard(matrix: AnnualHeatmapMatrix) -> some View {
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

                    Text("\(matrix.totalActiveDays) active days")
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
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
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
                    .accessibilityLabel("Previous year")
                    .disabled(selectedYear <= 1)

                    Text(String(selectedYear))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .frame(minWidth: 44)

                    Button(action: {
                        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
                        if selectedYear < currentYear {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedYear += 1
                                hoveredHeatmapCell = nil
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .padding(5)
                            .background(theme.cardBg.opacity(0.8))
                            .foregroundColor(selectedYear < Calendar(identifier: .gregorian).component(.year, from: Date()) ? theme.textPrimary : theme.textSecondary.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next year")
                    .disabled(selectedYear >= Calendar(identifier: .gregorian).component(.year, from: Date()))
                }
            }

            // Heatmap Grid Surface
            ZStack(alignment: .top) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(spacing: 2.5) {
                        ForEach(0..<7) { row in
                            Text(["Mon", "", "Wed", "", "Fri", "", ""][row])
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 26, height: 10)
                        }
                    }
                    .padding(.top, 20)
                    .accessibilityHidden(true)

                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 6) {
                            heatmapMonthHeadersRow(matrix: matrix)
                            HStack(spacing: 2.5) {
                                ForEach(Array(matrix.columns.enumerated()), id: \.offset) { _, cells in
                                    VStack(spacing: 2.5) {
                                        ForEach(cells) { cell in heatmapCellView(cell: cell) }
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
                Text("\(matrix.formattedYearDuration) logged in \(String(selectedYear)) • \(matrix.formattedYearEarnings) earned")
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

    private func heatmapMonthHeadersRow(matrix: AnnualHeatmapMatrix) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(matrix.monthHeaders, id: \.columnIndex) { header in
                Text(header.monthName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .offset(x: CGFloat(header.columnIndex) * 12.5)
            }
        }
        .frame(width: CGFloat(matrix.columns.count) * 12.5 - 2.5, height: 12, alignment: .topLeading)
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
                hoveredHeatmapCell = hovering ? cell : nil
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(TimeFormatter.format(headerDate: cell.date))
            .accessibilityValue("\(cell.formattedDuration), \(cell.formattedEarnings), \(cell.sprintCount) sprints")
            .accessibilityHidden(!cell.isInSelectedYear)
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
