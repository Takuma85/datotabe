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
    func loadSettings(storeId: String) -> [CostCategorySetting] {
        let key = storageKey(storeId: storeId)
        let decoded = AppJSONStore.load([CostCategorySetting].self, key: key, fallback: defaultSettings())
        let merged = mergeDefaultsIfNeeded(decoded)

        if merged != decoded {
            saveSettings(storeId: storeId, settings: merged)
        }
        return merged
    }

    func saveSettings(storeId: String, settings: [CostCategorySetting]) {
        AppJSONStore.save(settings, key: storageKey(storeId: storeId))
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
