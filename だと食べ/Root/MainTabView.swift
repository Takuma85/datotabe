import SwiftUI

enum RootTab: Hashable {
    case order      // オーダー（座席管理）
    case inventory  // 在庫数値
    case office     // 事務
    case settings   // 設定
}

struct MainTabView: View {
    @State private var selectedTab: RootTab = .order
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // オーダー（座席管理）
            NavigationStack {
                SeatManagementView()
            }
            .tabItem {
                Label("オーダー", systemImage: "rectangle.grid.2x2")
            }
            .tag(RootTab.order)
            
            // 在庫数値
            NavigationStack {
                InventoryMenuView()
            }
            .tabItem {
                Label("在庫数値", systemImage: "shippingbox")
            }
            .tag(RootTab.inventory)
            
            // 事務
            NavigationStack {
                OfficeMenuView()
            }
            .tabItem {
                Label("事務", systemImage: "briefcase")
            }
        }
    }
}
