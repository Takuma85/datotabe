import SwiftUI

struct ChangeLogView: View {
    @State private var logs: [ChangeLogEntry] = []

    private let storeId = "store_1"
    private let repository: ChangeLogRepository = UserDefaultsChangeLogRepository()

    var body: some View {
        List {
            if logs.isEmpty {
                Text("変更履歴はまだありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(logs) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(log.entityType)
                                .font(.caption.weight(.semibold))
                            Text(log.action)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Self.dateFormatter.string(from: log.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(log.summary)
                            .font(.subheadline)

                        Text("\(log.entityId) / \(log.userId)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("変更履歴")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    load()
                } label: {
                    Label("再読込", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        logs = repository.fetch(storeId: storeId, entityType: nil, entityId: nil)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()
}

#Preview {
    NavigationStack {
        ChangeLogView()
    }
}
