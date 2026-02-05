import SwiftUI

struct CPUBar: View {
    let percent: Double
    let mode: ThrottleMode?
    
    private var barColor: Color {
        if let mode = mode {
            switch mode {
            case .fullSpeed:
                return defaultColor
            case .efficiency:
                return .blue
            case .stopped:
                return .red
            }
        }
        return defaultColor
    }
    
    private var defaultColor: Color {
        if percent > 80 {
            return .red
        } else if percent > 50 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var fillWidth: CGFloat {
        min(percent / 100.0, 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                
                // Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: geometry.size.width * fillWidth)
                
                // Mode indicator overlay
                if let mode = mode, mode != .fullSpeed {
                    HStack {
                        Spacer()
                        Text(mode.indicator)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.trailing, 2)
                    }
                }
            }
        }
    }
}
