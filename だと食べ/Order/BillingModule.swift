import Foundation
import SwiftUI

// MARK: - Models

struct OrderItem: Identifiable, Hashable {
    let id: String
    var name: String
    var unitPrice: Int
    var quantity: Int

    var lineTotal: Int {
        unitPrice * quantity
    }
}

enum PayMethod: String, CaseIterable, Identifiable, Hashable {
    case cash = "現金"
    case card = "クレジットカード"
    case emoney = "電子マネー"

    var id: String { rawValue }
}

struct PaymentRecord: Identifiable, Hashable {
    let id: String
    var amount: Int
    var method: PayMethod
    var subtype: String?
    var itemIds: [String]?
    var createdAt: Date
}

struct StageReceipt: Hashable {
    var payment: PaymentRecord
    var change: Int
}

struct SettlementResult: Hashable {
    var tableId: String
    var businessDate: Date
    var totalAmount: Int
    var payments: [PaymentRecord]
    var people: Int
}

// MARK: - ViewModel

@MainActor
final class BillingViewModel: ObservableObject {
    let tableId: String
    let people: Int

    private let initialItems: [OrderItem]

    @Published var items: [OrderItem]
    @Published var payments: [PaymentRecord] = []
    @Published var selectedItemIds: Set<String> = []

    @Published var singleItemMode: Bool = true
    @Published var method: PayMethod = .cash
    @Published var subtype: String? = nil
    @Published var customSubtype: String = ""

    @Published var inputValue: String = ""
    @Published var lastStage: StageReceipt? = nil
    @Published var isAllDone: Bool = false
    @Published var toast: String = ""

    init(tableId: String, people: Int, items: [OrderItem]) {
        self.tableId = tableId
        self.people = people
        self.items = items
        self.initialItems = items
    }

    // MARK: - Derived values

    var totalAmount: Int {
        items.reduce(0) { $0 + $1.lineTotal }
    }

    var initialTotalAmount: Int {
        initialItems.reduce(0) { $0 + $1.lineTotal }
    }

    var paidOverall: Int {
        payments
            .filter { $0.itemIds == nil || $0.itemIds?.isEmpty == true }
            .reduce(0) { $0 + $1.amount }
    }

    var remainingOverall: Int {
        max(totalAmount - paidOverall, 0)
    }

    var selectedTotal: Int {
        items
            .filter { selectedItemIds.contains($0.id) }
            .reduce(0) { $0 + $1.lineTotal }
    }

    var selectedPaid: Int {
        payments
            .filter { payment in
                guard let ids = payment.itemIds else { return false }
                return ids.contains { selectedItemIds.contains($0) }
            }
            .reduce(0) { $0 + $1.amount }
    }

    var remainingSelected: Int {
        max(selectedTotal - selectedPaid, 0)
    }

    var isSplitMode: Bool {
        !selectedItemIds.isEmpty
    }

    var targetRemaining: Int {
        isSplitMode ? remainingSelected : remainingOverall
    }

    var currentInput: Int {
        Int(inputValue) ?? 0
    }

    var isPartial: Bool {
        currentInput > 0 && currentInput < targetRemaining
    }

    var canCommit: Bool {
        currentInput > 0 && !(singleItemMode && selectedItemIds.isEmpty && !items.isEmpty)
    }

    var subtypeCandidates: [String] {
        switch method {
        case .cash:
            return []
        case .card:
            return [
                "VISA", "MasterCard", "JCB", "American Express",
                "Diners", "銀聯", "Discover", "デビット", "その他"
            ]
        case .emoney:
            return [
                "交通系IC", "iD", "QUICPay", "楽天Edy", "WAON",
                "nanaco", "PayPay", "楽天ペイ", "d払い",
                "au PAY", "メルペイ", "WeChat Pay", "Alipay", "その他"
            ]
        }
    }

    // MARK: - Actions

    func toggleSelection(for item: OrderItem) {
        if singleItemMode {
            if selectedItemIds.contains(item.id) {
                selectedItemIds.removeAll()
            } else {
                selectedItemIds = [item.id]
            }
        } else {
            if selectedItemIds.contains(item.id) {
                selectedItemIds.remove(item.id)
            } else {
                selectedItemIds.insert(item.id)
            }
        }
    }

