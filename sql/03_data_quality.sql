\set ON_ERROR_STOP on
\timing on

-- ============================================================
-- FMCG Consumer Growth & Promotion Insights
-- Phase 4: Data Quality Audit
-- ============================================================
--
-- This script DOES NOT delete or correct source records.
-- It identifies integrity issues and analytical review items.
-- Exclusion decisions are made only after investigation.
-- ============================================================

DROP TABLE IF EXISTS staging.data_quality_summary;

CREATE TABLE staging.data_quality_summary (
    check_name   TEXT PRIMARY KEY,
    result_value BIGINT,
    result_pct   NUMERIC(12,6),
    status       TEXT NOT NULL,
    notes        TEXT
);

WITH
transaction_total AS (
    SELECT COUNT(*)::BIGINT AS total_rows
    FROM staging.transactions
),

raw_day_bounds AS (
    SELECT
        MIN(BTRIM(day)::INTEGER) AS min_day,
        MAX(BTRIM(day)::INTEGER) AS max_day
    FROM raw.transaction_data
    WHERE BTRIM(day) ~ '^[0-9]+$'
),

unmatched_products AS (
    SELECT COUNT(*)::BIGINT AS unmatched_rows
    FROM staging.transactions t
    LEFT JOIN (
        SELECT DISTINCT product_id
        FROM staging.products
        WHERE product_id IS NOT NULL
    ) p
        ON t.product_id = p.product_id
    WHERE t.product_id IS NOT NULL
      AND p.product_id IS NULL
),

duplicate_transaction_stats AS (
    SELECT
        COUNT(*)::BIGINT AS duplicate_groups,
        COALESCE(SUM(row_count - 1), 0)::BIGINT AS extra_duplicate_rows
    FROM (
        SELECT COUNT(*)::BIGINT AS row_count
        FROM raw.transaction_data
        GROUP BY
            household_key,
            basket_id,
            day,
            product_id,
            quantity,
            sales_value,
            store_id,
            retail_disc,
            trans_time,
            week_no,
            coupon_disc,
            coupon_match_disc
        HAVING COUNT(*) > 1
    ) d
),

duplicate_product_ids AS (
    SELECT COUNT(*)::BIGINT AS duplicate_ids
    FROM (
        SELECT product_id
        FROM staging.products
        WHERE product_id IS NOT NULL
        GROUP BY product_id
        HAVING COUNT(*) > 1
    ) d
),

duplicate_customer_ids AS (
    SELECT COUNT(*)::BIGINT AS duplicate_ids
    FROM (
        SELECT customer_id
        FROM staging.customers
        WHERE customer_id IS NOT NULL
        GROUP BY customer_id
        HAVING COUNT(*) > 1
    ) d
),

metrics AS (
    SELECT
        tt.total_rows,

        COUNT(*) FILTER (
            WHERE t.customer_id IS NULL
        )::BIGINT AS null_customer_ids,

        COUNT(*) FILTER (
            WHERE t.basket_id IS NULL
        )::BIGINT AS null_basket_ids,

        COUNT(*) FILTER (
            WHERE t.product_id IS NULL
        )::BIGINT AS null_product_ids,

        COUNT(*) FILTER (
            WHERE t.quantity <= 0
        )::BIGINT AS non_positive_quantities,

        COUNT(*) FILTER (
            WHERE t.sales_amount < 0
        )::BIGINT AS negative_sales,

        COUNT(*) FILTER (
            WHERE t.sales_amount = 0
        )::BIGINT AS zero_sales,

        COUNT(*) FILTER (
            WHERE t.sales_amount > 0
              AND t.sales_amount < 0.000001
        )::BIGINT AS micro_positive_sales,

        COUNT(*) FILTER (
            WHERE t.discount_amount > 0
              AND t.discount_amount < 0.000001
        )::BIGINT AS micro_discount_lines,

        COUNT(*) FILTER (
            WHERE t.transaction_date IS NULL
               OR t.day_index IS NULL
               OR t.day_index < rb.min_day
               OR t.day_index > rb.max_day
               OR t.transaction_date
                  <> DATE '2000-01-01' + (t.day_index - 1)
        )::BIGINT AS invalid_transaction_dates,

        COUNT(*) FILTER (
            WHERE t.promo_line_flag <>
                CASE
                    WHEN COALESCE(ABS(t.retail_discount), 0)
                       + COALESCE(ABS(t.coupon_discount), 0)
                       + COALESCE(ABS(t.coupon_match_discount), 0) > 0
                    THEN 1
                    ELSE 0
                END
        )::BIGINT AS promotion_logic_mismatches

    FROM staging.transactions t
    CROSS JOIN transaction_total tt
    CROSS JOIN raw_day_bounds rb
    GROUP BY tt.total_rows
),

