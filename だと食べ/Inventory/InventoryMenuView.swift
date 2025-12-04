import SwiftUI

struct InventoryMenuView: View {
    var body: some View {
        List {
            Section("在庫数値") {
                NavigationLink("発注アラート", destination: OrderAlertView())
                NavigationLink("納品入力", destination: DeliveryInputView())
                NavigationLink("ロス入力", destination: LossInputView())
                NavigationLink("仕込入力", destination: PrepInputView())
                NavigationLink("棚卸入力", destination: StocktakeInputView())
            }
        }
        .navigationTitle("在庫数値")
    }
}

#Preview {
    NavigationStack {
        InventoryMenuView()
    }
}
