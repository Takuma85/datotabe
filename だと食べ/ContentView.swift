import SwiftUI
import Observation

// MARK: - Models (in-memory; no SwiftData)

enum Unit: String, CaseIterable, Identifiable, Codable {
    case g, ml, cc, kg, L, 個, 食
    var id: String { rawValue }
}

struct Item: Identifiable, Equatable, Codable {
    var id: UUID = .init()
    var name: String
    var unit: Unit
    var currentStock: Double
    var reorderPoint: Double
}

// Loss models (ロス専用)
struct Batch: Identifiable, Codable { var id: UUID = .init(); var quantity: Double; var expiresAt: Date? }
struct LossItem: Identifiable, Codable { var id: UUID = .init(); var name: String; var batches: [Batch] }
struct LossPrep: Identifiable, Codable { var id: UUID = .init(); var name: String }
struct LossLog: Identifiable, Codable { var id: UUID = .init(); var itemName: String; var quantity: Double; var at: Date }

// MARK: - ReorderEngine
struct ReorderEngine {
    static func reorderSuggestions(_ items: [Item], includeEqual: Bool = true) -> [Item] {
        items.filter { includeEqual ? $0.currentStock <= $0.reorderPoint : $0.currentStock < $0.reorderPoint }
    }
}

// MARK: - App State
@Observable final class AppState {
    // 完全分離: 食材 / 料理
    var ingItems: [Item] = [
        .init(name: "牛乳", unit: .L, currentStock: 2, reorderPoint: 3),
        .init(name: "卵", unit: .個, currentStock: 30, reorderPoint: 12),
        .init(name: "小麦粉", unit: .kg, currentStock: 5, reorderPoint: 5),
        .init(name: "砂糖", unit: .kg, currentStock: 6, reorderPoint: 5),
        .init(name: "バター", unit: .g, currentStock: 499, reorderPoint: 500),
    ]
    var prepItems: [Item] = [
        .init(name: "カレー", unit: .食, currentStock: 8, reorderPoint: 5),
        .init(name: "プリン", unit: .個, currentStock: 10, reorderPoint: 4),
    ]

    // ロス
    var lossItems: [LossItem] = [
        .init(name: "牛乳1L", batches: [
            .init(quantity: 3.0, expiresAt: Calendar.current.date(byAdding: .day, value: -1, to: .now)),
            .init(quantity: 2.0, expiresAt: Calendar.current.date(byAdding: .day, value: 3, to: .now)),
        ]),
        .init(name: "卵10個", batches: [
            .init(quantity: 1.0, expiresAt: Calendar.current.date(byAdding: .day, value: -5, to: .now)),
            .init(quantity: 2.0, expiresAt: Calendar.current.date(byAdding: .day, value: 2, to: .now)),
        ]),
        .init(name: "小麦粉1kg", batches: [ .init(quantity: 5.0, expiresAt: nil) ]),
    ]
    var lossPreps: [LossPrep] = [ .init(name: "鶏のから揚げ仕込み"), .init(name: "サラダ仕込み"), .init(name: "ラーメン仕込み") ]
    var lossLogs: [LossLog] = []
}

// MARK: - App Entry
@main
struct InventoryApp: App {
    @State private var state = AppState()
    var body: some Scene {
        WindowGroup { RootView().environment(state) }
    }
}

// MARK: - Root & Navigation
enum Screen { case home, delivery, prep, stocktake, loss }

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var screen: Screen = .home
    var body: some View {
        NavigationStack {
            Group {
                switch screen {
                case .home: HomeView(onNavigate: { screen = $0 })
                case .delivery: DeliveryView(onBack: { screen = .home })
                case .prep: PrepView(onBack: { screen = .home })
                case .stocktake: StocktakeView(onBack: { screen = .home })
                case .loss: LossView(onBack: { screen = .home })
                }
            }
        }
        .environment(state)
    }
}

