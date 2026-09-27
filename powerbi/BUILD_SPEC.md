# Power BI Build Specification

## Output

`powerbi/consumer_growth_dashboard.pbix`

## Connection

Source: PostgreSQL `analytics` layer  
Mode: Import

Power BI Desktop connection values must come from the existing project database configuration.
Do not store database passwords in the PBIX documentation or Git.

---

# 1. Data Model

Use five imported model tables:

- `DimCustomer`
- `DimMonth`
- `DimCategory`
- `FactMonthlyActivity`
- `FactCustomerCategory`

Promotion summary metrics are merged into `DimCustomer`.

## 1.1 DimCustomer

Use this PostgreSQL query:

```sql
SELECT
    cm.customer_id,
    cm.total_spend,
    cm.total_transactions,
    cm.average_basket_value,
    cm.active_months,
    cm.purchase_frequency,
    cm.recency_days,
    cm.average_items_per_basket,
    cm.category_diversity,
    cm.promotion_purchase_share,
    cm.promotion_spend_share,
    cm.top_category,
    cm.top_category_share,
    cs.segment_id,
    cs.segment_name,
    cs.model_version,
    pm.promo_baskets,
    pm.nonpromo_baskets,
    pm.promo_sales,
    pm.nonpromo_sales,
    pm.promo_average_basket_value,
    pm.nonpromo_average_basket_value
FROM analytics.customer_metrics cm
LEFT JOIN analytics.customer_segments cs
    ON cm.customer_id = cs.customer_id
LEFT JOIN analytics.promotion_metrics pm
    ON cm.customer_id = pm.customer_id
ORDER BY cm.customer_id;
```

Expected grain:

> one row per customer

Expected rows:

> 2,500

---

## 1.2 FactMonthlyActivity

Use:

```
SELECT
    customer_id,
    year_month,
    monthly_sales,
    monthly_transactions,
    monthly_quantity,
    monthly_promo_sales,
    monthly_promo_transactions,
    active_flag
FROM analytics.monthly_customer_activity
ORDER BY customer_id, year_month;
```

Expected grain:

> one row per active customer × relative month

Expected rows:

> 45,298

The source date is synthetic and must not be described as real historical calendar time.

---

## 1.3 DimMonth

Use:

```
SELECT DISTINCT
    year_month,
    DENSE_RANK() OVER (
        ORDER BY year_month
    )::INTEGER AS relative_month_index,
    'Month ' ||
    LPAD(
        DENSE_RANK() OVER (
            ORDER BY year_month
        )::TEXT,
        2,
        '0'
    ) AS relative_month_label
FROM analytics.monthly_customer_activity
ORDER BY year_month;
```

Expected months:

> 24

In Power BI:

- sort `relative_month_label` by `relative_month_index`;
- show `relative_month_label` to users;
- do not present the synthetic dates as real historical dates.

---

## 1.4 FactCustomerCategory

Use:

```
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
FROM analytics.customer_category_metrics
ORDER BY customer_id, category_rank, category;
```

Expected grain:

> one row per customer × category

Expected rows:

> 286,548

---

## 1.5 DimCategory

Use:

```
SELECT DISTINCT
    category
FROM analytics.customer_category_metrics
WHERE category IS NOT NULL
ORDER BY category;
```

Expected categories:

> 307

`COUPON/MISC ITEMS` must remain available for reconciliation but should not be presented as a strategic merchandise category without qualification.

---

# 2. Relationships

Create exactly these active relationships:

```
DimCustomer[customer_id]
    1 ───── * FactMonthlyActivity[customer_id]

DimCustomer[customer_id]
    1 ───── * FactCustomerCategory[customer_id]

DimMonth[year_month]
    1 ───── * FactMonthlyActivity[year_month]

DimCategory[category]
    1 ───── * FactCustomerCategory[category]
```

Cross-filter direction:

> Single

Do not create:

- fact-to-fact relationships;
- many-to-many relationships;
- bidirectional filtering unless a genuine unresolved requirement appears.

---

# 3. Mandatory DAX Measures

