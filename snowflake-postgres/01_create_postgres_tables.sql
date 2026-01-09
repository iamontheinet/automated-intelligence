-- ============================================================================
-- Snowflake Postgres: Create Tables
-- ============================================================================
-- Run this directly against your Snowflake Postgres instance using psql or
-- any PostgreSQL client.
--
-- Connection string format:
-- postgres://<user>:<password>@<host>:5432/postgres?sslmode=require
--
-- Database: postgres
-- Schema: public (default)
-- ============================================================================

-- Create schema if needed (optional - using public by default)
-- CREATE SCHEMA IF NOT EXISTS automated_intelligence;
-- SET search_path TO automated_intelligence;

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    customer_id BIGINT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    registration_date DATE,
    customer_segment VARCHAR(20)
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(36) PRIMARY KEY,
    customer_id BIGINT,
    order_date TIMESTAMP,
    order_status VARCHAR(20),
    total_amount NUMERIC(10,2),
    discount_percent NUMERIC(5,2),
    shipping_cost NUMERIC(8,2)
);

-- Order Items table
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36),
    product_id BIGINT,
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    quantity BIGINT,
    unit_price NUMERIC(10,2),
    line_total NUMERIC(12,2)
);

-- Product Catalog table
CREATE TABLE IF NOT EXISTS product_catalog (
    product_id BIGINT PRIMARY KEY,
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    description TEXT,
    features TEXT,
    price NUMERIC(10,2),
    stock_quantity BIGINT
);

-- Product Reviews table
CREATE TABLE IF NOT EXISTS product_reviews (
    review_id SERIAL PRIMARY KEY,
    product_id BIGINT,
    customer_id BIGINT,
    review_date DATE,
    rating BIGINT,
    review_title VARCHAR(200),
    review_text TEXT,
    verified_purchase BOOLEAN
);

-- Support Tickets table
CREATE TABLE IF NOT EXISTS support_tickets (
    ticket_id SERIAL PRIMARY KEY,
    customer_id BIGINT,
    ticket_date TIMESTAMP,
    category VARCHAR(50),
    priority VARCHAR(20),
    subject VARCHAR(200),
    description TEXT,
    resolution TEXT,
    status VARCHAR(20)
);

-- Data Quality Alerts table
CREATE TABLE IF NOT EXISTS data_quality_alerts (
    alert_time TIMESTAMP PRIMARY KEY,
    issue_summary TEXT
);
