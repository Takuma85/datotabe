import SwiftUI
//打刻管理画面
struct TimecardView: View {
    // 出勤・退勤・休憩の状態管理（とりあえずローカル）
    @State private var clockInAt: Date?
    @State private var clockOutAt: Date?
    @State private var breakMinutes: Int = 0  // v1ではまだ手入力でもOK
    
    // 画面上の状態をざっくり管理
    private enum WorkState {
        case beforeWork   // 出勤前
        case working      // 勤務中
        case afterWork    // 退勤済み
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

        // 日付表示用フォーマッタ
        private var timeFormatter: DateFormatter {
            let f = DateFormatter()
            f.dateStyle = .none
            f.timeStyle = .short
            return f
        }

        var body: some View {
            VStack(spacing: 24) {
                Text("打刻管理")
                    .font(.title2)
                    .bold()

                // 今日の状態表示
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
                        Button {
                            handleClockOut()
                        } label: {
                            Label("退勤する", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        // v1では休憩はあとで実装でもOK
                        // Button("休憩開始") { ... }

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
        }

        // MARK: - ロジック

        private var workTimeText: String {
            guard let clockInAt else { return "-" }
            let end = clockOutAt ?? Date()
            let total = end.timeIntervalSince(clockInAt) - Double(breakMinutes * 60)
            if total <= 0 {
                return "-"
            }
            let hours = Int(total) / 3600
            let minutes = (Int(total) % 3600) / 60
            return String(format: "%d時間 %d分", hours, minutes)
        }

        private func handleClockIn() {
            // すでに出勤済みなら何もしない（本番はアラート出しても良い）
            guard clockInAt == nil else { return }
            clockInAt = Date()
            clockOutAt = nil
            breakMinutes = 0
        }

        private func handleClockOut() {
            guard clockInAt != nil else { return }
            // すでに退勤済みなら何もしない
            guard clockOutAt == nil else { return }
            clockOutAt = Date()
        }

        private func resetToday() {
            clockInAt = nil
            clockOutAt = nil
            breakMinutes = 0
        }
    }

    #Preview {
        NavigationStack {
            TimecardView()
        }
    }
