import SwiftUI

struct TimecardManagerView: View {
    @EnvironmentObject var employeeStore: EmployeeStore
    @Environment(\.timeRecordRepository) var timeRecordRepository

    @State private var records: [TimeRecord] = []

    // MARK: - フォーマッタ

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "ja_JP")
        return f
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f
    }

    // MARK: - UI

    var body: some View {
        List {
            if records.isEmpty {
                Text("打刻データがありません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(groupedDates, id: \.self) { date in
                    Section(header: Text(dateFormatter.string(from: date))) {
                        ForEach(recordsForDate(date)) { record in
                            NavigationLink {
                                TimeRecordDetailView(record: record)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(employeeStore.name(for: record.employeeId))
                                            .font(.headline)
                                        Spacer()
                                        Text("ID: \(record.employeeId)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack {
                                        Text("出勤")
                                        Spacer()
                                        Text(record.clockInAt.map { timeFormatter.string(from: $0) } ?? "未打刻")
                                    }
                                    HStack {
                                        Text("退勤")
                                        Spacer()
                                        Text(record.clockOutAt.map { timeFormatter.string(from: $0) } ?? "未打刻")
                                    }
                                    HStack {
                                        Text("休憩")
                                        Spacer()
                                        Text("\(record.breakMinutes) 分")
                                    }
                                    HStack {
                                        Text("勤務時間（概算）")
                                        Spacer()
                                        Text(workedTimeString(for: record))
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                    Text("ステータス: \(record.status.label)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("打刻一覧（店長）")
        .onAppear {
            loadAllRecords()
        }
    }

    // MARK: - Grouping

    private var groupedDates: [Date] {
        let dates = Set(records.map { $0.date })
        return dates.sorted(by: >)
    }

    private func recordsForDate(_ date: Date) -> [TimeRecord] {
        let sameDay = records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        return sameDay.sorted {
            employeeStore.name(for: $0.employeeId) < employeeStore.name(for: $1.employeeId)
        }
    }

    private func workedTimeString(for record: TimeRecord) -> String {
        guard let clockIn = record.clockInAt else { return "-" }
        let end = record.clockOutAt ?? Date()
        let total = end.timeIntervalSince(clockIn) - Double(record.breakMinutes * 60)
        let minutes = max(0, Int(total / 60))
        if minutes <= 0 { return "-" }
        let h = minutes / 60
        let m = minutes % 60
        return "\(h)時間 \(m)分"
    }

    // MARK: - Repository 読み込み

    private func loadAllRecords() {
        var loaded = timeRecordRepository.loadAll()
        loaded.sort {
            if !Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                return $0.date > $1.date
            } else {
                return employeeStore.name(for: $0.employeeId) < employeeStore.name(for: $1.employeeId)
            }
        }
        records = loaded
    }
}

#Preview {
    NavigationStack {
        TimecardManagerView()
            .environmentObject(EmployeeStore())
            .environment(\.timeRecordRepository, UserDefaultsTimeRecordRepository())
    }
}

