import SwiftUI

// MARK: - Clock Picker Mode

enum ClockPickerMode: String, CaseIterable {
    case hour = "Hour"
    case minute = "Min"
}

// MARK: - Clock Time Helper

struct ClockTimeHelper {
    static func hour12(from date: Date, calendar: Calendar = .current) -> Int {
        let h24 = calendar.component(.hour, from: date)
        let h12 = h24 % 12
        return h12 == 0 ? 12 : h12
    }

    static func minute(from date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.minute, from: date)
    }

    static func isPM(from date: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: date) >= 12
    }

    static func setHour(date: Date, hour12: Int, calendar: Calendar = .current) -> Date {
        let currentH24 = calendar.component(.hour, from: date)
        let pm = currentH24 >= 12
        let targetH24 = pm ? (hour12 == 12 ? 12 : hour12 + 12) : (hour12 == 12 ? 0 : hour12)
        var comps = calendar.dateComponents([.year, .month, .day, .minute, .second], from: date)
        comps.hour = targetH24
        return calendar.date(from: comps) ?? date
    }

    static func setMinute(date: Date, minute: Int, calendar: Calendar = .current) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        comps.minute = max(0, min(59, minute))
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }

    static func setPeriod(date: Date, toPM: Bool, calendar: Calendar = .current) -> Date {
        let currentH24 = calendar.component(.hour, from: date)
        let currentIsPM = currentH24 >= 12
        guard currentIsPM != toPM else { return date }
        return calendar.date(byAdding: .hour, value: toPM ? 12 : -12, to: date) ?? date
    }

    static func stepMinutes(date: Date, minutes: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: date) ?? date
    }

    static func format12Hour(date: Date, calendar: Calendar = .current) -> String {
        let h = hour12(from: date, calendar: calendar)
        let m = minute(from: date, calendar: calendar)
        let period = isPM(from: date, calendar: calendar) ? "PM" : "AM"
        return String(format: "%d:%02d %@", h, m, period)
    }

    static func parseTime(_ input: String, on date: Date, calendar: Calendar = .current) -> Date? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let isPM = value.hasSuffix("PM")
        let isAM = value.hasSuffix("AM")
        let hasPeriod = isAM || isPM

        if hasPeriod {
            value = String(value.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let enteredHour = Int(parts[0]),
              let enteredMinute = Int(parts[1]),
              (0...59).contains(enteredMinute) else { return nil }

        let hour: Int
        if hasPeriod {
            guard (1...12).contains(enteredHour) else { return nil }
            hour = (enteredHour % 12) + (isPM ? 12 : 0)
        } else {
            guard (0...23).contains(enteredHour) else { return nil }
            hour = enteredHour
        }

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = enteredMinute
        components.second = 0
        return calendar.date(from: components)
    }
}

// MARK: - Interactive Analog Clock Dial

struct AnalogClockDialView: View {
    @Binding var date: Date
    @Binding var mode: ClockPickerMode
    let theme: PopoverTheme
    let diameter: CGFloat = 132

    private var radius: CGFloat { diameter / 2 }

    private var currentHour12: Int {
        ClockTimeHelper.hour12(from: date)
    }

    private var currentMinute: Int {
        ClockTimeHelper.minute(from: date)
    }

    private var hourHandAngle: Angle {
        let h = Double(currentHour12 % 12)
        let m = Double(currentMinute)
        return Angle(degrees: h * 30.0 + m * 0.5)
    }

    private var minuteHandAngle: Angle {
        Angle(degrees: Double(currentMinute) * 6.0)
    }

    var body: some View {
        ZStack {
            // Dial Background Circle
            Circle()
                .fill(theme.cardBg.opacity(0.85))
                .frame(width: diameter, height: diameter)
                .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1.2))