Create a dedicated measure table named:

`_Measures`

## Core measures

```
Total Sales =
SUM (
    FactMonthlyActivity[monthly_sales]
)
```

```
Total Customers =
DISTINCTCOUNT (
    DimCustomer[customer_id]
)
```

```
Active Customers =
DISTINCTCOUNT (
    FactMonthlyActivity[customer_id]
)
```

```
Total Transactions =
SUM (
    FactMonthlyActivity[monthly_transactions]
)
```

```
Average Basket Value =
DIVIDE (
    [Total Sales],
    [Total Transactions]
)
```

```
Revenue per Customer =
DIVIDE (
    [Total Sales],
    [Active Customers]
)
```

```
Promotion Sales =
SUM (
    FactMonthlyActivity[monthly_promo_sales]
)
```

```
Promotion Sales % =
DIVIDE (
    [Promotion Sales],
    [Total Sales]
)
```

```
Segment Revenue % =
DIVIDE (
    [Total Sales],
    CALCULATE (
        [Total Sales],
        REMOVEFILTERS (
            DimCustomer[segment_id],
            DimCustomer[segment_name]
        )
    )
)
```

## Segment profile measures

```
Customer Base % =
DIVIDE (
    [Total Customers],
    CALCULATE (
        [Total Customers],
        REMOVEFILTERS (
            DimCustomer[segment_id],
            DimCustomer[segment_name]
        )
    )
)
```

```
Average Customer Spend =
AVERAGE (
    DimCustomer[total_spend]
)
```

```
Average Purchase Frequency =
AVERAGE (
    DimCustomer[purchase_frequency]
)
```

```
Average Recency Days =
AVERAGE (
    DimCustomer[recency_days]
)
```

```
Average Promotion Purchase Share =
AVERAGE (
    DimCustomer[promotion_purchase_share]
)
```

```
Average Promotion Spend Share =
AVERAGE (
    DimCustomer[promotion_spend_share]
)
```

## Basket-promotion measures

`promo_sales` and `nonpromo_sales` classify entire baskets.

```
Promotional Basket Sales =
SUM (
    DimCustomer[promo_sales]
)
```

```
Non-Promotional Basket Sales =
SUM (
    DimCustomer[nonpromo_sales]
)
```

```
Promotional Basket Value =
DIVIDE (
    SUM ( DimCustomer[promo_sales] ),
    SUM ( DimCustomer[promo_baskets] )
)
```

```
Non-Promotional Basket Value =
DIVIDE (
    SUM ( DimCustomer[nonpromo_sales] ),
    SUM ( DimCustomer[nonpromo_baskets] )
)
```

## Category measures

```
Category Sales =
SUM (
    FactCustomerCategory[category_spend]
)
```

```
Category Promotion Sales =
SUM (
    FactCustomerCategory[category_promo_spend]
)
```

```
Category Promotion Sales % =
DIVIDE (
    [Category Promotion Sales],
    [Category Sales]
)
```

---

# 4. Formatting

Currency:

- Total Sales
- Average Basket Value
- Revenue per Customer
- Average Customer Spend
- Promotional Basket Sales
- Non-Promotional Basket Sales
- Promotional Basket Value
- Non-Promotional Basket Value
- Category Sales
- Category Promotion Sales

Format:

`$#,##0.00`

Percentage:

- Promotion Sales %
- Segment Revenue %
- Customer Base %
- Average Promotion Purchase Share
- Average Promotion Spend Share
- Category Promotion Sales %

Format:

`0.00%`

Counts:

`#,##0`

---

# 5. Page 1 — Business Overview

Question:

> What is happening at an overall consumer/business level?

## KPI cards

1. Total Sales
2. Active Customers
3. Total Transactions
4. Average Basket Value
5. Promotion Sales %

## Visuals

### Monthly revenue trend

Line chart:

- X-axis: `DimMonth[relative_month_label]`
- Y-axis: `[Total Sales]`

Sort by relative month index.

### Category revenue contribution

Horizontal bar chart:

- Category: `DimCategory[category]`
- Value: `[Category Sales]`

