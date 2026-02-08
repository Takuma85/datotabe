import Foundation

@MainActor
final class CostCalcViewModel: ObservableObject {
    @Published var month: Date
    @Published var fromDate: Date
    @Published var toDate: Date

    @Published var settings: [CostCategorySetting] = []
    @Published var monthlyReport: AnalyticsMonthlyReport?
    @Published var dailyRows: [AnalyticsDailyRow] = []
    @Published var errorMessage: String?

    private let storeId: String
    private let analyticsRepository: AnalyticsRepository
    private let settingsRepository: CostCategorySettingsRepository

    init(
        storeId: String = "store_1",
        analyticsRepository: AnalyticsRepository = MockAnalyticsRepository(),
        settingsRepository: CostCategorySettingsRepository = UserDefaultsCostCategorySettingsRepository()
    ) {
        self.storeId = storeId
        self.analyticsRepository = analyticsRepository
        self.settingsRepository = settingsRepository

        let today = Calendar.current.startOfDay(for: Date())
        self.month = today
        self.toDate = today
        self.fromDate = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today

        loadSettings()
    }

    func loadSettings() {
        settings = settingsRepository.loadSettings(storeId: storeId)
    }

    func saveSettings() {
        settingsRepository.saveSettings(storeId: storeId, settings: settings)
    }

    func loadMonthly() {
        Task { await loadMonthlyAsync() }
    }

    func loadDaily() {
        Task { await loadDailyAsync() }
    }

    private func loadMonthlyAsync() async {
        errorMessage = nil
        do {
            monthlyReport = try await analyticsRepository.fetchMonthly(storeId: storeId, month: month)
        } catch {
            errorMessage = "月次原価の取得に失敗しました: \(error)"
        }
    }

    private func loadDailyAsync() async {
        errorMessage = nil
        do {
            dailyRows = try await analyticsRepository.fetchDaily(storeId: storeId, from: fromDate, to: toDate)
        } catch {
            errorMessage = "日次原価の取得に失敗しました: \(error)"
        }
    }
}
