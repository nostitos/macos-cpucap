import SwiftUI

struct CPUBar: View {
    let percent: Double
    let mode: ThrottleMode?
    let pCoreCount: Int
    
    // Full bar = 50% of P-core capacity
    private var maxPercent: Double {
        Double(max(pCoreCount, 1)) * 100.0 * 0.5
    }
    
    // Percentage of bar filled (capped at 1.0)
    private var capacityUsed: Double {
        percent / maxPercent
    }
    
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
        // Color based on P-core capacity usage, not raw percent
        if capacityUsed > 0.8 {
            return .red
        } else if capacityUsed > 0.5 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var fillWidth: CGFloat {
        // Scale to P-core capacity
        min(CGFloat(capacityUsed), 1.0)
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
