import Foundation
import Darwin
import AppKit

// Darwin constants for setpriority
private let PRIO_DARWIN_PROCESS: Int32 = 4
private let PRIO_DARWIN_BG: Int32 = 0x1000

class CPULimiter: ObservableObject {
    static let shared = CPULimiter()
    
    @Published var activeModes: [String: ThrottleMode] = [:]  // appName -> mode
    @Published var currentlyThrottling: Set<String> = []       // apps currently being throttled
    
    private var processMonitor: ProcessMonitor?
    private var timer: Timer?
    
    // Track which PIDs we've put in background mode so we can restore them
    private var backgroundPids: Set<pid_t> = []
    private var stoppedPids: Set<pid_t> = []
    
    // Track PIDs per app so we can restore even if processMonitor doesn't have them
    private var appPids: [String: Set<pid_t>] = [:]
    
    init() {}
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        self.processMonitor = monitor
        startTimer()
    }
    
    private func startTimer() {
        // Timer to handle frontmost app changes and apply throttling
        // Only needed when there are active modes
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                guard let self = self, !self.activeModes.isEmpty else { return }
                self.applyThrottling()
            }
        }
    }
    
    // MARK: - Public API
    
    func setMode(appName: String, mode: ThrottleMode) {
        // Skip if mode hasn't changed
        if activeModes[appName] == mode { return }
        if mode == .fullSpeed && activeModes[appName] == nil { return }
        
        // Restore previous state only if mode is actually changing
        restoreApp(appName)
        
        DispatchQueue.main.async {
            if mode == .fullSpeed {
                self.activeModes.removeValue(forKey: appName)
            } else {
                self.activeModes[appName] = mode
            }
        }
        
        // Apply immediately
        applyThrottling()
    }
    
    func removeMode(appName: String) {
        restoreApp(appName)
        
        DispatchQueue.main.async {
            self.activeModes.removeValue(forKey: appName)
            self.currentlyThrottling.remove(appName)
        }
    }
    
    func stopAll() {
        // Restore all managed processes
        for appName in activeModes.keys {
            restoreApp(appName)
        }
    }
    
    func getModeForApp(_ appName: String) -> ThrottleMode? {
        activeModes[appName]
    }
    
    func isThrottling(_ appName: String) -> Bool {
        currentlyThrottling.contains(appName)
    }
    
    // MARK: - Throttling Logic
    
    private func applyThrottling() {
        guard !activeModes.isEmpty else { return }
        
        // Get frontmost app once
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        
        var newThrottling: Set<String> = []
        
        for (appName, mode) in activeModes {
            guard let pids = processMonitor?.pidsForApp(appName), !pids.isEmpty else {
                continue
            }
            
            // Don't throttle frontmost app - restore it
            if isFrontmost(appName: appName, frontApp: frontApp) {
                restorePids(pids)
                continue
            }
            
            // Track PIDs for this app so we can restore them later
            appPids[appName] = Set(pids)
            
            // Apply throttling based on mode
            switch mode {
            case .fullSpeed:
                restorePids(pids)
                
            case .efficiency:
                // Set background QoS - runs on E-cores
                for pid in pids {
                    setBackgroundMode(pid: pid, enabled: true)
                }
                newThrottling.insert(appName)
                
            case .stopped:
                // SIGSTOP - completely freeze
                for pid in pids {
                    if !stoppedPids.contains(pid) {
                        kill(pid, SIGSTOP)
                        stoppedPids.insert(pid)
                    }
                }
                newThrottling.insert(appName)
            }
        }
        
        // Update UI only if changed
        if newThrottling != currentlyThrottling {
            DispatchQueue.main.async {
                self.currentlyThrottling = newThrottling
            }
        }
    }
    
    // MARK: - Background Mode (E-core affinity)
    
    private func setBackgroundMode(pid: pid_t, enabled: Bool) {
        let priority = enabled ? PRIO_DARWIN_BG : 0
        let result = setpriority(PRIO_DARWIN_PROCESS, UInt32(pid), priority)
        
        if result == 0 {
            if enabled {
                backgroundPids.insert(pid)
            } else {
                backgroundPids.remove(pid)
            }
        }
    }
    
    // MARK: - Restore Functions
    
    private func restoreApp(_ appName: String) {
        // First try our cached PIDs (important for stopped apps that won't show in processMonitor)
        var pidsToRestore: [pid_t] = []
        
        if let cachedPids = appPids[appName] {
            pidsToRestore = Array(cachedPids)
        }
        
        // Also check processMonitor in case there are new PIDs
        if let monitorPids = processMonitor?.pidsForApp(appName) {
            for pid in monitorPids {
                if !pidsToRestore.contains(pid) {
                    pidsToRestore.append(pid)
                }
            }
        }
        
        restorePids(pidsToRestore)
        
        // Clear cached PIDs for this app
        appPids.removeValue(forKey: appName)
    }
    
    private func restorePids(_ pids: [pid_t]) {
        for pid in pids {
            // Always try to resume - SIGCONT is safe to send even if not stopped
            kill(pid, SIGCONT)
            stoppedPids.remove(pid)
            
            // Remove background mode if set
            if backgroundPids.contains(pid) {
                setBackgroundMode(pid: pid, enabled: false)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func isFrontmost(appName: String, frontApp: String) -> Bool {
        if frontApp == appName { return true }
        if frontApp.contains(appName) { return true }
        if appName.contains(frontApp) && !frontApp.isEmpty { return true }
        if appName == "Chrome" && frontApp.contains("Google Chrome") { return true }
        if appName == "Chrome Canary" && frontApp.contains("Chrome Canary") { return true }
        return false
    }
    
    // MARK: - Legacy compatibility (for migration)
    
    var activeLimits: [String: Double] {
        // Convert modes to fake percentages for any legacy code
        var result: [String: Double] = [:]
        for (app, mode) in activeModes {
            switch mode {
            case .fullSpeed: break
            case .efficiency: result[app] = 50  // Arbitrary value
            case .stopped: result[app] = 0
            }
        }
        return result
    }
}
