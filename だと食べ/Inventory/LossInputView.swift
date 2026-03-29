import SwiftUI

struct LossInputView: View {
    @Binding var ingredients: [InventoryItem]
    @Binding var preps: [InventoryItem]
    @State private var mode: InventoryMode = .ingredient
    @State private var selectedId: UUID?
    @State private var quantityText = "1"
    @State private var logs: [LossLog] = []
    
    private var options: [InventoryItem] {
        mode == .ingredient ? ingredients : preps
    }
    
    var body: some View {
        List {
            Section("ロス入力") {
                Picker("対象", selection: $mode) {
                    ForEach(InventoryMode.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _ in
                    selectedId = options.first?.id
                }
                
                Picker("名称", selection: Binding(
                    get: { selectedId ?? options.first?.id ?? UUID() },
                    set: { selectedId = $0 }
                )) {
                    ForEach(options) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                
                TextField("数量", text: $quantityText)
                    .keyboardType(.decimalPad)
                
                Button("保存", action: saveLoss)
                    .buttonStyle(.borderedProminent)
            }
            
            Section("ロス一覧") {
                if logs.isEmpty {
                    Text("ロス記録なし")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(logs) { log in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.itemName)
                            Text("\(log.quantity, specifier: "%.3f") / \(log.at.formatted(date: .numeric, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("ロス入力")
        .onAppear {
            if selectedId == nil { selectedId = options.first?.id }
        }
    }
    
    private func saveLoss() {
        guard let selectedId, let quantity = Double(quantityText), quantity > 0 else { return }
        
        if mode == .ingredient {
            guard let index = ingredients.firstIndex(where: { $0.id == selectedId }) else { return }
            let actualLoss = min(quantity, ingredients[index].currentStock)
            ingredients[index].currentStock = clampNumber(ingredients[index].currentStock - actualLoss)
            logs.insert(LossLog(itemName: ingredients[index].name, quantity: actualLoss, at: Date()), at: 0)
        } else {
            guard let index = preps.firstIndex(where: { $0.id == selectedId }) else { return }
            let actualLoss = min(quantity, preps[index].currentStock)
            preps[index].currentStock = clampNumber(preps[index].currentStock - actualLoss)
            logs.insert(LossLog(itemName: preps[index].name, quantity: actualLoss, at: Date()), at: 0)
        }
        
        quantityText = "1"
    }
}

private struct LossLog: Identifiable {
    let id = UUID()
    let itemName: String
    let quantity: Double
    let at: Date
}
