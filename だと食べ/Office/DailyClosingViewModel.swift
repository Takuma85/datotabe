import Foundation
import Combine

/// レジ締め画面用の ViewModel
final class DailyClosingViewModel: ObservableObject {
    
    // 依存関係
    private let repository: DailyClosingRepositoryProtocol
    private let storeId: String

    // 画面で表示・編集する1日分のレジ締めデータ
    @Published var closing: DailyClosing

    @Published var isLoading: Bool = false
    @Published var toastMessage: String?

    // MARK: - 初期化

    init(
            storeId: String,
            date: Date,
            repository: DailyClosingRepositoryProtocol = MockDailyClosingRepository()
        ) {
            self.storeId = storeId
            self.repository = repository

            if let loaded = repository.loadClosing(storeId: storeId, date: date) {
                self.closing = loaded
            } else {
                self.closing = DailyClosing(
                    storeName: "だと食べ 本店",
                    date: date,
                    previousCashBalance: 0,
                    cashSales: 0,
                    cashInTotal: 0,
                    cashOutTotal: 0,
                    actualCashBalance: 0,
                    note: "",
                    status: .draft
                )
            }
        }
    /// デフォルトは「今日」のレジ締めをロード
        convenience init(
            storeId: String = "store_1",
            repository: DailyClosingRepositoryProtocol = MockDailyClosingRepository()
        ) {
            self.init(storeId: storeId, date: Date(), repository: repository)
        }

    // MARK: - ユースケース的なメソッド

    /// 実際に数えたレジ内現金を更新する
    func updateActualCash(from text: String) {
            let value = Int(text) ?? 0
            closing.actualCashBalance = value
        }

    /// 最新状態を再計算する（今はダミーでメッセージだけ）
    /// 後から Firebase / API 呼び出しに差し替え予定
    func recalculateFromServerMock() {
            let date = closing.date
            if let loaded = repository.loadClosing(storeId: storeId, date: date) {
                // 実残高とメモは維持したいので、必要な項目だけ上書きしてもOK
                let actual = closing.actualCashBalance
                let note = closing.note

                closing = loaded
                closing.actualCashBalance = actual
                closing.note = note
            }
            toastMessage = "（ダミー）売上・入出金から理論残高を再計算しました。"
        }

    /// 店長が「締め確定」を押したときの処理
    func confirmClosing() {
            closing.status = .confirmed
            // 将来ここで Firebase に保存する
            repository.saveClosing(storeId: storeId, closing: closing)
            toastMessage = "レジ締めを締め確定しました。"
        }

    /// 差額に応じたラベル文言
    var differenceLabelText: String {
        let diff = closing.difference
        if diff == 0 {
            return "差額：0円（ピッタリです）"
        } else if diff > 0 {
            return "差額：+\(diff)円（実際のほうが多いです）"
        } else {
            return "差額：\(diff)円（実際のほうが少ないです）"
        }
    }

    /// ステータスの表示文字列
    var statusText: String {
        closing.status.label
    }
}
