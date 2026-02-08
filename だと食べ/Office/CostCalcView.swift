import SwiftUI

struct CostCalcView: View {
    @StateObject private var viewModel = CostCalcViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsSection
                monthlySection
                dailySection
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("原価計算")
        .onAppear {
            viewModel.loadMonthly()
            viewModel.loadDaily()
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("原価カテゴリ設定")
                .font(.headline)
                .padding(.horizontal)

            ForEach($viewModel.settings) { $setting in
                Toggle(isOn: $setting.isCogs) {
                    Text(setting.expenseCategory.label)
                }
                .padding(.horizontal)
                .onChange(of: setting.isCogs) { _, _ in
                    viewModel.saveSettings()
                    viewModel.loadMonthly()
                    viewModel.loadDaily()
                }
            }
        }
    }

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            if let report = viewModel.monthlyReport {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    KpiCard(title: "売上", value: formatCurrency(report.kpi.salesTotalInclTax))
                    KpiCard(title: "原価", value: formatCurrency(report.kpi.cogsTotal))
                    KpiCard(title: "粗利", value: formatCurrency(report.kpi.grossProfit))
                    KpiCard(title: "原価率", value: formatPercent(report.kpi.cogsRatio))
                    KpiCard(title: "粗利率", value: formatPercent(report.kpi.grossMarginRatio))
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 6) {
                    Text("原価内訳")
                        .font(.subheadline)
                        .padding(.horizontal)
                    let sorted = report.breakdowns.cogsByCategory.sorted { $0.value > $1.value }
                    ForEach(sorted, id: \.key) { key, value in
                        HStack {
                            Text(key.label)
                            Spacer()
                            Text(formatCurrency(value))
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                Text("月次データがありません。")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .onChange(of: viewModel.month) { _, _ in
            viewModel.loadMonthly()
        }
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日次一覧")
                .font(.headline)
                .padding(.horizontal)

            HStack {
                DatePicker("開始", selection: $viewModel.fromDate, displayedComponents: .date)
                DatePicker("終了", selection: $viewModel.toDate, displayedComponents: .date)
                Spacer()
                Button {
                    viewModel.loadDaily()
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

            ForEach(viewModel.dailyRows) { row in
                VStack(alignment: .leading, spacing: 4) {
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
                }
                .padding(.horizontal)
                Divider()
                    .padding(.horizontal)
            }
        }
        .onChange(of: viewModel.fromDate) { _, _ in
            viewModel.loadDaily()
        }
        .onChange(of: viewModel.toDate) { _, _ in
            viewModel.loadDaily()
        }
    }

    private func formatCurrency(_ value: Int) -> String {
        let number = NSNumber(value: value)
        return "¥" + (numberFormatter.string(from: number) ?? "\(value)")
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.1f%%", value * 100)
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

