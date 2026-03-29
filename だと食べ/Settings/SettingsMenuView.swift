import SwiftUI

struct SettingsMenuView: View {
    var body: some View {
        List {
            Section("設定") {
                NavigationLink("メニュー設定", destination: MenuSettingView())
                NavigationLink("座席設定", destination: SeatSettingView())
                NavigationLink("取引先マスタ", destination: VendorListView())
            }
        }
        .navigationTitle("設定")
    }
}
