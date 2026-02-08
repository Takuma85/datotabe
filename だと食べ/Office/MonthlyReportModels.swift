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
