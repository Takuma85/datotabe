import Foundation

@MainActor
final class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []

    @Published var fromDate: Date
    @Published var toDate: Date
    @Published var selectedCategory: ExpenseCategory? = nil
    @Published var selectedPaymentMethod: ExpensePaymentMethod? = nil
    @Published var selectedReimbursed: Bool? = nil
    @Published var selectedStatus: ExpenseStatus? = nil
    @Published var selectedEmployeeId: Int? = nil

    private let storeId: String
    private let repository: ExpenseRepository
    private let cashTransactionRepository: CashTransactionRepository

    init(
        storeId: String = "store_1",
        repository: ExpenseRepository = MockExpenseRepository(),
        cashTransactionRepository: CashTransactionRepository = MockCashTransactionRepository()
    ) {
        self.storeId = storeId
        self.repository = repository
        self.cashTransactionRepository = cashTransactionRepository

        let today = Calendar.current.startOfDay(for: Date())
        self.toDate = today
        self.fromDate = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today

        loadList()
    }

    func loadList() {
        expenses = repository.fetchExpenses(
            storeId: storeId,
            from: fromDate,
            to: toDate,
            category: selectedCategory,
            paymentMethod: selectedPaymentMethod,
            reimbursed: selectedReimbursed,
            status: selectedStatus,
            employeeId: selectedEmployeeId
        )
    }

    func save(expense: Expense) {
        var updated = expense
        updated.updatedAt = Date()
        updated = synchronizeCashFlowLink(for: updated)
        repository.save(expense: updated)
        loadList()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let target = expenses[index]
            if let txId = target.cashTransactionId {
                cashTransactionRepository.delete(id: txId)
            }
            repository.delete(id: target.id)
        }
        loadList()
    }

    func newDraft(currentUserId: String) -> Expense {
        let now = Date()
        return Expense(
            id: UUID().uuidString,
            storeId: storeId,
            date: Calendar.current.startOfDay(for: now),
            amount: 0,
            taxAmount: 0,
            currency: "JPY",
            category: .misc,
            subCategory: nil,
            vendorId: nil,
            vendorNameRaw: nil,
            paymentMethod: .cash,
            employeeId: nil,
            isReimbursed: false,
            reimbursedAt: nil,
            reimbursementCashTransactionId: nil,
            cashTransactionId: nil,
            receiptImagePath: nil,
            memo: "",
            status: .submitted,
            createdByUserId: currentUserId,
            updatedByUserId: currentUserId,
            approvedByUserId: nil,
            approvedAt: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    var totalAmount: Int {
        expenses.map { $0.amount }.reduce(0, +)
    }

    var reimbursedTotal: Int {
        expenses.filter { $0.isReimbursed }.map { $0.amount }.reduce(0, +)
    }

    var unreimbursedTotal: Int {
        expenses.filter { $0.paymentMethod == .employeeAdvance && !$0.isReimbursed }
            .map { $0.amount }
            .reduce(0, +)
    }

    var cashExpenseTotal: Int {
        expenses
            .filter { $0.paymentMethod == .cash }
            .map(\.amount)
            .reduce(0, +)
    }

    var linkedCashExpenseCount: Int {
        expenses.filter { $0.paymentMethod == .cash && $0.cashTransactionId != nil }.count
    }

    var unlinkedCashExpenseCount: Int {
        expenses.filter { $0.paymentMethod == .cash && $0.cashTransactionId == nil }.count
    }

    func linkedCashTransaction(for expense: Expense) -> CashTransaction? {
        guard let txId = expense.cashTransactionId else { return nil }
        return cashTransactionRepository.findById(txId)
    }

    // MARK: - Helpers

    private func synchronizeCashFlowLink(for expense: Expense) -> Expense {
        var updated = expense

        guard updated.paymentMethod == .cash else {
            if let txId = updated.cashTransactionId {
                cashTransactionRepository.delete(id: txId)
            }
            updated.cashTransactionId = nil
            return updated
        }

        let transactionId = updated.cashTransactionId ?? UUID().uuidString
        let existing = cashTransactionRepository.findById(transactionId)

        let transaction = CashTransaction(
            id: transactionId,
            storeId: updated.storeId,
            date: Calendar.current.startOfDay(for: updated.date),
            time: existing?.time ?? Date(),
            type: .out,
            amount: updated.amount,
            category: existing?.category ?? .purchase,
            expenseId: updated.id,
            vendorId: updated.vendorId,
            description: cashExpenseDescription(for: updated),
            createdByUserId: existing?.createdByUserId ?? updated.createdByUserId,
            updatedByUserId: updated.updatedByUserId,
            createdAt: existing?.createdAt ?? updated.createdAt,
            updatedAt: Date()
        )
        cashTransactionRepository.save(transaction: transaction)

        updated.cashTransactionId = transactionId
        return updated
    }

    private func cashExpenseDescription(for expense: Expense) -> String {
        let memo = expense.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        if memo.isEmpty {
            return "経費（\(expense.category.label)）"
        }
        return "経費（\(expense.category.label)）: \(memo)"
    }
}

@MainActor
final class ExpenseReimbursementViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var showReimbursed: Bool = false

    private let storeId: String
    private let repository: ExpenseRepository
    private let cashTransactionRepository: CashTransactionRepository

    init(
        storeId: String = "store_1",
        repository: ExpenseRepository = MockExpenseRepository(),
        cashTransactionRepository: CashTransactionRepository = MockCashTransactionRepository()
    ) {
        self.storeId = storeId
        self.repository = repository
        self.cashTransactionRepository = cashTransactionRepository
        loadList()
    }

    func loadList() {
        let base = repository.fetchExpenses(
            storeId: storeId,
            from: Date.distantPast,
            to: Date.distantFuture,
            category: nil,
            paymentMethod: nil,
            reimbursed: showReimbursed ? true : false,
            status: .approved,
            employeeId: nil
        )
        expenses = base.filter { expense in
            expense.paymentMethod == .employeeAdvance || expense.employeeId != nil
        }
    }

    func markReimbursed(expense: Expense) {
        var updated = expense
        updated.isReimbursed = true
        updated.reimbursedAt = Date()
        updated.updatedAt = Date()

        let txId = updated.reimbursementCashTransactionId ?? "reimburse_\(UUID().uuidString)"
        let transaction = CashTransaction(
            id: txId,
            storeId: updated.storeId,
            date: Calendar.current.startOfDay(for: updated.date),
            time: Date(),
            type: .out,
            amount: updated.amount,
            category: .expenseReimburse,
            expenseId: updated.id,
            vendorId: updated.vendorId,
            description: "立替精算",
            createdByUserId: updated.createdByUserId,
            updatedByUserId: updated.updatedByUserId,
            createdAt: updated.createdAt,
            updatedAt: Date()
        )

        cashTransactionRepository.save(transaction: transaction)
        updated.reimbursementCashTransactionId = transaction.id
        repository.save(expense: updated)
        loadList()
    }
}
