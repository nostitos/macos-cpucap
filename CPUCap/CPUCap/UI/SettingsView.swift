import SwiftUI
import ServiceManagement

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case rules = "Rules"
    case alerts = "Alerts"
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .rules: return "list.bullet"
        case .alerts: return "bell"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var hogDetector: HogDetector
    @EnvironmentObject var processMonitor: ProcessMonitor
    
    @State private var selectedTab: SettingsTab = .general
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var hogThreshold: Double = 40
    @State private var hogDuration: Double = 10
    @State private var alertsEnabled = true
    @State private var samplingInterval: Double = 2.0
    
    var body: some View {
        HSplitView {
            // Sidebar
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .listStyle(.sidebar)
            .frame(width: 150)
            
            // Content
            VStack {
                switch selectedTab {
                case .general:
                    generalContent
                case .rules:
                    rulesContent
                case .alerts:
                    alertsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 550, height: 400)
        .onAppear {
            hogThreshold = hogDetector.hogThreshold
            hogDuration = hogDetector.hogDuration
            alertsEnabled = hogDetector.alertsEnabled
            samplingInterval = processMonitor.samplingInterval
        }
    }
    
    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)
            
            GroupBox("Startup") {
                Toggle("Launch CPU Cap at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LoginItemManager.setLaunchAtLogin(newValue)
                    }
                    .padding(8)
            }
            
            GroupBox("Sampling") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Update interval:")
                        Slider(value: $samplingInterval, in: 0.5...5.0, step: 0.5)
                        Text("\(String(format: "%.1f", samplingInterval))s")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                    .onChange(of: samplingInterval) { _, newValue in
                        processMonitor.setSamplingInterval(newValue)
                    }
                    
                    Text("How often CPU usage is measured. Lower = more responsive but uses more CPU.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            
            
            Spacer()
        }
        .padding(20)
    }
    
    private var rulesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Rules")
                .font(.title2)
                .fontWeight(.semibold)
            
            if ruleStore.rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No rules configured")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Set a cap on any process from the menu bar dropdown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(ruleStore.rules) { rule in
                        RuleRowView(rule: rule)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            ruleStore.removeRule(ruleStore.rules[index])
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }
    
    private var alertsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CPU Hog Alerts")
                .font(.title2)
                .fontWeight(.semibold)
            
            GroupBox {
                Toggle("Enable CPU hog alerts", isOn: $alertsEnabled)
                    .onChange(of: alertsEnabled) { _, newValue in
                        hogDetector.alertsEnabled = newValue
                        if newValue {
                            hogDetector.start()
                        } else {
                            hogDetector.stop()
                        }
                    }
                    .padding(8)
            }
            
            GroupBox("Alert Threshold") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("CPU threshold:")
                        Slider(value: $hogThreshold, in: 15...100, step: 5)
                        Text("\(Int(hogThreshold))%")
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                    .onChange(of: hogThreshold) { _, newValue in
                        hogDetector.setThreshold(newValue)
                    }
                    
                    HStack {
                        Text("Duration:")
                        Slider(value: $hogDuration, in: 5...60, step: 5)
                        Text("\(Int(hogDuration))s")
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                    .onChange(of: hogDuration) { _, newValue in
                        hogDetector.setDuration(newValue)
                    }
                    
                    Text("Alert when a process exceeds \(Int(hogThreshold))% CPU for more than \(Int(hogDuration)) seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            .disabled(!alertsEnabled)
            .opacity(alertsEnabled ? 1.0 : 0.5)
            
            Spacer()
        }
        .padding(20)
    }
}

struct RuleRowView: View {
    let rule: Rule
    @EnvironmentObject var ruleStore: RuleStore
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { newValue in
                    var updated = rule
                    updated.enabled = newValue
                    ruleStore.updateRule(updated)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            
            Text(rule.appName)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(modeText(rule.mode))
                .foregroundColor(modeColor(rule.mode))
                .fontWeight(.medium)
                .frame(width: 70)
            
            Button(action: {
                ruleStore.removeRule(rule)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private func modeText(_ mode: ThrottleMode) -> String {
        switch mode {
        case .fullSpeed: return "Full"
        case .efficiency: return "E-cores"
        case .stopped: return "Stopped"
        }
    }
    
    private func modeColor(_ mode: ThrottleMode) -> Color {
        switch mode {
        case .fullSpeed: return .green
        case .efficiency: return .blue
        case .stopped: return .red
        }
    }
}
