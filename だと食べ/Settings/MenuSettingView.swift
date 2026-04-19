import SwiftUI

struct MenuSettingView: View {
    @State private var menuItems: [SeatMenuItem] = []
    @State private var inventoryItems: [InventoryItem] = []
    @State private var links: [InventoryItemLink] = []
    @State private var searchText: String = ""
    @State private var toast: String = ""

    private var filteredMenuItems: [SeatMenuItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return menuItems
            .filter { trimmed.isEmpty || $0.name.localizedCaseInsensitiveContains(trimmed) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section("在庫リンク設定") {
                Text("メニュー商品と在庫品目を結び付けます")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                TextField("メニュー商品を検索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Label("在庫品目: \(inventoryItems.count)件", systemImage: "shippingbox")
                    .font(.subheadline)
            }

            Section("メニュー商品") {
                if filteredMenuItems.isEmpty {
                    Text("該当する商品がありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredMenuItems) { item in
                        NavigationLink {
                            MenuInventoryLinkEditorView(
                                menuItem: item,
                                inventoryItems: inventoryItems,
                                links: $links,
                                onPersist: persistLinks
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                if let summary = linkSummary(for: item.id) {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("リンク未設定")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("メニュー設定")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    reload()
                } label: {
                    Label("再読込", systemImage: "arrow.clockwise")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !toast.isEmpty {
                Text(toast)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        menuItems = loadOrderMenu()
        inventoryItems = InventoryStorage.loadIngredients().filter { $0.isActive }
        links = InventoryStorage.loadLinks()
    }

    private func persistLinks() {
        InventoryStorage.saveLinks(links)
        showToast("リンク設定を保存しました")
    }

    private func linkSummary(for menuItemId: String) -> String? {
        let itemById = Dictionary(uniqueKeysWithValues: inventoryItems.map { ($0.id, $0.name) })
        let names = links
            .filter { $0.menuItemId == menuItemId && $0.isActive }
            .sorted { $0.quantityPerSale > $1.quantityPerSale }
            .map { link -> String in
                let name = itemById[link.inventoryItemId] ?? "未登録品目"
                return "\(name) ×\(link.quantityPerSale)"
            }

        guard !names.isEmpty else { return nil }
        return names.joined(separator: " / ")
    }

    private func showToast(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if toast == message {
                toast = ""
            }
        }
    }
}

private struct MenuInventoryLinkEditorView: View {
    let menuItem: SeatMenuItem
    let inventoryItems: [InventoryItem]
    @Binding var links: [InventoryItemLink]
    let onPersist: () -> Void

    @State private var selectedInventoryItemId: String = ""
    @State private var quantityPerSale: Int = 1

    private var currentLinks: [InventoryItemLink] {
        links
            .filter { $0.menuItemId == menuItem.id }
            .sorted { lhs, rhs in
                inventoryName(for: lhs.inventoryItemId) < inventoryName(for: rhs.inventoryItemId)
            }
    }

    var body: some View {
        Form {
            Section("現在のリンク") {
                if currentLinks.isEmpty {
                    Text("この商品はリンク未設定です")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(currentLinks) { link in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(inventoryName(for: link.inventoryItemId))
                                Text(link.isActive ? "有効" : "無効")
                                    .font(.caption2)
                                    .foregroundColor(link.isActive ? .secondary : .orange)
                            }
                            Spacer()
                            Text("×\(link.quantityPerSale)")
                                .fontWeight(.semibold)
                        }
                    }
                    .onDelete(perform: deleteLinks)
                }
            }

            Section("リンク追加 / 更新") {
                if inventoryItems.isEmpty {
                    Text("在庫品目がありません。先に在庫画面で品目を登録してください。")
                        .foregroundColor(.secondary)
                } else {
                    Picker("在庫品目", selection: $selectedInventoryItemId) {
                        ForEach(inventoryItems.sorted { $0.name < $1.name }) { item in
                            Text(item.name).tag(item.id)
                        }
                    }

                    Stepper("1注文あたり数量 \(quantityPerSale)", value: $quantityPerSale, in: 1...99)

                    Button("保存") {
                        upsertLink()
                    }
                    .disabled(selectedInventoryItemId.isEmpty)
                }
            }
        }
        .navigationTitle(menuItem.name)
        .onAppear {
            if selectedInventoryItemId.isEmpty {
                selectedInventoryItemId = inventoryItems.first?.id ?? ""
            }
        }
    }

    private func upsertLink() {
        guard !selectedInventoryItemId.isEmpty else { return }

        if let existingIndex = links.firstIndex(where: {
            $0.menuItemId == menuItem.id && $0.inventoryItemId == selectedInventoryItemId
        }) {
            links[existingIndex].quantityPerSale = quantityPerSale
            links[existingIndex].isActive = true
        } else {
            links.append(
                InventoryItemLink(
                    id: UUID().uuidString,
                    menuItemId: menuItem.id,
                    inventoryItemId: selectedInventoryItemId,
                    quantityPerSale: quantityPerSale,
                    isActive: true
                )
            )
        }

        onPersist()
    }

    private func deleteLinks(at offsets: IndexSet) {
        let targetIDs = offsets.map { currentLinks[$0].id }
        links.removeAll { targetIDs.contains($0.id) }
        onPersist()
    }

    private func inventoryName(for inventoryItemId: String) -> String {
        inventoryItems.first(where: { $0.id == inventoryItemId })?.name ?? "未登録品目"
    }
}
