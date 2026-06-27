import Foundation

protocol CashTransactionRepository {
    func fetchTransactions(
        storeId: String,
        from: Date,
        to: Date,
        type: CashTransactionType?,
        category: CashTransactionCategory?,
        minAmount: Int?,
        maxAmount: Int?
    ) -> [CashTransaction]

    func save(transaction: CashTransaction)
    func delete(id: String)
    func findById(_ id: String) -> CashTransaction?
}

final class MockCashTransactionRepository: CashTransactionRepository {
    private static let storageKey = "cashTransactions.v1"
    private static var sharedItems: [CashTransaction] = AppJSONStore.load(
        [CashTransaction].self,
        key: storageKey,
        fallback: CashTransaction.sample()
    )

    private let changeLogRepository: ChangeLogRepository

    init(seed: [CashTransaction]? = nil, changeLogRepository: ChangeLogRepository = UserDefaultsChangeLogRepository()) {
        self.changeLogRepository = changeLogRepository
        if let seed {
            Self.sharedItems = seed
            persist()
        }
    }

    func fetchTransactions(
        storeId: String,
        from: Date,
        to: Date,
        type: CashTransactionType?,
        category: CashTransactionCategory?,
        minAmount: Int?,
        maxAmount: Int?
    ) -> [CashTransaction] {
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay = cal.startOfDay(for: to)

        return Self.sharedItems
            .filter { $0.storeId == storeId }
            .filter { tx in
                let d = cal.startOfDay(for: tx.date)
                return d >= fromDay && d <= toDay
            }
            .filter { tx in
                if let type = type {
                    return tx.type == type
                }
                return true
            }
            .filter { tx in
                if let category = category {
                    return tx.category == category
                }
                return true
            }
            .filter { tx in
                if let minAmount = minAmount {
                    return tx.amount >= minAmount
                }
                return true
            }
            .filter { tx in
                if let maxAmount = maxAmount {
                    return tx.amount <= maxAmount
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return (lhs.time ?? lhs.date) > (rhs.time ?? rhs.date)
                }
                return lhs.date > rhs.date
            }
    }

    func save(transaction: CashTransaction) {
        let action: String
        if let index = Self.sharedItems.firstIndex(where: { $0.id == transaction.id }) {
            Self.sharedItems[index] = transaction
            action = "update"
        } else {
            Self.sharedItems.append(transaction)
            action = "create"
        }
        persist()
        changeLogRepository.record(
            storeId: transaction.storeId,
            entityType: "cash_transaction",
            entityId: transaction.id,
            action: action,
            summary: "\(transaction.type.rawValue) \(transaction.amount)円"
        )
    }

    func delete(id: String) {
        let deleted = Self.sharedItems.first { $0.id == id }
        Self.sharedItems.removeAll { $0.id == id }
        persist()
        if let deleted {
            changeLogRepository.record(
                storeId: deleted.storeId,
                entityType: "cash_transaction",
                entityId: deleted.id,
                action: "delete",
                summary: "\(deleted.type.rawValue) \(deleted.amount)円"
            )
        }
    }

    func findById(_ id: String) -> CashTransaction? {
        Self.sharedItems.first { $0.id == id }
    }

    private func persist() {
        AppJSONStore.save(Self.sharedItems, key: Self.storageKey)
    }
}
