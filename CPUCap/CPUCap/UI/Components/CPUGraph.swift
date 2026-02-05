import SwiftUI

struct CPUGraph: View {
    let history: [CPUHistoryPoint]
    let height: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 1)
                        Spacer()
                    }
                }
                
                if history.count > 1 {
                    let maxY = height
                    let stepX = geo.size.width / CGFloat(max(history.count - 1, 1))
                    
                    // Layer 1: E-limited (blue) - bottom layer
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: maxY))
                        
                        for (index, point) in history.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = maxY - (CGFloat(min(point.eLimitedCPU, 100)) / 100.0 * maxY)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        path.addLine(to: CGPoint(x: geo.size.width, y: maxY))
                        path.closeSubpath()
                    }
                    .fill(Color.blue.opacity(0.6))
                    
                    // Layer 2: Auto-stopped (orange) - stacked on E-limited
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: maxY))
                        
                        for (index, point) in history.enumerated() {
                            let x = CGFloat(index) * stepX
                            let stackedValue = point.eLimitedCPU + point.autoStoppedCPU
                            let y = maxY - (CGFloat(min(stackedValue, 100)) / 100.0 * maxY)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        // Go back along E-limited line to close
                        for (index, point) in history.enumerated().reversed() {
                            let x = CGFloat(index) * stepX
                            let y = maxY - (CGFloat(min(point.eLimitedCPU, 100)) / 100.0 * maxY)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        path.closeSubpath()
                    }
                    .fill(Color.orange.opacity(0.6))
                    
                    // Layer 3: Unlimited (green) - stacked on top
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: maxY))
                        
                        for (index, point) in history.enumerated() {
                            let x = CGFloat(index) * stepX
                            let totalStacked = point.eLimitedCPU + point.autoStoppedCPU + point.unlimitedCPU
                            let y = maxY - (CGFloat(min(totalStacked, 100)) / 100.0 * maxY)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        // Go back along previous stack line to close
                        for (index, point) in history.enumerated().reversed() {
                            let x = CGFloat(index) * stepX
                            let stackedValue = point.eLimitedCPU + point.autoStoppedCPU
                            let y = maxY - (CGFloat(min(stackedValue, 100)) / 100.0 * maxY)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        path.closeSubpath()
                    }
                    .fill(Color.green.opacity(0.5))
                    
                    // Total CPU line (white stroke on top)
                    Path { path in
                        for (index, point) in history.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = maxY - (CGFloat(min(point.totalCPU, 100)) / 100.0 * maxY)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
                
                // Y-axis labels
                VStack {
                    Text("100%")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("50%")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("0%")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(width: 25)
                
                // Legend (top-right)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 3) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Unlimited")
                    }
                    HStack(spacing: 3) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text("E-limited")
                    }
                    HStack(spacing: 3) {
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Text("Auto-stop")
                    }
                }
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .padding(4)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                .cornerRadius(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 4)
                .padding(.top, 2)
            }
        }
        .frame(height: height)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }
}

// Compact version for menu bar - taller now (was 56)
struct CPUGraphMini: View {
    let history: [CPUHistoryPoint]
    
    var body: some View {
        CPUGraph(history: history, height: 80)
            .padding(.horizontal, 12)
    }
}
