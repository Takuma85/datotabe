import SwiftUI

struct DailyClosingView: View {

    @StateObject private var viewModel = DailyClosingViewModel()

    // 券種ごとのTextFieldで使う文字列状態
    @State private var denominationTexts: [CashDenomination: String] = [:]

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

                HStack {
                    Text("締め確定者")
                    Spacer()
                    Text(viewModel.closing.confirmedBy ?? "未確定")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("締め確定日時")
                    Spacer()
                    Text(
                        viewModel.closing.confirmedAt.map(Self.dateTimeFormatter.string(from:))
                        ?? "未確定"
                    )
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
                ForEach(CashDenomination.allCases.filter { $0.isBill }) { denomination in
                    denominationInputRow(for: denomination)
                }

                ForEach(CashDenomination.allCases.filter { !$0.isBill }) { denomination in
                    denominationInputRow(for: denomination)
                }

                HStack {
                    Text("現金合計")
                    Spacer()
                    Text("¥\(viewModel.closing.actualCashBalance)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("差額")
                    Spacer()
                    Text(viewModel.differenceLabelText)
                        .foregroundColor(colorForDifference(viewModel.closing.difference))
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("課題フラグ")
                    Spacer()
                    Text(viewModel.closing.issueFlag ? "要確認" : "問題なし")
                        .foregroundColor(viewModel.closing.issueFlag ? .red : .secondary)
                        .fontWeight(viewModel.closing.issueFlag ? .semibold : .regular)
                }

                if viewModel.closing.issueFlag {
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
            syncDenominationTextsFromModel()
        }
        .onChange(of: viewModel.closing.date) { _, _ in
            // 日付が変わったら、その日付のデータをモックから再読み込み
            viewModel.recalculateFromServerMock()
            syncDenominationTextsFromModel()
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

    private func denominationInputRow(for denomination: CashDenomination) -> some View {
        HStack {
            Text("\(denomination.label) (\(denomination.categoryLabel))")
            Spacer()
            TextField("0", text: denominationBinding(for: denomination))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text("枚")
                .foregroundColor(.secondary)
            Text("¥\(viewModel.subtotal(for: denomination))")
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func denominationBinding(for denomination: CashDenomination) -> Binding<String> {
        Binding(
            get: { denominationTexts[denomination] ?? "" },
            set: { newValue in
                denominationTexts[denomination] = newValue
                viewModel.updateCount(for: denomination, from: newValue)
            }
        )
    }

    private func syncDenominationTextsFromModel() {
        var synced: [CashDenomination: String] = [:]
        for denomination in CashDenomination.allCases {
            let count = viewModel.count(for: denomination)
            synced[denomination] = count == 0 ? "" : String(count)
        }
        denominationTexts = synced
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

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationView {
        DailyClosingView()
    }
}
