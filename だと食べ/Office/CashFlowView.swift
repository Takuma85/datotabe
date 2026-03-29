import SwiftUI

struct CashFlowView: View {
    @Environment(\.vendorRepository) private var vendorRepository
    @StateObject private var viewModel = CashFlowViewModel()

    @State private var isPresentingForm: Bool = false
    @State private var editingTransaction: CashTransaction?

    var body: some View {
        VStack(spacing: 0) {
            filterArea
            Divider()
            summaryArea
            Divider()
            listArea
        }
        .navigationTitle("入出金")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingTransaction = viewModel.newDraft()
                    isPresentingForm = true
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingForm, onDismiss: {
            editingTransaction = nil
        }) {
            if let tx = editingTransaction {
                NavigationView {
                    CashTransactionFormView(
                        transaction: tx,
                        onSave: { updated in
                            viewModel.save(transaction: updated)
                            isPresentingForm = false
                        },
                        onCancel: {
                            isPresentingForm = false
                        }
                    )
                }
            }
        }
    }

    private var filterArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DatePicker("開始", selection: $viewModel.fromDate, displayedComponents: .date)
                DatePicker("終了", selection: $viewModel.toDate, displayedComponents: .date)
            }

            HStack {
                Picker("入出区分", selection: Binding(
                    get: { viewModel.selectedType },
                    set: { viewModel.selectedType = $0 }
                )) {
                    Text("すべて").tag(CashTransactionType?.none)
                    ForEach(CashTransactionType.allCases) { t in
                        Text(t.label).tag(CashTransactionType?.some(t))
                    }
                }
                .pickerStyle(.menu)

                Picker("カテゴリ", selection: Binding(
                    get: { viewModel.selectedCategory },
                    set: { viewModel.selectedCategory = $0 }
                )) {
                    Text("すべて").tag(CashTransactionCategory?.none)
                    ForEach(CashTransactionCategory.allCases) { c in
                        Text(c.label).tag(CashTransactionCategory?.some(c))
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Button {
                    viewModel.loadList()
                } label: {
                    Label("再読込", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            HStack {
                TextField("金額下限", text: $viewModel.minAmountText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 120)
                Text("〜")
                TextField("金額上限", text: $viewModel.maxAmountText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 120)

                Spacer()

                Button {
                    viewModel.loadList()
                } label: {
                    Label("適用", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var summaryArea: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("入金合計：\(formatCurrency(viewModel.cashInTotal))")
                Text("出金合計：\(formatCurrency(viewModel.cashOutTotal))")
            }
            Spacer()
            Text("差額：\(formatCurrency(viewModel.difference))")
                .fontWeight(.semibold)
                .foregroundColor(viewModel.difference >= 0 ? .blue : .red)
        }
        .padding([.horizontal, .vertical], 12)
    }

    private var listArea: some View {
        List {
            ForEach(viewModel.transactions) { tx in
                Button {
                    editingTransaction = tx
                    isPresentingForm = true
                } label: {
                    transactionRow(tx)
                }
            }
            .onDelete(perform: viewModel.delete)
        }
    }

    private func transactionRow(_ tx: CashTransaction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(tx.date))
                    .font(.headline)
                if let time = tx.time {
                    Text(formatTime(time))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(tx.type.label)
                    .font(.caption)
                    .padding(4)
                    .background(tx.type == .in ? Color.blue.opacity(0.15) : Color.red.opacity(0.15))
                    .cornerRadius(4)
            }

            HStack {
                Text(tx.category?.label ?? "未選択")
                    .font(.subheadline)
                Spacer()
                Text(signedAmount(tx))
                    .fontWeight(.semibold)
                    .foregroundColor(tx.type == .in ? .blue : .red)
            }

            let vendorName = displayVendorName(for: tx)
            if !vendorName.isEmpty {
                Text("相手先：\(vendorName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !tx.description.isEmpty {
                Text("メモ：\(tx.description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func signedAmount(_ tx: CashTransaction) -> String {
        let sign = tx.type == .in ? "+" : "-"
        return "\(sign)\(formatCurrency(tx.amount))"
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func formatCurrency(_ value: Int) -> String {
        let number = NSNumber(value: value)
        return "¥" + (Self.numberFormatter.string(from: number) ?? "\(value)")
    }

    private func displayVendorName(for tx: CashTransaction) -> String {
        if let vendorId = tx.vendorId,
           let vendor = vendorRepository.findById(vendorId) {
            return vendor.name
        }
        return ""
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "HH:mm"
        return df
    }()

    private static let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf
    }()
}

private struct CashTransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.vendorRepository) private var vendorRepository

    @State private var transaction: CashTransaction
    @State private var amountText: String
    @State private var includeTime: Bool
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    let onSave: (CashTransaction) -> Void
    let onCancel: () -> Void

    init(
        transaction: CashTransaction,
        onSave: @escaping (CashTransaction) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _transaction = State(initialValue: transaction)
        _amountText = State(initialValue: transaction.amount == 0 ? "" : String(transaction.amount))
        _includeTime = State(initialValue: transaction.time != nil)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        Form {
            Section(header: Text("基本情報")) {
                DatePicker("日付", selection: $transaction.date, displayedComponents: .date)

                Toggle("時刻を入力", isOn: $includeTime)
                    .onChange(of: includeTime) { _, enabled in
                        if enabled && transaction.time == nil {
                            transaction.time = Date()
                        }
                        if !enabled {
                            transaction.time = nil
                        }
                    }

                if includeTime {
                    DatePicker(
                        "時刻",
                        selection: Binding(
                            get: { transaction.time ?? Date() },
                            set: { transaction.time = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            Section(header: Text("入出金内容")) {
                Picker("入出区分", selection: $transaction.type) {
                    ForEach(CashTransactionType.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                Picker("カテゴリ", selection: Binding(
                    get: { transaction.category },
                    set: { transaction.category = $0 }
                )) {
                    Text("未選択").tag(CashTransactionCategory?.none)
                    ForEach(CashTransactionCategory.allCases) { c in
                        Text(c.label).tag(CashTransactionCategory?.some(c))
                    }
                }

                TextField("金額", text: $amountText)
                    .keyboardType(.numberPad)

                Picker("相手先", selection: Binding(
                    get: { transaction.vendorId ?? "" },
                    set: { transaction.vendorId = $0.isEmpty ? nil : $0 }
                )) {
                    Text("未選択").tag("")
                    ForEach(activeVendors(), id: \.id) { v in
                        Text(v.name).tag(v.id)
                    }
                }

                TextField("メモ（任意）", text: $transaction.description)

                TextField("経費ID（任意）", text: Binding(
                    get: { transaction.expenseId ?? "" },
                    set: { transaction.expenseId = $0.isEmpty ? nil : $0 }
                ))
            }
        }
        .navigationTitle("入出金入力")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") {
                    onCancel()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    save()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("入力エラー"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func save() {
        let amount = Int(amountText.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let amount = amount, amount > 0 else {
            alertMessage = "金額は1円以上の数値で入力してください。"
            showAlert = true
            return
        }

        transaction.amount = amount
        transaction.updatedAt = Date()

        onSave(transaction)
        dismiss()
    }

    private func activeVendors() -> [Vendor] {
        vendorRepository.fetchVendors(
            storeId: "store_1",
            search: nil,
            category: nil,
            isActive: true
        )
    }
}

#Preview {
    NavigationView {
        CashFlowView()
    }
}
