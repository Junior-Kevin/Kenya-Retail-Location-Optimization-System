CREATE VIEW gold.fact_store_performance AS
SELECT
    s.store_id,
    s.store_name,
    s.format,
    s.county,

    YEAR(p.transaction_date)  AS year,
    MONTH(p.transaction_date) AS month,

    COUNT(DISTINCT p.transaction_id) AS transactions,
    SUM(p.final_price_kes)              AS monthly_revenue,
    AVG(p.final_price_kes)              AS avg_transaction_value,
    SUM(p.quantity)                 AS units_sold,

    -- Revenue efficiency
    SUM(p.final_price_kes) / NULLIF(s.size_sqm, 0) AS revenue_per_sqm

FROM silver.pos p
JOIN silver.stores s
    ON p.store_id = s.store_id
GROUP BY
    s.store_id,
    s.store_name,
    s.format,
    s.size_sqm,
    s.county,
    YEAR(p.transaction_date),
    MONTH(p.transaction_date)
