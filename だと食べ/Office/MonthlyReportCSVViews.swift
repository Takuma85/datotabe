import SwiftUI

struct MonthlySummaryCSVView: View {
    @Environment(\.monthlyReportRepository) var repository

    @State private var targetMonth: Date = Date()
    @State private var csvText: String = ""
    @State private var errorMessage: String?

    private let storeId: String = "store_1"

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("対象月") {
                    MonthYearPicker(
                        title: "月を選択",
                        selection: $targetMonth
                    )
                }

                Section {
                    Button {
                        Task { await generateCSV() }
                    } label: {
                        Label("月次サマリCSVを生成", systemImage: "doc.badge.plus")
                    }
                }
            }
            .frame(maxHeight: 260)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            if !csvText.isEmpty {
                Text("プレビュー")
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
        .navigationTitle("月次サマリCSV")
    }

    private func generateCSV() async {
        errorMessage = nil
        do {
            let summary = try await repository.fetchMonthlySummary(storeId: storeId, month: targetMonth)
            csvText = buildSummaryCSV(summary: summary)
        } catch {
            errorMessage = "CSV生成に失敗しました。"
            csvText = ""
        }
    }

    private func buildSummaryCSV(summary: MonthlySummary) -> String {
        let header = [
            "year_month",
            "store_id",
            "store_name",
            "sales_total_incl_tax",
            "sales_cash_incl_tax",
            "sales_card_incl_tax",
            "sales_qr_incl_tax",
            "sales_other_incl_tax",
            "sales_subtotal_excl_tax",
            "sales_tax_total",
            "expenses_total",
            "expenses_food",
            "expenses_drink",
            "expenses_consumable",
            "expenses_utility",
            "expenses_misc",
            "cash_in_total",
            "cash_out_total",
            "cash_out_purchase_total",
            "cash_out_reimburse_total",
            "cash_out_deposit_to_bank_total",
            "closing_difference_total",
            "closing_issue_days"
        ]

        let row: [String] = [
            summary.yearMonth,
            summary.storeId,
            summary.storeName,
            "\(summary.salesTotalInclTax)",
            "\(summary.salesCashInclTax)",
            "\(summary.salesCardInclTax)",
            "\(summary.salesQrInclTax)",
            "\(summary.salesOtherInclTax)",
            "\(summary.salesSubtotalExclTax)",
            "\(summary.salesTaxTotal)",
            "\(summary.expensesTotal)",
            "\(summary.expensesFood)",
            "\(summary.expensesDrink)",
            "\(summary.expensesConsumable)",
            "\(summary.expensesUtility)",
            "\(summary.expensesMisc)",
            "\(summary.cashInTotal)",
            "\(summary.cashOutTotal)",
            "\(summary.cashOutPurchaseTotal)",
            "\(summary.cashOutReimburseTotal)",
            "\(summary.cashOutDepositToBankTotal)",
            "\(summary.closingDifferenceTotal)",
            "\(summary.closingIssueDays)"
        ].map(csvEscape)

        return ([header.map(csvEscape).joined(separator: ","), row.joined(separator: ",")]).joined(separator: "\n")
    }
}

struct MonthlyDailyCSVView: View {
    @Environment(\.monthlyReportRepository) var repository

    @State private var targetMonth: Date = Date()
    @State private var csvText: String = ""
    @State private var errorMessage: String?

    private let storeId: String = "store_1"

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("対象月") {
                    MonthYearPicker(
                        title: "月を選択",
                        selection: $targetMonth
                    )
                }

                Section {
                    Button {
                        Task { await generateCSV() }
                    } label: {
                        Label("月次日別CSVを生成", systemImage: "doc.badge.plus")
                    }
                }
            }
            .frame(maxHeight: 260)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            if !csvText.isEmpty {
                Text("プレビュー")
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
        .navigationTitle("月次日別CSV")
    }

    private func generateCSV() async {
        errorMessage = nil
        do {
            let daily = try await repository.fetchMonthlyDaily(storeId: storeId, month: targetMonth)
            csvText = buildDailyCSV(items: daily)
        } catch {
            errorMessage = "CSV生成に失敗しました。"
            csvText = ""
        }
    }

    private func buildDailyCSV(items: [MonthlyDaily]) -> String {
        let header = [
            "date",
            "store_id",
            "store_name",
            "sales_total_incl_tax",
            "sales_subtotal_excl_tax",
            "sales_tax_total",
            "sales_cash_incl_tax",
            "sales_card_incl_tax",
            "sales_qr_incl_tax",
            "sales_other_incl_tax",
            "expenses_total",
            "cash_in_total",
            "cash_out_total",
            "expected_cash_balance",
            "actual_cash_balance",
            "difference",
            "issue_flag"
        ]

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "ja_JP")

        var lines: [String] = []
        lines.append(header.map(csvEscape).joined(separator: ","))

        for item in items {
            let row: [String] = [
                df.string(from: item.date),
                item.storeId,
                item.storeName,
                "\(item.salesTotalInclTax)",
                "\(item.salesSubtotalExclTax)",
                "\(item.salesTaxTotal)",
                "\(item.salesCashInclTax)",
                "\(item.salesCardInclTax)",
                "\(item.salesQrInclTax)",
                "\(item.salesOtherInclTax)",
                "\(item.expensesTotal)",
                "\(item.cashInTotal)",
                "\(item.cashOutTotal)",
                item.expectedCashBalance.map { "\($0)" } ?? "",
                item.actualCashBalance.map { "\($0)" } ?? "",
                item.closingDifference.map { "\($0)" } ?? "",
                item.closingIssueFlag.map { $0 ? "true" : "false" } ?? ""
            ].map(csvEscape)
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }
}

