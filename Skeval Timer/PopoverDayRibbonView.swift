import SwiftUI

/// Today in one strip under the popover's figures: sprints, the current pause, and the forecast.
/// It redraws once a minute, never on the 1-second tick.
struct PopoverDayRibbonView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    private let barHeight: CGFloat = 14

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Live {
                let ribbon = vm.todayRibbon(now: context.date)
                VStack(alignment: .leading, spacing: 4) {
                    bar(ribbon)
                    marks(ribbon)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText(ribbon))
            }
        }
    }

    private func bar(_ ribbon: DayRibbon) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(theme.cardBorder.opacity(0.35))
                ForEach(Array(ribbon.blocks.enumerated()), id: \.offset) { _, block in
                    let x = width * block.start
                    let w = max(2, width * (block.end - block.start))
                    switch block.kind {
                    case .work:
                        RoundedRectangle(cornerRadius: 3).fill(theme.accentColor)
                            .frame(width: w, height: barHeight).offset(x: x)
                    case .pause:
                        RoundedRectangle(cornerRadius: 3).fill(Color.orange)
                            .frame(width: w, height: barHeight).offset(x: x)
                    case .forecast:
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(theme.accentIcon, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
                            .frame(width: w, height: barHeight).offset(x: x)
                    }
                }
                if let now = ribbon.now {
                    Capsule().fill(theme.textPrimary)
                        .frame(width: 2, height: barHeight + 6)
                        .offset(x: min(width - 2, max(0, width * now - 1)))
                }
            }
            .frame(height: barHeight)
        }
        .frame(height: barHeight + 6)
    }

    private func marks(_ ribbon: DayRibbon) -> some View {
        GeometryReader { proxy in
            ForEach(Array(ribbon.marks.enumerated()), id: \.offset) { index, mark in
                let label = Text(mark.date, format: .dateTime.hour())
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize()
                // Centre each label on its hour, but keep the first and last inside the strip.
                let width = proxy.size.width
                let centred = width * mark.position - 22
                let x = index == 0 ? 0 : min(max(0, centred), width - 44)
                let alignment: Alignment = index == 0 ? .leading : (x < centred ? .trailing : .center)
                label.frame(width: 44, alignment: alignment).offset(x: x)
            }
        }
        .frame(height: 12)
    }

    private func accessibilityText(_ ribbon: DayRibbon) -> String {
        let work = ribbon.blocks.filter { $0.kind == .work }.count
        var parts = ["Today's sprints: \(work)"]
        if ribbon.blocks.contains(where: { $0.kind == .pause }) { parts.append("paused now") }
        if let forecast = ribbon.blocks.first(where: { $0.kind == .forecast }) {
            let end = ribbon.window.start.addingTimeInterval(ribbon.window.duration * forecast.end)
            parts.append("finish around \(TimeFormatter.format(displayTime: end))")
        }
        return parts.joined(separator: ", ")
    }
}
