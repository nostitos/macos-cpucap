import Foundation

struct DefaultRules {
    // No default rules - user decides what to limit
    static let rules: [Rule] = []
    
    // Suggested modes for common CPU-heavy apps
    static func suggestedMode(for appName: String) -> ThrottleMode? {
        // Apps that are known to be resource-intensive in background
        let efficiencyApps = [
            "Safari", "Chrome", "Firefox", "Arc",
            "Spotlight", "Photos", "Time Machine",
            "Xcode", "Simulator"
        ]
        
        if efficiencyApps.contains(appName) {
            return .efficiency
        }
        
        return nil
    }
}
