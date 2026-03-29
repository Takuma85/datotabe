import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var mode: Mode = .monthly

    enum Mode: String, CaseIterable, Identifiable {
        case monthly = "月次"
        case daily = "日次"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("表示", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            if mode == .monthly {
                monthlyView
            } else {
                dailyView
            }
        }
        .navigationTitle("分析")
        .onAppear {
            viewModel.loadMonthly()
            viewModel.loadDaily()
        }
    }

    private var monthlyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    MonthYearPicker(title: "対象月", selection: $viewModel.month)
                    Spacer()
                    Button {
                        viewModel.loadMonthly()
                    } label: {
                        Label("再読込", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                if let message = viewModel.errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                if let report = viewModel.monthlyReport {
                    kpiSection(report: report)
                    paymentSection(report: report)
                    cogsSection(report: report)
                    cashSection(report: report)
                    laborSection(report: report)
                    breakdownSection(report: report)
                    warningSection(report: report)
                } else if viewModel.isLoadingMonthly {
                    ProgressView("読み込み中...")
                        .padding(.horizontal)
                } else {
                    Text("月次データがありません。")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 16)
        }
        .onChange(of: viewModel.month) { _, _ in
            viewModel.loadMonthly()
        }
    }

    private var dailyView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    DatePicker("開始", selection: $viewModel.fromDate, displayedComponents: .date)
                    DatePicker("終了", selection: $viewModel.toDate, displayedComponents: .date)
                }
                HStack {
                    Spacer()
                    Button {
                        viewModel.loadDaily()
                    } label: {
                        Label("再読込", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()

            if let message = viewModel.errorMessage {
                Text(message)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            List {
                Section("日次一覧") {
                    ForEach(viewModel.dailyRows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(dateFormatter.string(from: row.date))
                                    .font(.headline)
                                Spacer()
                                Text("売上 \(formatCurrency(row.salesTotalInclTax))")
                            }
                            HStack(spacing: 12) {
                                Text("原価 \(formatCurrency(row.cogsTotal))")
                                Text("原価率 \(formatPercent(row.cogsRatio))")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                Text("客数 \(row.guestCount)")
                                Text("労働 \(formatLaborHours(row.laborMinutesTotal))")
                                if let diff = row.closingDifference {
                                    Text("レジ差額 \(formatSignedCurrency(diff))")
                                        .foregroundColor(diff == 0 ? .secondary : .red)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .onChange(of: viewModel.fromDate) { _, _ in
            viewModel.loadDaily()
        }
        .onChange(of: viewModel.toDate) { _, _ in
            viewModel.loadDaily()
        }
    }

    private func kpiSection(report: AnalyticsMonthlyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("売上・客数")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                KpiCard(title: "売上合計", value: formatCurrency(report.kpi.salesTotalInclTax))
                KpiCard(title: "客数合計", value: "\(report.kpi.guestCount)")
                KpiCard(title: "客単価", value: formatCurrency(report.kpi.avgSpendPerGuest))
                KpiCard(title: "会計件数", value: "\(report.kpi.receiptCount)")
                KpiCard(title: "会計単価", value: formatCurrency(report.kpi.avgSpendPerReceipt))
                KpiCard(title: "税抜売上", value: formatCurrency(report.kpi.salesSubtotalExclTax))
            }
            .padding(.horizontal)
        }
    }

    private func paymentSection(report: AnalyticsMonthlyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("支払構成")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                paymentRow(label: "現金", amount: report.kpi.payCash, ratio: report.kpi.cashRatio)
                paymentRow(label: "カード", amount: report.kpi.payCard, ratio: report.kpi.cardRatio)
                paymentRow(label: "QR", amount: report.kpi.payQr, ratio: report.kpi.qrRatio)
                paymentRow(label: "その他", amount: report.kpi.payOther, ratio: report.kpi.otherRatio)
            }
            .padding(.horizontal)
        }
    }

    private func cogsSection(report: AnalyticsMonthlyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("原価・粗利")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                KpiCard(title: "原価合計", value: formatCurrency(report.kpi.cogsTotal))
                KpiCard(title: "粗利", value: formatCurrency(report.kpi.grossProfit))
                KpiCard(title: "原価率", value: formatPercent(report.kpi.cogsRatio))
                KpiCard(title: "粗利率", value: formatPercent(report.kpi.grossMarginRatio))
            }
            .padding(.horizontal)
        }
    }

    private func cashSection(report: AnalyticsMonthlyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("現金・監査")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                KpiCard(title: "レジ差額合計", value: formatSignedCurrency(report.kpi.closingDifferenceTotal))
                KpiCard(title: "問題日数", value: "\(report.kpi.closingIssueDays) 日")
                KpiCard(title: "銀行入金合計", value: formatCurrency(report.kpi.depositToBankTotal))
            }
            .padding(.horizontal)
        }
    }

    private func laborSection(report: AnalyticsMonthlyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("労務")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                KpiCard(title: "労働分数合計", value: "\(report.kpi.laborMinutesTotal) 分")
                KpiCard(title: "人時売上", value: formatCurrency(report.kpi.salesPerLaborHour))
            }
            .padding(.horizontal)
        }
    }

    private func breakdownSection(report: AnalyticsMonthlyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内訳")
                .font(.headline)
                .padding(.horizontal)

            breakdownList(
                title: "原価カテゴリ別",
                items: report.breakdowns.cogsByCategory
            )

            breakdownList(
                title: "経費カテゴリ別",
                items: report.breakdowns.expensesByCategory
            )

            vendorList(
                title: "取引先別支出（上位10）",
                items: report.breakdowns.expensesByVendor
            )
        }
    }

    private func warningSection(report: AnalyticsMonthlyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("警告")
                .font(.headline)
                .padding(.horizontal)

            if report.warnings.isEmpty {
                Text("警告はありません。")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(report.warnings) { warning in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(warning.message)
                                .font(.subheadline)
                            Text("差異：\(formatSignedCurrency(warning.value))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func paymentRow(label: String, amount: Int, ratio: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(formatCurrency(amount))
                Text(formatPercent(ratio))
                    .foregroundColor(.secondary)
            }
            ProgressView(value: ratio ?? 0)
        }
    }

    private func breakdownList(title: String, items: [ExpenseCategory: Int]) -> some View {
        let sorted = items.sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal)
            ForEach(sorted, id: \.key) { key, value in
                HStack {
                    Text(key.label)
                    Spacer()
                    Text(formatCurrency(value))
                }
                .padding(.horizontal)
            }
        }
    }

    private func vendorList(title: String, items: [String: Int]) -> some View {
        let sorted = items.sorted { $0.value > $1.value }.prefix(10)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal)
            ForEach(Array(sorted), id: \.key) { key, value in
                HStack {
                    Text(key)
                    Spacer()
                    Text(formatCurrency(value))
                }
                .padding(.horizontal)
            }
        }
    }

    private func formatCurrency(_ value: Int) -> String {
        let number = NSNumber(value: value)
        return "¥" + (numberFormatter.string(from: number) ?? "\(value)")
    }

    private func formatCurrency(_ value: Double?) -> String {
        guard let value else { return "-" }
        return formatCurrency(Int(value.rounded()))
    }

    private func formatSignedCurrency(_ value: Int) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(formatCurrency(abs(value)))"
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.1f%%", value * 100)
    }

    private func formatLaborHours(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60.0
        return String(format: "%.2f h", hours)
    }

    private static let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf
    }()

    private var numberFormatter: NumberFormatter { Self.numberFormatter }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }
}

private struct KpiCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
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
