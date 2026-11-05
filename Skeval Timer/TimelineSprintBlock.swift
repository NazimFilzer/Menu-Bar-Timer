import SwiftUI

/// Keeps active clock spans exact and gives completed labels a readable minimum height.
struct TimelineSprintBlock: View {
    let segment: TimelineSegment
    let theme: PopoverTheme
    let width: CGFloat
    let select: () -> Void

    private var height: CGFloat { DailyTimelineLayout.spanHeight(for: segment) }

    private var title: String { segment.displayName }
    private var duration: String {
        segment.netWork.map { TimeFormatter.format(shortDuration: $0) } ?? "Unresolved"
    }
    private var accent: Color {
        switch segment.status {
        case .sleep, .recovery: return .orange
        case .paused: return theme.textSecondary
        case .active: return .green
        case .completed: return theme.accentColor
        }
    }
    private var status: String {
        switch segment.status {
        case .active: return "Active"
        case .paused: return "Paused"
        case .sleep, .recovery: return "Unresolved"
        case .completed: return ""
        }
    }

    private var usesExternalLabel: Bool { DailyTimelineLayout.usesExternalLabel(for: segment) }
    private var usesRightPausedLabel: Bool { segment.paused > 0 && height < 68 }
    private var blockHeight: CGFloat {
        DailyTimelineLayout.blockHeight(for: segment)
    }

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 4) {
                if !usesExternalLabel { headline.fixedSize(horizontal: false, vertical: true) }
                if height >= 68, let note = extraNote {
                    Text(note).font(.system(size: 10))
                        .foregroundStyle(note == pausedLabel ? Color.orange : theme.textSecondary).lineLimit(1)
                }
            }
            .padding(.horizontal, height >= 44 ? 10 : 8)
            .padding(.vertical, height >= 44 ? 6 : 0)
            .frame(width: width, height: blockHeight, alignment: .topLeading)
            .background(accent.opacity(theme.isLight ? 0.07 : 0.12))
            .overlay(alignment: .leading) {
                Rectangle().fill(accent.opacity(0.8)).frame(width: 3)
            }
            .overlay(alignment: .bottom) { unresolvedShade }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(accent.opacity(0.13), lineWidth: 0.5))
            .contentShape(Rectangle())
            .clipped()
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if usesExternalLabel {
                Button(action: select) {
                    headline
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: width, height: DailyTimelineLayout.externalLabelHeight, alignment: .leading)
                        .background(theme.cardBg, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .stroke(accent.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                // The clock span ends five points below the block. Leave room
                // for the Now line before placing the full-height label.
                .offset(y: height + DailyTimelineLayout.externalLabelGap)
            }
        }
        .help("\(title) · \(segment.status.rawValue)\n\(timeRange)\n\(duration) work. Select for details.")
        .accessibilityLabel("\(title), \(segment.status.rawValue), \(timeRange), \(duration) work")
    }

    private var headline: some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: height >= 44 ? 12 : 11, weight: .semibold))
                .foregroundStyle(theme.textPrimary).lineLimit(1)
                .layoutPriority(1)
            if !status.isEmpty {
                statusBadge
                    .fixedSize()
                    .layoutPriority(2)
            }
            Text(timeRange).font(.system(size: 10)).monospacedDigit()
                .foregroundStyle(theme.textSecondary).lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 0)
            if width >= 360 {
                Text(duration).font(.system(size: 10, weight: .medium)).monospacedDigit()
                    .foregroundStyle(theme.textSecondary).lineLimit(1)
            }
            if usesRightPausedLabel {
                Text(pausedLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            if segment.status == .active {
                Circle().fill(accent).frame(width: 5, height: 5)
            }
            Text(status).font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(accent.opacity(0.12), in: Capsule())
    }

    private var timeRange: String {
        let start = time(segment.interval.start)
        let end = segment.sprint.endTime == nil && !segment.continuesAfter ? "now" : time(segment.interval.end)
        return "\(start) to \(end)"
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits))
    }

    private var extraNote: String? {
        if segment.continuesBefore {
            return "Counted on \(segment.sprint.startTime.formatted(date: .abbreviated, time: .omitted))"
        }
        if segment.continuesAfter { return "Continues next day" }
        if segment.paused > 0, !usesRightPausedLabel { return pausedLabel }
        return nil
    }

    private var pausedLabel: String {
        "\(TimeFormatter.format(shortDuration: segment.paused)) paused"
    }

    @ViewBuilder
    private var unresolvedShade: some View {
        if let start = segment.unresolvedStart, start < segment.interval.end {
            let seconds = segment.interval.end.timeIntervalSince(max(start, segment.interval.start))
            let fraction = seconds / segment.interval.duration
            Rectangle().fill(accent.opacity(0.09))
                .frame(height: height * fraction)
                .allowsHitTesting(false)
        }
    }
}
