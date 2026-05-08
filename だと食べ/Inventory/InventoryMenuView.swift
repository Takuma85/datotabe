import SwiftUI

private let inventoryIngredientsStorageKey = "inventory.items.ingredients.v1"
private let inventoryPrepsStorageKey = "inventory.items.preps.v1"

struct InventoryItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var category: String
    var unit: String
    var onHand: Double
    var reorderPoint: Double
    var reservedQuantity: Double
    
    var availableQuantity: Double {
        clampNumber(max(onHand - reservedQuantity, 0))
    }
    
    var currentStock: Double {
        get { onHand }
        set { onHand = clampNumber(newValue) }
    }
    
    init(id: UUID = UUID(), name: String, category: String = "未分類", unit: String, currentStock: Double, reorderPoint: Double, reservedQuantity: Double = 0) {
        self.id = id
        self.name = name
        self.category = category
        self.unit = unit
        self.onHand = clampNumber(currentStock)
        self.reorderPoint = clampNumber(reorderPoint)
        self.reservedQuantity = clampNumber(reservedQuantity)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case unit
        case onHand
        case currentStock
        case reorderPoint
        case reservedQuantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        unit = try container.decode(String.self, forKey: .unit)
        let decodedOnHand = try container.decodeIfPresent(Double.self, forKey: .onHand)
        let decodedCurrentStock = try container.decodeIfPresent(Double.self, forKey: .currentStock)
        onHand = clampNumber(decodedOnHand ?? decodedCurrentStock ?? 0)
        reorderPoint = clampNumber((try container.decodeIfPresent(Double.self, forKey: .reorderPoint)) ?? 0)
        reservedQuantity = clampNumber((try container.decodeIfPresent(Double.self, forKey: .reservedQuantity)) ?? 0)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(unit, forKey: .unit)
        try container.encode(clampNumber(onHand), forKey: .onHand)
        try container.encode(clampNumber(reorderPoint), forKey: .reorderPoint)
        try container.encode(clampNumber(reservedQuantity), forKey: .reservedQuantity)
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

enum InventoryStorage {
    static func loadIngredients() -> [InventoryItem] {
        let raw = AppJSONStore.load([InventoryItem].self, key: inventoryIngredientsStorageKey, fallback: InventorySeeds.ingredients)
        return applyReservations(to: sanitize(raw))
    }

    static func saveIngredients(_ items: [InventoryItem]) {
        let normalized = sanitize(items).map { item -> InventoryItem in
            var copied = item
            copied.reservedQuantity = 0
            return copied
        }
        AppJSONStore.save(normalized, key: inventoryIngredientsStorageKey)
    }

    static func loadPreps() -> [InventoryItem] {
        let raw = AppJSONStore.load([InventoryItem].self, key: inventoryPrepsStorageKey, fallback: InventorySeeds.preps)
        return sanitize(raw)
    }

    static func savePreps(_ items: [InventoryItem]) {
        let normalized = sanitize(items).map { item -> InventoryItem in
            var copied = item
            copied.reservedQuantity = 0
            return copied
        }
        AppJSONStore.save(normalized, key: inventoryPrepsStorageKey)
    }

    private static func sanitize(_ items: [InventoryItem]) -> [InventoryItem] {
        items.map { item in
            var copied = item
            copied.onHand = clampNumber(item.onHand)
            copied.reorderPoint = clampNumber(item.reorderPoint)
            copied.reservedQuantity = clampNumber(item.reservedQuantity)
            return copied
        }
    }

    private static func applyReservations(to items: [InventoryItem]) -> [InventoryItem] {
        let reservedByItem = loadInventoryReservations().reduce(into: [UUID: Double]()) { result, reservation in
            result[reservation.inventoryItemId, default: 0] += reservation.quantity
        }

        return items.map { item in
            var copied = item
            copied.reservedQuantity = clampNumber(reservedByItem[item.id] ?? 0)
            return copied
        }
    }
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
    @State private var ingredients: [InventoryItem] = InventoryStorage.loadIngredients()
    @State private var preps: [InventoryItem] = InventoryStorage.loadPreps()
    
    private var lowStockCount: Int {
        ReorderEngine.reorderSuggestions(items: ingredients, useLessOrEqual: useLessOrEqual).count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("在庫管理")
                        .font(.title2.bold())
                    Text("納品・棚卸し・ロス・発注アラートをここから管理")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 10) {
                    summaryCard(title: "食材", value: "\(ingredients.count)品目")
                    summaryCard(title: "仕込み品", value: "\(preps.count)品目")
                    summaryCard(title: "要発注", value: "\(lowStockCount)件", isWarning: lowStockCount > 0)
                }

                inventorySnapshot(title: "食材在庫", items: ingredients)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("発注アラート")
                            .font(.headline)
                        Spacer()
                        Toggle("発注点を含める", isOn: $useLessOrEqual)
                            .labelsHidden()
                    }
                    
                    HStack(spacing: 8) {
                        Text(useLessOrEqual ? "判定: 現在庫が発注点以下" : "判定: 現在庫が発注点未満")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("再計算", action: runReorderCheck)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    
                    if alerts.isEmpty {
                        Text("現在アラートはありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(alerts.prefix(3), id: \.self) { alert in
                                Text(alert)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
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
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    NavigationLink {
                        OrderAlertView(
                            ingredients: $ingredients,
                            useLessOrEqual: $useLessOrEqual,
                            alerts: $alerts
                        )
                    } label: {
                        menuCard(title: "発注アラート")
                    }
                    NavigationLink {
                        DeliveryInputView(items: $ingredients)
                    } label: {
                        menuCard(title: "納品入力")
                    }
                    NavigationLink {
                        PrepInputView(items: $preps)
                    } label: {
                        menuCard(title: "仕込入力")
                    }
                    NavigationLink {
                        StocktakeInputView(ingredients: $ingredients, preps: $preps)
                    } label: {
                        menuCard(title: "棚卸入力")
                    }
                    NavigationLink {
                        LossInputView(ingredients: $ingredients, preps: $preps)
                    } label: {
                        menuCard(title: "ロス入力")
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            reloadInventory()
        }
        .onChange(of: ingredients) { _, _ in
            InventoryStorage.saveIngredients(ingredients)
            runReorderCheck()
        }
        .onChange(of: preps) { _, _ in
            InventoryStorage.savePreps(preps)
        }
    }

    @ViewBuilder
    private func inventorySnapshot(title: String, items: [InventoryItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    reloadInventory()
                } label: {
                    Text("再読込")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if items.isEmpty {
                Text("在庫品目がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(item.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            inventoryMetric(label: "理論在庫", value: formatQty(item.onHand, unit: item.unit))
                            inventoryMetric(label: "引当", value: formatQty(item.reservedQuantity, unit: item.unit))
                            inventoryMetric(label: "利用可能", value: formatQty(item.availableQuantity, unit: item.unit))
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func inventoryMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func summaryCard(title: String, value: String, isWarning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(isWarning ? .orange : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func menuCard(title: String) -> some View {
        HStack(spacing: 8) {
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
    }

    private func reloadInventory() {
        ingredients = InventoryStorage.loadIngredients()
        preps = InventoryStorage.loadPreps()
        runReorderCheck()
    }
}

#Preview {
    NavigationStack {
        InventoryMenuView()
    }
}
