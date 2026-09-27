\set ON_ERROR_STOP on
\timing on

-- ============================================================
-- FMCG Consumer Growth & Promotion Insights
-- Phase 5.2: Customer x Category Metrics
-- ============================================================
--
-- Grain:
--   one row per customer x category
--
-- Behavioral validity:
--   quantity > 0
--   AND sales_amount >= 0
--
-- Category validity:
--   category IS NOT NULL
--
-- Gasoline quantity:
--   gasoline transactions remain in sales, basket and
--   promotion metrics, but their quantity contribution is
--   excluded from countable-item quantity metrics.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.customer_category_metrics;

CREATE TABLE analytics.customer_category_metrics AS

WITH valid_lines AS (
    SELECT
        t.customer_id,
        t.basket_id,
        t.product_id,
        t.sales_amount,
        t.quantity,
        t.promo_line_flag,

        p.category,
        p.subcategory,

        CASE
            WHEN p.subcategory = 'GASOLINE-REG UNLEADED'
                THEN 0::NUMERIC
            ELSE t.quantity
        END AS countable_quantity

    FROM staging.transactions t

    LEFT JOIN staging.products p
        ON t.product_id = p.product_id

    WHERE t.quantity > 0
      AND t.sales_amount >= 0
      AND p.category IS NOT NULL
),

aggregated AS (
    SELECT
        customer_id,
        category,

        SUM(sales_amount) AS category_spend,

        COUNT(
            DISTINCT basket_id
        )::BIGINT AS category_transactions,

        SUM(countable_quantity) AS category_quantity,

        COALESCE(
            SUM(sales_amount) FILTER (
                WHERE promo_line_flag = 1
            ),
            0
        ) AS category_promo_spend,

        COUNT(
            DISTINCT basket_id
        ) FILTER (
            WHERE promo_line_flag = 1
        )::BIGINT AS category_promo_transactions

    FROM valid_lines

    GROUP BY
        customer_id,
        category
),

with_shares AS (
    SELECT
        a.customer_id,
        a.category,
        a.category_spend,
        a.category_transactions,
        a.category_quantity,

        a.category_spend
            / NULLIF(cm.total_spend, 0)
            AS category_spend_share,

        a.category_promo_spend,
        a.category_promo_transactions,

        a.category_promo_spend
            / NULLIF(a.category_spend, 0)
            AS category_promo_spend_share

    FROM aggregated a

    INNER JOIN analytics.customer_metrics cm
        ON a.customer_id = cm.customer_id
),

ranked AS (
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY
                category_spend DESC,
                category_transactions DESC,
                category ASC
        )::INTEGER AS category_rank

    FROM with_shares
)

SELECT
    customer_id,
    category,
    category_spend,
    category_transactions,
    category_quantity,
    category_spend_share,
    category_promo_spend,
    category_promo_transactions,
    category_promo_spend_share,
    category_rank

FROM ranked

ORDER BY
    customer_id,
    category_rank,
    category
;

-- ============================================================
-- INDEXES
-- ============================================================

CREATE UNIQUE INDEX idx_customer_category_grain
    ON analytics.customer_category_metrics(
        customer_id,
        category
    );

CREATE INDEX idx_customer_category_customer
    ON analytics.customer_category_metrics(customer_id);

CREATE INDEX idx_customer_category_category
    ON analytics.customer_category_metrics(category);

CREATE INDEX idx_customer_category_rank
    ON analytics.customer_category_metrics(
        customer_id,
        category_rank
    );

ANALYZE analytics.customer_category_metrics;

-- ============================================================
-- VALIDATION 1: GRAIN / NULL CHECK
-- ============================================================

SELECT
    COUNT(*) AS rows,
    COUNT(
        DISTINCT (customer_id, category)
    ) AS distinct_customer_categories,

    COUNT(*) FILTER (
        WHERE customer_id IS NULL
    ) AS null_customer_ids,

    COUNT(*) FILTER (
        WHERE category IS NULL
    ) AS null_categories

FROM analytics.customer_category_metrics;

-- ============================================================
-- VALIDATION 2: CATEGORY SALES RECONCILIATION
-- ============================================================

WITH source AS (
    SELECT
        SUM(t.sales_amount) AS source_sales
    FROM staging.transactions t
    LEFT JOIN staging.products p
        ON t.product_id = p.product_id
    WHERE t.quantity > 0
      AND t.sales_amount >= 0
      AND p.category IS NOT NULL
),

category AS (
    SELECT
        SUM(category_spend) AS category_sales
    FROM analytics.customer_category_metrics
)

SELECT
    s.source_sales,
    c.category_sales,
    c.category_sales - s.source_sales AS difference
FROM source s
CROSS JOIN category c;

