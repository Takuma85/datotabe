# v1 参照条件チートシート + API 仕様

## 0) 共通前提
- 店舗設定: `stores.day_cutoff_time`（例: 05:00）
- すべての集計は `store_id × business_date` を軸にする
- 「business_date」は以下の扱いで統一
  - `sales_receipts.business_date`
  - `daily_reports.date`
  - `daily_closings.date`
  - `expenses.date`
  - `cash_transactions.date`
  - `time_records.work_date`

---

## 1) 日報（daily_reports）再集計の参照条件
### 1.1 売上（sales_receipts）
対象: 指定店舗・営業日
- `sr.store_id = :store_id`
- `sr.business_date = :business_date`
- `sr.status IN ('posted','refunded')`

集計:
- `SUM(sr.total_incl_tax)`（税込総売上）
- `SUM(sr.subtotal_excl_tax)`（税抜売上）
- `SUM(sr.tax_total)`（税）
- `COUNT(*)`（会計件数）
- `SUM(sr.people_count)`（客数）

### 1.2 支払内訳（payment_splits）
対象: 上の `sales_receipts` に紐づく splits
- `ps.sales_receipt_id IN (売上対象の sr.id)`

集計:
- `SUM(ps.amount_incl_tax)` GROUP BY `ps.payment_method`

監査（推奨）:
- `SUM(sr.total_incl_tax)` と `SUM(ps.amount_incl_tax)` の差 → warning

### 1.3 経費（expenses）
対象: 指定店舗・営業日
- `e.store_id = :store_id`
- `e.date = :business_date`
- `e.status = 'approved'`

集計:
- `SUM(e.amount)`（経費合計）
- `SUM(e.amount)` GROUP BY `e.category`（カテゴリ別）

### 1.4 入出金（cash_transactions）
対象: 指定店舗・営業日
- `ct.store_id = :store_id`
- `ct.date = :business_date`

集計:
- `cash_in_total = SUM(ct.amount WHERE ct.type='in')`
- `cash_out_total = SUM(ct.amount WHERE ct.type='out')`

### 1.5 レジ締め（daily_closings）
対象: 指定店舗・営業日
- `dc.store_id = :store_id`
- `dc.date = :business_date`
- `dc.status IN ('draft','confirmed','approved')`（表示は全て、集計用途は confirmed 以上推奨）

参照:
- `dc.expected_cash_balance`
- `dc.actual_cash_balance`
- `dc.difference`
- `dc.issue_flag`

### 1.6 勤怠（time_records）
対象: 指定店舗・営業日
- `tr.store_id = :store_id`
- `tr.work_date = :business_date`
- `tr.status = 'approved'`（分析に使うなら approved 推奨）

集計:
- `labor_minutes_total = SUM(tr.work_minutes)`（または計算）

---

## 2) レジ締め（daily_closings）の参照条件（理論値）
### 2.1 前日繰越
- 前日: `:prev_date = business_date - 1`
- `previous_cash_balance = prev_daily_closings.actual_cash_balance`
  - `prev.store_id=:store_id AND prev.date=:prev_date`
  - `prev` が無ければ 0（初回は初期残高入力でもOK）

### 2.2 当日現金売上（cash_sales）
- 対象売上条件（1.1）+ `payment_method='cash'` 相当
  - v1で `payment_splits` があるなら
    - `cash_sales = SUM(ps.amount_incl_tax WHERE ps.payment_method='cash')`
  - ないなら `sales_receipts.payment_method='cash'` を参照

### 2.3 入出金
- (1.4) と同じ

### 2.4 理論残高
- `expected = previous + cash_sales + cash_in_total - cash_out_total`

---

## 3) 原価計算（Costing v1）の参照条件
### 3.1 売上（期間）
- `sr.store_id=:store_id`
- `sr.business_date BETWEEN :from AND :to`
- `sr.status IN ('posted','refunded')`

### 3.2 原価（COGS）
- `e.store_id=:store_id`
- `e.date BETWEEN :from AND :to`
- `e.status='approved'`
- `cost_category_settings.is_cogs=true` の category のみ

---

