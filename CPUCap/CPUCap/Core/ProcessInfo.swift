import Foundation
import AppKit

// Shared constant for process resource usage
let RUSAGE_INFO_V4: Int32 = 4

/// Status of a process in relation to CPU Cap
enum ProcessStatus {
    case running      // Normal, not being limited
    case slowed       // Currently being throttled (SIGSTOP/SIGCONT cycle)
    case stopped      // Completely stopped
    
    var color: NSColor {
        switch self {
        case .running: return .systemGreen
        case .slowed: return .systemBlue
        case .stopped: return .systemRed
        }
    }
}

struct AppProcessInfo: Identifiable, Hashable {
    let id: String  // appName is the unique identifier for grouped processes
    let appName: String
    let pids: [pid_t]
    let cpuPercent: Double
    let cpuAverage: Double      // Average CPU over time
    let bundlePath: String?
    let status: ProcessStatus
    let throttleMode: ThrottleMode?  // Current throttle mode if any
    
    var pidCount: Int { pids.count }
    
    /// Get the app icon from the bundle path
    var icon: NSImage? {
        guard let path = bundlePath else { return nil }
        
        // Try to find the .app bundle
        if let appRange = path.range(of: ".app") {
            let appPath = String(path[..<appRange.upperBound])
            return NSWorkspace.shared.icon(forFile: appPath)
        }
        
        // Fallback to generic executable icon
        return NSWorkspace.shared.icon(forFile: path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(cpuPercent)
    }
    
    static func == (lhs: AppProcessInfo, rhs: AppProcessInfo) -> Bool {
        lhs.id == rhs.id && lhs.cpuPercent == rhs.cpuPercent && lhs.cpuAverage == rhs.cpuAverage
    }
}

struct RawProcessInfo {
    let pid: pid_t
    let name: String
    let cpuTime: UInt64  // mach absolute time units
    let bundleIdentifier: String?
    let bundlePath: String?
}

/// Individual sub-process info for detail view
struct SubProcessInfo: Identifiable {
    let id: pid_t  // PID is the unique identifier
    let pid: pid_t
    let originalName: String      // Original name before cleanAppName (e.g., "Wire Helper (Renderer)")
    let cpuPercent: Double
    let memoryBytes: UInt64       // Physical footprint in bytes
    let diskReadBytes: UInt64
    let diskWriteBytes: UInt64
    let bundlePath: String?
    
    var memoryFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryBytes), countStyle: .memory)
    }
    
    var diskReadFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(diskReadBytes), countStyle: .file)
    }
    
    var diskWriteFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(diskWriteBytes), countStyle: .file)
    }
}

/// Aggregated detail info for an app (all sub-processes combined)
struct AppDetailInfo {
    let appName: String
    let bundlePath: String?
    let bundleIdentifier: String?
    let version: String?
    let subProcesses: [SubProcessInfo]
    
    var totalCPU: Double {
        subProcesses.reduce(0) { $0 + $1.cpuPercent }
    }
    
    var totalMemory: UInt64 {
        subProcesses.reduce(0) { $0 + $1.memoryBytes }
    }
    
    var totalDiskRead: UInt64 {
        subProcesses.reduce(0) { $0 + $1.diskReadBytes }
    }
    
    var totalDiskWrite: UInt64 {
        subProcesses.reduce(0) { $0 + $1.diskWriteBytes }
    }
    
    var totalMemoryFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
    }
    
    var totalDiskReadFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalDiskRead), countStyle: .file)
    }
    
    var totalDiskWriteFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalDiskWrite), countStyle: .file)
    }
    
    var icon: NSImage? {
        guard let path = bundlePath else { return nil }
        if let appRange = path.range(of: ".app") {
            let appPath = String(path[..<appRange.upperBound])
            return NSWorkspace.shared.icon(forFile: appPath)
        }
        return NSWorkspace.shared.icon(forFile: path)
    }
    
    var appBundlePath: String? {
        guard let path = bundlePath, let appRange = path.range(of: ".app") else { return nil }
        return String(path[..<appRange.upperBound])
    }
}

/// CPU history data point for graphing
struct CPUHistoryPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let totalCPU: Double
    let eLimitedCPU: Double      // CPU used by E-limited apps
    let autoStoppedCPU: Double   // CPU used by auto-stopped apps
    let unlimitedCPU: Double     // CPU used by unlimited apps
}

/// Summary of CPU usage
struct CPUSummary {
    var totalCPU: Double = 0
    var pCoreCPU: Double = 0
    var eCoreCPU: Double = 0
    
    var pCoreCount: Int = 0
    var eCoreCount: Int = 0
}
