import SwiftUI

struct DailyClosingListView: View {
    
    // モックのリポジトリを使う
    private let repository = MockDailyClosingRepository()

    // とりあえず「直近7日ぶん」のダミー日付リスト
    private let dates: [Date] = {
        let calendar = Calendar.current
        let today = Date()
        // 0: 今日, 1: 昨日, ... という感じで7日分
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }()

    var body: some View {
        List(dates, id: \.self) { date in
            // 🟡 ここで DailyClosing をモックから取得
            if let closing = repository.loadClosing(storeId: "store_1", date: date) {
                NavigationLink {
                    DailyClosingView(
                        viewModel: DailyClosingViewModel(
                            storeId: "store_1",
                            date: date
                        )
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        // 日付
                        Text(dateString(date))
                            .font(.headline)
                        
                        // 店舗名
                        Text(closing.storeName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // 理論残高
                        HStack {
                            Text("理論残高")
                                .font(.caption2)
                            Spacer()
                            Text("¥\(closing.expectedCashBalance)")
                                .font(.caption2)
                                .bold()
                        }
                        
                        // ステータス + 問題ありアイコン
                        HStack {
                            Text("ステータス")
                                .font(.caption2)
                            Spacer()
                            Text(closing.status.label)
                                .font(.caption2)
                                .foregroundColor(
                                    closing.status == .confirmed ? .green :
                                        closing.status == .draft ? .orange :
                                            .blue
                                )
                            if closing.hasIssue {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("レジ締め一覧")
    }

    // MARK: - Helpers

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd (EEE)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        DailyClosingListView()
    }
}

