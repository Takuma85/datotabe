import Foundation
import SwiftUI

protocol AnalyticsRepository {
    func fetchMonthly(storeId: String, month: Date) async throws -> AnalyticsMonthlyReport
    func fetchDaily(storeId: String, from: Date, to: Date) async throws -> [AnalyticsDailyRow]
}

enum AnalyticsRepositoryError: Error {
    case invalidRange
    case invalidMonth
}

final class MockAnalyticsRepository: AnalyticsRepository {
    private let salesRepository: SalesRepository
    private let expenseRepository: ExpenseRepository
    private let cashTransactionRepository: CashTransactionRepository
    private let dailyClosingRepository: DailyClosingRepositoryProtocol
    private let timeRecordRepository: TimeRecordRepository
    private let costCategorySettingsRepository: CostCategorySettingsRepository

    init(
        salesRepository: SalesRepository = MockSalesRepository(),
        expenseRepository: ExpenseRepository = MockExpenseRepository(),
        cashTransactionRepository: CashTransactionRepository = MockCashTransactionRepository(),
        dailyClosingRepository: DailyClosingRepositoryProtocol = MockDailyClosingRepository(),
        timeRecordRepository: TimeRecordRepository = UserDefaultsTimeRecordRepository(),
        costCategorySettingsRepository: CostCategorySettingsRepository = UserDefaultsCostCategorySettingsRepository()
    ) {
        self.salesRepository = salesRepository
        self.expenseRepository = expenseRepository
        self.cashTransactionRepository = cashTransactionRepository
        self.dailyClosingRepository = dailyClosingRepository
        self.timeRecordRepository = timeRecordRepository
        self.costCategorySettingsRepository = costCategorySettingsRepository
    }

