import Foundation
import SwiftUI

private let orderCategoriesStorageKey = "seatorder.categories"
private let orderMenuStorageKey = "seatorder.menu"
private let orderStockStorageKey = "orderpage.stock"

private func orderHistoryStorageKey(seatId: String) -> String {
    "seatorder.history.\(seatId)"
}

struct SeatOrderCategory: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var locked: Bool = false
}

struct SeatMenuItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var price: Int
    var categoryId: String
    var options: [String]? = nil
    var soldOut: Bool = false
}

struct SeatCartEntry: Identifiable, Hashable {
    let id: String
    let itemId: String
    var itemName: String
    var unitPrice: Int
    var quantity: Int
    var option: String?

    var lineTotal: Int {
        unitPrice * quantity
    }
}

struct SeatOrderLine: Identifiable, Codable, Hashable {
    let id: String
    var itemId: String
    var name: String
    var quantity: Int
    var price: Int
    var option: String?

    var lineTotal: Int {
        price * quantity
    }
}

struct SeatOrderRecord: Identifiable, Codable, Hashable {
    let id: String
    var seatId: String
    var at: Date
    var lines: [SeatOrderLine]
    var total: Int
}

typealias SeatStock = [String: Int]

private func orderUUID() -> String {
    UUID().uuidString
}

private func defaultOrderCategories() -> [SeatOrderCategory] {
    [
        .init(id: "all", name: "全て", locked: true),
        .init(id: "fried", name: "揚げ物", locked: true),
        .init(id: "sashimi", name: "刺身", locked: true),
        .init(id: "snack", name: "つまみ", locked: true),
        .init(id: "ippin", name: "一品物", locked: true),
        .init(id: "soft", name: "ソフトドリンク", locked: true),
        .init(id: "alcohol", name: "アルコール", locked: true)
    ]
}

private func defaultOrderMenu() -> [SeatMenuItem] {
    func build(
        categoryId: String,
        names: [String],
        basePrice: Int,
        options: [String]? = nil,
        soldOutIndexes: Set<Int> = []
    ) -> [SeatMenuItem] {
        names.enumerated().map { index, name in
            SeatMenuItem(
                id: orderUUID(),
                name: name,
                price: basePrice + index * 20,
                categoryId: categoryId,
                options: options,
                soldOut: soldOutIndexes.contains(index)
            )
        }
    }

    let shochuOptions = ["水", "お湯", "ロック", "炭酸"]
    let whiskyOptions = ["ロック", "水", "お湯", "ハイボール", "ストレート"]

    return build(categoryId: "fried", names: ["唐揚げ", "ポテトフライ", "なんこつ唐揚げ", "チーズフライ", "春巻き"], basePrice: 380)
        + build(categoryId: "sashimi", names: ["まぐろ", "サーモン", "はまち", "たい", "三点盛り"], basePrice: 480)
        + build(categoryId: "snack", names: ["枝豆", "冷奴", "きゅうり一本漬け", "たこわさ", "キムチ"], basePrice: 280)
        + build(categoryId: "ippin", names: ["出汁巻き卵", "焼き鳥盛り", "牛すじ煮込み", "海老マヨ", "鉄板餃子"], basePrice: 420)
        + build(categoryId: "soft", names: ["ウーロン茶", "緑茶", "コーラ", "ジンジャーエール", "オレンジジュース"], basePrice: 250)
        + build(categoryId: "alcohol", names: ["生ビール(中)", "ハイボール", "レモンサワー", "ウーロンハイ"], basePrice: 420)
        + build(categoryId: "alcohol", names: ["焼酎(芋)", "焼酎(麦)", "梅酒"], basePrice: 420, options: shochuOptions, soldOutIndexes: [2])
        + build(categoryId: "alcohol", names: ["ウイスキー"], basePrice: 500, options: whiskyOptions)
}

private func loadOrderCategories() -> [SeatOrderCategory] {
    AppJSONStore.load([SeatOrderCategory].self, key: orderCategoriesStorageKey, fallback: defaultOrderCategories())
}

func loadOrderMenu() -> [SeatMenuItem] {
    AppJSONStore.load([SeatMenuItem].self, key: orderMenuStorageKey, fallback: defaultOrderMenu())
}

private func loadSeatOrderHistory(seatId: String) -> [SeatOrderRecord] {
    AppJSONStore.load([SeatOrderRecord].self, key: orderHistoryStorageKey(seatId: seatId), fallback: [])
}

private func saveSeatOrderHistory(_ history: [SeatOrderRecord], seatId: String) {
    AppJSONStore.save(history, key: orderHistoryStorageKey(seatId: seatId))
}

private func loadSeatStock() -> SeatStock {
    AppJSONStore.load(SeatStock.self, key: orderStockStorageKey, fallback: [:])
}

