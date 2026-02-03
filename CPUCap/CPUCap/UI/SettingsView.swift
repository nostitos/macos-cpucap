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
    
    @State private var selectedTab: SettingsTab = .general
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var hogThreshold: Double = 80
    @State private var hogDuration: Double = 10
    @State private var alertsEnabled = true
    
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
            
            GroupBox("About") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CPU Cap monitors running processes and enforces CPU usage limits using SIGSTOP/SIGCONT signals.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Processes are grouped by app name - all helper processes (like browser renderers) are counted together.")
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
                    }
                    .padding(8)
            }
            
            GroupBox("Alert Threshold") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("CPU threshold:")
                        Slider(value: $hogThreshold, in: 50...100, step: 5)
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
            
            Text("\(Int(rule.capPercent))%")
                .foregroundColor(.orange)
                .fontWeight(.medium)
                .frame(width: 50)
            
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
}