Use Top N by Category Sales for readability.

### Segment revenue contribution

Bar or donut chart:

- Legend/Axis: `DimCustomer[segment_name]`
- Value: `[Total Sales]`
- Tooltip: `[Segment Revenue %]`

## Slicers

- Relative Month
- Segment

---

# 6. Page 2 — Consumer Segments

Question:

> Who are the main consumer groups and how do they behave differently?

## Mandatory segment profile

Use a matrix with segment rows and:

- Total Customers
- Customer Base %
- Segment Revenue %
- Average Customer Spend
- Average Purchase Frequency
- Average Recency Days
- Average Basket Value
- Average Promotion Purchase Share
- Average Promotion Spend Share

## Behavioral comparison visual

Use a clustered bar/column chart comparing selected decision-relevant segment measures.

Do not mix currency, percentages and days on one uninterpretable axis.

## Category preference visual

Bar chart:

- Axis: category
- Value: Category Sales
- Legend or slicer: segment

Exclude or clearly qualify `COUPON/MISC ITEMS` in business-facing category interpretation.

## Slicers

- Segment
- Category

Relative Month may be shown only for date-aware transaction visuals.

Do not imply that static all-history segment characteristics change with a month slicer.

---

# 7. Page 3 — Promotion & Growth Opportunities

Question:

> Which consumer behaviors create the clearest opportunities for business action?

## Promotion exposure visual

Clustered column:

- Axis: segment
- Average Promotion Purchase Share
- Average Promotion Spend Share

The two measures must remain visually distinct.

## Promotional vs non-promotional sales

Clustered or stacked bar:

- Axis: segment
- Promotional Basket Sales
- Non-Promotional Basket Sales

Label clearly that these are entire-basket classifications.

## Basket-value comparison

Clustered columns:

- Promotional Basket Value
- Non-Promotional Basket Value
- Axis: segment

Do not describe the difference as causal promotion lift.

## Category promotion pattern

Matrix or heatmap-style table:

- Rows: category
- Columns: segment
- Value: Category Promotion Sales %

Use conditional formatting if helpful.

## Exactly three executive insight cards

Each card must contain:

```
INSIGHT
SO WHAT?
ACTION
```

### Card 1 — Retention priority

INSIGHT
High-Value Frequent Shoppers are 40.28% of customers but generate 73.52% of total sales.

SO WHAT?
A decline in their engagement would expose a disproportionate share of the current revenue base.

ACTION
Monitor recency and purchase-frequency deterioration and use category-relevant re-engagement rather than automatic broad discounting.

### Card 2 — Frequency growth

INSIGHT
Large-Basket Occasional Shoppers have the highest average basket value but purchase only 2.94 times per active month.

SO WHAT?
Their behavioral growth gap is visit frequency rather than basket expansion.

ACTION
Use replenishment, next-visit and category-relevant engagement to encourage additional shopping occasions.

### Card 3 — Promotion measurement

INSIGHT
Large-Basket Occasional Shoppers have 89.94% promotion purchase share, but only 51.36% promotion spend share; High-Value Frequent Shoppers are 85.37% and 51.21%.

SO WHAT?
A promotional item appearing in a basket is not the same as customer sales being promotion-dependent.

ACTION
Use promotional-line dependence and category context for targeting instead of basket exposure alone.

---

# 8. Dashboard Design Rules

- Exactly three primary analytical pages.
- Use a consistent visual hierarchy.
- Keep titles business-readable.
- Avoid decorative custom visuals.
- Avoid duplicate visuals showing the same conclusion.
- Use concise tooltips and labels.
- Preserve original segment names.
- Never present synthetic dates as actual historical dates.
- Do not describe observational promotion patterns as causal lift.
- Do not claim profitability because margin data is unavailable.

---

# 9. Reconciliation Targets

The final PBIX must reconcile to PostgreSQL/Python values generated in:

- `powerbi/powerbi_validation_targets.csv`
- `powerbi/powerbi_segment_validation.csv`

Do not proceed to Phase 11 while material discrepancies remain.
