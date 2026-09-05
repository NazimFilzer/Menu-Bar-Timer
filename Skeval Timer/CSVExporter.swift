import Foundation
import AppKit
import UniformTypeIdentifiers

enum CSVExporter {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static let lock = NSLock()

    // MARK: - RFC-4180 CSV Generation

    static func generateCSV(sprints: [Sprint]) -> String {
        var lines: [String] = []
        // RFC-4180 standard header: Date,Start,End,Duration,Tag
        lines.append("Date,Start,End,Duration,Tag")

        // Sort chronologically (oldest first for spreadsheets)
        let sorted = sprints.sorted(by: { $0.startTime < $1.startTime })

        for sprint in sorted {
            lock.lock()
            let dateStr = dateFormatter.string(from: sprint.startTime)
            let startStr = timeFormatter.string(from: sprint.startTime)
            let endStr = sprint.endTime != nil ? timeFormatter.string(from: sprint.effectiveEnd ?? sprint.endTime!) : ""
            lock.unlock()

            let durStr = TimeFormatter.format(clock: sprint.duration ?? 0)
            let tagStr = sprint.tag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let row = [
                escapeRFC4180(dateStr),
                escapeRFC4180(startStr),
                escapeRFC4180(endStr),
                escapeRFC4180(durStr),
                escapeRFC4180(tagStr)
            ].joined(separator: ",")

            lines.append(row)
        }

        // RFC-4180 specifies CRLF line terminators (\r\n)
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func generateCSV(store: DayLogStore) -> String {
        let allLogs = store.allLogs()
        let allSprints = allLogs.values.flatMap { $0 }.filter { $0.endTime != nil }
        return generateCSV(sprints: allSprints)
    }

    // MARK: - RFC-4180 Field Escaping
    // 1. If string contains comma, quote, or newline (\r, \n), enclose in double quotes
    // 2. Any internal double quote must be doubled (" -> "")
    static func escapeRFC4180(_ field: String) -> String {
        let containsSpecialChar = field.contains(",") ||
                                  field.contains("\"") ||
                                  field.contains("\n") ||
                                  field.contains("\r")

        if containsSpecialChar {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        } else {
            return field
        }
    }

    // MARK: - macOS NSSavePanel Dialog

    @MainActor
    static func promptSavePanel(sprints: [Sprint], suggestedName: String? = nil, onComplete: ((Bool, URL?) -> Void)? = nil) {
        let csvContent = generateCSV(sprints: sprints)
        let panel = NSSavePanel()

        lock.lock()
        let todayStr = dateFormatter.string(from: Date())
        lock.unlock()

        let defaultName = suggestedName ?? "skeval-sprints-\(todayStr).csv"
        panel.nameFieldStringValue = defaultName
        panel.title = "Export Sprints to CSV"
        panel.message = "Choose a destination to save your sprint data in RFC-4180 CSV format."
        panel.canCreateDirectories = true

        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType.commaSeparatedText]
        } else {
            panel.allowedFileTypes = ["csv"]
        }

        panel.begin { response in
            if response == .OK, let targetURL = panel.url {
                do {
                    try csvContent.write(to: targetURL, atomically: true, encoding: .utf8)
                    onComplete?(true, targetURL)
                } catch {
                    print("❌ Failed to write CSV file: \(error)")
                    onComplete?(false, nil)
                }
            } else {
                onComplete?(false, nil)
            }
        }
    }
}
