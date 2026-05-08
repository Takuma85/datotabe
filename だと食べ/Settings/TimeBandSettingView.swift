import SwiftUI

struct TimeBandSettingView: View {
    @Environment(\.appSettingsRepository) private var repository

    @State private var drafts: [TimeBandDraft] = []
    @State private var saveMessage: String?

    private let storeId = "store_1"

    var body: some View {
        List {
            Section("時間帯") {
                ForEach($drafts) { $draft in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("名称", text: $draft.name)
                            .font(.headline)
                        HStack {
                            TextField("コード", text: $draft.code)
                                .textInputAutocapitalization(.never)
                            TextField("開始", text: $draft.startTime)
                            TextField("終了", text: $draft.endTime)
                        }
                        Stepper("並び順 \(draft.sortOrder)", value: $draft.sortOrder, in: 0...999)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: delete)
            }

            if let saveMessage {
                Section {
                    Text(saveMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("時間帯設定")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("追加", action: add)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存", action: save)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        drafts = repository.loadTimeBands(storeId: storeId).map(TimeBandDraft.init)
    }

    private func add() {
        drafts.append(TimeBandDraft(
            code: "band_\(drafts.count + 1)",
            name: "時間帯\(drafts.count + 1)",
            startTime: "00:00",
            endTime: "00:00",
            sortOrder: ((drafts.map(\.sortOrder).max() ?? 0) + 10)
        ))
    }

    private func delete(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
    }

    private func save() {
        let bands = drafts.map(\.timeBand)
        repository.saveTimeBands(storeId: storeId, timeBands: bands)
        drafts = repository.loadTimeBands(storeId: storeId).map(TimeBandDraft.init)
        saveMessage = "保存しました"
    }
}

private struct TimeBandDraft: Identifiable {
    let id = UUID()
    var code: String
    var name: String
    var startTime: String
    var endTime: String
    var sortOrder: Int

    init(_ timeBand: TimeBand) {
        self.code = timeBand.code
        self.name = timeBand.name
        self.startTime = timeBand.startTime
        self.endTime = timeBand.endTime
        self.sortOrder = timeBand.sortOrder
    }

    init(code: String, name: String, startTime: String, endTime: String, sortOrder: Int) {
        self.code = code
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.sortOrder = sortOrder
    }

    var timeBand: TimeBand {
        TimeBand(
            code: code,
            name: name,
            startTime: startTime,
            endTime: endTime,
            sortOrder: sortOrder
        )
    }
}

#Preview {
    NavigationStack {
        TimeBandSettingView()
    }
}
