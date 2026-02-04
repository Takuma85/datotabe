import Foundation

/// レジ締めのステータス
enum ClosingStatus: String, CaseIterable, Identifiable {
    case draft       // 自動計算だけ終わった状態
    case confirmed   // 店長が実残高を入力して締めた
    case approved    // オーナーなどが承認（必要なら使う）

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft: return "ドラフト"
        case .confirmed: return "締め済み"
        case .approved: return "承認済み"
        }
    }
}

/// レジ締め1日分の表示用モデル（まだDBとは分離しておく想定）
struct DailyClosing: Identifiable {
    let id: UUID = UUID()

    var storeName: String             // 店舗名（今回は文字列だけ持つ）
    var date: Date                    // 対象日

    // 前日からの繰越
    var previousCashBalance: Int      // 前日締め後のレジ残高（円）

    // 当日の現金売上と入出金
    var cashSales: Int                // 当日現金売上
    var cashInTotal: Int              // 入金合計（釣銭投入など）
    var cashOutTotal: Int             // 出金合計（買い物・立替精算など）

    // 実際のレジ内現金（カウント結果）
    var actualCashBalance: Int        // 実残高

    // メモ等
    var note: String
    var status: ClosingStatus

    // MARK: - 計算プロパティ

    /// 理論上のレジ残高
    var expectedCashBalance: Int {
        previousCashBalance + cashSales + cashInTotal - cashOutTotal
    }

    /// 差額（実際 - 理論）
    var difference: Int {
        actualCashBalance - expectedCashBalance
    }

    /// 差額に問題ありかどうか（仮で±1000円以上）
    var hasIssue: Bool {
        abs(difference) >= 1000
    }
}

