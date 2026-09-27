\set ON_ERROR_STOP on
\timing on

-- ============================================================
-- FMCG Consumer Growth & Promotion Insights
-- Phase 5.1: Customer Metrics + Monthly Customer Activity
-- ============================================================
--
-- ANALYTICAL VALIDITY RULE
-- ------------------------
-- Behavioral transaction lines:
--
--     quantity > 0
--     AND sales_amount >= 0
--
-- GASOLINE QUANTITY RULE
-- ----------------------
-- GASOLINE-REG UNLEADED transactions remain valid for sales,
-- baskets, frequency, category and promotion analytics.
--
-- Their quantity values are excluded only from countable-item
-- quantity metrics because the source documentation does not
-- define a comparable gasoline quantity unit.
--
-- SALES SEMANTICS
-- ---------------
-- sales_amount represents retailer sales value attributed to
-- the customer, not customer out-of-pocket spend.
--
-- TIME SEMANTICS
-- --------------
-- transaction_date is based on the documented synthetic date
-- anchor established in staging. Recency uses the maximum
-- VALID transaction date in the dataset, never CURRENT_DATE.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.monthly_customer_activity;
DROP TABLE IF EXISTS analytics.customer_metrics;

-- ============================================================
-- CUSTOMER METRICS
-- Grain: one row per customer
-- ============================================================

CREATE TABLE analytics.customer_metrics AS

WITH valid_lines AS (
    SELECT
        t.customer_id,
        t.basket_id,
        t.product_id,
        t.transaction_date,
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
),

dataset_bounds AS (
    SELECT
        MAX(transaction_date) AS dataset_end_date
    FROM valid_lines
),

basket_level AS (
    SELECT
        customer_id,
        basket_id,
        MIN(transaction_date) AS transaction_date,
        SUM(sales_amount) AS basket_sales,
        SUM(countable_quantity) AS basket_countable_quantity,
        MAX(promo_line_flag)::SMALLINT AS promo_basket_flag

    FROM valid_lines

    GROUP BY
        customer_id,
        basket_id
),

customer_basket_metrics AS (
    SELECT
        customer_id,

        SUM(basket_sales) AS total_spend,

        COUNT(*)::BIGINT AS total_transactions,

        SUM(basket_sales)
            / NULLIF(COUNT(*), 0)
            AS average_basket_value,

        COUNT(
            DISTINCT DATE_TRUNC('month', transaction_date)
        )::INTEGER AS active_months,

        COUNT(*)::NUMERIC
            / NULLIF(
                COUNT(DISTINCT DATE_TRUNC('month', transaction_date)),
                0
            )
            AS purchase_frequency,

        MAX(transaction_date) AS latest_purchase_date,

        SUM(basket_countable_quantity)
            / NULLIF(COUNT(*), 0)
            AS average_items_per_basket,

        COUNT(*) FILTER (
            WHERE promo_basket_flag = 1
        )::BIGINT AS promotional_baskets

    FROM basket_level

    GROUP BY customer_id
),

customer_line_metrics AS (
    SELECT
        customer_id,

        COUNT(
            DISTINCT category
        ) FILTER (
            WHERE category IS NOT NULL
        )::INTEGER AS category_diversity,

        SUM(sales_amount) FILTER (
            WHERE promo_line_flag = 1
        ) AS promotional_line_sales

    FROM valid_lines

    GROUP BY customer_id
),

category_metrics AS (
    SELECT
        customer_id,
        category,

        SUM(sales_amount) AS category_spend,

        COUNT(
            DISTINCT basket_id
        )::BIGINT AS category_transactions

    FROM valid_lines

    WHERE category IS NOT NULL

    GROUP BY
        customer_id,
        category
),

ranked_categories AS (
    SELECT
        customer_id,
        category,
        category_spend,
        category_transactions,

        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY
                category_spend DESC,
                category_transactions DESC,
                category ASC
        ) AS category_rank

    FROM category_metrics
),

top_categories AS (
    SELECT
        customer_id,
        category AS top_category,
        category_spend AS top_category_spend

    FROM ranked_categories

    WHERE category_rank = 1
)

SELECT
    cbm.customer_id,

    cbm.total_spend,

    cbm.total_transactions,

    cbm.average_basket_value,

    cbm.active_months,

    cbm.purchase_frequency,

    (
        db.dataset_end_date
        - cbm.latest_purchase_date
    )::INTEGER AS recency_days,

    cbm.average_items_per_basket,

    clm.category_diversity,

    cbm.promotional_baskets::NUMERIC
        / NULLIF(cbm.total_transactions, 0)
        AS promotion_purchase_share,

    COALESCE(clm.promotional_line_sales, 0)::NUMERIC
        / NULLIF(cbm.total_spend, 0)
        AS promotion_spend_share,

    tc.top_category,

    tc.top_category_spend
        / NULLIF(cbm.total_spend, 0)
        AS top_category_share

FROM customer_basket_metrics cbm

JOIN customer_line_metrics clm
    ON cbm.customer_id = clm.customer_id

LEFT JOIN top_categories tc
    ON cbm.customer_id = tc.customer_id

CROSS JOIN dataset_bounds db

ORDER BY cbm.customer_id
;

-- ============================================================
-- MONTHLY CUSTOMER ACTIVITY
-- Grain: one row per customer x active calendar month
-- ============================================================

CREATE TABLE analytics.monthly_customer_activity AS

WITH valid_lines AS (
    SELECT
        t.customer_id,
        t.basket_id,
        t.transaction_date,
        t.sales_amount,
        t.quantity,
        t.promo_line_flag,
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
)

