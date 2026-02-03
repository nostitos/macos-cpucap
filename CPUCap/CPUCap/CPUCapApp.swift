import SwiftUI
import AppKit

@main
struct CPUCapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var processMonitor = ProcessMonitor()
    @StateObject private var cpuLimiter = CPULimiter()
    @StateObject private var ruleStore = RuleStore()
    @StateObject private var hogDetector = HogDetector()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(processMonitor)
                .environmentObject(cpuLimiter)
                .environmentObject(ruleStore)
                .environmentObject(hogDetector)
                .frame(width: 420, height: 800)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                Text(formatCPU(processMonitor.summary.totalCPU))
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)
        
        Window("CPU Cap Settings", id: "settings") {
            SettingsView()
                .environmentObject(ruleStore)
                .environmentObject(hogDetector)
                .frame(minWidth: 450, minHeight: 350)
        }
        .windowResizability(.contentSize)
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
