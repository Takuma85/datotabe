import SwiftUI

@main
struct DadtoTabeApp: App {
    // ✅ 従業員マスタ（全画面で共有する）
    @StateObject private var employeeStore = EmployeeStore()
        private let timeRecordRepository = UserDefaultsTimeRecordRepository()//将来 DB に変えたいときは、この1行だけ変えればOK：private let timeRecordRepository = DbTimeRecordRepository(/* 接続情報など */)

        var body: some Scene {
            WindowGroup {
                MainTabView()
                    .environmentObject(employeeStore)
                    .environment(\.timeRecordRepository, timeRecordRepository)
            }
        }
}
