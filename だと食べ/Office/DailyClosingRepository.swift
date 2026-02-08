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

    func loadClosing(storeId: String, date: Date) -> DailyClosing? {
        let calendar = Calendar.current

        // 日によってちょっと数字が変わるようにする
        let day = calendar.component(.day, from: date)

        let previous = 30000 + day * 100      // 前日繰越
        let cashSales = 80000 + day * 500     // 現金売上
        let cashIn = 10_000                   // 入金
        let cashOut = 5_000                   // 出金

        // 今日か過去かでステータスと実残高を変える
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)

        var status: ClosingStatus = .draft
        var actual: Int = 0

        if target < today {
            // 過去日は「締め済み」で、差額0になるように実残高 = 理論残高
            let expected = previous + cashSales + cashIn - cashOut
            status = .confirmed
            actual = expected
        } else {
            // 今日以降（基本は今日）はドラフト・実残高 0 のまま
            status = .draft
            actual = 0
        }

        return DailyClosing(
            storeName: "だと食べ 本店",
            date: date,
            previousCashBalance: previous,
            cashSales: cashSales,
            cashInTotal: cashIn,
            cashOutTotal: cashOut,
            actualCashBalance: actual,
            note: "",
            status: status
        )
    }

    func saveClosing(storeId: String, closing: DailyClosing) {
        // 今は何もしないダミー実装
        print("Mock saveClosing called for storeId=\(storeId), date=\(closing.date)")
    }
}


