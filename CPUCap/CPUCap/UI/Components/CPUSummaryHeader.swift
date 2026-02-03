import SwiftUI

struct CPUSummaryHeader: View {
    let summary: CPUSummary
    let isEnabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Title row with master toggle
            HStack {
                Text("CPU Cap")
                    .font(.headline)
                
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
                    title: "P-cores",
                    value: "\(Int(summary.pCoreCPU))%",
                    color: .blue
                )
                
                // E-cores
                StatBox(
                    title: "E-cores",
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
