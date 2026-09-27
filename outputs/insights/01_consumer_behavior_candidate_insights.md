## 6. Candidate Insights

The following findings are **provisional pre-segmentation insights**. They describe observed customer behavior and are not yet final business recommendations.

### Candidate Insight 1 — Customer value is concentrated

**Finding**  
A relatively small part of the customer base accounts for a disproportionate share of retailer sales value.

**Evidence**  
The top 20% of customers generate 53.05% of total sales, while the top 10% generate 34.29%. Mean customer sales are 3,222.98 versus a median of 2,157.75, and the customer-sales Gini coefficient is 0.5028.

**Business relevance**  
Customer value is not evenly distributed, so treating the full customer base as behaviorally homogeneous could obscure commercially important differences.

**Next analysis**  
Segmentation will test whether the higher-value population forms one or more distinct behavioral groups when spend is considered jointly with frequency, recency, basket value, category diversity and promotion behavior.

---

### Candidate Insight 2 — Purchase frequency strongly differentiates customer value

**Finding**  
Customers who purchase more frequently tend to have materially higher total retailer sales value.

**Evidence**  
Purchase frequency and total sales have a Spearman correlation of 0.7956. The highest-frequency group has median customer sales of 6,016.41 versus 500.15 in the lowest-frequency group, a 12.03x difference.

**Business relevance**  
Purchase frequency appears to be an important dimension of customer engagement and value, although the relationship is descriptive rather than causal.

**Next analysis**  
Segmentation will determine whether high-frequency customers remain behaviorally distinct after accounting for basket value, category breadth, recency and promotion dependence.

---

### Candidate Insight 3 — Broad category engagement is strongly associated with customer value

**Finding**  
Customers purchasing across a broader range of categories also tend to have much higher historical sales value.

**Evidence**  
Category diversity and total customer sales have a Spearman correlation of 0.9217. Median sales are 7,054.70 in the highest-diversity group versus 394.49 in the lowest-diversity group, a 17.88x difference.

**Business relevance**  
Category breadth is a strong marker of observed customer engagement, but both category diversity and total sales accumulate with purchasing activity and observed history.

**Next analysis**  
Segmentation will assess whether category diversity adds an interpretable engagement dimension after it is considered jointly with frequency and total spend rather than treating this association as causal.

---

### Candidate Insight 4 — Promotion exposure and promotion sales dependence are distinct behaviors

**Finding**  
Promotional baskets are widespread across the customer base, but customers differ substantially in how much of their sales value comes from promotional lines.

**Evidence**  
Mean promotion purchase share is 84.50%, and 84.40% of customers have promotions in at least 75% of their baskets. Mean promotion spend share is 50.11%, while only 2.12% of customers have at least 75% of sales on promotional lines. The two promotion measures have a Spearman correlation of only 0.3453.

**Business relevance**  
Frequent exposure to promotional baskets should not automatically be interpreted as strong promotion dependence. Basket-level promotion exposure and promotional sales reliance capture different aspects of behavior.

**Next analysis**  
Segmentation and the later promotion analysis will compare these measures separately and test whether distinct customer groups exhibit meaningfully different promotional behavior.

---

### Candidate Insight 5 — A small historically valuable high-recency pocket exists

**Finding**  
A small subset of historically valuable customers has gone materially longer than most customers without a purchase.

**Evidence**  
Using P80 thresholds for both historical sales and recency identifies 18 customers (0.72% of the customer base). They represent 133,715.49 in historical sales, or 1.66% of the dataset total, with median historical sales of 6,698.82 and median recency of 42 days. Under stricter P90/P90 thresholds, only two customers qualify.

**Business relevance**  
This is not evidence of a broad churn problem, but it identifies a narrowly defined population whose historical value may justify closer reactivation analysis.

**Next analysis**  
Segmentation will show whether these customers belong to a coherent behavioral segment. Any future reactivation recommendation must remain descriptive and must not assume churn, incremental lift or causal campaign impact.