## 4) 分析（Analytics v1）の参照条件
### 4.1 月次（month=YYYY-MM）
- `from = 月初のbusiness_date`
- `to = 月末のbusiness_date`
- 期間は全て business_date 範囲で揃える

参照元:
- 売上: `sales_receipts`（3.1）
- 支払: `payment_splits`（売上に join）
- 原価: `expenses`（3.2）
- レジ差額: `daily_closings`（date 範囲、status confirmed/approved 推奨）
- 銀行入金: `cash_transactions`（date 範囲、category='deposit_to_bank' AND type='out'）
- 労務: `time_records`（work_date 範囲、status approved 推奨）

---

## 5) 月次CSV（集計）の参照条件
### 5.1 日次縦持ち（date行）
- `date = business_date`
- 売上は `sales_receipts.business_date`
- 経費/入出金/勤怠/締めは各 `date/work_date` をそのまま

### 5.2 月次サマリ
- 日次を `DATE_TRUNC('month', business_date)` でまとめる

---

## 6) 仕訳生成（journal生成）の参照条件（v1日次まとめ）
### 6.1 1エントリ単位
- `store_id × business_date × source_type='daily_summary'`

### 6.2 売上仕訳
- 売上: `sales_receipts`（1.1）を日次で合算
- 支払: `payment_splits` を日次で method別合算

### 6.3 経費仕訳
- `expenses`（1.3）を日次で category×payment_method で合算

### 6.4 資金移動系（任意）
- `cash_transactions`（1.4）からカテゴリ限定（deposit_to_bank/change系/reimburse）

---

## 7) UIで日付を出すときの表示ルール（混乱防止）
- 画面の「対象日」は必ず 営業日（business_date） を表示
- 参考情報として sold_at / clock_in_at の実時刻は別枠に表示
- 入力フォームのデフォルト日付は「今の日時 → business_date」

---

## 1) 日報 自動生成／再集計 API（v1）
### 1.1 エンドポイント
`POST /stores/{store_id}/daily-reports/{business_date}/rebuild`
- 指定営業日の「日報（daily_reports）+ 時間帯別（daily_report_segments）」を再生成/更新
- 冪等: 同じ日付で何度叩いても最新の元データから再計算

### 1.2 処理フロー（v1確定）
1. `store.day_cutoff_time` を取得
2. 対象営業日 `:bd` を受け取る（YYYY-MM-DD）
3. 売上（sales_receipts + payment_splits）集計
4. 経費（expenses approved）集計
5. 勤怠（time_records approved）集計
6. レジ締め（daily_closings）参照（存在すれば紐付け）
7. `daily_reports` を upsert（statusは draft を維持）
8. `daily_report_segments` を upsert（v1は all_day のみでもOK。lunch/dinnerは time_bands があれば作る）

### 1.3 疑似SQL（集計の骨格）
A) 売上サマリ（sales_receipts）
```
WITH sr AS (
  SELECT *
  FROM sales_receipts
  WHERE store_id = :store_id
    AND business_date = :bd
    AND status IN ('posted','refunded')
),
sales_sum AS (
  SELECT
    COALESCE(SUM(total_incl_tax),0)    AS sales_total_incl_tax,
    COALESCE(SUM(subtotal_excl_tax),0) AS sales_subtotal_excl_tax,
    COALESCE(SUM(tax_total),0)         AS sales_tax_total,
    COALESCE(COUNT(*),0)               AS receipt_count,
    COALESCE(SUM(COALESCE(people_count,0)),0) AS guest_count
  FROM sr
),
pay_sum AS (
  SELECT
    COALESCE(SUM(CASE WHEN ps.payment_method='cash' THEN ps.amount_incl_tax END),0) AS pay_cash,
    COALESCE(SUM(CASE WHEN ps.payment_method='card' THEN ps.amount_incl_tax END),0) AS pay_card,
    COALESCE(SUM(CASE WHEN ps.payment_method='qr'   THEN ps.amount_incl_tax END),0) AS pay_qr,
    COALESCE(SUM(CASE WHEN ps.payment_method NOT IN ('cash','card','qr') THEN ps.amount_incl_tax END),0) AS pay_other,
    COALESCE(SUM(ps.amount_incl_tax),0) AS pay_total
  FROM payment_splits ps
  JOIN sr ON sr.id = ps.sales_receipt_id
)
SELECT * FROM sales_sum, pay_sum;
```

