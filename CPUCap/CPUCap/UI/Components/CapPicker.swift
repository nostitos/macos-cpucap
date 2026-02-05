import SwiftUI

struct ModePicker: View {
    let currentMode: ThrottleMode?
    let isThrottling: Bool
    let onModeChanged: (ThrottleMode?) -> Void
    
    var body: some View {
        Menu {
            Button(action: { onModeChanged(nil) }) {
                HStack {
                    Text("Full Speed")
                    if currentMode == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            Button(action: { onModeChanged(.efficiency) }) {
                HStack {
                    Text("Efficiency")
                    Text("runs on E-cores")
                        .foregroundColor(.secondary)
                    if currentMode == .efficiency {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Button(action: { onModeChanged(.stopped) }) {
                HStack {
                    Text("Auto-Stop")
                    Text("pauses in background, resumes when focused")
                        .foregroundColor(.secondary)
                    if currentMode == .stopped {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(labelText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(labelColor)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
    
    private var labelText: String {
        guard let mode = currentMode else { return "--" }
        return mode.indicator.isEmpty ? "--" : mode.indicator
    }
    
    private var labelColor: Color {
        guard let mode = currentMode else { return .secondary }
        switch mode {
        case .fullSpeed: return .secondary
        case .efficiency: return .blue
        case .stopped: return .red
        }
    }
    
    private var backgroundColor: Color {
        guard let mode = currentMode else { return Color.gray.opacity(0.1) }
        switch mode {
        case .fullSpeed: return Color.gray.opacity(0.1)
        case .efficiency: return Color.blue.opacity(0.2)
        case .stopped: return Color.red.opacity(0.2)
        }
    }
}

// Legacy compatibility alias
typealias CapPicker = ModePicker
