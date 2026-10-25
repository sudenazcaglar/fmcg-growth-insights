# Power BI Project — Consumer Growth

Editable source for the seven-page **FMCG Consumer Growth & Promotion Insights** report, including its report layout, semantic model, Power Query definitions and 46 explicit DAX measures.

**[View the live dashboard][dashboard]** · [Project overview](../README.md) · [Model and filters](docs/MODEL_AND_FILTERS.md) · [Measure dictionary](docs/MEASURES.md)

## Project files

| Path | Contents |
|---|---|
| [ConsumerGrowth/ConsumerGrowth.pbip](ConsumerGrowth/ConsumerGrowth.pbip) | Power BI Desktop project entry point |
| [ConsumerGrowth/ConsumerGrowth.Report/](ConsumerGrowth/ConsumerGrowth.Report/) | Report pages, visuals, theme and registered image resources |
| [ConsumerGrowth/ConsumerGrowth.SemanticModel/](ConsumerGrowth/ConsumerGrowth.SemanticModel/) | Tables, relationships, DAX measures and source parameters |
| [docs/MODEL_AND_FILTERS.md](docs/MODEL_AND_FILTERS.md) | Table grains, relationships and filter behavior |
| [docs/MEASURES.md](docs/MEASURES.md) | Definitions and formulas for all 46 measures |
| [powerbi_validation_targets.csv](powerbi_validation_targets.csv) | Overall analytical control totals |
| [powerbi_segment_validation.csv](powerbi_segment_validation.csv) | Segment-level validation targets |

Keep the `.pbip` file and the `.Report` and `.SemanticModel` folders together inside `ConsumerGrowth/`. Their relative references connect the report to its model. Preserve all report resources and model definition files, including the model diagram when present.

## Open and refresh

1. Clone the repository or select **Code → Download ZIP** on GitHub and extract the archive. Download the complete project structure.
2. On Windows, open `powerbi/ConsumerGrowth/ConsumerGrowth.pbip` in a current Power BI Desktop version that supports PBIP and the report definition format.
3. In Power Query, set `pSourceMode` to `PostgreSQL`, `pServer` to your PostgreSQL server and port, and `pDatabase` to the database containing the project's `analytics` schema.
4. Enter database credentials through Power BI Desktop, apply the parameters and refresh. The account needs read access to the five analytical tables listed below.

The public source project excludes the local data cache, raw data and database backups. It can open with its model definitions but requires an accessible data source to populate the visuals. The live dashboard is available for viewing the published results without configuring a database.

## Required data

The model imports the following PostgreSQL tables:

| Table | Purpose |
|---|---|
| `analytics.customer_metrics` | Customer value and shopping behavior |
| `analytics.customer_segments` | Behavioral segment assignments |
| `analytics.promotion_metrics` | Customer-level promotional and non-promotional basket metrics |
| `analytics.monthly_customer_activity` | Customer activity by relative month |
| `analytics.customer_category_metrics` | Customer-category purchasing across the observation period |

For source acquisition and rebuilding these tables, follow the [data documentation](../data/README.md), [SQL workflow](../sql/), [Python notebooks](../notebooks/) and [reproduction instructions](../README.md#reproducing-the-analysis).

The model also supports `Snapshot` mode for a separately held set of five corresponding CSV files. Those files are not included in this public repository. Use that mode only when all five files are available locally, and set `pSnapshotFolder` to their folder. Credentials are configured in Desktop or Service and are not stored in these documents.

## Report pages

| Page | Focus |
|---|---|
| Business overview | Sales, customers, baskets and relative-month trends |
| Consumer value | Segment size and sales contribution |
| Shopping behavior | Purchase frequency, recency and basket value |
| Category preferences | Merchandise priorities across segments |
| Promotion exposure | Promotional basket exposure and promoted-line sales dependence |
| Basket comparisons | Promotional basket values and category patterns |
| Growth priorities | Three proposed retention and growth actions |

Customer profiles and category metrics cover the observation period. Month filters apply to monthly activity measures. The [model documentation](docs/MODEL_AND_FILTERS.md) explains the page-level differences and the distinction between weighted totals and customer averages.

## Supporting deliverables

- [Excel validation workbook](../excel/business_validation.xlsx)
- [Executive presentation](../presentation/consumer_growth_executive.pptx)
- [Dashboard screenshots](../docs/images/)

Format reference: [Microsoft Power BI Desktop projects](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview).

[dashboard]: https://app.powerbi.com/view?r=eyJrIjoiMGFiNjk2MzYtOTg2Ny00MWJlLWIyZmYtODY1YTZmMGQwZjc2IiwidCI6IjdjMDY0MDFiLTYwMDMtNDAxYy1hZWJiLWQzZmI3NDEzZDYxMSJ9
