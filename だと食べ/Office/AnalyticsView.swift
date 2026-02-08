import SwiftUI

struct AnalyticsView: View {
    @Environment(\.vendorRepository) private var vendorRepository
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var targetMonth: Date = Date()

    var body: some View {
        List {
            Section("対象月") {
                MonthYearPicker(
                    title: "月を選択",
                    selection: $targetMonth
                )
            }

            Section("取引先別支出（上位）") {
                ForEach(viewModel.topVendors) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.vendorName)
                                .font(.headline)
                            Text("件数: \(item.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(formatCurrency(item.amount))
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("分析")
        .onAppear { reload() }
        .onChange(of: targetMonth) { _, _ in reload() }
    }

    private func reload() {
        viewModel.load(month: targetMonth, vendorRepository: vendorRepository)
    }

    private func formatCurrency(_ value: Int) -> String {
        let number = NSNumber(value: value)
        return "¥" + (Self.numberFormatter.string(from: number) ?? "\(value)")
    }

    private static let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf
    }()
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

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var topVendors: [VendorSpendItem] = []
    @Published private(set) var expenses: [Expense] = []

    let storeId: String = "store_1"
    private let expenseRepository: ExpenseRepository

    init(expenseRepository: ExpenseRepository = MockExpenseRepository()) {
        self.expenseRepository = expenseRepository
    }

    func load(month: Date, vendorRepository: VendorRepository) {
        let range = monthRange(for: month)
        let items = expenseRepository.fetchExpenses(
            storeId: storeId,
            from: range.start,
            to: range.end,
            category: nil,
            paymentMethod: nil,
            reimbursed: nil,
            status: .approved,
            employeeId: nil
        )
        expenses = items

        var grouped: [String: VendorSpendItem] = [:]

        for expense in items {
            let vendorName: String
            let key: String

            if let vendorId = expense.vendorId,
               let vendor = vendorRepository.findById(vendorId) {
                vendorName = vendor.name
                key = "vendor:\(vendorId)"
            } else if let raw = expense.vendorNameRaw, !raw.isEmpty {
                vendorName = raw
                key = "raw:\(raw)"
            } else {
                vendorName = "未紐付け"
                key = "unknown"
            }

            var item = grouped[key] ?? VendorSpendItem(
                id: key,
                vendorName: vendorName,
                amount: 0,
                count: 0
            )
            item.amount += expense.amount
            item.count += 1
            grouped[key] = item
        }

        topVendors = grouped.values
            .sorted { $0.amount > $1.amount }
            .prefix(10)
            .map { $0 }
    }

    private func monthRange(for date: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        let start = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? date
        let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? date
        return (cal.startOfDay(for: start), cal.startOfDay(for: end))
    }
}

struct VendorSpendItem: Identifiable, Hashable {
    let id: String
    let vendorName: String
    var amount: Int
    var count: Int
}
