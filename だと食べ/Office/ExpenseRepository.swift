import Foundation

protocol ExpenseRepository {
    func fetchExpenses(
        storeId: String,
        from: Date,
        to: Date,
        category: ExpenseCategory?,
        paymentMethod: ExpensePaymentMethod?,
        reimbursed: Bool?,
        status: ExpenseStatus?,
        employeeId: Int?
    ) -> [Expense]

    func save(expense: Expense)
    func delete(id: String)
    func findById(_ id: String) -> Expense?
}

final class MockExpenseRepository: ExpenseRepository {
    private static let storageKey = "expenses.v1"
    private static var sharedItems: [Expense] = AppJSONStore.load(
        [Expense].self,
        key: storageKey,
        fallback: Expense.sample()
    )

    private let changeLogRepository: ChangeLogRepository

    init(seed: [Expense]? = nil, changeLogRepository: ChangeLogRepository = UserDefaultsChangeLogRepository()) {
        self.changeLogRepository = changeLogRepository
        if let seed {
            Self.sharedItems = seed
            persist()
        }
    }

    func fetchExpenses(
        storeId: String,
        from: Date,
        to: Date,
        category: ExpenseCategory?,
        paymentMethod: ExpensePaymentMethod?,
        reimbursed: Bool?,
        status: ExpenseStatus?,
        employeeId: Int?
    ) -> [Expense] {
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay = cal.startOfDay(for: to)

        return Self.sharedItems
            .filter { $0.storeId == storeId }
            .filter { expense in
                let d = cal.startOfDay(for: expense.date)
                return d >= fromDay && d <= toDay
            }
            .filter { expense in
                if let category = category {
                    return expense.category == category
                }
                return true
            }
            .filter { expense in
                if let method = paymentMethod {
                    return expense.paymentMethod == method
                }
                return true
            }
            .filter { expense in
                if let reimbursed = reimbursed {
                    return expense.isReimbursed == reimbursed
                }
                return true
            }
            .filter { expense in
                if let status = status {
                    return expense.status == status
                }
                return true
            }
            .filter { expense in
                if let employeeId = employeeId {
                    return expense.employeeId == employeeId
                }
                return true
            }
            .sorted { $0.date > $1.date }
    }

    func save(expense: Expense) {
        let action: String
        if let index = Self.sharedItems.firstIndex(where: { $0.id == expense.id }) {
            Self.sharedItems[index] = expense
            action = "update"
        } else {
            Self.sharedItems.append(expense)
            action = "create"
        }
        persist()
        changeLogRepository.record(
            storeId: expense.storeId,
            entityType: "expense",
            entityId: expense.id,
            action: action,
            summary: "\(expense.category.rawValue) \(expense.amount)円"
        )
    }

    func delete(id: String) {
        let deleted = Self.sharedItems.first { $0.id == id }
        Self.sharedItems.removeAll { $0.id == id }
        persist()
        if let deleted {
            changeLogRepository.record(
                storeId: deleted.storeId,
                entityType: "expense",
                entityId: deleted.id,
                action: "delete",
                summary: "\(deleted.category.rawValue) \(deleted.amount)円"
            )
        }
    }

    func findById(_ id: String) -> Expense? {
        Self.sharedItems.first { $0.id == id }
    }

    private func persist() {
        AppJSONStore.save(Self.sharedItems, key: Self.storageKey)
    }
}
