import SwiftUI
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (menu bar only, no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Only request notifications if running as a proper app bundle
        // (UNUserNotificationCenter crashes when running from swift build)
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
            UNUserNotificationCenter.current().delegate = self
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSLog("[AppDelegate] applicationShouldTerminateAfterLastWindowClosed called - returning false")
        return false  // Keep running when windows are closed
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        NSLog("[AppDelegate] applicationShouldTerminate called")
        return .terminateNow
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Ensure all processes are resumed before quitting
        CPULimiter.shared.stopAll()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .list])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let appName = userInfo["appName"] as? String else {
            completionHandler()
            return
        }
        
        // Handle the action
        HogDetector.shared.handleNotificationAction(response.actionIdentifier, appName: appName)
        
        completionHandler()
    }
}