B) 経費（expenses）
```
SELECT
  COALESCE(SUM(amount),0) AS total_expenses
FROM expenses
WHERE store_id = :store_id
  AND date = :bd
  AND status = 'approved';
```

C) 勤怠（time_records）
```
SELECT
  COALESCE(SUM(work_minutes),0) AS labor_minutes_total
FROM time_records
WHERE store_id = :store_id
  AND work_date = :bd
  AND status = 'approved';
```

D) レジ締め参照（daily_closings）
```
SELECT *
FROM daily_closings
WHERE store_id = :store_id
  AND date = :bd;
```

E) 監査warning（売上合計 vs 支払合計）
```
-- app側で差分判定
diff = sales_total_incl_tax - pay_total
if abs(diff) > 0 => warnings += sales_payment_mismatch
```

### 1.4 daily_reports upsert（例: 擬似）
- `store_id + date（business_date）` で一意
- すでに submitted/approved の場合
  - v1推奨: 再集計は禁止（409）または adminのみ可 + change_logs必須

更新項目（v1）:
- total_sales / cash_sales / card_sales / qr_sales / other_sales
- guest_count / table_count / average_spend
- total_expenses
- total_labor_minutes
- daily_closing_id（あれば）
- warnings（カラムが無ければ返却だけでもOK）

### 1.5 レスポンス例
```json
{
  "daily_report": {
    "store_id": 1,
    "date": "2026-02-04",
    "status": "draft",
    "total_sales": 61800,
    "cash_sales": 22000,
    "card_sales": 36000,
    "qr_sales": 3800,
    "other_sales": 0,
    "guest_count": 120,
    "table_count": 55,
    "average_spend": 515,
    "total_expenses": 8200,
    "total_labor_minutes": 780,
    "daily_closing_id": 10
  },
  "warnings": [
    { "code": "sales_payment_mismatch", "message": "売上合計と支払合計に差異があります", "value": 1200 }
  ]
}
```

---

## 2) 分析 月次ダッシュボード API（v1）
### 2.1 エンドポイント
`GET /stores/{store_id}/analytics/monthly?month=YYYY-MM`

### 2.2 期間決定（business_date）
- `from = YYYY-MM-01`
- `to = YYYY-MM-last_day`
- 以降のWHEREはすべて `business_date/date/work_date` の BETWEEN で統一

### 2.3 疑似SQL（骨格）
A) 売上（sales_receipts）
```
WITH sr AS (
  SELECT *
  FROM sales_receipts
  WHERE store_id = :store_id
    AND business_date BETWEEN :from AND :to
    AND status IN ('posted','refunded')
),
sales_sum AS (
  SELECT
    COALESCE(SUM(total_incl_tax),0)    AS sales_total_incl_tax,
    COALESCE(SUM(subtotal_excl_tax),0) AS sales_subtotal_excl_tax,
    COALESCE(SUM(tax_total),0)         AS sales_tax_total,
    COALESCE(COUNT(*),0)               AS receipt_count,
    COALESCE(SUM(COALESCE(people_count,0)),0) AS guest_count
  FROM sr
),
pay_sum AS (
  SELECT
    COALESCE(SUM(CASE WHEN ps.payment_method='cash' THEN ps.amount_incl_tax END),0) AS pay_cash,
    COALESCE(SUM(CASE WHEN ps.payment_method='card' THEN ps.amount_incl_tax END),0) AS pay_card,
    COALESCE(SUM(CASE WHEN ps.payment_method='qr'   THEN ps.amount_incl_tax END),0) AS pay_qr,
    COALESCE(SUM(CASE WHEN ps.payment_method NOT IN ('cash','card','qr') THEN ps.amount_incl_tax END),0) AS pay_other,
    COALESCE(SUM(ps.amount_incl_tax),0) AS pay_total
  FROM payment_splits ps
  JOIN sr ON sr.id = ps.sales_receipt_id
)
SELECT * FROM sales_sum, pay_sum;
```

