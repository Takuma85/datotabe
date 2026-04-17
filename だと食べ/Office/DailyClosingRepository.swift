import Foundation

/// レジ締めデータの取得・保存を担当するプロトコル
/// 将来ここを Firebase 実装に差し替える想定
protocol DailyClosingRepositoryProtocol {

    /// ある店舗・日付のレジ締めデータを取得（なければ nil）
    func loadClosing(storeId: String, date: Date) -> DailyClosing?

    /// レジ締めデータを保存（新規 or 更新）
    func saveClosing(storeId: String, closing: DailyClosing)
}

final class MockDailyClosingRepository: DailyClosingRepositoryProtocol {
    private static var storedClosings: [String: DailyClosing] = [:]

    private let salesRepository: SalesRepository
    private let cashTransactionRepository: CashTransactionRepository
    private let storeName: String

    init(
        salesRepository: SalesRepository = MockSalesRepository(),
        cashTransactionRepository: CashTransactionRepository = MockCashTransactionRepository(),
        storeName: String = "だと食べ 本店"
    ) {
        self.salesRepository = salesRepository
        self.cashTransactionRepository = cashTransactionRepository
        self.storeName = storeName
    }

    func loadClosing(storeId: String, date: Date) -> DailyClosing? {
        let day = Calendar.current.startOfDay(for: date)
        let closingId = DailyClosing.makeId(storeId: storeId, date: day)

        let previousBalance = previousCashBalance(storeId: storeId, date: day, depth: 0)
        let cashSales = cashSalesTotal(storeId: storeId, date: day)
        let cashInTotal = cashFlowTotal(storeId: storeId, date: day, type: .in)
        let cashOutTotal = cashFlowTotal(storeId: storeId, date: day, type: .out)

        if var saved = Self.storedClosings[closingId] {
            saved.storeId = storeId
            saved.storeName = storeName
            saved.date = day
            saved.previousCashBalance = previousBalance
            saved.cashSales = cashSales
            saved.cashInTotal = cashInTotal
            saved.cashOutTotal = cashOutTotal
            if saved.status == .draft {
                saved.confirmedAt = nil
                saved.confirmedBy = nil
            }
            Self.storedClosings[closingId] = saved
            return saved
        }

        var created = DailyClosing(
            id: closingId,
            storeId: storeId,
            storeName: storeName,
            date: day,
            previousCashBalance: previousBalance,
            cashSales: cashSales,
            cashInTotal: cashInTotal,
            cashOutTotal: cashOutTotal,
            actualCashBalance: 0,
            countedCashUnits: [:],
            note: "",
            status: .draft,
            confirmedAt: nil,
            confirmedBy: nil
        )

        let today = Calendar.current.startOfDay(for: Date())
        if day < today {
            // 過去日は仮で締め済みデータを作り、理論値=実残高にしておく
            created.actualCashBalance = created.expectedCashBalance
            created.status = .confirmed
            created.confirmedAt = defaultConfirmedAt(for: day)
            created.confirmedBy = "manager_1"
        }

        Self.storedClosings[closingId] = created
        return created
    }

    func saveClosing(storeId: String, closing: DailyClosing) {
        let day = Calendar.current.startOfDay(for: closing.date)
        let closingId = DailyClosing.makeId(storeId: storeId, date: day)

        var saved = closing
        saved.storeId = storeId
        saved.storeName = storeName
        saved.date = day
        saved.previousCashBalance = previousCashBalance(storeId: storeId, date: day, depth: 0)
        saved.cashSales = cashSalesTotal(storeId: storeId, date: day)
        saved.cashInTotal = cashFlowTotal(storeId: storeId, date: day, type: .in)
        saved.cashOutTotal = cashFlowTotal(storeId: storeId, date: day, type: .out)

        if saved.status == .confirmed || saved.status == .approved {
            if saved.confirmedAt == nil {
                saved.confirmedAt = Date()
            }
            if saved.confirmedBy?.isEmpty ?? true {
                saved.confirmedBy = "manager_1"
            }
        } else {
            saved.confirmedAt = nil
            saved.confirmedBy = nil
        }

        // IDを日付ベースで正規化して保持する
        let normalized = DailyClosing(
            id: closingId,
            storeId: saved.storeId,
            storeName: saved.storeName,
            date: saved.date,
            previousCashBalance: saved.previousCashBalance,
            cashSales: saved.cashSales,
            cashInTotal: saved.cashInTotal,
            cashOutTotal: saved.cashOutTotal,
            actualCashBalance: saved.actualCashBalance,
            countedCashUnits: saved.countedCashUnits,
            note: saved.note,
            status: saved.status,
            confirmedAt: saved.confirmedAt,
            confirmedBy: saved.confirmedBy
        )

        Self.storedClosings[closingId] = normalized
    }

    // MARK: - 集計ヘルパー

    private func previousCashBalance(storeId: String, date: Date, depth: Int) -> Int {
        let cal = Calendar.current
        guard let previousDate = cal.date(byAdding: .day, value: -1, to: date) else {
            return baseOpeningBalance(for: storeId, date: date)
        }

        let previousId = DailyClosing.makeId(storeId: storeId, date: previousDate)
        if let previous = Self.storedClosings[previousId] {
            return carryForwardBalance(from: previous)
        }

        if depth >= 30 {
            return baseOpeningBalance(for: storeId, date: previousDate)
        }

        let previousOpening = previousCashBalance(storeId: storeId, date: previousDate, depth: depth + 1)
        return expectedCashBalance(
            storeId: storeId,
            date: previousDate,
            openingBalance: previousOpening
        )
    }

    private func carryForwardBalance(from closing: DailyClosing) -> Int {
        if closing.status == .confirmed || closing.status == .approved {
            return closing.actualCashBalance
        }
        return closing.expectedCashBalance
    }

    private func expectedCashBalance(storeId: String, date: Date, openingBalance: Int) -> Int {
        let cashSales = cashSalesTotal(storeId: storeId, date: date)
        let cashInTotal = cashFlowTotal(storeId: storeId, date: date, type: .in)
        let cashOutTotal = cashFlowTotal(storeId: storeId, date: date, type: .out)
        return openingBalance + cashSales + cashInTotal - cashOutTotal
    }

    private func cashSalesTotal(storeId: String, date: Date) -> Int {
        salesRepository.fetchPaymentSplits(
            storeId: storeId,
            from: date,
            to: date
        )
        .filter { $0.method == .cash }
        .map(\.amountInclTax)
        .reduce(0, +)
    }

    private func cashFlowTotal(storeId: String, date: Date, type: CashTransactionType) -> Int {
        cashTransactionRepository.fetchTransactions(
            storeId: storeId,
            from: date,
            to: date,
            type: type,
            category: nil,
            minAmount: nil,
            maxAmount: nil
        )
        .map(\.amount)
        .reduce(0, +)
    }

    private func baseOpeningBalance(for storeId: String, date: Date) -> Int {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        let storeSalt = max(1, abs(storeId.hashValue % 17))
        return 30_000 + ((dayOfYear + storeSalt) % 7) * 1_000
    }

    private func defaultConfirmedAt(for day: Date) -> Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day
    }
}
