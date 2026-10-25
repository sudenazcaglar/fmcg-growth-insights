# Semantic Model and Filter Behavior

[Power BI project guide](../README.md) · [Measure dictionary](MEASURES.md)

The project uses an Import semantic model with three dimensions, two fact tables and a measure table. It contains 46 explicit DAX measures and four active relationships. Filters flow from dimensions to facts in one direction. Automatic date/time tables are disabled; identifiers and numerical source columns are hidden where appropriate so report visuals use explicit measures.

## Tables and analytical grain

| Table | Grain and purpose |
|---|---|
| `DimCustomer` | One row per customer; full-period behavior, segment assignment and promotion metrics |
| `DimMonth` | One row per synthetic relative month; filters monthly activity |
| `DimCategory` | One row per category; includes the merchandise classification |
| `FactMonthlyActivity` | One row per customer and relative month |
| `FactCustomerCategory` | One row per customer and category across the observation period |
| `_Measures` | Explicit DAX measures and a hidden holder column |

## Relationships

Each relationship is many-to-one from the fact to its dimension; filtering flows from the dimension to the fact.

| Dimension | Fact | Join |
|---|---|---|
| DimCustomer | FactMonthlyActivity | customer_id |
| DimCustomer | FactCustomerCategory | customer_id |
| DimMonth | FactMonthlyActivity | year_month |
| DimCategory | FactCustomerCategory | category |

The facts have no direct relationship. `DimMonth` does not filter the category fact, and `DimCategory` does not filter monthly activity or the customer dimension. The category fact has no time key; category-by-month analysis would require an additional source grain and reconciliation of basket counts.

## Expected filter behavior

The table describes dimension slicers where report interactions are enabled. Visual filters and page interactions can further restrict the scope.

| Measure family | Segment | Relative month | Category |
|---|---|---|---|
| Total Sales, Transactions, Active Customers, Promotion Sales, weighted basket | Yes | Yes | No |
| Total Customers, customer means, basket classification | Yes | No | No |
| Category Sales, Category Promotion %, Category Customers | Yes | No | Yes |
| Segment Revenue % | Numerator only; denominator keeps all segments | Yes | No |
| Customer Base % | Numerator only; denominator keeps all segments | No | No |
| Static insight/action text | Baseline only | Baseline only | Baseline only |

The segment share measures remove filters on segment ID and segment name from their denominators. Other explicitly applied customer filters can still affect the result.

Page interactions prevent category and month selections from implying unsupported comparisons across the two facts. Merchandise and Top N filters apply only to their configured category visuals. Category basket counts are non-additive across categories and are not used as the overall transaction KPI.

## Calculations that must remain distinct

- **Weighted basket value:** total retailer sales divided by total baskets. Unfiltered baseline: $29.20538260.
- **Mean customer basket value:** average of each customer's basket average. For Large-Basket Occasional Shoppers, this is $40.0703623; the weighted basket value is $36.7683252.
- **Promoted-line sales:** sales only on transaction lines with a non-zero discount. The baseline total is $4,108,958.96.
- **Promotional basket sales:** all sales in baskets containing at least one promoted line, including non-promoted lines in those baskets.
- **Promotion exposure:** customer profiles use the unweighted mean of each customer's promotional-basket share. `Promotion Basket Exposure %` separately calculates exposure from summed basket counts.
- **Promotion spend share:** customer profiles average each customer's promoted-line sales share. `Promotion Sales %` divides total promoted-line sales by total sales.
- **Recency:** days since the last valid purchase at the dataset endpoint; it does not move with today's date.
- **Frequency:** baskets divided by active months for each customer, then averaged for the profile; it does not divide by all 24 months.

Promotional and non-promotional basket comparisons are descriptive associations. They do not estimate causal promotion lift or profit.

## Connection parameters

| Parameter | Purpose |
|---|---|
| `pSourceMode` | Selects `PostgreSQL` or `Snapshot` |
| `pServer` | PostgreSQL server and port for the user's environment |
| `pDatabase` | Database containing the `analytics` schema |
| `pSnapshotFolder` | Local folder containing the five corresponding CSV tables; used only in Snapshot mode |

`fnAnalyticsTable` selects the source and applies explicit column types. The CSV branch uses UTF-8 parsing and handles null values. Database credentials are supplied through Desktop or Service, not through repository files.

Snapshot CSVs, database backups and the local data cache are excluded from the public project. Snapshot mode requires separately available files. The [project guide](../README.md#required-data) lists the required PostgreSQL tables and source rebuild links.

## Report page interactions

| Page | Segment slicer | Second slicer / scope |
|---|---|---|
| Business overview | All metrics and trend | Relative month: all metrics and trend |
| Consumer value | Profile and sales chart | Relative month: sales chart only |
| Shopping behavior | Profile and both charts | None; all-period metrics |
| Category preferences | Both rankings | Category: lower Top 6 only |
| Promotion exposure | Both charts | None; all-period metrics |
| Basket comparisons | Both views | Category: promotion matrix only |
| Growth priorities | No slicer | Full-baseline proposals |

Chart selection filters related views on Business overview, Shopping behavior and Promotion exposure. Cross-view filtering is disabled where it would mix different grains or imply an unsupported scope. Slicers do not cross-filter one another. Clear selections resets the current analytical page's slicers. Header navigation provides seven destinations on every page.

## Validation scope

The supplied baseline has 2,500 customers, 45,298 customer-month rows and 286,548 customer-category rows. Overall retailer sales are $8,057,443.80 across 275,889 baskets.

Run row-count and reconciliation measures without report, page or visual filters when comparing with the fixed baseline. Category and merchandise filters must be cleared for cross-fact sales comparisons. Recalculate the control totals after changing the source population; these fixed values describe the supplied analytical dataset.

Definitions: [semantic model source](../ConsumerGrowth/ConsumerGrowth.SemanticModel/definition/) · [DAX measure dictionary](MEASURES.md).
