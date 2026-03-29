import SwiftUI

struct OrderAlertView: View {
    @Binding var ingredients: [InventoryItem]
    @Binding var useLessOrEqual: Bool
    @Binding var alerts: [String]
    
    var body: some View {
        List {
            Section {
                Toggle("境界を含む（≤）", isOn: $useLessOrEqual)
                Button("アラート再計算", action: runReorderCheck)
            }
            Section("アラート") {
                if alerts.isEmpty {
                    Text("アラートはありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(alerts, id: \.self) { alert in
                        Text(alert)
                    }
                }
            }
        }
        .navigationTitle("発注アラート")
        .onAppear(perform: runReorderCheck)
    }
    
    private func runReorderCheck() {
        let targets = ReorderEngine.reorderSuggestions(items: ingredients, useLessOrEqual: useLessOrEqual)
        alerts = targets.map { item in
            "\(item.name) が発注点を下回りました（在庫 \(formatQty(item.currentStock, unit: item.unit))）"
        }
    }
}