private func saveSeatStock(_ stock: SeatStock) {
    AppJSONStore.save(stock, key: orderStockStorageKey)
}

private func inferredOptions(for item: SeatMenuItem) -> [String]? {
    if item.options?.isEmpty == false {
        return item.options
    }

    if item.name.contains("焼酎") || item.name.contains("梅酒") {
        return ["水", "お湯", "ロック", "炭酸"]
    }

    if item.name.contains("ウイスキー") {
        return ["ロック", "水", "お湯", "ハイボール", "ストレート"]
    }

    return nil
}

func clearSeatOrderHistory(seatId: String) {
    InventoryStorage.consumeReservations(forSeatId: seatId)
    UserDefaults.standard.removeObject(forKey: orderHistoryStorageKey(seatId: seatId))
}

func billingItemsForSeat(_ seat: Seat) -> [OrderItem] {
    let seatId = String(seat.id)
    let history = loadSeatOrderHistory(seatId: seatId)

    guard !history.isEmpty else {
        return sampleOrderItems(for: seat)
    }

    var grouped: [String: OrderItem] = [:]

    for record in history {
        for line in record.lines {
            let name: String
            if let option = line.option, !option.isEmpty {
                name = "\(line.name) (\(option))"
            } else {
                name = line.name
            }

            let key = "\(line.itemId)#\(line.option ?? "")#\(line.price)"
            if var existing = grouped[key] {
                existing.quantity += line.quantity
                grouped[key] = existing
            } else {
                grouped[key] = OrderItem(
                    id: key,
                    name: name,
                    unitPrice: line.price,
                    quantity: line.quantity
                )
            }
        }
    }

    let items = grouped.values.sorted { $0.name < $1.name }
    return items.isEmpty ? sampleOrderItems(for: seat) : items
}

@MainActor
final class SeatOrderViewModel: ObservableObject {
    let seatId: String

    @Published var categories: [SeatOrderCategory] = []
    @Published var menu: [SeatMenuItem] = []
    @Published var stock: SeatStock = [:]
    @Published var inventoryItems: [InventoryItem] = []
    @Published var inventoryLinks: [InventoryItemLink] = []
    @Published var reservations: [InventoryReservation] = []
    @Published var history: [SeatOrderRecord] = []
    @Published var cart: [SeatCartEntry] = []
    @Published var activeCategoryId: String = "all"
    @Published var toast: String = ""

    init(seatId: String) {
        self.seatId = seatId
        reload()
    }

    func reload() {
        categories = loadOrderCategories()
        menu = loadOrderMenu()
        stock = loadSeatStock()
        inventoryItems = InventoryStorage.loadIngredients()
        inventoryLinks = InventoryStorage.loadLinks()
        reservations = InventoryStorage.loadReservations()
        history = loadSeatOrderHistory(seatId: seatId).sorted { $0.at > $1.at }
    }

    func filteredMenu(searchText: String) -> [SeatMenuItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return menu.filter { item in
            let matchesCategory = activeCategoryId == "all" || item.categoryId == activeCategoryId
            let matchesSearch = trimmed.isEmpty || item.name.localizedCaseInsensitiveContains(trimmed)
            return matchesCategory && matchesSearch
        }
    }

    func quantityInCart(for itemId: String) -> Int {
        cart.filter { $0.itemId == itemId }.reduce(0) { $0 + $1.quantity }
    }

    func availableStock(for item: SeatMenuItem) -> Int? {
        guard let capacity = menuCapacity(for: item.id) else { return nil }
        return max(capacity - quantityInCart(for: item.id), 0)
    }

    func isSoldOut(_ item: SeatMenuItem) -> Bool {
        if item.soldOut {
            return true
        }

        if let remaining = availableStock(for: item) {
            return remaining <= 0
        }

        return false
    }

    func addToCart(item: SeatMenuItem, quantity: Int, option: String?) {
        guard quantity > 0 else { return }
        guard !isSoldOut(item) else {
            showToast("この商品は品切れです")
            return
        }

        let normalizedOption = option?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentQuantity = cart
            .filter { $0.itemId == item.id && $0.option == normalizedOption }
            .reduce(0) { $0 + $1.quantity }

        guard canSetCartQuantity(itemId: item.id, newQuantity: currentQuantity + quantity, excludingEntryId: nil) else {
            showToast("在庫数を超えています")
            return
        }

        if let index = cart.firstIndex(where: { $0.itemId == item.id && $0.option == normalizedOption }) {
            cart[index].quantity += quantity
        } else {
            cart.append(
                SeatCartEntry(
                    id: orderUUID(),
                    itemId: item.id,
                    itemName: item.name,
                    unitPrice: item.price,
                    quantity: quantity,
                    option: normalizedOption?.isEmpty == true ? nil : normalizedOption
                )
            )
        }

        showToast("カートに追加しました")
    }

