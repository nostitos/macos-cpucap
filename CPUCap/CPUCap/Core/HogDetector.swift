import Foundation
import UserNotifications

class HogDetector: ObservableObject {
    static let shared = HogDetector()
    
    @Published var hogThreshold: Double = 50.0  // Alert if > 50%
    @Published var hogDuration: TimeInterval = 10.0  // for > 10 seconds
    @Published var alertsEnabled: Bool = true
    @Published var mutedApps: Set<String> = []  // Apps user said "don't warn about"
    
    private var hogStartTimes: [String: Date] = [:]  // appName -> when it started hogging
    private var recentAlerts: [String: Date] = [:]  // appName -> when we last alerted
    private let alertCooldown: TimeInterval = 60.0  // Don't re-alert for 60 seconds
    
    private var processMonitor: ProcessMonitor?
    private var ruleStore: RuleStore?
    private var timer: Timer?
    
    // Storage for muted apps
    private let defaults = UserDefaults(suiteName: "com.cpucap.app") ?? UserDefaults.standard
    private let mutedAppsKey = "CPUCapMutedApps"
    
    // Notification action identifiers
    static let categoryIdentifier = "CPU_HOG_ALERT"
    static let actionLetContinue = "LET_CONTINUE"
    static let actionLimitUsage = "LIMIT_USAGE"
    static let actionDontWarn = "DONT_WARN"
    
    init() {
        loadMutedApps()
        registerNotificationCategory()
    }
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        self.processMonitor = monitor
        start()
    }
    
    func setRuleStore(_ store: RuleStore) {
        self.ruleStore = store
    }
    
    private func registerNotificationCategory() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        
        let letContinueAction = UNNotificationAction(
            identifier: HogDetector.actionLetContinue,
            title: "Let it continue",
            options: []
        )
        
        let limitUsageAction = UNNotificationAction(
            identifier: HogDetector.actionLimitUsage,
            title: "Limit its CPU usage",
            options: [.foreground]
        )
        
        let dontWarnAction = UNNotificationAction(
            identifier: HogDetector.actionDontWarn,
            title: "Don't warn about this app",
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: HogDetector.categoryIdentifier,
            actions: [letContinueAction, limitUsageAction, dontWarnAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
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
            // Skip muted apps
            if mutedApps.contains(process.appName) {
                continue
            }
            
            // Skip apps that already have a throttle mode set
            if process.throttleMode != nil {
                continue
            }
            
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
        // Only send notifications if running as a proper app bundle
        guard Bundle.main.bundleIdentifier != nil else {
            print("CPU Hog: \(process.appName) is using \(Int(process.cpuPercent))% CPU")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "\(process.appName) has been using more than \(Int(hogThreshold))% CPU for over \(Int(hogDuration)) seconds."
        content.body = "What would you like to do about it?"
        content.sound = .default
        content.userInfo = ["appName": process.appName, "cpuPercent": process.cpuPercent]
        content.categoryIdentifier = HogDetector.categoryIdentifier
        
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
    
    // MARK: - Handle notification actions
    
    func handleNotificationAction(_ actionIdentifier: String, appName: String) {
        switch actionIdentifier {
        case HogDetector.actionLetContinue:
            // Just dismiss - do nothing
            print("User chose to let \(appName) continue")
            
        case HogDetector.actionLimitUsage:
            // Set efficiency mode (E-cores) on the app
            ruleStore?.setModeForApp(appName, mode: .efficiency)
            print("Setting \(appName) to efficiency mode (E-cores)")
            
        case HogDetector.actionDontWarn:
            // Add to muted list
            muteApp(appName)
            print("Muted warnings for \(appName)")
            
        default:
            break
        }
    }
    
    // MARK: - Muted apps management
    
    func muteApp(_ appName: String) {
        mutedApps.insert(appName)
        saveMutedApps()
    }
    
    func unmuteApp(_ appName: String) {
        mutedApps.remove(appName)
        saveMutedApps()
    }
    
    private func loadMutedApps() {
        if let saved = defaults.stringArray(forKey: mutedAppsKey) {
            mutedApps = Set(saved)
        }
    }
    
    private func saveMutedApps() {
        defaults.set(Array(mutedApps), forKey: mutedAppsKey)
    }
    
    // MARK: - Settings
    
    func setThreshold(_ threshold: Double) {
        hogThreshold = max(1, min(100, threshold))
    }
    
    func setDuration(_ duration: TimeInterval) {
        hogDuration = max(1, duration)
    }
}
