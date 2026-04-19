import Foundation

struct InventoryItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var unit: String
    var onHand: Int
    var reservedQuantity: Int
    var reorderPoint: Int
    var isActive: Bool

    var availableQuantity: Int {
        onHand - reservedQuantity
    }
}

struct InventoryItemLink: Identifiable, Codable, Hashable {
    let id: String
    var menuItemId: String
    var inventoryItemId: String
    var quantityPerSale: Int
    var isActive: Bool
}

struct InventoryReservation: Identifiable, Codable, Hashable {
    let id: String
    var seatId: String
    var inventoryItemId: String
    var quantity: Int
    var updatedAt: Date
}

enum InventoryTransactionType: String, Codable, Hashable {
    case `in`
    case out
    case adjust
}

enum InventoryTransactionReason: String, Codable, Hashable {
    case purchase
    case sale
    case waste
    case stocktakeAdjust = "stocktake_adjust"
    case other
}

struct InventoryTransaction: Identifiable, Codable, Hashable {
    let id: String
    var inventoryItemId: String
    var type: InventoryTransactionType
    var reason: InventoryTransactionReason
    var quantity: Int
    var at: Date
    var seatId: String?
    var note: String?
}

enum InventoryStorage {
    private static let itemsKey = "inventory.items.v1"
    private static let linksKey = "order.inventory.links.v1"
    private static let reservationsKey = "order.inventory.reservations.v1"
    private static let transactionsKey = "inventory.transactions.v1"

    static func loadIngredients() -> [InventoryItem] {
        load(key: itemsKey, fallback: defaultInventoryItems())
    }

    static func saveIngredients(_ items: [InventoryItem]) {
        save(items, key: itemsKey)
    }

    static func loadLinks() -> [InventoryItemLink] {
        load(key: linksKey, fallback: [])
    }

    static func saveLinks(_ links: [InventoryItemLink]) {
        save(links, key: linksKey)
    }

    static func loadReservations() -> [InventoryReservation] {
        load(key: reservationsKey, fallback: [])
    }

    static func saveReservations(_ reservations: [InventoryReservation]) {
        save(reservations, key: reservationsKey)
    }

    static func loadTransactions() -> [InventoryTransaction] {
        load(key: transactionsKey, fallback: [])
    }

    static func saveTransactions(_ transactions: [InventoryTransaction]) {
        save(transactions, key: transactionsKey)
    }

    static func reserveForSeat(seatId: String, requiredByInventoryId: [String: Int]) {
        guard !requiredByInventoryId.isEmpty else { return }

        var items = loadIngredients()
        var reservations = loadReservations()
        let now = Date()

        for (inventoryItemId, requiredQty) in requiredByInventoryId where requiredQty > 0 {
            if let itemIndex = items.firstIndex(where: { $0.id == inventoryItemId }) {
                items[itemIndex].reservedQuantity += requiredQty
            } else {
                items.append(
                    InventoryItem(
                        id: inventoryItemId,
                        name: "未登録品目",
                        unit: "個",
                        onHand: 0,
                        reservedQuantity: requiredQty,
                        reorderPoint: 0,
                        isActive: true
                    )
                )
            }

            if let reservationIndex = reservations.firstIndex(where: {
                $0.seatId == seatId && $0.inventoryItemId == inventoryItemId
            }) {
                reservations[reservationIndex].quantity += requiredQty
                reservations[reservationIndex].updatedAt = now
            } else {
                reservations.append(
                    InventoryReservation(
                        id: UUID().uuidString,
                        seatId: seatId,
                        inventoryItemId: inventoryItemId,
                        quantity: requiredQty,
                        updatedAt: now
                    )
                )
            }
        }

        saveIngredients(items)
        saveReservations(reservations)
    }

    static func consumeReservations(forSeatId seatId: String) {
        var reservations = loadReservations()
        let seatReservations = reservations.filter { $0.seatId == seatId }
        guard !seatReservations.isEmpty else { return }

        var items = loadIngredients()
        var transactions = loadTransactions()
        let now = Date()

        for reservation in seatReservations where reservation.quantity > 0 {
            if let itemIndex = items.firstIndex(where: { $0.id == reservation.inventoryItemId }) {
                items[itemIndex].reservedQuantity = max(items[itemIndex].reservedQuantity - reservation.quantity, 0)
                items[itemIndex].onHand -= reservation.quantity
            } else {
                items.append(
                    InventoryItem(
                        id: reservation.inventoryItemId,
                        name: "未登録品目",
                        unit: "個",
                        onHand: -reservation.quantity,
                        reservedQuantity: 0,
                        reorderPoint: 0,
                        isActive: true
                    )
                )
            }

            transactions.append(
                InventoryTransaction(
                    id: UUID().uuidString,
                    inventoryItemId: reservation.inventoryItemId,
                    type: .out,
                    reason: .sale,
                    quantity: reservation.quantity,
                    at: now,
                    seatId: seatId,
                    note: "会計確定"
                )
            )
        }

        reservations.removeAll { $0.seatId == seatId }

        saveIngredients(items)
        saveReservations(reservations)
        saveTransactions(transactions)
    }

    private static func defaultInventoryItems() -> [InventoryItem] {
        let menu = loadOrderMenu()
        var seenNames = Set<String>()
        var items: [InventoryItem] = []

        for menuItem in menu {
            guard seenNames.insert(menuItem.name).inserted else { continue }
            items.append(
                InventoryItem(
                    id: menuItem.id,
                    name: menuItem.name,
                    unit: "個",
                    onHand: 20,
                    reservedQuantity: 0,
                    reorderPoint: 5,
                    isActive: true
                )
            )
        }

        return items
    }

    private static func load<T: Decodable>(key: String, fallback: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key) else { return fallback }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? fallback
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