B) 原価（COGS: expenses × cost_category_settings）
```
WITH cogs_cats AS (
  SELECT expense_category
  FROM cost_category_settings
  WHERE store_id = :store_id AND is_cogs = true
)
SELECT
  COALESCE(SUM(e.amount),0) AS cogs_total
FROM expenses e
JOIN cogs_cats c ON c.expense_category = e.category
WHERE e.store_id = :store_id
  AND e.date BETWEEN :from AND :to
  AND e.status = 'approved';
```

（内訳も返す場合）
```
SELECT e.category, COALESCE(SUM(e.amount),0) AS amount
FROM expenses e
JOIN cogs_cats c ON c.expense_category = e.category
WHERE e.store_id=:store_id AND e.date BETWEEN :from AND :to AND e.status='approved'
GROUP BY e.category;
```

C) レジ差額（daily_closings）
```
SELECT
  COALESCE(SUM(difference),0) AS closing_difference_total,
  COALESCE(SUM(CASE WHEN issue_flag THEN 1 END),0) AS closing_issue_days
FROM daily_closings
WHERE store_id = :store_id
  AND date BETWEEN :from AND :to
  AND status IN ('confirmed','approved');
```

D) 銀行入金（cash_transactions）
```
SELECT
  COALESCE(SUM(amount),0) AS deposit_to_bank_total
FROM cash_transactions
WHERE store_id = :store_id
  AND date BETWEEN :from AND :to
  AND type = 'out'
  AND category = 'deposit_to_bank';
```

E) 労務（time_records）
```
SELECT
  COALESCE(SUM(work_minutes),0) AS labor_minutes_total
FROM time_records
WHERE store_id = :store_id
  AND work_date BETWEEN :from AND :to
  AND status = 'approved';
```

F) 取引先別支出（vendors）
```
SELECT
  COALESCE(v.id, 0) AS vendor_id,
  COALESCE(v.name, '未紐付け') AS vendor_name,
  COALESCE(SUM(e.amount),0) AS amount
FROM expenses e
LEFT JOIN vendors v ON v.id = e.vendor_id
WHERE e.store_id = :store_id
  AND e.date BETWEEN :from AND :to
  AND e.status = 'approved'
GROUP BY COALESCE(v.id,0), COALESCE(v.name,'未紐付け')
ORDER BY amount DESC
LIMIT 10;
```

### 2.4 KPI算出（app側）
- `gross_profit = sales_total_incl_tax - cogs_total`
- `cogs_ratio = cogs_total / sales_total_incl_tax`（0除算は null）
- `gross_margin_ratio = gross_profit / sales_total_incl_tax`
- `avg_spend_per_guest = sales_total_incl_tax / guest_count`
- `avg_spend_per_receipt = sales_total_incl_tax / receipt_count`
- `sales_per_labor_hour = sales_total_incl_tax / (labor_minutes_total/60)`

### 2.5 レスポンス例（確定形）
```json
{
  "month": "2026-02",
  "kpi": {
    "sales_total_incl_tax": 1800000,
    "sales_subtotal_excl_tax": 1636363,
    "sales_tax_total": 163637,
    "receipt_count": 920,
    "guest_count": 2100,
    "avg_spend_per_guest": 857,
    "avg_spend_per_receipt": 1956,

    "pay_cash": 650000,
    "pay_card": 980000,
    "pay_qr": 150000,
    "pay_other": 20000,

    "cogs_total": 430000,
    "gross_profit": 1370000,
    "cogs_ratio": 0.239,
    "gross_margin_ratio": 0.761,

    "closing_difference_total": -3200,
    "closing_issue_days": 4,
    "deposit_to_bank_total": 500000,

    "labor_minutes_total": 25680,
    "sales_per_labor_hour": 4206
  },
  "breakdowns": {
    "cogs_by_category": { "food": 320000, "drink": 110000 },
    "top_vendors": [
      { "vendor_id": 1, "vendor_name": "八百屋A", "amount": 120000 }
    ]
  },
  "warnings": [
    { "code": "sales_payment_mismatch", "message": "売上合計と支払合計に差異があります", "value": 1200 }
  ]
}
```

---

