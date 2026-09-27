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
