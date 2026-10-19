# Dashboard Build Guide (Power BI / Tableau)

## Data model
- `customers[customer_id]` (one) → `orders[customer_id]` (many)
- Use a dedicated calendar/date table for time-series reporting.
- Keep customer-level churn status separate from order-level facts to avoid duplicating churn labels across transactions.

## Recommended layout
### Executive overview
Top row: eligible customers | 180-day churn rate | repeat-purchase rate | net delivered revenue | delivered orders.
Middle: monthly revenue line chart and annual purchasing-customer trend.
Bottom: churn by customer tier and acquisition channel.

### Retention
Cohort heatmap: cohort month on rows, cohort age month on columns, retention percentage as color.
Add slicers for acquisition channel, city, customer tier and acquisition year.
Use cohort-age comparisons when interpreting recent cohorts; recent cohorts have less time to mature.

### Segment deep dive
Bar chart: churn rate by segment.
Scatter: customer recency vs frequency, size by lifetime revenue.
Matrix: RFM segment, customers, average revenue, average recency, churn rate.
Category chart: delivered orders and net revenue by category.

## QA checklist
- Delivered revenue excludes returned/cancelled orders.
- Churn denominator includes only customers with at least 180 days of observation.
- A customer is counted once in customer-level metrics, not once per order.
- Cohort month is based on first delivered order, not signup date.
- Latest cohorts have incomplete follow-up; avoid comparing them directly with mature cohorts.
- All visuals display a "Synthetic portfolio dataset" note.
