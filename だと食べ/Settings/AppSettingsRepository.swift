import Foundation
import SwiftUI

struct TaxRateSetting: Identifiable, Hashable, Codable {
    var id: String { code }

    let code: String
    var name: String
    var rate: Double
    var isDefault: Bool
}

struct TaxSettings: Hashable, Codable {
    var storeId: String
    var roundingRule: TaxRoundingRule
    var rates: [TaxRateSetting]

    var defaultRate: TaxRateSetting {
        rates.first(where: { $0.isDefault }) ?? rates.first ?? TaxSettings.default(storeId: storeId).defaultRate
    }

    static func `default`(storeId: String) -> TaxSettings {
        TaxSettings(
            storeId: storeId,
            roundingRule: .floor,
            rates: [
                TaxRateSetting(code: "standard", name: "標準税率", rate: 0.10, isDefault: true),
                TaxRateSetting(code: "reduced", name: "軽減税率", rate: 0.08, isDefault: false),
                TaxRateSetting(code: "exempt", name: "非課税", rate: 0, isDefault: false)
            ]
        )
    }
}

protocol AppSettingsRepository {
    func loadTaxSettings(storeId: String) -> TaxSettings
    func saveTaxSettings(_ settings: TaxSettings)

    func loadTimeBands(storeId: String) -> [TimeBand]
    func saveTimeBands(storeId: String, timeBands: [TimeBand])

    func loadBusinessDatePolicy(storeId: String) -> BusinessDatePolicy
    func saveBusinessDatePolicy(storeId: String, policy: BusinessDatePolicy)
}

final class UserDefaultsAppSettingsRepository: AppSettingsRepository {
    func loadTaxSettings(storeId: String) -> TaxSettings {
        let key = taxKey(storeId: storeId)
        let loaded = AppJSONStore.load(
            TaxSettings.self,
            key: key,
            fallback: TaxSettings.default(storeId: storeId)
        )
        return normalizeTaxSettings(loaded, storeId: storeId)
    }

    func saveTaxSettings(_ settings: TaxSettings) {
        AppJSONStore.save(normalizeTaxSettings(settings, storeId: settings.storeId), key: taxKey(storeId: settings.storeId))
    }

    func loadTimeBands(storeId: String) -> [TimeBand] {
        let loaded = AppJSONStore.load(
            [TimeBand].self,
            key: timeBandKey(storeId: storeId),
            fallback: Self.defaultTimeBands()
        )
        return normalizeTimeBands(loaded)
    }

    func saveTimeBands(storeId: String, timeBands: [TimeBand]) {
        AppJSONStore.save(normalizeTimeBands(timeBands), key: timeBandKey(storeId: storeId))
    }

    func loadBusinessDatePolicy(storeId: String) -> BusinessDatePolicy {
        AppJSONStore.load(
            BusinessDatePolicy.self,
            key: businessDateKey(storeId: storeId),
            fallback: BusinessDatePolicy.default
        ).normalized
    }

    func saveBusinessDatePolicy(storeId: String, policy: BusinessDatePolicy) {
        AppJSONStore.save(policy.normalized, key: businessDateKey(storeId: storeId))
    }

    static func defaultTimeBands() -> [TimeBand] {
        [
            TimeBand(code: "all_day", name: "終日", startTime: "00:00", endTime: "23:59", sortOrder: 0),
            TimeBand(code: "lunch", name: "ランチ", startTime: "11:00", endTime: "15:00", sortOrder: 10),
            TimeBand(code: "dinner", name: "ディナー", startTime: "17:00", endTime: "23:00", sortOrder: 20)
        ]
    }

    private func taxKey(storeId: String) -> String {
        "settings.tax.\(storeId).v1"
    }

    private func timeBandKey(storeId: String) -> String {
        "settings.timeBands.\(storeId).v1"
    }

    private func businessDateKey(storeId: String) -> String {
        "settings.businessDate.\(storeId).v1"
    }

    private func normalizeTaxSettings(_ settings: TaxSettings, storeId: String) -> TaxSettings {
        var rates = settings.rates
            .filter { !$0.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { rate in
                TaxRateSetting(
                    code: rate.code,
                    name: rate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? rate.code : rate.name,
                    rate: min(max(rate.rate, 0), 1),
                    isDefault: rate.isDefault
                )
            }

        if rates.isEmpty {
            rates = TaxSettings.default(storeId: storeId).rates
        }

        if !rates.contains(where: { $0.isDefault }), !rates.isEmpty {
            rates[0].isDefault = true
        } else if let defaultIndex = rates.firstIndex(where: { $0.isDefault }) {
            for index in rates.indices {
                rates[index].isDefault = index == defaultIndex
            }
        }

        return TaxSettings(storeId: storeId, roundingRule: settings.roundingRule, rates: rates)
    }

    private func normalizeTimeBands(_ timeBands: [TimeBand]) -> [TimeBand] {
        var deduped: [String: TimeBand] = [:]
        for band in timeBands {
            let code = band.code.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { continue }
            deduped[code] = TimeBand(
                code: code,
                name: band.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? code : band.name,
                startTime: normalizeTimeText(band.startTime),
                endTime: normalizeTimeText(band.endTime),
                sortOrder: band.sortOrder
            )
        }

        if deduped["all_day"] == nil {
            deduped["all_day"] = TimeBand(
                code: "all_day",
                name: "終日",
                startTime: "00:00",
                endTime: "23:59",
                sortOrder: 0
            )
        }

        return deduped.values.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.code < $1.code
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    private func normalizeTimeText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "00:00" }
        return trimmed
    }
}

private struct AppSettingsRepositoryKey: EnvironmentKey {
    static let defaultValue: AppSettingsRepository = UserDefaultsAppSettingsRepository()
}

extension EnvironmentValues {
    var appSettingsRepository: AppSettingsRepository {
        get { self[AppSettingsRepositoryKey.self] }
        set { self[AppSettingsRepositoryKey.self] = newValue }
    }
}
