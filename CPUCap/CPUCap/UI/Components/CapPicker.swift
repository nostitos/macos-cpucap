import SwiftUI

struct CapPicker: View {
    let currentCap: Double?
    let isLimiting: Bool
    let suggestedCap: Double?
    let onCapChanged: (Double?) -> Void
    
    @State private var showingCustomInput = false
    @State private var customValue: String = ""
    
    private let presets: [Double?] = [nil, 5, 10, 15, 20, 25, 30, 50]
    
    var body: some View {
        Menu {
            Button(action: { onCapChanged(nil) }) {
                HStack {
                    Text("No limit")
                    if currentCap == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            ForEach(presets.compactMap { $0 }, id: \.self) { preset in
                Button(action: { onCapChanged(preset) }) {
                    HStack {
                        Text("\(Int(preset))%")
                        if let cap = currentCap, cap == preset {
                            Image(systemName: "checkmark")
                        }
                        if let suggested = suggestedCap, suggested == preset, currentCap != preset {
                            Text("(suggested)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Custom...") {
                customValue = currentCap != nil ? "\(Int(currentCap!))" : ""
                showingCustomInput = true
            }
        } label: {
            HStack(spacing: 2) {
                if let cap = currentCap {
                    Text("\(Int(cap))%")
                        .font(.system(.caption, design: .monospaced))
                } else {
                    Text("--")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(currentCap != nil ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .sheet(isPresented: $showingCustomInput) {
            CustomCapInputView(
                value: $customValue,
                onSubmit: { value in
                    if let intValue = Int(value), intValue > 0, intValue <= 100 {
                        onCapChanged(Double(intValue))
                    }
                    showingCustomInput = false
                },
                onCancel: {
                    showingCustomInput = false
                }
            )
        }
    }
}

struct CustomCapInputView: View {
    @Binding var value: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Set Custom CPU Cap")
                .font(.headline)
            
            HStack {
                TextField("Cap %", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("%")
            }
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button("Set") {
                    onSubmit(value)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(Int(value) == nil || Int(value)! <= 0 || Int(value)! > 100)
            }
        }
        .padding(20)
        .frame(width: 200)
    }
}
