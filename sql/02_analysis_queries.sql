USE ecommerce_retention;

-- Q1. Overall churn rate among customers eligible for a full 180-day observation window
SELECT
  COUNT(*) AS eligible_customers,
  SUM(CASE WHEN churned_180d = TRUE THEN 1 ELSE 0 END) AS churned_customers,
  ROUND(100.0 * AVG(CASE WHEN churned_180d IS NOT NULL THEN churned_180d END), 2) AS churn_rate_pct
FROM customers
WHERE observation_eligible = TRUE;

-- Q2. Churn rate by customer tier
SELECT customer_tier, COUNT(*) AS customers,
       ROUND(100.0 * AVG(churned_180d), 2) AS churn_rate_pct,
       ROUND(AVG(lifetime_revenue_inr), 2) AS avg_lifetime_revenue_inr
FROM customers
WHERE observation_eligible = TRUE
GROUP BY customer_tier
ORDER BY churn_rate_pct DESC;

-- Q3. Monthly revenue and order trend
SELECT DATE_FORMAT(order_date, '%Y-%m') AS order_month,
       COUNT(DISTINCT order_id) AS delivered_orders,
       COUNT(DISTINCT customer_id) AS purchasing_customers,
       ROUND(SUM(net_order_value_inr), 2) AS net_revenue_inr
FROM orders
WHERE order_status = 'Delivered'
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY order_month;

-- Q4. Repeat purchase rate
WITH customer_order_counts AS (
  SELECT customer_id, COUNT(DISTINCT order_id) AS order_count
  FROM orders
  WHERE order_status = 'Delivered'
  GROUP BY customer_id
)
SELECT COUNT(*) AS purchasing_customers,
       SUM(order_count >= 2) AS repeat_customers,
       ROUND(100.0 * SUM(order_count >= 2) / COUNT(*), 2) AS repeat_purchase_rate_pct
FROM customer_order_counts;

-- Q5. RFM feature table
WITH rfm AS (
  SELECT customer_id,
         DATEDIFF('2024-12-31', MAX(order_date)) AS recency_days,
         COUNT(DISTINCT order_id) AS frequency,
         ROUND(SUM(net_order_value_inr), 2) AS monetary_value_inr
  FROM orders
  WHERE order_status = 'Delivered'
  GROUP BY customer_id
)
SELECT * FROM rfm
ORDER BY recency_days, frequency DESC, monetary_value_inr DESC;

-- Q6. Category performance
SELECT category,
       COUNT(DISTINCT order_id) AS delivered_orders,
       COUNT(DISTINCT customer_id) AS customers,
       ROUND(SUM(net_order_value_inr), 2) AS revenue_inr,
       ROUND(AVG(net_order_value_inr), 2) AS avg_net_order_value_inr
FROM orders
WHERE order_status = 'Delivered'
GROUP BY category
ORDER BY revenue_inr DESC;

-- Q7. Window function: each customer's most recent delivered order
WITH ranked_orders AS (
  SELECT customer_id, order_id, order_date, net_order_value_inr,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC) AS rn
  FROM orders
  WHERE order_status = 'Delivered'
)
SELECT customer_id, order_id, order_date, net_order_value_inr
FROM ranked_orders
WHERE rn = 1;

-- Q8. Cohort retention by first delivered-order month and month age
WITH first_order AS (
  SELECT customer_id, MIN(order_date) AS first_order_date
  FROM orders
  WHERE order_status = 'Delivered'
  GROUP BY customer_id
),
activity AS (
  SELECT o.customer_id,
         DATE_FORMAT(f.first_order_date, '%Y-%m-01') AS cohort_month,
         TIMESTAMPDIFF(MONTH, f.first_order_date, o.order_date) AS cohort_age_month,
         DATE_FORMAT(o.order_date, '%Y-%m-01') AS activity_month
  FROM orders o
  JOIN first_order f ON o.customer_id = f.customer_id
  WHERE o.order_status = 'Delivered'
),
cohort_size AS (
  SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_customers
  FROM activity
  WHERE cohort_age_month = 0
  GROUP BY cohort_month
),
retention AS (
  SELECT cohort_month, cohort_age_month, COUNT(DISTINCT customer_id) AS active_customers
  FROM activity
  GROUP BY cohort_month, cohort_age_month
)
SELECT r.cohort_month, r.cohort_age_month, r.active_customers, c.cohort_customers,
       ROUND(100.0 * r.active_customers / c.cohort_customers, 2) AS retention_pct
FROM retention r
JOIN cohort_size c ON r.cohort_month = c.cohort_month
ORDER BY r.cohort_month, r.cohort_age_month;
