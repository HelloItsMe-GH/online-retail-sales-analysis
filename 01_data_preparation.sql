-- Online Retail: preparation and business classification
-- PostgreSQL
-- Prerequisite: online_retail_staging has been imported from the source CSV.
-- Source columns are TEXT. This script rebuilds the clean table and sales view.

DROP VIEW IF EXISTS online_retail_sales;
DROP TABLE IF EXISTS online_retail_clean;

CREATE TABLE online_retail_clean AS
SELECT
    invoice_no,
    stock_code,
    NULLIF(TRIM(description), '') AS description,
    quantity::INTEGER AS quantity,
    TO_TIMESTAMP(invoice_date, 'DD.MM.YYYY HH24:MI')::TIMESTAMP AS invoice_date,
    REPLACE(unit_price, ',', '.')::NUMERIC(10, 2) AS unit_price,
    NULLIF(TRIM(customer_id), '') AS customer_id,
    country,
    quantity::INTEGER * REPLACE(unit_price, ',', '.')::NUMERIC(10, 2) AS line_amount,
    invoice_no LIKE 'C%' AS has_c_prefix
FROM online_retail_staging;

-- Classify positive goods sales separately from cancellations, zero-price rows,
-- postage/fees and financial adjustments. This is an analytical definition,
-- not a claim that every excluded row is a confirmed refund.
CREATE VIEW online_retail_sales AS
SELECT
    *,
    CASE
        WHEN quantity > 0
         AND unit_price > 0
         AND NOT has_c_prefix
         AND UPPER(TRIM(description)) NOT IN (
             'POSTAGE',
             'DOTCOM POSTAGE',
             'MANUAL',
             'CARRIAGE',
             'ADJUST BAD DEBT',
             'NEXT DAY CARRIAGE',
             'PACKING CHARGE',
             'BANK CHARGES',
             'AMAZON FEE',
             'SAMPLES'
         )
         AND UPPER(TRIM(stock_code)) NOT IN (
             'BANK CHARGES',
             'AMAZONFEE'
         )
        THEN TRUE
        ELSE FALSE
    END AS is_positive_goods_sale
FROM online_retail_clean;

-- Quick validation checks
SELECT 'staging' AS table_name, COUNT(*) AS row_count
FROM online_retail_staging
UNION ALL
SELECT 'clean', COUNT(*)
FROM online_retail_clean;

SELECT
    MIN(invoice_date) AS first_invoice_date,
    MAX(invoice_date) AS last_invoice_date,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS rows_without_customer_id,
    COUNT(*) FILTER (WHERE description IS NULL) AS rows_without_description,
    COUNT(*) FILTER (WHERE quantity < 0) AS rows_with_negative_quantity,
    COUNT(*) FILTER (WHERE unit_price = 0) AS rows_with_zero_price,
    COUNT(*) FILTER (WHERE unit_price < 0) AS rows_with_negative_price
FROM online_retail_clean;

SELECT
    is_positive_goods_sale,
    COUNT(*) AS rows_count,
    COUNT(DISTINCT invoice_no) AS invoices_count,
    ROUND(SUM(line_amount), 2) AS net_line_amount,
    SUM(quantity) AS total_quantity
FROM online_retail_sales
GROUP BY is_positive_goods_sale
ORDER BY is_positive_goods_sale DESC;
