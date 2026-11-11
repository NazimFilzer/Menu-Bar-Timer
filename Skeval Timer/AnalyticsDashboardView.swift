import SwiftUI

/// Analytics page: pick a range, see it against the previous period, then its shape and details.
/// Totals use completed sprints only, like the Week and Month reports.
struct AnalyticsDashboardView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    var openSettings: () -> Void = {}

    @AppStorage("skevalAnalyticsRange") private var kindKey = AnalyticsRangeKind.month.rawValue
    @State private var offset = 0
    @State private var customRange: AnalyticsRange?
    @State private var showingCustom = false
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
    @State private var customEnd = Date()

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }()

    private var kind: AnalyticsRangeKind { AnalyticsRangeKind(rawValue: kindKey) ?? .month }

    var body: some View {
        let _ = vm.logRevision
        let logs = vm.store.allLogs()
        let today = Date()
        let earliest = logs.values.flatMap { $0 }.filter { !$0.isOpen }.map(\.startTime).min()
        let range = customRange ?? AnalyticsRange.make(kind, offset: offset, today: today, earliest: earliest, calendar: calendar)
        let days = AnalyticsComparison.bars(range.dates(calendar: calendar), logs: logs, today: today,
                                            settings: vm.goal, calendar: calendar)
        let comparison = AnalyticsComparison.calculate(range: range, logs: logs, earliest: earliest, today: today,
                                                       settings: vm.goal, calendar: calendar)
        let byWeek = range.drawsWeeks(calendar: calendar)
        // Previous bars cover the same days the comparison card compares.
        let previousDays = comparison.previous == nil || byWeek ? nil
            : AnalyticsComparison.bars(Array(range.previousDates(calendar: calendar).prefix(comparison.comparedDays)),
                                       logs: logs, today: today, settings: vm.goal, calendar: calendar)
        let bars = AnalyticsBar.make(days: days, previousDays: previousDays, byWeek: byWeek, settings: vm.goal,
                                     today: today, calendar: calendar)
        let sprints = days.flatMap(\.completedSprints)
        let worked = days.reduce(0) { $0 + $1.totalSeconds }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                rangeBar(range)
                AnalyticsComparisonCard(range: range, comparison: comparison, goal: vm.goal, theme: theme,
                                        openSettings: openSettings)
                AnalyticsHoursChart(bars: bars, byWeek: byWeek, previousName: range.previousName, theme: theme)
                if byWeek {
                    AnalyticsEveryDayCard(days: days, totals: comparison.current, settings: vm.goal, theme: theme)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { detailCards(sprints: sprints, worked: worked) }
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 16) { detailCards(sprints: sprints, worked: worked) }
                }
                if byWeek {
                    AnalyticsMonthlyTotalsCard(days: days.filter { calendar.startOfDay(for: $0.date) <= calendar.startOfDay(for: today) },
                                               settings: vm.goal, exportSprints: sprints,
                                               profileName: vm.activeProfileName, theme: theme)
                } else {
                    PeriodTimesheetView(vm: vm, days: days, periodTitle: range.label,
                                        defaultDate: min(range.end, today), theme: theme,
                                        hidesUpcomingDays: true, offersEmptyDayFilter: true, exportSprints: sprints)
                }
            }
            .padding(20)
            .foregroundStyle(theme.textPrimary)
        }
    }

    @ViewBuilder private func detailCards(sprints: [Sprint], worked: TimeInterval) -> some View {
        SprintPatternsCardView(summary: SprintPatterns.calculate(sprints: sprints), theme: theme)
            .frame(minWidth: 320)
        AnalyticsTagCard(tags: MonthlyAnalytics.calculateTagBreakdown(sprints: sprints, totalSeconds: worked,
                                                                     hourlyRate: vm.goal.hourlyRate,
                                                                     currencySymbol: vm.goal.currencySymbol),
                         showsEarnings: vm.goal.hasHourlyRate, theme: theme)
            .frame(minWidth: 320)
    }

    // MARK: Range

    private func rangeBar(_ range: AnalyticsRange) -> some View {
        HStack(spacing: 12) {
            Picker("Range", selection: Binding<AnalyticsRangeKind?>(
                get: { customRange == nil ? kind : nil },
                set: { if let new = $0 { kindKey = new.rawValue; offset = 0; customRange = nil } }
            )) {
                ForEach(AnalyticsRangeKind.allCases) { Text($0.title).tag(Optional($0)) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if customRange == nil, kind != .all {
                DashboardPeriodNavigator(periodName: kind.rawValue, canGoForward: offset < 0,
                                         resetTitle: offset == 0 ? nil : kind.currentTitle, theme: theme,
                                         move: { offset = min(0, offset + $0) }, reset: { offset = 0 }) {
                    rangeLabel(range.label)
                }
                .fixedSize()
            } else {
                rangeLabel(range.label)
                if customRange != nil {
                    Button("Clear") { customRange = nil }
                        .help("Back to the \(kind.title.lowercased()) range")
                }
            }
            Spacer(minLength: 8)
            Button("Custom range…", systemImage: "calendar") { showingCustom = true }
                .popover(isPresented: $showingCustom, arrowEdge: .bottom) { customEditor }
        }
    }

    private func rangeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(theme.cardBg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.cardBorder, lineWidth: 1))
    }

    private var customEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom range").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("From")
                    CalendarDatePicker(title: "Range start date", selection: $customStart, theme: theme,
                                       allowedRange: Date.distantPast...Date())
                }
                GridRow {
                    Text("To")
                    CalendarDatePicker(title: "Range end date", selection: $customEnd, theme: theme,
                                       allowedRange: Date.distantPast...Date())
                }
            }
            Text("It is compared with the same number of days right before it.")
                .font(.caption).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { showingCustom = false }
                    .keyboardShortcut(.cancelAction)
                Button("Show range") {
                    customRange = AnalyticsRange.custom(from: customStart, to: customEnd, calendar: calendar)
                    showingCustom = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 300)
    }
}
