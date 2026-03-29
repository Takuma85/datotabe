import Foundation
import SwiftUI

struct CostCategorySetting: Identifiable, Hashable, Codable {
    var id: String { expenseCategory.rawValue }
    let expenseCategory: ExpenseCategory
    var isCogs: Bool
}

protocol CostCategorySettingsRepository {
    func loadSettings(storeId: String) -> [CostCategorySetting]
    func saveSettings(storeId: String, settings: [CostCategorySetting])
}

final class UserDefaultsCostCategorySettingsRepository: CostCategorySettingsRepository {
    private let defaults = UserDefaults.standard

    func loadSettings(storeId: String) -> [CostCategorySetting] {
        let key = storageKey(storeId: storeId)
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CostCategorySetting].self, from: data) {
            return mergeDefaultsIfNeeded(decoded)
        }

        let seeded = defaultSettings()
        saveSettings(storeId: storeId, settings: seeded)
        return seeded
    }

    func saveSettings(storeId: String, settings: [CostCategorySetting]) {
        let key = storageKey(storeId: storeId)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }

    private func storageKey(storeId: String) -> String {
        "costCategorySettings_\(storeId)"
    }

    private func defaultSettings() -> [CostCategorySetting] {
        ExpenseCategory.allCases.map { category in
            let isCogs = category == .food || category == .drink
            return CostCategorySetting(expenseCategory: category, isCogs: isCogs)
        }
    }

    private func mergeDefaultsIfNeeded(_ current: [CostCategorySetting]) -> [CostCategorySetting] {
        let currentMap = Dictionary(uniqueKeysWithValues: current.map { ($0.expenseCategory, $0) })
        return ExpenseCategory.allCases.map { category in
            currentMap[category] ?? CostCategorySetting(
                expenseCategory: category,
                isCogs: category == .food || category == .drink
            )
        }
    }
}

private struct CostCategorySettingsRepositoryKey: EnvironmentKey {
    static let defaultValue: CostCategorySettingsRepository = UserDefaultsCostCategorySettingsRepository()
}

extension EnvironmentValues {
    var costCategorySettingsRepository: CostCategorySettingsRepository {
        get { self[CostCategorySettingsRepositoryKey.self] }
        set { self[CostCategorySettingsRepositoryKey.self] = newValue }
    }
}