    func fetchMonthly(storeId: String, month: Date) async throws -> AnalyticsMonthlyReport {
        let monthRange = try monthRange(for: month)
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
        let timeRecords = timeRecordRepository.loadAll()
        let settings = costCategorySettingsRepository.loadSettings(storeId: storeId)
        let cogsCategories = Set(settings.filter { $0.isCogs }.map(\.expenseCategory))

        let salesTotalInclTax = receipts.map(\.totalInclTax).reduce(0, +)
        let salesSubtotalExclTax = receipts.map(\.subtotalExclTax).reduce(0, +)
        let salesTaxTotal = receipts.map(\.taxTotal).reduce(0, +)
        let receiptCount = receipts.count
        let guestCount = receipts.map(\.peopleCount).reduce(0, +)

        let payCash = splits.filter { $0.method == .cash }.map(\.amountInclTax).reduce(0, +)
        let payCard = splits.filter { $0.method == .card }.map(\.amountInclTax).reduce(0, +)
        let payQr = splits.filter { $0.method == .qr }.map(\.amountInclTax).reduce(0, +)
        let payOther = splits.filter { $0.method == .other }.map(\.amountInclTax).reduce(0, +)
        let payTotal = payCash + payCard + payQr + payOther

        let cogsTotal = expenses
            .filter { cogsCategories.contains($0.category) }
            .map(\.amount)
            .reduce(0, +)

        let grossProfit = salesTotalInclTax - cogsTotal

        let closingInfo = loadClosingSummary(storeId: storeId, from: monthRange.start, to: monthRange.end)

        let depositToBankTotal = cash
            .filter { $0.type == .out && $0.category == .depositToBank }
            .map(\.amount)
            .reduce(0, +)

        let laborMinutesTotal = timeRecords
            .filter { $0.storeId == storeId }
            .filter { $0.status == .approved }
            .filter { isDate($0.date, between: monthRange.start, and: monthRange.end) }
            .map(calcWorkedMinutes)
            .reduce(0, +)

        let kpi = AnalyticsMonthlyKpi(
            salesTotalInclTax: salesTotalInclTax,
            salesSubtotalExclTax: salesSubtotalExclTax,
            salesTaxTotal: salesTaxTotal,
            receiptCount: receiptCount,
            guestCount: guestCount,
            avgSpendPerGuest: ratio(numerator: Double(salesTotalInclTax), denominator: Double(guestCount)),
            avgSpendPerReceipt: ratio(numerator: Double(salesTotalInclTax), denominator: Double(receiptCount)),
            payCash: payCash,
            payCard: payCard,
            payQr: payQr,
            payOther: payOther,
            payTotal: payTotal,
            cashRatio: ratio(numerator: Double(payCash), denominator: Double(payTotal)),
            cardRatio: ratio(numerator: Double(payCard), denominator: Double(payTotal)),
            qrRatio: ratio(numerator: Double(payQr), denominator: Double(payTotal)),
            otherRatio: ratio(numerator: Double(payOther), denominator: Double(payTotal)),
            cogsTotal: cogsTotal,
            grossProfit: grossProfit,
            cogsRatio: ratio(numerator: Double(cogsTotal), denominator: Double(salesTotalInclTax)),
            grossMarginRatio: ratio(numerator: Double(grossProfit), denominator: Double(salesTotalInclTax)),
            closingDifferenceTotal: closingInfo.totalDifference,
            closingIssueDays: closingInfo.issueDays,
            depositToBankTotal: depositToBankTotal,
            laborMinutesTotal: laborMinutesTotal,
            salesPerLaborHour: ratio(
                numerator: Double(salesTotalInclTax),
                denominator: Double(laborMinutesTotal) / 60.0
            )
        )

        let cogsByCategory = sumByCategory(
            expenses: expenses.filter { cogsCategories.contains($0.category) }
        )
        let expensesByCategory = sumByCategory(expenses: expenses)
        let paymentsByMethod: [PaymentMethod: Int] = [
            .cash: payCash,
            .card: payCard,
            .qr: payQr,
            .other: payOther
        ]

        let expensesByVendor = sumByVendor(expenses: expenses)

        let breakdowns = AnalyticsMonthlyBreakdowns(
            cogsByCategory: cogsByCategory,
            expensesByCategory: expensesByCategory,
            paymentsByMethod: paymentsByMethod,
            expensesByVendor: expensesByVendor
        )

        var warnings: [AnalyticsWarning] = []
        let mismatch = salesTotalInclTax - payTotal
        if mismatch != 0 {
            warnings.append(AnalyticsWarning(
                code: "sales_payment_mismatch",
                message: "売上合計と支払合計に差異があります",
                value: mismatch
            ))
        }

        return AnalyticsMonthlyReport(
            month: yearMonthString(for: month),
            kpi: kpi,
            breakdowns: breakdowns,
            warnings: warnings
        )
    }

