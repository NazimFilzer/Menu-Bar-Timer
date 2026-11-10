import SwiftUI

struct DailyTimelineView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @Binding var temporaryHours: TimelineHours?
    @State private var selectedSprint: Sprint?
    /// The page scrolls to this id for "Scroll to now". The timeline has no scroll area of its own.
    static let nowAnchor = "daily-timeline-now"
    private static let hourHeight = DailyTimelineLayout.pointsPerHour

    private var hours: TimelineHours { temporaryHours ?? vm.goal.timelineHours }

    var body: some View {
        let now = Date()
        // Only the hours with work are drawn; Visible hours sets the outer limits.
        let timeline = vm.dailyTimeline(hours: hours, fitsToWork: true, now: now)
        GeometryReader { geometry in
            timelineGrid(timeline, now: now, width: geometry.size.width)
        }
        .frame(height: height(timeline.visible.duration) + 28)
        .help("Gaps are untracked time. Select a sprint for details.")
        .onChange(of: Calendar.current.startOfDay(for: vm.selectedDate)) {
            selectedSprint = nil
        }
        .sheet(item: $selectedSprint) { sprint in
            TimelineSprintDetailsView(vm: vm, sprintID: sprint.id, theme: theme)
        }
    }

    private func timelineGrid(_ timeline: DailyTimeline, now: Date, width: CGFloat) -> some View {
        let labelWidth: CGFloat = 55
        let trackWidth = max(1, width - labelWidth - 8)
        return ZStack(alignment: .topLeading) {
            if now < timeline.visible.end {
                Rectangle().fill(theme.textSecondary.opacity(0.04))
                    .frame(width: trackWidth, height: height(timeline.visible.end.timeIntervalSince(max(now, timeline.visible.start))))
                    .offset(x: labelWidth, y: y(max(now, timeline.visible.start), in: timeline))
            }
            ForEach(timeline.hourMarks, id: \.self) { mark in
                HStack(spacing: 8) {
                    // The Now label takes this slot when the current time is within a few points of the hour.
                    let nowCovers = now >= timeline.visible.start && now < timeline.visible.end
                        && abs(y(now, in: timeline) + 8 - y(mark, in: timeline)) < 14
                    Text(hourLabel(mark)).font(.system(size: 11, weight: .medium))
                        .opacity(nowCovers ? 0 : 1)
                        .help(mark.formatted(.dateTime.hour().minute().timeZone(.specificName(.long))))
                        .foregroundStyle(theme.textSecondary).frame(width: labelWidth - 8, alignment: .trailing)
                    Rectangle().fill(theme.cardBorder.opacity(0.55)).frame(height: 0.5)
                }
                .frame(height: 16).offset(y: y(mark, in: timeline))
            }
            ForEach(timeline.gaps, id: \.start) { gap in
                untrackedBand(gap, width: max(1, trackWidth - 10), top: y(gap.start, in: timeline) + 8)
                    .offset(x: labelWidth, y: y(gap.start, in: timeline) + 8)
            }
            ForEach(DailyTimelineLayout.arrange(timeline.segments)) { segment in
                let blockWidth = trackWidth / CGFloat(segment.columnCount)
                TimelineSprintBlock(segment: segment, theme: theme,
                                    width: max(1, blockWidth - 10)) {
                    selectedSprint = segment.sprint
                }
                    .offset(x: labelWidth + CGFloat(segment.column) * blockWidth,
                            y: y(segment.interval.start, in: timeline) + 8)
            }
            if now >= timeline.visible.start && now < timeline.visible.end {
                // A laid-out (not offset) marker at the Now line, for the page's "Scroll to now".
                VStack(spacing: 0) {
                    Color.clear.frame(width: 1, height: y(now, in: timeline) + 8)
                    Color.clear.frame(width: 1, height: 1).id(Self.nowAnchor)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                HStack(spacing: 8) {
                    Text("Now").font(.system(size: 10, weight: .semibold))
                        .frame(width: labelWidth - 8, alignment: .trailing)
                    Rectangle().frame(height: 1.5)
                }
                .foregroundStyle(theme.accentIcon)
                .frame(width: width - 8)
                .offset(y: y(now, in: timeline) + 8)
                .allowsHitTesting(false)
            }
        }
    }

    private func untrackedBand(_ gap: DateInterval, width: CGFloat, top: CGFloat) -> some View {
        let bandHeight = max(1, height(gap.duration) - 5)
        let visibleStart: CGFloat = 0
        let visibleEnd = bandHeight
        let labelSpace = visibleEnd - visibleStart
        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.textSecondary.opacity(theme.isLight ? 0.035 : 0.045))
            if gap.duration >= 20 * 60, labelSpace >= 22 {
                let durationLabel = "\(TimeFormatter.format(shortDuration: gap.duration)) untracked"
                let timeSlot = "\(gap.start.formatted(date: .omitted, time: .shortened)) to \(gap.end.formatted(date: .omitted, time: .shortened))"
                HStack(spacing: 8) {
                    Text(durationLabel).font(.system(size: 11, weight: .medium))
                    Text(timeSlot).font(.caption)
                }
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(width: width, height: 22)
                .position(x: width / 2, y: (visibleStart + visibleEnd) / 2)
                .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(width: width, height: bandHeight)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(TimeFormatter.format(shortDuration: gap.duration)) untracked time")
        .help("No sprint was recorded during this time.")
    }

    private func height(_ seconds: TimeInterval) -> CGFloat { max(0, seconds / 3600 * Self.hourHeight) }
    private func y(_ date: Date, in timeline: DailyTimeline) -> CGFloat {
        height(date.timeIntervalSince(timeline.visible.start))
    }

    private func hourLabel(_ date: Date) -> String {
        hourLabel(Calendar.current.component(.hour, from: date))
    }

    private func hourLabel(_ value: Int) -> String {
        let hour = value % 24
        let clockHour = hour % 12 == 0 ? 12 : hour % 12
        return "\(clockHour)\(hour < 12 ? "AM" : "PM")"
    }
}

