import Foundation

@MainActor
final class DailyReportViewModel: ObservableObject {

    // 一覧・詳細
    @Published var reports: [DailyReport] = []
    @Published var selectedReport: DailyReport?

    // 画面状態
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // 絞り込み条件
    @Published var fromDate: Date
    @Published var toDate: Date
    @Published var selectedStatus: DailyReport.Status? = nil

    // CSV出力
    @Published var isExporting: Bool = false
    @Published var exportedCSVURL: URL?

    private let storeId: String
    private let repository: DailyReportRepository

    init(
        storeId: String = "store_1",
        repository: DailyReportRepository = MockDailyReportRepository()
    ) {
        self.storeId = storeId
        self.repository = repository

        let today = Calendar.current.startOfDay(for: Date())
        self.toDate = today
        self.fromDate = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
    }

    // MARK: - 一覧読み込み

    func loadList() {
        Task {
            await loadListAsync()
        }
    }

    private func loadListAsync() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let list = try await repository.fetchReports(
                storeId: storeId,
                from: fromDate,
                to: toDate,
                status: selectedStatus
            )
            self.reports = list
        } catch {
            self.errorMessage = "日報一覧の取得に失敗しました: \(error)"
        }
    }

    // MARK: - 選択

    func select(report: DailyReport?) {
        self.selectedReport = report
    }

    // MARK: - 自動生成（再生成）

    func generate(for date: Date) {
        Task {
            await generateAsync(for: date)
        }
    }

    private func generateAsync(for date: Date) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let report = try await repository.generate(
                storeId: storeId,
                date: date
            )
            self.selectedReport = report

            // 一覧も更新
            let list = try await repository.fetchReports(
                storeId: storeId,
                from: fromDate,
                to: toDate,
                status: selectedStatus
            )
            self.reports = list
        } catch {
            self.errorMessage = "日報の自動作成に失敗しました: \(error)"
        }
    }

    // MARK: - ステータス変更（提出 / 承認 / 差戻し）

    func submitSelected() {
        guard let id = selectedReport?.id else { return }
        Task {
            await changeStatus(id: id, action: repository.submit, label: "提出")
        }
    }

    func approveSelected() {
        guard let id = selectedReport?.id else { return }
        Task {
            await changeStatus(id: id, action: repository.approve, label: "承認")
        }
    }

    func rejectSelected(reason: String) {
        guard let id = selectedReport?.id else { return }
        Task {
            await changeStatusWithReason(
                id: id,
                action: repository.reject,
                label: "差戻し",
                reason: reason
            )
        }
    }

    private func changeStatus(
        id: String,
        action: @escaping (String) async throws -> DailyReport,
        label: String
    ) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await action(id)
            self.selectedReport = updated

            let list = try await repository.fetchReports(
                storeId: storeId,
                from: fromDate,
                to: toDate,
                status: selectedStatus
            )
            self.reports = list
        } catch {
            self.errorMessage = "日報の\(label)に失敗しました: \(error)"
        }
    }

    private func changeStatusWithReason(
        id: String,
        action: @escaping (String, String) async throws -> DailyReport,
        label: String,
        reason: String
    ) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await action(id, reason)
            self.selectedReport = updated

            let list = try await repository.fetchReports(
                storeId: storeId,
                from: fromDate,
                to: toDate,
                status: selectedStatus
            )
            self.reports = list
        } catch {
            self.errorMessage = "日報の\(label)に失敗しました: \(error)"
        }
    }

    // MARK: - CSV出力

    func exportCSV(profileCode: String = "default") {
        Task {
            await exportCSVAsync(profileCode: profileCode)
        }
    }

    private func exportCSVAsync(profileCode: String) async {
        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await repository.exportCSV(
                storeId: storeId,
                from: fromDate,
                to: toDate,
                profileCode: profileCode
            )
            self.exportedCSVURL = url
        } catch {
            self.errorMessage = "CSV出力に失敗しました: \(error)"
        }
    }
}

