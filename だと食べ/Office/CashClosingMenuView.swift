import SwiftUI

struct CashClosingMenuView: View {
    var body: some View {
        List {
            Section("レジ締め") {
                NavigationLink("レジ締め（今日）", destination: DailyClosingView())
                NavigationLink("レジ締め一覧", destination: DailyClosingListView())
            }
        }
        .navigationTitle("レジ締め")
    }
}

#Preview {
    NavigationStack {
        CashClosingMenuView()
    }
}
