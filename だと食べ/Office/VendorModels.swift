import Foundation

enum VendorCategory: String, CaseIterable, Identifiable, Codable {
    case foodSupplier = "food_supplier"
    case drinkSupplier = "drink_supplier"
    case consumable
    case service
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .foodSupplier: return "食材"
        case .drinkSupplier: return "飲料"
        case .consumable: return "消耗品"
        case .service: return "サービス"
        case .other: return "その他"
        }
    }
}

struct Vendor: Identifiable, Hashable, Codable {
    let id: String
    let storeId: String

    var name: String
    var category: VendorCategory

    var phone: String?
    var email: String?
    var memo: String?

    var isActive: Bool

    var createdAt: Date
    var updatedAt: Date
}

extension Vendor {
    static func sample(storeId: String = "store_1") -> [Vendor] {
        let now = Date()
        return [
            Vendor(
                id: "vendor_1",
                storeId: storeId,
                name: "八百屋A",
                category: .foodSupplier,
                phone: nil,
                email: nil,
                memo: nil,
                isActive: true,
                createdAt: now,
                updatedAt: now
            ),
            Vendor(
                id: "vendor_2",
                storeId: storeId,
                name: "酒屋B",
                category: .drinkSupplier,
                phone: nil,
                email: nil,
                memo: nil,
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
        ]
    }
}
