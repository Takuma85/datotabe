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
    private let defaultStoreId: String

    private let salesRepository: SalesRepository
    private let expenseRepository: ExpenseRepository
    private let dailyClosingRepository: DailyClosingRepositoryProtocol
    private let timeRecordRepository: TimeRecordRepository

    init(
        storeId: String = "store_1",
        salesRepository: SalesRepository = MockSalesRepository(),
        expenseRepository: ExpenseRepository = MockExpenseRepository(),
        dailyClosingRepository: DailyClosingRepositoryProtocol = MockDailyClosingRepository(),
        timeRecordRepository: TimeRecordRepository = UserDefaultsTimeRecordRepository()
    ) {
        self.defaultStoreId = storeId
        self.salesRepository = salesRepository
        self.expenseRepository = expenseRepository
        self.dailyClosingRepository = dailyClosingRepository
        self.timeRecordRepository = timeRecordRepository

        seedInitialReports()
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

        refreshCachedReports()

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
                if let status {
                    return report.status == status
                }
                return true
            }
            .sorted { $0.date > $1.date }
    }

    // 詳細取得
    func fetchReportDetail(id: String) async throws -> DailyReport {
        refreshCachedReports()

        guard let report = reports.first(where: { $0.id == id }) else {
            throw DailyReportRepositoryError.notFound
        }
        return report
    }

    // 日報生成（売上 / 経費 / 労務 / レジ締め情報を自動集計）
    func generate(
        storeId: String,
        date: Date
    ) async throws -> DailyReport {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)

        if let index = reports.firstIndex(where: { r in
            r.storeId == storeId && cal.isDate(r.date, inSameDayAs: day)
        }) {
            let base = reports[index]
            let refreshed = buildDailyReport(
                id: base.id,
                storeId: base.storeId,
                date: day,
                status: .draft,
                notes: "自動再生成",
                issueNotes: base.issueNotes
            )
            reports[index] = refreshed
            return refreshed
        }

        let created = buildDailyReport(
            id: UUID().uuidString,
            storeId: storeId,
            date: day,
            status: .draft,
            notes: "自動生成された日報",
            issueNotes: nil
        )
        reports.append(created)
        return created
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
        let prefix = (report.issueNotes?.isEmpty == false) ? (report.issueNotes! + "\n") : ""
        report.issueNotes = prefix + "差戻し理由: " + reason
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
            "total_expenses",
            "total_labor_minutes",
            "daily_closing_id",
            "daily_closing_status",
            "cash_difference",
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
                    String(report.totalExpenses),
                    String(report.totalLaborMinutes),
                    report.dailyClosingId ?? "",
                    report.dailyClosingStatus?.rawValue ?? "",
                    report.cashDifference.map { String($0) } ?? "",
                    report.status.rawValue
                ]
                lines.append(cols.joined(separator: ","))
            }
        }

        let csvString = lines.joined(separator: "\n")
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

    private func seedInitialReports() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        for offset in 0..<3 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }

            let status: DailyReport.Status = (offset == 0) ? .draft : .approved
            let report = buildDailyReport(
                id: UUID().uuidString,
                storeId: defaultStoreId,
                date: day,
                status: status,
                notes: offset == 0 ? "本日分の下書き日報" : "自動生成サンプル",
                issueNotes: nil
            )
            reports.append(report)
        }
    }

    private func refreshCachedReports() {
        reports = reports.map { existing in
            buildDailyReport(
                id: existing.id,
                storeId: existing.storeId,
                date: existing.date,
                status: existing.status,
                notes: existing.notes,
                issueNotes: existing.issueNotes
            )
        }
    }

    private func buildDailyReport(
        id: String,
        storeId: String,
        date: Date,
        status: DailyReport.Status,
        notes: String?,
        issueNotes: String?
    ) -> DailyReport {
        let day = Calendar.current.startOfDay(for: date)

        let receipts = salesRepository.fetchReceipts(
            storeId: storeId,
            from: day,
            to: day,
            statuses: [.posted, .refunded]
        )

        let splits = salesRepository.fetchPaymentSplits(
            storeId: storeId,
            from: day,
            to: day
        )

        let totalSales = receipts.map(\.totalInclTax).reduce(0, +)
        let cashSales = splits.filter { $0.method == .cash }.map(\.amountInclTax).reduce(0, +)
        let cardSales = splits.filter { $0.method == .card }.map(\.amountInclTax).reduce(0, +)
        let qrSales = splits.filter { $0.method == .qr }.map(\.amountInclTax).reduce(0, +)
        let otherSales = splits.filter { $0.method == .other }.map(\.amountInclTax).reduce(0, +)
        let guestCount = receipts.map(\.peopleCount).reduce(0, +)
        let tableCount = receipts.filter { $0.status == .posted }.count
        let averageSpend = guestCount > 0 ? totalSales / guestCount : 0

        let allDay = DailyReportSegment(
            timeBandCode: "all_day",
            timeBandName: "終日",
            totalSales: totalSales,
            cashSales: cashSales,
            cardSales: cardSales,
            qrSales: qrSales,
            otherSales: otherSales,
            guestCount: guestCount,
            tableCount: tableCount,
            averageSpend: averageSpend
        )

        let expenses = expenseRepository.fetchExpenses(
            storeId: storeId,
            from: day,
            to: day,
            category: nil,
            paymentMethod: nil,
            reimbursed: nil,
            status: .approved,
            employeeId: nil
        )
        let totalExpenses = expenses.map(\.amount).reduce(0, +)

        let totalLaborMinutes = timeRecordRepository.loadAll()
            .filter { $0.storeId == storeId }
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .filter { $0.status == .approved }
            .map(calcWorkedMinutes)
            .reduce(0, +)

        let closing = dailyClosingRepository.loadClosing(storeId: storeId, date: day)
        let closingStatus = closing?.status
        let shouldShowDifference = (closingStatus == .confirmed || closingStatus == .approved)
        let cashDifference = shouldShowDifference ? closing?.difference : nil

        let mergedIssueNotes = mergeIssueNotes(
            base: issueNotes,
            closing: closing
        )

        return DailyReport(
            id: id,
            storeId: storeId,
            date: day,
            status: status,
            total: allDay,
            segments: [allDay],
            totalExpenses: totalExpenses,
            totalLaborMinutes: totalLaborMinutes,
            dailyClosingId: closing?.id,
            dailyClosingStatus: closingStatus,
            cashDifference: cashDifference,
            notes: notes,
            issueNotes: mergedIssueNotes
        )
    }

    private func mergeIssueNotes(base: String?, closing: DailyClosing?) -> String? {
        guard let closing else { return base }
        guard closing.issueFlag else { return base }

        let message = "レジ差額あり: \(closing.difference)円"
        let trimmed = base?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmed, !trimmed.isEmpty {
            if trimmed.contains(message) {
                return trimmed
            }
            return "\(trimmed)\n\(message)"
        }
        return message
    }

    private func calcWorkedMinutes(_ record: TimeRecord) -> Int {
        guard let clockIn = record.clockInAt else { return 0 }
        let end = record.clockOutAt ?? clockIn
        let total = end.timeIntervalSince(clockIn) - Double(record.breakMinutes * 60)
        return max(0, Int(total / 60))
    }

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