/// The sprint card's Visible hours popover: a temporary range for this day, or a saved default.
struct TimelineHoursEditor: View {
    @Bindable var vm: TimerViewModel
    @Binding var temporaryHours: TimelineHours?
    let theme: PopoverTheme

    private var hours: TimelineHours { temporaryHours ?? vm.goal.timelineHours }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visible hours").font(.headline)
            Picker("Start", selection: Binding(get: { hours.startHour }, set: {
                temporaryHours = TimelineHours(startHour: $0, endHour: hours.endHour)
            })) {
                ForEach(0..<hours.endHour, id: \.self) { Text(hourLabel($0)).tag($0) }
            }
            Picker("End", selection: Binding(get: { hours.endHour }, set: {
                temporaryHours = TimelineHours(startHour: hours.startHour, endHour: $0)
            })) {
                ForEach((hours.startHour + 1)...24, id: \.self) { hour in
                    Text(hourLabel(hour)).tag(hour)
                }
            }
            Text("Today shows only the hours with work, within these limits, and always includes every sprint. A day change restores the default.")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            Text("Saved: \(hourLabel(vm.goal.timelineHours.startHour)) to \(hourLabel(vm.goal.timelineHours.endHour))")
                .font(.caption).foregroundStyle(theme.textSecondary)
            HStack {
                Button("Save default") { vm.goal.timelineHours = hours }
                    .disabled(hours == vm.goal.timelineHours)
                    .help("Save these hours for all days.")
                Button("Reset hours") { temporaryHours = nil }
                    .disabled(hours == vm.goal.timelineHours)
                    .help("Restore the saved hours for this day.")
            }
        }.padding(18).frame(width: 300)
    }

    private func hourLabel(_ value: Int) -> String { TimelineHoursEditor.label(value) }

    static func label(_ value: Int) -> String {
        let hour = value % 24
        let clockHour = hour % 12 == 0 ? 12 : hour % 12
        return "\(clockHour)\(hour < 12 ? "AM" : "PM")"
    }
}
