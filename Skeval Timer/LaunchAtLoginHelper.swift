import Foundation
import ServiceManagement

enum LaunchAtLoginHelper {
    static var isEnabled: Bool {
        guard Bundle.main.bundlePath.hasPrefix("/Applications") else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else {
            return "Move Skeval Timer to Applications to enable launch at login."
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            if SMAppService.mainApp.status == .requiresApproval {
                return "Allow Skeval Timer in System Settings > General > Login Items."
            }
            return nil
        } catch {
            return "Launch at login could not be changed: \(error.localizedDescription)"
        }
    }
}
