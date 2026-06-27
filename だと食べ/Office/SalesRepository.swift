import Foundation
import SwiftUI

protocol SalesRepository {
    func fetchReceipts(
        storeId: String,
        from: Date,
        to: Date,
        statuses: [SalesReceiptStatus]
    ) -> [SalesReceipt]

    func fetchPaymentSplits(
        storeId: String,
        from: Date,
        to: Date
    ) -> [PaymentSplit]
}

final class MockSalesRepository: SalesRepository {
    private var receipts: [SalesReceipt]
    private var splits: [PaymentSplit]
    private let settingsRepository: AppSettingsRepository

    init(
        seedReceipts: [SalesReceipt] = SalesReceipt.sample(),
        settingsRepository: AppSettingsRepository = UserDefaultsAppSettingsRepository()
    ) {
        self.receipts = seedReceipts
        self.splits = PaymentSplit.sample(receipts: seedReceipts)
        self.settingsRepository = settingsRepository
    }

    func fetchReceipts(
        storeId: String,
        from: Date,
        to: Date,
        statuses: [SalesReceiptStatus]
    ) -> [SalesReceipt] {
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay = cal.startOfDay(for: to)

        return receipts
            .filter { $0.storeId == storeId }
            .filter { receipt in
                let d = cal.startOfDay(for: receipt.businessDate)
                return d >= fromDay && d <= toDay
            }
            .filter { receipt in
                statuses.contains(receipt.status)
            }
            .map(normalizeTax)
            .sorted { $0.businessDate > $1.businessDate }
    }

    func fetchPaymentSplits(
        storeId: String,
        from: Date,
        to: Date
    ) -> [PaymentSplit] {
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay = cal.startOfDay(for: to)

        return splits
            .filter { $0.storeId == storeId }
            .filter { split in
                let d = cal.startOfDay(for: split.businessDate)
                return d >= fromDay && d <= toDay
            }
    }

    private func normalizeTax(_ receipt: SalesReceipt) -> SalesReceipt {
        let taxSettings = settingsRepository.loadTaxSettings(storeId: receipt.storeId)
        let result = TaxCalculator.fromTaxIncluded(
            totalInclTax: receipt.totalInclTax,
            rate: taxSettings.defaultRate.rate,
            rounding: taxSettings.roundingRule
        )

        var normalized = receipt
        normalized.subtotalExclTax = result.subtotalExclTax
        normalized.taxTotal = result.taxAmount
        return normalized
    }
}

// MARK: - SwiftUI Environment

private struct SalesRepositoryKey: EnvironmentKey {
    static let defaultValue: SalesRepository = MockSalesRepository()
}

extension EnvironmentValues {
    var salesRepository: SalesRepository {
        get { self[SalesRepositoryKey.self] }
        set { self[SalesRepositoryKey.self] = newValue }
    }
}
