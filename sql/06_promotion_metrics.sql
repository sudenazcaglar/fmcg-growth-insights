\set ON_ERROR_STOP on
\timing on

-- ============================================================
-- FMCG Consumer Growth & Promotion Insights
-- Phase 5.3: Customer Promotion Metrics
-- ============================================================
--
-- Grain:
--   one row per customer
--
-- Behavioral validity:
--   quantity > 0
--   AND sales_amount >= 0
--
-- Promotional basket:
--   any VALID basket containing at least one VALID line with
--   promo_line_flag = 1
--
-- IMPORTANT:
--   promo_sales / nonpromo_sales classify the FULL basket sales
--   according to basket promotional status.
--
--   promotion_spend_share retains the project-wide definition:
--   promotional LINE sales / total customer sales.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.promotion_metrics;

CREATE TABLE analytics.promotion_metrics AS

WITH valid_lines AS (
    SELECT
        customer_id,
        basket_id,
        sales_amount,
        promo_line_flag

    FROM staging.transactions

    WHERE quantity > 0
      AND sales_amount >= 0
),

basket_level AS (
    SELECT
        customer_id,
        basket_id,

        SUM(sales_amount) AS basket_sales,

        MAX(promo_line_flag)::SMALLINT
            AS promo_basket_flag

    FROM valid_lines

    GROUP BY
        customer_id,
        basket_id
),

customer_basket_metrics AS (
    SELECT
        customer_id,

        COUNT(*) FILTER (
            WHERE promo_basket_flag = 1
        )::BIGINT AS promo_baskets,

        COUNT(*) FILTER (
            WHERE promo_basket_flag = 0
        )::BIGINT AS nonpromo_baskets,

        COALESCE(
            SUM(basket_sales) FILTER (
                WHERE promo_basket_flag = 1
            ),
            0
        ) AS promo_sales,

        COALESCE(
            SUM(basket_sales) FILTER (
                WHERE promo_basket_flag = 0
            ),
            0
        ) AS nonpromo_sales

    FROM basket_level

    GROUP BY customer_id
),

customer_line_metrics AS (
    SELECT
        customer_id,

        SUM(sales_amount) AS total_sales,

        COALESCE(
            SUM(sales_amount) FILTER (
                WHERE promo_line_flag = 1
            ),
            0
        ) AS promo_line_sales

    FROM valid_lines

    GROUP BY customer_id
)

SELECT
    cbm.customer_id,

    cbm.promo_baskets,
    cbm.nonpromo_baskets,

    cbm.promo_sales,
    cbm.nonpromo_sales,

    cbm.promo_sales
        / NULLIF(cbm.promo_baskets, 0)
        AS promo_average_basket_value,

    cbm.nonpromo_sales
        / NULLIF(cbm.nonpromo_baskets, 0)
        AS nonpromo_average_basket_value,

    cbm.promo_baskets::NUMERIC
        / NULLIF(
            cbm.promo_baskets + cbm.nonpromo_baskets,
            0
        )
        AS promotion_purchase_share,

    clm.promo_line_sales
        / NULLIF(clm.total_sales, 0)
        AS promotion_spend_share

FROM customer_basket_metrics cbm

INNER JOIN customer_line_metrics clm
    ON cbm.customer_id = clm.customer_id

ORDER BY cbm.customer_id
;

-- ============================================================
-- INDEX
-- ============================================================

CREATE UNIQUE INDEX idx_promotion_metrics_customer_id
    ON analytics.promotion_metrics(customer_id);

ANALYZE analytics.promotion_metrics;

-- ============================================================
-- VALIDATION 1: GRAIN
-- ============================================================

SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT customer_id) AS distinct_customers,

    COUNT(*) FILTER (
        WHERE customer_id IS NULL
    ) AS null_customer_ids

FROM analytics.promotion_metrics;

-- ============================================================
-- VALIDATION 2: BASKET RECONCILIATION
-- ============================================================

WITH source AS (
    SELECT
        COUNT(DISTINCT basket_id)::BIGINT AS source_baskets
    FROM staging.transactions
    WHERE quantity > 0
      AND sales_amount >= 0
),

analytics AS (
    SELECT
        SUM(promo_baskets + nonpromo_baskets)::BIGINT
            AS analytics_baskets
    FROM analytics.promotion_metrics
)

SELECT
    s.source_baskets,
    a.analytics_baskets,
    a.analytics_baskets - s.source_baskets
        AS basket_difference

FROM source s
CROSS JOIN analytics a;

-- ============================================================
-- VALIDATION 3: SALES RECONCILIATION
-- ============================================================

WITH source AS (
    SELECT
        SUM(sales_amount) AS source_sales
    FROM staging.transactions
    WHERE quantity > 0
      AND sales_amount >= 0
),

analytics AS (
    SELECT
        SUM(promo_sales + nonpromo_sales)
            AS analytics_sales
    FROM analytics.promotion_metrics
)

SELECT
    s.source_sales,
    a.analytics_sales,
    a.analytics_sales - s.source_sales
        AS sales_difference

FROM source s
CROSS JOIN analytics a;

-- ============================================================
-- VALIDATION 4: PROMO / NONPROMO BASKET RECONCILIATION
-- ============================================================

