-- MySQL 8.0+
-- Synthetic portfolio dataset. Not actual Amazon.in customer data.
CREATE DATABASE IF NOT EXISTS ecommerce_retention;
USE ecommerce_retention;

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
  customer_id VARCHAR(12) PRIMARY KEY,
  signup_date DATE NOT NULL,
  city VARCHAR(60),
  customer_tier VARCHAR(30),
  acquisition_channel VARCHAR(40),
  age_band VARCHAR(10),
  first_purchase_date DATE NULL,
  last_purchase_date DATE NULL,
  delivered_orders INT DEFAULT 0,
  lifetime_revenue_inr DECIMAL(14,2) DEFAULT 0,
  avg_order_value_inr DECIMAL(12,2) DEFAULT 0,
  days_since_last_purchase INT,
  observation_eligible BOOLEAN,
  churned_180d BOOLEAN NULL,
  customer_status VARCHAR(30)
);

CREATE TABLE orders (
  order_id VARCHAR(16) PRIMARY KEY,
  customer_id VARCHAR(12) NOT NULL,
  order_date DATE NOT NULL,
  category VARCHAR(60),
  order_amount_inr DECIMAL(12,2),
  discount_pct DECIMAL(5,2),
  payment_method VARCHAR(40),
  device_type VARCHAR(30),
  order_status VARCHAR(20),
  net_order_value_inr DECIMAL(12,2),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  INDEX idx_orders_date (order_date),
  INDEX idx_orders_customer_date (customer_id, order_date)
);

-- Load CSV files using MySQL Workbench Table Data Import Wizard,
-- or LOAD DATA LOCAL INFILE if enabled and configured.