    func updateCartQuantity(entryId: String, quantity: Int) {
        guard let index = cart.firstIndex(where: { $0.id == entryId }) else { return }

        if quantity <= 0 {
            cart.remove(at: index)
            return
        }

        let itemId = cart[index].itemId
        guard canSetCartQuantity(itemId: itemId, newQuantity: quantity, excludingEntryId: entryId) else {
            showToast("在庫数を超えています")
            return
        }

        cart[index].quantity = quantity
    }

    func removeCartEntry(_ entry: SeatCartEntry) {
        cart.removeAll { $0.id == entry.id }
    }

    func submitOrder() {
        guard !cart.isEmpty else { return }

        let submittedEntries = cart
        let lines = submittedEntries.map { entry in
            SeatOrderLine(
                id: orderUUID(),
                itemId: entry.itemId,
                name: entry.itemName,
                quantity: entry.quantity,
                price: entry.unitPrice,
                option: entry.option
            )
        }

        let record = SeatOrderRecord(
            id: orderUUID(),
            seatId: seatId,
            at: Date(),
            lines: lines,
            total: submittedEntries.reduce(0) { $0 + $1.lineTotal }
        )

        var nextHistory = history
        nextHistory.insert(record, at: 0)
        history = nextHistory
        saveSeatOrderHistory(nextHistory, seatId: seatId)

        var nextStock = stock
        for entry in submittedEntries {
            if let current = nextStock[entry.itemId] {
                nextStock[entry.itemId] = max(current - entry.quantity, 0)
            }
        }
        stock = nextStock
        saveSeatStock(nextStock)

        let required = requiredInventoryForEntries(submittedEntries)
        InventoryStorage.reserveForSeat(seatId: seatId, requiredByInventoryId: required)
        inventoryItems = InventoryStorage.loadIngredients()
        reservations = InventoryStorage.loadReservations()

        cart.removeAll()
        showToast("注文を登録しました")
    }

    var cartSubtotal: Int {
        cart.reduce(0) { $0 + $1.lineTotal }
    }

    private func menuCapacity(for itemId: String) -> Int? {
        var candidates: [Int] = []

        if let current = stock[itemId] {
            candidates.append(max(current, 0))
        }

        if let inventoryCapacity = linkedInventoryCapacity(for: itemId) {
            candidates.append(inventoryCapacity)
        }

        return candidates.min()
    }

    private func linkedInventoryCapacity(for itemId: String) -> Int? {
        let links = inventoryLinks.filter { $0.menuItemId == itemId && $0.isActive && $0.quantityPerSale > 0 }
        guard !links.isEmpty else { return nil }

        let itemsById = Dictionary(uniqueKeysWithValues: inventoryItems.map { ($0.id, $0) })
        var capacity = Int.max

        for link in links {
            guard let item = itemsById[link.inventoryItemId] else { return 0 }
            capacity = min(capacity, item.availableQuantity / link.quantityPerSale)
        }

        return max(capacity, 0)
    }

    private func canSetCartQuantity(itemId: String, newQuantity: Int, excludingEntryId: String?) -> Bool {
        guard let capacity = menuCapacity(for: itemId) else { return true }
        let otherQuantity = cart
            .filter { $0.itemId == itemId && $0.id != excludingEntryId }
            .reduce(0) { $0 + $1.quantity }
        return otherQuantity + newQuantity <= capacity
    }

    private func requiredInventoryForEntries(_ entries: [SeatCartEntry]) -> [String: Int] {
        let activeLinks = inventoryLinks.filter { $0.isActive && $0.quantityPerSale > 0 }
        let linksByMenu = Dictionary(grouping: activeLinks, by: \.menuItemId)
        var required: [String: Int] = [:]

        for entry in entries {
            guard let links = linksByMenu[entry.itemId] else { continue }
            for link in links {
                required[link.inventoryItemId, default: 0] += entry.quantity * link.quantityPerSale
            }
        }

        return required
    }

    private func showToast(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self else { return }
            if self.toast == message {
                self.toast = ""
            }
        }
    }
}

struct SeatOrderView: View {
    @Environment(\.dismiss) private var dismiss

    let seat: Seat

    @StateObject private var viewModel: SeatOrderViewModel
    @State private var searchText: String = ""
    @State private var editingItem: SeatMenuItem?

