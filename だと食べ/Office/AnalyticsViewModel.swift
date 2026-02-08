import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var month: Date
    @Published var fromDate: Date
    @Published var toDate: Date

    @Published var monthlyReport: AnalyticsMonthlyReport?
    @Published var dailyRows: [AnalyticsDailyRow] = []
    @Published var errorMessage: String?
    @Published var isLoadingMonthly: Bool = false
    @Published var isLoadingDaily: Bool = false

    private let storeId: String
    private let repository: AnalyticsRepository

    init(
        storeId: String = "store_1",
        repository: AnalyticsRepository = MockAnalyticsRepository()
    ) {
        self.storeId = storeId
        self.repository = repository

        let today = Calendar.current.startOfDay(for: Date())
        self.month = today
        self.toDate = today
        self.fromDate = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
    }

    func loadMonthly() {
        Task { await loadMonthlyAsync() }
    }

    func loadDaily() {
        Task { await loadDailyAsync() }
    }

    private func loadMonthlyAsync() async {
        isLoadingMonthly = true
        errorMessage = nil
        defer { isLoadingMonthly = false }

        do {
            monthlyReport = try await repository.fetchMonthly(storeId: storeId, month: month)
        } catch {
            errorMessage = "月次データの取得に失敗しました: \(error)"
        }
    }

    private func loadDailyAsync() async {
        isLoadingDaily = true
        errorMessage = nil
        defer { isLoadingDaily = false }

        do {
            dailyRows = try await repository.fetchDaily(storeId: storeId, from: fromDate, to: toDate)
        } catch {
            errorMessage = "日次データの取得に失敗しました: \(error)"
        }
    }
}
