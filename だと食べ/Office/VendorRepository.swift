import Foundation
import SwiftUI

protocol VendorRepository {
    func fetchVendors(
        storeId: String,
        search: String?,
        category: VendorCategory?,
        isActive: Bool?
    ) -> [Vendor]

    func findById(_ id: String) -> Vendor?
    func save(vendor: Vendor)
    func delete(id: String)
}

final class MockVendorRepository: VendorRepository {
    private static let storageKey = "vendors.v1"
    private static var sharedItems: [Vendor] = AppJSONStore.load(
        [Vendor].self,
        key: storageKey,
        fallback: Vendor.sample()
    )

    private let changeLogRepository: ChangeLogRepository

    init(seed: [Vendor]? = nil, changeLogRepository: ChangeLogRepository = UserDefaultsChangeLogRepository()) {
        self.changeLogRepository = changeLogRepository
        if let seed {
            Self.sharedItems = seed
            persist()
        }
    }

    func fetchVendors(
        storeId: String,
        search: String?,
        category: VendorCategory?,
        isActive: Bool?
    ) -> [Vendor] {
        var result = Self.sharedItems.filter { $0.storeId == storeId }

        if let search = search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = search.lowercased()
            result = result.filter { $0.name.lowercased().contains(q) }
        }

        if let category = category {
            result = result.filter { $0.category == category }
        }

        if let isActive = isActive {
            result = result.filter { $0.isActive == isActive }
        }

        return result.sorted { $0.name < $1.name }
    }

    func findById(_ id: String) -> Vendor? {
        Self.sharedItems.first { $0.id == id }
    }

    func save(vendor: Vendor) {
        let action: String
        if let index = Self.sharedItems.firstIndex(where: { $0.id == vendor.id }) {
            Self.sharedItems[index] = vendor
            action = "update"
        } else {
            Self.sharedItems.append(vendor)
            action = "create"
        }
        persist()
        changeLogRepository.record(
            storeId: vendor.storeId,
            entityType: "vendor",
            entityId: vendor.id,
            action: action,
            summary: vendor.name
        )
    }

    func delete(id: String) {
        let deleted = Self.sharedItems.first { $0.id == id }
        Self.sharedItems.removeAll { $0.id == id }
        persist()
        if let deleted {
            changeLogRepository.record(
                storeId: deleted.storeId,
                entityType: "vendor",
                entityId: deleted.id,
                action: "delete",
                summary: deleted.name
            )
        }
    }

    private func persist() {
        AppJSONStore.save(Self.sharedItems, key: Self.storageKey)
    }
}

private struct VendorRepositoryKey: EnvironmentKey {
    static let defaultValue: VendorRepository = MockVendorRepository()
}

extension EnvironmentValues {
    var vendorRepository: VendorRepository {
        get { self[VendorRepositoryKey.self] }
        set { self[VendorRepositoryKey.self] = newValue }
    }
}
