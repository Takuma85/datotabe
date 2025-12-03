import SwiftUIA

// =====================
// 1) 機能の列挙 (Feature enum)
// =====================
enum Feature: String, Identifiable, CaseIterable {
    case order
    case checkout
    case self_qr
    case others
    case order_alert
    case delivery
    case loss_input
    case prep_input
    case stocktake_input
    case daily_report
    case analytics
    case cash_flow
    case slip_detail
    case timecard
    case cost
    case menu_set
    case seat_set

    var id: String { rawValue }

    var label: String {
        switch self {
        case .order:            return "注文"
        case .checkout:         return "会計"
        case .self_qr:          return "QR出力"
        case .others:           return "その他"
        case .order_alert:      return "発注アラート"
        case .delivery:         return "納品入力"
        case .loss_input:       return "ロス入力"
        case .prep_input:       return "仕込入力"
        case .stocktake_input:  return "棚卸入力"
        case .daily_report:     return "日報"
        case .analytics:        return "分析"
        case .cash_flow:        return "入出金"
        case .slip_detail:      return "伝票明細"
        case .timecard:         return "打刻管理"
        case .cost:             return "原価計算"
        case .menu_set:         return "メニュー設定"
        case .seat_set:         return "座席設定"
        }
    }

    /// SF Symbols 名（環境に合わせて調整してOK）
    var iconName: String {
        switch self {
        case .order:            return "fork.knife"
        case .checkout:         return "creditcard"
        case .self_qr:          return "qrcode"
        case .others:           return "ellipsis"
        case .order_alert:      return "exclamationmark.triangle"
        case .delivery:         return "truck.box"
        case .loss_input:       return "trash"
        case .prep_input:       return "takeoutbag.and.cup.and.straw" // なければ "bag" とかに変更
        case .stocktake_input:  return "checklist"
        case .daily_report:     return "doc.text"
        case .analytics:        return "chart.bar.xaxis"
        case .cash_flow:        return "yensign.circle"
        case .slip_detail:      return "doc.plaintext"
        case .timecard:         return "clock.badge.checkmark"
        case .cost:             return "function"
        case .menu_set:         return "list.bullet"
        case .seat_set:         return "square.grid.2x2"
        }
    }

    var highlight: Bool {
        switch self {
        case .order, .checkout, .others,
             .order_alert, .delivery,
             .loss_input, .prep_input, .stocktake_input,
             .seat_set:
            return true
        default:
            return false
        }
    }
}

// =====================
// 2) メニュー用モデル
// =====================

struct MenuItem: Identifiable {
    let id: Feature
}

struct Category: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let items: [MenuItem]
}

// =====================
// 3) メインデータ
// =====================

let menuStructure: [Category] = [
    Category(
        id: "seats",
        title: "座席管理",
        iconName: "chair.lounge",
        items: [
            MenuItem(id: .order),
            MenuItem(id: .checkout),
            MenuItem(id: .self_qr),
            MenuItem(id: .others)
        ]
    ),
    Category(
        id: "inventory",
        title: "在庫数値",
        iconName: "shippingbox",
        items: [
            MenuItem(id: .order_alert),
            MenuItem(id: .delivery),
            MenuItem(id: .loss_input),
            MenuItem(id: .prep_input),
            MenuItem(id: .stocktake_input)
        ]
    ),
    Category(
        id: "office",
        title: "事務",
        iconName: "briefcase",
        items: [
            MenuItem(id: .daily_report),
            MenuItem(id: .analytics),
            MenuItem(id: .cash_flow),
            MenuItem(id: .slip_detail),
            MenuItem(id: .timecard),
            MenuItem(id: .cost)
        ]
    ),
    Category(
        id: "settings",
        title: "設定",
        iconName: "gearshape",
        items: [
            MenuItem(id: .menu_set),
            MenuItem(id: .seat_set)
        ]
    )
]

// =====================
// 4) ルートビュー
// =====================

struct RestaurantPosApp: View {
    @State private var activeTab: String = "seats"
    @State private var selectedFeature: Feature? = nil

