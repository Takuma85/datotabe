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

private func csvEscape(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    return value
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
        }
    }
    .environment(\.monthlyReportRepository, MockMonthlyReportRepository())
}