campaign_checks AS (
    SELECT
        COUNT(*) FILTER (
            WHERE promotion_id IS NULL
               OR start_day_index IS NULL
               OR end_day_index IS NULL
               OR start_date IS NULL
               OR end_date IS NULL
               OR end_date < start_date
        )::BIGINT AS invalid_campaign_dates
    FROM staging.promotions
),

missing_categories AS (
    SELECT COUNT(*)::BIGINT AS missing_category_rows
    FROM staging.transactions t
    LEFT JOIN staging.products p
        ON t.product_id = p.product_id
    WHERE p.product_id IS NOT NULL
      AND p.category IS NULL
)

INSERT INTO staging.data_quality_summary
    (check_name, result_value, result_pct, status, notes)

SELECT
    'Raw transaction rows',
    m.total_rows,
    NULL,
    'INFO',
    'Total transaction-line rows loaded into staging.'
FROM metrics m

UNION ALL

SELECT
    'Null customer IDs',
    m.null_customer_ids,
    ROUND(100.0 * m.null_customer_ids / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.null_customer_ids = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Rows with no usable customer identifier.'
FROM metrics m

UNION ALL

SELECT
    'Null basket IDs',
    m.null_basket_ids,
    ROUND(100.0 * m.null_basket_ids / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.null_basket_ids = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Rows with no usable basket identifier.'
FROM metrics m

UNION ALL

SELECT
    'Null product IDs',
    m.null_product_ids,
    ROUND(100.0 * m.null_product_ids / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.null_product_ids = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Rows with no usable product identifier.'
FROM metrics m

UNION ALL

SELECT
    'Unmatched product IDs',
    u.unmatched_rows,
    ROUND(100.0 * u.unmatched_rows / NULLIF(m.total_rows, 0), 6),
    CASE WHEN u.unmatched_rows = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Transaction rows whose product_id is absent from the product master.'
FROM unmatched_products u
CROSS JOIN metrics m

UNION ALL

SELECT
    'Invalid transaction dates',
    m.invalid_transaction_dates,
    ROUND(100.0 * m.invalid_transaction_dates / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.invalid_transaction_dates = 0 THEN 'PASS' ELSE 'FAIL' END,
    'Null, out-of-range, or inconsistent synthetic transaction dates.'
FROM metrics m

UNION ALL

SELECT
    'Invalid campaign dates',
    c.invalid_campaign_dates,
    NULL,
    CASE WHEN c.invalid_campaign_dates = 0 THEN 'PASS' ELSE 'FAIL' END,
    'Campaigns with missing date indices/dates or end_date before start_date.'
FROM campaign_checks c

UNION ALL

SELECT
    'Non-positive quantities',
    m.non_positive_quantities,
    ROUND(100.0 * m.non_positive_quantities / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.non_positive_quantities = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'quantity <= 0; requires return/invalid-row investigation.'
FROM metrics m

UNION ALL

SELECT
    'Negative sales',
    m.negative_sales,
    ROUND(100.0 * m.negative_sales / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.negative_sales = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'sales_amount < 0; must not be silently converted.'
FROM metrics m

UNION ALL

SELECT
    'Zero sales',
    m.zero_sales,
    ROUND(100.0 * m.zero_sales / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.zero_sales = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Exact zero sales values requiring contextual review.'
FROM metrics m

UNION ALL

SELECT
    'Scientific micro sales',
    m.micro_positive_sales,
    ROUND(100.0 * m.micro_positive_sales / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.micro_positive_sales = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Very small positive sales values preserved from scientific notation.'
FROM metrics m

UNION ALL

SELECT
    'Micro discount lines',
    m.micro_discount_lines,
    ROUND(100.0 * m.micro_discount_lines / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.micro_discount_lines = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Very small non-zero source discount values; promo rule currently treats them as promotional.'
FROM metrics m

UNION ALL

SELECT
    'Promotion logic mismatches',
    m.promotion_logic_mismatches,
    ROUND(100.0 * m.promotion_logic_mismatches / NULLIF(m.total_rows, 0), 6),
    CASE WHEN m.promotion_logic_mismatches = 0 THEN 'PASS' ELSE 'FAIL' END,
    'promo_line_flag must equal the canonical discount rule.'
FROM metrics m

UNION ALL

SELECT
    'Exact duplicate transaction rows',
    d.extra_duplicate_rows,
    ROUND(100.0 * d.extra_duplicate_rows / NULLIF(m.total_rows, 0), 6),
    CASE WHEN d.extra_duplicate_rows = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Extra rows beyond the first record within exact full-row duplicate groups.'
FROM duplicate_transaction_stats d
CROSS JOIN metrics m

UNION ALL

SELECT
    'Exact duplicate transaction groups',
    d.duplicate_groups,
    NULL,
    CASE WHEN d.duplicate_groups = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Number of full-row duplicate groups in raw transaction data.'
FROM duplicate_transaction_stats d

UNION ALL

SELECT
    'Duplicate product IDs',
    d.duplicate_ids,
    NULL,
    CASE WHEN d.duplicate_ids = 0 THEN 'PASS' ELSE 'FAIL' END,
    'Duplicate canonical product IDs could create join fan-out.'
FROM duplicate_product_ids d

UNION ALL

SELECT
    'Duplicate customer IDs',
    d.duplicate_ids,
    NULL,
    CASE WHEN d.duplicate_ids = 0 THEN 'PASS' ELSE 'FAIL' END,
    'staging.customers must remain one row per customer.'
FROM duplicate_customer_ids d

UNION ALL

SELECT
    'Transactions with missing category',
    mc.missing_category_rows,
    ROUND(100.0 * mc.missing_category_rows / NULLIF(m.total_rows, 0), 6),
    CASE WHEN mc.missing_category_rows = 0 THEN 'PASS' ELSE 'REVIEW' END,
    'Matched products whose canonical category is missing.'
FROM missing_categories mc
CROSS JOIN metrics m
;

-- ============================================================
-- REQUIRED QA SUMMARY
-- ============================================================

SELECT
    check_name,
    result_value,
    result_pct,
    status,
    notes
FROM staging.data_quality_summary
ORDER BY
    CASE status
        WHEN 'FAIL' THEN 1
        WHEN 'REVIEW' THEN 2
        WHEN 'PASS' THEN 3
        ELSE 4
    END,
    check_name;

-- ============================================================
-- DIAGNOSTIC 1: NON-POSITIVE QUANTITIES
-- ============================================================

SELECT
    CASE
        WHEN quantity < 0 THEN 'NEGATIVE'
        WHEN quantity = 0 THEN 'ZERO'
    END AS quantity_issue,
    COUNT(*) AS row_count,
    COUNT(*) FILTER (WHERE sales_amount < 0) AS negative_sales_rows,
    COUNT(*) FILTER (WHERE sales_amount = 0) AS zero_sales_rows,
    COUNT(*) FILTER (WHERE sales_amount > 0) AS positive_sales_rows,
    MIN(sales_amount) AS min_sales,
    MAX(sales_amount) AS max_sales
FROM staging.transactions
WHERE quantity <= 0
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- DIAGNOSTIC 2: NEGATIVE SALES
-- ============================================================

SELECT
    COUNT(*) AS negative_sales_rows,
    COUNT(*) FILTER (WHERE quantity < 0) AS negative_quantity_rows,
    COUNT(*) FILTER (WHERE quantity = 0) AS zero_quantity_rows,
    COUNT(*) FILTER (WHERE quantity > 0) AS positive_quantity_rows,
    MIN(sales_amount) AS min_negative_sale,
    MAX(sales_amount) AS max_negative_sale
FROM staging.transactions
WHERE sales_amount < 0;

-- ============================================================
-- DIAGNOSTIC 3: EXACT DUPLICATE SAMPLES
-- ============================================================

SELECT
    household_key,
    basket_id,
    day,
    product_id,
    quantity,
    sales_value,
    store_id,
    retail_disc,
    trans_time,
    week_no,
    coupon_disc,
    coupon_match_disc,
    COUNT(*) AS duplicate_count
FROM raw.transaction_data
GROUP BY
    household_key,
    basket_id,
    day,
    product_id,
    quantity,
    sales_value,
    store_id,
    retail_disc,
    trans_time,
    week_no,
    coupon_disc,
    coupon_match_disc
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- ============================================================
-- DIAGNOSTIC 4: UNMATCHED PRODUCT SAMPLE
-- ============================================================

SELECT
    t.customer_id,
    t.basket_id,
    t.product_id,
    t.transaction_date,
    t.quantity,
    t.sales_amount
FROM staging.transactions t
LEFT JOIN staging.products p
    ON t.product_id = p.product_id
WHERE p.product_id IS NULL
LIMIT 20;

-- ============================================================
-- DIAGNOSTIC 5: MICRO FLOATING-POINT SOURCE VALUES
-- ============================================================

SELECT
    COUNT(*) AS micro_sales_rows,
    MIN(sales_amount) AS min_micro_sale,
    MAX(sales_amount) AS max_micro_sale
FROM staging.transactions
WHERE sales_amount > 0
  AND sales_amount < 0.000001;

SELECT
    COUNT(*) AS micro_discount_rows,
    MIN(discount_amount) AS min_micro_discount,
    MAX(discount_amount) AS max_micro_discount
FROM staging.transactions
WHERE discount_amount > 0
  AND discount_amount < 0.000001;


-- ============================================================
-- PHASE 4 RESOLUTION REGISTER
-- ============================================================

DROP TABLE IF EXISTS staging.data_quality_resolutions;

CREATE TABLE staging.data_quality_resolutions (
    issue_name       TEXT PRIMARY KEY,
    observed_evidence TEXT NOT NULL,
    decision          TEXT NOT NULL,
    downstream_rule   TEXT NOT NULL,
    resolution_status TEXT NOT NULL
);

INSERT INTO staging.data_quality_resolutions
    (issue_name, observed_evidence, decision, downstream_rule, resolution_status)
VALUES

(
    'Non-positive quantity',
    '14,466 rows have quantity = 0; no negative quantities. Removing them leaves 2,500/2,500 customers and removes 595 baskets.',
    'Exclude from behavioral analytics because the source guide does not define quantity = 0 as a valid purchase or return state.',
    'Valid behavioral lines require quantity > 0 AND sales_amount >= 0.',
    'RESOLVED'
),

(
    'Zero sales with positive quantity',
    '4,451 rows have quantity > 0 and sales_amount = 0; 3,749 are promotional.',
    'Retain because positive quantity represents product activity and zero sales alone is not sufficient evidence of an invalid transaction.',
    'Include when quantity > 0 AND sales_amount >= 0.',
    'RESOLVED'
),

(
    'Missing category',
    '7,839 rows across 15 products have missing category and zero sales; after the behavioral validity filter, zero valid missing-category rows remain.',
    'Do not create a strategic Unknown category from these rows.',
    'Category metrics use valid behavioral lines with a non-null category.',
    'RESOLVED'
),

(
    'Scientific floating-point artifacts',
    '29 micro-positive sales rows and 34 micro-discount rows exist. All 29 micro-sales rows have quantity = 0; 28 of 34 micro-discount rows have quantity = 0.',
    'Preserve source numeric values; do not silently round or rewrite them.',
    'Behavioral filter removes invalid quantity rows; remaining non-zero discounts follow the canonical promotion rule.',
    'RESOLVED'
),

(
    'Gasoline quantity scale',
    '24,962 gasoline lines account for 257,331,979 of 260,685,622 valid quantity units (98.71%). Non-gasoline quantity has median 1, p99 5, p99.9 10 and max 144.',
    'Retain gasoline transactions for sales, basket, customer, category and promotion analysis. The source guide does not document a gasoline-specific quantity unit, so do not interpret or convert the quantity values.',
    'Exclude GASOLINE-REG UNLEADED quantity only from item-count quantity metrics such as average_items_per_basket.',
    'RESOLVED'
),

(
    'High sales values',
    'Maximum line sales is 840; upper-tail examples are gift cards, tickets, seasonal products, baskets and fuel.',
    'Retain. Observed values have plausible product context and there is no evidence that they are data errors.',
    'No sales-value outlier exclusion at the SQL analytics stage.',
    'RESOLVED'
);

SELECT *
FROM staging.data_quality_resolutions
ORDER BY issue_name;