WITH valid_lines AS (
    SELECT
        customer_id,
        basket_id,
        promo_line_flag
    FROM staging.transactions
    WHERE quantity > 0
      AND sales_amount >= 0
),

basket_level AS (
    SELECT
        customer_id,
        basket_id,
        MAX(promo_line_flag) AS promo_basket_flag
    FROM valid_lines
    GROUP BY
        customer_id,
        basket_id
),

source AS (
    SELECT
        COUNT(*) FILTER (
            WHERE promo_basket_flag = 1
        )::BIGINT AS source_promo_baskets,

        COUNT(*) FILTER (
            WHERE promo_basket_flag = 0
        )::BIGINT AS source_nonpromo_baskets

    FROM basket_level
),

analytics AS (
    SELECT
        SUM(promo_baskets)::BIGINT
            AS analytics_promo_baskets,

        SUM(nonpromo_baskets)::BIGINT
            AS analytics_nonpromo_baskets

    FROM analytics.promotion_metrics
)

SELECT
    s.source_promo_baskets,
    a.analytics_promo_baskets,
    a.analytics_promo_baskets - s.source_promo_baskets
        AS promo_difference,

    s.source_nonpromo_baskets,
    a.analytics_nonpromo_baskets,
    a.analytics_nonpromo_baskets - s.source_nonpromo_baskets
        AS nonpromo_difference

FROM source s
CROSS JOIN analytics a;

-- ============================================================
-- VALIDATION 5: SHARE SANITY
-- ============================================================

SELECT
    COUNT(*) FILTER (
        WHERE promotion_purchase_share < 0
           OR promotion_purchase_share > 1
    ) AS invalid_promotion_purchase_share,

    COUNT(*) FILTER (
        WHERE promotion_spend_share < 0
           OR promotion_spend_share > 1
    ) AS invalid_promotion_spend_share,

    COUNT(*) FILTER (
        WHERE promo_baskets < 0
           OR nonpromo_baskets < 0
    ) AS invalid_basket_counts,

    COUNT(*) FILTER (
        WHERE promo_sales < 0
           OR nonpromo_sales < 0
    ) AS invalid_sales_values

FROM analytics.promotion_metrics;

-- ============================================================
-- VALIDATION 6: CUSTOMER_METRICS RECONCILIATION
-- ============================================================

SELECT
    COUNT(*) AS mismatched_customers

FROM analytics.promotion_metrics pm

INNER JOIN analytics.customer_metrics cm
    ON pm.customer_id = cm.customer_id

WHERE ABS(
        pm.promotion_purchase_share
        - cm.promotion_purchase_share
    ) > 0.000000001

   OR ABS(
        pm.promotion_spend_share
        - cm.promotion_spend_share
    ) > 0.000000001;

-- ============================================================
-- VALIDATION 7: ZERO-DENOMINATOR PROFILE
-- ============================================================

SELECT
    COUNT(*) FILTER (
        WHERE promo_baskets = 0
    ) AS customers_with_no_promo_baskets,

    COUNT(*) FILTER (
        WHERE nonpromo_baskets = 0
    ) AS customers_with_no_nonpromo_baskets,

    COUNT(*) FILTER (
        WHERE promo_average_basket_value IS NULL
    ) AS null_promo_abv,

    COUNT(*) FILTER (
        WHERE nonpromo_average_basket_value IS NULL
    ) AS null_nonpromo_abv

FROM analytics.promotion_metrics;

-- ============================================================
-- VALIDATION 8: TOTAL PROMOTIONAL LINE SALES
-- ============================================================

WITH source AS (
    SELECT
        COALESCE(
            SUM(sales_amount) FILTER (
                WHERE promo_line_flag = 1
            ),
            0
        ) AS source_promo_line_sales

    FROM staging.transactions

    WHERE quantity > 0
      AND sales_amount >= 0
),

reconstructed AS (
    SELECT
        SUM(
            cm.total_spend
            * pm.promotion_spend_share
        ) AS reconstructed_promo_line_sales

    FROM analytics.promotion_metrics pm

    INNER JOIN analytics.customer_metrics cm
        ON pm.customer_id = cm.customer_id
)

SELECT
    s.source_promo_line_sales,
    r.reconstructed_promo_line_sales,
    r.reconstructed_promo_line_sales
        - s.source_promo_line_sales
        AS difference

FROM source s
CROSS JOIN reconstructed r;

-- ============================================================
-- SUMMARY
-- ============================================================

SELECT
    COUNT(*) AS customers,

    SUM(promo_baskets) AS total_promo_baskets,
    SUM(nonpromo_baskets) AS total_nonpromo_baskets,

    SUM(promo_sales) AS total_promo_basket_sales,
    SUM(nonpromo_sales) AS total_nonpromo_basket_sales,

    MIN(promotion_purchase_share)
        AS min_promotion_purchase_share,

    MAX(promotion_purchase_share)
        AS max_promotion_purchase_share,

    MIN(promotion_spend_share)
        AS min_promotion_spend_share,

    MAX(promotion_spend_share)
        AS max_promotion_spend_share

FROM analytics.promotion_metrics;

-- ============================================================
-- SAMPLE
-- ============================================================

SELECT *
FROM analytics.promotion_metrics
ORDER BY customer_id
LIMIT 10;
