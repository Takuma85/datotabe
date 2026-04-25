import SwiftUI

struct AccountingExportView: View {
    @ObservedObject private var appStore = AppStore.shared

    @State private var targetMonth: Date = Date()
    @State private var preview: AccountingExportPreview?
    @State private var csvText: String = ""
    @State private var message: String?

    private let storeId = "store_1"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Form {
                    Section("対象月") {
                        MonthYearPicker(title: "月を選択", selection: $targetMonth)
                    }
                    Section {
                        Button {
                            reloadPreview()
                        } label: {
                            Label("仕訳プレビュー更新", systemImage: "arrow.clockwise")
                        }

                        Button {
                            exportCSV()
                        } label: {
                            Label("CSV出力履歴へ追加", systemImage: "tray.and.arrow.down")
                        }
                        .disabled(preview == nil)
                    }
                }
                .frame(maxHeight: 280)

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if let preview {
                    validationSection(preview.validation)
                    journalLineSection(preview.lines)
                    csvSection(csvText: preview.csv)
                } else {
                    Text("対象月を選択して仕訳プレビューを読み込んでください。")
                        .foregroundColor(.secondary)
                }

                exportHistorySection
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .navigationTitle("会計CSV出力")
        .onAppear {
            reloadPreview()
        }
        .onChange(of: targetMonth) { _, _ in
            reloadPreview()
        }
    }

    private func reloadPreview() {
        let built = appStore.buildAccountingExportPreview(storeId: storeId, month: targetMonth)
        preview = built
        csvText = built.csv
        message = nil
    }

    private func exportCSV() {
        guard let preview else { return }
        appStore.recordExportHistory(
            month: preview.month,
            lineCount: preview.lines.count,
            warningCount: preview.validation.warningCount
        )
        csvText = preview.csv
        message = "出力履歴へ記録しました（対象月: \(preview.month)、仕訳 \(preview.lines.count) 件、警告 \(preview.validation.warningCount) 件）"
    }

    @ViewBuilder
    private func validationSection(_ validation: AccountingValidationSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("出力前バリデーション")
                .font(.headline)

            Group {
                validationRow(
                    title: "売上合計 vs 決済合計",
                    value: validation.salesPaymentDifference,
                    okText: "一致"
                )
                validationRow(
                    title: "借方合計 vs 貸方合計",
                    value: validation.debitCreditDifference,
                    okText: "一致"
                )
                Text("未割当マッピング: \(validation.unmappedCount) 件")
                    .foregroundColor(validation.unmappedCount == 0 ? .secondary : .orange)
                    .font(.subheadline)
            }

            if validation.issues.isEmpty {
                Text("警告はありません。")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(validation.issues) { issue in
                    HStack {
                        Text(issue.message)
                        Spacer()
                        if let value = issue.value {
                            Text("\(value)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(issue.severity == .error ? .red : .orange)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }

    private func validationRow(title: String, value: Int, okText: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value == 0 ? okText : "\(value)")
                .foregroundColor(value == 0 ? .secondary : .orange)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func journalLineSection(_ lines: [JournalLine]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("月次仕訳一覧 (\(lines.count) 件)")
                .font(.headline)

            if lines.isEmpty {
                Text("仕訳がありません。")
                    .foregroundColor(.secondary)
            } else {
                ForEach(lines) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(dateString(line.businessDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("¥\(line.amount)")
                                .font(.subheadline)
                                .bold()
                        }
                        Text("借方: \(line.debitAccount)")
                            .font(.subheadline)
                        Text("貸方: \(line.creditAccount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(line.memo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func csvSection(csvText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CSVプレビュー")
                .font(.headline)

            ScrollView(.horizontal) {
                Text(csvText)
                    .font(.system(.footnote, design: .monospaced))
                    .padding(12)
            }
            .background(Color.gray.opacity(0.08))
            .cornerRadius(10)
        }
    }

    private var exportHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("出力履歴")
                .font(.headline)

            if appStore.exportHistories.isEmpty {
                Text("出力履歴はありません。")
                    .foregroundColor(.secondary)
            } else {
                ForEach(appStore.exportHistories) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("対象月: \(entry.month)")
                        Text("仕訳件数: \(entry.lineCount) / 警告件数: \(entry.warningCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(dateTimeString(entry.exportedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

private struct MonthYearPicker: View {
    let title: String
    @Binding var selection: Date

    private let calendar = Calendar.current

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("年", selection: Binding(
                get: { calendar.component(.year, from: selection) },
                set: { update(year: $0, month: calendar.component(.month, from: selection)) }
            )) {
                ForEach(yearRange(), id: \.self) { year in
                    Text("\(year)年").tag(year)
                }
            }
            .pickerStyle(.menu)

            Picker("月", selection: Binding(
                get: { calendar.component(.month, from: selection) },
                set: { update(year: calendar.component(.year, from: selection), month: $0) }
            )) {
                ForEach(1...12, id: \.self) { month in
                    Text("\(month)月").tag(month)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func update(year: Int, month: Int) {
        let components = DateComponents(year: year, month: month, day: 1)
        if let date = calendar.date(from: components) {
            selection = date
        }
    }

    private func yearRange() -> [Int] {
        let currentYear = calendar.component(.year, from: Date())
        return Array((currentYear - 2)...(currentYear + 1))
    }
}

#Preview {
    NavigationStack {
        AccountingExportView()
    }
}