## 3) v1でのガード（事故防止ルール）
- 日報再集計:
  - `daily_reports.status IN ('submitted','approved')` は 409で拒否（推奨）
  - 例外: adminのみ許可 + change_logs必須（運用が必要なら）
- 集計は必ず business_date 範囲で統一（カレンダー日で集計しない）
- 「売上合計≠支払合計」は warnings で必ず返す（見落とし防止）

---

## 実装バッチ定義（Codex作業用）

このセクションは、要件PDF群をどの実装バッチとして扱うかを固定するための作業メモ。以後、ユーザーが「第1バッチ」「第2バッチ」などと指定した場合はこの対応表を優先する。

要件PDFの参照元:
- Google Drive: https://drive.google.com/drive/folders/1DgEX8RTpyJtExC0MotoPW08eTy0Swahd
- 各バッチの「参照資料」は上記Google Driveフォルダ内の `要件定義書/` を参照する。

### 第1バッチ: 在庫管理
参照資料:
- `要件定義書/在庫管理機能 要件定義 v1（オーダー引当方式）まとめ.pdf`
- 補助参照: `要件定義書/共通テーブルDDL.pdf`
- 補助参照: `要件定義書/business_date 参照条件一覧（v1確定チートシート）.pdf`

目的:
- 後続の締め・会計処理を成立させるための在庫引当土台を作る。

範囲:
- 会計・在庫の不足モデルを追加する。
- 注文商品と在庫品目のリンク設定を入れる。
- 在庫引当 `reserved` を実装する。
- 在庫画面に `on_hand` / `reserved` / `available` を出す。
- 仮実装の「先頭在庫品目を減らす」処理を廃止する。

主な変更対象:
- `Shared/AppModels.swift`
- `Shared/AppStore.swift`
- `Inventory/InventoryStatusView.swift`
- `Settings/MenuSettingView.swift`

実装タスク:
- `InventoryItemLink` を追加する。
- `InventoryReservation` を追加する。
- `InventoryItem` に `onHand`, `reservedQuantity`, `availableQuantity` を扱える形を追加する。
- サンプル `inventoryItemLinks` と `inventoryReservations` を保持する。
- 注文追加時にリンクされた在庫へ `reserved` を積む。
- 会計完了時に `reserved` を減らして `onHand` を減らす。
- 棚卸・納品・ロスとの整合を壊さないように整理する。
- メニュー商品に対して在庫品目と数量を結び付ける簡易UIを追加する。
- 在庫画面で理論在庫、引当、利用可能、直近トランザクション、引当状況を見えるようにする。

完了条件:
- 商品ごとに引当先在庫を設定できる。
- 注文を追加すると `reserved` が増える。
- 会計確定すると `reserved` が減り `onHand` が減る。
- 在庫画面で `on_hand` / `reserved` / `available` が確認できる。
- 先頭在庫品目を機械的に減らす仮ロジックがなくなる。

### 第2バッチ: 日報 / レジ締め / 経費 / 入出金 / 承認
参照資料:
- `要件定義書/日報機能 要件定義 v1.pdf`
- `要件定義書/レジ締め機能 要件定義 v1.pdf`
- `要件定義書/経費・立替機能 要件定義 v1.pdf`
- `要件定義書/入出金機能 要件定義 v1.pdf`
- 補助参照: `要件定義書/日報（daily_reports）× 承認フロー／変更履歴（v1） 要件定義.pdf`
- 補助参照: `要件定義書/レジ締め（cash_closings）× 承認フロー／変更履歴（v1） 要件定義.pdf`
- 補助参照: `要件定義書/承認フロー／変更履歴ログ（v1）＋経費・立替（expense）連携要件定義.pdf`

目的:
- 1営業日の締めを成立させる。
- 第1バッチで在庫引当の土台ができた前提で進める。

範囲:
- 日報に経費・労務・レジ締めを統合する。
- レジ締めを要件準拠に近づける。
- 経費と入出金をひも付ける。
- 日報を正式な締め記録にする。

主な変更対象:
- `Shared/AppModels.swift`
- `Shared/AppStore.swift`
- `Office/DailyReportModels.swift`
- `Office/DailyReportView.swift`
- `Office/CashClosingView.swift`
- `Office/ExpenseView.swift`
- `Office/CashFlowView.swift`

