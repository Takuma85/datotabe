import SwiftUI

struct OfficeMenuView: View {
    var body: some View {
        List {
            Section("事務") {
                NavigationLink("日報", destination: DailyReportView())
                NavigationLink("分析", destination: AnalyticsView())
                NavigationLink("入出金", destination: CashFlowView())
                NavigationLink("伝票明細", destination: SlipDetailView())
                NavigationLink("打刻管理", destination: TimecardView())
                NavigationLink("原価計算", destination: CostCalcView())
            }
        }
        .navigationTitle("事務")
    }
}

#Preview {
    NavigationStack {
        OfficeMenuView()
    }
}
