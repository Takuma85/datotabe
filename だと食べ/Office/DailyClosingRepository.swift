import Foundation

/// レジ締めデータの取得・保存を担当するプロトコル
/// 将来ここを Firebase 実装に差し替える想定
protocol DailyClosingRepositoryProtocol {

    /// ある店舗・日付のレジ締めデータを取得（なければ nil）
    func loadClosing(storeId: String, date: Date) -> DailyClosing?

    /// レジ締めデータを保存（新規 or 更新）
    func saveClosing(storeId: String, closing: DailyClosing)
}

/// とりあえず UI 用のダミー実装（後で Firebase 版に差し替える）
final class MockDailyClosingRepository: DailyClosingRepositoryProtocol {

    func loadClosing(storeId: String, date: Date) -> DailyClosing? {
        // 実際は storeId + date をキーに読み込む想定
        // 今は「その日用のダミーデータ」を適当に返すだけ
        let day = Calendar.current.component(.day, from: date)

        return DailyClosing(
            storeName: "だと食べ 本店",
            date: date,
            previousCashBalance: 30000 + day * 100,  // 日付でちょっと変わるように
            cashSales: 80000 + day * 500,
            cashInTotal: 10000,
            cashOutTotal: 5000,
            actualCashBalance: 0,
            note: "",
            status: .draft
        )
    }

    func saveClosing(storeId: String, closing: DailyClosing) {
        // 今は何もしないダミー実装
        // 後で Firebase 保存処理に差し替え予定
        print("Mock saveClosing called for storeId=\(storeId), date=\(closing.date)")
    }
}

