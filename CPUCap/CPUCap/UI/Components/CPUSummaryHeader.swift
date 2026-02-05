import SwiftUI

struct CPUSummaryHeader: View {
    let summary: CPUSummary
    let isEnabled: Bool
    let onToggle: () -> Void
    
    private var cpuName: String {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var name = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &name, &size, nil, 0)
        return String(cString: name)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Title row with master toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU Cap")
                        .font(.headline)
                    Text(cpuName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Master on/off toggle
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)
            }
            
            // Stats row
            HStack(spacing: 16) {
                // Total CPU
                StatBox(
                    title: "Total",
                    value: "\(Int(summary.totalCPU))%",
                    color: colorForCPU(summary.totalCPU)
                )
                
                // P-cores
                StatBox(
                    title: "\(summary.pCoreCount) P-cores",
                    value: "\(Int(summary.pCoreCPU))%",
                    color: .blue
                )
                
                // E-cores
                StatBox(
                    title: "\(summary.eCoreCount) E-cores",
                    value: "\(Int(summary.eCoreCPU))%",
                    color: .cyan
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func colorForCPU(_ percent: Double) -> Color {
        if percent < 50 {
            return .green
        } else if percent < 80 {
            return .orange
        } else {
            return .red
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 50)
    }
}
