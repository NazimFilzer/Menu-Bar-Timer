import Foundation

/// Screen geometry for the fixed-scale daily timeline. Recorded intervals stay unchanged.
enum DailyTimelineLayout {
    static let pointsPerHour: CGFloat = 64
    static let externalLabelGap: CGFloat = 14
    static let externalLabelHeight: CGFloat = 28
    static let verticalClearance: CGFloat = 4

    static func height(_ duration: TimeInterval) -> CGFloat {
        max(0, duration / 3600 * pointsPerHour)
    }

    static func spanHeight(for segment: TimelineSegment) -> CGFloat {
        max(2, height(segment.interval.duration) - 5)
    }

    static func blockHeight(for segment: TimelineSegment) -> CGFloat {
        let span = spanHeight(for: segment)
        return segment.status == .active ? span : max(18, span)
    }

    static func usesExternalLabel(for segment: TimelineSegment) -> Bool {
        segment.status == .active && spanHeight(for: segment) < 26
    }

    static func occupiedHeight(for segment: TimelineSegment) -> CGFloat {
        if usesExternalLabel(for: segment) {
            return spanHeight(for: segment) + externalLabelGap + externalLabelHeight + verticalClearance
        }
        return blockHeight(for: segment) + verticalClearance
    }

    static func arrange(_ segments: [TimelineSegment]) -> [TimelineSegment] {
        DailyTimeline.assignColumns(segments) { segment in
            let occupiedSeconds = occupiedHeight(for: segment) / pointsPerHour * 3600
            let visualEnd = segment.interval.start.addingTimeInterval(occupiedSeconds)
            return max(segment.interval.end, visualEnd)
        }
    }
}
