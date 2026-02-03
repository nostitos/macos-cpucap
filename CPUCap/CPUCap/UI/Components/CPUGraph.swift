import SwiftUI

struct CPUGraph: View {
    let history: [CPUHistoryPoint]
    let height: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 1)
                        Spacer()
                    }
                }
                
                // Draw the CPU line
                if history.count > 1 {
                    Path { path in
                        let maxY = height
                        let stepX = geo.size.width / CGFloat(max(history.count - 1, 1))
                        
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
                    .stroke(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    
                    // Fill under the line
                    Path { path in
                        let maxY = height
                        let stepX = geo.size.width / CGFloat(max(history.count - 1, 1))
                        
                        path.move(to: CGPoint(x: 0, y: maxY))
                        
                        for (index, point) in history.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = maxY - (CGFloat(min(point.totalCPU, 100)) / 100.0 * maxY)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        path.addLine(to: CGPoint(x: geo.size.width, y: maxY))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.3),
                                Color.yellow.opacity(0.2),
                                Color.orange.opacity(0.1)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
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
            }
        }
        .frame(height: height)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }
}

// Compact version for menu bar
struct CPUGraphMini: View {
    let history: [CPUHistoryPoint]
    
    var body: some View {
        CPUGraph(history: history, height: 56)  // 40 * 1.4 = 56
            .padding(.horizontal, 12)
    }
}