    func fetchDaily(storeId: String, from: Date, to: Date) async throws -> [AnalyticsDailyRow] {
        guard from <= to else {
            throw AnalyticsRepositoryError.invalidRange
        }

        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay = cal.startOfDay(for: to)

        let receipts = salesRepository.fetchReceipts(
            storeId: storeId,
            from: fromDay,
            to: toDay,
            statuses: [.posted, .refunded]
        )
        let expenses = expenseRepository.fetchExpenses(
            storeId: storeId,
            from: fromDay,
            to: toDay,
            category: nil,
            paymentMethod: nil,
            reimbursed: nil,
            status: .approved,
            employeeId: nil
        )
        let timeRecords = timeRecordRepository.loadAll()
        let settings = costCategorySettingsRepository.loadSettings(storeId: storeId)
        let cogsCategories = Set(settings.filter { $0.isCogs }.map(\.expenseCategory))

        let receiptByDay = groupByDay(receipts) { $0.businessDate }
        let expenseByDay = groupByDay(expenses) { $0.date }
        let timeByDay = groupByDay(
            timeRecords.filter { $0.storeId == storeId }.filter { $0.status == .approved }
        ) { $0.date }

        var rows: [AnalyticsDailyRow] = []
        for day in daysInRange(from: fromDay, to: toDay) {
            let key = dayKey(day)
            let dayReceipts = receiptByDay[key] ?? []
            let dayExpenses = expenseByDay[key] ?? []
            let dayTime = timeByDay[key] ?? []

            let salesTotalInclTax = dayReceipts.map(\.totalInclTax).reduce(0, +)
            let guestCount = dayReceipts.map(\.peopleCount).reduce(0, +)
            let cogsTotal = dayExpenses
                .filter { cogsCategories.contains($0.category) }
                .map(\.amount)
                .reduce(0, +)
            let laborMinutesTotal = dayTime.map(calcWorkedMinutes).reduce(0, +)

            var closingDifference: Int? = nil
            if let closing = dailyClosingRepository.loadClosing(storeId: storeId, date: day),
               closing.status == .confirmed || closing.status == .approved {
                closingDifference = closing.difference
            }

            let row = AnalyticsDailyRow(
                date: day,
                dateKey: key,
                salesTotalInclTax: salesTotalInclTax,
                cogsTotal: cogsTotal,
                cogsRatio: ratio(numerator: Double(cogsTotal), denominator: Double(salesTotalInclTax)),
                guestCount: guestCount,
                closingDifference: closingDifference,
                laborMinutesTotal: laborMinutesTotal
            )
            rows.append(row)
        }

        return rows
    }

    // MARK: - Helpers

    private func loadClosingSummary(storeId: String, from: Date, to: Date) -> (totalDifference: Int, issueDays: Int) {
        var totalDifference = 0
        var issueDays = 0

        for day in daysInRange(from: from, to: to) {
            if let closing = dailyClosingRepository.loadClosing(storeId: storeId, date: day),
               closing.status == .confirmed || closing.status == .approved {
                totalDifference += closing.difference
                if closing.hasIssue {
                    issueDays += 1
                }
            }
        }
        return (totalDifference, issueDays)
    }

    private func sumByCategory(expenses: [Expense]) -> [ExpenseCategory: Int] {
        var dict: [ExpenseCategory: Int] = [:]
        for e in expenses {
            dict[e.category, default: 0] += e.amount
        }
        return dict
    }

    private func sumByVendor(expenses: [Expense]) -> [String: Int] {
        var dict: [String: Int] = [:]
        for e in expenses {
            let name = (e.vendorName?.isEmpty == false) ? e.vendorName! : "その他（未紐付け）"
            dict[name, default: 0] += e.amount
        }
        return dict
    }

    private func calcWorkedMinutes(_ record: TimeRecord) -> Int {
        guard let clockIn = record.clockInAt else { return 0 }
        let end = record.clockOutAt ?? clockIn
        let total = end.timeIntervalSince(clockIn) - Double(record.breakMinutes * 60)
        return max(0, Int(total / 60))
    }

    private func ratio(numerator: Double, denominator: Double) -> Double? {
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }

    private func monthRange(for date: Date) throws -> (start: Date, end: Date) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let start = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) else {
            throw AnalyticsRepositoryError.invalidMonth
        }
        guard let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            throw AnalyticsRepositoryError.invalidMonth
        }
        return (cal.startOfDay(for: start), cal.startOfDay(for: end))
    }

    private func daysInRange(from start: Date, to end: Date) -> [Date] {
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

    private func yearMonthString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
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

    private func isDate(_ date: Date, between start: Date, and end: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        return d >= cal.startOfDay(for: start) && d <= cal.startOfDay(for: end)
    }
}

private struct AnalyticsRepositoryKey: EnvironmentKey {
    static let defaultValue: AnalyticsRepository = MockAnalyticsRepository()
}

extension EnvironmentValues {
    var analyticsRepository: AnalyticsRepository {
        get { self[AnalyticsRepositoryKey.self] }
        set { self[AnalyticsRepositoryKey.self] = newValue }
    }
}