// MARK: - Home
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var includeEqual = true
    @State private var alerts: [String] = []
    let onNavigate: (Screen) -> Void

    var body: some View {
        VStack(spacing: 16) {
            // 通知エリア
            Card {
                HStack(alignment: .firstTextBaseline) {
                    Text("発注アラート \(includeEqual ? "(現在庫 ≤ 発注点)" : "(現在庫 < 発注点)")").font(.headline)
                    Spacer()
                    Toggle("境界を含む（≤）", isOn: $includeEqual).labelsHidden()
                    Button("アラート再計算") { runReorderCheck() }.buttonStyle(.borderedProminent)
                }
                if alerts.isEmpty {
                    Text("ここにアラートが表示されます（食材の現状在庫から算出）").foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(alerts, id: \.self) { msg in
                            Text(msg).padding(8).background(Color.yellow.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            // 入力ボタン
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ButtonFill("納品物入力") { onNavigate(.delivery) }
                ButtonFill("仕込み数入力") { onNavigate(.prep) }
                ButtonFill("棚卸し数入力") { onNavigate(.stocktake) }
                ButtonFill("ロス入力") { onNavigate(.loss) }
            }

            // 開発用セルフテスト
            SelfTestsView()

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("ホーム")
    }

    private func runReorderCheck() {
        let targets = ReorderEngine.reorderSuggestions(state.ingItems, includeEqual: includeEqual)
        alerts = targets.map { "\($0.name) が発注点を下回りました（在庫 \(formatQty($0.currentStock, $0.unit))）" }
    }
}

// MARK: - Delivery (食材)
struct DeliveryView: View {
    @Environment(AppState.self) private var state
    @State private var showEditor = false
    @State private var editing: Item? = nil

    // Keypad
    @State private var showKeypad = false
    @State private var keypadText = ""
    @State private var keypadUnit: Unit = .個
    @State private var keypadTargetID: UUID? = nil

    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("← 戻る", action: onBack).buttonStyle(.bordered)
                Spacer()
                Text("納品物入力（食材）").font(.headline)
                Spacer()
                Button("食材を編集") { editing = nil; showEditor = true }.buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            Card {
                HStack {
                    Text("食材名").font(.caption).foregroundStyle(.secondary); Spacer()
                    Text("現在庫").font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                    Text("発注点").font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                    Text("単位").font(.caption).foregroundStyle(.secondary).frame(width: 40)
                    Text("編集").font(.caption).foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                }
                Divider()
                ForEach(state.ingItems) { it in
                    HStack {
                        Text(it.name).lineLimit(1)
                        Spacer()
                        Button(formatQty(it.currentStock, it.unit)) { openKeypad(it) }
                            .buttonStyle(.bordered).frame(width: 80)
                        Text(String(format: "%.0f", it.reorderPoint)).frame(width: 60, alignment: .trailing)
                        Text(it.unit.rawValue).frame(width: 40, alignment: .leading)
                        Button("編集") { editing = it; showEditor = true }.frame(width: 64, alignment: .trailing)
                    }
                    Divider()
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ItemEditorSheet(
                title: editing == nil ? "新規食材を追加" : "食材を編集",
                item: editing,
                roleName: "食材",
                allNamesLowercased: Set(state.ingItems.map{ $0.name.lowercased() }),
                onSave: { newItem in
                    if let editing, let idx = state.ingItems.firstIndex(where: { $0.id == editing.id }) {
                        state.ingItems[idx] = newItem
                    } else {
                        state.ingItems.insert(newItem, at: 0)
                    }
                }
            )
        }
        .sheet(isPresented: $showKeypad) {
            VStack(alignment: .leading, spacing: 12) {
                Text("現在庫の入力").font(.headline)
                NumericKeypadWithUnit(text: $keypadText, unit: $keypadUnit) { commitKeypad() }
                Button("閉じる") { showKeypad = false }.buttonStyle(.bordered)
            }.padding()
        }
        .navigationBarBackButtonHidden(true)
    }

    private func openKeypad(_ it: Item) {
        keypadTargetID = it.id
        keypadText = String(it.currentStock)
        keypadUnit = it.unit
        showKeypad = true
    }
    private func commitKeypad() {
        guard let id = keypadTargetID, let n = Double(keypadText) else { return }
        if let idx = state.ingItems.firstIndex(where: { $0.id == id }) {
            state.ingItems[idx].currentStock = clampNumber(n)
            state.ingItems[idx].unit = keypadUnit
        }
        showKeypad = false
    }
}

// MARK: - Prep (料理)
struct PrepView: View {
    @Environment(AppState.self) private var state
    @State private var showEditor = false
    @State private var editing: Item? = nil

    // Keypad
    @State private var showKeypad = false
    @State private var keypadText = ""
    @State private var keypadUnit: Unit = .食
    @State private var keypadTargetID: UUID? = nil

    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("← 戻る", action: onBack).buttonStyle(.bordered)
                Spacer()
                Text("仕込み数入力（料理）").font(.headline)
                Spacer()
                Button("料理を編集") { editing = nil; showEditor = true }.buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            Card {
                HStack {
                    Text("料理名").font(.caption).foregroundStyle(.secondary); Spacer()
                    Text("現在数").font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                    Text("目安数").font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                    Text("単位").font(.caption).foregroundStyle(.secondary).frame(width: 40)
                    Text("編集").font(.caption).foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                }
                Divider()
                ForEach(state.prepItems) { it in
                    HStack {
                        Text(it.name).lineLimit(1)
                        Spacer()
                        Button(formatQty(it.currentStock, it.unit)) { openKeypad(it) }.buttonStyle(.bordered).frame(width: 80)
                        Text(String(format: "%.0f", it.reorderPoint)).frame(width: 60, alignment: .trailing)
                        Text(it.unit.rawValue).frame(width: 40, alignment: .leading)
                        Button("編集") { editing = it; showEditor = true }.frame(width: 64, alignment: .trailing)
                    }
                    Divider()
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ItemEditorSheet(
                title: editing == nil ? "新規料理を追加" : "料理を編集",
                item: editing,
                roleName: "料理",
                allNamesLowercased: Set(state.prepItems.map{ $0.name.lowercased() }),
                defaultUnit: .食,
                onSave: { newItem in
                    if let editing, let idx = state.prepItems.firstIndex(where: { $0.id == editing.id }) {
                        state.prepItems[idx] = newItem
                    } else {
                        state.prepItems.insert(newItem, at: 0)
                    }
                }
            )
        }
        .sheet(isPresented: $showKeypad) {
            VStack(alignment: .leading, spacing: 12) {
                Text("現在数の入力").font(.headline)
                NumericKeypadWithUnit(text: $keypadText, unit: $keypadUnit) { commitKeypad() }
                Button("閉じる") { showKeypad = false }.buttonStyle(.bordered)
            }.padding()
        }
        .navigationBarBackButtonHidden(true)
    }

    private func openKeypad(_ it: Item) {
        keypadTargetID = it.id
        keypadText = String(it.currentStock)
        keypadUnit = it.unit
        showKeypad = true
    }
    private func commitKeypad() {
        guard let id = keypadTargetID, let n = Double(keypadText) else { return }
        if let idx = state.prepItems.firstIndex(where: { $0.id == id }) {
            state.prepItems[idx].currentStock = clampNumber(n)
            state.prepItems[idx].unit = keypadUnit
        }
        showKeypad = false
    }
}

// MARK: - Stocktake (棚卸し)
struct StocktakeView: View {
    @Environment(AppState.self) private var state

    enum Mode: String, CaseIterable { case 食材, 仕込み品 }
    @State private var mode: Mode = .食材
    @State private var search = ""
    @State private var counts: [UUID: String] = [:]
    @State private var activeID: UUID? = nil

    // alerts
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    let onBack: () -> Void

    var list: [Item] { mode == .食材 ? state.ingItems : state.prepItems }
    var filtered: [Item] { search.isEmpty ? list : list.filter{ $0.name.contains(search) } }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("← 戻る", action: onBack).buttonStyle(.bordered)
                Spacer()
                Text("棚卸し入力").font(.headline)
                Spacer()
            }.padding(.horizontal)

            HStack(spacing: 8) {
                Picker("", selection: $mode) { ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) } }
                    .pickerStyle(.segmented)
                TextField("名前で検索", text: $search).textFieldStyle(.roundedBorder)
                Button("一括確定") { bulkCommit() }.buttonStyle(.borderedProminent)
            }

            Card {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(mode.rawValue)：\(filtered.count) 件").foregroundStyle(.secondary)
                        .padding(.bottom, 6)
                    ForEach(filtered) { it in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading) {
                                Text(it.name).fontWeight(.semibold).lineLimit(1)
                                Text("理論在庫: \(formatQty(it.currentStock, it.unit)) / 発注点: \(formatQty(it.reorderPoint, it.unit))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            TextField("棚卸し数", text: Binding(get: { counts[it.id] ?? "" }, set: { counts[it.id] = $0 }))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                            Button("キーパッド") { openKeypad(it) }.buttonStyle(.bordered)
                            Button("確定") { commitOne(it) }.buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { activeID != nil }, set: { if !$0 { activeID = nil } })) {
            VStack(alignment: .leading, spacing: 12) {
                Text("棚卸し入力").font(.headline)
                if let id = activeID {
                    NumericKeypadWithUnit(text: Binding(get: { counts[id] ?? "" }, set: { counts[id] = $0 }), unit: .constant(.個)) {
                        if let it = list.first(where: { $0.id == id }) { commitOne(it) }
                    }
                }
                Button("閉じる") { activeID = nil }.buttonStyle(.bordered)
            }.padding()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(alertMessage) }
        .navigationBarBackButtonHidden(true)
    }

    private func openKeypad(_ it: Item) { activeID = it.id; counts[it.id] = counts[it.id] ?? String(it.currentStock) }

    private func commitOne(_ it: Item) {
        let txt = counts[it.id] ?? "0"
        let counted = clampNumber(Double(txt) ?? 0)
        let diff = counted - it.currentStock
        if let idx = (mode == .食材 ? state.ingItems.firstIndex(of: it) : state.prepItems.firstIndex(of: it)) {
            if mode == .食材 { state.ingItems[idx].currentStock = counted } else { state.prepItems[idx].currentStock = counted }
        }
        activeID = nil
        alertTitle = "棚卸し"
        alertMessage = "\(it.name) を棚卸し確定\n理論在庫: \(formatQty(it.currentStock, it.unit))\n実在庫: \(formatQty(counted, it.unit))\n差分: \(diff >= 0 ? "+" : "")\(formatQty(diff, it.unit))\(diff < 0 ? "（ロス）" : "")"
        showAlert = true
    }

    private func bulkCommit() {
        var changed = 0
        if mode == .食材 {
            for i in state.ingItems.indices { if let txt = counts[state.ingItems[i].id], let v = Double(txt) { state.ingItems[i].currentStock = clampNumber(v); changed += 1 } }
        } else {
            for i in state.prepItems.indices { if let txt = counts[state.prepItems[i].id], let v = Double(txt) { state.prepItems[i].currentStock = clampNumber(v); changed += 1 } }
        }
        alertTitle = "棚卸し"
        alertMessage = "\(mode.rawValue) を一括確定しました（\(changed) 件）"
        showAlert = true
    }
}

