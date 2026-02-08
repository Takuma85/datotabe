import SwiftUI

struct OfficeMenuView: View {
    var body: some View {
        List {
            Section("事務") {
                NavigationLink("営業成績", destination: SalesPerformanceTabView())
                NavigationLink("分析", destination: AnalyticsView())
                NavigationLink("入出金", destination: CashFlowView())
                NavigationLink("経費・立替", destination: ExpenseView())
                NavigationLink("伝票明細", destination: SlipDetailView())
                NavigationLink("打刻管理", destination: TimecardView())
                NavigationLink("打刻一覧（店長）", destination: TimecardManagerView())
                NavigationLink("原価計算", destination: CostCalcView())
                NavigationLink("レジ締め", destination: CashClosingMenuView())
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
