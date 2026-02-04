import SwiftUI

struct DailyReportView: View {

    @StateObject private var viewModel = DailyReportViewModel()

    // 差戻し理由用（簡易）
    @State private var rejectReason: String = "内容を確認してください"

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // 絞り込み & 操作用エリア
                filterArea

                Divider()

                // 一覧 + 詳細
                contentArea
            }
            .navigationTitle("日報")
        }
        .onAppear {
            viewModel.loadList()
        }
        .alert(isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { flag in
                if !flag { viewModel.errorMessage = nil }
            })
        ) {
            Alert(
                title: Text("エラー"),
                message: Text(viewModel.errorMessage ?? "不明なエラー"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - 上部のフィルター & ボタン

    private var filterArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DatePicker(
                    "開始",
                    selection: $viewModel.fromDate,
                    displayedComponents: .date
                )
                DatePicker(
                    "終了",
                    selection: $viewModel.toDate,
                    displayedComponents: .date
                )
            }

            HStack {
                Picker("ステータス", selection: Binding(
                    get: { viewModel.selectedStatus },
                    set: { viewModel.selectedStatus = $0 }
                )) {
                    Text("すべて").tag(DailyReport.Status?.none)
                    ForEach(DailyReport.Status.allCases, id: \.self) { status in
                        Text(label(for: status)).tag(DailyReport.Status?.some(status))
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Button {
                    viewModel.loadList()
                } label: {
                    Label("再読込", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button {
                    // とりあえず「終了日」の日報を自動作成
                    viewModel.generate(for: viewModel.toDate)
                } label: {
                    Label("この日の日報を自動作成", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button {
                    viewModel.exportCSV(profileCode: "default")
                } label: {
                    Label("CSV出力", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    // MARK: - 一覧 & 詳細

    private var contentArea: some View {
        HStack(spacing: 0) {
            // 左側：一覧
            listArea
                .frame(minWidth: 260, maxWidth: 320)

            Divider()

            // 右側：詳細
            detailArea
        }
    }

    private var listArea: some View {
        List(selection: Binding(
            get: { viewModel.selectedReport?.id },
            set: { id in
                if let id = id,
                   let report = viewModel.reports.first(where: { $0.id == id }) {
                    viewModel.select(report: report)
                }
            })
        ) {
            ForEach(viewModel.reports) { report in
                Button {
                    viewModel.select(report: report)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatDate(report.date))
                                .font(.headline)
                            Text("売上合計：\(formatCurrency(report.total.totalSales))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(label(for: report.status))
                            .font(.caption)
                            .padding(4)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("読み込み中…")
            } else if viewModel.reports.isEmpty {
                Text("対象期間の日報がありません")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var detailArea: some View {
        Group {
            if let report = viewModel.selectedReport {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // 基本情報
                        GroupBox("基本情報") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("日付：\(formatDate(report.date))")
                                Text("ステータス：\(label(for: report.status))")
                                Text("店舗ID：\(report.storeId)")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 1日トータル
                        GroupBox("1日トータル") {
                            segmentView(report.total)
                        }

                        // 時間帯別
                        GroupBox("時間帯別内訳") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(report.segments) { seg in
                                    if seg.timeBandCode != "all_day" {
                                        Divider()
                                    }
                                    segmentRow(seg)
                                }
                            }
                        }

                        // コメント
                        if let notes = report.notes, !notes.isEmpty {
                            GroupBox("メモ") {
                                Text(notes)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let issues = report.issueNotes, !issues.isEmpty {
                            GroupBox("トラブル・課題") {
                                Text(issues)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // 操作ボタン
                        GroupBox("ステータス操作") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button("提出") {
                                        viewModel.submitSelected()
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Button("承認") {
                                        viewModel.approveSelected()
                                    }
                                    .buttonStyle(.bordered)

                                    Button("差戻し") {
                                        viewModel.rejectSelected(reason: rejectReason)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }

                                TextField("差戻し理由", text: $rejectReason)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        // CSV共有（モック）
                        if let url = viewModel.exportedCSVURL {
                            GroupBox("CSVファイル") {
                                Text("出力済みCSV：\(url.lastPathComponent)")
                                    .font(.footnote)
                                ShareLink("CSVを共有", item: url)
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Text("左の一覧から日報を選択してください")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - 小さいビュー部品

    private func segmentView(_ seg: DailyReportSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("売上合計：\(formatCurrency(seg.totalSales))")
                Spacer()
                Text("客数：\(seg.guestCount)名")
            }
            HStack {
                Text("現金：\(formatCurrency(seg.cashSales))")
                Text("カード：\(formatCurrency(seg.cardSales))")
                Text("QR：\(formatCurrency(seg.qrSales))")
            }
            .font(.footnote)

            HStack {
                Text("会計件数：\(seg.tableCount)件")
                Text("客単価：\(formatCurrency(seg.averageSpend))")
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func segmentRow(_ seg: DailyReportSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(seg.timeBandName)
                .font(.headline)
            segmentView(seg)
        }
    }

    // MARK: - フォーマット系

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatCurrency(_ value: Int) -> String {
        let number = NSNumber(value: value)
        return "¥" + (Self.numberFormatter.string(from: number) ?? "\(value)")
    }

    private func label(for status: DailyReport.Status) -> String {
        switch status {
        case .draft: return "下書き"
        case .submitted: return "提出済み"
        case .approved: return "承認済み"
        case .rejected: return "差戻し"
        }
    }

    // MARK: - フォーマッタ

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private static let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf
    }()
}

// プレビュー（任意）
struct DailyReportView_Previews: PreviewProvider {
    static var previews: some View {
        DailyReportView()
    }
}