struct AccountMappingSettingsView: View {
    @Environment(\.monthlyReportRepository) var repository

    @State private var mappings: [AccountMapping] = []
    @State private var message: String?
    @State private var isError: Bool = false

    private let storeId: String = "store_1"

    var body: some View {
        Form {
            Section("店舗") {
                Text("store_id: \(storeId)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            ForEach(AccountMappingType.allCases, id: \.self) { type in
                Section(type.label) {
                    let rows = indexedMappings(for: type)
                    if rows.isEmpty {
                        Text("該当マッピングがありません。")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(rows) { row in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(row.mapping.mappingKey)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                TextField(
                                    "借方コード",
                                    text: Binding(
                                        get: { mappings[row.index].debitAccountCode ?? "" },
                                        set: { mappings[row.index].debitAccountCode = $0.nilIfEmpty }
                                    )
                                )
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                TextField(
                                    "貸方コード",
                                    text: Binding(
                                        get: { mappings[row.index].creditAccountCode ?? "" },
                                        set: { mappings[row.index].creditAccountCode = $0.nilIfEmpty }
                                    )
                                )
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                TextField(
                                    "税区分コード（任意）",
                                    text: Binding(
                                        get: { mappings[row.index].taxCode ?? "" },
                                        set: { mappings[row.index].taxCode = $0.nilIfEmpty }
                                    )
                                )
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                Toggle(
                                    "有効",
                                    isOn: Binding(
                                        get: { mappings[row.index].isActive },
                                        set: { mappings[row.index].isActive = $0 }
                                    )
                                )
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("マッピングを保存", systemImage: "tray.and.arrow.down")
                }
            }
        }
        .navigationTitle("仕訳マッピング")
        .onAppear {
            loadMappings()
        }
        .safeAreaInset(edge: .bottom) {
            if let message = message {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(isError ? .red : .secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
        }
    }

    private func indexedMappings(for type: AccountMappingType) -> [IndexedMapping] {
        mappings.enumerated().compactMap { index, mapping in
            guard mapping.mappingType == type else { return nil }
            return IndexedMapping(index: index, mapping: mapping)
        }
    }

    private func loadMappings() {
        mappings = repository.fetchAccountMappings(storeId: storeId)
    }

    private func save() {
        repository.saveAccountMappings(storeId: storeId, mappings: mappings)
        loadMappings()
        isError = false
        message = "保存しました。"
    }
}

private struct IndexedMapping: Identifiable {
    let index: Int
    let mapping: AccountMapping
    var id: String { mapping.id }
}

struct JournalGenerateView: View {
    @Environment(\.monthlyReportRepository) var repository

    @State private var fromDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var toDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var result: JournalGenerationResult?
    @State private var errorMessage: String?

    private let storeId: String = "store_1"
    private let userId: String = "manager_1"

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        VStack(spacing: 12) {
            Form {
                Section("対象期間") {
                    DatePicker("開始日", selection: $fromDate, displayedComponents: .date)
                    DatePicker("終了日", selection: $toDate, displayedComponents: .date)
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        Label("日次仕訳を生成", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .frame(maxHeight: 220)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            if let result = result {
                VStack(alignment: .leading, spacing: 8) {
                    Text("生成件数: \(result.generatedEntries)")
                    Text("更新件数: \(result.replacedEntries)")
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                if !result.warningMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("警告")
                            .font(.headline)
                        ForEach(result.warningMessages, id: \.self) { warning in
                            Text("・\(warning)")
                                .font(.footnote)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                if !result.previewEntries.isEmpty {
                    Text("プレビュー")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    List(result.previewEntries, id: \.id) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayFormatter.string(from: entry.businessDate))
                                .fontWeight(.semibold)
                            Text("lines: \(entry.lines.count) / status: \(entry.status.rawValue)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("仕訳生成の結果がここに表示されます。")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .navigationTitle("仕訳生成")
    }

    private func generate() {
        errorMessage = nil
        do {
            result = try repository.generateJournals(
                storeId: storeId,
                from: fromDate,
                to: toDate,
                createdByUserId: userId
            )
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }
}

struct JournalCSVExportView: View {
    @Environment(\.monthlyReportRepository) var repository

    @State private var fromDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var toDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var csvText: String = ""
    @State private var errorMessage: String?

    private let storeId: String = "store_1"

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("対象期間") {
                    DatePicker("開始日", selection: $fromDate, displayedComponents: .date)
                    DatePicker("終了日", selection: $toDate, displayedComponents: .date)
                }

                Section {
                    Button {
                        exportCSV()
                    } label: {
                        Label("仕訳CSVを生成", systemImage: "doc.badge.plus")
                    }
                }
            }
            .frame(maxHeight: 220)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            if !csvText.isEmpty {
                Text("プレビュー")
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
        .navigationTitle("仕訳CSV")
    }

    private func exportCSV() {
        errorMessage = nil
        do {
            csvText = try repository.exportJournalsCSV(
                storeId: storeId,
                from: fromDate,
                to: toDate
            )
        } catch {
            csvText = ""
            errorMessage = error.localizedDescription
        }
    }
}

private func csvEscape(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    return value
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
        List {
            NavigationLink("月次サマリCSV", destination: MonthlySummaryCSVView())
            NavigationLink("月次日別CSV", destination: MonthlyDailyCSVView())
            NavigationLink("仕訳マッピング", destination: AccountMappingSettingsView())
            NavigationLink("仕訳生成", destination: JournalGenerateView())
            NavigationLink("仕訳CSV", destination: JournalCSVExportView())
        }
    }
    .environment(\.monthlyReportRepository, MockMonthlyReportRepository())
}
