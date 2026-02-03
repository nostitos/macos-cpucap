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
    
    // Processes with active caps (tamed)
    private var tamedProcesses: [AppProcessInfo] {
        processMonitor.processes.filter { $0.capPercent != nil }
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
                    Image(systemName: "gear")
                        .foregroundColor(processMonitor.showSystemProcesses ? .blue : .secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(processMonitor.showSystemProcesses ? "Hide system processes" : "Show system processes")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Divider()
            
            // Tamed processes section (if any)
            if !tamedProcesses.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("Tamed Apps")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(tamedProcesses.count)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    
                    ForEach(tamedProcesses) { process in
                        TamedProcessRow(process: process)
                    }
                }
                .background(Color.orange.opacity(0.05))
                
                Divider()
            }
            
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
                
                Text("Cap")
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
            
            // Footer
            HStack(spacing: 12) {
                // Enabled/Disabled status
                HStack(spacing: 4) {
                    Circle()
                        .fill(processMonitor.isEnabled ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(processMonitor.isEnabled ? "Active" : "Paused")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Active limits count
                if !cpuLimiter.activeLimits.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        Text("\(cpuLimiter.activeLimits.count) limited")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
    }
    
    private func setupConnections() {
        cpuLimiter.setProcessMonitor(processMonitor)
        ruleStore.setCPULimiter(cpuLimiter)
        ruleStore.setProcessMonitor(processMonitor)
        hogDetector.setProcessMonitor(processMonitor)
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