SELECT
    customer_id,

    DATE_TRUNC(
        'month',
        transaction_date
    )::DATE AS year_month,

    SUM(sales_amount) AS monthly_sales,

    COUNT(
        DISTINCT basket_id
    )::BIGINT AS monthly_transactions,

    SUM(countable_quantity) AS monthly_quantity,

    COALESCE(
        SUM(sales_amount) FILTER (
            WHERE promo_line_flag = 1
        ),
        0
    ) AS monthly_promo_sales,

    COUNT(
        DISTINCT basket_id
    ) FILTER (
        WHERE promo_line_flag = 1
    )::BIGINT AS monthly_promo_transactions,

    1::SMALLINT AS active_flag

FROM valid_lines

GROUP BY
    customer_id,
    DATE_TRUNC('month', transaction_date)::DATE

ORDER BY
    customer_id,
    year_month
;

-- ============================================================
-- INDEXES
-- ============================================================

CREATE UNIQUE INDEX idx_customer_metrics_customer_id
    ON analytics.customer_metrics(customer_id);

CREATE UNIQUE INDEX idx_monthly_activity_customer_month
    ON analytics.monthly_customer_activity(
        customer_id,
        year_month
    );

CREATE INDEX idx_monthly_activity_month
    ON analytics.monthly_customer_activity(year_month);

ANALYZE analytics.customer_metrics;
ANALYZE analytics.monthly_customer_activity;

-- ============================================================
-- VALIDATION 1: CUSTOMER GRAIN
-- ============================================================

SELECT
    COUNT(*) AS customer_rows,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    COUNT(*) FILTER (
        WHERE total_transactions <= 0
    ) AS customers_without_transactions,
    COUNT(*) FILTER (
        WHERE active_months <= 0
    ) AS customers_without_active_months,
    COUNT(*) FILTER (
        WHERE recency_days < 0
    ) AS negative_recency_customers
FROM analytics.customer_metrics;

-- ============================================================
-- VALIDATION 2: CUSTOMER METRIC RECONCILIATION
-- ============================================================

WITH valid_lines AS (
    SELECT
        t.*,
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
),

source_totals AS (
    SELECT
        SUM(sales_amount) AS source_sales,
        COUNT(DISTINCT basket_id) AS source_baskets,
        SUM(countable_quantity) AS source_countable_quantity
    FROM valid_lines
),

analytics_totals AS (
    SELECT
        SUM(total_spend) AS analytics_sales,
        SUM(total_transactions) AS analytics_baskets,

        SUM(
            average_items_per_basket
            * total_transactions
        ) AS analytics_countable_quantity
    FROM analytics.customer_metrics
)

SELECT
    s.source_sales,
    a.analytics_sales,
    a.analytics_sales - s.source_sales AS sales_difference,

    s.source_baskets,
    a.analytics_baskets,
    a.analytics_baskets - s.source_baskets AS basket_difference,

    s.source_countable_quantity,
    a.analytics_countable_quantity,
    a.analytics_countable_quantity
        - s.source_countable_quantity
        AS quantity_difference

FROM source_totals s
CROSS JOIN analytics_totals a;

-- ============================================================
-- VALIDATION 3: SHARE / CATEGORY SANITY
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
        WHERE top_category_share < 0
           OR top_category_share > 1
    ) AS invalid_top_category_share,

    COUNT(*) FILTER (
        WHERE category_diversity <= 0
    ) AS customers_without_categories,

    COUNT(*) FILTER (
        WHERE top_category IS NULL
    ) AS customers_without_top_category

FROM analytics.customer_metrics;

-- ============================================================
-- VALIDATION 4: MONTHLY RECONCILIATION
-- ============================================================

WITH valid_lines AS (
    SELECT
        t.*,
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
),

source_totals AS (
    SELECT
        SUM(sales_amount) AS source_sales,
        COUNT(DISTINCT basket_id) AS source_baskets,
        SUM(countable_quantity) AS source_quantity
    FROM valid_lines
),

monthly_totals AS (
    SELECT
        SUM(monthly_sales) AS monthly_sales,
        SUM(monthly_transactions) AS monthly_baskets,
        SUM(monthly_quantity) AS monthly_quantity
    FROM analytics.monthly_customer_activity
)

SELECT
    s.source_sales,
    m.monthly_sales,
    m.monthly_sales - s.source_sales AS sales_difference,

    s.source_baskets,
    m.monthly_baskets,
    m.monthly_baskets - s.source_baskets AS basket_difference,

    s.source_quantity,
    m.monthly_quantity,
    m.monthly_quantity - s.source_quantity AS quantity_difference

FROM source_totals s
CROSS JOIN monthly_totals m;

-- ============================================================
-- VALIDATION 5: DATASET / METRIC SUMMARY
-- ============================================================

SELECT
    MIN(total_spend) AS min_customer_spend,
    MAX(total_spend) AS max_customer_spend,

    MIN(total_transactions) AS min_transactions,
    MAX(total_transactions) AS max_transactions,

    MIN(active_months) AS min_active_months,
    MAX(active_months) AS max_active_months,

    MIN(recency_days) AS min_recency_days,
    MAX(recency_days) AS max_recency_days,

    MIN(average_items_per_basket) AS min_items_per_basket,
    MAX(average_items_per_basket) AS max_items_per_basket

FROM analytics.customer_metrics;

SELECT
    COUNT(*) AS monthly_rows,
    COUNT(DISTINCT customer_id) AS monthly_customers,
    MIN(year_month) AS first_month,
    MAX(year_month) AS last_month,
    MIN(active_flag) AS min_active_flag,
    MAX(active_flag) AS max_active_flag
FROM analytics.monthly_customer_activity;

-- ============================================================
-- SAMPLE
-- ============================================================

SELECT *
FROM analytics.customer_metrics
ORDER BY customer_id
LIMIT 10;
