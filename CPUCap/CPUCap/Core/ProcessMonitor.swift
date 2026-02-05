import Foundation
import Darwin

let PROC_PIDPATHINFO_MAXSIZE: Int = 4096
let MAXCOMLEN: Int = 16

class ProcessMonitor: ObservableObject {
    @Published var processes: [AppProcessInfo] = []
    @Published var summary: CPUSummary = CPUSummary()
    @Published var cpuHistory: [CPUHistoryPoint] = []
    @Published var isEnabled: Bool = true
    @Published var showSystemProcesses: Bool = false
    
    private var timer: Timer?
    private var previousSamples: [pid_t: UInt64] = [:]
    private var previousTimestamp: CFAbsoluteTime = 0
    private let minCPUThreshold: Double = 0.1  // Show processes using >0.1% CPU
    
    // Cache for process start times (doesn't change)
    private var startTimeCache: [pid_t: Date] = [:]
    
    // Mach timebase for converting CPU times to nanoseconds
    private let timebaseNumer: Double
    private let timebaseDenom: Double
    
    // System processes to optionally hide
    private let systemProcesses = Set([
        "kernel_task", "launchd", "WindowServer", "loginwindow",
        "systemstats", "coreaudiod", "coreduetd", "distnoted"
    ])
    
    // Always hide ourselves - no point capping CPU Cap
    private let hiddenProcesses = Set(["CPU Cap", "CPUCap"])
    
    private var coreCount: Int {
        Foundation.ProcessInfo.processInfo.activeProcessorCount
    }
    