// MARK: - Loss (ロス)
struct LossView: View {
    @Environment(AppState.self) private var state

    enum EntryType: String, CaseIterable { case 食材, 仕込み品 }
    @State private var entryType: EntryType = .食材
    @State private var selectedLossItemID: UUID?
    @State private var selectedLossPrepID: UUID?
    @State private var qtyText = "1.0"
    @State private var now = Date()
    @State private var filterDays: Int = 7

    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("← 戻る", action: onBack).buttonStyle(.bordered)
                Spacer()
                Text("ロス登録（一覧のみ表示）").font(.headline)
                Spacer()
            }.padding(.horizontal)

            // ツールバー
            HStack(spacing: 8) {
                DatePicker("基準日時", selection: $now)
                Stepper("表示期間(日): \(filterDays)", value: $filterDays, in: 1...60)
                Button("期限切れを再スキャン") { autoRegisterExpired() }.buttonStyle(.borderedProminent).tint(.pink)
                ShareLink(item: exportCSVURL(), preview: SharePreview("loss.csv")) { Text("CSV書き出し") }.buttonStyle(.bordered)
            }

            // 入力フォーム
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ロス入力").fontWeight(.semibold)
                    HStack {
                        Picker("対象", selection: $entryType) { ForEach(EntryType.allCases, id: \.self) { Text($0.rawValue) } }
                            .pickerStyle(.segmented)
                        if entryType == .食材 {
                            Picker("名称", selection: Binding(
                                get: { selectedLossItemID ?? state.lossItems.first?.id },
                                set: { selectedLossItemID = $0 }
                            )) {
                                ForEach(state.lossItems) { Text($0.name).tag(Optional($0.id)) }
                            }
                        } else {
                            Picker("名称", selection: Binding(
                                get: { selectedLossPrepID ?? state.lossPreps.first?.id },
                                set: { selectedLossPrepID = $0 }
                            )) {
                                ForEach(state.lossPreps) { Text($0.name).tag(Optional($0.id)) }
                            }
                        }
                        TextField("数量", text: $qtyText).keyboardType(.decimalPad).frame(width: 90).textFieldStyle(.roundedBorder)
                        Button("保存") { registerManualLoss() }.buttonStyle(.borderedProminent)
                    }
                }
            }

            // 一覧
            Card {
                HStack { Text("ロス一覧（期間: \(filterDays) 日）").fontWeight(.semibold); Spacer(); Text("件数: \(filteredLogs().count)").foregroundStyle(.secondary) }
                List(filteredLogs()) { log in
                    HStack {
                        Text(formatDate(log.at)).frame(width: 170, alignment: .leading)
                        Text(log.itemName).frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.3f", log.quantity)).frame(width: 80, alignment: .trailing)
                    }
                }
                .frame(minHeight: 200)
            }
        }
        .padding()
        .onAppear { autoRegisterExpired() } // 起動時一度
        .navigationBarBackButtonHidden(true)
    }

    // 自動ロス（期限切れ）
    private func autoRegisterExpired() {
        let nowMs = now.timeIntervalSince1970
        var added: [LossLog] = []
        for i in state.lossItems.indices {
            state.lossItems[i].batches.sort { (a, b) in
                switch (a.expiresAt, b.expiresAt) {
                case let (da?, db?): return da < db
                case (_?, nil): return true
                case (nil, _?): return false
                default: return false
                }
            }
            for j in state.lossItems[i].batches.indices {
                if let ex = state.lossItems[i].batches[j].expiresAt, ex.timeIntervalSince1970 < nowMs, state.lossItems[i].batches[j].quantity > 0 {
                    added.append(.init(itemName: state.lossItems[i].name, quantity: state.lossItems[i].batches[j].quantity, at: now))
                    state.lossItems[i].batches[j].quantity = 0
                }
            }
            state.lossItems[i].batches.removeAll { $0.quantity <= 1e-4 }
        }
        if !added.isEmpty { state.lossLogs.append(contentsOf: added) }
    }

    // 手動ロス（理由なし）
    private func registerManualLoss() {
        guard let q = Double(qtyText), q > 0 else { return showSimpleAlert("正しい数量を入力してください") }
        if entryType == .食材 {
            guard let id = selectedLossItemID ?? state.lossItems.first?.id, let idx = state.lossItems.firstIndex(where: { $0.id == id }) else { return }
            // FIFO 消費（期限がある方を先に）
            state.lossItems[idx].batches.sort { (a, b) in
                switch (a.expiresAt, b.expiresAt) {
                case let (da?, db?): return da < db
                case (_?, nil): return true
                case (nil, _?): return false
                default: return false
                }
            }
            var remaining = q
            for j in state.lossItems[idx].batches.indices {
                if remaining <= 0 { break }
                let take = min(remaining, state.lossItems[idx].batches[j].quantity)
                state.lossItems[idx].batches[j].quantity -= take
                remaining -= take
            }
            state.lossItems[idx].batches.removeAll { $0.quantity <= 1e-4 }
            state.lossLogs.append(.init(itemName: state.lossItems[idx].name, quantity: q - max(0, remaining), at: now))
        } else {
            guard let id = selectedLossPrepID ?? state.lossPreps.first?.id, let prep = state.lossPreps.first(where: { $0.id == id }) else { return }
            state.lossLogs.append(.init(itemName: prep.name, quantity: q, at: now))
        }
        qtyText = "1.0"
    }

    private func filteredLogs() -> [LossLog] {
        let boundary = Calendar.current.date(byAdding: .day, value: -filterDays, to: now) ?? now
        return state.lossLogs.filter { $0.at >= boundary && $0.at <= now }
    }

    private func exportCSVURL() -> URL {
        let headers = ["日時", "品目", "数量"]
        let rows = filteredLogs().map { [formatDate($0.at), $0.itemName, String($0.quantity)] }
        let esc: (String) -> String = { s in
            if s.contains(",") || s.contains("\n") || s.contains("\"") {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            } else { return s }
        }
        let csv = ([headers] + rows).map { $0.map(esc).joined(separator: ",") }.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appending(path: "loss_\(Int(now.timeIntervalSince1970)).csv")
        try? csv.data(using: .utf8)?.write(to: url)
        return url
    }
}

