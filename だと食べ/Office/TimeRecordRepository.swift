//  TimeRecordRepository.swift
//「勤怠データをどう扱うか」の共通の約束!!!!!!!!!!!!!!!!
import Foundation
import SwiftUI

// MARK: - 打刻ステータス

enum TimeRecordStatus: String, Codable, CaseIterable, Identifiable {
    case draft      // まだ未承認
    case approved   // 承認済
    case rejected   // 差戻し

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft: return "下書き"
        case .approved: return "承認"
        case .rejected: return "差戻し"
        }
    }
}

// MARK: - 勤怠1件分のモデル

struct TimeRecord: Identifiable, Codable {
    let id: UUID
    let employeeId: Int
    let date: Date // 日単位（0:00 切り捨て）

    var clockInAt: Date?
    var clockOutAt: Date?
    var breakMinutes: Int
    var isOnBreak: Bool
    var lastBreakStart: Date?

    // デフォルト値付きなので、古いデータには自動で .draft が入る
    var status: TimeRecordStatus = .draft
}

// MARK: - リポジトリプロトコル

protocol TimeRecordRepository {
    /// 特定従業員・特定日付の勤怠1件を取得
    func load(employeeId: Int, date: Date) -> TimeRecord?

    /// 勤怠を保存（新規 or 上書き）
    func save(_ record: TimeRecord)

    /// 特定従業員・特定日付の勤怠削除
    func delete(employeeId: Int, date: Date)

    /// 全勤怠を取得（店長一覧・月次集計用）
    func loadAll() -> [TimeRecord]
}

// MARK: - UserDefaults 実装

final class UserDefaultsTimeRecordRepository: TimeRecordRepository {

    private let defaults = UserDefaults.standard
    private let prefix = "timeRecord_"   // timeRecord_<empId>_yyyy-MM-dd

    private lazy var dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    private func key(employeeId: Int, date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let dateString = dateKeyFormatter.string(from: day)
        return "\(prefix)\(employeeId)_\(dateString)"
    }

    /// 旧形式からのマイグレーション用
    private struct LegacyStoredTimeRecord: Codable {
        var clockInAt: Date?
        var clockOutAt: Date?
        var breakMinutes: Int
        var isOnBreak: Bool
        var lastBreakStart: Date?
    }

    // MARK: - TimeRecordRepository

    func load(employeeId: Int, date: Date) -> TimeRecord? {
        let k = key(employeeId: employeeId, date: date)
        guard let data = defaults.data(forKey: k) else { return nil }

        // 新形式を試す
        if let record = try? JSONDecoder().decode(TimeRecord.self, from: data) {
            return record
        }

        // 旧形式から変換
        if let legacy = try? JSONDecoder().decode(LegacyStoredTimeRecord.self, from: data) {
            let day = Calendar.current.startOfDay(for: date)
            return TimeRecord(
                id: UUID(),
                employeeId: employeeId,
                date: day,
                clockInAt: legacy.clockInAt,
                clockOutAt: legacy.clockOutAt,
                breakMinutes: legacy.breakMinutes,
                isOnBreak: legacy.isOnBreak,
                lastBreakStart: legacy.lastBreakStart,
                status: .draft
            )
        }

        return nil
    }

    func save(_ record: TimeRecord) {
        let k = key(employeeId: record.employeeId, date: record.date)
        do {
            let data = try JSONEncoder().encode(record)
            defaults.set(data, forKey: k)
        } catch {
            print("Failed to encode TimeRecord:", error)
        }
    }

    func delete(employeeId: Int, date: Date) {
        let k = key(employeeId: employeeId, date: date)
        defaults.removeObject(forKey: k)
    }

    func loadAll() -> [TimeRecord] {
        let dict = defaults.dictionaryRepresentation()
        var result: [TimeRecord] = []

        for (key, value) in dict {
            guard key.hasPrefix(prefix),
                  let data = value as? Data else { continue }

            // key: "timeRecord_<empId>_yyyy-MM-dd"
            let suffix = key.dropFirst(prefix.count) // "<empId>_yyyy-MM-dd"
            let parts = suffix.split(separator: "_", maxSplits: 1)
            guard parts.count == 2,
                  let empId = Int(parts[0]) else { continue }

            let dateString = String(parts[1])
            guard let date = dateKeyFormatter.date(from: dateString) else { continue }

            // 新形式優先
            if let record = try? JSONDecoder().decode(TimeRecord.self, from: data) {
                result.append(record)
                continue
            }

            // 旧形式から変換
            if let legacy = try? JSONDecoder().decode(LegacyStoredTimeRecord.self, from: data) {
                let day = Calendar.current.startOfDay(for: date)
                let record = TimeRecord(
                    id: UUID(),
                    employeeId: empId,
                    date: day,
                    clockInAt: legacy.clockInAt,
                    clockOutAt: legacy.clockOutAt,
                    breakMinutes: legacy.breakMinutes,
                    isOnBreak: legacy.isOnBreak,
                    lastBreakStart: legacy.lastBreakStart,
                    status: .draft
                )
                result.append(record)
            }
        }

        return result
    }
}

// MARK: - SwiftUI Environment

private struct TimeRecordRepositoryKey: EnvironmentKey {
    static let defaultValue: TimeRecordRepository = UserDefaultsTimeRecordRepository()
}

extension EnvironmentValues {
    var timeRecordRepository: TimeRecordRepository {
        get { self[TimeRecordRepositoryKey.self] }
        set { self[TimeRecordRepositoryKey.self] = newValue }
    }
}
