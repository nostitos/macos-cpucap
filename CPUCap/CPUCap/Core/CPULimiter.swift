import Foundation
import Darwin
import AppKit

class CPULimiter: ObservableObject {
    static let shared = CPULimiter()
    
    @Published var activeLimits: [String: Double] = [:]  // appName -> capPercent
    @Published var limitingStatus: [String: Bool] = [:]  // appName -> isCurrentlyThrottling
    
    private var processMonitor: ProcessMonitor?
    private var timer: Timer?
    private var cycleCount: Int = 0
    
    init() {}
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        self.processMonitor = monitor
        startTimer()
    }
    
    private func startTimer() {
        // Single timer for all throttling - runs every 1 second
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.throttleCycle()
            }
        }
    }
    
    func setLimit(appName: String, capPercent: Double) {
        // Resume processes first
        if let pids = processMonitor?.pidsForApp(appName) {
            for pid in pids { kill(pid, SIGCONT) }
        }
        
        DispatchQueue.main.async {
            self.activeLimits[appName] = capPercent
            self.limitingStatus[appName] = true
        }
    }
    
    func removeLimit(appName: String) {
        // Resume processes
        if let pids = processMonitor?.pidsForApp(appName) {
            for pid in pids { kill(pid, SIGCONT) }
        }
        
        DispatchQueue.main.async {
            self.activeLimits.removeValue(forKey: appName)
            self.limitingStatus.removeValue(forKey: appName)
        }
    }
    
    func stopAll() {
        // Resume all limited processes
        for appName in activeLimits.keys {
            if let pids = processMonitor?.pidsForApp(appName) {
                for pid in pids { kill(pid, SIGCONT) }
            }
        }
    }
    
    /// Called every 1 second - handles all throttling in one place
    private func throttleCycle() {
        guard !activeLimits.isEmpty else { return }
        
        cycleCount += 1
        let cyclePhase = cycleCount % 10
        
        // Get frontmost app once
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        
        // Batch status updates
        var newStatus: [String: Bool] = [:]
        
        for (appName, cap) in activeLimits {
            guard let pids = processMonitor?.pidsForApp(appName), !pids.isEmpty else {
                continue
            }
            
            // Don't throttle frontmost app
            if isFrontmost(appName: appName, frontApp: frontApp) {
                for pid in pids { kill(pid, SIGCONT) }
                newStatus[appName] = false
                continue
            }
            
            // Simple duty cycle based on cap percentage
            // cap=20 means run 2 out of 10 cycles
            let runCycles = max(1, Int(cap / 10.0))
            
            if cyclePhase < runCycles {
                for pid in pids { kill(pid, SIGCONT) }
            } else {
                for pid in pids { kill(pid, SIGSTOP) }
            }
            newStatus[appName] = true
        }
        
        // Single UI update
        if !newStatus.isEmpty {
            DispatchQueue.main.async {
                for (app, status) in newStatus {
                    self.limitingStatus[app] = status
                }
            }
        }
    }
    
    private func isFrontmost(appName: String, frontApp: String) -> Bool {
        if frontApp == appName { return true }
        if frontApp.contains(appName) { return true }
        if appName.contains(frontApp) && !frontApp.isEmpty { return true }
        if appName == "Chrome" && frontApp.contains("Google Chrome") { return true }
        if appName == "Chrome Canary" && frontApp.contains("Chrome Canary") { return true }
        return false
    }
    
    func isLimiting(_ appName: String) -> Bool {
        limitingStatus[appName] ?? false
    }
    
    func getCapForApp(_ appName: String) -> Double? {
        activeLimits[appName]
    }
}
