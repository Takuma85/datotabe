import SwiftUI

struct DailyClosingView: View {

    @StateObject private var viewModel = DailyClosingViewModel()

    // TextField で使うための文字列状態
    @State private var actualCashText: String = ""

    // 簡易アラート表示用
    @State private var showAlert: Bool = false
    
    init(viewModel: DailyClosingViewModel = DailyClosingViewModel()) {
            _viewModel = StateObject(wrappedValue: viewModel)
        }

    var body: some View {
        Form {
            // 基本情報
            Section(header: Text("基本情報")) {
                HStack {
                    Text("店舗")
                    Spacer()
                    Text(viewModel.closing.storeName)
                        .foregroundColor(.secondary)
                }

                DatePicker(
                        "日付",
                        selection: Binding(
                            get: { viewModel.closing.date },
                            set: { viewModel.closing.date = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)

                HStack {
                    Text("ステータス")
                    Spacer()
                    Text(viewModel.statusText)
                        .foregroundColor(.secondary)
                }
            }

            // 理論値の計算サマリ
            Section(header: Text("理論残高の計算")) {
                closingRow(label: "前日繰越", value: viewModel.closing.previousCashBalance)
                closingRow(label: "当日 現金売上", value: viewModel.closing.cashSales)
                closingRow(label: "入金合計", value: viewModel.closing.cashInTotal)
                closingRow(label: "出金合計", value: viewModel.closing.cashOutTotal)

                HStack {
                    Text("理論残高")
                    Spacer()
                    Text("¥\(viewModel.closing.expectedCashBalance)")
                        .fontWeight(.semibold)
                }
            }

            // 実残高入力
            Section(header: Text("実際のレジ内現金")) {
                TextField("レジ内の現金残高を入力", text: $actualCashText)
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.closing.date) { newDate in
                                // 日付が変わったら、その日付のデータをモックから再読み込み
                                viewModel.recalculateFromServerMock()
                            }

                HStack {
                    Text("差額")
                    Spacer()
                    Text(viewModel.differenceLabelText)
                        .foregroundColor(colorForDifference(viewModel.closing.difference))
                        .fontWeight(.semibold)
                }

                if viewModel.closing.hasIssue {
                    Text("※ 差額が大きいため、入出金や売上データを確認してください。")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            // メモ
            Section(header: Text("メモ")) {
                TextEditor(text: Binding(
                    get: { viewModel.closing.note },
                    set: { viewModel.closing.note = $0 }
                ))
                .frame(minHeight: 80)
            }
        }
        .navigationTitle("レジ締め")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("再計算") {
                    viewModel.recalculateFromServerMock()
                    showAlertIfNeeded()
                }
                Button("締め確定") {
                    viewModel.confirmClosing()
                    showAlertIfNeeded()
                }
            }
        }
        .onAppear {
            // 初回表示時に実残高テキストをモデルの値から同期
            actualCashText = viewModel.closing.actualCashBalance == 0
            ? ""
            : String(viewModel.closing.actualCashBalance)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("レジ締め"),
                message: Text(viewModel.toastMessage ?? ""),
                dismissButton: .default(Text("OK"), action: {
                    viewModel.toastMessage = nil
                })
            )
        }
    }

    // MARK: - Helper Views / Functions

    private func closingRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("¥\(value)")
                .foregroundColor(.secondary)
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private func colorForDifference(_ diff: Int) -> Color {
        if diff == 0 {
            return .primary
        } else if diff > 0 {
            return .blue
        } else {
            return .red
        }
    }
    private func showAlertIfNeeded() {
            if viewModel.toastMessage != nil {
                showAlert = true
            }
        }
}

#Preview {
    NavigationView {
        DailyClosingView()
    }
}
