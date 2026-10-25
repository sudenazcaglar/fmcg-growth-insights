# Business Validation Workbook

**FMCG Consumer Growth & Promotion Insights**

Seven worksheets combine customer and promotion analysis across 2,500 households with formula-based checks against the project's SQL and Python reference totals. Three analytical views present the findings, while four validation sheets make the supporting calculations available for review.

**[Download Excel](https://raw.githubusercontent.com/sudenazcaglar/fmcg-growth-insights/main/excel/business_validation.xlsx)** · [View the live dashboard][dashboard] · [Executive presentation](../presentation/README.md) · [Project overview](../README.md)

## Explore the workbook

### 01 · Overview

Retailer sales, customers, purchase occasions and monthly activity in one view.

[![Overview worksheet: headline sales, customer and basket metrics with a monthly sales chart.](images/01-overview.png)](images/01-overview.png)

### 02 · Consumer profiles

Compare three shopper groups by sales contribution, spending, visit frequency and recency.

[![Consumer profiles worksheet: segment metrics and a chart comparing customer share with sales share.](images/02-consumer-profiles.png)](images/02-consumer-profiles.png)

### 03 · Promotion patterns

Customer averages distinguish the share of baskets containing a promoted item from the share of spending on promoted items.

[![Promotion patterns worksheet: customer-level averages of promotion exposure and promoted-item spending by segment.](images/03-promotion-patterns.png)](images/03-promotion-patterns.png)

### 04 · Basket-value comparisons

The second view of **Promotion patterns** compares weighted basket values by promotion status within each segment. These differences describe associations; they do not measure campaign lift.

[![Promotion patterns worksheet, second view: weighted basket values for baskets with and without promoted items.](images/04-basket-value-comparisons.png)](images/04-basket-value-comparisons.png)

## Validation worksheets

These four sheets compare recalculated results with the supplied reference totals. Each preview shows the sheet's summary area; supporting records are available in the workbook.

<details>
<summary><strong>05 · KPI checks</strong></summary>

`01_KPI_Check` reconciles sales, customer and basket counts, weighted basket value and promotion metrics, with explicit differences and tolerances.

[![KPI validation worksheet: Excel results, reference totals, differences, tolerances and check statuses.](images/05-kpi-check.png)](images/05-kpi-check.png)

</details>

<details>
<summary><strong>06 · Segment reconciliation</strong></summary>

`02_Segment_Summary` calculates segment profiles from the included customer records and checks customer counts, sales, mean basket values and sales shares.

[![Segment summary worksheet: shopper profiles and comparisons with SQL reference values.](images/06-segment-summary.png)](images/06-segment-summary.png)

</details>

<details>
<summary><strong>07 · Category reconciliation</strong></summary>

`03_Category_Check` reconciles total sales across 307 categories and checks leading-category totals against the reference values.

[![Category validation worksheet: all-category and leading-category sales compared with reference totals.](images/07-category-check.png)](images/07-category-check.png)

</details>

<details>
<summary><strong>08 · Promotion reconciliation</strong></summary>

`04_Promotion_Check` checks promotion exposure, promoted-item spending shares and the sales and basket totals split by promotion status.

[![Promotion validation worksheet: exposure and spending-share checks, with sales and basket-count reconciliations.](images/08-promotion-check.png)](images/08-promotion-check.png)

</details>

## Using the workbook

Download the file and open it in Excel to inspect the formulas, charts and supporting data. It contains a saved data snapshot; changes to the database or dashboard do not automatically refresh the workbook.

[dashboard]: https://app.powerbi.com/view?r=eyJrIjoiMGFiNjk2MzYtOTg2Ny00MWJlLWIyZmYtODY1YTZmMGQwZjc2IiwidCI6IjdjMDY0MDFiLTYwMDMtNDAxYy1hZWJiLWQzZmI3NDEzZDYxMSJ9
