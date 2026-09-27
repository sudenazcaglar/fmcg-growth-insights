\set ON_ERROR_STOP on
\timing on

-- ============================================================
-- FMCG Consumer Growth & Promotion Insights
-- Phase 2: Raw schema and source ingestion
--
-- Raw-layer principle:
--   - preserve source rows and values
--   - defer canonical renaming, type conversion and business
--     transformations to the staging layer
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;

-- ------------------------------------------------------------
-- Source: campaign_desc.csv
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.campaign_desc (
    description TEXT,
    campaign TEXT,
    start_day TEXT,
    end_day TEXT
);

-- ------------------------------------------------------------
-- Source: campaign_table.csv
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.campaign_table (
    description TEXT,
    household_key TEXT,
    campaign TEXT
);

-- ------------------------------------------------------------
-- Source: causal_data.csv
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.causal_data (
    product_id TEXT,
    store_id TEXT,
    week_no TEXT,
    display TEXT,
    mailer TEXT
);

-- ------------------------------------------------------------
-- Source: coupon.csv
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.coupon (
    coupon_upc TEXT,
    product_id TEXT,
    campaign TEXT
);

-- ------------------------------------------------------------
-- Source: coupon_redempt.csv
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.coupon_redempt (
    household_key TEXT,
    day TEXT,
    coupon_upc TEXT,
    campaign TEXT
);

-- ------------------------------------------------------------
-- Source: hh_demographic.csv
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.hh_demographic (
    classification_1 TEXT,
    classification_2 TEXT,
    classification_3 TEXT,
    homeowner_desc TEXT,
    classification_5 TEXT,
    classification_4 TEXT,
    kid_category_desc TEXT,
    household_key TEXT
);

-- ------------------------------------------------------------
-- Source: product.csv
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.product (
    product_id TEXT,
    manufacturer TEXT,
    department TEXT,
    brand TEXT,
    commodity_desc TEXT,
    sub_commodity_desc TEXT,
    curr_size_of_product TEXT
);

-- ------------------------------------------------------------
-- Source: transaction_data.csv
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.transaction_data (
    household_key TEXT,
    basket_id TEXT,
    day TEXT,
    product_id TEXT,
    quantity TEXT,
    sales_value TEXT,
    store_id TEXT,
    retail_disc TEXT,
    trans_time TEXT,
    week_no TEXT,
    coupon_disc TEXT,
    coupon_match_disc TEXT
);

-- Re-running this script must not duplicate raw data.
TRUNCATE TABLE
    raw.campaign_desc,
    raw.campaign_table,
    raw.causal_data,
    raw.coupon,
    raw.coupon_redempt,
    raw.hh_demographic,
    raw.product,
    raw.transaction_data;

\echo 'Loading campaign_desc.csv'
\copy raw.campaign_desc FROM 'data/raw/campaign_desc.csv' WITH (FORMAT csv, HEADER true, NULL '\N', ENCODING 'UTF8');

\echo 'Loading campaign_table.csv'
\copy raw.campaign_table FROM 'data/raw/campaign_table.csv' WITH (FORMAT csv, HEADER true, NULL '\N', ENCODING 'UTF8');

\echo 'Loading coupon.csv'
\copy raw.coupon FROM 'data/raw/coupon.csv' WITH (FORMAT csv, HEADER true, NULL '\N', ENCODING 'UTF8');

\echo 'Loading coupon_redempt.csv'
\copy raw.coupon_redempt FROM 'data/raw/coupon_redempt.csv' WITH (FORMAT csv, HEADER true, NULL '\N', ENCODING 'UTF8');

\echo 'Loading hh_demographic.csv'
\copy raw.hh_demographic FROM 'data/raw/hh_demographic.csv' WITH (FORMAT csv, HEADER true, NULL '\N', ENCODING 'UTF8');

\echo 'Loading product.csv'
\copy raw.product FROM 'data/raw/product.csv' WITH (FORMAT csv, HEADER true, NULL '\N', ENCODING 'UTF8');

\echo 'Loading transaction_data.csv'
\copy raw.transaction_data FROM 'data/raw/transaction_data.csv' WITH (FORMAT csv, HEADER true, NULL '\N', ENCODING 'UTF8');

-- Largest file; intentionally loaded last.
\echo 'Loading causal_data.csv'
\copy raw.causal_data FROM 'data/raw/causal_data.csv' WITH (FORMAT csv, HEADER true, NULL '\N', ENCODING 'UTF8');

-- ============================================================
-- Raw row-count reconciliation
-- ============================================================
SELECT
    source_file,
    expected_rows,
    loaded_rows,
    CASE
        WHEN expected_rows = loaded_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM (
    SELECT
        'campaign_desc.csv'::TEXT AS source_file,
        30::BIGINT AS expected_rows,
        COUNT(*)::BIGINT AS loaded_rows
    FROM raw.campaign_desc

    UNION ALL

    SELECT
        'campaign_table.csv',
        7208,
        COUNT(*)
    FROM raw.campaign_table

    UNION ALL

    SELECT
        'causal_data.csv',
        36786524,
        COUNT(*)
    FROM raw.causal_data

    UNION ALL

    SELECT
        'coupon.csv',
        124548,
        COUNT(*)
    FROM raw.coupon

    UNION ALL

    SELECT
        'coupon_redempt.csv',
        2318,
        COUNT(*)
    FROM raw.coupon_redempt

    UNION ALL

    SELECT
        'hh_demographic.csv',
        801,
        COUNT(*)
    FROM raw.hh_demographic

    UNION ALL

    SELECT
        'product.csv',
        92353,
        COUNT(*)
    FROM raw.product

    UNION ALL

    SELECT
        'transaction_data.csv',
        2595732,
        COUNT(*)
    FROM raw.transaction_data
) AS reconciliation
ORDER BY source_file;
