import Foundation

struct ChangeLogEntry: Identifiable, Hashable, Codable {
    let id: String
    let storeId: String
    let entityType: String
    let entityId: String
    let action: String
    let summary: String
    let userId: String
    let createdAt: Date
}

protocol ChangeLogRepository {
    func fetch(storeId: String, entityType: String?, entityId: String?) -> [ChangeLogEntry]
    func append(_ entry: ChangeLogEntry)
}

final class UserDefaultsChangeLogRepository: ChangeLogRepository {
    private let key = "changeLogs.v1"

    func fetch(storeId: String, entityType: String?, entityId: String?) -> [ChangeLogEntry] {
        loadAll()
            .filter { $0.storeId == storeId }
            .filter { entry in
                guard let entityType else { return true }
                return entry.entityType == entityType
            }
            .filter { entry in
                guard let entityId else { return true }
                return entry.entityId == entityId
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func append(_ entry: ChangeLogEntry) {
        var entries = loadAll()
        entries.append(entry)
        AppJSONStore.save(entries, key: key)
    }

    private func loadAll() -> [ChangeLogEntry] {
        AppJSONStore.load([ChangeLogEntry].self, key: key, fallback: [])
    }
}

extension ChangeLogRepository {
    func record(
        storeId: String,
        entityType: String,
        entityId: String,
        action: String,
        summary: String,
        userId: String = "system"
    ) {
        append(ChangeLogEntry(
            id: UUID().uuidString,
            storeId: storeId,
            entityType: entityType,
            entityId: entityId,
            action: action,
            summary: summary,
            userId: userId,
            createdAt: Date()
        ))
    }
}
