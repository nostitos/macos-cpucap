import Foundation

/// Throttle mode for managed apps
enum ThrottleMode: String, Codable, CaseIterable {
    case fullSpeed = "full"       // No throttling
    case efficiency = "efficiency" // Run on E-cores (background QoS)
    case stopped = "stopped"       // Completely stopped (SIGSTOP)
    
    var displayName: String {
        switch self {
        case .fullSpeed: return "Full Speed"
        case .efficiency: return "E-limited"
        case .stopped: return "Auto-stop"
        }
    }
    
    /// Short indicator for the process list
    var indicator: String {
        switch self {
        case .fullSpeed: return ""
        case .efficiency: return "E"
        case .stopped: return "S"
        }
    }
    
    var description: String {
        switch self {
        case .fullSpeed: return "Run at full speed on all cores"
        case .efficiency: return "Limit to E-cores to save power"
        case .stopped: return "Stop when in background, resume when focused"
        }
    }
}

struct Rule: Codable, Identifiable, Equatable {
    let id: UUID
    var appName: String
    var mode: ThrottleMode
    var enabled: Bool
    
    // Legacy support for migration
    var capPercent: Double? {
        get { nil }
        set { }  // ignored
    }
    
    init(id: UUID = UUID(), appName: String, mode: ThrottleMode, enabled: Bool = true) {
        self.id = id
        self.appName = appName
        self.mode = mode
        self.enabled = enabled
    }
    
    // Migration initializer - convert old percentage caps to modes
    init(id: UUID = UUID(), appName: String, capPercent: Double, enabled: Bool = true) {
        self.id = id
        self.appName = appName
        // Convert: any cap becomes efficiency mode
        self.mode = .efficiency
        self.enabled = enabled
    }
    
    // Custom decoding to handle migration from old format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        appName = try container.decode(String.self, forKey: .appName)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        
        // Try to decode new mode format first
        if let modeValue = try? container.decode(ThrottleMode.self, forKey: .mode) {
            mode = modeValue
        } else if let _ = try? container.decode(Double.self, forKey: .capPercent) {
            // Migration: old capPercent format -> efficiency mode
            mode = .efficiency
        } else {
            mode = .efficiency
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, appName, mode, enabled, capPercent
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(appName, forKey: .appName)
        try container.encode(mode, forKey: .mode)
        try container.encode(enabled, forKey: .enabled)
    }
}
