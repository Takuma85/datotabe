import SwiftUI

<<<<<<< HEAD
struct InventoryMenuView: View {
    @State private var inventoryItems: [InventoryItem] = []
    @State private var reservations: [InventoryReservation] = []
    @State private var transactions: [InventoryTransaction] = []

    private var activeItems: [InventoryItem] {
        inventoryItems
            .filter(\.isActive)
            .sorted { $0.name < $1.name }
    }

    private var recentTransactions: [InventoryTransaction] {
        transactions
            .sorted { $0.at > $1.at }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        List {
            Section("在庫操作") {
                NavigationLink("発注アラート", destination: OrderAlertView())
                NavigationLink("納品入力", destination: DeliveryInputView())
                NavigationLink("ロス入力", destination: LossInputView())
                NavigationLink("仕込入力", destination: PrepInputView())
                NavigationLink("棚卸入力", destination: StocktakeInputView())
            }

            Section("在庫一覧（on_hand / reserved / available）") {
                if activeItems.isEmpty {
                    Text("在庫品目がありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(activeItems) { item in
                        NavigationLink {
                            InventoryItemDetailView(inventoryItemId: item.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(item.availableQuantity <= item.reorderPoint ? "不足" : "通常")
                                        .font(.caption)
                                        .foregroundColor(item.availableQuantity <= item.reorderPoint ? .red : .secondary)
                                }
                                HStack(spacing: 12) {
                                    Label("on_hand \(item.onHand)", systemImage: "archivebox")
                                    Label("reserved \(item.reservedQuantity)", systemImage: "lock")
                                    Label("available \(item.availableQuantity)", systemImage: "checkmark.circle")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            Section("引当状況（席単位）") {
                if reservations.isEmpty {
                    Text("引当中のデータはありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(reservations.sorted { $0.updatedAt > $1.updatedAt }) { reservation in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(itemName(for: reservation.inventoryItemId))
                                    .font(.subheadline.weight(.medium))
                                Text("席 \(reservation.seatId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("×\(reservation.quantity)")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }

            Section("直近トランザクション") {
                if recentTransactions.isEmpty {
                    Text("トランザクションはありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(recentTransactions) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(itemName(for: transaction.inventoryItemId))
                                    .font(.subheadline.weight(.medium))
                                Text("\(transaction.reason.rawValue) / \(transaction.at.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(transaction.type == .out ? "-" : "+")\(transaction.quantity)")
                                .foregroundColor(transaction.type == .out ? .red : .blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("在庫数値")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    reload()
                } label: {
                    Label("再読込", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        inventoryItems = InventoryStorage.loadIngredients()
        reservations = InventoryStorage.loadReservations()
        transactions = InventoryStorage.loadTransactions()
    }

    private func itemName(for inventoryItemId: String) -> String {
        inventoryItems.first(where: { $0.id == inventoryItemId })?.name ?? "未登録品目"
    }
}

private struct InventoryItemDetailView: View {
    let inventoryItemId: String

    @State private var item: InventoryItem?
    @State private var reservations: [InventoryReservation] = []
    @State private var transactions: [InventoryTransaction] = []

    private var itemReservations: [InventoryReservation] {
        reservations
            .filter { $0.inventoryItemId == inventoryItemId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var itemTransactions: [InventoryTransaction] {
        transactions
            .filter { $0.inventoryItemId == inventoryItemId }
            .sorted { $0.at > $1.at }
            .prefix(20)
            .map { $0 }
    }

    var body: some View {
        Form {
            if let item {
                Section("在庫指標") {
                    metricRow(label: "on_hand", value: item.onHand)
                    metricRow(label: "reserved", value: item.reservedQuantity)
                    metricRow(label: "available", value: item.availableQuantity)
                    metricRow(label: "reorder_point", value: item.reorderPoint)
                }
            } else {
                Section {
                    Text("品目が見つかりません")
                        .foregroundColor(.secondary)
                }
            }

            Section("引当内訳") {
                if itemReservations.isEmpty {
                    Text("引当はありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(itemReservations) { reservation in
                        HStack {
                            Text("席 \(reservation.seatId)")
                            Spacer()
                            Text("×\(reservation.quantity)")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }

            Section("直近トランザクション") {
                if itemTransactions.isEmpty {
                    Text("履歴はありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(itemTransactions) { transaction in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(transaction.reason.rawValue)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(transaction.type == .out ? "-" : "+")\(transaction.quantity)")
                                    .foregroundColor(transaction.type == .out ? .red : .blue)
                            }
                            Text(transaction.at.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let seatId = transaction.seatId {
                                Text("席 \(seatId)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(item?.name ?? "在庫詳細")
        .onAppear(perform: reload)
    }

    private func reload() {
        item = InventoryStorage
            .loadIngredients()
            .first(where: { $0.id == inventoryItemId })
        reservations = InventoryStorage.loadReservations()
        transactions = InventoryStorage.loadTransactions()
    }

    private func metricRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
        }
=======
struct InventoryItem: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var unit: String
    var currentStock: Double
    var reorderPoint: Double
    
    init(id: UUID = UUID(), name: String, category: String = "未分類", unit: String, currentStock: Double, reorderPoint: Double) {
        self.id = id
        self.name = name
        self.category = category
        self.unit = unit
        self.currentStock = currentStock
        self.reorderPoint = reorderPoint
    }
}

enum InventoryMode: String, CaseIterable {
    case ingredient = "食材"
    case prep = "仕込み品"
}

enum ReorderEngine {
    static func reorderSuggestions(items: [InventoryItem], useLessOrEqual: Bool = true) -> [InventoryItem] {
        items.filter { item in
            useLessOrEqual ? item.currentStock <= item.reorderPoint : item.currentStock < item.reorderPoint
        }
    }
}

enum InventorySeeds {
    static let ingredients: [InventoryItem] = [
        InventoryItem(name: "牛乳", category: "乳製品", unit: "L", currentStock: 2, reorderPoint: 3),
        InventoryItem(name: "卵", category: "卵", unit: "個", currentStock: 30, reorderPoint: 12),
        InventoryItem(name: "小麦粉", category: "粉類", unit: "kg", currentStock: 5, reorderPoint: 5),
        InventoryItem(name: "砂糖", category: "調味料", unit: "kg", currentStock: 6, reorderPoint: 5),
        InventoryItem(name: "バター", category: "乳製品", unit: "g", currentStock: 499, reorderPoint: 500)
    ]
    
    static let preps: [InventoryItem] = [
        InventoryItem(name: "カレー", category: "主菜", unit: "食", currentStock: 8, reorderPoint: 5),
        InventoryItem(name: "プリン", category: "デザート", unit: "個", currentStock: 10, reorderPoint: 4)
    ]
}

func formatQty(_ value: Double, unit: String) -> String {
    let isInt = abs(value.rounded() - value) < 1e-9
    let numberText = isInt
        ? String(Int(value.rounded()))
        : String(format: "%.3f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    return "\(numberText)\(unit)"
}

func clampNumber(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return max(0, (value * 1000).rounded() / 1000)
}

struct InventoryMenuView: View {
    @State private var useLessOrEqual = true
    @State private var alerts: [String] = []
    @State private var ingredients: [InventoryItem] = InventorySeeds.ingredients
    @State private var preps: [InventoryItem] = InventorySeeds.preps
    
    private var lowStockCount: Int {
        ReorderEngine.reorderSuggestions(items: ingredients, useLessOrEqual: useLessOrEqual).count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("在庫数値")
                        .font(.title2.bold())
                    Text("納品・棚卸し・ロス・発注アラートをここから管理")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 10) {
                    summaryCard(title: "食材", value: "\(ingredients.count)品目", tint: .blue)
                    summaryCard(title: "仕込み品", value: "\(preps.count)品目", tint: .mint)
                    summaryCard(title: "要発注", value: "\(lowStockCount)件", tint: lowStockCount == 0 ? .green : .orange)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("発注アラート")
                            .font(.headline)
                        Spacer()
                        Toggle("境界を含む（≤）", isOn: $useLessOrEqual)
                            .labelsHidden()
                    }
                    
                    HStack(spacing: 8) {
                        Text(useLessOrEqual ? "判定: 現在庫 ≤ 発注点" : "判定: 現在庫 < 発注点")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("再計算", action: runReorderCheck)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    
                    if alerts.isEmpty {
                        Text("現在アラートはありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(alerts.prefix(3), id: \.self) { alert in
                                Text("• \(alert)")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.orange.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            if alerts.count > 3 {
                                Text("ほか \(alerts.count - 3) 件")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    NavigationLink {
                        OrderAlertView(
                            ingredients: $ingredients,
                            useLessOrEqual: $useLessOrEqual,
                            alerts: $alerts
                        )
                    } label: {
                        menuCard(icon: "exclamationmark.triangle.fill", title: "発注アラート", color: .orange)
                    }
                    NavigationLink {
                        DeliveryInputView(items: $ingredients)
                    } label: {
                        menuCard(icon: "tray.and.arrow.down.fill", title: "納品入力", color: .blue)
                    }
                    NavigationLink {
                        PrepInputView(items: $preps)
                    } label: {
                        menuCard(icon: "takeoutbag.and.cup.and.straw.fill", title: "仕込入力", color: .mint)
                    }
                    NavigationLink {
                        StocktakeInputView(ingredients: $ingredients, preps: $preps)
                    } label: {
                        menuCard(icon: "list.clipboard.fill", title: "棚卸入力", color: .indigo)
                    }
                    NavigationLink {
                        LossInputView(ingredients: $ingredients, preps: $preps)
                    } label: {
                        menuCard(icon: "trash.fill", title: "ロス入力", color: .red)
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            runReorderCheck()
        }
    }
    
    @ViewBuilder
    private func summaryCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func menuCard(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func runReorderCheck() {
        let targets = ReorderEngine.reorderSuggestions(items: ingredients, useLessOrEqual: useLessOrEqual)
        alerts = targets.map { item in
            "\(item.name) が発注点を下回りました（在庫 \(formatQty(item.currentStock, unit: item.unit))）"
        }
>>>>>>> origin/main
    }
}

#Preview {
    NavigationStack {
        InventoryMenuView()
    }
}
