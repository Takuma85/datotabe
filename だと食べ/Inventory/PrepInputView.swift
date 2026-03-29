import SwiftUI

struct PrepInputView: View {
    @Binding var items: [InventoryItem]
    @State private var showingSettings = false
    
    private var groupedCategories: [String] {
        Set(items.map(\.category).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未分類" : $0 })
            .sorted()
    }
    
    var body: some View {
        List {
            ForEach(groupedCategories, id: \.self) { category in
                Section(category) {
                    ForEach(items.indices.filter { normalizedCategory(items[$0].category) == category }, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(items[index].name)
                                .font(.headline)
                            HStack {
                                Text("現在数")
                                Spacer()
                                Text(formatQty(items[index].currentStock, unit: items[index].unit))
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("数量調整")
                                Spacer()
                                Stepper(value: $items[index].currentStock, in: 0...9999, step: 1) {
                                    Text("\(Int(items[index].currentStock))")
                                        .monospacedDigit()
                                }
                            }
                            HStack {
                                Text("目安数")
                                Spacer()
                                Text(formatQty(items[index].reorderPoint, unit: items[index].unit))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("仕込入力（仕込み品）")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("設定") {
                    showingSettings = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            PrepListSettingsView(items: $items)
        }
    }
    
    private func normalizedCategory(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未分類" : trimmed
    }
}

private struct PrepListSettingsView: View {
    @Binding var items: [InventoryItem]
    @Environment(\.dismiss) private var dismiss
    
    @State private var editingId: UUID?
    @State private var name = ""
    @State private var selectedCategory = "未分類"
    @State private var unit = "食"
    @State private var currentStockText = ""
    @State private var reorderPointText = ""
    @State private var errorMessage = ""
    @State private var customCategories: [String] = []
    @State private var showingAddCategoryAlert = false
    @State private var newCategoryName = ""
    
    private let unitOptions = ["食", "個", "枚", "皿", "杯", "g", "kg", "ml", "L"]
    private let defaultCategories = ["未分類", "主菜", "副菜", "デザート", "スープ", "ソース", "仕込みベース", "その他"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(editingId == nil ? "新規追加" : "編集") {
                    TextField("仕込み名", text: $name)
                    HStack(spacing: 8) {
                        Picker("カテゴリー", selection: $selectedCategory) {
                            ForEach(availableCategories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button {
                            showingAddCategoryAlert = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .accessibilityLabel("カテゴリー追加")
                    }
                    Picker("単位", selection: $unit) {
                        ForEach(unitOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    TextField("現在数（未設定なら空欄）", text: $currentStockText)
                        .keyboardType(.decimalPad)
                    TextField("目安数（未設定なら空欄）", text: $reorderPointText)
                        .keyboardType(.decimalPad)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    
                    HStack {
                        Button(editingId == nil ? "追加" : "更新", action: saveItem)
                            .buttonStyle(.borderedProminent)
                        if editingId != nil {
                            Button("キャンセル編集", action: resetEditor)
                                .buttonStyle(.bordered)
                        }
                    }
                }
                
                ForEach(groupedItemsForSettings, id: \.category) { group in
                    Section("登録済み仕込みリスト / \(group.category)") {
                        if group.items.isEmpty {
                            Text("品目がありません")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(group.items) { item in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.headline)
                                        Text("現在数: \(formatQty(item.currentStock, unit: item.unit)) / 目安数: \(formatQty(item.reorderPoint, unit: item.unit))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("編集") {
                                        startEdit(item)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("削除", role: .destructive) {
                                        items.removeAll { $0.id == item.id }
                                        if editingId == item.id {
                                            resetEditor()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("仕込みリスト設定")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("カテゴリー追加", isPresented: $showingAddCategoryAlert) {
                TextField("カテゴリー名", text: $newCategoryName)
                Button("追加") {
                    appendCategory()
                }
                Button("キャンセル", role: .cancel) {
                    newCategoryName = ""
                }
            } message: {
                Text("追加したカテゴリーは選択肢に表示されます")
            }
            .onAppear {
                customCategories = Array(
                    Set(items.map(\.category).map(normalizedCategory))
                        .subtracting(defaultCategories)
                ).sorted()
                if !availableCategories.contains(selectedCategory) {
                    selectedCategory = availableCategories.first ?? "未分類"
                }
            }
        }
    }
    
    private var availableCategories: [String] {
        Array(Set(defaultCategories + customCategories + items.map(\.category).map(normalizedCategory))).sorted()
    }
    
    private var groupedItemsForSettings: [(category: String, items: [InventoryItem])] {
        Dictionary(grouping: items, by: { normalizedCategory($0.category) })
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.category < $1.category }
    }
    
    private func normalizedCategory(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未分類" : trimmed
    }
    
    private func startEdit(_ item: InventoryItem) {
        editingId = item.id
        name = item.name
        selectedCategory = normalizedCategory(item.category)
        unit = item.unit
        currentStockText = String(item.currentStock)
        reorderPointText = String(item.reorderPoint)
        errorMessage = ""
    }
    
    private func saveItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "仕込み名を入力してください"
            return
        }
        
        let stockText = currentStockText.trimmingCharacters(in: .whitespacesAndNewlines)
        let reorderText = reorderPointText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let currentValue: Double
        if stockText.isEmpty {
            currentValue = 0
        } else if let value = Double(stockText) {
            currentValue = value
        } else {
            errorMessage = "現在数は数値で入力してください"
            return
        }
        
        let reorderValue: Double
        if reorderText.isEmpty {
            reorderValue = 0
        } else if let value = Double(reorderText) {
            reorderValue = value
        } else {
            errorMessage = "目安数は数値で入力してください"
            return
        }
        
        let duplicated = items.contains {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame && $0.id != editingId
        }
        guard !duplicated else {
            errorMessage = "同名の仕込みがすでに存在します"
            return
        }
        
        if let editingId {
            items = items.map { item in
                guard item.id == editingId else { return item }
                var updated = item
                updated.name = trimmedName
                updated.category = normalizedCategory(selectedCategory)
                updated.unit = unit
                updated.currentStock = clampNumber(currentValue)
                updated.reorderPoint = clampNumber(reorderValue)
                return updated
            }
        } else {
            items.insert(
                InventoryItem(
                    name: trimmedName,
                    category: normalizedCategory(selectedCategory),
                    unit: unit,
                    currentStock: clampNumber(currentValue),
                    reorderPoint: clampNumber(reorderValue)
                ),
                at: 0
            )
        }
        
        resetEditor()
    }
    
    private func resetEditor() {
        editingId = nil
        name = ""
        selectedCategory = availableCategories.first ?? "未分類"
        unit = "食"
        currentStockText = ""
        reorderPointText = ""
        errorMessage = ""
    }
    
    private func appendCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !availableCategories.contains(trimmed) {
            customCategories.append(trimmed)
            customCategories = Array(Set(customCategories)).sorted()
        }
        selectedCategory = trimmed
        newCategoryName = ""
    }
}
