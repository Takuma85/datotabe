import SwiftUI

struct TaxSettingView: View {
    @Environment(\.appSettingsRepository) private var repository

    @State private var settings = TaxSettings.default(storeId: "store_1")
    @State private var policy = BusinessDatePolicy.default
    @State private var saveMessage: String?

    private let storeId = "store_1"

    var body: some View {
        Form {
            Section("消費税") {
                Picker("丸め", selection: $settings.roundingRule) {
                    ForEach(TaxRoundingRule.allCases) { rule in
                        Text(rule.label).tag(rule)
                    }
                }

                ForEach(settings.rates.indices, id: \.self) { index in
                    taxRateRow(index: index)
                }
            }

            Section("business_date") {
                Stepper(
                    "営業日切替: \(policy.normalized.dayBoundaryHour):00",
                    value: $policy.dayBoundaryHour,
                    in: 0...23
                )
            }

            if let saveMessage {
                Section {
                    Text(saveMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("税率・営業日設定")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存", action: save)
            }
        }
        .onAppear(perform: load)
    }

    private func taxRateRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(settings.rates[index].name)
                    .font(.headline)
                Spacer()
                Toggle("標準", isOn: Binding(
                    get: { settings.rates[index].isDefault },
                    set: { enabled in
                        guard enabled else { return }
                        for target in settings.rates.indices {
                            settings.rates[target].isDefault = target == index
                        }
                    }
                ))
                .labelsHidden()
            }

            Stepper(
                String(format: "税率 %.1f%%", settings.rates[index].rate * 100),
                value: $settings.rates[index].rate,
                in: 0...1,
                step: 0.01
            )
        }
        .padding(.vertical, 4)
    }

    private func load() {
        settings = repository.loadTaxSettings(storeId: storeId)
        policy = repository.loadBusinessDatePolicy(storeId: storeId)
    }

    private func save() {
        repository.saveTaxSettings(settings)
        repository.saveBusinessDatePolicy(storeId: storeId, policy: policy)
        saveMessage = "保存しました"
    }
}

#Preview {
    NavigationStack {
        TaxSettingView()
    }
}
