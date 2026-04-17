import Foundation

@MainActor
final class CashFlowViewModel: ObservableObject {
    @Published var transactions: [CashTransaction] = []

    @Published var fromDate: Date
    @Published var toDate: Date
    @Published var selectedType: CashTransactionType? = nil
    @Published var selectedCategory: CashTransactionCategory? = nil
    @Published var minAmountText: String = ""
    @Published var maxAmountText: String = ""

    @Published var errorMessage: String?

    private let storeId: String
    private let repository: CashTransactionRepository
    private let expenseRepository: ExpenseRepository

    init(
        storeId: String = "store_1",
        repository: CashTransactionRepository = MockCashTransactionRepository(),
        expenseRepository: ExpenseRepository = MockExpenseRepository()
    ) {
        self.storeId = storeId
        self.repository = repository
        self.expenseRepository = expenseRepository

        let today = Calendar.current.startOfDay(for: Date())
        self.toDate = today
        self.fromDate = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today

        loadList()
    }

    func loadList() {
        let minAmount = Int(minAmountText.trimmingCharacters(in: .whitespacesAndNewlines))
        let maxAmount = Int(maxAmountText.trimmingCharacters(in: .whitespacesAndNewlines))

        transactions = repository.fetchTransactions(
            storeId: storeId,
            from: fromDate,
            to: toDate,
            type: selectedType,
            category: selectedCategory,
            minAmount: minAmount,
            maxAmount: maxAmount
        )
    }

    func save(transaction: CashTransaction) {
        var normalized = transaction
        normalized.updatedAt = Date()
        let previous = repository.findById(normalized.id)
        repository.save(transaction: normalized)
        syncExpenseLink(afterSaving: normalized, previous: previous)
        loadList()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let tx = transactions[index]
            unlinkExpenseIfNeeded(for: tx)
            repository.delete(id: tx.id)
        }
        loadList()
    }

    func delete(transaction: CashTransaction) {
        unlinkExpenseIfNeeded(for: transaction)
        repository.delete(id: transaction.id)
        loadList()
    }

    var cashInTotal: Int {
        transactions
            .filter { $0.type == .in }
            .map { $0.amount }
            .reduce(0, +)
    }

    var cashOutTotal: Int {
        transactions
            .filter { $0.type == .out }
            .map { $0.amount }
            .reduce(0, +)
    }

    var difference: Int {
        cashInTotal - cashOutTotal
    }

    var linkedExpenseCount: Int {
        transactions.filter { $0.expenseId != nil }.count
    }

    func linkedExpense(for transaction: CashTransaction) -> Expense? {
        guard let expenseId = transaction.expenseId else { return nil }
        return expenseRepository.findById(expenseId)
    }

    func cashExpenseCandidates(currentTransactionId: String) -> [Expense] {
        let allExpenses = expenseRepository.fetchExpenses(
            storeId: storeId,
            from: Date.distantPast,
            to: Date.distantFuture,
            category: nil,
            paymentMethod: .cash,
            reimbursed: nil,
            status: nil,
            employeeId: nil
        )

        return allExpenses
            .filter { expense in
                if expense.cashTransactionId == nil {
                    return true
                }
                return expense.cashTransactionId == currentTransactionId
            }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.date > rhs.date
            }
    }

    func newDraft() -> CashTransaction {
        let now = Date()
        return CashTransaction(
            id: UUID().uuidString,
            storeId: storeId,
            date: Calendar.current.startOfDay(for: now),
            time: now,
            type: .out,
            amount: 0,
            category: nil,
            expenseId: nil,
            vendorId: nil,
            description: "",
            createdByUserId: "current_user",
            updatedByUserId: "current_user",
            createdAt: now,
            updatedAt: now
        )
    }

    // MARK: - Helpers

    private func syncExpenseLink(afterSaving transaction: CashTransaction, previous: CashTransaction?) {
        if let oldExpenseId = previous?.expenseId,
           oldExpenseId != transaction.expenseId,
           var oldExpense = expenseRepository.findById(oldExpenseId),
           oldExpense.cashTransactionId == transaction.id {
            oldExpense.cashTransactionId = nil
            oldExpense.updatedAt = Date()
            expenseRepository.save(expense: oldExpense)
        }

        guard let expenseId = transaction.expenseId,
              var expense = expenseRepository.findById(expenseId) else {
            return
        }

        expense.cashTransactionId = transaction.id
        expense.updatedAt = Date()
        expenseRepository.save(expense: expense)
    }

    private func unlinkExpenseIfNeeded(for transaction: CashTransaction) {
        guard let expenseId = transaction.expenseId,
              var expense = expenseRepository.findById(expenseId) else {
            return
        }
        if expense.cashTransactionId == transaction.id {
            expense.cashTransactionId = nil
            expense.updatedAt = Date()
            expenseRepository.save(expense: expense)
        }
    }
}
