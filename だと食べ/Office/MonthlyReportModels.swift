import Foundation

struct MonthlySummary: Hashable, Codable {
    let yearMonth: String
    let storeId: String
    let storeName: String

    var salesTotalInclTax: Int
    var salesCashInclTax: Int
    var salesCardInclTax: Int
    var salesQrInclTax: Int
    var salesOtherInclTax: Int

    var salesSubtotalExclTax: Int
    var salesTaxTotal: Int

    var expensesTotal: Int
    var expensesFood: Int
    var expensesDrink: Int
    var expensesConsumable: Int
    var expensesUtility: Int
    var expensesMisc: Int

    var cashInTotal: Int
    var cashOutTotal: Int
    var cashOutPurchaseTotal: Int
    var cashOutReimburseTotal: Int
    var cashOutDepositToBankTotal: Int

    var closingDifferenceTotal: Int
    var closingIssueDays: Int
}

struct MonthlyDaily: Hashable, Codable {
    let date: Date
    let storeId: String
    let storeName: String

    var salesTotalInclTax: Int
    var salesSubtotalExclTax: Int
    var salesTaxTotal: Int

    var salesCashInclTax: Int
    var salesCardInclTax: Int
    var salesQrInclTax: Int
    var salesOtherInclTax: Int

    var expensesTotal: Int
    var cashInTotal: Int
    var cashOutTotal: Int

    var expectedCashBalance: Int?
    var actualCashBalance: Int?
    var closingDifference: Int?
    var closingIssueFlag: Bool?
}

enum AccountMappingType: String, CaseIterable, Identifiable, Codable {
    case salesPayment = "sales_payment"
    case salesRevenue = "sales_revenue"
    case expenseCategory = "expense_category"
    case expensePayment = "expense_payment"
    case cashTxCategory = "cash_tx_category"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .salesPayment: return "売上: 支払方法 → 借方"
        case .salesRevenue: return "売上: 売上高 → 貸方"
        case .expenseCategory: return "経費: カテゴリ → 借方"
        case .expensePayment: return "経費: 支払方法 → 貸方"
        case .cashTxCategory: return "入出金: カテゴリ → 振替"
        }
    }
}

struct AccountMapping: Identifiable, Hashable, Codable {
    let id: String
    let storeId: String

    var mappingType: AccountMappingType
    var mappingKey: String

    var debitAccountCode: String?
    var creditAccountCode: String?
    var taxCode: String?

    var isActive: Bool
    var updatedAt: Date
}

enum JournalStatus: String, CaseIterable, Identifiable, Codable {
    case draft
    case exported

    var id: String { rawValue }
}

enum JournalSourceType: String, CaseIterable, Identifiable, Codable {
    case dailySummary = "daily_summary"

    var id: String { rawValue }
}

struct JournalLine: Identifiable, Hashable, Codable {
    let id: String

    var lineNo: Int
    var debitAccountCode: String
    var creditAccountCode: String
    var amount: Int
    var taxCode: String?
    var memo: String
    var sourceRefType: String?
    var sourceRefKey: String?
}

struct JournalEntry: Identifiable, Hashable, Codable {
    let id: String

    let storeId: String
    var businessDate: Date
    var sourceType: JournalSourceType
    var status: JournalStatus

    var createdByUserId: String
    var createdAt: Date
    var updatedAt: Date

    var lines: [JournalLine]
}

struct JournalGenerationResult: Hashable, Codable {
    var generatedEntries: Int
    var replacedEntries: Int
    var warningMessages: [String]
    var previewEntries: [JournalEntry]
}
