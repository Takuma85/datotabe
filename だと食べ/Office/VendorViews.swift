import SwiftUI

struct VendorListView: View {
    @Environment(\.vendorRepository) private var vendorRepository
    @State private var searchText: String = ""
    @State private var selectedCategory: VendorCategory? = nil
    @State private var showInactive: Bool = false
    @State private var isPresentingForm: Bool = false
    @State private var editingVendor: Vendor?

    private let storeId: String = "store_1"

    var body: some View {
        List {
            Section {
                TextField("検索", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("種別", selection: Binding(
                    get: { selectedCategory },
                    set: { selectedCategory = $0 }
                )) {
                    Text("すべて").tag(VendorCategory?.none)
                    ForEach(VendorCategory.allCases) { c in
                        Text(c.label).tag(VendorCategory?.some(c))
                    }
                }
                .pickerStyle(.menu)

                Toggle("無効も表示", isOn: $showInactive)
            }

            Section("取引先一覧") {
                ForEach(vendors()) { vendor in
                    Button {
                        editingVendor = vendor
                        isPresentingForm = true
                    } label: {
                        vendorRow(vendor)
                    }
                }
            }
        }
        .navigationTitle("取引先マスタ")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingVendor = nil
                    isPresentingForm = true
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingForm, onDismiss: {
            editingVendor = nil
        }) {
            NavigationView {
                VendorFormView(
                    storeId: storeId,
                    vendor: editingVendor,
                    onSave: { vendor in
                        vendorRepository.save(vendor: vendor)
                        isPresentingForm = false
                    },
                    onCancel: {
                        isPresentingForm = false
                    }
                )
            }
        }
    }

    private func vendors() -> [Vendor] {
        vendorRepository.fetchVendors(
            storeId: storeId,
            search: searchText,
            category: selectedCategory,
            isActive: showInactive ? nil : true
        )
    }

    private func vendorRow(_ vendor: Vendor) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vendor.name)
                    .font(.headline)
                Text(vendor.category.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !vendor.isActive {
                Text("無効")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct VendorFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var vendor: VendorDraft
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    let storeId: String
    let onSave: (Vendor) -> Void
    let onCancel: () -> Void

    init(
        storeId: String,
        vendor: Vendor?,
        onSave: @escaping (Vendor) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.storeId = storeId
        self.onSave = onSave
        self.onCancel = onCancel
        _vendor = State(initialValue: VendorDraft(from: vendor, storeId: storeId))
    }

    var body: some View {
        Form {
            Section(header: Text("基本情報")) {
                TextField("取引先名（必須）", text: $vendor.name)

                Picker("種別", selection: $vendor.category) {
                    ForEach(VendorCategory.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("連絡先・メモ")) {
                TextField("電話", text: $vendor.phone)
                TextField("メール", text: $vendor.email)
                TextField("メモ", text: $vendor.memo)
            }

            if vendor.isEdit {
                Section(header: Text("状態")) {
                    Toggle("有効", isOn: $vendor.isActive)
                }
            }
        }
        .navigationTitle(vendor.isEdit ? "取引先編集" : "取引先追加")
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
        let trimmed = vendor.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertMessage = "取引先名は必須です。"
            showAlert = true
            return
        }
        guard trimmed.count <= 255 else {
            alertMessage = "取引先名は255文字以内で入力してください。"
            showAlert = true
            return
        }

        let now = Date()
        let built = Vendor(
            id: vendor.id ?? UUID().uuidString,
            storeId: storeId,
            name: trimmed,
            category: vendor.category,
            phone: vendor.phone.isEmpty ? nil : vendor.phone,
            email: vendor.email.isEmpty ? nil : vendor.email,
            memo: vendor.memo.isEmpty ? nil : vendor.memo,
            isActive: vendor.isActive,
            createdAt: vendor.createdAt ?? now,
            updatedAt: now
        )

        onSave(built)
        dismiss()
    }
}

private struct VendorDraft {
    var id: String?
    var name: String
    var category: VendorCategory
    var phone: String
    var email: String
    var memo: String
    var isActive: Bool
    var createdAt: Date?
    var isEdit: Bool

    init(from vendor: Vendor?, storeId: String) {
        if let vendor = vendor {
            self.id = vendor.id
            self.name = vendor.name
            self.category = vendor.category
            self.phone = vendor.phone ?? ""
            self.email = vendor.email ?? ""
            self.memo = vendor.memo ?? ""
            self.isActive = vendor.isActive
            self.createdAt = vendor.createdAt
            self.isEdit = true
        } else {
            self.id = nil
            self.name = ""
            self.category = .other
            self.phone = ""
            self.email = ""
            self.memo = ""
            self.isActive = true
            self.createdAt = nil
            self.isEdit = false
        }
    }
}

#Preview {
    NavigationStack {
        VendorListView()
    }
}
