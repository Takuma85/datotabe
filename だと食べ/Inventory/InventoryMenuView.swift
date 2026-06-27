import SwiftUI

enum InventoryMode: String, CaseIterable {
    case ingredient = "食材"
    case prep = "仕込み品"
}

enum ReorderEngine {
    static func reorderSuggestions(items: [InventoryItem], useLessOrEqual: Bool = true) -> [InventoryItem] {
        items.filter { item in
            let stock = item.currentStock
            let reorderPoint = Double(item.reorderPoint)
            return useLessOrEqual ? stock <= reorderPoint : stock < reorderPoint
        }
    }
}

func formatQty(_ value: Int, unit: String) -> String {
    formatQty(Double(value), unit: unit)
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
    @State private var reservations: [InventoryReservation] = InventoryStorage.loadReservations()
    @State private var transactions: [InventoryTransaction] = InventoryStorage.loadTransactions()

    private var activeIngredients: [InventoryItem] {
        ingredients
            .filter(\.isActive)
            .sorted { $0.name < $1.name }
    }

    private var activePreps: [InventoryItem] {
        preps
            .filter(\.isActive)
            .sorted { $0.name < $1.name }
    }

    private var recentTransactions: [InventoryTransaction] {
        transactions
            .sorted { $0.at > $1.at }
            .prefix(10)
            .map { $0 }
    }

    private var lowStockCount: Int {
        ReorderEngine.reorderSuggestions(items: activeIngredients, useLessOrEqual: useLessOrEqual).count
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
                    summaryCard(title: "食材", value: "\(activeIngredients.count)品目")
                    summaryCard(title: "仕込み品", value: "\(activePreps.count)品目")
                    summaryCard(title: "要発注", value: "\(lowStockCount)件", isWarning: lowStockCount > 0)
                }

                reorderPanel

                inventorySnapshot(title: "食材在庫", items: activeIngredients, showsDetail: true)
                inventorySnapshot(title: "仕込み品", items: activePreps, showsDetail: false)
                reservationsPanel
                transactionPanel

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

    private var reorderPanel: some View {
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
    }

    @ViewBuilder
    private func inventorySnapshot(title: String, items: [InventoryItem], showsDetail: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("再読込", action: reloadInventory)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if items.isEmpty {
                Text("在庫品目がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    let row = inventoryRow(item)
                    if showsDetail {
                        NavigationLink {
                            InventoryItemDetailView(inventoryItemId: item.id)
                        } label: {
                            row
                        }
                        .buttonStyle(.plain)
                    } else {
                        row
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func inventoryRow(_ item: InventoryItem) -> some View {
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

            Text("発注点: \(formatQty(item.reorderPoint, unit: item.unit))")
                .font(.caption)
                .foregroundStyle(item.availableQuantity <= item.reorderPoint ? .orange : .secondary)
        }
        .padding(10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var reservationsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("引当状況")
                .font(.headline)

            if reservations.isEmpty {
                Text("引当中のデータはありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reservations.sorted { $0.updatedAt > $1.updatedAt }) { reservation in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(itemName(for: reservation.inventoryItemId))
                                .font(.subheadline.weight(.medium))
                            Text("席 \(reservation.seatId)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatQty(reservation.quantity, unit: itemUnit(for: reservation.inventoryItemId)))
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var transactionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("直近トランザクション")
                .font(.headline)

            if recentTransactions.isEmpty {
                Text("トランザクションはありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentTransactions) { transaction in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(itemName(for: transaction.inventoryItemId))
                                .font(.subheadline.weight(.medium))
                            Text("\(transaction.reason.rawValue) / \(transaction.at.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(transaction.type == .out ? "-" : "+")\(formatQty(transaction.quantity, unit: itemUnit(for: transaction.inventoryItemId)))")
                            .foregroundStyle(transaction.type == .out ? .red : .blue)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

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

    private func menuCard(title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

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

    private func reloadInventory() {
        ingredients = InventoryStorage.loadIngredients()
        preps = InventoryStorage.loadPreps()
        reservations = InventoryStorage.loadReservations()
        transactions = InventoryStorage.loadTransactions()
        runReorderCheck()
    }

    private func runReorderCheck() {
        let targets = ReorderEngine.reorderSuggestions(items: activeIngredients, useLessOrEqual: useLessOrEqual)
        alerts = targets.map { item in
            "\(item.name) が発注点を下回りました（在庫 \(formatQty(item.currentStock, unit: item.unit))）"
        }
    }

    private func itemName(for inventoryItemId: String) -> String {
        ingredients.first(where: { $0.id == inventoryItemId })?.name ?? "未登録品目"
    }

    private func itemUnit(for inventoryItemId: String) -> String {
        ingredients.first(where: { $0.id == inventoryItemId })?.unit ?? "個"
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
                    metricRow(label: "理論在庫", value: formatQty(item.onHand, unit: item.unit))
                    metricRow(label: "引当", value: formatQty(item.reservedQuantity, unit: item.unit))
                    metricRow(label: "利用可能", value: formatQty(item.availableQuantity, unit: item.unit))
                    metricRow(label: "発注点", value: formatQty(item.reorderPoint, unit: item.unit))
                }
            } else {
                Section {
                    Text("品目が見つかりません")
                        .foregroundStyle(.secondary)
                }
            }

            Section("引当内訳") {
                if itemReservations.isEmpty {
                    Text("引当はありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(itemReservations) { reservation in
                        HStack {
                            Text("席 \(reservation.seatId)")
                            Spacer()
                            Text(formatQty(reservation.quantity, unit: item?.unit ?? "個"))
                                .fontWeight(.semibold)
                        }
                    }
                }
            }

            Section("直近トランザクション") {
                if itemTransactions.isEmpty {
                    Text("履歴はありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(itemTransactions) { transaction in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(transaction.reason.rawValue)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(transaction.type == .out ? "-" : "+")\(formatQty(transaction.quantity, unit: item?.unit ?? "個"))")
                                    .foregroundStyle(transaction.type == .out ? .red : .blue)
                            }
                            Text(transaction.at.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let seatId = transaction.seatId {
                                Text("席 \(seatId)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
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

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    NavigationStack {
        InventoryMenuView()
    }
}
