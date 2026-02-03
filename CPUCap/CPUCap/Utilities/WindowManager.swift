import SwiftUI
import AppKit

class DetailWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSLog("[WindowDelegate] windowShouldClose - returning true")
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        NSLog("[WindowDelegate] windowWillClose")
    }
}

class WindowManager {
    static let shared = WindowManager()
    
    private var detailWindows: [String: NSWindow] = [:]
    private var windowDelegates: [String: DetailWindowDelegate] = [:]
    
    func openProcessDetail(
        process: AppProcessInfo,
        processMonitor: ProcessMonitor,
        cpuLimiter: CPULimiter,
        ruleStore: RuleStore
    ) {
        // If window already exists for this app, bring it to front
        if let existingWindow = detailWindows[process.appName] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Delay window creation slightly to avoid interfering with menu bar
        DispatchQueue.main.async { [self] in
            // Create the SwiftUI view
            let detailView = ProcessDetailView(process: process)
                .environmentObject(processMonitor)
                .environmentObject(cpuLimiter)
                .environmentObject(ruleStore)
            
            // Create hosting controller
            let hostingController = NSHostingController(rootView: detailView)
            
            // Create window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            window.contentViewController = hostingController
            window.title = "\(process.appName) - Details"
            window.center()
            window.isReleasedWhenClosed = false
            window.level = .floating  // Keep above other windows
            
            // Set delegate to handle close properly
            let delegate = DetailWindowDelegate()
            window.delegate = delegate
            self.windowDelegates[process.appName] = delegate
            
            // Track window closure
            let appName = process.appName
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.detailWindows.removeValue(forKey: appName)
                self?.windowDelegates.removeValue(forKey: appName)
            }
            
            self.detailWindows[process.appName] = window
            
            // Show window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func closeProcessDetail(for appName: String) {
        detailWindows[appName]?.close()
        detailWindows.removeValue(forKey: appName)
    }
}
