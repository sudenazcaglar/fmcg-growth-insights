# Data

## Source

This project uses the **dunnhumby — The Complete Journey** retail dataset.

The raw dataset is stored locally under `data/raw/` and is intentionally excluded from Git version control.

## Raw Source Files

| File | Rows | Purpose |
|---|---:|---|
| `campaign_desc.csv` | 30 | Campaign metadata and campaign day ranges |
| `campaign_table.csv` | 7,208 | Household-to-campaign assignments |
| `causal_data.csv` | 36,786,524 | Product/store/week display and mailer information |
| `coupon.csv` | 124,548 | Coupon-to-product and campaign relationships |
| `coupon_redempt.csv` | 2,318 | Household coupon redemption activity |
| `hh_demographic.csv` | 801 | Available household demographic attributes |
| `product.csv` | 92,353 | Product master and category hierarchy |
| `transaction_data.csv` | 2,595,732 | Transaction-line purchasing and discount data |

The source package also includes:

`dunnhumby - The Complete Journey User Guide.pdf`

## Data Handling

Raw source values are loaded into the PostgreSQL `raw` schema with minimal transformation.

Canonical column naming, data-type conversion, date normalization, null handling, promotion derivation and analytical business rules are applied later in the `staging` layer.

The raw licensed/source files are not committed to this repository.


## Data Quality and Analytical Rules

### Transaction validity

Behavioral analytics use transaction lines satisfying:

```text
quantity > 0 AND sales_amount >= 0
```

The source contains 14,466 rows with `quantity = 0` and no rows with negative quantity. The zero-quantity rows are retained in the raw and staging layers for traceability but excluded from downstream behavioral metrics.

This exclusion removes 595 baskets but does not remove any of the 2,500 customers from the valid behavioral population.

### Sales value interpretation

`SALES_VALUE` represents the amount received by the retailer for the product sale. It must not be described as the customer's out-of-pocket spend.

The project retains the specification's `total_spend` metric name, but business documentation interprets it as customer-attributed retailer sales value.

### Zero-sales transactions

Transaction lines with `quantity > 0` and `sales_amount = 0` are retained. Zero sales alone is not treated as evidence of an invalid purchase line.

### Gasoline quantity

Gasoline transactions contain a quantity scale that is not comparable with normal countable retail units. The source documentation does not define a gasoline-specific physical unit.

Gasoline transactions remain valid for:

- sales;
- customer value;
- basket activity;
- purchase frequency;
- category analysis;
- promotion analysis.

However, `GASOLINE-REG UNLEADED` quantity is excluded from item-count quantity metrics such as `average_items_per_basket`.

No gallon, litre or other physical-unit conversion is inferred.

### Missing category

Rows with missing category are retained for overall value where otherwise valid, but excluded from category-specific metrics.

In this dataset, all 7,839 missing-category transaction rows also have `quantity = 0`, so none remain after applying the behavioral-validity rule.

### Floating-point artifacts

Very small scientific-notation sales and discount values are preserved rather than silently rounded.

Promotion classification continues to follow the project rule that any non-zero source discount produces a promotional transaction line.

### Time representation

The source uses sequential day indices rather than documented absolute calendar dates.

For deterministic date operations, staging uses a synthetic anchor:

```text
DAY 1 = 2000-01-01
```

These generated dates are analytical dates only and must not be interpreted as historical calendar dates.