    init(seat: Seat) {
        self.seat = seat
        _viewModel = StateObject(wrappedValue: SeatOrderViewModel(seatId: String(seat.id)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryTabs
                searchBar
                menuList
            }
            .safeAreaInset(edge: .bottom) {
                bottomArea
            }
            .navigationTitle("注文")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("再読込") {
                        viewModel.reload()
                    }
                }
            }
            .sheet(item: $editingItem) { item in
                SeatOrderItemEditorView(
                    item: item,
                    maxQuantity: viewModel.availableStock(for: item),
                    onAdd: { quantity, option in
                        viewModel.addToCart(item: item, quantity: quantity, option: option)
                    }
                )
            }
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    Button(category.name) {
                        viewModel.activeCategoryId = category.id
                    }
                    .buttonStyle(OrderFilterChipStyle(isSelected: viewModel.activeCategoryId == category.id))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("席 \(seat.id) / \(seat.occupants)名")
                .font(.footnote)
                .foregroundColor(.secondary)

            TextField("メニュー検索", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
    }

    private var menuList: some View {
        List {
            Section("メニュー") {
                ForEach(viewModel.filteredMenu(searchText: searchText)) { item in
                    let soldOut = viewModel.isSoldOut(item)

                    Button {
                        editingItem = item
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("¥\(item.price)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let remaining = viewModel.availableStock(for: item) {
                                    Text("残り \(remaining)")
                                        .font(.caption)
                                        .foregroundColor(remaining == 0 ? .red : .secondary)
                                }

                                if soldOut {
                                    Text("品切れ")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else if let options = inferredOptions(for: item), !options.isEmpty {
                                    Text(options.joined(separator: " / "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(soldOut ? "追加不可" : "追加")
                                    .font(.caption)
                                    .foregroundColor(soldOut ? .red : .blue)

                                let inCart = viewModel.quantityInCart(for: item.id)
                                if inCart > 0 {
                                    Text("カート \(inCart)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(soldOut)
                }
            }

            Section("カート") {
                if viewModel.cart.isEmpty {
                    Text("カートは空です")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.cart) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.itemName)
                                        .font(.headline)
                                    if let option = entry.option, !option.isEmpty {
                                        Text(option)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(formatYen(entry.lineTotal))
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Button {
                                    viewModel.updateCartQuantity(entryId: entry.id, quantity: entry.quantity - 1)
                                } label: {
                                    Text("-")
                                        .frame(width: 28)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Text("\(entry.quantity)")
                                    .frame(minWidth: 28)

                                Button {
                                    viewModel.updateCartQuantity(entryId: entry.id, quantity: entry.quantity + 1)
                                } label: {
                                    Text("+")
                                        .frame(width: 28)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Spacer()

                                Button("削除") {
                                    viewModel.removeCartEntry(entry)
                                }
                                .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("注文履歴") {
                if viewModel.history.isEmpty {
                    Text("まだ注文履歴はありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.history) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(record.at.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(formatYen(record.total))
                                    .fontWeight(.semibold)
                            }

                            ForEach(record.lines) { line in
                                HStack {
                                    Text(line.name)
                                    if let option = line.option, !option.isEmpty {
                                        Text("(\(option))")
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("x\(line.quantity)")
                                        .foregroundColor(.secondary)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var bottomArea: some View {
        VStack(spacing: 8) {
            if !viewModel.toast.isEmpty {
                Text(viewModel.toast)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("カート合計")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatYen(viewModel.cartSubtotal))
                        .font(.headline)
                }

                Spacer()

                Button("注文を確定") {
                    viewModel.submitOrder()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.cart.isEmpty)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

private struct SeatOrderItemEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let item: SeatMenuItem
    let maxQuantity: Int?
    let onAdd: (Int, String?) -> Void

    @State private var quantity: Int = 1
    @State private var option: String = ""

    private var options: [String] {
        inferredOptions(for: item) ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("商品") {
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text("¥\(item.price)")
                            .foregroundColor(.secondary)
                    }
                }

                if !options.isEmpty {
                    Section("オプション") {
                        Picker("内容", selection: $option) {
                            ForEach(options, id: \.self) { candidate in
                                Text(candidate).tag(candidate)
                            }
                        }
                    }
                }

                Section("数量") {
                    Stepper("数量 \(quantity)", value: $quantity, in: 1...max(allowedMaxQuantity, 1))
                    if let maxQuantity {
                        Text("追加可能数: \(maxQuantity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("数量選択")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        onAdd(quantity, options.isEmpty ? nil : option)
                        dismiss()
                    }
                    .disabled(allowedMaxQuantity <= 0)
                }
            }
            .onAppear {
                if let first = options.first {
                    option = first
                }
            }
        }
    }

    private var allowedMaxQuantity: Int {
        maxQuantity ?? 20
    }
}

private struct OrderFilterChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.black : Color.white)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(isSelected ? 0 : 0.15), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