実装タスク:
- `DailyReport` に `totalExpenses`, `totalLaborMinutes`, `dailyClosingId`, 必要なら `cashDifference` を追加する。
- `CashClosing` に `previousCashBalance`, `cashSales`, `cashInTotal`, `cashOutTotal`, `difference`, `issueFlag`, `confirmedAt`, `confirmedBy` 相当を追加する。
- `ExpenseRecord` に `paymentMethod`, `taxAmount`, `cashFlowId` または `cashTransactionId` 相当を追加する。
- 日報生成時に経費合計と労働時間を集計する。
- レジ締め生成時に前日繰越と入出金集計を反映する。
- 経費登録時に必要に応じて入出金との関連付けを保持する。
- 日報とレジ締めの紐付けを保持する。
- 日報画面で売上、経費、労務、レジ締め状況を表示する。
- レジ締め画面で理論現金の内訳、差額、課題フラグを表示する。
- 経費画面 / 入出金画面で現金払い経費と入出金を追えるようにする。

完了条件:
- 日報に売上、経費、労務、締め状況が揃う。
- レジ締めで `前日残高 + 当日現金売上 + 入金 - 出金` の理論値が見える。
- 差額が自動計算される。
- 経費のうち現金払いが入出金と結び付く。
- 日報からその日の締めが完了しているか確認できる。

### 第3バッチ: 仕訳出力 / account_mappings
参照資料:
- `要件定義書/2) 会計ソフト連携：仕訳出力 要件定義 v1（journal_entries : journal_lines）.pdf`
- `要件定義書/1) account_mappings 初期テンプレ（v1ひな形）.pdf`
- 補助参照: `要件定義書/1) 月次集計CSV 要件定義 v1.pdf`
- 補助参照: 第2バッチで使う経費・立替、入出金、日報、レジ締め要件。

目的:
- 会計処理を実データ化する。
- 第2バッチまでで日々の締めが成立している前提で進める。

範囲:
- 仕訳モデルを追加する。
- 勘定科目マッピングを要件準拠に拡張する。
- 日次まとめ仕訳を生成する。
- 会計出力画面で仕訳プレビューと警告を出す。

主な変更対象:
- `Shared/AppModels.swift`
- `Shared/AppStore.swift`
- `Settings/AccountMappingSettingView.swift`
- `Office/AccountingExportView.swift`

実装タスク:
- `JournalEntry` を追加する。
- `JournalLine` を追加する。
- `AccountMapping` を拡張し、`mappingType`, `mappingKey`, `taxCode`, `isActive` を扱う。
- `journalEntries`, `journalLines` を保持する。
- 日次まとめ仕訳生成関数を追加する。
- 売上、経費、入出金を仕訳生成対象にする。
- 売上は payment method ごとに借方、売上高を貸方へ集約する。
- 経費は expense category ごとの借方、支払手段側を貸方へ集約する。
- 入出金はカテゴリ別マッピングで振替仕訳化する。
- 借貸一致チェックを追加する。
- マッピング未設定警告を追加する。
- `mappingType` + `mappingKey` を登録できるUIへ変更する。
- 最低限 `sales_payment`, `sales_revenue`, `expense_category`, `cash_tx_category` を扱う。
- 会計出力画面で実際に生成された仕訳を一覧表示する。
- 未設定マッピングや不一致を警告表示する。
- 出力ジョブ作成時に仕訳生成を先に走らせる。

完了条件:
- 指定営業日または対象月に対して仕訳が生成される。
- 売上、経費、入出金が仕訳行に変換される。
- 借方合計と貸方合計が一致する。
- マッピング未設定が画面で確認できる。
- 会計出力画面がダミー履歴ではなく、実仕訳ベースになる。

### 第4バッチ: 月次CSV / 打刻 / 分析
参照資料:
- `要件定義書/1) 月次集計CSV 要件定義 v1.pdf`
- `要件定義書/打刻機能 要件整理（v1）.pdf`
- `要件定義書/分析（Analytics）要件定義 v1：おすすめ確定案.pdf`
- `要件定義書/分析（Analytics）日次API 要件定義 v1.pdf`

