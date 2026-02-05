import SwiftUI

enum SortColumn: String {
    case name, cpu, avg
}

enum SortOrder {
    case ascending, descending
}

struct MenuBarView: View {
    @EnvironmentObject var processMonitor: ProcessMonitor
    @EnvironmentObject var cpuLimiter: CPULimiter
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var hogDetector: HogDetector
    
    @Environment(\.openWindow) private var openWindow
    
    @State private var searchText = ""
    @State private var showGraph = true
    @State private var sortColumn: SortColumn = .avg
    @State private var sortOrder: SortOrder = .descending
    @State private var showLimitedSection = false
    
    // Filtered and sorted processes
    private var filteredProcesses: [AppProcessInfo] {
        var processes = processMonitor.processes
        
        // Filter by search
        if !searchText.isEmpty {
            processes = processes.filter {
                $0.appName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        processes.sort { a, b in
            let result: Bool
            switch sortColumn {
            case .name:
                result = a.appName.localizedCaseInsensitiveCompare(b.appName) == .orderedAscending
            case .cpu:
                result = a.cpuPercent < b.cpuPercent
            case .avg:
                result = a.cpuAverage < b.cpuAverage
            }
            return sortOrder == .ascending ? result : !result
        }
        
        return processes
    }
    
    // All limited processes (E-limited + auto-stopped)
    private var limitedProcesses: [AppProcessInfo] {
        processMonitor.processes.filter { ruleStore.modeForApp($0.appName) != nil }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Summary Header with master toggle
            CPUSummaryHeader(
                summary: processMonitor.summary,
                isEnabled: processMonitor.isEnabled,
                onToggle: { processMonitor.toggle() }
            )
            
            Divider()
            
            // CPU Graph (collapsible)
            if showGraph && !processMonitor.cpuHistory.isEmpty {
                CPUGraphMini(history: processMonitor.cpuHistory)
                    .padding(.vertical, 4)
                Divider()
            }
            
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                TextField("Filter processes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                
                // Graph toggle
                Button(action: { showGraph.toggle() }) {
                    Image(systemName: showGraph ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis")
                        .foregroundColor(showGraph ? .blue : .secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(showGraph ? "Hide graph" : "Show graph")
                
                // System processes toggle
                Button(action: { processMonitor.showSystemProcesses.toggle() }) {
                    Image(systemName: processMonitor.showSystemProcesses ? "eye" : "eye.slash")
                        .foregroundColor(processMonitor.showSystemProcesses ? .blue : .secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(processMonitor.showSystemProcesses ? "Showing system processes (click to hide)" : "Hiding system processes (click to show)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Divider()
            
            // Column headers (clickable for sorting)
            HStack(spacing: 6) {
                Text("")
                    .frame(width: 8)  // status dot
                Text("")
                    .frame(width: 18)  // icon
                
                // Name column - sortable
                Button(action: { toggleSort(.name) }) {
                    HStack(spacing: 2) {
                        Text("Name")
                        sortIndicator(for: .name)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 140, alignment: .leading)
                
                Text("CPU")
                    .frame(maxWidth: .infinity)
                
                // Now column - sortable
                Button(action: { toggleSort(.cpu) }) {
                    HStack(spacing: 2) {
                        Text("Now")
                        sortIndicator(for: .cpu)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 42, alignment: .trailing)
                
                // Avg column - sortable
                Button(action: { toggleSort(.avg) }) {
                    HStack(spacing: 2) {
                        Text("Avg")
                        sortIndicator(for: .avg)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 36, alignment: .trailing)
                
                Text("Mode")
                    .frame(width: 55)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            Divider()
            
            // Process list
            if filteredProcesses.isEmpty {
                VStack(spacing: 8) {
                    if processMonitor.processes.isEmpty {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading processes...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No matches for '\(searchText)'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredProcesses) { process in
                            ProcessRowView(process: process)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Divider()
            
            // Expandable Limited section (unified for E-limited and auto-stopped)
            if showLimitedSection && !limitedProcesses.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("Limited")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    
                    ForEach(limitedProcesses) { process in
                        LimitedProcessRow(process: process)
                    }
                }
                .background(Color.gray.opacity(0.08))
                
                Divider()
            }
            
            // Footer
            HStack(spacing: 12) {
                // Limited count - clickable
                if !limitedProcesses.isEmpty {
                    Button(action: { showLimitedSection.toggle() }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 8, height: 8)
                            Text("\(limitedProcesses.count) limited")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text(showLimitedSection ? "(hide)" : "(show)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Click to \(showLimitedSection ? "hide" : "show") limited apps")
                }
                
                Spacer()
                
                Button("Settings") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onAppear {
            setupConnections()
            processMonitor.menuOpened()
        }
        .onDisappear {
            processMonitor.menuClosed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
    }
    
    private func setupConnections() {
        cpuLimiter.setProcessMonitor(processMonitor)
        ruleStore.setCPULimiter(cpuLimiter)
        ruleStore.setProcessMonitor(processMonitor)
        processMonitor.setRuleStore(ruleStore)
        hogDetector.setProcessMonitor(processMonitor)
        hogDetector.setRuleStore(ruleStore)
    }
    
    private func toggleSort(_ column: SortColumn) {
        if sortColumn == column {
            // Toggle order if same column
            sortOrder = sortOrder == .ascending ? .descending : .ascending
        } else {
            // New column, default to descending for CPU, ascending for name
            sortColumn = column
            sortOrder = column == .name ? .ascending : .descending
        }
    }
    
    @ViewBuilder
    private func sortIndicator(for column: SortColumn) -> some View {
        if sortColumn == column {
            Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                .font(.system(size: 8))
                .foregroundColor(.blue)
        } else {
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8))
                .foregroundColor(.secondary.opacity(0.5))
        }
    }
}

// Compact row for limited processes in expandable section
struct LimitedProcessRow: View {
    let process: AppProcessInfo
    
    @EnvironmentObject var ruleStore: RuleStore
    
    private var mode: ThrottleMode? {
        ruleStore.modeForApp(process.appName)
    }
    
    private var modeText: String {
        switch mode {
        case .efficiency: return "E-limited"
        case .stopped: return "auto-stopped"
        default: return ""
        }
    }
    
    private var modeColor: Color {
        switch mode {
        case .efficiency: return .blue
        case .stopped: return .orange
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // App icon
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            
            // App name
            Text(process.appName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // CPU %
            Text(String(format: "%.0f%%", process.cpuPercent))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
            
            // Mode text
            Text(modeText)
                .font(.caption2)
                .foregroundColor(modeColor)
                .frame(width: 70, alignment: .trailing)
            
            // Remove button
            Button(action: {
                ruleStore.setModeForApp(process.appName, mode: nil)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove limit")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }
}
