import SwiftUI

@main
struct DadtoTabeApp: App {
    @StateObject private var employeeStore = EmployeeStore()
    private let timeRecordRepository = UserDefaultsTimeRecordRepository()
    private let appSettingsRepository = UserDefaultsAppSettingsRepository()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(employeeStore)
                .environment(\.timeRecordRepository, timeRecordRepository)
                .environment(\.appSettingsRepository, appSettingsRepository)
        }
    }
}