// MARK: - Shared UI Pieces
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

struct ButtonFill: View {
    var title: String; var action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 4)
            .foregroundStyle(.primary)
    }
}

// MARK: - Item Editor Sheet
struct ItemEditorSheet: View {
    var title: String
    var item: Item?
    var roleName: String // 食材 / 料理
    var allNamesLowercased: Set<String>
    var defaultUnit: Unit = .個
    var onSave: (Item) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var unit: Unit = .個
    @State private var currentStock: String = "0"
    @State private var reorderPoint: String = "0"
    @State private var error: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("\(roleName)名")) {
                    TextField("名称", text: $name)
                }
                Section(header: Text("数量・単位")) {
                    TextField("現在庫", text: $currentStock).keyboardType(.decimalPad)
                    TextField("発注点 / 目安数", text: $reorderPoint).keyboardType(.decimalPad)
                    Picker("単位", selection: $unit) { ForEach(Unit.allCases) { Text($0.rawValue).tag($0) } }
                }
                if let error { Text("⚠︎ \(error)").foregroundStyle(.red) }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear {
                if let it = item {
                    name = it.name; unit = it.unit; currentStock = String(it.currentStock); reorderPoint = String(it.reorderPoint)
                } else { unit = defaultUnit }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { error = "名称を入力してください"; return }
        let key = trimmed.lowercased()
        if item == nil && allNamesLowercased.contains(key) { error = "すでに同名の\(roleName)が存在します"; return }
        guard let current = Double(currentStock), let reorder = Double(reorderPoint) else { error = "数値を正しく入力してください"; return }
        error = nil
        onSave(.init(id: item?.id ?? UUID(), name: trimmed, unit: unit, currentStock: clampNumber(current), reorderPoint: clampNumber(reorder)))
        dismiss()
    }
}

