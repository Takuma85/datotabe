import Foundation
import SwiftUI

protocol MonthlyReportRepository {
    func fetchMonthlySummary(storeId: String, month: Date) async throws -> MonthlySummary
    func fetchMonthlyDaily(storeId: String, month: Date) async throws -> [MonthlyDaily]

    func fetchAccountMappings(storeId: String) -> [AccountMapping]
    func saveAccountMappings(storeId: String, mappings: [AccountMapping])

    func generateJournals(
        storeId: String,
        from: Date,
        to: Date,
        createdByUserId: String
    ) throws -> JournalGenerationResult

    func fetchJournals(
        storeId: String,
        from: Date,
        to: Date,
        status: JournalStatus?
    ) throws -> [JournalEntry]

    func exportJournalsCSV(
        storeId: String,
        from: Date,
        to: Date
    ) throws -> String
}

enum MonthlyReportRepositoryError: Error {
    case invalidMonth
    case invalidDateRange
    case accountMappingNotFound(type: AccountMappingType, key: String)
    case accountCodeMissing(type: AccountMappingType, key: String, side: String)
}

extension MonthlyReportRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidMonth:
            return "月の指定が不正です。"
        case .invalidDateRange:
            return "日付範囲が不正です。"
        case let .accountMappingNotFound(type, key):
            return "勘定科目マッピングが不足しています: \(type.rawValue) / \(key)"
        case let .accountCodeMissing(type, key, side):
            return "勘定科目コードが不足しています: \(type.rawValue) / \(key) (\(side))"
        }
    }
}

final class MockMonthlyReportRepository: MonthlyReportRepository {
    private static var sharedMappingsByStore: [String: [AccountMapping]] = [:]
    private static var sharedJournalsByStore: [String: [JournalEntry]] = [:]

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
        bootstrapMappingsIfNeeded(for: "store_1")
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
            .map(\.amount)
            .reduce(0, +)
        mutable.expensesDrink = expenses
            .filter { $0.category == .drink }
            .map(\.amount)
            .reduce(0, +)
        mutable.expensesConsumable = expenses
            .filter { $0.category == .consumable }
            .map(\.amount)
            .reduce(0, +)
        mutable.expensesUtility = expenses
            .filter { $0.category == .utility }
            .map(\.amount)
            .reduce(0, +)
        mutable.expensesMisc = expenses
            .filter { $0.category == .misc }
            .map(\.amount)
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
            .map(\.amount)
            .reduce(0, +)
        mutable.cashOutReimburseTotal = cash
            .filter { $0.type == .out && $0.category == .expenseReimburse }
            .map(\.amount)
            .reduce(0, +)
        mutable.cashOutDepositToBankTotal = cash
            .filter { $0.type == .out && $0.category == .depositToBank }
            .map(\.amount)
            .reduce(0, +)

