\set ON_ERROR_STOP on
\timing on

-- ============================================================
-- FMCG Consumer Growth & Promotion Insights
-- Phase 3: Staging and Canonical Mapping
-- ============================================================
--
-- IMPORTANT TIME RULE
-- -------------------
-- The source dataset contains sequential DAY/WEEK_NO indices,
-- not real-world calendar dates.
--
-- For deterministic calendar-based calculations:
--   DAY 1 = 2000-01-01 (synthetic anchor)
--
-- transaction_date / start_date / end_date / redeem_date are
-- therefore synthetic analytical dates, not historical dates.
-- Original day indices are retained alongside them.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;

DROP TABLE IF EXISTS staging.redemptions;
DROP TABLE IF EXISTS staging.promotions;
DROP TABLE IF EXISTS staging.transactions;
DROP TABLE IF EXISTS staging.products;
DROP TABLE IF EXISTS staging.customers;

-- ============================================================
-- 1. CUSTOMERS
--
-- Customer universe is transaction-based.
-- Demographics are optional enrichment only.
-- ============================================================

CREATE TABLE staging.customers AS
WITH transaction_customers AS (
    SELECT DISTINCT
        CASE
            WHEN BTRIM(household_key) ~ '^[0-9]+$'
                THEN BTRIM(household_key)::INTEGER
            ELSE NULL
        END AS customer_id
    FROM raw.transaction_data
),
demographics AS (
    SELECT
        CASE
            WHEN BTRIM(household_key) ~ '^[0-9]+$'
                THEN BTRIM(household_key)::INTEGER
            ELSE NULL
        END AS customer_id,
        NULLIF(BTRIM(classification_1), '') AS classification_1,
        NULLIF(BTRIM(classification_2), '') AS classification_2,
        NULLIF(BTRIM(classification_3), '') AS classification_3,
        NULLIF(BTRIM(homeowner_desc), '') AS homeowner_desc,
        NULLIF(BTRIM(classification_5), '') AS classification_5,
        NULLIF(BTRIM(classification_4), '') AS classification_4,
        NULLIF(BTRIM(kid_category_desc), '') AS kid_category_desc
    FROM raw.hh_demographic
)
SELECT
    tc.customer_id,
    d.classification_1,
    d.classification_2,
    d.classification_3,
    d.homeowner_desc,
    d.classification_5,
    d.classification_4,
    d.kid_category_desc,
    (d.customer_id IS NOT NULL) AS has_demographics
FROM transaction_customers tc
LEFT JOIN demographics d
    ON tc.customer_id = d.customer_id
WHERE tc.customer_id IS NOT NULL;

-- ============================================================
-- 2. PRODUCTS
--
-- Canonical category = source COMMODITY_DESC
-- ============================================================

CREATE TABLE staging.products AS
SELECT
    CASE
        WHEN BTRIM(product_id) ~ '^[0-9]+$'
            THEN BTRIM(product_id)::BIGINT
        ELSE NULL
    END AS product_id,

    NULLIF(BTRIM(commodity_desc), '') AS category,
    NULLIF(BTRIM(department), '') AS department,
    NULLIF(BTRIM(sub_commodity_desc), '') AS subcategory,
    NULLIF(BTRIM(brand), '') AS brand,
    NULLIF(BTRIM(manufacturer), '') AS manufacturer,
    NULLIF(BTRIM(curr_size_of_product), '') AS package_size
FROM raw.product;

-- ============================================================
-- 3. TRANSACTIONS
-- ============================================================

