import Foundation

/// ランチ / ディナー / 終日 などの時間帯定義
struct TimeBand: Identifiable, Hashable, Codable {
    var id: String { code }

    let code: String        // "all_day", "lunch", "dinner" など
    let name: String        // "終日", "ランチ", "ディナー"
    let startTime: String   // "11:00:00" など（まずは文字列でOK）
    let endTime: String     // "15:00:00"
    let sortOrder: Int
}

/// 日報の時間帯別サマリ（縦持ち1行ぶん）
struct DailyReportSegment: Identifiable, Hashable, Codable {
    // 1日1レポートの中では timeBandCode が一意なので ID として使う
    var id: String { timeBandCode }

    let timeBandCode: String    // "all_day", "lunch" など
    let timeBandName: String    // "終日", "ランチ" など

    let totalSales: Int         // 総売上
    let cashSales: Int
    let cardSales: Int
    let qrSales: Int
    let otherSales: Int

    let guestCount: Int         // 客数
    let tableCount: Int         // 会計件数
    let averageSpend: Int       // 客単価
}

/// 1店舗 × 1日分の日報
struct DailyReport: Identifiable, Hashable, Codable {

    enum Status: String, Codable, CaseIterable {
        case draft
        case submitted
        case approved
        case rejected
    }

    let id: String          // UUID() などで発行（DBのID相当）
    let storeId: String
    let date: Date

    var status: Status

    /// 1日トータル（all_dayと同じ値を入れる運用）
    var total: DailyReportSegment

    /// 時間帯別の内訳（必ず all_day を含む）
    var segments: [DailyReportSegment]

    var notes: String?
    var issueNotes: String?
}

// MARK: - モックデータ（画面作り用）

extension DailyReport {
    static func mockSample() -> DailyReport {
        let allDay = DailyReportSegment(
            timeBandCode: "all_day",
            timeBandName: "終日",
            totalSales: 100_000,
            cashSales: 40_000,
            cardSales: 50_000,
            qrSales: 8_000,
            otherSales: 2_000,
            guestCount: 50,
            tableCount: 30,
            averageSpend: 2_000
        )

        let lunch = DailyReportSegment(
            timeBandCode: "lunch",
            timeBandName: "ランチ",
            totalSales: 40_000,
            cashSales: 20_000,
            cardSales: 15_000,
            qrSales: 4_000,
            otherSales: 1_000,
            guestCount: 20,
            tableCount: 12,
            averageSpend: 2_000
        )

        let dinner = DailyReportSegment(
            timeBandCode: "dinner",
            timeBandName: "ディナー",
            totalSales: 60_000,
            cashSales: 20_000,
            cardSales: 35_000,
            qrSales: 4_000,
            otherSales: 1_000,
            guestCount: 30,
            tableCount: 18,
            averageSpend: 2_000
        )

        return DailyReport(
            id: UUID().uuidString,
            storeId: "store_1",
            date: Date(),
            status: .draft,
            total: allDay,
            segments: [allDay, lunch, dinner],
            notes: "サンプル日報",
            issueNotes: nil
        )
    }
}

