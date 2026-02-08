import Foundation
import SwiftUI

protocol MonthlyReportRepository {
    func fetchMonthlySummary(storeId: String, month: Date) async throws -> MonthlySummary
    func fetchMonthlyDaily(storeId: String, month: Date) async throws -> [MonthlyDaily]
}

enum MonthlyReportRepositoryError: Error {
    case invalidMonth
}

final class MockMonthlyReportRepository: MonthlyReportRepository {
    private let salesRepository: SalesRepository
    private let expenseRepository: ExpenseRepository
    private let cashTransactionRepository: CashTransactionRepository
    private let dailyClosingRepository: DailyClosingRepositoryProtocol
    private let storeName: String

    init(
        salesRepository: SalesRepository = MockSalesRepository(),
        expenseRepository: ExpenseRepository = MockExpenseRepository(),
        cashTransactionRepository: CashTransactionRepository = MockCashTransactionRepository(),
        dailyClosingRepository: DailyClosingRepositoryProtocol = MockDailyClosingRepository(),
        storeName: String = "だと食べ 本店"
    ) {
        self.salesRepository = salesRepository
        self.expenseRepository = expenseRepository
        self.cashTransactionRepository = cashTransactionRepository
        self.dailyClosingRepository = dailyClosingRepository
        self.storeName = storeName
    }

    func fetchMonthlySummary(storeId: String, month: Date) async throws -> MonthlySummary {
        let daily = try await fetchMonthlyDaily(storeId: storeId, month: month)

        let yearMonth = yearMonthString(for: month)

        let summary = MonthlySummary(
            yearMonth: yearMonth,
            storeId: storeId,
            storeName: storeName,
            salesTotalInclTax: daily.map(\.salesTotalInclTax).reduce(0, +),
            salesCashInclTax: daily.map(\.salesCashInclTax).reduce(0, +),
            salesCardInclTax: daily.map(\.salesCardInclTax).reduce(0, +),
            salesQrInclTax: daily.map(\.salesQrInclTax).reduce(0, +),
            salesOtherInclTax: daily.map(\.salesOtherInclTax).reduce(0, +),
            salesSubtotalExclTax: daily.map(\.salesSubtotalExclTax).reduce(0, +),
            salesTaxTotal: daily.map(\.salesTaxTotal).reduce(0, +),
            expensesTotal: daily.map(\.expensesTotal).reduce(0, +),
            expensesFood: 0,
            expensesDrink: 0,
            expensesConsumable: 0,
            expensesUtility: 0,
            expensesMisc: 0,
            cashInTotal: daily.map(\.cashInTotal).reduce(0, +),
            cashOutTotal: daily.map(\.cashOutTotal).reduce(0, +),
            cashOutPurchaseTotal: 0,
            cashOutReimburseTotal: 0,
            cashOutDepositToBankTotal: 0,
            closingDifferenceTotal: daily.compactMap(\.closingDifference).reduce(0, +),
            closingIssueDays: daily.filter { $0.closingIssueFlag == true }.count
        )

        let monthRange = try monthRange(for: month)

        let expenses = expenseRepository.fetchExpenses(
            storeId: storeId,
            from: monthRange.start,
            to: monthRange.end,
            category: nil,
            paymentMethod: nil,
            reimbursed: nil,
            status: .approved,
            employeeId: nil
        )

        var mutable = summary
        mutable.expensesFood = expenses
            .filter { $0.category == .food }
            .map { $0.amount }
            .reduce(0, +)
        mutable.expensesDrink = expenses
            .filter { $0.category == .drink }
            .map { $0.amount }
            .reduce(0, +)
        mutable.expensesConsumable = expenses
            .filter { $0.category == .consumable }
            .map { $0.amount }
            .reduce(0, +)
        mutable.expensesUtility = expenses
            .filter { $0.category == .utility }
            .map { $0.amount }
            .reduce(0, +)
        mutable.expensesMisc = expenses
            .filter { $0.category == .misc }
            .map { $0.amount }
            .reduce(0, +)

        let cash = cashTransactionRepository.fetchTransactions(
            storeId: storeId,
            from: monthRange.start,
            to: monthRange.end,
            type: nil,
            category: nil,
            minAmount: nil,
            maxAmount: nil
        )

        mutable.cashOutPurchaseTotal = cash
            .filter { $0.type == .out && $0.category == .purchase }
            .map { $0.amount }
            .reduce(0, +)
        mutable.cashOutReimburseTotal = cash
            .filter { $0.type == .out && $0.category == .expenseReimburse }
            .map { $0.amount }
            .reduce(0, +)
        mutable.cashOutDepositToBankTotal = cash
            .filter { $0.type == .out && $0.category == .depositToBank }
            .map { $0.amount }
            .reduce(0, +)

        return mutable
    }

