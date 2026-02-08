import SwiftUI

struct ExpenseView: View {
    @Environment(\.vendorRepository) private var vendorRepository
    @EnvironmentObject private var employeeStore: EmployeeStore
    @StateObject private var viewModel: ExpenseViewModel
    @StateObject private var reimbursementViewModel: ExpenseReimbursementViewModel

    @State private var isPresentingForm: Bool = false
    @State private var editingExpense: Expense?
    private let storeId: String = "store_1"

    init() {
        let repository = MockExpenseRepository()
        _viewModel = StateObject(wrappedValue: ExpenseViewModel(repository: repository))
        _reimbursementViewModel = StateObject(wrappedValue: ExpenseReimbursementViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            filterArea
            Divider()
            summaryArea
            Divider()
            listArea
        }
        .navigationTitle("経費・立替")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    let currentUserId = employeeStore.currentEmployee?.name ?? "current_user"
                    editingExpense = viewModel.newDraft(currentUserId: currentUserId)
                    isPresentingForm = true
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingForm, onDismiss: {
            editingExpense = nil
        }) {
            if let expense = editingExpense {
                NavigationView {
                    ExpenseFormView(
                        expense: expense,
                        employees: employeeStore.employees,
                        defaultEmployeeId: employeeStore.currentEmployeeId,
                        storeId: storeId,
                        onSave: { updated in
                            viewModel.save(expense: updated)
                            reimbursementViewModel.showReimbursed = false
                            reimbursementViewModel.loadList()
                            isPresentingForm = false
                        },
                        onCancel: {
                            isPresentingForm = false
                        }
                    )
                }
            }
        }
        .onAppear {
            viewModel.loadList()
            reimbursementViewModel.loadList()
        }
    }

    private var filterArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DatePicker("開始", selection: $viewModel.fromDate, displayedComponents: .date)
                DatePicker("終了", selection: $viewModel.toDate, displayedComponents: .date)
            }

            HStack {
                Picker("カテゴリ", selection: Binding(
                    get: { viewModel.selectedCategory },
                    set: { viewModel.selectedCategory = $0 }
                )) {
                    Text("すべて").tag(ExpenseCategory?.none)
                    ForEach(ExpenseCategory.allCases) { c in
                        Text(c.label).tag(ExpenseCategory?.some(c))
                    }
                }
                .pickerStyle(.menu)

                Picker("支払方法", selection: Binding(
                    get: { viewModel.selectedPaymentMethod },
                    set: { viewModel.selectedPaymentMethod = $0 }
                )) {
                    Text("すべて").tag(ExpensePaymentMethod?.none)
                    ForEach(ExpensePaymentMethod.allCases) { m in
                        Text(m.label).tag(ExpensePaymentMethod?.some(m))
                    }
                }
                .pickerStyle(.menu)

                Picker("精算", selection: Binding(
                    get: { viewModel.selectedReimbursed },
                    set: { viewModel.selectedReimbursed = $0 }
                )) {
                    Text("すべて").tag(Bool?.none)
                    Text("未精算").tag(Bool?.some(false))
                    Text("精算済み").tag(Bool?.some(true))
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
                Picker("ステータス", selection: Binding(
                    get: { viewModel.selectedStatus },
                    set: { viewModel.selectedStatus = $0 }
                )) {
                    Text("すべて").tag(ExpenseStatus?.none)
                    ForEach(ExpenseStatus.allCases) { status in
                        Text(status.label).tag(ExpenseStatus?.some(status))
                    }
                }
                .pickerStyle(.menu)

                Picker("立替者", selection: Binding(
                    get: { viewModel.selectedEmployeeId },
                    set: { viewModel.selectedEmployeeId = $0 }
                )) {
                    Text("すべて").tag(Int?.none)
                    ForEach(employeeStore.employees) { e in
                        Text(e.name).tag(Int?.some(e.id))
                    }
                }
                .pickerStyle(.menu)

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
                Text("経費合計：\(formatCurrency(viewModel.totalAmount))")
                Text("精算済み合計：\(formatCurrency(viewModel.reimbursedTotal))")
            }
            Spacer()
            Text("未精算立替：\(formatCurrency(viewModel.unreimbursedTotal))")
                .fontWeight(.semibold)
                .foregroundColor(.red)
        }
        .padding([.horizontal, .vertical], 12)
    }

    private var listArea: some View {
        List {
            Section("経費一覧") {
                ForEach(viewModel.expenses) { expense in
                    Button {
                        editingExpense = expense
                        isPresentingForm = true
                    } label: {
                        expenseRow(expense)
                    }
                }
                .onDelete(perform: viewModel.delete)
            }

            Section {
                ForEach(reimbursementViewModel.expenses) { expense in
                    reimbursementRow(expense)
                }
            } header: {
                reimbursementHeader
            }
        }
    }

    private var reimbursementHeader: some View {
        HStack {
            Text("立替精算")
                .font(.headline)
            Spacer()
            Picker("表示", selection: $reimbursementViewModel.showReimbursed) {
                Text("未精算").tag(false)
                Text("精算済み").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            .onChange(of: reimbursementViewModel.showReimbursed) { _, _ in
                reimbursementViewModel.loadList()
            }
        }
    }

    private func reimbursementRow(_ expense: Expense) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(expense.date))
                    .font(.headline)
                Text("立替：\(employeeStore.name(for: expense.employeeId ?? 0))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("カテゴリ：\(expense.category.label)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(formatCurrency(expense.amount))
                    .fontWeight(.semibold)
                if expense.isReimbursed {
                    Text("精算済み")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Button("精算") {
                        reimbursementViewModel.markReimbursed(expense: expense)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func expenseRow(_ expense: Expense) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(expense.date))
                    .font(.headline)
                Spacer()
                Text(expense.status.label)
                    .font(.caption)
                    .padding(4)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
            }

            HStack {
                Text(expense.category.label)
                    .font(.subheadline)
                Spacer()
                Text(formatCurrency(expense.amount))
                    .fontWeight(.semibold)
            }

            HStack {
                Text("支払：\(expense.paymentMethod.label)")
                    .font(.caption)
                if let employeeId = expense.employeeId {
                    Text("立替：\(employeeStore.name(for: employeeId))")
                        .font(.caption)
                }
                if expense.isReimbursed {
                    Text("精算済み")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .foregroundColor(.secondary)

            let vendorName = displayVendorName(for: expense)
            if !vendorName.isEmpty {
                Text("取引先：\(vendorName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !expense.memo.isEmpty {
                Text("メモ：\(expense.memo)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatCurrency(_ value: Int) -> String {
        let number = NSNumber(value: value)
        return "¥" + (Self.numberFormatter.string(from: number) ?? "\(value)")
    }

    private func displayVendorName(for expense: Expense) -> String {
        if let vendorId = expense.vendorId,
           let vendor = vendorRepository.findById(vendorId) {
            return vendor.name
        }
        return expense.vendorNameRaw ?? ""
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private static let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf
    }()
}

private struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.vendorRepository) private var vendorRepository

    @State private var expense: Expense
    @State private var amountText: String
    @State private var taxText: String
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var vendorInputMode: VendorInputMode
    @State private var vendorSearchText: String = ""

    let employees: [Employee]
    let defaultEmployeeId: Int
    let storeId: String
    let onSave: (Expense) -> Void
    let onCancel: () -> Void

    init(
        expense: Expense,
        employees: [Employee],
        defaultEmployeeId: Int,
        storeId: String,
        onSave: @escaping (Expense) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _expense = State(initialValue: expense)
        _amountText = State(initialValue: expense.amount == 0 ? "" : String(expense.amount))
        _taxText = State(initialValue: expense.taxAmount == 0 ? "" : String(expense.taxAmount))
        _vendorInputMode = State(initialValue: expense.vendorId == nil ? .manual : .select)
        self.employees = employees
        self.defaultEmployeeId = defaultEmployeeId
        self.storeId = storeId
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        Form {
            Section(header: Text("基本情報")) {
                DatePicker("日付", selection: $expense.date, displayedComponents: .date)

                TextField("金額", text: $amountText)
                    .keyboardType(.numberPad)

                TextField("税額（任意）", text: $taxText)
                    .keyboardType(.numberPad)

                Picker("カテゴリ", selection: $expense.category) {
                    ForEach(ExpenseCategory.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }

                TextField("サブカテゴリ（任意）", text: Binding(
                    get: { expense.subCategory ?? "" },
                    set: { expense.subCategory = $0.isEmpty ? nil : $0 }
                ))
            }

            Section(header: Text("支払い")) {
                Picker("支払方法", selection: $expense.paymentMethod) {
                    ForEach(ExpensePaymentMethod.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                if expense.paymentMethod == .employeeAdvance {
                    Picker("従業員", selection: Binding(
                        get: { expense.employeeId ?? employees.first?.id },
                        set: { expense.employeeId = $0 }
                    )) {
                        ForEach(employees) { e in
                            Text(e.name).tag(Optional(e.id))
                        }
                    }
                }
            }

            Section(header: Text("取引先・メモ")) {
                Picker("入力方法", selection: $vendorInputMode) {
                    Text("選択").tag(VendorInputMode.select)
                    Text("手入力").tag(VendorInputMode.manual)
                }
                .pickerStyle(.segmented)

                if vendorInputMode == .select {
                    TextField("検索", text: $vendorSearchText)
                        .textFieldStyle(.roundedBorder)

                    Picker("取引先", selection: Binding(
                        get: { expense.vendorId ?? "" },
                        set: { newValue in
                            expense.vendorId = newValue.isEmpty ? nil : newValue
                            if expense.vendorId != nil {
                                expense.vendorNameRaw = nil
                            }
                        }
                    )) {
                        Text("未選択").tag("")
                        ForEach(activeVendors(), id: \.id) { v in
                            Text(v.name).tag(v.id)
                        }
                    }
                } else {
                    TextField("取引先（手入力）", text: Binding(
                        get: { expense.vendorNameRaw ?? "" },
                        set: { newValue in
                            expense.vendorNameRaw = newValue.isEmpty ? nil : newValue
                            if expense.vendorNameRaw != nil {
                                expense.vendorId = nil
                            }
                        }
                    ))
                }

                TextField("メモ（任意）", text: $expense.memo)
            }

            Section(header: Text("ステータス")) {
                Picker("ステータス", selection: $expense.status) {
                    ForEach(ExpenseStatus.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
            }
        }
        .navigationTitle("経費入力")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") { onCancel() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") { save() }
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

        let tax = Int(taxText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        expense.amount = amount
        expense.taxAmount = tax
        expense.updatedAt = Date()

        if expense.paymentMethod != .employeeAdvance {
            expense.employeeId = nil
            expense.isReimbursed = false
            expense.reimbursedAt = nil
            expense.reimbursementCashTransactionId = nil
        } else if expense.isReimbursed == false {
            if expense.employeeId == nil {
                expense.employeeId = defaultEmployeeId
            }
            if expense.status == .approved {
                expense.isReimbursed = false
            }
            expense.reimbursedAt = nil
            expense.reimbursementCashTransactionId = nil
        }

        onSave(expense)
        dismiss()
    }

    private func activeVendors() -> [Vendor] {
        vendorRepository.fetchVendors(
            storeId: storeId,
            search: vendorSearchText,
            category: nil,
            isActive: true
        )
    }
}

private enum VendorInputMode: String {
    case select
    case manual
}

#Preview {
    NavigationView {
        ExpenseView()
            .environmentObject(EmployeeStore())
    }
}
