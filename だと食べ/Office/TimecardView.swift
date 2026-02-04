import SwiftUI

struct TimecardView: View {
    @EnvironmentObject var employeeStore: EmployeeStore
    @Environment(\.timeRecordRepository) var timeRecordRepository

    // MARK: - 状態
    @State private var clockInAt: Date?
    @State private var clockOutAt: Date?
    @State private var breakMinutes: Int = 0
    @State private var isOnBreak: Bool = false
    @State private var lastBreakStart: Date?
    @State private var currentRecordId: UUID?

    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    // MARK: - 勤務状態

    private enum WorkState {
        case beforeWork
        case working
        case afterWork
    }

    private var workState: WorkState {
        if clockInAt == nil {
            return .beforeWork
        } else if clockOutAt == nil {
            return .working
        } else {
            return .afterWork
        }
    }

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    // MARK: - フォーマッタ

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f
    }

    // MARK: - UI 本体

    var body: some View {
        VStack(spacing: 24) {
            // 従業員選択
            VStack(alignment: .leading, spacing: 8) {
                Text("従業員")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("従業員", selection: $employeeStore.currentEmployeeId) {
                    ForEach(employeeStore.employees) { emp in
                        Text(emp.name).tag(emp.id)
                    }
                }
                .pickerStyle(.menu)

                if let emp = employeeStore.currentEmployee {
                    Text("現在の対象: \(emp.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("従業員が選択されていません")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }

            Text("打刻管理")
                .font(.title2)
                .bold()

            // 今日の打刻状況
            VStack(alignment: .leading, spacing: 8) {
                Text("本日の打刻状況")
                    .font(.headline)

                HStack {
                    Text("出勤:")
                    Spacer()
                    Text(clockInAt.map { timeFormatter.string(from: $0) } ?? "未打刻")
                }

                HStack {
                    Text("退勤:")
                    Spacer()
                    Text(clockOutAt.map { timeFormatter.string(from: $0) } ?? "未打刻")
                }

                HStack {
                    Text("休憩:")
                    Spacer()
                    Text("\(breakMinutes) 分")
                }

                HStack {
                    Text("状態:")
                    Spacer()
                    switch workState {
                    case .beforeWork:
                        Text("出勤前")
                    case .working:
                        Text(isOnBreak ? "休憩中" : "勤務中")
                    case .afterWork:
                        Text("退勤済み")
                    }
                }

                Divider()

                HStack {
                    Text("勤務時間(概算):")
                    Spacer()
                    Text(workTimeText)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // ボタンエリア
            VStack(spacing: 16) {
                switch workState {
                case .beforeWork:
                    Button {
                        handleClockIn()
                    } label: {
                        Label("出勤する", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                case .working:
                    if isOnBreak {
                        Button {
                            handleBreakEnd()
                        } label: {
                            Label("休憩終了", systemImage: "pause.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            handleBreakStart()
                        } label: {
                            Label("休憩開始", systemImage: "pause.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            handleClockOut()
                        } label: {
                            Label("退勤する", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                case .afterWork:
                    Text("本日の打刻は完了しています")
                        .foregroundColor(.secondary)

                    Button(role: .destructive) {
                        resetToday()
                    } label: {
                        Label("今日の打刻をリセット", systemImage: "arrow.counterclockwise")
                    }
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("打刻管理")
        .onAppear {
            loadTodayRecord()
        }
        .onChange(of: employeeStore.currentEmployeeId) { _ in
            loadTodayRecord()
        }
        .alert("エラー", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 勤務時間テキスト

    private var workTimeText: String {
        guard let clockInAt else { return "-" }
        let end = clockOutAt ?? Date()
        let total = end.timeIntervalSince(clockInAt) - Double(breakMinutes * 60)
        if total <= 0 { return "-" }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        return "\(hours)時間 \(minutes)分"
    }

    // MARK: - アクション

    private func handleClockIn() {
        guard clockInAt == nil else {
            showError("すでに出勤打刻済みです")
            return
        }
        guard employeeStore.currentEmployee != nil else {
            showError("従業員が選択されていません")
            return
        }

        clockInAt = Date()
        clockOutAt = nil
        breakMinutes = 0
        isOnBreak = false
        lastBreakStart = nil
        saveTodayRecord()
    }

    private func handleClockOut() {
        guard let _ = clockInAt else {
            showError("出勤打刻がありません")
            return
        }
        guard clockOutAt == nil else {
            showError("すでに退勤打刻済みです")
            return
        }
        if isOnBreak {
            showError("休憩中は退勤できません。先に休憩を終了してください。")
            return
        }

        let now = Date()
        if let clockInAt, now.timeIntervalSince(clockInAt) > 60 * 60 * 24 {
            showError("勤務時間が長すぎます。打刻内容を確認してください。")
            return
        }

        clockOutAt = now
        saveTodayRecord()
    }

    private func handleBreakStart() {
        guard let _ = clockInAt else {
            showError("出勤前です。先に出勤打刻をしてください。")
            return
        }
        guard !isOnBreak else {
            showError("すでに休憩中です")
            return
        }
        if clockOutAt != nil {
            showError("退勤後は休憩に入れません")
            return
        }

        isOnBreak = true
        lastBreakStart = Date()
        saveTodayRecord()
    }

    private func handleBreakEnd() {
        guard isOnBreak else {
            showError("現在は休憩中ではありません")
            return
        }
        guard let start = lastBreakStart else {
            isOnBreak = false
            lastBreakStart = nil
            showError("休憩開始時刻が不明です。")
            return
        }

        let now = Date()
        let interval = now.timeIntervalSince(start)
        if interval > 0 {
            breakMinutes += Int(interval / 60)
        }

        isOnBreak = false
        lastBreakStart = nil
        saveTodayRecord()
    }

    private func resetToday() {
        guard let emp = employeeStore.currentEmployee else {
            clockInAt = nil
            clockOutAt = nil
            breakMinutes = 0
            isOnBreak = false
            lastBreakStart = nil
            currentRecordId = nil
            return
        }

        timeRecordRepository.delete(employeeId: emp.id, date: today)
        clockInAt = nil
        clockOutAt = nil
        breakMinutes = 0
        isOnBreak = false
        lastBreakStart = nil
        currentRecordId = nil
    }

    // MARK: - エラー表示

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    // MARK: - Repository 永続化

    private func loadTodayRecord() {
        guard let emp = employeeStore.currentEmployee else {
            clockInAt = nil
            clockOutAt = nil
            breakMinutes = 0
            isOnBreak = false
            lastBreakStart = nil
            currentRecordId = nil
            return
        }

        if let record = timeRecordRepository.load(employeeId: emp.id, date: today) {
            currentRecordId = record.id
            clockInAt = record.clockInAt
            clockOutAt = record.clockOutAt
            breakMinutes = record.breakMinutes
            isOnBreak = record.isOnBreak
            lastBreakStart = record.lastBreakStart
        } else {
            clockInAt = nil
            clockOutAt = nil
            breakMinutes = 0
            isOnBreak = false
            lastBreakStart = nil
            currentRecordId = nil
        }
    }

    private func saveTodayRecord() {
        guard let emp = employeeStore.currentEmployee else { return }

        let id = currentRecordId ?? UUID()
        currentRecordId = id

        let record = TimeRecord(
            id: id,
            employeeId: emp.id,
            date: today,
            clockInAt: clockInAt,
            clockOutAt: clockOutAt,
            breakMinutes: breakMinutes,
            isOnBreak: isOnBreak,
            lastBreakStart: lastBreakStart
        )

        timeRecordRepository.save(record)
    }
}

#Preview {
    NavigationStack {
        TimecardView()
            .environmentObject(EmployeeStore())
            .environment(\.timeRecordRepository, UserDefaultsTimeRecordRepository())
    }
}

