import Foundation
import SwiftUI

enum AccountingValidationSeverity: String, Codable {
    case info
    case warning
    case error
}

struct AccountingValidationIssue: Identifiable, Hashable, Codable {
    var id: String { "\(code)_\(message)" }
    var code: String
    var message: String
    var severity: AccountingValidationSeverity
    var value: Int?
}

struct AccountingValidationSummary: Hashable, Codable {
    var salesPaymentDifference: Int
    var debitCreditDifference: Int
    var unmappedCount: Int
    var issues: [AccountingValidationIssue]

    var warningCount: Int {
        issues.filter { $0.severity != .info }.count
    }
}

struct JournalLine: Identifiable, Hashable, Codable {
    var id: String
    var storeId: String
    var businessDate: Date
    var sourceType: String
    var debitAccount: String
    var creditAccount: String
    var amount: Int
    var memo: String
}

struct AccountingExportPreview: Hashable {
    var month: String
    var lines: [JournalLine]
    var validation: AccountingValidationSummary
    var csv: String
}

struct AccountingExportHistoryEntry: Identifiable, Hashable, Codable {
    var id: String
    var month: String
    var lineCount: Int
    var warningCount: Int
    var exportedAt: Date
}

enum TimeRecordIssueCode: String, Codable {
    case missingClockIn
    case missingClockOut
    case invalidTimeRange
    case invalidBreakMinutes
    case overwork
    case inconsistentBreakState
}

struct TimeRecordIssue: Identifiable, Hashable, Codable {
    var id: String { code.rawValue + "_" + message }
    var code: TimeRecordIssueCode
    var message: String
    var severity: AccountingValidationSeverity
}

struct TimeRecordApprovalInfo: Hashable, Codable {
    var approvedByUserId: String?
    var approvedAt: Date?
    var rejectedByUserId: String?
    var rejectedAt: Date?
    var rejectionReason: String?
}

struct TimeRecordAdminRow: Identifiable {
    var id: UUID { record.id }
    var record: TimeRecord
    var approval: TimeRecordApprovalInfo?
    var issues: [TimeRecordIssue]
}

struct AppAnalyticsKpiSnapshot: Hashable {
    var month: String
    var salesTotalInclTax: Int
    var receiptCount: Int
    var avgSpendPerReceipt: Double?
    var cogsTotal: Int
    var grossProfit: Int
    var grossMarginRatio: Double?
    var closingDifferenceTotal: Int
    var laborMinutesTotal: Int
    var salesPerLaborHour: Double?
    var warnings: [AccountingValidationIssue]
}

struct DayCutoffTime: Hashable, Codable {
    var hour: Int
    var minute: Int

    static let `default` = DayCutoffTime(hour: 5, minute: 0)
}

enum BusinessDate {
    static func resolve(at dateTime: Date, cutoff: DayCutoffTime) -> Date {
        let cal = Calendar.current
        let day = cal.startOfDay(for: dateTime)
        guard let cutoffTime = cal.date(
            bySettingHour: cutoff.hour,
            minute: cutoff.minute,
            second: 0,
            of: day
        ) else {
            return day
        }
        if dateTime < cutoffTime {
            return cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return day
    }

    static func monthRange(containing month: Date) -> (start: Date, end: Date)? {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: month)
        guard let start = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            return nil
        }
        return (cal.startOfDay(for: start), cal.startOfDay(for: end))
    }
}

enum CommonAccountingUtilities {
    static func workedMinutes(clockInAt: Date?, clockOutAt: Date?, breakMinutes: Int) -> Int {
        guard let clockInAt else { return 0 }
        let end = clockOutAt ?? clockInAt
        let total = end.timeIntervalSince(clockInAt) - Double(breakMinutes * 60)
        return max(0, Int(total / 60))
    }

    static func ratio(numerator: Double, denominator: Double) -> Double? {
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }

    static func salesPaymentMismatch(salesTotalInclTax: Int, paymentTotal: Int) -> Int {
        salesTotalInclTax - paymentTotal
    }
}

struct StoreSettings: Hashable, Codable {
    var storeId: String
    var storeName: String
    var dayCutoffTime: DayCutoffTime

    static func `default`(storeId: String) -> StoreSettings {
        StoreSettings(
            storeId: storeId,
            storeName: "だと食べ 本店",
            dayCutoffTime: .default
        )
    }
}

protocol StoreSettingsRepository {
    func load(storeId: String) -> StoreSettings
    func save(_ settings: StoreSettings)
}

final class UserDefaultsStoreSettingsRepository: StoreSettingsRepository {
    private let defaults = UserDefaults.standard
    private let keyPrefix = "store_settings_"

    func load(storeId: String) -> StoreSettings {
        let key = storageKey(storeId: storeId)
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(StoreSettings.self, from: data) {
            return decoded
        }
        let seeded = StoreSettings.default(storeId: storeId)
        save(seeded)
        return seeded
    }

    func save(_ settings: StoreSettings) {
        let key = storageKey(storeId: settings.storeId)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }

    private func storageKey(storeId: String) -> String {
        "\(keyPrefix)\(storeId)"
    }
}

private struct StoreSettingsRepositoryKey: EnvironmentKey {
    static let defaultValue: StoreSettingsRepository = UserDefaultsStoreSettingsRepository()
}

extension EnvironmentValues {
    var storeSettingsRepository: StoreSettingsRepository {
        get { self[StoreSettingsRepositoryKey.self] }
        set { self[StoreSettingsRepositoryKey.self] = newValue }
    }
}