目的:
- 運用に耐える周辺機能を固める。
- 会計出力を完成に近づけつつ、勤怠と分析を業務で使える形に寄せる。

範囲:
- 会計CSV出力を実装する。
- 打刻の管理者運用を実装する。
- 分析KPIを要件準拠へ拡張する。
- 警告と監査性を強化する。

主な変更対象:
- `Shared/AppModels.swift`
- `Shared/AppStore.swift`
- `Office/AccountingExportView.swift`
- `Office/TimecardView.swift`
- `Office/AnalyticsView.swift`

実装タスク:
- `journal_lines` からCSV文字列を生成する。
- 月次対象の仕訳一覧を表示する。
- 出力前バリデーション結果を表示する。
- 出力履歴に件数、警告数、対象月を持たせる。
- 売上合計 vs 決済合計、借方合計 vs 貸方合計、未割当マッピングの検証を共通化する。
- 打刻管理者向け一覧、日付フィルタ、従業員フィルタを追加する。
- 打刻の承認 / 差戻し、不整合表示、詳細編集を追加する。
- 打刻にエラー状態や承認者情報が扱えるよう補強する。
- 分析画面へ `receiptCount`, `avgSpendPerReceipt`, `cogsTotal`, `grossProfit`, `grossMarginRatio`, `closingDifferenceTotal`, `laborMinutesTotal`, `salesPerLaborHour` を追加する。
- 経費、レジ締め、勤怠、売上から分析KPIを集計する。

完了条件:
- 仕訳をCSV形式で出力内容として確認できる。
- 会計出力前に不整合がわかる。
- 店長が打刻一覧を確認、修正、承認できる。
- 分析画面で売上だけでなく粗利、差額、人時売上まで見える。
- 業務の異常値が警告として見える。

### 第5バッチ: 共通DDL / business_date / 共通ユーティリティ / 設定系
参照資料:
- `要件定義書/共通テーブルDDL.pdf`
- `要件定義書/business_date 参照条件一覧（v1確定チートシート）.pdf`
- `要件定義書/共通ユーティリティ仕様（税計算・合計計算・一致チェック.pdf`
- 補助参照: `要件定義書/取引先マスタ（vendors）要件定義 v1：おすすめ確定案.pdf`
- 補助参照: `要件定義書/原価計算（Costing）要件定義 v1：おすすめ確定案.pdf`
- 補助参照: `要件定義書/レシピ原価（Costing v2：試算MVP）要件定義.pdf`

目的:
- 仕上げと運用安定化。
- これまで入れた機能を継続利用できる形に整える。

範囲:
- 設定値を各業務ロジックへ反映する。
- 永続化を入れる。
- テストを整備する。
- リファクタリングして保守可能な構造にする。

主な変更対象:
- `Shared/AppStore.swift`
- `Shared/AppModels.swift`
- `Settings/TaxSettingView.swift`
- `Settings/TimeBandSettingView.swift`
- `Settings/VendorSettingView.swift`
- `Settings/AccountMappingSettingView.swift`
- 永続化用の新規ファイル群
- テスト用の新規ファイル群

実装タスク:
- 税率、丸め、時間帯、取引先、勘定科目マッピングが各集計と出力に反映されるようにする。
- 日報の時間帯別集計は `timeBands` を使う。
- 会計出力は `accountMappings` を使う。
- インメモリ初期化依存を減らす。
- 最低限 JSON保存/読込または SwiftData などで継続保存する。
- 店舗データ、設定、履歴、締め、仕訳が再起動後も残るようにする。
- 在庫引当、日報集計、レジ締め計算、仕訳生成、CSV出力、勤怠計算の単体テストを追加する。
- `AppStore` の肥大化を分割する。
- 分割例: `InventoryService`, `ClosingService`, `AccountingService`, `AnalyticsService`
- UIから直接計算ロジックを持たせない。
- 主要更新に変更履歴を追加する。
- 承認操作や差戻し理由を追えるようにする。

完了条件:
- 再起動後もデータが残る。
- 設定変更が実際の集計や出力に反映される。
- 重要ロジックに自動テストがある。
- `AppStore` だけに依存しない構造になる。
- 業務データの監査性が上がる。
