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
    private var items: [Expense]

    init(seed: [Expense] = Expense.sample()) {
        self.items = seed
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

        return items
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
        if let index = items.firstIndex(where: { $0.id == expense.id }) {
            items[index] = expense
        } else {
            items.append(expense)
        }
    }

    func delete(id: String) {
        items.removeAll { $0.id == id }
    }

    func findById(_ id: String) -> Expense? {
        items.first { $0.id == id }
    }
}
