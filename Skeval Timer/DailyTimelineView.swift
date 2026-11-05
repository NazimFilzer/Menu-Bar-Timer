import SwiftUI

struct DailyTimelineView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @Binding var temporaryHours: TimelineHours?
    @State private var selectedSprint: Sprint?
    @State private var showingHours = false
    @State private var showingAddSprint = false
    @State private var focusRequest = 0
    @State private var visibleTimelineRect = CGRect.zero
    @State private var scrollPosition: ScrollPosition
    private static let hourHeight = DailyTimelineLayout.pointsPerHour

    init(vm: TimerViewModel, theme: PopoverTheme, temporaryHours: Binding<TimelineHours?>) {
        self.vm = vm
        self.theme = theme
        self._temporaryHours = temporaryHours
        let now = Date()
        let timeline = vm.dailyTimeline(hours: temporaryHours.wrappedValue, now: now)
        self._scrollPosition = State(initialValue: ScrollPosition(
            y: Self.focusOffset(timeline, now: now, today: vm.isViewingToday)
        ))
    }

    private var hours: TimelineHours { temporaryHours ?? vm.goal.timelineHours }

    var body: some View {
        let now = Date()
        let timeline = vm.dailyTimeline(hours: hours, now: now)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Daily timeline").font(.headline)
                    Text("\(hourLabel(timeline.visible.start)) to \(hourLabel(timeline.visible.end))")
                        .font(.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 8)
                Button("Add sprint", systemImage: "plus") { showingAddSprint = true }
                Button("Hours", systemImage: "slider.horizontal.3") { showingHours.toggle() }
                    .popover(isPresented: $showingHours) { hoursEditor }
                if vm.isViewingToday {
                    Button("Now") { focusRequest += 1 }
                }
            }
            .controlSize(.small)
            timelineScroll(timeline, now: now)
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("Gaps are untracked time. Select a sprint for details.")
            }
            .font(.caption).foregroundStyle(theme.textSecondary)
        }
        .padding(18)
        .background(theme.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder))
        .onChange(of: Calendar.current.startOfDay(for: vm.selectedDate)) {
            selectedSprint = nil
        }
        .sheet(item: $selectedSprint) { sprint in
            TimelineSprintDetailsView(vm: vm, sprintID: sprint.id, theme: theme)
        }
        .sheet(isPresented: $showingAddSprint) {
            AddSprintModalView(vm: vm, theme: theme, defaultDate: vm.selectedDate,
                               onDismiss: { showingAddSprint = false })
        }
    }

    private func timelineScroll(_ timeline: DailyTimeline, now: Date) -> some View {
        ScrollView(.vertical) {
            GeometryReader { geometry in
                timelineGrid(timeline, now: now, width: geometry.size.width)
            }
            .frame(height: height(timeline.visible.duration) + 28)
        }
        .frame(height: 400)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: CGRect.self) { $0.visibleRect } action: { _, rect in
            visibleTimelineRect = rect
        }
        .onChange(of: timeline.day.start) { focus(timeline, now: now) }
        .onChange(of: focusRequest) { focus(timeline, now: now) }
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
                    Text(hourLabel(mark)).font(.system(size: 11, weight: .medium))
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
                HStack(spacing: 8) {
                    Text("Now").font(.system(size: 10, weight: .semibold))
                        .frame(width: labelWidth - 8, alignment: .trailing)
                    Rectangle().frame(height: 1.5)
                }
                .foregroundStyle(theme.accentColor)
                .frame(width: width - 8)
                .offset(y: y(now, in: timeline) + 8)
                .allowsHitTesting(false)
            }
        }
    }

    private func untrackedBand(_ gap: DateInterval, width: CGFloat, top: CGFloat) -> some View {
        let bandHeight = max(1, height(gap.duration) - 5)
        let visibleStart = max(0, visibleTimelineRect.minY - top)
        let visibleEnd = min(bandHeight, visibleTimelineRect.maxY - top)
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

    private func focus(_ timeline: DailyTimeline, now: Date) {
        scrollPosition.scrollTo(y: Self.focusOffset(timeline, now: now, today: vm.isViewingToday))
    }

    private static func focusOffset(_ timeline: DailyTimeline, now: Date, today: Bool) -> CGFloat {
        let target = today ? now.addingTimeInterval(-3600)
            : (timeline.segments.first?.interval.start ?? timeline.visible.start)
        return max(0, target.timeIntervalSince(timeline.visible.start) / 3600 * hourHeight - 16)
    }

    private var hoursEditor: some View {
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
            Text("The range expands to include all sprints. A day change restores the default.")
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
}
