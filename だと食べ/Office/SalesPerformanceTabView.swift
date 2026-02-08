import SwiftUI

struct SalesPerformanceTabView: View {
    var body: some View {
        List {
            Section("営業成績") {
                NavigationLink("日報", destination: DailyReportView())
                NavigationLink("月次日別CSV出力", destination: MonthlyDailyCSVView())
                NavigationLink("勤怠 月次CSV出力", destination: MonthlyAttendanceCSVView())
                NavigationLink("月次サマリ", destination: MonthlySummaryCSVView())
            }
        }
        .navigationTitle("営業成績")
    }
}

#Preview {
    NavigationStack {
        SalesPerformanceTabView()
    }
}
