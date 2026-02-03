import Foundation
import ServiceManagement

struct LoginItemManager {
    static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
    
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
