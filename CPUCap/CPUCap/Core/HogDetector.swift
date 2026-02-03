import Foundation
import UserNotifications

class HogDetector: ObservableObject {
    @Published var hogThreshold: Double = 80.0  // Alert if > 80%
    @Published var hogDuration: TimeInterval = 10.0  // for > 10 seconds
    @Published var alertsEnabled: Bool = true
    
    private var hogStartTimes: [String: Date] = [:]  // appName -> when it started hogging
    private var recentAlerts: [String: Date] = [:]  // appName -> when we last alerted
    private let alertCooldown: TimeInterval = 60.0  // Don't re-alert for 60 seconds
    
    private var processMonitor: ProcessMonitor?
    private var timer: Timer?
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        self.processMonitor = monitor
        start()
    }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.check()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func check() {
        guard alertsEnabled, let processes = processMonitor?.processes else { return }
        
        let now = Date()
        var currentHogs = Set<String>()
        
        for process in processes {
            if process.cpuPercent > hogThreshold {
                currentHogs.insert(process.appName)
                
                if let startTime = hogStartTimes[process.appName] {
                    // Check if it's been hogging for long enough
                    if now.timeIntervalSince(startTime) >= hogDuration {
                        // Check cooldown
                        if let lastAlert = recentAlerts[process.appName],
                           now.timeIntervalSince(lastAlert) < alertCooldown {
                            continue  // Still in cooldown
                        }
                        
                        // Send alert
                        sendAlert(for: process)
                        recentAlerts[process.appName] = now
                    }
                } else {
                    // Start tracking this hog
                    hogStartTimes[process.appName] = now
                }
            }
        }
        
        // Clear tracking for processes that are no longer hogging
        for appName in hogStartTimes.keys {
            if !currentHogs.contains(appName) {
                hogStartTimes.removeValue(forKey: appName)
            }
        }
    }
    
    private func sendAlert(for process: AppProcessInfo) {
        let content = UNMutableNotificationContent()
        content.title = "CPU Hog Detected"
        content.body = "\(process.appName) is using \(Int(process.cpuPercent))% CPU"
        content.sound = .default
        content.userInfo = ["appName": process.appName]
        
        // Add action to limit the process
        content.categoryIdentifier = "CPU_HOG"
        
        let request = UNNotificationRequest(
            identifier: "cpuhog-\(process.appName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    func setThreshold(_ threshold: Double) {
        hogThreshold = max(1, min(100, threshold))
    }
    
    func setDuration(_ duration: TimeInterval) {
        hogDuration = max(1, duration)
    }
}