    func fetchMonthlyDaily(storeId: String, month: Date) async throws -> [MonthlyDaily] {
        let monthRange = try monthRange(for: month)
        let dates = daysInMonth(from: monthRange.start, to: monthRange.end)

        let receipts = salesRepository.fetchReceipts(
            storeId: storeId,
            from: monthRange.start,
            to: monthRange.end,
            statuses: [.posted, .refunded]
        )

        let splits = salesRepository.fetchPaymentSplits(
            storeId: storeId,
            from: monthRange.start,
            to: monthRange.end
        )

        let expenses = expenseRepository.fetchExpenses(
            storeId: storeId,
            from: monthRange.start,
            to: monthRange.end,
            category: nil,
            paymentMethod: nil,
            reimbursed: nil,
            status: .approved,
            employeeId: nil
        )

        let cash = cashTransactionRepository.fetchTransactions(
            storeId: storeId,
            from: monthRange.start,
            to: monthRange.end,
            type: nil,
            category: nil,
            minAmount: nil,
            maxAmount: nil
        )

        let receiptByDay = groupByDay(receipts) { $0.businessDate }
        let splitByDay = groupByDay(splits) { $0.businessDate }
        let expenseByDay = groupByDay(expenses) { $0.date }
        let cashByDay = groupByDay(cash) { $0.date }

        var result: [MonthlyDaily] = []
        let cal = Calendar.current

        for day in dates {
            let key = dayKey(day)
            let r = receiptByDay[key] ?? []
            let s = splitByDay[key] ?? []
            let e = expenseByDay[key] ?? []
            let c = cashByDay[key] ?? []

            let salesTotalInclTax = r.map(\.totalInclTax).reduce(0, +)
            let salesSubtotalExclTax = r.map(\.subtotalExclTax).reduce(0, +)
            let salesTaxTotal = r.map(\.taxTotal).reduce(0, +)

            let salesCashInclTax = s.filter { $0.method == .cash }.map(\.amountInclTax).reduce(0, +)
            let salesCardInclTax = s.filter { $0.method == .card }.map(\.amountInclTax).reduce(0, +)
            let salesQrInclTax = s.filter { $0.method == .qr }.map(\.amountInclTax).reduce(0, +)
            let salesOtherInclTax = s.filter { $0.method == .other }.map(\.amountInclTax).reduce(0, +)

            let expensesTotal = e.map(\.amount).reduce(0, +)
            let cashInTotal = c.filter { $0.type == .in }.map(\.amount).reduce(0, +)
            let cashOutTotal = c.filter { $0.type == .out }.map(\.amount).reduce(0, +)

            var expected: Int? = nil
            var actual: Int? = nil
            var difference: Int? = nil
            var issueFlag: Bool? = nil

            if let closing = dailyClosingRepository.loadClosing(storeId: storeId, date: day),
               closing.status == .confirmed || closing.status == .approved {
                expected = closing.expectedCashBalance
                actual = closing.actualCashBalance
                difference = closing.difference
                issueFlag = closing.hasIssue
            }

            let daily = MonthlyDaily(
                date: cal.startOfDay(for: day),
                storeId: storeId,
                storeName: storeName,
                salesTotalInclTax: salesTotalInclTax,
                salesSubtotalExclTax: salesSubtotalExclTax,
                salesTaxTotal: salesTaxTotal,
                salesCashInclTax: salesCashInclTax,
                salesCardInclTax: salesCardInclTax,
                salesQrInclTax: salesQrInclTax,
                salesOtherInclTax: salesOtherInclTax,
                expensesTotal: expensesTotal,
                cashInTotal: cashInTotal,
                cashOutTotal: cashOutTotal,
                expectedCashBalance: expected,
                actualCashBalance: actual,
                closingDifference: difference,
                closingIssueFlag: issueFlag
            )
            result.append(daily)
        }

        return result
    }

    // MARK: - Helpers

    private func yearMonthString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: date)
    }

    private func monthRange(for date: Date) throws -> (start: Date, end: Date) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let start = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) else {
            throw MonthlyReportRepositoryError.invalidMonth
        }
        guard let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            throw MonthlyReportRepositoryError.invalidMonth
        }
        return (cal.startOfDay(for: start), cal.startOfDay(for: end))
    }

    private func daysInMonth(from start: Date, to end: Date) -> [Date] {
        var dates: [Date] = []
        var current = start
        let cal = Calendar.current

        while current <= end {
            dates.append(current)
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: date)
    }

    private func groupByDay<T>(_ items: [T], date: (T) -> Date) -> [String: [T]] {
        var dict: [String: [T]] = [:]
        for item in items {
            let key = dayKey(date(item))
            dict[key, default: []].append(item)
        }
        return dict
    }
}

// MARK: - SwiftUI Environment

private struct MonthlyReportRepositoryKey: EnvironmentKey {
    static let defaultValue: MonthlyReportRepository = MockMonthlyReportRepository()
}

extension EnvironmentValues {
    var monthlyReportRepository: MonthlyReportRepository {
        get { self[MonthlyReportRepositoryKey.self] }
        set { self[MonthlyReportRepositoryKey.self] = newValue }
    }
}
