import Foundation

enum TimeFormatter {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM yyyy"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private static let shortDayTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f
    }()

    private static let rupeeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₹"
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "en_IN")
        return f
    }()

    private static let formatterLock = NSLock()

    static func format(rupees amount: Double) -> String {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        let rounded = round(amount)
        return rupeeFormatter.string(from: NSNumber(value: rounded)) ?? "₹\(Int(rounded))"
    }

    static func format(duration: TimeInterval?) -> String {
        guard let d = duration else { return "in progress" }
        let totalSeconds = max(0, Int(d))
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        if m > 0 { return "\(m)m \(String(format: "%02d", s))s" }
        return "\(s)s"
    }

    static func format(shortDuration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(shortDuration))
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "0m"
    }

    static func format(clock: TimeInterval) -> String {
        let totalSeconds = max(0, Int(clock))
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    static func format(shortClock: TimeInterval) -> String {
        let totalSeconds = max(0, Int(shortClock))
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    static func format(time: Date) -> String {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        return timeFormatter.string(from: time)
    }

    static func format(dateKey: Date) -> String {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        return dateKeyFormatter.string(from: dateKey)
    }

    static func parseDateKey(_ key: String) -> Date? {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        return dateKeyFormatter.date(from: key)
    }

    static func format(headerDate: Date) -> String {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        return headerDateFormatter.string(from: headerDate)
    }

    static func format(shortDate: Date) -> String {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        return shortDateFormatter.string(from: shortDate)
    }

    static func format(shortDayTitle: Date) -> String {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        return shortDayTitleFormatter.string(from: shortDayTitle)
    }

    static func format(relativeHeaderDate: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(relativeHeaderDate) {
            return format(headerDate: relativeHeaderDate)
        } else if cal.isDateInYesterday(relativeHeaderDate) {
            return "Yesterday (\(format(shortDayTitle: relativeHeaderDate)))"
        } else {
            return format(headerDate: relativeHeaderDate)
        }
    }

    static func format(menuItemTitle: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(menuItemTitle) {
            return "Today (\(format(shortDate: menuItemTitle)))"
        } else if cal.isDateInYesterday(menuItemTitle) {
            return "Yesterday (\(format(shortDate: menuItemTitle)))"
        } else {
            return format(shortDayTitle: menuItemTitle)
        }
    }

    static func clipboardRow(start: Date, effectiveEnd: Date) -> String {
        "\(format(time: start))\t\(format(time: effectiveEnd))"
    }

    static func parseTime(_ text: String, on reference: Date) -> Date? {
        let pieces = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        guard pieces.count == 2 || pieces.count == 3 else { return nil }
        let parts = pieces.compactMap { Int($0) }
        guard parts.count == pieces.count else { return nil }
        guard (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        let sec = parts.count == 3 ? parts[2] : 0
        guard (0..<60).contains(sec) else { return nil }

        var c = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        c.hour = parts[0]
        c.minute = parts[1]
        c.second = sec
        return Calendar.current.date(from: c)
    }

    static func combine(date: Date, time: Date, wrapIfBefore: Date? = nil, calendar: Calendar = .current) -> Date {
        let timeComps = calendar.dateComponents([.hour, .minute, .second], from: time)
        var result = calendar.date(bySettingHour: timeComps.hour ?? 0, minute: timeComps.minute ?? 0, second: timeComps.second ?? 0, of: date) ?? time
        if let baseline = wrapIfBefore, result < baseline {
            result = calendar.date(byAdding: .day, value: 1, to: result) ?? result
        }
        return result
    }
}
