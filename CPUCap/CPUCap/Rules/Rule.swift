import Foundation

struct Rule: Codable, Identifiable, Equatable {
    let id: UUID
    var appName: String
    var capPercent: Double
    var enabled: Bool
    
    init(id: UUID = UUID(), appName: String, capPercent: Double, enabled: Bool = true) {
        self.id = id
        self.appName = appName
        self.capPercent = capPercent
        self.enabled = enabled
    }
}