    func addAmount(_ amount: Int) {
        let current = Int(inputValue) ?? 0
        inputValue = String(current + amount)
    }

    func fillTarget() {
        inputValue = String(targetRemaining)
    }

    func backspace() {
        guard !inputValue.isEmpty else { return }
        inputValue.removeLast()
    }

    func clearInput() {
        inputValue = ""
    }

    func resetMethodSubtypeIfNeeded() {
        subtype = nil
        customSubtype = ""
    }

    func resolvedSubtype() -> String? {
        switch method {
        case .cash:
            return nil
        case .card, .emoney:
            if subtype == "その他" {
                let trimmed = customSubtype.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "その他" : trimmed
            }
            return subtype
        }
    }

    func commitPayment() {
        let input = currentInput
        let target = targetRemaining
        guard canCommit, input > 0 else { return }

        let change = max(input - target, 0)

        let payment = PaymentRecord(
            id: UUID().uuidString,
            amount: input,
            method: method,
            subtype: resolvedSubtype(),
            itemIds: isSplitMode ? Array(selectedItemIds).sorted() : nil,
            createdAt: Date()
        )

        let nextPayments = payments + [payment]
        apply(payments: nextPayments, lastCommittedPaymentID: payment.id, lastChange: change)
    }

    func cancelPayment(id: String) {
        let nextPayments = payments.filter { $0.id != id }
        apply(payments: nextPayments, lastCommittedPaymentID: nil, lastChange: 0)
        showToast("受領を取り消しました")
    }

    func cancelLastPayment() {
        guard let last = payments.last else { return }
        cancelPayment(id: last.id)
    }

    func settlementResult() -> SettlementResult {
        SettlementResult(
            tableId: tableId,
            businessDate: Date(),
            totalAmount: initialTotalAmount,
            payments: payments,
            people: people
        )
    }

    func resetAllForDemo() {
        items = initialItems
        payments = []
        selectedItemIds = []
        singleItemMode = true
        method = .cash
        subtype = nil
        customSubtype = ""
        inputValue = ""
        lastStage = nil
        isAllDone = false
        toast = ""
    }

    private func apply(payments nextPayments: [PaymentRecord], lastCommittedPaymentID: String?, lastChange: Int) {
        var remainingItems = initialItems
        var lastStageReceipt: StageReceipt?
        var done = false

        for payment in nextPayments {
            let isSplit = !(payment.itemIds?.isEmpty ?? true)

            if isSplit, let ids = payment.itemIds {
                let selectedIds = Set(ids)
                let selectedTotal = remainingItems
                    .filter { selectedIds.contains($0.id) }
                    .reduce(0) { $0 + $1.lineTotal }

                let selectedPaid = nextPayments
                    .filter { record in
                        guard let itemIds = record.itemIds else { return false }
                        return itemIds.contains { selectedIds.contains($0) }
                    }
                    .reduce(0) { $0 + $1.amount }

                if selectedTotal > 0 && selectedPaid >= selectedTotal {
                    remainingItems.removeAll { selectedIds.contains($0.id) }
                }
            }

            let paidOverall = nextPayments
                .filter { $0.itemIds == nil || $0.itemIds?.isEmpty == true }
                .reduce(0) { $0 + $1.amount }

            let remainingOverall = max(remainingItems.reduce(0) { $0 + $1.lineTotal } - paidOverall, 0)
            if remainingItems.isEmpty && remainingOverall <= 0 {
                done = true
                if payment.id == lastCommittedPaymentID {
                    lastStageReceipt = StageReceipt(payment: payment, change: lastChange)
                }
            }
        }

        if let lastCommittedPaymentID,
           let payment = nextPayments.last(where: { $0.id == lastCommittedPaymentID }),
           lastStageReceipt == nil {
            let isSplit = !(payment.itemIds?.isEmpty ?? true)
            let stageFullyDone: Bool

            if isSplit, let ids = payment.itemIds {
                let selectedIds = Set(ids)
                let selectedTotal = initialItems
                    .filter { selectedIds.contains($0.id) }
                    .reduce(0) { $0 + $1.lineTotal }
                let selectedPaid = nextPayments
                    .filter { record in
                        guard let itemIds = record.itemIds else { return false }
                        return itemIds.contains { selectedIds.contains($0) }
                    }
                    .reduce(0) { $0 + $1.amount }
                stageFullyDone = selectedTotal > 0 && selectedPaid >= selectedTotal
            } else {
                let remainingOverall = max(remainingItems.reduce(0) { $0 + $1.lineTotal }
                    - nextPayments
                        .filter { $0.itemIds == nil || $0.itemIds?.isEmpty == true }
                        .reduce(0) { $0 + $1.amount }, 0)
                stageFullyDone = remainingOverall <= 0
            }

            if stageFullyDone {
                lastStageReceipt = StageReceipt(payment: payment, change: lastChange)
            } else {
                showToast("受領を追加しました")
            }
        }

        items = remainingItems
        payments = nextPayments
        lastStage = lastStageReceipt
        isAllDone = done
        inputValue = ""
        if !done && lastStageReceipt == nil {
            selectedItemIds.removeAll()
        } else if done {
            selectedItemIds.removeAll()
        }
    }

