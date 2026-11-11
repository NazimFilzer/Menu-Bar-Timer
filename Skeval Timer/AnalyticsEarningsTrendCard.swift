import SwiftUI

/// Cumulative earnings through the range, with the previous period as a dashed ghost line.
/// It answers "how much this month compared with last?" in one look.
struct AnalyticsEarningsTrendCard: View {
    let trend: EarningsTrend
    let periodLabel: String
    let previousName: String?
    let currencySymbol: String
    let theme: PopoverTheme

    private let height: CGFloat = 150
    private let axisWidth: CGFloat = 56

    private var scale: Double { max(trend.total, trend.previousTotal ?? 0, 1) * 1.1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardCardHeader(title: "Earnings so far", icon: "chart.line.uptrend.xyaxis", theme: theme) {
                DashboardInfoButton(text: "Running total of earnings through each day, at your current hourly rate. "
                                    + "The dashed line is the \(previousName ?? "previous period") at the same rate.",
                                    theme: theme, accessibilityTitle: "About earnings so far")
            }
            chart
            facts
        }
        .modifier(WorkInsightsCardStyle(theme: theme))
    }

    private var chart: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(gridMarks.enumerated()), id: \.offset) { _, mark in gridLine(mark) }
            GeometryReader { proxy in
                let size = CGSize(width: proxy.size.width, height: height)
                ZStack(alignment: .topLeading) {
                    if let previous = trend.previous {
                        path(previous, in: size)
                            .stroke(theme.textSecondary.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    if !trend.current.isEmpty {
                        area(trend.current, in: size).fill(theme.successText.opacity(0.1))
                        path(trend.current, in: size)
                            .stroke(theme.successText, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        let end = point(trend.current.count - 1, trend.total, in: size)
                        Circle().fill(theme.successText).frame(width: 9, height: 9).position(end)
                    }
                }
            }
            .padding(.leading, axisWidth)
            .frame(height: height)
        }
        .frame(height: height)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.cardBorder).frame(height: 1).padding(.leading, axisWidth) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Earnings so far")
        .accessibilityValue(accessibilityValue)
    }

    private var facts: some View {
        HStack(alignment: .top, spacing: 28) {
            fact(money(trend.total), periodLabel, color: theme.successText)
            if let same = trend.previousBySameDay {
                fact(money(same), "\(previousName.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "Previous") by the same day")
            }
            if let total = trend.previousTotal {
                fact(money(total), "\(previousName.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "Previous") in total")
            }
        }
    }

    private func fact(_ value: String, _ label: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(color ?? theme.textPrimary)
            Text(label).font(.dashboardCaption).foregroundStyle(theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Geometry

    private var gridMarks: [Double] { [0, scale / 2.2, scale / 1.1] }

    private func point(_ index: Int, _ value: Double, in size: CGSize) -> CGPoint {
        let steps = max(1, trend.dayCount - 1)
        return CGPoint(x: size.width * CGFloat(index) / CGFloat(steps),
                       y: size.height * (1 - CGFloat(value / scale)))
    }

    private func path(_ values: [Double], in size: CGSize) -> Path {
        Path { path in
            for (index, value) in values.enumerated() {
                let p = point(index, value, in: size)
                index == 0 ? path.move(to: p) : path.addLine(to: p)
            }
        }
    }

    private func area(_ values: [Double], in size: CGSize) -> Path {
        var shape = path(values, in: size)
        shape.addLine(to: point(values.count - 1, 0, in: size))
        shape.addLine(to: point(0, 0, in: size))
        shape.closeSubpath()
        return shape
    }

    private func gridLine(_ mark: Double) -> some View {
        HStack(spacing: 6) {
            Text(compactMoney(mark))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .frame(width: axisWidth - 6, alignment: .trailing)
            Rectangle().fill(theme.cardBorder.opacity(0.5)).frame(height: 0.5)
        }
        .frame(height: 12)
        .offset(y: height * (1 - CGFloat(mark / scale)) - 6)
        .accessibilityHidden(true)
    }

    // MARK: Text

    private func money(_ amount: Double) -> String {
        EarningsCalculator.format(amount: amount, currencySymbol: currencySymbol)
    }

    private func compactMoney(_ amount: Double) -> String {
        if amount >= 1000 {
            return currencySymbol + (amount / 1000).formatted(.number.precision(.fractionLength(0...1))) + "k"
        }
        return currencySymbol + amount.formatted(.number.precision(.fractionLength(0)))
    }

    private var accessibilityValue: String {
        var text = "\(money(trend.total)) so far"
        if let same = trend.previousBySameDay { text += ", \(money(same)) by the same day in the \(previousName ?? "previous period")" }
        return text
    }
}
