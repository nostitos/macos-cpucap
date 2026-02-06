import SwiftUI
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var rightClickMonitor: Any?
    private var rightClickMenu: NSMenu?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (menu bar only, no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Only request notifications if running as a proper app bundle
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
            UNUserNotificationCenter.current().delegate = self
        }
        
        // Build the right-click context menu
        let menu = NSMenu()
        
        let aboutItem = NSMenuItem(title: "About CPU Cap", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit CPU Cap", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        rightClickMenu = menu
        
        // Monitor right-click events on the status bar area
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event -> NSEvent? in
            guard let self = self,
                  let menu = self.rightClickMenu,
                  let window = event.window,
                  window.className.contains("NSStatusBar") || window.level == .statusBar else {
                return event
            }
            
            // Show context menu at the mouse location
            let location = NSEvent.mouseLocation
            menu.popUp(positioning: nil, at: NSPoint(x: location.x, y: location.y), in: nil)
            return nil
        }
    }
    
    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "CPU Cap",
            .applicationVersion: version,
            .version: version,
            .credits: NSAttributedString(
                string: "Free, open-source macOS menu bar app that limits background apps to efficiency cores.\n\nhttps://github.com/nostitos/macos-cpucap",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        ])
    }
    
    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // Try to find existing settings window first
        if let settingsWindow = NSApp.windows.first(where: { $0.title.contains("Settings") }) {
            settingsWindow.makeKeyAndOrderFront(nil)
        } else {
            // Post notification for SwiftUI to open the window
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = rightClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        CPULimiter.shared.stopAll()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
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
        HogDetector.shared.handleNotificationAction(response.actionIdentifier, appName: appName)
        completionHandler()
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
