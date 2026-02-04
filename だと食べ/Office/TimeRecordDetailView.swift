//
//  TimeRecordDetailView.swift
//  だと食べ
import SwiftUI

struct TimeRecordDetailView: View {
    @EnvironmentObject var employeeStore: EmployeeStore
    @Environment(\.timeRecordRepository) var timeRecordRepository
    @Environment(\.dismiss) var dismiss

    @State private var record: TimeRecord

    init(record: TimeRecord) {
        _record = State(initialValue: record)
    }

    // 勤務時間（分）→ 表示文字列
    private var workedTimeText: String {
        guard let clockIn = record.clockInAt else { return "-" }
        let end = record.clockOutAt ?? Date()
        let total = end.timeIntervalSince(clockIn) - Double(record.breakMinutes * 60)
        let minutes = max(0, Int(total / 60))
        if minutes <= 0 { return "-" }
        let h = minutes / 60
        let m = minutes % 60
        return "\(h)時間 \(m)分"
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "ja_JP")
        return f
    }

    var body: some View {
        Form {
            Section("基本情報") {
                HStack {
                    Text("従業員")
                    Spacer()
                    Text(employeeStore.name(for: record.employeeId))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("日付")
                    Spacer()
                    Text(dateFormatter.string(from: record.date))
                        .foregroundColor(.secondary)
                }

                Picker("ステータス", selection: $record.status) {
                    ForEach(TimeRecordStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }
            }

            Section("打刻修正") {
                // nil の場合はとりあえず 9:00 / 18:00 を初期値にする
                DatePicker(
                    "出勤",
                    selection: Binding(
                        get: {
                            record.clockInAt ?? defaultTime(hour: 9)
                        },
                        set: { newValue in
                            record.clockInAt = newValue
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )

                DatePicker(
                    "退勤",
                    selection: Binding(
                        get: {
                            record.clockOutAt ?? defaultTime(hour: 18)
                        },
                        set: { newValue in
                            record.clockOutAt = newValue
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )

                Stepper(
                    "休憩 \(record.breakMinutes) 分",
                    value: $record.breakMinutes,
                    in: 0...600,
                    step: 5
                )
            }

            Section("勤務時間") {
                HStack {
                    Text("勤務時間(概算)")
                    Spacer()
                    Text(workedTimeText)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("打刻修正＆承認")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                    dismiss()
                }
            }
        }
    }

    private func defaultTime(hour: Int) -> Date {
        let cal = Calendar.current
        let base = cal.startOfDay(for: record.date)
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
    }

    private func save() {
        // ここでバリデーションしてもOK（退勤 < 出勤 など）
        timeRecordRepository.save(record)
    }
}

#Preview {
    NavigationStack {
        TimeRecordDetailView(
            record: TimeRecord(
                id: UUID(),
                employeeId: 1,
                date: Calendar.current.startOfDay(for: Date()),
                clockInAt: Date(),
                clockOutAt: Calendar.current.date(byAdding: .hour, value: 8, to: Date()),
                breakMinutes: 60,
                isOnBreak: false,
                lastBreakStart: nil,
                status: .draft
            )
        )
        .environmentObject(EmployeeStore())
        .environment(\.timeRecordRepository, UserDefaultsTimeRecordRepository())
    }
}

//  Created by Hirasawa Joichiro on 2026/02/04.
//