CREATE TABLE staging.transactions AS
WITH parsed AS (
    SELECT
        CASE
            WHEN BTRIM(household_key) ~ '^[0-9]+$'
                THEN BTRIM(household_key)::INTEGER
            ELSE NULL
        END AS customer_id,

        CASE
            WHEN BTRIM(basket_id) ~ '^[0-9]+$'
                THEN BTRIM(basket_id)::BIGINT
            ELSE NULL
        END AS basket_id,

        CASE
            WHEN BTRIM(day) ~ '^[0-9]+$'
                THEN BTRIM(day)::INTEGER
            ELSE NULL
        END AS day_index,

        CASE
            WHEN BTRIM(product_id) ~ '^[0-9]+$'
                THEN BTRIM(product_id)::BIGINT
            ELSE NULL
        END AS product_id,

        CASE
            WHEN BTRIM(quantity)
                 ~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'
                THEN BTRIM(quantity)::NUMERIC
            ELSE NULL
        END AS quantity,

        CASE
            WHEN BTRIM(sales_value)
                 ~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'
                THEN BTRIM(sales_value)::NUMERIC
            ELSE NULL
        END AS sales_amount,

        CASE
            WHEN BTRIM(store_id) ~ '^[0-9]+$'
                THEN BTRIM(store_id)::INTEGER
            ELSE NULL
        END AS store_id,

        CASE
            WHEN BTRIM(retail_disc)
                 ~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'
                THEN BTRIM(retail_disc)::NUMERIC
            ELSE NULL
        END AS retail_discount,

        CASE
            WHEN BTRIM(trans_time) ~ '^[0-9]+$'
                THEN BTRIM(trans_time)::INTEGER
            ELSE NULL
        END AS transaction_time_index,

        CASE
            WHEN BTRIM(week_no) ~ '^[0-9]+$'
                THEN BTRIM(week_no)::INTEGER
            ELSE NULL
        END AS week_no,

        CASE
            WHEN BTRIM(coupon_disc)
                 ~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'
                THEN BTRIM(coupon_disc)::NUMERIC
            ELSE NULL
        END AS coupon_discount,

        CASE
            WHEN BTRIM(coupon_match_disc)
                 ~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'
                THEN BTRIM(coupon_match_disc)::NUMERIC
            ELSE NULL
        END AS coupon_match_discount

    FROM raw.transaction_data
),
normalized AS (
    SELECT
        *,
        CASE
            WHEN day_index IS NOT NULL
                THEN DATE '2000-01-01' + (day_index - 1)
            ELSE NULL
        END AS transaction_date,

        CASE
            WHEN transaction_time_index BETWEEN 0 AND 2359
             AND MOD(transaction_time_index, 100) BETWEEN 0 AND 59
                THEN MAKE_TIME(
                    transaction_time_index / 100,
                    MOD(transaction_time_index, 100),
                    0
                )
            ELSE NULL
        END AS transaction_time,

        COALESCE(ABS(retail_discount), 0)
        + COALESCE(ABS(coupon_discount), 0)
        + COALESCE(ABS(coupon_match_discount), 0)
            AS discount_amount

    FROM parsed
)
SELECT
    customer_id,
    basket_id,
    product_id,
    transaction_date,
    day_index,
    quantity,
    sales_amount,
    store_id,
    retail_discount,
    coupon_discount,
    coupon_match_discount,
    discount_amount,

    CASE
        WHEN discount_amount > 0 THEN 1
        ELSE 0
    END::SMALLINT AS promo_line_flag,

    week_no,
    transaction_time,
    TRUE AS date_is_synthetic

FROM normalized;

-- ============================================================
-- 4. PROMOTIONS
--
-- Grain: one row per campaign/promotion.
-- Product/customer associations are not present at this grain.
-- Core promotional-purchase logic remains transaction-discount
-- based, per project specification.
-- ============================================================

CREATE TABLE staging.promotions AS
WITH parsed AS (
    SELECT
        CASE
            WHEN BTRIM(campaign) ~ '^[0-9]+$'
                THEN BTRIM(campaign)::INTEGER
            ELSE NULL
        END AS promotion_id,

        NULLIF(BTRIM(description), '') AS promotion_type,

        CASE
            WHEN BTRIM(start_day) ~ '^[0-9]+$'
                THEN BTRIM(start_day)::INTEGER
            ELSE NULL
        END AS start_day_index,

        CASE
            WHEN BTRIM(end_day) ~ '^[0-9]+$'
                THEN BTRIM(end_day)::INTEGER
            ELSE NULL
        END AS end_day_index

    FROM raw.campaign_desc
)
SELECT
    promotion_id,
    promotion_type,
    start_day_index,
    end_day_index,

    CASE
        WHEN start_day_index IS NOT NULL
            THEN DATE '2000-01-01' + (start_day_index - 1)
        ELSE NULL
    END AS start_date,

    CASE
        WHEN end_day_index IS NOT NULL
            THEN DATE '2000-01-01' + (end_day_index - 1)
        ELSE NULL
    END AS end_date,

    NULL::BIGINT AS product_id,
    NULL::INTEGER AS customer_id,
    TRUE AS date_is_synthetic

