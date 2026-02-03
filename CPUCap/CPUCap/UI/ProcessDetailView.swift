import SwiftUI
import AppKit

struct ProcessDetailView: View {
    let process: AppProcessInfo
    @EnvironmentObject var processMonitor: ProcessMonitor
    @EnvironmentObject var cpuLimiter: CPULimiter
    @EnvironmentObject var ruleStore: RuleStore
    
    @State private var capValue: Double = 50
    @State private var capEnabled: Bool = false
    @State private var subProcesses: [SubProcessInfo] = []
    @State private var refreshTimer: Timer?
    
    private func refreshSubProcesses() {
        // Try to get from ProcessMonitor (has CPU data)
        if let detail = processMonitor.getDetailedInfo(for: process.appName) {
            subProcesses = detail.subProcesses
            return
        }
        
        // Fallback: build list without CPU (at least show names/memory)
        var result: [SubProcessInfo] = []
        for pid in process.pids {
            var pathBuffer = [CChar](repeating: 0, count: 4096)
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            var name = "PID \(pid)"
            var bundlePath: String? = nil
            
            if pathLength > 0 {
                let path = String(cString: pathBuffer)
                bundlePath = path
                name = (path as NSString).lastPathComponent
            }
            
            var memoryBytes: UInt64 = 0
            var diskRead: UInt64 = 0
            var diskWrite: UInt64 = 0
            
            var rusage = rusage_info_v4()
            let rusageResult = withUnsafeMutablePointer(to: &rusage) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rusagePtr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, rusagePtr)
                }
            }
            
            if rusageResult == 0 {
                memoryBytes = rusage.ri_phys_footprint
                diskRead = rusage.ri_diskio_bytesread
                diskWrite = rusage.ri_diskio_byteswritten
            }
            
            result.append(SubProcessInfo(
                id: pid,
                pid: pid,
                originalName: name,
                cpuPercent: 0,
                memoryBytes: memoryBytes,
                diskReadBytes: diskRead,
                diskWriteBytes: diskWrite,
                bundlePath: bundlePath
            ))
        }
        subProcesses = result.sorted { $0.memoryBytes > $1.memoryBytes }
    }
    
    private var totalMemoryFormatted: String {
        let total = subProcesses.reduce(0) { $0 + $1.memoryBytes }
        return formatBytes(total)
    }
    
    private var totalDiskReadFormatted: String {
        let total = subProcesses.reduce(0) { $0 + $1.diskReadBytes }
        return formatBytes(total)
    }
    
    private var totalDiskWriteFormatted: String {
        let total = subProcesses.reduce(0) { $0 + $1.diskWriteBytes }
        return formatBytes(total)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        let kb = Double(bytes) / 1024
        return String(format: "%.0f KB", kb)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app info
            headerSection
            
            Divider()
            
            // Status and cap control
            statusSection
            
            Divider()
            
            // Resource summary
            resourceSection
            
            Divider()
            
            // Sub-processes list
            subProcessesSection
            
            Divider()
            
            // Actions
            actionsSection
        }
        .frame(width: 450, height: 500)
        .onAppear {
            loadCapSettings()
            refreshSubProcesses()
            // Refresh every 2 seconds to get updated CPU values
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                refreshSubProcesses()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            // App icon (large)
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                    .frame(width: 64, height: 64)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(process.appName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let bundlePath = process.bundlePath {
                    Text((bundlePath as NSString).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(bundlePath)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(statusText)
                        .font(.subheadline)
                }
                
                Spacer()
                
                // Process count
                Text("\(process.pids.count) process\(process.pids.count == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Cap control
            HStack(spacing: 12) {
                Toggle("Limit CPU", isOn: $capEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: capEnabled) { _, newValue in
                        if newValue {
                            ruleStore.setCapForApp(process.appName, cap: capValue)
                        } else {
                            ruleStore.setCapForApp(process.appName, cap: nil)
                        }
                    }
                
                Slider(value: $capValue, in: 1...100, step: 1)
                    .disabled(!capEnabled)
                    .frame(width: 150)
                    .onChange(of: capValue) { _, newValue in
                        if capEnabled {
                            ruleStore.setCapForApp(process.appName, cap: newValue)
                        }
                    }
                
                Text("\(Int(capValue))%")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 45, alignment: .trailing)
                    .foregroundColor(capEnabled ? .orange : .secondary)
            }
        }
        .padding(16)
    }
    
    // MARK: - Resource Section
    
    private var resourceSection: some View {
        HStack(spacing: 0) {
            resourceBox(
                title: "CPU",
                value: String(format: "%.1f%%", process.cpuPercent),
                subtitle: "Avg: \(String(format: "%.1f%%", process.cpuAverage))",
                color: cpuColor
            )
            
            Divider()
            
            resourceBox(
                title: "Memory",
                value: totalMemoryFormatted,
                subtitle: "\(process.pids.count) processes",
                color: .blue
            )
            
            Divider()
            
            resourceBox(
                title: "Disk Read",
                value: totalDiskReadFormatted,
                subtitle: "total",
                color: .green
            )
            
            Divider()
            
            resourceBox(
                title: "Disk Write",
                value: totalDiskWriteFormatted,
                subtitle: "total",
                color: .orange
            )
        }
        .frame(height: 70)
    }
    
    private func resourceBox(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // MARK: - Sub-processes Section
    
    private var subProcessesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sub-processes")
                    .font(.headline)
                Spacer()
                Text("\(subProcesses.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Column headers
            HStack(spacing: 8) {
                Text("PID")
                    .frame(width: 50, alignment: .leading)
                Text("Name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("CPU")
                    .frame(width: 55, alignment: .trailing)
                Text("Memory")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Sub-process list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(subProcesses) { sub in
                        subProcessRow(sub)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private func subProcessRow(_ sub: SubProcessInfo) -> some View {
        HStack(spacing: 8) {
            Text("\(sub.pid)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Text(sub.originalName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(String(format: "%.1f%%", sub.cpuPercent))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(sub.cpuPercent > 10 ? .orange : .primary)
                .frame(width: 55, alignment: .trailing)
            
            Text(sub.memoryFormatted)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(sub.cpuPercent > 20 ? Color.orange.opacity(0.1) : Color.clear)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button(action: openInFinder) {
                Label("Show in Finder", systemImage: "folder")
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            
            Spacer()
        }
        .padding(16)
    }
    
    // MARK: - Helper Properties
    
    private var statusColor: Color {
        switch process.status {
        case .running: return .green
        case .slowed: return .blue
        case .stopped: return .red
        }
    }
    
    private var statusText: String {
        switch process.status {
        case .running: return "Running"
        case .slowed: return "Throttled"
        case .stopped: return "Stopped"
        }
    }
    
    private var cpuColor: Color {
        if process.cpuPercent > 80 { return .red }
        if process.cpuPercent > 50 { return .orange }
        return .green
    }
    
    // MARK: - Actions
    
    private func loadCapSettings() {
        if let rule = ruleStore.ruleForApp(process.appName) {
            capEnabled = rule.enabled
            capValue = rule.capPercent
        } else {
            capEnabled = false
            capValue = 50
        }
    }
    
    private func openInFinder() {
        if let bundlePath = process.bundlePath {
            // Get the .app bundle path
            if let appRange = bundlePath.range(of: ".app") {
                let appPath = String(bundlePath[..<appRange.upperBound])
                NSWorkspace.shared.selectFile(appPath, inFileViewerRootedAtPath: "")
            } else {
                NSWorkspace.shared.selectFile(bundlePath, inFileViewerRootedAtPath: "")
            }
        }
    }
}
