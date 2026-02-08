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

    init(
        storeId: String = "store_1",
        repository: CashTransactionRepository = MockCashTransactionRepository()
    ) {
        self.storeId = storeId
        self.repository = repository

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
        repository.save(transaction: transaction)
        loadList()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let id = transactions[index].id
            repository.delete(id: id)
        }
        loadList()
    }

    func delete(transaction: CashTransaction) {
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
            vendorName: nil,
            description: "",
            createdByUserId: "current_user",
            updatedByUserId: "current_user",
            createdAt: now,
            updatedAt: now
        )
    }
}