-- ============================================================
-- VALIDATION 3: COUNTABLE QUANTITY RECONCILIATION
-- ============================================================

WITH source AS (
    SELECT
        SUM(
            CASE
                WHEN p.subcategory = 'GASOLINE-REG UNLEADED'
                    THEN 0::NUMERIC
                ELSE t.quantity
            END
        ) AS source_quantity

    FROM staging.transactions t

    LEFT JOIN staging.products p
        ON t.product_id = p.product_id

    WHERE t.quantity > 0
      AND t.sales_amount >= 0
      AND p.category IS NOT NULL
),

category AS (
    SELECT
        SUM(category_quantity) AS category_quantity
    FROM analytics.customer_category_metrics
)

SELECT
    s.source_quantity,
    c.category_quantity,
    c.category_quantity - s.source_quantity AS difference
FROM source s
CROSS JOIN category c;

-- ============================================================
-- VALIDATION 4: PROMOTIONAL SALES RECONCILIATION
-- ============================================================

WITH source AS (
    SELECT
        COALESCE(
            SUM(t.sales_amount) FILTER (
                WHERE t.promo_line_flag = 1
            ),
            0
        ) AS source_promo_sales

    FROM staging.transactions t

    LEFT JOIN staging.products p
        ON t.product_id = p.product_id

    WHERE t.quantity > 0
      AND t.sales_amount >= 0
      AND p.category IS NOT NULL
),

category AS (
    SELECT
        SUM(category_promo_spend) AS category_promo_sales
    FROM analytics.customer_category_metrics
)

SELECT
    s.source_promo_sales,
    c.category_promo_sales,
    c.category_promo_sales - s.source_promo_sales AS difference
FROM source s
CROSS JOIN category c;

-- ============================================================
-- VALIDATION 5: SHARE SANITY
-- ============================================================

SELECT
    COUNT(*) FILTER (
        WHERE category_spend_share < 0
           OR category_spend_share > 1
    ) AS invalid_category_spend_share,

    COUNT(*) FILTER (
        WHERE category_promo_spend_share < 0
           OR category_promo_spend_share > 1
    ) AS invalid_category_promo_share,

    COUNT(*) FILTER (
        WHERE category_transactions <= 0
    ) AS invalid_category_transactions,

    COUNT(*) FILTER (
        WHERE category_quantity < 0
    ) AS negative_category_quantity

FROM analytics.customer_category_metrics;

-- ============================================================
-- VALIDATION 6: CUSTOMER SHARE SUM
-- ============================================================

WITH customer_shares AS (
    SELECT
        customer_id,
        SUM(category_spend_share) AS total_category_share
    FROM analytics.customer_category_metrics
    GROUP BY customer_id
)

SELECT
    MIN(total_category_share) AS min_customer_category_share,
    MAX(total_category_share) AS max_customer_category_share,

    COUNT(*) FILTER (
        WHERE ABS(total_category_share - 1) > 0.000001
    ) AS customers_not_reconciling_to_one

FROM customer_shares;

-- ============================================================
-- VALIDATION 7: RANK-1 UNIQUENESS
-- ============================================================

WITH rank_one AS (
    SELECT
        customer_id,
        COUNT(*) AS rank_one_rows
    FROM analytics.customer_category_metrics
    WHERE category_rank = 1
    GROUP BY customer_id
)

SELECT
    COUNT(*) AS customers_with_rank_one,
    COUNT(*) FILTER (
        WHERE rank_one_rows <> 1
    ) AS customers_with_invalid_rank_one_count
FROM rank_one;

-- ============================================================
-- VALIDATION 8: TOP CATEGORY RECONCILIATION
-- ============================================================

SELECT
    COUNT(*) AS top_category_mismatches
FROM analytics.customer_metrics cm

JOIN analytics.customer_category_metrics ccm
    ON cm.customer_id = ccm.customer_id
   AND ccm.category_rank = 1

WHERE cm.top_category IS DISTINCT FROM ccm.category;

-- ============================================================
-- SUMMARY
-- ============================================================

SELECT
    COUNT(*) AS category_rows,
    COUNT(DISTINCT customer_id) AS customers,
    COUNT(DISTINCT category) AS categories,

    MIN(category_spend) AS min_category_spend,
    MAX(category_spend) AS max_category_spend,

    MIN(category_transactions) AS min_category_transactions,
    MAX(category_transactions) AS max_category_transactions,

    MIN(category_rank) AS min_category_rank,
    MAX(category_rank) AS max_category_rank

FROM analytics.customer_category_metrics;

-- ============================================================
-- SAMPLE: CUSTOMER 1 TOP CATEGORIES
-- ============================================================

SELECT *
FROM analytics.customer_category_metrics
WHERE customer_id = 1
ORDER BY category_rank
LIMIT 10;
