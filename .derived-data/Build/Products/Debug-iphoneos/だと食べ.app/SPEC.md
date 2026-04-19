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
