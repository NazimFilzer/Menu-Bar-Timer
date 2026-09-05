import Foundation
import ServiceManagement

enum LaunchAtLoginHelper {
    static var isEnabled: Bool {
        guard Bundle.main.bundlePath.hasPrefix("/Applications") else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[LaunchAtLogin] Notice: SMAppService requires app to be in /Applications. \(error)")
        }
    }
}