            // 12 Major Hour Ticks
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * 30.0
                Rectangle()
                    .fill(theme.textSecondary.opacity(0.35))
                    .frame(width: 1.2, height: i % 3 == 0 ? 6 : 3.5)
                    .offset(y: -(radius - 6))
                    .rotationEffect(Angle(degrees: angle))
            }

            // Number markers around dial
            if mode == .hour {
                ForEach(1...12, id: \.self) { h in
                    hourMarker(h)
                }
            } else {
                ForEach(0..<12, id: \.self) { i in
                    minuteMarker(i * 5)
                }
            }

            // Hour Hand
            Capsule()
                .fill(mode == .hour ? theme.neonTeal : theme.textPrimary.opacity(0.8))
                .frame(width: 3.5, height: radius * 0.50)
                .offset(y: -(radius * 0.25))
                .rotationEffect(hourHandAngle)
                .shadow(color: (mode == .hour ? theme.neonTeal : Color.clear).opacity(0.4), radius: 3)

            // Minute Hand
            Capsule()
                .fill(mode == .minute ? theme.neonTeal : theme.textSecondary)
                .frame(width: 2.0, height: radius * 0.72)
                .offset(y: -(radius * 0.36))
                .rotationEffect(minuteHandAngle)
                .shadow(color: (mode == .minute ? theme.neonTeal : Color.clear).opacity(0.4), radius: 3)

            // Center Pin
            Circle()
                .fill(theme.neonTeal)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(theme.bgDark, lineWidth: 2))
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDrag(at: value.location)
                }
                .onEnded { value in
                    handleDragEnded(at: value.location)
                }
        )
    }

    private func hourMarker(_ h: Int) -> some View {
        let angle = Double(h) * 30.0
        let rad = (angle - 90.0) * .pi / 180.0
        let numDist = radius * 0.73
        let x = numDist * cos(rad)
        let y = numDist * sin(rad)
        let isSelected = h == currentHour12

        return Button(action: {
            date = ClockTimeHelper.setHour(date: date, hour12: h)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                mode = .minute
            }
        }) {
            Text("\(h)")
                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .black : theme.textPrimary)
                .frame(width: 17, height: 17)
                .background(isSelected ? theme.neonTeal : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .offset(x: x, y: y)
    }

    private func minuteMarker(_ m: Int) -> some View {
        let angle = Double(m) * 6.0
        let rad = (angle - 90.0) * .pi / 180.0
        let numDist = radius * 0.73
        let x = numDist * cos(rad)
        let y = numDist * sin(rad)
        let isSelected = m == (currentMinute / 5 * 5) && currentMinute % 5 == 0

        return Button(action: {
            date = ClockTimeHelper.setMinute(date: date, minute: m)
        }) {
            Text(String(format: "%02d", m))
                .font(.system(size: 8.5, weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundColor(isSelected ? .black : theme.textSecondary)
                .frame(width: 17, height: 17)
                .background(isSelected ? theme.neonTeal : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .offset(x: x, y: y)
    }

    private func handleDrag(at location: CGPoint) {
        let dx = Double(location.x - radius)
        let dy = Double(location.y - radius)
        var rad = atan2(dy, dx) + .pi / 2.0
        if rad < 0 { rad += 2.0 * .pi }
        let deg = rad * 180.0 / .pi

        if mode == .hour {
            var h = Int(round(deg / 30.0)) % 12
            if h == 0 { h = 12 }
            date = ClockTimeHelper.setHour(date: date, hour12: h)
        } else {
            let m = Int(round(deg / 6.0)) % 60
            date = ClockTimeHelper.setMinute(date: date, minute: m)
        }
    }

    private func handleDragEnded(at location: CGPoint) {
        handleDrag(at: location)
        if mode == .hour {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                mode = .minute
            }
        }
    }
}

// MARK: - Single Clock Time Picker View

struct SingleClockPickerView: View {
    @Binding var date: Date
    let theme: PopoverTheme

    @State private var mode: ClockPickerMode = .hour
    @State private var timeText = ""
    @FocusState private var isTimeFieldFocused: Bool

    private var isPM: Bool {
        ClockTimeHelper.isPM(from: date)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Editable Time Display & AM / PM Controls
            HStack(spacing: 6) {
                Text("Time")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)

                TextField("9:30 AM", text: $timeText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(width: 100)
                    .background(theme.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                        parsedTimeText == nil && !timeText.isEmpty ? .red : (isTimeFieldFocused ? theme.neonTeal : theme.cardBorder),
                        lineWidth: 1
                    ))
                    .focused($isTimeFieldFocused)
                    .accessibilityLabel("Time")
                    .onSubmit(commitTimeText)
                    .onChange(of: timeText) { _, _ in
                        if let parsedTime = parsedTimeText {
                            date = parsedTime
                        }
                    }
                    .help("Enter a time such as 9:30 AM or 14:30")

                Button(action: commitTimeText) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(parsedTimeText == nil ? theme.textSecondary : theme.accentIcon)
                        .frame(width: 24, height: 24)
                        .background(theme.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .disabled(parsedTimeText == nil)
                .help("Apply time")

                Spacer()

                // AM / PM Segmented Toggle Buttons
                HStack(spacing: 2) {
                    Button(action: {
                        date = ClockTimeHelper.setPeriod(date: date, toPM: false)
                    }) {
                        Text("AM")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(!isPM ? .black : theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(!isPM ? theme.neonTeal : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)

                    Button(action: {
                        date = ClockTimeHelper.setPeriod(date: date, toPM: true)
                    }) {
                        Text("PM")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(isPM ? .black : theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isPM ? theme.neonTeal : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
                .padding(2)
                .background(theme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.cardBorder, lineWidth: 1))
            }
            .padding(.horizontal, 4)

            // Analog Clock Face
            AnalogClockDialView(date: $date, mode: $mode, theme: theme)

            // Quick Stepper Chips Row
            HStack(spacing: 4) {
                stepButton("-15m", minutes: -15)
                stepButton("-5m", minutes: -5)
                stepButton("+5m", minutes: 5)
                stepButton("+15m", minutes: 15)

                Spacer()

                Button(action: {
                    date = Date()
                }) {
                    Text("Now")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.accentText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(theme.neonTeal.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(theme.neonTeal.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 2)
        }
        .padding(8)
        .background(theme.cardBg.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder.opacity(0.6), lineWidth: 1))
        .onAppear {
            timeText = ClockTimeHelper.format12Hour(date: date)
        }
        .onChange(of: date) { _, newDate in
            let draftDate = ClockTimeHelper.parseTime(timeText, on: newDate)
            if !isTimeFieldFocused || draftDate != newDate {
                timeText = ClockTimeHelper.format12Hour(date: newDate)
            }
        }
        .onChange(of: isTimeFieldFocused) { _, isFocused in
            if !isFocused {
                timeText = ClockTimeHelper.format12Hour(date: date)
            }
        }
    }

    private func stepButton(_ label: String, minutes: Int) -> some View {
        Button(action: {
            date = ClockTimeHelper.stepMinutes(date: date, minutes: minutes)
        }) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.cardBorder, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private var parsedTimeText: Date? {
        ClockTimeHelper.parseTime(timeText, on: date)
    }

    private func commitTimeText() {
        guard let parsedTime = parsedTimeText else { return }
        date = parsedTime
        timeText = ClockTimeHelper.format12Hour(date: parsedTime)
        isTimeFieldFocused = false
    }
}

// MARK: - Dual Clock Time Picker View (Start & End Time)

struct DualClockTimePickerView: View {
    @Binding var startTime: Date
    @Binding var endTime: Date
    let theme: PopoverTheme

    @State private var activeTarget: Target = .start

    enum Target {
        case start
        case end
    }

    private var activeDateBinding: Binding<Date> {
        Binding(
            get: { activeTarget == .start ? startTime : endTime },
            set: { newDate in
                if activeTarget == .start {
                    startTime = newDate
                } else {
                    endTime = newDate
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            // Target Selector Row: Start vs End
            HStack(spacing: 6) {
                targetTab(
                    title: "START",
                    formattedTime: ClockTimeHelper.format12Hour(date: startTime),
                    isSelected: activeTarget == .start,
                    action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            activeTarget = .start
                        }
                    }
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(theme.textSecondary.opacity(0.5))

                targetTab(
                    title: "END",
                    formattedTime: ClockTimeHelper.format12Hour(date: endTime),
                    isSelected: activeTarget == .end,
                    action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            activeTarget = .end
                        }
                    }
                )
            }

            // Single Clock Picker for the active target
            SingleClockPickerView(date: activeDateBinding, theme: theme)
        }
    }

    private func targetTab(title: String, formattedTime: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isSelected ? theme.neonTeal : theme.textSecondary.opacity(0.4))
                    .frame(width: 5, height: 5)

                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? theme.accentText : theme.textSecondary)

                Spacer()

                Text(formattedTime)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .monospaced))
                    .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? theme.neonTeal.opacity(0.12) : theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? theme.neonTeal : theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
