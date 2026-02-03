import SwiftUI

struct CPUBar: View {
    let percent: Double
    let cap: Double?
    
    private var barColor: Color {
        if let cap = cap, percent > cap {
            return .orange
        } else if percent > 80 {
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
    
    private var capPosition: CGFloat? {
        guard let cap = cap else { return nil }
        return min(cap / 100.0, 1.0)
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
                
                // Cap indicator line
                if let capPos = capPosition {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)
                        .offset(x: geometry.size.width * capPos - 1)
                }
            }
        }
    }
}
