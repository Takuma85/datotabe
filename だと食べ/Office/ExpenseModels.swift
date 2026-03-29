import Foundation

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case food
    case drink
    case consumable
    case utility
    case misc
    case transportation
    case equipment

    var id: String { rawValue }

    var label: String {
        switch self {
        case .food: return "食材"
        case .drink: return "飲料"
        case .consumable: return "消耗品"
        case .utility: return "水道光熱"
        case .misc: return "雑費"
        case .transportation: return "交通費"
        case .equipment: return "備品"
        }
    }
}

enum ExpensePaymentMethod: String, CaseIterable, Identifiable, Codable {
    case cash
    case card
    case bankTransfer
    case employeeAdvance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cash: return "現金"
        case .card: return "カード"
        case .bankTransfer: return "振込"
        case .employeeAdvance: return "従業員立替"
        }
    }
}

enum ExpenseStatus: String, CaseIterable, Identifiable, Codable {
    case draft
    case submitted
    case approved
    case rejected

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft: return "下書き"
        case .submitted: return "申請中"
        case .approved: return "承認済み"
        case .rejected: return "却下"
        }
    }
}

struct Expense: Identifiable, Hashable, Codable {
    let id: String
    let storeId: String

    var date: Date

    var amount: Int
    var taxAmount: Int
    var currency: String

    var category: ExpenseCategory
    var subCategory: String?

    var vendorId: String?
    var vendorNameRaw: String?

    var paymentMethod: ExpensePaymentMethod
    var employeeId: Int?

    var isReimbursed: Bool
    var reimbursedAt: Date?
    var reimbursementCashTransactionId: String?

    var receiptImagePath: String?
    var memo: String

    var status: ExpenseStatus

    var createdByUserId: String
    var updatedByUserId: String
    var approvedByUserId: String?
    var approvedAt: Date?

    var createdAt: Date
    var updatedAt: Date
}

extension Expense {
    static func sample(storeId: String = "store_1") -> [Expense] {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        return [
            Expense(
                id: UUID().uuidString,
                storeId: storeId,
                date: today,
                amount: 5000,
                taxAmount: 0,
                currency: "JPY",
                category: .food,
                subCategory: "野菜",
                vendorId: "vendor_1",
                vendorNameRaw: nil,
                paymentMethod: .cash,
                employeeId: nil,
                isReimbursed: false,
                reimbursedAt: nil,
                reimbursementCashTransactionId: nil,
                receiptImagePath: nil,
                memo: "営業用",
                status: .approved,
                createdByUserId: "manager_1",
                updatedByUserId: "manager_1",
                approvedByUserId: "manager_1",
                approvedAt: now,
                createdAt: now,
                updatedAt: now
            ),
            Expense(
                id: UUID().uuidString,
                storeId: storeId,
                date: today,
                amount: 1800,
                taxAmount: 0,
                currency: "JPY",
                category: .consumable,
                subCategory: nil,
                vendorId: nil,
                vendorNameRaw: "コンビニ",
                paymentMethod: .employeeAdvance,
                employeeId: 1,
                isReimbursed: false,
                reimbursedAt: nil,
                reimbursementCashTransactionId: nil,
                receiptImagePath: nil,
                memo: "氷購入",
                status: .submitted,
                createdByUserId: "staff_1",
                updatedByUserId: "staff_1",
                approvedByUserId: nil,
                approvedAt: nil,
                createdAt: now,
                updatedAt: now
            )
        ]
    }
}
