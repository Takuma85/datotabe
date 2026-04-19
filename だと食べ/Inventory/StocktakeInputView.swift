import SwiftUI

struct StocktakeInputView: View {
    @Binding var ingredients: [InventoryItem]
    @Binding var preps: [InventoryItem]
    @State private var mode: InventoryMode = .ingredient
    @State private var searchText = ""
    @State private var counts: [UUID: String] = [:]
    
    private var list: [InventoryItem] {
        mode == .ingredient ? ingredients : preps
    }
    
    private var filtered: [InventoryItem] {
        if searchText.isEmpty { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List {
            Section {
                Picker("対象", selection: $mode) {
                    ForEach(InventoryMode.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                
                TextField("名前で検索", text: $searchText)
                    .textInputAutocapitalization(.never)
                
                Button("一括確定", action: bulkCommit)
            }
            
            Section("\(mode.rawValue)：\(filtered.count)件") {
                ForEach(filtered) { item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).font(.headline)
                            Text("理論在庫: \(formatQty(item.currentStock, unit: item.unit)) / 発注点: \(formatQty(item.reorderPoint, unit: item.unit))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField("棚卸し数", text: bindingForCount(of: item))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Button("確定") {
                            commit(item: item)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("棚卸入力")
    }
    
    private func bindingForCount(of item: InventoryItem) -> Binding<String> {
        Binding(
            get: { counts[item.id, default: ""] },
            set: { counts[item.id] = $0 }
        )
    }
    
    private func commit(item: InventoryItem) {
        let text = counts[item.id, default: ""]
        guard let value = Double(text) else { return }
        apply(itemId: item.id, value: clampNumber(value))
    }
    
    private func bulkCommit() {
        for item in list where counts[item.id] != nil {
            commit(item: item)
        }
    }
    
    private func apply(itemId: UUID, value: Double) {
        if mode == .ingredient {
            ingredients = ingredients.map { current in
                guard current.id == itemId else { return current }
                var updated = current
                updated.currentStock = value
                return updated
            }
        } else {
            preps = preps.map { current in
                guard current.id == itemId else { return current }
                var updated = current
                updated.currentStock = value
                return updated
            }
        }
    }
}