    var currentCategory: Category {
        menuStructure.first(where: { $0.id == activeTab }) ?? menuStructure[0]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                                .frame(width: 28, height: 28)
                            Text("R")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Restaurant POS")
                                .font(.subheadline.bold())
                            Text("だとたべ / メインメニュー")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("店長: 山田 太郎")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("本日の担当: ホールA")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.white.shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2))

                // カテゴリタブ＋説明カード
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        // タブ
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(menuStructure) { category in
                                    let isActive = (category.id == activeTab)
                                    Button {
                                        activeTab = category.id
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: category.iconName)
                                            Text(category.title)
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(isActive ? Color.blue : Color.white)
                                        )
                                        .foregroundColor(isActive ? .white : .gray)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(isActive ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(isActive ? 0.15 : 0.05), radius: isActive ? 4 : 2, x: 0, y: 2)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }

                        // 説明カード
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(currentCategory.title) のショートカット")
                                .font(.subheadline.bold())
                            Text("上のカテゴリを切り替えると、下のメニューが入れ替わります。各ボタンを押すと、シートで該当画面のプレビューが開きます。")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("本日: \(Date.now.formatted(date: .numeric, time: .omitted)) / v0.1.0")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                    }

                    // グリッド
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(currentCategory.items) { item in
                            let feature = item.id
                            Button {
                                selectedFeature = feature
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: feature.iconName)
                                            .font(.system(size: 22))
                                            .foregroundColor(
                                                feature.highlight ? .blue : .gray
                                            )
                                        Spacer()
                                        if feature.highlight {
                                            Text("よく使う")
                                                .font(.system(size: 10, weight: .semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.blue.opacity(0.1))
                                                )
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    Text(feature.label)
                                        .font(.footnote.bold())
                                        .foregroundColor(.primary)
                                    Text(description(for: feature))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 110, alignment: .top)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }

                // 下部タブバー（ダミー）
                HStack {
                    bottomTab(icon: "plus.circle.fill", label: "オーダー", active: true)
                    bottomTab(icon: "chart.bar.fill", label: "在庫数値", active: false)
                    bottomTab(icon: "tray.full.fill", label: "事務", active: false)
                    bottomTab(icon: "gearshape.fill", label: "設定", active: false)
                }
                .font(.caption2)
                .padding(.vertical, 6)
                .background(
                    Color.white
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: -2)
                )
            }
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(item: $selectedFeature) { feature in
                FeatureHostView(feature: feature)
            }
        }
    }

    @ViewBuilder
    private func bottomTab(icon: String, label: String, active: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(label)
        }
        .foregroundColor(active ? .blue : .gray)
        .frame(maxWidth: .infinity)
    }

    private func description(for feature: Feature) -> String {
        switch feature {
        case .order:
            return "テーブル/席ごとの注文登録画面を開きます。"
        case .checkout:
            return "会計・割り勘・伝票分割などの画面に移動します。"
        case .self_qr:
            return "セルフオーダー用のQRコードを発行・印刷します。"
        case .others:
            return "簡易メモや臨時メニューなど、その他の機能です。"
        case .order_alert:
            return "発注点を下回った食材を一覧で確認します。（在庫アプリを差し込み予定）"
        case .delivery:
            return "納品物の入力・食材の在庫更新画面を開きます。"
        case .loss_input:
            return "在庫ロスの数量を登録する画面です。"
        case .prep_input:
            return "仕込み完了数を入力し、在庫と連動させる画面です。"
        case .stocktake_input:
            return "棚卸しで実在庫を入力し、理論在庫との差分を確認します。"
        case .daily_report:
            return "売上・客数などの日報入力画面を開きます。"
        case .analytics:
            return "売上推移・時間帯別客数・メニュー構成比などを可視化します。"
        case .cash_flow:
            return "レジ入金・出金・釣銭合わせなどの入出金管理画面です。"
        case .slip_detail:
            return "伝票別・テーブル別の明細を確認する画面です。"
        case .timecard:
            return "スタッフの出退勤打刻・勤怠確認を行う画面です。"
        case .cost:
            return "原価計算・メニュー別粗利の確認画面に移動します。"
        case .menu_set:
            return "メニューの登録・カテゴリー編集などを行います。"
        case .seat_set:
            return "座席レイアウトやテーブル名の設定画面に移動します。"
        }
    }
}

// =====================
// 5) 機能ごとの画面の振り分け
// =====================

struct FeatureHostView: View {
    let feature: Feature

    var body: some View {
        NavigationStack {
            Group {
                switch feature {
                case .order:
                    OrderView()
                case .checkout:
                    CheckoutView()
                case .self_qr:
                    QRExportView()
                case .others:
                    OthersView()
                case .order_alert:
                    OrderAlertView()
                case .delivery:
                    DeliveryView()
                case .loss_input:
                    LossInputView()
                case .prep_input:
                    PrepInputView()
                case .stocktake_input:
                    StocktakeInputView()
                case .daily_report:
                    DailyReportView()
                case .analytics:
                    AnalyticsView()
                case .cash_flow:
                    CashFlowView()
                case .slip_detail:
                    SlipDetailView()
                case .timecard:
                    TimecardView()
                case .cost:
                    CostCalcView()
                case .menu_set:
                    MenuSettingView()
                case .seat_set:
                    SeatSettingView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: feature.iconName)
                        Text(feature.label)
                            .font(.headline)
                    }
                }
            }
        }
    }
}

