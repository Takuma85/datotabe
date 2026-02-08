import Foundation

enum SalesReceiptStatus: String, CaseIterable, Identifiable, Codable {
    case posted
    case refunded
    case draft

    var id: String { rawValue }
}

enum PaymentMethod: String, CaseIterable, Identifiable, Codable {
    case cash
    case card
    case qr
    case other

    var id: String { rawValue }
}

struct SalesReceipt: Identifiable, Hashable, Codable {
    let id: String
    let storeId: String
    let businessDate: Date

    var totalInclTax: Int
    var subtotalExclTax: Int
    var taxTotal: Int

    var status: SalesReceiptStatus
}

struct PaymentSplit: Identifiable, Hashable, Codable {
    let id: String
    let receiptId: String
    let storeId: String
    let businessDate: Date

    var method: PaymentMethod
    var amountInclTax: Int
}

extension SalesReceipt {
    static func sample(storeId: String = "store_1") -> [SalesReceipt] {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today

        return [
            SalesReceipt(
                id: UUID().uuidString,
                storeId: storeId,
                businessDate: today,
                totalInclTax: 120_000,
                subtotalExclTax: 109_091,
                taxTotal: 10_909,
                status: .posted
            ),
            SalesReceipt(
                id: UUID().uuidString,
                storeId: storeId,
                businessDate: yesterday,
                totalInclTax: 80_000,
                subtotalExclTax: 72_727,
                taxTotal: 7_273,
                status: .posted
            ),
            SalesReceipt(
                id: UUID().uuidString,
                storeId: storeId,
                businessDate: yesterday,
                totalInclTax: -5_000,
                subtotalExclTax: -4_545,
                taxTotal: -455,
                status: .refunded
            )
        ]
    }
}

extension PaymentSplit {
    static func sample(receipts: [SalesReceipt]) -> [PaymentSplit] {
        var splits: [PaymentSplit] = []

        for receipt in receipts {
            let absTotal = abs(receipt.totalInclTax)
            let cash = Int(Double(absTotal) * 0.4)
            let card = Int(Double(absTotal) * 0.5)
            let other = absTotal - cash - card

            let sign = receipt.totalInclTax >= 0 ? 1 : -1

            splits.append(
                PaymentSplit(
                    id: UUID().uuidString,
                    receiptId: receipt.id,
                    storeId: receipt.storeId,
                    businessDate: receipt.businessDate,
                    method: .cash,
                    amountInclTax: sign * cash
                )
            )
            splits.append(
                PaymentSplit(
                    id: UUID().uuidString,
                    receiptId: receipt.id,
                    storeId: receipt.storeId,
                    businessDate: receipt.businessDate,
                    method: .card,
                    amountInclTax: sign * card
                )
            )
            if other != 0 {
                splits.append(
                    PaymentSplit(
                        id: UUID().uuidString,
                        receiptId: receipt.id,
                        storeId: receipt.storeId,
                        businessDate: receipt.businessDate,
                        method: .other,
                        amountInclTax: sign * other
                    )
                )
            }
        }

        return splits
    }
}
