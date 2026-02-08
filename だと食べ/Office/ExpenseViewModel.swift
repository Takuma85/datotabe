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

    init(
        storeId: String = "store_1",
        repository: ExpenseRepository = MockExpenseRepository()
    ) {
        self.storeId = storeId
        self.repository = repository

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
        repository.save(expense: expense)
        loadList()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let id = expenses[index].id
            repository.delete(id: id)
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
            vendorName: nil,
            paymentMethod: .cash,
            employeeId: nil,
            isReimbursed: false,
            reimbursedAt: nil,
            reimbursementCashTransactionId: nil,
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
}

@MainActor
final class ExpenseReimbursementViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var showReimbursed: Bool = false

    private let storeId: String
    private let repository: ExpenseRepository

    init(
        storeId: String = "store_1",
        repository: ExpenseRepository = MockExpenseRepository()
    ) {
        self.storeId = storeId
        self.repository = repository
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
        updated.reimbursementCashTransactionId = "mock_cash_tx_\(UUID().uuidString)"
        updated.updatedAt = Date()
        repository.save(expense: updated)
        loadList()
    }
}