        return mutable
    }

    func fetchMonthlyDaily(storeId: String, month: Date) async throws -> [MonthlyDaily] {
        let monthRange = try monthRange(for: month)
        let dates = daysInRange(from: monthRange.start, to: monthRange.end)

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

    func fetchAccountMappings(storeId: String) -> [AccountMapping] {
        bootstrapMappingsIfNeeded(for: storeId)
        return (Self.sharedMappingsByStore[storeId] ?? []).sorted {
            if $0.mappingType.rawValue == $1.mappingType.rawValue {
                return $0.mappingKey < $1.mappingKey
            }
            return $0.mappingType.rawValue < $1.mappingType.rawValue
        }
    }

    func saveAccountMappings(storeId: String, mappings: [AccountMapping]) {
        bootstrapMappingsIfNeeded(for: storeId)

        let now = Date()
        var deduped: [String: AccountMapping] = [:]
        for mapping in mappings {
            var copy = mapping
            copy.updatedAt = now
            deduped["\(copy.mappingType.rawValue)::\(copy.mappingKey)"] = copy
        }

        Self.sharedMappingsByStore[storeId] = deduped.values.sorted {
            if $0.mappingType.rawValue == $1.mappingType.rawValue {
                return $0.mappingKey < $1.mappingKey
            }
            return $0.mappingType.rawValue < $1.mappingType.rawValue
        }
    }

    func generateJournals(
        storeId: String,
        from: Date,
        to: Date,
        createdByUserId: String
    ) throws -> JournalGenerationResult {
        let fromDay = startOfDay(from)
        let toDay = startOfDay(to)
        guard fromDay <= toDay else {
            throw MonthlyReportRepositoryError.invalidDateRange
        }

        bootstrapMappingsIfNeeded(for: storeId)

        var all = Self.sharedJournalsByStore[storeId] ?? []
        var generated = 0
        var replaced = 0
        var warnings: [String] = []

        for day in daysInRange(from: fromDay, to: toDay) {
            let build = try buildDailyJournalLines(storeId: storeId, businessDate: day)
            warnings.append(contentsOf: build.warnings)

            guard !build.lines.isEmpty else { continue }

            let now = Date()
            if let index = all.firstIndex(where: {
                $0.storeId == storeId && startOfDay($0.businessDate) == day && $0.sourceType == .dailySummary
            }) {
                var entry = all[index]
                entry.lines = build.lines.enumerated().map { index, line in
                    var mutable = line
                    mutable.lineNo = index + 1
                    return mutable
                }
                entry.status = .draft
                entry.updatedAt = now
                all[index] = entry
                replaced += 1
            } else {
                let entry = JournalEntry(
                    id: UUID().uuidString,
                    storeId: storeId,
                    businessDate: day,
                    sourceType: .dailySummary,
                    status: .draft,
                    createdByUserId: createdByUserId,
                    createdAt: now,
                    updatedAt: now,
                    lines: build.lines.enumerated().map { index, line in
                        var mutable = line
                        mutable.lineNo = index + 1
                        return mutable
                    }
                )
                all.append(entry)
                generated += 1
            }
        }

        all.sort {
            if $0.businessDate == $1.businessDate {
                return $0.createdAt > $1.createdAt
            }
            return $0.businessDate > $1.businessDate
        }
        Self.sharedJournalsByStore[storeId] = all

        let preview = try fetchJournals(storeId: storeId, from: fromDay, to: toDay, status: nil)
        return JournalGenerationResult(
            generatedEntries: generated,
            replacedEntries: replaced,
            warningMessages: warnings,
            previewEntries: preview
        )
    }

    func fetchJournals(
        storeId: String,
        from: Date,
        to: Date,
        status: JournalStatus?
    ) throws -> [JournalEntry] {
        let fromDay = startOfDay(from)
        let toDay = startOfDay(to)
        guard fromDay <= toDay else {
            throw MonthlyReportRepositoryError.invalidDateRange
        }

        return (Self.sharedJournalsByStore[storeId] ?? [])
            .filter {
                let d = startOfDay($0.businessDate)
                return d >= fromDay && d <= toDay
            }
            .filter {
                if let status = status {
                    return $0.status == status
                }
                return true
            }
            .sorted {
                if $0.businessDate == $1.businessDate {
                    return $0.createdAt > $1.createdAt
                }
                return $0.businessDate > $1.businessDate
            }
    }

    func exportJournalsCSV(
        storeId: String,
        from: Date,
        to: Date
    ) throws -> String {
        let entries = try fetchJournals(storeId: storeId, from: from, to: to, status: nil)
            .sorted { $0.businessDate < $1.businessDate }

        let header = [
            "business_date",
            "store_id",
            "entry_id",
            "line_no",
            "debit_account_code",
            "credit_account_code",
            "amount",
            "tax_code",
            "memo"
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "ja_JP")

        var lines: [String] = [header.map(csvEscape).joined(separator: ",")]
        for entry in entries {
            for line in entry.lines.sorted(by: { $0.lineNo < $1.lineNo }) {
                let row = [
                    dateFormatter.string(from: entry.businessDate),
                    entry.storeId,
                    entry.id,
                    "\(line.lineNo)",
                    line.debitAccountCode,
                    line.creditAccountCode,
                    "\(line.amount)",
                    line.taxCode ?? "",
                    line.memo
                ]
                lines.append(row.map(csvEscape).joined(separator: ","))
            }
        }

        if !entries.isEmpty {
            var all = Self.sharedJournalsByStore[storeId] ?? []
            let targetIds = Set(entries.map(\.id))
            let now = Date()
            for index in all.indices where targetIds.contains(all[index].id) {
                all[index].status = .exported
                all[index].updatedAt = now
            }
            Self.sharedJournalsByStore[storeId] = all
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Journal Builders

    private func buildDailyJournalLines(
        storeId: String,
        businessDate: Date
    ) throws -> (lines: [JournalLine], warnings: [String]) {
        let receipts = salesRepository.fetchReceipts(
            storeId: storeId,
            from: businessDate,
            to: businessDate,
            statuses: [.posted, .refunded]
        )
        let receiptIdSet = Set(receipts.map(\.id))

        let splits = salesRepository.fetchPaymentSplits(
            storeId: storeId,
            from: businessDate,
            to: businessDate
        ).filter { receiptIdSet.contains($0.receiptId) }

        let approvedExpenses = expenseRepository.fetchExpenses(
            storeId: storeId,
            from: businessDate,
            to: businessDate,
            category: nil,
            paymentMethod: nil,
            reimbursed: nil,
            status: .approved,
            employeeId: nil
        )

        let journalizableCashCategories: Set<CashTransactionCategory> = [
            .depositToBank, .changePrep, .changeReturn, .expenseReimburse
        ]
        let cashTransactions = cashTransactionRepository.fetchTransactions(
            storeId: storeId,
            from: businessDate,
            to: businessDate,
            type: nil,
            category: nil,
            minAmount: nil,
            maxAmount: nil
        ).filter { tx in
            guard let category = tx.category else { return false }
            return journalizableCashCategories.contains(category)
        }

        var warnings: [String] = []
        var lines: [JournalLine] = []

        let salesTotal = receipts.map(\.totalInclTax).reduce(0, +)
        let paymentTotal = splits.map(\.amountInclTax).reduce(0, +)
        if salesTotal != paymentTotal {
            warnings.append(
                "\(dayKey(businessDate)): 売上合計(\(salesTotal))と支払合計(\(paymentTotal))に差分があります。"
            )
        }

        let revenueMapping = try requiredMapping(
            storeId: storeId,
            type: .salesRevenue,
            key: "revenue"
        )
        let revenueCredit = try requiredAccountCode(
            mapping: revenueMapping,
            side: "credit",
            value: revenueMapping.creditAccountCode
        )

        for method in PaymentMethod.allCases {
            let amount = splits
                .filter { $0.method == method }
                .map(\.amountInclTax)
                .reduce(0, +)
            guard amount != 0 else { continue }

            let paymentMapping = try requiredMapping(
                storeId: storeId,
                type: .salesPayment,
                key: method.mappingKey
            )
            let paymentDebit = try requiredAccountCode(
                mapping: paymentMapping,
                side: "debit",
                value: paymentMapping.debitAccountCode
            )

            appendTransferLine(
                lines: &lines,
                amount: amount,
                debitAccountCode: paymentDebit,
                creditAccountCode: revenueCredit,
                taxCode: revenueMapping.taxCode ?? paymentMapping.taxCode,
                memo: "売上 \(method.mappingKey)",
                sourceRefType: "sales",
                sourceRefKey: method.mappingKey
            )
        }

        let expenseGroups = Dictionary(grouping: approvedExpenses) {
            "\($0.category.mappingKey)::\($0.paymentMethod.mappingKey)"
        }
        for (groupKey, items) in expenseGroups {
            let amount = items.map(\.amount).reduce(0, +)
            guard amount != 0 else { continue }

            guard let first = items.first else { continue }

            let categoryMapping = try requiredMapping(
                storeId: storeId,
                type: .expenseCategory,
                key: first.category.mappingKey
            )
            let paymentMapping = try requiredMapping(
                storeId: storeId,
                type: .expensePayment,
                key: first.paymentMethod.mappingKey
            )
            let debit = try requiredAccountCode(
                mapping: categoryMapping,
                side: "debit",
                value: categoryMapping.debitAccountCode
            )
            let credit = try requiredAccountCode(
                mapping: paymentMapping,
                side: "credit",
                value: paymentMapping.creditAccountCode
            )

            appendTransferLine(
                lines: &lines,
                amount: amount,
                debitAccountCode: debit,
                creditAccountCode: credit,
                taxCode: categoryMapping.taxCode ?? paymentMapping.taxCode,
                memo: "経費 \(groupKey)",
                sourceRefType: "expense",
                sourceRefKey: groupKey
            )
        }

        let cashGroups = Dictionary(grouping: cashTransactions) { $0.category }
        for (categoryOpt, items) in cashGroups {
            guard let category = categoryOpt else { continue }
            let signedAmount = items.reduce(0) { partial, tx in
                partial + tx.type.sign * tx.amount
            }
            guard signedAmount != 0 else { continue }

            let mapping = try requiredMapping(
                storeId: storeId,
                type: .cashTxCategory,
                key: category.mappingKey
            )
            let debit = try requiredAccountCode(
                mapping: mapping,
                side: "debit",
                value: mapping.debitAccountCode
            )
            let credit = try requiredAccountCode(
                mapping: mapping,
                side: "credit",
                value: mapping.creditAccountCode
            )

            appendTransferLine(
                lines: &lines,
                amount: signedAmount,
                debitAccountCode: debit,
                creditAccountCode: credit,
                taxCode: mapping.taxCode,
                memo: "資金移動 \(category.mappingKey)",
                sourceRefType: "cash_tx",
                sourceRefKey: category.mappingKey
            )
        }

        return (lines, warnings)
    }

    private func appendTransferLine(
        lines: inout [JournalLine],
        amount: Int,
        debitAccountCode: String,
        creditAccountCode: String,
        taxCode: String?,
        memo: String,
        sourceRefType: String?,
        sourceRefKey: String?
    ) {
        guard amount != 0 else { return }

        let normalizedAmount = abs(amount)
        let debit = amount > 0 ? debitAccountCode : creditAccountCode
        let credit = amount > 0 ? creditAccountCode : debitAccountCode

        lines.append(
            JournalLine(
                id: UUID().uuidString,
                lineNo: lines.count + 1,
                debitAccountCode: debit,
                creditAccountCode: credit,
                amount: normalizedAmount,
                taxCode: taxCode,
                memo: memo,
                sourceRefType: sourceRefType,
                sourceRefKey: sourceRefKey
            )
        )
    }

    // MARK: - Mapping Helpers

    private func requiredMapping(
        storeId: String,
        type: AccountMappingType,
        key: String
    ) throws -> AccountMapping {
        bootstrapMappingsIfNeeded(for: storeId)
        guard let mapping = (Self.sharedMappingsByStore[storeId] ?? []).first(where: {
            $0.mappingType == type && $0.mappingKey == key && $0.isActive
        }) else {
            throw MonthlyReportRepositoryError.accountMappingNotFound(type: type, key: key)
        }
        return mapping
    }

    private func requiredAccountCode(
        mapping: AccountMapping,
        side: String,
        value: String?
    ) throws -> String {
        guard let code = value?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            throw MonthlyReportRepositoryError.accountCodeMissing(
                type: mapping.mappingType,
                key: mapping.mappingKey,
                side: side
            )
        }
        return code
    }

    private func bootstrapMappingsIfNeeded(for storeId: String) {
        guard Self.sharedMappingsByStore[storeId] == nil else { return }

        let now = Date()
        var mappings: [AccountMapping] = []

        func add(
            type: AccountMappingType,
            key: String,
            debit: String? = nil,
            credit: String? = nil,
            tax: String? = nil,
            isActive: Bool = true
        ) {
            mappings.append(
                AccountMapping(
                    id: UUID().uuidString,
                    storeId: storeId,
                    mappingType: type,
                    mappingKey: key,
                    debitAccountCode: debit,
                    creditAccountCode: credit,
                    taxCode: tax,
                    isActive: isActive,
                    updatedAt: now
                )
            )
        }

        add(type: .salesPayment, key: "cash", debit: "1110")
        add(type: .salesPayment, key: "card", debit: "1130")
        add(type: .salesPayment, key: "qr", debit: "1140")
        add(type: .salesPayment, key: "other", debit: "1190")
        add(type: .salesRevenue, key: "revenue", credit: "4110")

        add(type: .expenseCategory, key: "food", debit: "5210")
        add(type: .expenseCategory, key: "drink", debit: "5220")
        add(type: .expenseCategory, key: "consumable", debit: "5310")
        add(type: .expenseCategory, key: "utility", debit: "5410")
        add(type: .expenseCategory, key: "misc", debit: "5990")
        add(type: .expenseCategory, key: "transportation", debit: "5710")
        add(type: .expenseCategory, key: "equipment", debit: "5320")

        add(type: .expensePayment, key: "cash", credit: "1110")
        add(type: .expensePayment, key: "card", credit: "2110")
        add(type: .expensePayment, key: "bank_transfer", credit: "2110")
        add(type: .expensePayment, key: "employee_advance", credit: "2160")

        add(type: .cashTxCategory, key: "deposit_to_bank", debit: "1120", credit: "1110")
        add(type: .cashTxCategory, key: "change_prep", debit: "1110", credit: "1180")
        add(type: .cashTxCategory, key: "change_return", debit: "1180", credit: "1110")
        add(type: .cashTxCategory, key: "expense_reimburse", debit: "2160", credit: "1110")
        add(type: .cashTxCategory, key: "purchase", debit: "5310", credit: "1110", isActive: false)

        Self.sharedMappingsByStore[storeId] = mappings
    }

    // MARK: - Date / CSV Helpers

    private func yearMonthString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
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

    private func daysInRange(from start: Date, to end: Date) -> [Date] {
        var dates: [Date] = []
        var current = startOfDay(start)
        let endDay = startOfDay(end)
        let cal = Calendar.current

        while current <= endDay {
            dates.append(current)
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func groupByDay<T>(_ items: [T], date: (T) -> Date) -> [String: [T]] {
        var dict: [String: [T]] = [:]
        for item in items {
            let key = dayKey(date(item))
            dict[key, default: []].append(item)
        }
        return dict
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

private extension PaymentMethod {
    var mappingKey: String { rawValue }
}

private extension ExpenseCategory {
    var mappingKey: String { rawValue }
}

private extension ExpensePaymentMethod {
    var mappingKey: String {
        switch self {
        case .cash: return "cash"
        case .card: return "card"
        case .bankTransfer: return "bank_transfer"
        case .employeeAdvance: return "employee_advance"
        }
    }
}

private extension CashTransactionCategory {
    var mappingKey: String {
        switch self {
        case .changePrep: return "change_prep"
        case .changeReturn: return "change_return"
        case .purchase: return "purchase"
        case .expenseReimburse: return "expense_reimburse"
        case .depositToBank: return "deposit_to_bank"
        case .other: return "other"
        }
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