    private func showToast(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            guard let self else { return }
            if self.toast == message {
                self.toast = ""
            }
        }
    }
}

// MARK: - Main Billing View

struct BillingView: View {
    @StateObject var viewModel: BillingViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var onClose: (() -> Void)? = nil
    var onCompleted: ((SettlementResult) -> Void)? = nil

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        Group {
            if let stage = viewModel.lastStage, viewModel.isAllDone {
                OverallDoneView(
                    tableId: viewModel.tableId,
                    people: viewModel.people,
                    stage: stage,
                    onCancelLast: {
                        viewModel.cancelLastPayment()
                    },
                    onFinish: {
                        onCompleted?(viewModel.settlementResult())
                        onClose?()
                    }
                )
            } else if let stage = viewModel.lastStage {
                StageDoneView(
                    stage: stage,
                    onCancelLast: {
                        viewModel.cancelLastPayment()
                    },
                    onNext: {
                        viewModel.lastStage = nil
                    }
                )
            } else {
                billingMainView
            }
        }
        .onChange(of: viewModel.method) { _, _ in
            viewModel.resetMethodSubtypeIfNeeded()
        }
    }

    private var billingMainView: some View {
        Group {
            if isCompactLayout {
                ScrollView {
                    billingContent
                }
            } else {
                billingContent
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var billingContent: some View {
        VStack(alignment: .leading, spacing: isCompactLayout ? 12 : 16) {
            HStack {
                Text("会計（テーブル \(viewModel.tableId) / \(viewModel.people)名）")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                if let onClose {
                    Button("閉じる") { onClose() }
                        .buttonStyle(.bordered)
                }
            }

            if isCompactLayout {
                rightPanel(isCompact: true)
                leftPanel(isCompact: true)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    leftPanel(isCompact: false)
                    rightPanel(isCompact: false)
                }
            }

            toastView
        }
        .padding(isCompactLayout ? 12 : 16)
    }

    @ViewBuilder
    private var toastView: some View {
        if !viewModel.toast.isEmpty {
            HStack {
                Spacer()
                Text(viewModel.toast)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var orderItemsList: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.items) { item in
                let selected = viewModel.selectedItemIds.contains(item.id)
                HStack(spacing: 10) {
                    Button {
                        viewModel.toggleSelection(for: item)
                    } label: {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected ? .blue : .gray)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        Text("¥\(item.unitPrice) × \(item.quantity)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(formatYen(item.lineTotal))
                        .fontWeight(.medium)
                }
                .padding(10)
                .background(selected ? Color.blue.opacity(0.08) : Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? Color.blue : Color.clear, lineWidth: 1)
                )
                .cornerRadius(12)
            }

            if viewModel.items.isEmpty {
                Text("すべて精算済み")
                    .foregroundColor(.secondary)
                    .padding(.top, 12)
            }
        }
    }

    private func leftPanel(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支払い方法")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(PayMethod.allCases) { method in
                    Button {
                        viewModel.method = method
                    } label: {
                        Text(method.rawValue)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MethodChipStyle(isSelected: viewModel.method == method))
                }
            }

            if viewModel.method != .cash {
                VStack(alignment: .leading, spacing: 8) {
                    Text("具体的な手段")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(viewModel.subtypeCandidates, id: \.self) { subtype in
                            Button {
                                viewModel.subtype = subtype
                            } label: {
                                Text(subtype)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MethodChipStyle(isSelected: viewModel.subtype == subtype))
                        }
                    }

                    if viewModel.subtype == "その他" {
                        TextField("自由入力", text: $viewModel.customSubtype)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Divider()

            HStack {
                Text("注文品目（分割したい品にチェック）")
                    .font(.subheadline)
                Spacer()
                Text("選択中：\(viewModel.selectedItemIds.count)品")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isCompact {
                orderItemsList
            } else {
                ScrollView {
                    orderItemsList
                }
            }

            Divider()

            KeyValueRow(label: "合計", value: formatYen(viewModel.totalAmount))
            KeyValueRow(label: "受領合計", value: formatYen(viewModel.paidOverall))
            KeyValueRow(label: "残額", value: formatYen(viewModel.remainingOverall))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
    }

    private func rightPanel(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            KeyValueRow(label: "ターゲット残額", value: formatYen(viewModel.targetRemaining))

            if viewModel.singleItemMode && viewModel.selectedItemIds.isEmpty && !viewModel.items.isEmpty {
                Text("※ 個別精算モード中です。品目を1つ選択してください。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isCompact {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    Button("¥1,000") { viewModel.addAmount(1000) }
                        .buttonStyle(ShortcutButtonStyle())
                    Button("¥5,000") { viewModel.addAmount(5000) }
                        .buttonStyle(ShortcutButtonStyle())
                    Button("¥10,000") { viewModel.addAmount(10000) }
                        .buttonStyle(ShortcutButtonStyle())
                    Button("残額") { viewModel.fillTarget() }
                        .buttonStyle(OutlineShortcutButtonStyle())
                }
            } else {
                HStack(spacing: 8) {
                    Button("¥1,000") { viewModel.addAmount(1000) }
                        .buttonStyle(ShortcutButtonStyle())
                    Button("¥5,000") { viewModel.addAmount(5000) }
                        .buttonStyle(ShortcutButtonStyle())
                    Button("¥10,000") { viewModel.addAmount(10000) }
                        .buttonStyle(ShortcutButtonStyle())
                    Button("残額") { viewModel.fillTarget() }
                        .buttonStyle(OutlineShortcutButtonStyle())
                }
            }

            KeypadView(
                value: $viewModel.inputValue,
                onBackspace: { viewModel.backspace() },
                onClear: { viewModel.clearInput() }
            )

            Toggle(isOn: $viewModel.singleItemMode) {
                Text("個別精算モード（1品ずつ）")
                    .font(.footnote)
            }

            Divider()

            Text("受領一覧")
                .font(.subheadline)

            if viewModel.payments.isEmpty {
                Text("受領がありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.payments) { payment in
                            ReceiptRowView(
                                payment: payment,
                                onCancel: { viewModel.cancelPayment(id: payment.id) }
                            )
                        }
                    }
                }
                .frame(maxHeight: isCompact ? 180 : 220)
            }

            if !isCompact {
                Spacer()
            }

            Button {
                viewModel.commitPayment()
            } label: {
                Text(viewModel.isPartial ? "続けて入力" : "決済確定")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(CommitButtonStyle(isEnabled: viewModel.canCommit, isPartial: viewModel.isPartial))
            .disabled(!viewModel.canCommit)
        }
        .padding()
        .frame(maxWidth: isCompact ? .infinity : 360, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Stage Done / Overall Done

struct StageDoneView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let stage: StageReceipt
    let onCancelLast: () -> Void
    let onNext: () -> Void

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("会計完了（このステージ）")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StageBadge(text: paymentLabel(stage.payment))
                    Spacer()
                    Text(formatYen(stage.payment.amount))
                        .font(.title3)
                        .fontWeight(.bold)
                }

                if stage.change > 0 {
                    Text("お釣り：\(formatYen(stage.change))")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Text("お釣り：¥0")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)

            if isCompactLayout {
                VStack(spacing: 10) {
                    Button("次の会計へ進む", action: onNext)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    Button("直前の受領を取り消す", action: onCancelLast)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    Button("直前の受領を取り消す", action: onCancelLast)
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("次の会計へ進む", action: onNext)
                        .buttonStyle(.borderedProminent)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

struct OverallDoneView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let tableId: String
    let people: Int
    let stage: StageReceipt
    let onCancelLast: () -> Void
    let onFinish: () -> Void

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("会計全体完了")
                .font(.title2)
                .fontWeight(.bold)

            Text("テーブル \(tableId) / \(people)名")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StageBadge(text: paymentLabel(stage.payment))
                    Spacer()
                    Text(formatYen(stage.payment.amount))
                        .font(.title3)
                        .fontWeight(.bold)
                }

                if stage.change > 0 {
                    Text("お釣り：\(formatYen(stage.change))")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Text("お釣り：¥0")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)

            if isCompactLayout {
                VStack(spacing: 10) {
                    Button("完了", action: onFinish)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    Button("直前の受領を取り消す", action: onCancelLast)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    Button("直前の受領を取り消す", action: onCancelLast)
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("完了", action: onFinish)
                        .buttonStyle(.borderedProminent)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Small Views

struct ReceiptRowView: View {
    let payment: PaymentRecord
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                StageBadge(text: paymentLabel(payment))
                if let ids = payment.itemIds, !ids.isEmpty {
                    Text("分割 \(ids.count) 品")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("全体")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(formatYen(payment.amount))
                .fontWeight(.medium)

            Button("取消", action: onCancel)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).fontWeight(.bold)
        }
        .font(.subheadline)
    }
}

struct StageBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(999)
    }
}

struct KeypadView: View {
    @Binding var value: String
    let onBackspace: () -> Void
    let onClear: () -> Void

    private let keys = ["7", "8", "9", "4", "5", "6", "1", "2", "3", "0", "00", "⌫"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("入力中：")
                Text(formatYen(Int(value) ?? 0))
                    .fontWeight(.bold)
            }
            .font(.subheadline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(keys, id: \.self) { key in
                    Button {
                        if key == "⌫" {
                            onBackspace()
                        } else {
                            value.append(contentsOf: key)
                        }
                    } label: {
                        Text(key)
                            .font(.title3)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("クリア", action: onClear)
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - Helpers

func paymentLabel(_ payment: PaymentRecord) -> String {
    let base = payment.method.rawValue
    if let subtype = payment.subtype, !subtype.isEmpty {
        return "\(base) / \(subtype)"
    }
    return base
}

func formatYen(_ amount: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "¥"
    formatter.locale = Locale(identifier: "ja_JP")
    return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
}

func sampleOrderItems(for seat: Seat) -> [OrderItem] {
    let guestCount = max(seat.occupants, 1)

    return [
        OrderItem(id: "seat-\(seat.id)-otoshi", name: "お通し", unitPrice: 350, quantity: guestCount),
        OrderItem(id: "seat-\(seat.id)-beer", name: "生ビール", unitPrice: 600, quantity: guestCount),
        OrderItem(id: "seat-\(seat.id)-karaage", name: "唐揚げ", unitPrice: 780, quantity: 1)
    ]
}

// MARK: - Styles

struct MethodChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(999)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct ShortcutButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(999)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct OutlineShortcutButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .overlay(
                Capsule().stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct CommitButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let isPartial: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Group {
                    if !isEnabled {
                        Color.gray.opacity(0.35)
                    } else if isPartial {
                        Color.green
                    } else {
                        Color.blue
                    }
                }
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

// MARK: - Demo Host

struct BillingDemoHostView: View {
    @State private var showBilling = false

    var sampleItems: [OrderItem] = [
        .init(id: "i1", name: "ラーメン", unitPrice: 900, quantity: 2),
        .init(id: "i2", name: "餃子", unitPrice: 500, quantity: 1),
        .init(id: "i3", name: "生ビール", unitPrice: 600, quantity: 3)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("営業画面から会計を開く想定")
                    .font(.headline)

                Button("会計を開く") {
                    showBilling = true
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("営業")
            .sheet(isPresented: $showBilling) {
                BillingView(
                    viewModel: BillingViewModel(
                        tableId: "1A",
                        people: 2,
                        items: sampleItems
                    ),
                    onClose: {
                        showBilling = false
                    },
                    onCompleted: { result in
                        print("会計完了: \(result)")
                    }
                )
            }
        }
    }
}

#Preview {
    BillingDemoHostView()
}