FROM parsed;

-- ============================================================
-- 5. COUPON REDEMPTIONS
--
-- A coupon may map to multiple eligible products, so an exact
-- redeemed PRODUCT_ID cannot be inferred from coupon.csv.
-- product_id therefore remains NULL rather than fabricating an
-- association.
-- ============================================================

CREATE TABLE staging.redemptions AS
WITH parsed AS (
    SELECT
        CASE
            WHEN BTRIM(household_key) ~ '^[0-9]+$'
                THEN BTRIM(household_key)::INTEGER
            ELSE NULL
        END AS customer_id,

        CASE
            WHEN BTRIM(campaign) ~ '^[0-9]+$'
                THEN BTRIM(campaign)::INTEGER
            ELSE NULL
        END AS promotion_id,

        CASE
            WHEN BTRIM(day) ~ '^[0-9]+$'
                THEN BTRIM(day)::INTEGER
            ELSE NULL
        END AS redeem_day_index,

        CASE
            WHEN BTRIM(coupon_upc) ~ '^[0-9]+$'
                THEN BTRIM(coupon_upc)::BIGINT
            ELSE NULL
        END AS coupon_upc

    FROM raw.coupon_redempt
)
SELECT
    customer_id,
    promotion_id,
    coupon_upc,

    CASE
        WHEN redeem_day_index IS NOT NULL
            THEN DATE '2000-01-01' + (redeem_day_index - 1)
        ELSE NULL
    END AS redeem_date,

    redeem_day_index,
    NULL::BIGINT AS product_id,
    TRUE AS date_is_synthetic

FROM parsed;

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_staging_customers_customer_id
    ON staging.customers(customer_id);

CREATE INDEX idx_staging_products_product_id
    ON staging.products(product_id);

CREATE INDEX idx_staging_transactions_customer_id
    ON staging.transactions(customer_id);

CREATE INDEX idx_staging_transactions_basket_id
    ON staging.transactions(basket_id);

CREATE INDEX idx_staging_transactions_product_id
    ON staging.transactions(product_id);

CREATE INDEX idx_staging_transactions_date
    ON staging.transactions(transaction_date);

CREATE INDEX idx_staging_redemptions_customer_id
    ON staging.redemptions(customer_id);

CREATE INDEX idx_staging_redemptions_promotion_id
    ON staging.redemptions(promotion_id);

ANALYZE staging.customers;
ANALYZE staging.products;
ANALYZE staging.transactions;
ANALYZE staging.promotions;
ANALYZE staging.redemptions;

-- ============================================================
-- STAGING ROW-COUNT CHECK
-- ============================================================

SELECT *
FROM (
    SELECT
        'customers'::TEXT AS table_name,
        2500::BIGINT AS expected_rows,
        COUNT(*)::BIGINT AS actual_rows
    FROM staging.customers

    UNION ALL

    SELECT
        'products',
        92353,
        COUNT(*)
    FROM staging.products

    UNION ALL

    SELECT
        'transactions',
        2595732,
        COUNT(*)
    FROM staging.transactions

    UNION ALL

    SELECT
        'promotions',
        30,
        COUNT(*)
    FROM staging.promotions

    UNION ALL

    SELECT
        'redemptions',
        2318,
        COUNT(*)
    FROM staging.redemptions
) checks
ORDER BY table_name;

-- ============================================================
-- DATE / PROMOTION SANITY CHECK
-- ============================================================

SELECT
    MIN(day_index) AS min_day_index,
    MAX(day_index) AS max_day_index,
    MIN(transaction_date) AS min_transaction_date,
    MAX(transaction_date) AS max_transaction_date,
    COUNT(*) FILTER (WHERE promo_line_flag = 1) AS promo_lines,
    COUNT(*) FILTER (WHERE promo_line_flag = 0) AS nonpromo_lines
FROM staging.transactions;

-- ============================================================
-- CANONICAL SAMPLE
-- ============================================================

SELECT
    customer_id,
    basket_id,
    product_id,
    transaction_date,
    day_index,
    quantity,
    sales_amount,
    retail_discount,
    coupon_discount,
    coupon_match_discount,
    discount_amount,
    promo_line_flag
FROM staging.transactions
WHERE customer_id = 2375
  AND basket_id = 26984851472
  AND product_id = 1004906
LIMIT 1;
