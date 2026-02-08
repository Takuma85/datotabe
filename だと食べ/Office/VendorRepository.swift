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
    private var items: [Vendor]

    init(seed: [Vendor] = Vendor.sample()) {
        self.items = seed
    }

    func fetchVendors(
        storeId: String,
        search: String?,
        category: VendorCategory?,
        isActive: Bool?
    ) -> [Vendor] {
        var result = items.filter { $0.storeId == storeId }

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
        items.first { $0.id == id }
    }

    func save(vendor: Vendor) {
        if let index = items.firstIndex(where: { $0.id == vendor.id }) {
            items[index] = vendor
        } else {
            items.append(vendor)
        }
    }

    func delete(id: String) {
        items.removeAll { $0.id == id }
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
