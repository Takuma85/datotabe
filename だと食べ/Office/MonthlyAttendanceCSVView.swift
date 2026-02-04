//
//  MonthlyAttendanceCSVView.swift
//  だと食べ
import SwiftUI

struct MonthlyAttendanceCSVView: View {
    @Environment(\.timeRecordRepository) var timeRecordRepository
    @EnvironmentObject var employeeStore: EmployeeStore

    @State private var targetMonth: Date = Date()
    @State private var csvText: String = ""

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy年MM月"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("対象月") {
                    DatePicker(
                        "月を選択",
                        selection: $targetMonth,
                        displayedComponents: [.date]
                    )
                }

                Section {
                    Button {
                        generateCSV()
                    } label: {
                        Label("CSVを生成", systemImage: "doc.badge.plus")
                    }
                }
            }
            .frame(maxHeight: 260)

            if !csvText.isEmpty {
                Text("プレビュー (\(monthFormatter.string(from: targetMonth)))")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView {
                    Text(csvText)
                        .font(.system(.footnote, design: .monospaced))
                        .padding()
                }
            } else {
                Text("CSVを生成するとここに表示されます。")
                    .foregroundColor(.secondary)
                    .padding()
            }

            Spacer()
        }
        .navigationTitle("勤怠 月次CSV")
    }

    // MARK: - CSV 生成

    private func generateCSV() {
        let all = timeRecordRepository.loadAll()
        let cal = Calendar.current

        let year = cal.component(.year, from: targetMonth)
        let month = cal.component(.month, from: targetMonth)

        // 対象月のみに絞る
        let filtered = all.filter { record in
            let cYear = cal.component(.year, from: record.date)
            let cMonth = cal.component(.month, from: record.date)
            return cYear == year && cMonth == month
        }

        // 日付 & 従業員名順
        let sorted = filtered.sorted { a, b in
            if a.date != b.date {
                return a.date < b.date
            }
            let nameA = employeeStore.name(for: a.employeeId)
            let nameB = employeeStore.name(for: b.employeeId)
            return nameA < nameB
        }

        var lines: [String] = []
        lines.append("employeeId,employeeName,date,clockIn,clockOut,breakMinutes,workedMinutes,workedHours,status")

        let dateF = DateFormatter()
        dateF.dateFormat = "yyyy-MM-dd"
        dateF.locale = Locale(identifier: "ja_JP")

        let timeF = DateFormatter()
        timeF.dateFormat = "HH:mm"
        timeF.locale = Locale(identifier: "ja_JP")

        for r in sorted {
            let empName = employeeStore.name(for: r.employeeId)
            let dateStr = dateF.string(from: r.date)
            let clockInStr = r.clockInAt.map { timeF.string(from: $0) } ?? ""
            let clockOutStr = r.clockOutAt.map { timeF.string(from: $0) } ?? ""

            let workedMinutes = calcWorkedMinutes(for: r)
            let workedHours = String(format: "%.2f", Double(workedMinutes) / 60.0)

            let line = [
                "\(r.employeeId)",
                "\"\(empName)\"",
                dateStr,
                clockInStr,
                clockOutStr,
                "\(r.breakMinutes)",
                "\(workedMinutes)",
                workedHours,
                r.status.rawValue
            ].joined(separator: ",")

            lines.append(line)
        }

        csvText = lines.joined(separator: "\n")
    }

    private func calcWorkedMinutes(for record: TimeRecord) -> Int {
        guard let clockIn = record.clockInAt else { return 0 }
        let end = record.clockOutAt ?? clockIn
        let total = end.timeIntervalSince(clockIn) - Double(record.breakMinutes * 60)
        return max(0, Int(total / 60))
    }
}

#Preview {
    NavigationStack {
        MonthlyAttendanceCSVView()
            .environmentObject(EmployeeStore())
            .environment(\.timeRecordRepository, UserDefaultsTimeRecordRepository())
    }
}

//  Created by Hirasawa Joichiro on 2026/02/04.
//

