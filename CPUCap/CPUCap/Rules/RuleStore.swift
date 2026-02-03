import Foundation
import Combine

class RuleStore: ObservableObject {
    @Published var rules: [Rule] = []
    
    private let storageKey = "CPUCapRules"
    private var cpuLimiter: CPULimiter?
    private var processMonitor: ProcessMonitor?
    private var applyTimer: Timer?
    
    init() {
        loadRules()
        startAutoApply()
    }
    
    func setCPULimiter(_ limiter: CPULimiter) {
        self.cpuLimiter = limiter
        applyAllRules()
    }
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        self.processMonitor = monitor
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
                cpuLimiter?.removeLimit(appName: rule.appName)
            } else if rule.enabled {
                applyRule(rule)
            }
        }
    }
    
    func removeRule(_ rule: Rule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
        cpuLimiter?.removeLimit(appName: rule.appName)
    }
    
    func ruleForApp(_ appName: String) -> Rule? {
        rules.first { $0.appName == appName }
    }
    
    func setCapForApp(_ appName: String, cap: Double?) {
        if let cap = cap {
            if let existingRule = ruleForApp(appName) {
                var updated = existingRule
                updated.capPercent = cap
                updated.enabled = true
                updateRule(updated)
            } else {
                let newRule = Rule(appName: appName, capPercent: cap, enabled: true)
                addRule(newRule)
            }
        } else {
            // Remove cap
            if let existingRule = ruleForApp(appName) {
                removeRule(existingRule)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
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
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    // MARK: - Rule Application
    
    private func applyRule(_ rule: Rule) {
        guard rule.enabled, let limiter = cpuLimiter else { return }
        limiter.setLimit(appName: rule.appName, capPercent: rule.capPercent)
    }
    
    private func applyAllRules() {
        for rule in rules where rule.enabled {
            applyRule(rule)
        }
    }
    
    private func startAutoApply() {
        // Periodically check for new processes that match rules
        applyTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.applyAllRules()
        }
    }
}
