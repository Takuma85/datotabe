import SwiftUI

struct ExpenseReimbursementView: View {
    @EnvironmentObject private var employeeStore: EmployeeStore
    @StateObject private var viewModel = ExpenseReimbursementViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            listArea
        }
        .navigationTitle("立替精算")
        .onAppear {
            viewModel.loadList()
        }
    }

    private var header: some View {
        HStack {
            Picker("表示", selection: $viewModel.showReimbursed) {
                Text("未精算").tag(false)
                Text("精算済み").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.showReimbursed) { _, _ in
                viewModel.loadList()
            }

            Spacer()

            Button {
                viewModel.loadList()
            } label: {
                Label("再読込", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var listArea: some View {
        List {
            ForEach(viewModel.expenses) { expense in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(expense.date))
                            .font(.headline)
                        Text("立替：\(employeeStore.name(for: expense.employeeId ?? 0))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("カテゴリ：\(expense.category.label)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(formatCurrency(expense.amount))
                            .fontWeight(.semibold)
                        if expense.isReimbursed {
                            Text("精算済み")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Button("精算") {
                                viewModel.markReimbursed(expense: expense)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatCurrency(_ value: Int) -> String {
        let number = NSNumber(value: value)
        return "¥" + (Self.numberFormatter.string(from: number) ?? "\(value)")
    }

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

#Preview {
    NavigationView {
        ExpenseReimbursementView()
            .environmentObject(EmployeeStore())
    }
}
