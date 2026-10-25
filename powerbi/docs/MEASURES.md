# DAX Measure Dictionary

[Power BI project guide](../README.md) · [Model and filters](MODEL_AND_FILTERS.md)

This dictionary documents all 46 explicit measures in the supplied semantic model. Amounts represent retailer sales value in USD. The formulas are preserved from the project definition.

Customer-profile measures average full-period customer metrics; monthly activity measures respond to the relative-month selection. Promotional-line sales and entire promotional-basket sales are distinct measures. See [filter behavior](MODEL_AND_FILTERS.md#expected-filter-behavior) for the scope of each measure family.

The `QA` measures are reconciliation checks. Their stated row counts and zero differences refer to the supplied baseline with report, page and visual filters cleared. Category and merchandise filters must be cleared when comparing category totals with overall sales. A changed source population requires an updated validation baseline.

Source: [`_Measures.tmdl`](../ConsumerGrowth/ConsumerGrowth.SemanticModel/definition/tables/_Measures.tmdl).

## Total Sales

Retailer sales value on valid lines; responds to relative month and segment, not category.

```dax
Total Sales = SUM ( FactMonthlyActivity[monthly_sales] )
```

## Total Customers

Full observation-period customer population in the selected segment; month and category do not filter this dimension.

```dax
Total Customers = DISTINCTCOUNT ( DimCustomer[customer_id] )
```

## Active Customers

Customers with activity in the selected relative months and segment.

```dax
Active Customers = DISTINCTCOUNT ( FactMonthlyActivity[customer_id] )
```

## Total Transactions

Distinct baskets aggregated from mutually exclusive customer-month groups.

```dax
Total Transactions = SUM ( FactMonthlyActivity[monthly_transactions] )
```

## Average Basket Value

Basket-weighted value: total sales divided by total baskets; not the mean of customer basket averages.

```dax
Average Basket Value = DIVIDE ( [Total Sales], [Total Transactions] )
```

## Revenue per Customer

Selected-period sales per active customer.

```dax
Revenue per Customer = DIVIDE ( [Total Sales], [Active Customers] )
```

## Promotion Sales

Sales of promotional transaction lines only; not entire promotional baskets.

```dax
Promotion Sales = SUM ( FactMonthlyActivity[monthly_promo_sales] )
```

## Non-Promotion Sales

Sales of non-promotional lines in the selected period.

```dax
Non-Promotion Sales = [Total Sales] - [Promotion Sales]
```

## Promotion Sales %

Weighted promotional-line sales share.

```dax
Promotion Sales % = DIVIDE ( [Promotion Sales], [Total Sales] )
```

## Promotion Basket Exposure %

Weighted proportion of baskets containing any promotional line.

```dax
Promotion Basket Exposure % = DIVIDE ( SUM ( FactMonthlyActivity[monthly_promo_transactions] ), [Total Transactions] )
```

## Segment Revenue %

Share of sales across all segments, retaining the relative-month filter. Segment selections do not rebase the denominator.

```dax
Segment Revenue % = DIVIDE ( [Total Sales], CALCULATE ( [Total Sales], REMOVEFILTERS ( DimCustomer[segment_id], DimCustomer[segment_name] ) ) )
```

## Customer Base %

Customer population share across all segments; full observation period.

```dax
Customer Base % = DIVIDE ( [Total Customers], CALCULATE ( [Total Customers], REMOVEFILTERS ( DimCustomer[segment_id], DimCustomer[segment_name] ) ) )
```

## Segment Customer %

Alias for `Customer Base %`; both measures return the same value.

```dax
Segment Customer % = [Customer Base %]
```

## Average Customer Spend

Mean full-period retailer sales attributed to each customer. Full observation period; not affected by relative-month or category selection.

```dax
Average Customer Spend = AVERAGE ( DimCustomer[total_spend] )
```

## Average Purchase Frequency

Customer mean of baskets / active months; not baskets divided by all 24 months. Full observation period; not affected by relative-month or category selection.

```dax
Average Purchase Frequency = AVERAGE ( DimCustomer[purchase_frequency] )
```

## Average Recency Days

Mean days since last valid purchase at the dataset end; never relative to today. Full observation period; not affected by relative-month or category selection.

```dax
Average Recency Days = AVERAGE ( DimCustomer[recency_days] )
```

## Mean Customer Basket Value

Unweighted mean of each customer average basket value. Reconciles to the analytical segment profile (40.07 for Large-Basket Occasional Shoppers). Full observation period; not affected by relative-month or category selection.

```dax
Mean Customer Basket Value = AVERAGE ( DimCustomer[average_basket_value] )
```

## Average Category Diversity

Mean distinct purchased categories per customer; unmodified analytical definition. Full observation period; not affected by relative-month or category selection.

```dax
Average Category Diversity = AVERAGE ( DimCustomer[category_diversity] )
```

## Average Items per Basket

Mean customer items per basket; gasoline quantity excluded upstream. Full observation period; not affected by relative-month or category selection.

```dax
Average Items per Basket = AVERAGE ( DimCustomer[average_items_per_basket] )
```

## Average Promotion Purchase Share

Unweighted customer mean: promotional baskets / baskets. Full observation period; not affected by relative-month or category selection.

```dax
Average Promotion Purchase Share = AVERAGE ( DimCustomer[promotion_purchase_share] )
```

## Average Promotion Spend Share

Unweighted customer mean: promotional-line sales / sales. Full observation period; not affected by relative-month or category selection.

```dax
Average Promotion Spend Share = AVERAGE ( DimCustomer[promotion_spend_share] )
```

## All Period Sales

Sales across all 24 relative months in the selected segment.

```dax
All Period Sales = CALCULATE ( [Total Sales], REMOVEFILTERS ( DimMonth ) )
```

## All Period Segment Revenue %

Full-period segment sales contribution; denominator retains the full segment population.

```dax
All Period Segment Revenue % = DIVIDE ( [All Period Sales], CALCULATE ( [All Period Sales], REMOVEFILTERS ( DimCustomer[segment_id], DimCustomer[segment_name] ) ) )
```

## Promotional Basket Count

Baskets containing at least one promotional line. Full observation period.

```dax
Promotional Basket Count = SUM ( DimCustomer[promo_baskets] )
```

## Non-Promotional Basket Count

Baskets with no promotional line. Full observation period.

```dax
Non-Promotional Basket Count = SUM ( DimCustomer[nonpromo_baskets] )
```

## Promotional Basket Sales

Entire sales of baskets containing at least one promotional line. Full observation period.

```dax
Promotional Basket Sales = SUM ( DimCustomer[promo_sales] )
```

## Non-Promotional Basket Sales

Entire sales of baskets containing no promotional line. Full observation period.

```dax
Non-Promotional Basket Sales = SUM ( DimCustomer[nonpromo_sales] )
```

## Promotional Basket Value

Weighted mean entire-basket sales for promotional baskets; descriptive, not causal lift. Full observation period.

```dax
Promotional Basket Value = DIVIDE ( [Promotional Basket Sales], [Promotional Basket Count] )
```

## Non-Promotional Basket Value

Weighted mean entire-basket sales for non-promotional baskets; blank when denominator is zero. Full observation period.

```dax
Non-Promotional Basket Value = DIVIDE ( [Non-Promotional Basket Sales], [Non-Promotional Basket Count] )
```

## Category Sales

Full-period sales in the selected category and segment. No month grain exists in this fact.

```dax
Category Sales = SUM ( FactCustomerCategory[category_spend] )
```

## Category Promotion Sales

Full-period promotional-line sales in the selected category and segment.

```dax
Category Promotion Sales = SUM ( FactCustomerCategory[category_promo_spend] )
```

## Category Promotion Sales %

Weighted full-period promotional-line sales share by category and segment.

```dax
Category Promotion Sales % = DIVIDE ( [Category Promotion Sales], [Category Sales] )
```

## Category Customers

Customers who purchased the selected category; full observation period.

```dax
Category Customers = DISTINCTCOUNT ( FactCustomerCategory[customer_id] )
```

## Merchandise Sales

Category sales excluding COUPON/MISC ITEMS and (CORP USE ONLY); exclusion applies only where this measure or equivalent visual filter is used.

```dax
Merchandise Sales = CALCULATE ( [Category Sales], KEEPFILTERS ( DimCategory[is_business_merchandise] = TRUE () ) )
```

## Category Sales Share %

Category contribution retaining merchandise and segment scope. Not a distinct basket share.

```dax
Category Sales Share % = DIVIDE ( [Category Sales], CALCULATE ( [Category Sales], REMOVEFILTERS ( DimCategory[category] ) ) )
```

## Segment Color

Stable segment palette shared by all pages.

```dax
Segment Color = SWITCH ( SELECTEDVALUE ( DimCustomer[segment_id] ), 1, "#2563EB", 2, "#7C3AED", 3, "#0F9488", "#2563EB" )
```

## Selected Period Label

Relative-time filter summary; no calendar-year claim.

```dax
Selected Period Label = IF ( COUNTROWS ( VALUES ( DimMonth[relative_month_index] ) ) = 24, "All 24 relative months", FORMAT ( COUNTROWS ( VALUES ( DimMonth[relative_month_index] ) ), "0" ) & " relative months selected" )
```

## QA Customer Rows

Expected unfiltered: 2500.

```dax
QA Customer Rows = COUNTROWS ( DimCustomer )
```

## QA Monthly Rows

Expected unfiltered: 45298.

```dax
QA Monthly Rows = COUNTROWS ( FactMonthlyActivity )
```

## QA Customer Category Rows

Expected unfiltered: 286548.

```dax
QA Customer Category Rows = COUNTROWS ( FactCustomerCategory )
```

## QA Customer Sales Difference

Expected 0 without category filters.

```dax
QA Customer Sales Difference = [All Period Sales] - SUM ( DimCustomer[total_spend] )
```

## QA Category Sales Difference

Expected 0 without category/merchandise filters.

```dax
QA Category Sales Difference = [Category Sales] - [All Period Sales]
```

## QA Basket Sales Difference

Expected 0.

```dax
QA Basket Sales Difference = [Promotional Basket Sales] + [Non-Promotional Basket Sales] - [All Period Sales]
```

## QA Promotion Sales Difference

Expected 0 without category/merchandise filters.

```dax
QA Promotion Sales Difference = [Category Promotion Sales] - CALCULATE ( [Promotion Sales], REMOVEFILTERS ( DimMonth ) )
```

## QA Orphan Monthly Customers

Expected 0 unfiltered.

```dax
QA Orphan Monthly Customers = COUNTROWS ( EXCEPT ( VALUES ( FactMonthlyActivity[customer_id] ), VALUES ( DimCustomer[customer_id] ) ) )
```

## QA Orphan Category Customers

Expected 0 unfiltered.

```dax
QA Orphan Category Customers = COUNTROWS ( EXCEPT ( VALUES ( FactCustomerCategory[customer_id] ), VALUES ( DimCustomer[customer_id] ) ) )
```