    init() {
        // Get mach timebase info for converting CPU times
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        timebaseNumer = Double(timebaseInfo.numer)
        timebaseDenom = Double(timebaseInfo.denom)
        
        // Get core counts
        summary.pCoreCount = getPCoreCount()
        summary.eCoreCount = getECoreCount()
        
        // Delay start to ensure run loop is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start()
        }
    }
    
    private func getPCoreCount() -> Int {
        var count: Int = 0
        var size = MemoryLayout<Int>.size
        sysctlbyname("hw.perflevel0.logicalcpu", &count, &size, nil, 0)
        return count > 0 ? count : 6  // Default for M1
    }
    
    private func getECoreCount() -> Int {
        var count: Int = 0
        var size = MemoryLayout<Int>.size
        sysctlbyname("hw.perflevel1.logicalcpu", &count, &size, nil, 0)
        return count > 0 ? count : 4  // Default for M1
    }
    
    @Published var isMenuOpen: Bool = false
    
    func start() {
        guard isEnabled else { return }
        
        // Only sample when menu is open
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isEnabled, self.isMenuOpen else { return }
            self.sample()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func menuOpened() {
        isMenuOpen = true
        sample()  // Immediate sample when menu opens
    }
    
    func menuClosed() {
        isMenuOpen = false
    }
    
    func toggle() {
        isEnabled.toggle()
        if isEnabled {
            start()
        } else {
            stop()
        }
    }
    
    private func sample() {
        let currentTimestamp = CFAbsoluteTimeGetCurrent()
        let now = Date()
        
        // Get all PIDs
        var numPids: Int32 = proc_listallpids(nil, 0)
        guard numPids > 0 else { return }
        
        var pids = [pid_t](repeating: 0, count: Int(numPids))
        numPids = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * Int(numPids)))
        
        guard numPids > 0 else { return }
        pids = Array(pids.prefix(Int(numPids)))
        
        // Collect process data
        var currentSamples: [pid_t: UInt64] = [:]
        var processData: [pid_t: (name: String, bundlePath: String?, cpuTimeNs: Double, startTime: Date?)] = [:]
        
        for pid in pids {
            guard pid > 0 else { continue }
            
            var rusage = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &rusage) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rusagePtr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, rusagePtr)
                }
            }
            
            guard result == 0 else { continue }
            
            let cpuTimeMach = rusage.ri_user_time &+ rusage.ri_system_time
            currentSamples[pid] = cpuTimeMach
            
            // Convert to nanoseconds
            let cpuTimeNs = Double(cpuTimeMach) * timebaseNumer / timebaseDenom
            
            // Get process start time (cached - it never changes)
            var startTime: Date? = startTimeCache[pid]
            if startTime == nil {
                var bsdInfo = proc_bsdinfo()
                let bsdSize = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
                if bsdSize > 0 {
                    let startSec = Double(bsdInfo.pbi_start_tvsec)
                    let startUsec = Double(bsdInfo.pbi_start_tvusec)
                    startTime = Date(timeIntervalSince1970: startSec + startUsec / 1_000_000)
                    startTimeCache[pid] = startTime
                }
            }
            
            let (name, bundlePath) = getProcessInfo(pid: pid)
            processData[pid] = (name, bundlePath, cpuTimeNs, startTime)
        }
        
        // Calculate CPU percentages (instantaneous) and lifetime averages
        guard previousTimestamp > 0 else {
            previousSamples = currentSamples
            previousTimestamp = currentTimestamp
            return
        }
        
        let timeDeltaSec = currentTimestamp - previousTimestamp
        guard timeDeltaSec > 0 else { return }
        let timeDeltaNs = timeDeltaSec * 1_000_000_000
        
        // Group by app name
        var appData: [String: (cpuNow: Double, cpuAvg: Double, pids: [pid_t], bundlePath: String?)] = [:]
        var totalCPUUsage: Double = 0.0
        
        for (pid, data) in processData {
            let appName = cleanAppName(data.name)
            
            // Always skip ourselves
            if hiddenProcesses.contains(appName) {
                continue
            }
            
            // Skip system processes if not showing them
            if !showSystemProcesses && systemProcesses.contains(appName) {
                continue
            }
            
            // Calculate instantaneous CPU %
            var cpuNow: Double = 0
            if let prevMach = previousSamples[pid], let currMach = currentSamples[pid] {
                let deltaMach = currMach > prevMach ? currMach - prevMach : 0
                let deltaNs = Double(deltaMach) * timebaseNumer / timebaseDenom
                cpuNow = (deltaNs / timeDeltaNs) * 100.0
            }
            
            // Calculate lifetime average CPU %
            // cpuAvg = totalCpuTime / processAge * 100
            var cpuAvg: Double = 0
            if let startTime = data.startTime {
                let ageSeconds = now.timeIntervalSince(startTime)
                if ageSeconds > 1 {  // Avoid division by very small numbers
                    let ageNs = ageSeconds * 1_000_000_000
                    cpuAvg = (data.cpuTimeNs / ageNs) * 100.0
                }
            }
            
            totalCPUUsage += cpuNow
            
            if var existing = appData[appName] {
                existing.cpuNow += cpuNow
                existing.cpuAvg += cpuAvg
                existing.pids.append(pid)
                if existing.bundlePath == nil {
                    existing.bundlePath = data.bundlePath
                }
                appData[appName] = existing
            } else {
                appData[appName] = (cpuNow, cpuAvg, [pid], data.bundlePath)
            }
        }
        
        // Get reference to limiter for status
        let limiter = CPULimiter.shared
        
        // Convert to AppProcessInfo array
        // Filter by lifetime average (stable) instead of instantaneous (flickery)
        let newProcesses = appData
            .compactMap { (appName, data) -> AppProcessInfo? in
                let mode = limiter.getModeForApp(appName)
                let hasMode = mode != nil
                
                // Show if lifetime average >= threshold OR has a mode set
                guard data.cpuAvg >= minCPUThreshold || hasMode else {
                    return nil
                }
                
                let isThrottling = limiter.isThrottling(appName)
                
                let status: ProcessStatus
                if let mode = mode {
                    switch mode {
                    case .fullSpeed:
                        status = .running
                    case .efficiency:
                        status = isThrottling ? .slowed : .running
                    case .stopped:
                        status = isThrottling ? .stopped : .running
                    }
                } else {
                    status = .running
                }
                
                return AppProcessInfo(
                    id: appName,
                    appName: appName,
                    pids: data.pids,
                    cpuPercent: data.cpuNow,
                    cpuAverage: data.cpuAvg,
                    bundlePath: data.bundlePath,
                    status: status,
                    throttleMode: mode
                )
            }
        
        // Update history for graph
        let historyPoint = CPUHistoryPoint(
            timestamp: Date(),
            totalCPU: totalCPUUsage / Double(coreCount),
            pCoreCPU: totalCPUUsage * 0.7 / Double(summary.pCoreCount),  // Approximation
            eCoreCPU: totalCPUUsage * 0.3 / Double(summary.eCoreCount)   // Approximation
        )
        
        DispatchQueue.main.async {
            self.processes = newProcesses
            self.summary.totalCPU = totalCPUUsage / Double(self.coreCount)
            self.summary.pCoreCPU = historyPoint.pCoreCPU
            self.summary.eCoreCPU = historyPoint.eCoreCPU
            
            // Keep last 60 points (~2 minutes at 2s interval)
            self.cpuHistory.append(historyPoint)
            if self.cpuHistory.count > 60 {
                self.cpuHistory.removeFirst()
            }
        }
        
        previousSamples = currentSamples
        previousTimestamp = currentTimestamp
        
        // Clean up stale cache entries (PIDs that no longer exist)
        let currentPids = Set(currentSamples.keys)
        startTimeCache = startTimeCache.filter { currentPids.contains($0.key) }
    }
    
    /// Stable sort - only reorder when a process jumps significantly
    private func stableSortProcesses(_ newProcesses: [AppProcessInfo]) -> [AppProcessInfo] {
        guard !processes.isEmpty else {
            return newProcesses.sorted(by: { $0.cpuPercent > $1.cpuPercent })
        }
        
        // Keep existing order, just update values
        var result: [AppProcessInfo] = []
        var remaining = newProcesses
        
        // First, keep existing processes in their current order
        for oldProcess in processes {
            if let idx = remaining.firstIndex(where: { $0.appName == oldProcess.appName }) {
                result.append(remaining[idx])
                remaining.remove(at: idx)
            }
        }
        
        // Add any new processes at the end, sorted by CPU
        remaining.sort { $0.cpuPercent > $1.cpuPercent }
        result.append(contentsOf: remaining)
        
        // Only do a full re-sort if top process changed significantly
        let shouldResort = result.count > 1 && 
            result[0].cpuPercent < result[1].cpuPercent - 15.0  // 15% threshold to swap
        
        if shouldResort {
            return result.sorted { $0.cpuPercent > $1.cpuPercent }
        }
        
        return result
    }
    
    private func getProcessInfo(pid: pid_t) -> (name: String, bundlePath: String?) {
        var pathBuffer = [CChar](repeating: 0, count: PROC_PIDPATHINFO_MAXSIZE)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        
        var name = "Unknown"
        var bundlePath: String? = nil
        
        if pathLength > 0 {
            let path = String(cString: pathBuffer)
            bundlePath = path
            
            if let appRange = path.range(of: ".app/") {
                let appPath = String(path[..<appRange.lowerBound])  // Get path before ".app"
                name = (appPath as NSString).lastPathComponent  // Just the app name without .app
            } else if path.hasSuffix(".app") {
                name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            } else {
                name = (path as NSString).lastPathComponent
            }
        } else {
            var nameBuffer = [CChar](repeating: 0, count: MAXCOMLEN + 1)
            _ = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            if nameBuffer[0] != 0 {
                name = String(cString: nameBuffer)
            }
        }
        
        // Handle our own app - might show as "CPUCap", "CPU Cap", or truncated
        if name == "CPUCap" || name == "CPU Cap" || name.hasPrefix("CPU Cap") {
            name = "CPU Cap"
        }
        
        // If still Unknown, try to get a better name
        if name == "Unknown" {
            var nameBuffer = [CChar](repeating: 0, count: MAXCOMLEN + 1)
            _ = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            if nameBuffer[0] != 0 {
                name = String(cString: nameBuffer)
            }
        }
        
        return (name, bundlePath)
    }
    
    /// Get the actual executable name (for detail view sub-processes)
    private func getExecutableName(pid: pid_t) -> String {
        var pathBuffer = [CChar](repeating: 0, count: PROC_PIDPATHINFO_MAXSIZE)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        
        if pathLength > 0 {
            let path = String(cString: pathBuffer)
            return (path as NSString).lastPathComponent  // e.g., "Spotify Helper (Renderer)"
        }
        
        // Fallback to proc_name
        var nameBuffer = [CChar](repeating: 0, count: MAXCOMLEN + 1)
        _ = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if nameBuffer[0] != 0 {
            return String(cString: nameBuffer)
        }
        
        return "PID \(pid)"
    }
    
    private func cleanAppName(_ name: String) -> String {
        let helpers: [String: String] = [
            // WebKit processes - don't group as Safari, they're used by many apps
            "com.apple.WebKit.WebContent": "WebKit",
            "com.apple.WebKit.Networking": "WebKit",
            "com.apple.WebKit.GPU": "WebKit",
            "Google Chrome Helper": "Chrome",
            "Google Chrome Helper (GPU)": "Chrome",
            "Google Chrome Helper (Renderer)": "Chrome",
            "Google Chrome Canary Helper": "Chrome Canary",
            "Google Chrome Canary Helper (GPU)": "Chrome Canary",
            "Google Chrome Canary Helper (Renderer)": "Chrome Canary",
            "Cursor Helper": "Cursor",
            "Cursor Helper (GPU)": "Cursor",
            "Cursor Helper (Plugin)": "Cursor",
            "Cursor Helper (Renderer)": "Cursor",
            "Code Helper": "VS Code",
            "Code Helper (GPU)": "VS Code",
            "Code Helper (Plugin)": "VS Code",
            "Code Helper (Renderer)": "VS Code",
            "Electron Helper": "Electron",
            "node": "Node.js",
            "mds": "Spotlight",
            "mds_stores": "Spotlight",
            "mdworker": "Spotlight",
            "mdworker_shared": "Spotlight",
            "spotlightknowledged": "Spotlight",
            "Spotlight": "Spotlight",
            "photoanalysisd": "Photos",
            "photolibraryd": "Photos",
            "IMAPStore": "Mail",
            "backupd": "Time Machine",
            "backupd-helper": "Time Machine",
            "WindowServer": "WindowServer",
        ]
        
        if let mapped = helpers[name] {
            return mapped
        }
        
        // WebKit processes are used by many apps (Mail, Notes, etc.), not just Safari
        if name.contains("WebContent") || name.contains("com.apple.WebKit") {
            return "WebKit"
        }
        
        if name.contains("Chrome Canary Helper") {
            return "Chrome Canary"
        }
        if name.contains("Chrome Helper") {
            return "Chrome"
        }
        
        if name.contains("Cursor Helper") {
            return "Cursor"
        }
        
        if name.contains("Code Helper") {
            return "VS Code"
        }
        
        if name.contains("Wire Helper") {
            return "Wire"
        }
        
        if name.contains("Slack Helper") {
            return "Slack"
        }
        
        if name.contains("Discord Helper") {
            return "Discord"
        }
        
        if name.contains("zoom") || name.contains("Zoom") {
            return "Zoom"
        }
        
        if name.contains("Teams Helper") || name.contains("Microsoft Teams") {
            return "Teams"
        }
        
        if name.hasSuffix(" Helper") || name.contains(" Helper (") {
            let baseName = name
                .replacingOccurrences(of: " Helper (Renderer)", with: "")
                .replacingOccurrences(of: " Helper (GPU)", with: "")
                .replacingOccurrences(of: " Helper (Plugin)", with: "")
                .replacingOccurrences(of: " Helper", with: "")
            if !baseName.isEmpty {
                return baseName
            }
        }
        
        return name
    }
    
    func pidsForApp(_ appName: String) -> [pid_t] {
        processes.first(where: { $0.appName == appName })?.pids ?? []
    }
    
    /// Get detailed info for an app including all sub-processes
    func getDetailedInfo(for appName: String) -> AppDetailInfo? {
        guard let appInfo = processes.first(where: { $0.appName == appName }) else {
            return nil
        }
        
        var subProcesses: [SubProcessInfo] = []
        let timeDeltaSec = max(0.1, CFAbsoluteTimeGetCurrent() - previousTimestamp)
        let timeDeltaNs = timeDeltaSec * 1_000_000_000
        
        for pid in appInfo.pids {
            // Get actual executable name (e.g., "Spotify Helper (Renderer)")
            let originalName = getExecutableName(pid: pid)
            let (_, bundlePath) = getProcessInfo(pid: pid)
            
            // Try to get resource usage (may fail for some processes)
            var memoryBytes: UInt64 = 0
            var diskRead: UInt64 = 0
            var diskWrite: UInt64 = 0
            var cpuPercent: Double = 0
            
            var rusage = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &rusage) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rusagePtr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, rusagePtr)
                }
            }
            
            if result == 0 {
                memoryBytes = rusage.ri_phys_footprint
                diskRead = rusage.ri_diskio_bytesread
                diskWrite = rusage.ri_diskio_byteswritten
                
                // Calculate CPU for this specific PID
                let currentCPUTime = rusage.ri_user_time &+ rusage.ri_system_time
                if let prevCPUTime = previousSamples[pid] {
                    let cpuDeltaMach = currentCPUTime > prevCPUTime ? currentCPUTime - prevCPUTime : 0
                    let cpuDeltaNs = Double(cpuDeltaMach) * timebaseNumer / timebaseDenom
                    cpuPercent = (cpuDeltaNs / timeDeltaNs) * 100.0
                }
            }
            
            let subProcess = SubProcessInfo(
                id: pid,
                pid: pid,
                originalName: originalName,
                cpuPercent: cpuPercent,
                memoryBytes: memoryBytes,
                diskReadBytes: diskRead,
                diskWriteBytes: diskWrite,
                bundlePath: bundlePath
            )
            subProcesses.append(subProcess)
        }
        
        // Sort by CPU descending
        subProcesses.sort { $0.cpuPercent > $1.cpuPercent }
        
        // Get bundle identifier and version from Info.plist
        var bundleIdentifier: String? = nil
        var version: String? = nil
        
        if let bundlePath = appInfo.bundlePath,
           let appRange = bundlePath.range(of: ".app") {
            let appPath = String(bundlePath[..<appRange.upperBound])
            let infoPlistPath = appPath + "/Contents/Info.plist"
            
            if let plistData = FileManager.default.contents(atPath: infoPlistPath),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
                bundleIdentifier = plist["CFBundleIdentifier"] as? String
                version = plist["CFBundleShortVersionString"] as? String
                if let build = plist["CFBundleVersion"] as? String, version != nil {
                    version = "\(version!) (\(build))"
                }
            }
        }
        
        return AppDetailInfo(
            appName: appName,
            bundlePath: appInfo.bundlePath,
            bundleIdentifier: bundleIdentifier,
            version: version,
            subProcesses: subProcesses
        )
    }
}
