import Foundation

struct AnalyticsWarning: Identifiable, Hashable, Codable {
    var id: String { code }
    let code: String
    let message: String
    let value: Int
}

struct AnalyticsMonthlyKpi: Hashable, Codable {
    var salesTotalInclTax: Int
    var salesSubtotalExclTax: Int
    var salesTaxTotal: Int
    var receiptCount: Int
    var guestCount: Int
    var avgSpendPerGuest: Double?
    var avgSpendPerReceipt: Double?

    var payCash: Int
    var payCard: Int
    var payQr: Int
    var payOther: Int
    var payTotal: Int

    var cashRatio: Double?
    var cardRatio: Double?
    var qrRatio: Double?
    var otherRatio: Double?

    var cogsTotal: Int
    var grossProfit: Int
    var cogsRatio: Double?
    var grossMarginRatio: Double?

    var closingDifferenceTotal: Int
    var closingIssueDays: Int
    var depositToBankTotal: Int

    var laborMinutesTotal: Int
    var salesPerLaborHour: Double?
}

struct AnalyticsMonthlyBreakdowns: Hashable, Codable {
    var cogsByCategory: [ExpenseCategory: Int]
    var expensesByCategory: [ExpenseCategory: Int]
    var paymentsByMethod: [PaymentMethod: Int]
    var expensesByVendor: [String: Int]
}

struct AnalyticsMonthlyReport: Hashable, Codable {
    let month: String
    var kpi: AnalyticsMonthlyKpi
    var breakdowns: AnalyticsMonthlyBreakdowns
    var warnings: [AnalyticsWarning]
}

struct AnalyticsDailyRow: Identifiable, Hashable, Codable {
    var id: String { dateKey }
    let date: Date
    let dateKey: String
    let salesTotalInclTax: Int
    let cogsTotal: Int
    let cogsRatio: Double?
    let guestCount: Int
    let closingDifference: Int?
    let laborMinutesTotal: Int
}
