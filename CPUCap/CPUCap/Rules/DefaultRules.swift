import Foundation

struct DefaultRules {
    // No default rules - user decides what to limit
    static let rules: [Rule] = []
    
    // No suggested caps - user knows their workflow best
    static func suggestedCap(for appName: String) -> Double? {
        nil
    }
}
