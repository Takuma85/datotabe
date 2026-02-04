import Foundation

// MARK: - Repository プロトコル

protocol DailyReportRepository {
    func fetchReports(
        storeId: String,
        from: Date,
        to: Date,
        status: DailyReport.Status?
    ) async throws -> [DailyReport]

    func fetchReportDetail(id: String) async throws -> DailyReport

    func generate(
        storeId: String,
        date: Date
    ) async throws -> DailyReport

    func submit(reportId: String) async throws -> DailyReport
    func approve(reportId: String) async throws -> DailyReport
    func reject(reportId: String, reason: String) async throws -> DailyReport

    /// 日報CSV（縦持ち）を書き出して、そのファイルURLを返す想定
    func exportCSV(
        storeId: String,
        from: Date,
        to: Date,
        profileCode: String
    ) async throws -> URL
}

// MARK: - エラー定義

enum DailyReportRepositoryError: Error {
    case notFound
    case invalidRange
    case ioError
}

// MARK: - モック実装（まずはこれで画面を作る）

final class MockDailyReportRepository: DailyReportRepository {

    private var reports: [DailyReport] = []
    private let storeId: String = "store_1"

    init() {
        // 直近3日分くらいのサンプルデータを作っておく
        let today = Date()
        let cal = Calendar.current

        for i in 0..<3 {
            if let date = cal.date(byAdding: .day, value: -i, to: today) {
                var sample = DailyReport.mockSample()
                // 日付とIDだけ上書きして使い回し
                sample = DailyReport(
                    id: UUID().uuidString,
                    storeId: storeId,
                    date: date,
                    status: i == 0 ? .draft : .approved,
                    total: sample.total,
                    segments: sample.segments,
                    notes: sample.notes,
                    issueNotes: sample.issueNotes
                )
                reports.append(sample)
            }
        }
    }

    // 一覧取得
    func fetchReports(
        storeId: String,
        from: Date,
        to: Date,
        status: DailyReport.Status?
    ) async throws -> [DailyReport] {

        guard from <= to else {
            throw DailyReportRepositoryError.invalidRange
        }

        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay = cal.startOfDay(for: to)

        return reports
            .filter { $0.storeId == storeId }
            .filter { report in
                let d = cal.startOfDay(for: report.date)
                return d >= fromDay && d <= toDay
            }
            .filter { report in
                if let status = status {
                    return report.status == status
                } else {
                    return true
                }
            }
            .sorted { $0.date > $1.date }
    }

    // 詳細取得
    func fetchReportDetail(id: String) async throws -> DailyReport {
        guard let report = reports.first(where: { $0.id == id }) else {
            throw DailyReportRepositoryError.notFound
        }
        return report
    }

    // 日報生成（モックなので、存在すれば上書き・なければ追加）
    func generate(
        storeId: String,
        date: Date
    ) async throws -> DailyReport {

        let cal = Calendar.current
        let day = cal.startOfDay(for: date)

        // 既存があれば更新
        if let index = reports.firstIndex(where: { r in
            r.storeId == storeId && cal.isDate(r.date, inSameDayAs: day)
        }) {
            var updated = reports[index]
            // 本当はここで集計し直すが、今はモックなのでそのまま
            updated.status = .draft
            reports[index] = updated
            return updated
        }

        // 新規作成（モックデータ使い回し）
        var sample = DailyReport.mockSample()
        sample = DailyReport(
            id: UUID().uuidString,
            storeId: storeId,
            date: day,
            status: .draft,
            total: sample.total,
            segments: sample.segments,
            notes: "自動生成されたモック日報",
            issueNotes: nil
        )
        reports.append(sample)
        return sample
    }

    // 提出
    func submit(reportId: String) async throws -> DailyReport {
        try updateStatus(id: reportId, to: .submitted)
    }

    // 承認
    func approve(reportId: String) async throws -> DailyReport {
        try updateStatus(id: reportId, to: .approved)
    }

    // 差戻し
    func reject(reportId: String, reason: String) async throws -> DailyReport {
        var report = try updateStatus(id: reportId, to: .rejected)
        // 差戻し理由を issueNotes に追記（簡易実装）
        let prefix = (report.issueNotes?.isEmpty == false) ? (report.issueNotes! + "\n") : ""
        report.issueNotes = prefix + "差戻し理由: " + reason
        // 配列側も更新
        if let idx = reports.firstIndex(where: { $0.id == report.id }) {
            reports[idx] = report
        }
        return report
    }

    // CSV出力（モック：テンポラリに1ファイル書き出す）
    func exportCSV(
        storeId: String,
        from: Date,
        to: Date,
        profileCode: String
    ) async throws -> URL {

        let targetReports = try await fetchReports(
            storeId: storeId,
            from: from,
            to: to,
            status: nil
        )

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        var lines: [String] = []

        // ヘッダ
        lines.append([
            "date",
            "store_id",
            "time_band_code",
            "time_band_name",
            "total_sales",
            "cash_sales",
            "card_sales",
            "qr_sales",
            "other_sales",
            "guest_count",
            "table_count",
            "average_spend",
            "status"
        ].joined(separator: ","))

        for report in targetReports {
            for segment in report.segments {
                let cols: [String] = [
                    df.string(from: report.date),
                    report.storeId,
                    segment.timeBandCode,
                    segment.timeBandName,
                    String(segment.totalSales),
                    String(segment.cashSales),
                    String(segment.cardSales),
                    String(segment.qrSales),
                    String(segment.otherSales),
                    String(segment.guestCount),
                    String(segment.tableCount),
                    String(segment.averageSpend),
                    report.status.rawValue
                ]
                lines.append(cols.joined(separator: ","))
            }
        }

        let csvString = lines.joined(separator: "\n")

        // 一時ファイルに保存
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "daily_reports_\(Int(Date().timeIntervalSince1970)).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csvString.data(using: .utf8)?.write(to: fileURL)
            return fileURL
        } catch {
            throw DailyReportRepositoryError.ioError
        }
    }

    // MARK: - 内部ヘルパー

    private func updateStatus(id: String, to newStatus: DailyReport.Status) throws -> DailyReport {
        guard let index = reports.firstIndex(where: { $0.id == id }) else {
            throw DailyReportRepositoryError.notFound
        }
        var report = reports[index]
        report.status = newStatus
        reports[index] = report
        return report
    }
}

