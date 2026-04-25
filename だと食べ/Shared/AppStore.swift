import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published private(set) var exportHistories: [AccountingExportHistoryEntry] = []

    private let salesRepository: SalesRepository
    private let expenseRepository: ExpenseRepository
    private let cashTransactionRepository: CashTransactionRepository
    private let dailyClosingRepository: DailyClosingRepositoryProtocol
    private let timeRecordRepository: TimeRecordRepository
    private let costCategorySettingsRepository: CostCategorySettingsRepository

    private let defaults = UserDefaults.standard
    private let exportHistoryKey = "appstore_accounting_export_history_v1"
    private let approvalMetaKey = "appstore_time_record_approval_meta_v1"
    private var approvalMetaByRecordId: [String: TimeRecordApprovalInfo] = [:]

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
        self.exportHistories = Self.loadExportHistories(defaults: defaults, key: exportHistoryKey)
        self.approvalMetaByRecordId = Self.loadApprovalMeta(defaults: defaults, key: approvalMetaKey)
    }

    // MARK: - Accounting Export

    func buildAccountingExportPreview(storeId: String, month: Date) -> AccountingExportPreview {
        let lines = buildJournalLines(storeId: storeId, month: month)
        let validation = validateJournalLines(storeId: storeId, month: month, lines: lines)
        let csv = journalLinesCSV(lines)
        return AccountingExportPreview(
            month: monthString(month),
            lines: lines,
            validation: validation,
            csv: csv
        )
    }

    func recordExportHistory(month: String, lineCount: Int, warningCount: Int) {
        let entry = AccountingExportHistoryEntry(
            id: UUID().uuidString,
            month: month,
            lineCount: lineCount,
            warningCount: warningCount,
            exportedAt: Date()
        )
        exportHistories.insert(entry, at: 0)
        persistExportHistories()
    }

    func journalLinesCSV(_ lines: [JournalLine]) -> String {
        let header = [
            "business_date",
            "store_id",
            "source_type",
            "debit_account",
            "credit_account",
            "amount",
            "memo"
        ]

        var rows: [String] = [header.joined(separator: ",")]
        let dateFormatter = Self.csvDateFormatter

        for line in lines {
            let row = [
                dateFormatter.string(from: line.businessDate),
                line.storeId,
                line.sourceType,
                line.debitAccount,
                line.creditAccount,
                String(line.amount),
                line.memo
            ].map(csvEscape)
            rows.append(row.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    func buildJournalLines(storeId: String, month: Date) -> [JournalLine] {
        guard let monthRange = BusinessDate.monthRange(containing: month) else { return [] }

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

        var receiptsById: [String: SalesReceipt] = [:]
        for receipt in receipts {
            // 重複IDが混在していてもクラッシュさせず、後勝ちで扱う
            receiptsById[receipt.id] = receipt
        }
        var lines: [JournalLine] = []

        for split in splits {
            guard let receipt = receiptsById[split.receiptId] else { continue }
            let debit = salesDebitAccount(for: split.method) ?? "未割当"
            lines.append(
                JournalLine(
                    id: UUID().uuidString,
                    storeId: storeId,
                    businessDate: receipt.businessDate,
                    sourceType: "sales_receipt",
                    debitAccount: debit,
                    creditAccount: "売上高",
                    amount: split.amountInclTax,
                    memo: "売上 \(split.method.rawValue)"
                )
            )
        }

        for expense in expenses {
            let debit = expenseDebitAccount(for: expense.category) ?? "未割当"
            let credit = expenseCreditAccount(for: expense.paymentMethod) ?? "未割当"
            lines.append(
                JournalLine(
                    id: UUID().uuidString,
                    storeId: storeId,
                    businessDate: expense.date,
                    sourceType: "expense",
                    debitAccount: debit,
                    creditAccount: credit,
                    amount: expense.amount,
                    memo: "経費 \(expense.category.rawValue)"
                )
            )
        }

        return lines.sorted { lhs, rhs in
            if lhs.businessDate == rhs.businessDate {
                return lhs.id < rhs.id
            }
            return lhs.businessDate < rhs.businessDate
        }
    }

    func validateJournalLines(storeId: String, month: Date, lines: [JournalLine]) -> AccountingValidationSummary {
        guard let monthRange = BusinessDate.monthRange(containing: month) else {
            return AccountingValidationSummary(
                salesPaymentDifference: 0,
                debitCreditDifference: 0,
                unmappedCount: 0,
                issues: []
            )
        }

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

        let salesTotal = receipts.map(\.totalInclTax).reduce(0, +)
        let paymentTotal = splits.map(\.amountInclTax).reduce(0, +)
        let salesPaymentDiff = CommonAccountingUtilities.salesPaymentMismatch(
            salesTotalInclTax: salesTotal,
            paymentTotal: paymentTotal
        )

        let debitTotal = lines.map(\.amount).reduce(0, +)
        let creditTotal = lines.map(\.amount).reduce(0, +)
        let debitCreditDiff = debitTotal - creditTotal

        let unmappedCount = lines.filter {
            $0.debitAccount == "未割当" || $0.creditAccount == "未割当"
        }.count

        var issues: [AccountingValidationIssue] = []
        if salesPaymentDiff != 0 {
            issues.append(
                AccountingValidationIssue(
                    code: "sales_payment_mismatch",
                    message: "売上合計と決済合計に差異があります",
                    severity: .warning,
                    value: salesPaymentDiff
                )
            )
        }
        if debitCreditDiff != 0 {
            issues.append(
                AccountingValidationIssue(
                    code: "debit_credit_mismatch",
                    message: "借方合計と貸方合計に差異があります",
                    severity: .error,
                    value: debitCreditDiff
                )
            )
        }
        if unmappedCount > 0 {
            issues.append(
                AccountingValidationIssue(
                    code: "unmapped_account",
                    message: "未割当の勘定マッピングがあります",
                    severity: .warning,
                    value: unmappedCount
                )
            )
        }

        return AccountingValidationSummary(
            salesPaymentDifference: salesPaymentDiff,
            debitCreditDifference: debitCreditDiff,
            unmappedCount: unmappedCount,
            issues: issues
        )
    }

    // MARK: - Timecard Admin

    func loadAdminTimeRecords(
        storeId: String,
        date: Date?,
        employeeId: Int?
    ) -> [TimeRecordAdminRow] {
        let cal = Calendar.current
        let rows = timeRecordRepository.loadAll()
            .filter { $0.storeId == storeId }
            .filter { record in
                guard let date else { return true }
                return cal.isDate(record.date, inSameDayAs: date)
            }
            .filter { record in
                guard let employeeId else { return true }
                return record.employeeId == employeeId
            }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.employeeId < rhs.employeeId
                }
                return lhs.date > rhs.date
            }

        return rows.map { record in
            TimeRecordAdminRow(
                record: record,
                approval: approvalMetaByRecordId[record.id.uuidString],
                issues: timeRecordIssues(for: record)
            )
        }
    }

    func approveTimeRecord(_ record: TimeRecord, managerUserId: String) {
        var updated = record
        updated.status = .approved
        timeRecordRepository.save(updated)

        approvalMetaByRecordId[record.id.uuidString] = TimeRecordApprovalInfo(
            approvedByUserId: managerUserId,
            approvedAt: Date(),
            rejectedByUserId: nil,
            rejectedAt: nil,
            rejectionReason: nil
        )
        persistApprovalMeta()
    }

    func rejectTimeRecord(_ record: TimeRecord, managerUserId: String, reason: String?) {
        var updated = record
        updated.status = .rejected
        timeRecordRepository.save(updated)

        approvalMetaByRecordId[record.id.uuidString] = TimeRecordApprovalInfo(
            approvedByUserId: nil,
            approvedAt: nil,
            rejectedByUserId: managerUserId,
            rejectedAt: Date(),
            rejectionReason: reason
        )
        persistApprovalMeta()
    }

    func saveTimeRecord(_ record: TimeRecord) {
        timeRecordRepository.save(record)
    }

    func timeRecordIssues(for record: TimeRecord) -> [TimeRecordIssue] {
        var issues: [TimeRecordIssue] = []

        if record.clockInAt == nil {
            issues.append(TimeRecordIssue(
                code: .missingClockIn,
                message: "出勤打刻がありません",
                severity: .error
            ))
        }

        if record.clockOutAt == nil {
            issues.append(TimeRecordIssue(
                code: .missingClockOut,
                message: "退勤打刻がありません",
                severity: .warning
            ))
        }

        if let inAt = record.clockInAt, let outAt = record.clockOutAt, outAt < inAt {
            issues.append(TimeRecordIssue(
                code: .invalidTimeRange,
                message: "退勤時刻が出勤時刻より前です",
                severity: .error
            ))
        }

        if record.breakMinutes < 0 || record.breakMinutes > 600 {
            issues.append(TimeRecordIssue(
                code: .invalidBreakMinutes,
                message: "休憩時間が不正です",
                severity: .warning
            ))
        }

        let workedMinutes = CommonAccountingUtilities.workedMinutes(
            clockInAt: record.clockInAt,
            clockOutAt: record.clockOutAt,
            breakMinutes: record.breakMinutes
        )
        if workedMinutes > 16 * 60 {
            issues.append(TimeRecordIssue(
                code: .overwork,
                message: "勤務時間が16時間を超えています",
                severity: .warning
            ))
        }

        if record.isOnBreak && record.clockOutAt != nil {
            issues.append(TimeRecordIssue(
                code: .inconsistentBreakState,
                message: "退勤済みなのに休憩中フラグが残っています",
                severity: .warning
            ))
        }

        return issues
    }

    // MARK: - Analytics KPI

    func aggregateAnalyticsKpi(storeId: String, month: Date) -> AppAnalyticsKpiSnapshot {
        guard let monthRange = BusinessDate.monthRange(containing: month) else {
            return AppAnalyticsKpiSnapshot(
                month: monthString(month),
                salesTotalInclTax: 0,
                receiptCount: 0,
                avgSpendPerReceipt: nil,
                cogsTotal: 0,
                grossProfit: 0,
                grossMarginRatio: nil,
                closingDifferenceTotal: 0,
                laborMinutesTotal: 0,
                salesPerLaborHour: nil,
                warnings: []
            )
        }

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

        let cogsSettings = costCategorySettingsRepository.loadSettings(storeId: storeId)
        let cogsCategories = Set(cogsSettings.filter { $0.isCogs }.map(\.expenseCategory))
        let cogsTotal = expenses
            .filter { cogsCategories.contains($0.category) }
            .map(\.amount)
            .reduce(0, +)

        let salesTotalInclTax = receipts.map(\.totalInclTax).reduce(0, +)
        let receiptCount = receipts.count
        let grossProfit = salesTotalInclTax - cogsTotal

        let laborMinutesTotal = timeRecordRepository.loadAll()
            .filter { $0.storeId == storeId }
            .filter { $0.status == .approved }
            .filter { isDate($0.date, between: monthRange.start, and: monthRange.end) }
            .map { CommonAccountingUtilities.workedMinutes(
                clockInAt: $0.clockInAt,
                clockOutAt: $0.clockOutAt,
                breakMinutes: $0.breakMinutes
            ) }
            .reduce(0, +)

        let closingDifferenceTotal = daysInRange(from: monthRange.start, to: monthRange.end)
            .compactMap { dailyClosingRepository.loadClosing(storeId: storeId, date: $0) }
            .filter { $0.status == .confirmed || $0.status == .approved }
            .map(\.difference)
            .reduce(0, +)

        let salesPaymentDiff = salesTotalInclTax - splits.map(\.amountInclTax).reduce(0, +)
        var warnings: [AccountingValidationIssue] = []
        if salesPaymentDiff != 0 {
            warnings.append(
                AccountingValidationIssue(
                    code: "sales_payment_mismatch",
                    message: "売上合計と決済合計に差異があります",
                    severity: .warning,
                    value: salesPaymentDiff
                )
            )
        }

        return AppAnalyticsKpiSnapshot(
            month: monthString(month),
            salesTotalInclTax: salesTotalInclTax,
            receiptCount: receiptCount,
            avgSpendPerReceipt: CommonAccountingUtilities.ratio(
                numerator: Double(salesTotalInclTax),
                denominator: Double(receiptCount)
            ),
            cogsTotal: cogsTotal,
            grossProfit: grossProfit,
            grossMarginRatio: CommonAccountingUtilities.ratio(
                numerator: Double(grossProfit),
                denominator: Double(salesTotalInclTax)
            ),
            closingDifferenceTotal: closingDifferenceTotal,
            laborMinutesTotal: laborMinutesTotal,
            salesPerLaborHour: CommonAccountingUtilities.ratio(
                numerator: Double(salesTotalInclTax),
                denominator: Double(laborMinutesTotal) / 60.0
            ),
            warnings: warnings
        )
    }

    // MARK: - Helpers

    private func salesDebitAccount(for method: PaymentMethod) -> String? {
        switch method {
        case .cash:
            return "現金"
        case .card:
            return "未収金（カード）"
        case .qr:
            return "未収金（QR）"
        case .other:
            return nil
        }
    }

    private func expenseDebitAccount(for category: ExpenseCategory) -> String? {
        switch category {
        case .food:
            return "仕入高（食材）"
        case .drink:
            return "仕入高（飲料）"
        case .consumable:
            return "消耗品費"
        case .utility:
            return "水道光熱費"
        case .misc:
            return "雑費"
        case .transportation:
            return "旅費交通費"
        case .equipment:
            return "備品費"
        }
    }

    private func expenseCreditAccount(for payment: ExpensePaymentMethod) -> String? {
        switch payment {
        case .cash:
            return "現金"
        case .card:
            return "未払金（カード）"
        case .bankTransfer:
            return "普通預金"
        case .employeeAdvance:
            return "未払金（立替）"
        }
    }

    private func monthString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    private func daysInRange(from start: Date, to end: Date) -> [Date] {
        var dates: [Date] = []
        let cal = Calendar.current
        var current = cal.startOfDay(for: start)
        let toDay = cal.startOfDay(for: end)

        while current <= toDay {
            dates.append(current)
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }

    private func isDate(_ date: Date, between start: Date, and end: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        return d >= cal.startOfDay(for: start) && d <= cal.startOfDay(for: end)
    }

    private func persistExportHistories() {
        if let data = try? JSONEncoder().encode(exportHistories) {
            defaults.set(data, forKey: exportHistoryKey)
        }
    }

    private func persistApprovalMeta() {
        if let data = try? JSONEncoder().encode(approvalMetaByRecordId) {
            defaults.set(data, forKey: approvalMetaKey)
        }
    }

    private static func loadExportHistories(defaults: UserDefaults, key: String) -> [AccountingExportHistoryEntry] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AccountingExportHistoryEntry].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.exportedAt > $1.exportedAt }
    }

    private static func loadApprovalMeta(defaults: UserDefaults, key: String) -> [String: TimeRecordApprovalInfo] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: TimeRecordApprovalInfo].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
