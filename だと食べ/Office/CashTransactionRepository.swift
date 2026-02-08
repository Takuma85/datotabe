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
    private var items: [CashTransaction]

    init(seed: [CashTransaction] = CashTransaction.sample()) {
        self.items = seed
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

        return items
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
        if let index = items.firstIndex(where: { $0.id == transaction.id }) {
            items[index] = transaction
        } else {
            items.append(transaction)
        }
    }

    func delete(id: String) {
        items.removeAll { $0.id == id }
    }

    func findById(_ id: String) -> CashTransaction? {
        items.first { $0.id == id }
    }
}
