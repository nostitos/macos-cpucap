import Foundation
import Combine

class RuleStore: ObservableObject {
    @Published var rules: [Rule] = []
    
    private let storageKey = "CPUCapRules"
    private var cpuLimiter: CPULimiter?
    private var processMonitor: ProcessMonitor?
    
    // Use a consistent UserDefaults location regardless of how the app is launched
    private let defaults: UserDefaults = {
        if let defaults = UserDefaults(suiteName: "com.cpucap.app") {
            return defaults
        }
        return UserDefaults.standard
    }()
    
    init() {
        loadRules()
    }
    
    func setCPULimiter(_ limiter: CPULimiter) {
        self.cpuLimiter = limiter
        applyAllRules()  // Apply once when limiter is ready
    }
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        self.processMonitor = monitor
    }
    
    /// Called by ProcessMonitor after each sample to apply rules to newly appeared processes
    func reapplyRulesIfNeeded() {
        applyAllRules()
    }
    
    // MARK: - Rule Management
    
    func addRule(_ rule: Rule) {
        rules.append(rule)
        saveRules()
        if rule.enabled {
            applyRule(rule)
        }
    }
    
    func updateRule(_ rule: Rule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            let oldRule = rules[index]
            rules[index] = rule
            saveRules()
            
            // Handle enable/disable changes
            if oldRule.enabled && !rule.enabled {
                cpuLimiter?.removeMode(appName: rule.appName)
            } else if rule.enabled {
                applyRule(rule)
            }
        }
    }
    
    func removeRule(_ rule: Rule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
        cpuLimiter?.removeMode(appName: rule.appName)
    }
    
    func ruleForApp(_ appName: String) -> Rule? {
        rules.first { $0.appName == appName }
    }
    
    /// Set throttle mode for an app
    func setModeForApp(_ appName: String, mode: ThrottleMode?) {
        if let mode = mode, mode != .fullSpeed {
            if let existingRule = ruleForApp(appName) {
                var updated = existingRule
                updated.mode = mode
                updated.enabled = true
                updateRule(updated)
            } else {
                let newRule = Rule(appName: appName, mode: mode, enabled: true)
                addRule(newRule)
            }
        } else {
            // Remove rule (full speed or nil)
            if let existingRule = ruleForApp(appName) {
                removeRule(existingRule)
            }
        }
    }
    
    /// Get current mode for an app
    func modeForApp(_ appName: String) -> ThrottleMode? {
        guard let rule = ruleForApp(appName), rule.enabled else { return nil }
        return rule.mode
    }
    
    // Legacy compatibility - converts to mode internally
    func setCapForApp(_ appName: String, cap: Double?) {
        if cap != nil {
            setModeForApp(appName, mode: .efficiency)
        } else {
            setModeForApp(appName, mode: nil)
        }
    }
    
    // MARK: - Persistence
    
    private func loadRules() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Rule].self, from: data) {
            rules = decoded
        } else {
            // Load default rules on first launch
            rules = DefaultRules.rules
            saveRules()
        }
    }
    
    private func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
    
    // MARK: - Rule Application
    
    private func applyRule(_ rule: Rule) {
        guard rule.enabled, let limiter = cpuLimiter else { return }
        limiter.setMode(appName: rule.appName, mode: rule.mode)
    }
    
    private func applyAllRules() {
        for rule in rules where rule.enabled {
            applyRule(rule)
        }
    }
}
