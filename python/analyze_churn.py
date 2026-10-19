"""
Amazon.in-style Customer Churn & Retention Analysis
Synthetic dataset for portfolio demonstration; not actual Amazon customer data.
Run from project root: python python/analyze_churn.py
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
customers = pd.read_csv(ROOT / "data" / "customers.csv", parse_dates=["signup_date", "first_purchase_date", "last_purchase_date"])
orders = pd.read_csv(ROOT / "data" / "orders.csv", parse_dates=["order_date"])

ANALYSIS_DATE = pd.Timestamp("2024-12-31")
DELIVERED = orders.loc[orders["order_status"].eq("Delivered")].copy()
DELIVERED["order_month"] = DELIVERED["order_date"].dt.to_period("M").dt.to_timestamp()
DELIVERED["signup_cohort"] = DELIVERED["customer_id"].map(
    customers.set_index("customer_id")["signup_date"].dt.to_period("M").astype(str)
)

# 1) Data quality checks
print("Customers:", len(customers), "Orders:", len(orders))
print("Duplicate customer IDs:", customers["customer_id"].duplicated().sum())
print("Duplicate order IDs:", orders["order_id"].duplicated().sum())
print("Null customer IDs in orders:", orders["customer_id"].isna().sum())
print("Invalid negative order amounts:", (orders["order_amount_inr"] < 0).sum())

# 2) KPI summary
eligible = customers.loc[customers["observation_eligible"].astype(str).str.lower().isin(["true", "1"])]
churn = pd.to_numeric(eligible["churned_180d"], errors="coerce")
print("\\n--- KPI SUMMARY ---")
print(f"Eligible customers: {len(eligible):,}")
print(f"180-day churn rate: {churn.mean():.1%}")
print(f"Total delivered orders: {len(DELIVERED):,}")
print(f"Net delivered revenue (INR): ₹{DELIVERED['net_order_value_inr'].sum():,.0f}")
print(f"Repeat-purchase customer rate: {(customers['delivered_orders'] >= 2).mean():.1%}")

# 3) Monthly trends
monthly = DELIVERED.groupby("order_month").agg(
    delivered_orders=("order_id", "nunique"),
    purchasing_customers=("customer_id", "nunique"),
    revenue_inr=("net_order_value_inr", "sum"),
    aov_inr=("net_order_value_inr", "mean"),
).reset_index()
monthly.to_csv(ROOT / "data" / "monthly_kpis.csv", index=False)

# 4) Churn by customer tier and acquisition channel
eligible = eligible.copy()
eligible["churned_180d"] = pd.to_numeric(eligible["churned_180d"], errors="coerce")
for dim in ["customer_tier", "acquisition_channel", "city", "age_band"]:
    segment = eligible.groupby(dim).agg(
        customers=("customer_id", "nunique"),
        churn_rate=("churned_180d", "mean"),
        avg_lifetime_revenue_inr=("lifetime_revenue_inr", "mean"),
        avg_delivered_orders=("delivered_orders", "mean"),
    ).reset_index()
    segment.to_csv(ROOT / "data" / f"churn_by_{dim}.csv", index=False)

# 5) Cohort retention: customers who made at least one delivered order in cohort month,
# then share of cohort customers with a delivered order in each subsequent month.
first_order = DELIVERED.groupby("customer_id")["order_date"].min().rename("first_order_date")
cohort_base = DELIVERED.merge(first_order, on="customer_id", how="left")
cohort_base["cohort_month"] = cohort_base["first_order_date"].dt.to_period("M")
cohort_base["order_month_period"] = cohort_base["order_date"].dt.to_period("M")
cohort_base["cohort_age_month"] = (
    (cohort_base["order_month_period"].dt.year - cohort_base["cohort_month"].dt.year) * 12
    + cohort_base["order_month_period"].dt.month - cohort_base["cohort_month"].dt.month
)
cohort_counts = cohort_base.groupby(["cohort_month", "cohort_age_month"])["customer_id"].nunique().reset_index(name="active_customers")
cohort_sizes = cohort_counts.loc[cohort_counts["cohort_age_month"].eq(0), ["cohort_month", "active_customers"]].rename(columns={"active_customers":"cohort_size"})
cohort_counts = cohort_counts.merge(cohort_sizes, on="cohort_month", how="left")
cohort_counts["retention_rate"] = cohort_counts["active_customers"] / cohort_counts["cohort_size"]
cohort_counts.to_csv(ROOT / "data" / "cohort_retention.csv", index=False)

# 6) RFM segmentation at analysis date
rfm = DELIVERED.groupby("customer_id").agg(
    recency_days=("order_date", lambda s: (ANALYSIS_DATE - s.max()).days),
    frequency=("order_id", "nunique"),
    monetary=("net_order_value_inr", "sum"),
).reset_index()
rfm["R_score"] = pd.qcut(rfm["recency_days"].rank(method="first", ascending=False), 4, labels=[4,3,2,1]).astype(int)
rfm["F_score"] = pd.qcut(rfm["frequency"].rank(method="first"), 4, labels=[1,2,3,4]).astype(int)
rfm["M_score"] = pd.qcut(rfm["monetary"].rank(method="first"), 4, labels=[1,2,3,4]).astype(int)
rfm["rfm_segment"] = np.select(
    [(rfm["R_score"] >= 3) & (rfm["F_score"] >= 3),
     (rfm["R_score"] >= 3) & (rfm["F_score"] <= 2),
     (rfm["R_score"] <= 2) & (rfm["F_score"] >= 3),
     (rfm["R_score"] <= 2) & (rfm["F_score"] <= 2)],
    ["Loyal / High Value", "New / Promising", "Needs Attention", "Hibernating"],
    default="Other"
)
rfm.to_csv(ROOT / "data" / "rfm_segments.csv", index=False)

print("\\nAnalysis outputs saved to data/.")
