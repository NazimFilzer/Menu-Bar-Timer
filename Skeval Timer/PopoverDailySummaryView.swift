import SwiftUI

/// Always shows today. The history picker must never change the live summary.
struct PopoverDailySummaryView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        let _ = vm.logRevision // Refresh the Today date after a day rollover, without observing ticks here.
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                PopoverSectionTitle("Today", systemImage: "sun.max.fill", theme: theme)
                Spacer()
                Text(Date(), format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(theme.textSecondary)
            }
            Live { figures }
            Live { goalProgress }
            PopoverDayRibbonView(vm: vm, theme: theme)
            PopoverFinishForecastView(vm: vm, theme: theme)
            PopoverTimesheetCopyButton(vm: vm, date: Calendar.current.startOfDay(for: Date()), theme: theme)
            Text("Timesheet uses completed sprints only.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .themedCard(theme, padding: 14, radius: 12)
    }

    private var figures: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(TimeFormatter.format(hoursAndMinutes: vm.totalTodayElapsed))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.8).lineLimit(1)
                Text("Work time · \(vm.goal.goalLabel) goal")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 4)
            if vm.goal.hasHourlyRate {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(vm.todayEarningsLabel)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.successText)
                        .minimumScaleFactor(0.65).lineLimit(1)
                    Text("Earnings · \(vm.goal.hourlyRateLabel)/h")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var goalProgress: some View {
        let remaining = max(0, vm.goal.dailyGoalSeconds - vm.totalTodayElapsed)
        let fraction = vm.goal.dailyGoalSeconds > 0 ? min(1, vm.totalTodayElapsed / vm.goal.dailyGoalSeconds) : 0
        return VStack(alignment: .leading, spacing: 8) {
            // Drawn by hand: a native ProgressView turns grey while the menu bar app is inactive.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.cardBorder.opacity(0.6))
                    Capsule().fill(theme.accentColor)
                        .frame(width: max(fraction > 0 ? 6 : 0, geo.size.width * fraction))
                }
            }
            .frame(height: 7)
            .accessibilityElement()
            .accessibilityLabel("Today's daily goal")
            .accessibilityValue("\(Int(fraction * 100)) percent")
            HStack {
                Text(remaining == 0 ? "Daily goal reached" : "\(TimeFormatter.format(shortDuration: remaining)) left to reach the daily goal")
                    .foregroundStyle(remaining == 0 ? theme.successText : theme.textSecondary)
                Spacer(minLength: 4)
                Text("\(Int(fraction * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(remaining == 0 ? theme.successText : theme.accentText)
            }
            .font(.system(size: 11, design: .rounded))
        }
    }
}

private struct PopoverFinishForecastView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        // This view only exists while the popover is open. No hidden idle timer.
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            Live {
                let forecast = vm.finishForecast()
                // Once the goal is reached, the progress row already shows the result.
                // Keep the decoration with the content so no empty box remains.
                if forecast.status != .goalReached {
                    VStack(alignment: .leading, spacing: 6) {
                        projection(forecast)
                        if forecast.finishDate != nil { upcomingBreaks }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.bgDark.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder private func projection(_ forecast: FinishForecast) -> some View {
        if let finish = forecast.finishDate {
            HStack(alignment: .firstTextBaseline) {
                Text("Finish around")
                Spacer()
                Text(finish, format: .dateTime.hour().minute())
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.accentText)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            if forecast.finishesAfterToday {
                // Same words as Today's forecast card.
                Text("\(finish.formatted(.dateTime.month(.abbreviated).day())). Crosses midnight. A sprint stays credited to its start day.")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(theme.warningText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(assumption(for: forecast.status)
                 + (vm.plannedBreakMinutes > 0 ? " Includes \(vm.plannedBreakMinutes) min of upcoming breaks." : ""))
                .font(.system(size: 11, design: .rounded)).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if forecast.status != .goalReached {
            Text(heldMessage(for: forecast.status))
                .font(.system(size: 11, design: .rounded)).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var upcomingBreaks: some View {
        // Custom controls: a native Stepper draws an unreadable bezel when the app is inactive.
        HStack(spacing: 6) {
            Text("Upcoming breaks")
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 4)
            Button { vm.plannedBreakMinutes = max(0, vm.plannedBreakMinutes - 5) } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(PopoverIconButtonStyle(theme: theme))
            .disabled(vm.plannedBreakMinutes <= 0)
            .accessibilityLabel("Fewer upcoming break minutes")
            Text("\(vm.plannedBreakMinutes) min")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(minWidth: 48)
                .accessibilityLabel("Upcoming breaks: \(vm.plannedBreakMinutes) minutes")
            Button { vm.plannedBreakMinutes = min(240, vm.plannedBreakMinutes + 5) } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(PopoverIconButtonStyle(theme: theme))
            .disabled(vm.plannedBreakMinutes >= 240)
            .accessibilityLabel("More upcoming break minutes")
        }
        .font(.system(size: 11, design: .rounded))
        .help("Count only breaks still ahead. This does not pause the timer or change recorded work. It resets each day and on app restart.")
    }

    private func assumption(for status: FinishForecast.Status) -> String {
        switch status {
        case .working: "If you keep working."
        case .resumeNow: "If you resume now."
        default: "If you clock in now."
        }
    }

    private func heldMessage(for status: FinishForecast.Status) -> String {
        switch status {
        case .recovery: "Resolve the unfinished sprint to show a finish-time forecast."
        case .sleepHeld: "Classify sleep time to show a finish-time forecast."
        case .previousDaySprint: "The current sprint belongs to a previous day. Clock out and start a sprint today to forecast today's goal."
        default: ""
        }
    }
}

struct PopoverTimesheetCopyButton: View {
    let vm: TimerViewModel
    let date: Date
    let theme: PopoverTheme

    private var copied: Bool {
        vm.lastCopiedTimesheetDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
    }

    var body: some View {
        Button { vm.copyDailyTimesheet(for: date) } label: {
            Label(copied ? "Copied timesheet" : copyLabel, systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(PopoverSoftButtonStyle(theme: theme))
        .disabled(dayIsEmpty)
        .help("Copy Login, actual Logout, blank Lunch, and Break in whole minutes. Includes pauses and gaps between completed sprints.")
    }

    private var copyLabel: String {
        if Calendar.current.isDateInToday(date) { return "Copy today's timesheet" }
        return "Copy \(TimeFormatter.format(shortDayTitle: date)) timesheet"
    }

    private var dayIsEmpty: Bool {
        _ = vm.logRevision
        return vm.store.log(for: date).completedSprints.isEmpty
    }
}