// =====================
// 6) 各機能のダミービュー
// =====================

struct BaseFeaturePage: View {
    let title: String
    let note: String?

    init(title: String, note: String? = nil) {
        self.title = title
        self.note = note
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title2.bold())
            Text("ここに「\(title)」の画面ロジックを実装していきます。")
                .font(.subheadline)
                .foregroundColor(.gray)
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct OrderView: View {
    var body: some View {
        BaseFeaturePage(
            title: "注文画面",
            note: "席別の注文・コース・トッピング選択などを配置する想定です。"
        )
    }
}

struct CheckoutView: View {
    var body: some View {
        BaseFeaturePage(
            title: "会計画面",
            note: "既存の会計デモ（React+TS）の画面をここに持ってくる予定です。"
        )
    }
}

struct QRExportView: View {
    var body: some View {
        BaseFeaturePage(
            title: "QR出力画面",
            note: "席ごとのセルフオーダー用QRコードの一覧・印刷UIを配置します。"
        )
    }
}

struct OthersView: View {
    var body: some View {
        BaseFeaturePage(
            title: "その他機能",
            note: "簡易メモ・スタッフ共有用メッセージなどを入れる余白として使えます。"
        )
    }
}

struct OrderAlertView: View {
    var body: some View {
        BaseFeaturePage(
            title: "発注アラート画面",
            note: "在庫アプリのアラート一覧部分を組み込む候補画面です。"
        )
    }
}

struct DeliveryView: View {
    var body: some View {
        BaseFeaturePage(
            title: "納品入力画面",
            note: "DeliveryAppWireframe の納品入力画面をここに統合予定です。"
        )
    }
}

struct LossInputView: View {
    var body: some View {
        BaseFeaturePage(
            title: "ロス入力画面",
            note: "ロス入力タブ（loss screen）の UI を簡略化して組み込むイメージです。"
        )
    }
}

struct PrepInputView: View {
    var body: some View {
        BaseFeaturePage(
            title: "仕込入力画面",
            note: "仕込み数入力（prep screen）を、在庫数値カテゴリから直接開けるようにする想定です。"
        )
    }
}

struct StocktakeInputView: View {
    var body: some View {
        BaseFeaturePage(
            title: "棚卸入力画面",
            note: "棚卸し入力（stocktake screen）をここから呼び出す予定です。"
        )
    }
}

struct DailyReportView: View {
    var body: some View {
        BaseFeaturePage(
            title: "日報画面",
            note: "売上・客数・客単価などの日報入力UIを配置します。"
        )
    }
}

struct AnalyticsView: View {
    var body: some View {
        BaseFeaturePage(
            title: "分析画面",
            note: "売上推移・時間帯別客数・メニュー構成比などをカード/グラフで表示する予定です。"
        )
    }
}

struct CashFlowView: View {
    var body: some View {
        BaseFeaturePage(
            title: "入出金管理画面",
            note: "レジ入金・出金・釣銭差異などを記録する簡易入出金画面を想定しています。"
        )
    }
}

struct SlipDetailView: View {
    var body: some View {
        BaseFeaturePage(
            title: "伝票明細画面",
            note: "伝票ごとの明細確認や再発行、CSVエクスポートなどを行う予定です。"
        )
    }
}

struct TimecardView: View {
    var body: some View {
        BaseFeaturePage(
            title: "打刻管理画面",
            note: "スタッフの出退勤打刻と勤怠一覧を管理する画面をここに実装していきます。"
        )
    }
}

struct CostCalcView: View {
    var body: some View {
        BaseFeaturePage(
            title: "原価計算画面",
            note: "レシピ原価・メニュー別粗利を表示する集計画面予定です。"
        )
    }
}

struct MenuSettingView: View {
    var body: some View {
        BaseFeaturePage(
            title: "メニュー設定画面",
            note: "カテゴリ並び替え・メニュー登録/非表示などを行う設定画面です。"
        )
    }
}

struct SeatSettingView: View {
    var body: some View {
        BaseFeaturePage(
            title: "座席設定画面",
            note: "テーブル名・座席レイアウト・エリア区分の設定を想定しています。"
        )
    }
}

// =====================
// 7) エントリポイント
// =====================

@main
struct RestaurantPosRootApp: App {
    var body: some Scene {
        WindowGroup {
            RestaurantPosApp()
        }
    }
}

// プレビュー
struct RestaurantPosApp_Previews: PreviewProvider {
    static var previews: some View {
        RestaurantPosApp()
    }
}

