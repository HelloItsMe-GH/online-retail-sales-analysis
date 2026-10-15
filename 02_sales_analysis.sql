-- Online Retail: core exploratory analysis
-- Run after 01_data_preparation.sql.
-- Each section is a separate result set; in pgAdmin, inspect each Data Output tab.

-- 1. Monthly goods sales. December 2011 is incomplete (data ends Dec 9).
SELECT
    DATE_TRUNC('month', invoice_date)::DATE AS month,
    COUNT(DISTINCT invoice_no) AS invoices_count,
    COUNT(*) AS line_count,
    SUM(quantity) AS units_sold,
    ROUND(SUM(line_amount), 2) AS revenue
FROM online_retail_sales
WHERE is_positive_goods_sale = TRUE
GROUP BY 1
ORDER BY 1;

-- 2. Top 10 products by revenue.
SELECT
    stock_code,
    description,
    SUM(quantity) AS units_sold,
    COUNT(DISTINCT invoice_no) AS invoices_count,
    ROUND(SUM(line_amount), 2) AS revenue
FROM online_retail_sales
WHERE is_positive_goods_sale = TRUE
GROUP BY stock_code, description
ORDER BY revenue DESC
LIMIT 10;

-- 3. Top 10 products by quantity.
SELECT
    stock_code,
    description,
    SUM(quantity) AS units_sold,
    COUNT(DISTINCT invoice_no) AS invoices_count,
    ROUND(SUM(line_amount), 2) AS revenue
FROM online_retail_sales
WHERE is_positive_goods_sale = TRUE
GROUP BY stock_code, description
ORDER BY units_sold DESC
LIMIT 10;

-- 4. Country performance.
SELECT
    country,
    COUNT(DISTINCT invoice_no) AS invoices_count,
    COUNT(DISTINCT customer_id) AS identified_customers,
    SUM(quantity) AS units_sold,
    ROUND(SUM(line_amount), 2) AS revenue
FROM online_retail_sales
WHERE is_positive_goods_sale = TRUE
GROUP BY country
ORDER BY revenue DESC;

-- 5. Average and median invoice value by country; only countries with 20+ invoices.
WITH invoice_values AS (
    SELECT
        country,
        invoice_no,
        SUM(line_amount) AS invoice_value
    FROM online_retail_sales
    WHERE is_positive_goods_sale = TRUE
    GROUP BY country, invoice_no
)
SELECT
    country,
    COUNT(*) AS invoices_count,
    ROUND(AVG(invoice_value), 2) AS avg_invoice_value,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY invoice_value))::NUMERIC, 2)
        AS median_invoice_value,
    ROUND(MAX(invoice_value), 2) AS max_invoice_value
FROM invoice_values
GROUP BY country
HAVING COUNT(*) >= 20
ORDER BY avg_invoice_value DESC;

-- 6. Customers: one invoice versus repeat purchases.
WITH customer_metrics AS (
    SELECT
        customer_id,
        COUNT(DISTINCT invoice_no) AS invoices_count,
        SUM(line_amount) AS revenue
    FROM online_retail_sales
    WHERE is_positive_goods_sale = TRUE
      AND customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT
    CASE WHEN invoices_count = 1 THEN '1 invoice' ELSE '2+ invoices' END AS customer_group,
    COUNT(*) AS customers_count,
    SUM(invoices_count) AS invoices_count,
    ROUND(SUM(revenue), 2) AS revenue
FROM customer_metrics
GROUP BY 1
ORDER BY 1;

-- 7. Top 10 identified customers by goods revenue.
SELECT
    customer_id,
    COUNT(DISTINCT invoice_no) AS invoices_count,
    SUM(quantity) AS units_sold,
    ROUND(SUM(line_amount), 2) AS revenue
FROM online_retail_sales
WHERE is_positive_goods_sale = TRUE
  AND customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY revenue DESC
LIMIT 10;

-- 8. Monthly negative transactions on C-prefixed invoices.
-- Amount is shown as an absolute value for comparison; it is NOT verified
-- as cash refunds paid.
SELECT
    DATE_TRUNC('month', invoice_date)::DATE AS month,
    COUNT(DISTINCT invoice_no) AS c_invoices_count,
    COUNT(*) AS line_count,
    SUM(ABS(quantity)) AS units_on_negative_lines,
    ROUND(SUM(ABS(line_amount)), 2) AS absolute_line_amount
FROM online_retail_clean
WHERE has_c_prefix = TRUE
  AND quantity < 0
GROUP BY 1
ORDER BY 1;

-- 9. Top products by absolute amount on C-prefixed negative lines.
SELECT
    stock_code,
    description,
    COUNT(*) AS line_count,
    COUNT(DISTINCT invoice_no) AS c_invoices_count,
    SUM(ABS(quantity)) AS units_on_negative_lines,
    ROUND(SUM(ABS(line_amount)), 2) AS absolute_line_amount
FROM online_retail_clean
WHERE has_c_prefix = TRUE
  AND quantity < 0
GROUP BY stock_code, description
ORDER BY absolute_line_amount DESC
LIMIT 10;

-- 10. Investigate the large quantity outlier without deleting it.
SELECT
    invoice_no,
    invoice_date,
    customer_id,
    stock_code,
    description,
    quantity,
    unit_price,
    line_amount
FROM online_retail_sales
WHERE stock_code = '23843'
  AND is_positive_goods_sale = TRUE
ORDER BY line_amount DESC;

-- 11. Sensitivity check: goods revenue with and without the identified outlier.
SELECT
    'all qualifying goods sales' AS scenario,
    ROUND(SUM(line_amount), 2) AS revenue
FROM online_retail_sales
WHERE is_positive_goods_sale = TRUE

UNION ALL

SELECT
    'excluding identified outlier' AS scenario,
    ROUND(SUM(line_amount), 2) AS revenue
FROM online_retail_sales
WHERE is_positive_goods_sale = TRUE
  AND NOT (stock_code = '23843' AND invoice_no = '581483')
ORDER BY scenario;
