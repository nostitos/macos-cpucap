import SwiftUI
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (menu bar only, no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Request notification permissions for CPU hog alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
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
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap - could open settings for the process
        let userInfo = response.notification.request.content.userInfo
        if let appName = userInfo["appName"] as? String {
            print("User tapped notification for: \(appName)")
            // Could trigger UI to show cap options for this app
        }
        completionHandler()
    }
}
