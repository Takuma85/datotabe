import SwiftUI

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
    }
}

#Preview {
    NavigationStack {
        InventoryMenuView()
    }
}
