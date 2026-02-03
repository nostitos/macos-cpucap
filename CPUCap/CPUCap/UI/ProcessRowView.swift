import SwiftUI

struct ProcessRowView: View {
    let process: AppProcessInfo
    let showAverage: Bool
    
    @EnvironmentObject var processMonitor: ProcessMonitor
    @EnvironmentObject var cpuLimiter: CPULimiter
    @EnvironmentObject var ruleStore: RuleStore
    
    @State private var showingCapPicker = false
    
    init(process: AppProcessInfo, showAverage: Bool = true) {
        self.process = process
        self.showAverage = showAverage
    }
    
    private func openDetail() {
        WindowManager.shared.openProcessDetail(
            process: process,
            processMonitor: processMonitor,
            cpuLimiter: cpuLimiter,
            ruleStore: ruleStore
        )
    }
    
    private var currentCap: Double? {
        ruleStore.ruleForApp(process.appName)?.capPercent
    }
    
    private var isLimiting: Bool {
        cpuLimiter.isLimiting(process.appName)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // App icon - clickable
            Group {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                }
            }
            .onTapGesture {
                openDetail()
            }
            
            // App name - clickable to show details
            Text(process.appName)
                .font(.system(.body, design: .default))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 140, alignment: .leading)
                .onTapGesture {
                    openDetail()
                }
                .help("Click for details")
            
            // CPU bar
            CPUBar(percent: process.cpuPercent, cap: currentCap)
                .frame(height: 14)
            
            // CPU percentage (current)
            Text(formatCPU(process.cpuPercent))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 42, alignment: .trailing)
            
            // Average CPU (if enabled)
            if showAverage {
                Text(formatCPU(process.cpuAverage))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            
            // Cap picker
            CapPicker(
                currentCap: currentCap,
                isLimiting: isLimiting,
                suggestedCap: DefaultRules.suggestedCap(for: process.appName)
            ) { newCap in
                ruleStore.setCapForApp(process.appName, cap: newCap)
            }
            .frame(width: 55)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(rowBackground)
        .cornerRadius(4)
        .padding(.horizontal, 4)
    }
    
    private var statusColor: Color {
        switch process.status {
        case .running:
            return .green
        case .slowed:
            return .blue
        case .stopped:
            return .red
        }
    }
    
    private var rowBackground: Color {
        switch process.status {
        case .running:
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        case .slowed:
            return Color.blue.opacity(0.1)
        case .stopped:
            return Color.red.opacity(0.1)
        }
    }
    
    private func formatCPU(_ value: Double) -> String {
        if value >= 100 {
            return "\(Int(value))%"
        } else if value >= 10 {
            return "\(Int(value))%"
        } else {
            return String(format: "%.1f%%", value)
        }
    }
}

// Compact row for tamed processes section
struct TamedProcessRow: View {
    let process: AppProcessInfo
    
    @EnvironmentObject var processMonitor: ProcessMonitor
    @EnvironmentObject var cpuLimiter: CPULimiter
    @EnvironmentObject var ruleStore: RuleStore
    
    private func openDetail() {
        WindowManager.shared.openProcessDetail(
            process: process,
            processMonitor: processMonitor,
            cpuLimiter: cpuLimiter,
            ruleStore: ruleStore
        )
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Status dot
            Circle()
                .fill(process.status == .slowed ? Color.blue : Color.green)
                .frame(width: 6, height: 6)
            
            // App icon - clickable
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .onTapGesture {
                        openDetail()
                    }
            }
            
            // App name - clickable
            Text(process.appName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .onTapGesture {
                    openDetail()
                }
            
            Spacer()
            
            // Cap value
            if let cap = process.capPercent {
                Text("\(Int(cap))%")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.orange)
            }
            
            // Remove button
            Button(action: {
                ruleStore.setCapForApp(process.appName, cap: nil)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}
