import Foundation

/// 現金カウントで扱う券種
enum CashDenomination: Int, CaseIterable, Hashable, Identifiable {
    case bill10000 = 10_000
    case bill5000 = 5_000
    case bill2000 = 2_000
    case bill1000 = 1_000
    case coin500 = 500
    case coin100 = 100
    case coin50 = 50
    case coin10 = 10
    case coin5 = 5
    case coin1 = 1

    var id: Int { rawValue }

    var label: String {
        "¥\(rawValue)"
    }

    var categoryLabel: String {
        switch self {
        case .bill10000, .bill5000, .bill2000, .bill1000:
            return "お札"
        default:
            return "硬貨"
        }
    }

    var isBill: Bool {
        switch self {
        case .bill10000, .bill5000, .bill2000, .bill1000:
            return true
        default:
            return false
        }
    }
}

/// レジ締めのステータス
enum ClosingStatus: String, CaseIterable, Identifiable, Codable, Hashable {
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
    let id: String
    var storeId: String
    var storeName: String             // 店舗名（今回は文字列だけ持つ）
    var date: Date                    // 対象日

    // 要件: 前日からの繰越
    var previousCashBalance: Int      // 前日締め後のレジ残高（円）

    // 要件: 当日の現金売上と入出金
    var cashSales: Int                // 当日現金売上
    var cashInTotal: Int              // 入金合計（釣銭投入など）
    var cashOutTotal: Int             // 出金合計（買い物・立替精算など）

    // 実際のレジ内現金（カウント結果）
    var actualCashBalance: Int        // 実残高
    var countedCashUnits: [CashDenomination: Int] = [:] // 券種ごとの枚数

    // メモ等
    var note: String
    var status: ClosingStatus
    var confirmedAt: Date?
    var confirmedBy: String?

    // MARK: - 計算プロパティ

    /// 理論上のレジ残高
    var expectedCashBalance: Int {
        previousCashBalance + cashSales + cashInTotal - cashOutTotal
    }

    /// 差額（実際 - 理論）
    var difference: Int {
        actualCashBalance - expectedCashBalance
    }

    /// 要件: 課題フラグ（仮で±1000円以上）
    var issueFlag: Bool {
        abs(difference) >= 1000
    }

    /// 既存参照互換
    var hasIssue: Bool {
        issueFlag
    }
}

extension DailyClosing {
    static func makeId(storeId: String, date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        return "closing_\(storeId)_\(Self.idFormatter.string(from: day))"
    }

    private static let idFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