// MARK: - Numeric Keypad (SwiftUI)
struct NumericKeypadWithUnit: View {
    @Binding var text: String
    @Binding var unit: Unit
    var onCommit: (() -> Void)? = nil

    private let keys: [[String]] = [["1","2","3"],["4","5","6"],["7","8","9"],[".","0","00"]]

    var body: some View {
        VStack(spacing: 14) {
            // 入力値＋単位選択
            HStack {
                Text(text.isEmpty ? "0" : text)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)

                Picker("単位", selection: $unit) {
                    ForEach(Unit.allCases) { u in Text(u.rawValue).tag(u) }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            .padding(.horizontal)

            // 数字キー
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        Button { tap(key) } label :{
                            Text(key)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            // 操作キー
            HStack(spacing: 12) {
                Button("削除") { if !text.isEmpty { _ = text.removeLast() } }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button("クリア") { text.removeAll() }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button("確定") { onCommit?() }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }

    private func tap(_ key: String) {
        if key == "." {
            if text.isEmpty { text = "0." }
            else if !text.contains(".") { text.append(".") }
        } else { text.append(key) }
    }
}

// MARK: - Helpers
func clampNumber(_ n: Double) -> Double { guard n.isFinite && n >= 0 else { return 0 }; return (n * 1000).rounded() / 1000 }
func formatQty(_ q: Double, _ unit: Unit) -> String { abs(q - q.rounded()) < 1e-9 ? String(Int(q)) + unit.rawValue : String(q) + unit.rawValue }
func formatDate(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f.string(from: d)
}

// Simple alert fallback for non-UIKit contexts
func showSimpleAlert(_ message: String) {
    #if DEBUG
    print("ALERT:", message)
    #endif
}

// MARK: - Self Tests (軽量)
struct SelfTestsView: View {
    @State private var results: [(String, Bool, String)] = []
    var body: some View {
        Card {
            Text("Self Tests").font(.headline)
            if results.isEmpty { Text("—").foregroundStyle(.secondary) }
            ForEach(Array(results.indices), id: \.self) { i in
                Text("\(results[i].0): \(results[i].1 ? "OK" : "NG")\(results[i].2.isEmpty ? "" : " → \(results[i].2)")")
                    .foregroundStyle(results[i].1 ? .secondary : Color.red)
            }
        }
        .onAppear { runTests() }
    }
    private func runTests() {
        var out: [(String, Bool, String)] = []
        let a = Item(name: "A", unit: .個, currentStock: 1, reorderPoint: 2)
        let b = Item(name: "B", unit: .kg, currentStock: 5, reorderPoint: 5)
        let c = Item(name: "C", unit: .L, currentStock: 6, reorderPoint: 5)
        out.append(test("formatQty int", formatQty(2, .L) == "2L"))
        out.append(test("formatQty float", formatQty(2.5, .kg) == "2.5kg"))
        out.append(test("clampNumber round", clampNumber(1.23456) == 1.235))
        out.append(test("clampNumber negative to 0", clampNumber(-3) == 0))
        out.append(test("reorder <=", ReorderEngine.reorderSuggestions([a,b,c], includeEqual: true).map{ $0.name } == ["A","B"]))
        out.append(test("reorder <", ReorderEngine.reorderSuggestions([a,b,c], includeEqual: false).map{ $0.name } == ["A"]))
        results = out
    }
    private func test(_ name: String, _ pass: Bool, _ note: String = "") -> (String, Bool, String) { (name, pass, note) }
}
