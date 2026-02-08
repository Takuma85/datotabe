import Foundation

enum CashTransactionType: String, CaseIterable, Identifiable, Codable {
    case `in`
    case out

    var id: String { rawValue }

    var label: String {
        switch self {
        case .in: return "入金"
        case .out: return "出金"
        }
    }

    var sign: Int {
        switch self {
        case .in: return 1
        case .out: return -1
        }
    }
}

enum CashTransactionCategory: String, CaseIterable, Identifiable, Codable {
    case changePrep
    case changeReturn
    case purchase
    case expenseReimburse
    case depositToBank
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .changePrep: return "釣銭準備金"
        case .changeReturn: return "釣銭回収"
        case .purchase: return "現金での買い出し"
        case .expenseReimburse: return "立替精算"
        case .depositToBank: return "銀行入金"
        case .other: return "その他"
        }
    }
}

struct CashTransaction: Identifiable, Hashable, Codable {
    let id: String
    let storeId: String

    var date: Date
    var time: Date?

    var type: CashTransactionType
    var amount: Int

    var category: CashTransactionCategory?
    var expenseId: String?
    var vendorName: String?

    var description: String

    var createdByUserId: String
    var updatedByUserId: String
    var createdAt: Date
    var updatedAt: Date
}

extension CashTransaction {
    static func sample(storeId: String = "store_1") -> [CashTransaction] {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        let items: [CashTransaction] = [
            CashTransaction(
                id: UUID().uuidString,
                storeId: storeId,
                date: today,
                time: cal.date(bySettingHour: 9, minute: 30, second: 0, of: now),
                type: .in,
                amount: 30000,
                category: .changePrep,
                expenseId: nil,
                vendorName: nil,
                description: "釣銭準備金投入",
                createdByUserId: "manager_1",
                updatedByUserId: "manager_1",
                createdAt: now,
                updatedAt: now
            ),
            CashTransaction(
                id: UUID().uuidString,
                storeId: storeId,
                date: today,
                time: cal.date(bySettingHour: 14, minute: 0, second: 0, of: now),
                type: .out,
                amount: 1200,
                category: .purchase,
                expenseId: nil,
                vendorName: "コンビニ",
                description: "氷を購入",
                createdByUserId: "staff_1",
                updatedByUserId: "staff_1",
                createdAt: now,
                updatedAt: now
            ),
            CashTransaction(
                id: UUID().uuidString,
                storeId: storeId,
                date: today,
                time: nil,
                type: .out,
                amount: 5000,
                category: .depositToBank,
                expenseId: nil,
                vendorName: "○○銀行",
                description: "売上入金",
                createdByUserId: "manager_1",
                updatedByUserId: "manager_1",
                createdAt: now,
                updatedAt: now
            )
        ]
        return items
    }
}
