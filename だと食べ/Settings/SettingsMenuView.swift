import SwiftUI

struct SettingsMenuView: View {
    var body: some View {
        List {
            Section("設定") {
                NavigationLink("メニュー設定", destination: MenuSettingView())
                NavigationLink("座席設定", destination: SeatSettingView())
                NavigationLink("税率・営業日設定", destination: TaxSettingView())
                NavigationLink("時間帯設定", destination: TimeBandSettingView())
                NavigationLink("取引先マスタ", destination: VendorListView())
                NavigationLink("仕訳マッピング", destination: AccountMappingSettingsView())
                NavigationLink("変更履歴", destination: ChangeLogView())
            }
        }
        .navigationTitle("設定")
    }
}
