-- DROP TABLE IF EXISTS gold.fact_store_performance;
-- GO

/*
===============================================================================
TABLE: gold.fact_store_performance
PURPOSE: Store-level performance benchmarking and optimization
BUSINESS QUESTIONS ANSWERED:
1. Which stores outperform their county average?
2. Which stores underperform despite strong locations?
3. What is revenue per sqm by format?
4. Are nearby stores hurting each other?
===============================================================================
*/
IF OBJECT_ID('gold.fact_store_performance', 'U') IS NOT NULL
    DROP TABLE gold.fact_store_performance;
GO

CREATE TABLE gold.fact_store_performance (
    store_id NVARCHAR(50) PRIMARY KEY,
    store_name NVARCHAR(100),
    county NVARCHAR(100),
    store_format NVARCHAR(50),
    size_sqm INT,
    opening_date DATE,
    
    -- Sales performance
    total_transactions INT,
    total_revenue_kes DECIMAL(18,2),
    avg_transaction_value DECIMAL(18,2),
    unique_customers INT,
    last_transaction_date DATE,
    days_since_last_sale INT,
    
    -- Efficiency metrics
    revenue_per_sqm DECIMAL(18,2),
    revenue_per_customer DECIMAL(18,2),
    avg_items_per_transaction DECIMAL(10,2),
    
    -- Customer quality
    avg_customer_value DECIMAL(5,2),
    premium_customer_ratio DECIMAL(5,2),
    
    -- Competition metrics
    competitors_in_county INT,
    avg_competitor_size DECIMAL(10,2),
    
    -- Performance benchmarks
    revenue_tier NVARCHAR(10),  -- High, Medium, Low
    vs_county_average DECIMAL(10,2),  -- % above/below county average
    efficiency_score DECIMAL(5,2),    -- 0-100 scale
    
    -- Flags
    underperforming_flag BIT,
    cannibalization_risk BIT,
    at_risk_flag BIT
);
GO

WITH store_sales AS (
    SELECT
        p.store_id,
        s.store_name,
        s.county,
        s.format AS store_format,
        s.size_sqm,
        COUNT(DISTINCT p.transaction_id) AS total_transactions,
        SUM(p.final_price_kes) AS total_revenue_kes,
        AVG(p.final_price_kes) AS avg_transaction_value,
        COUNT(DISTINCT p.customer_id) AS unique_customers,
        MAX(p.transaction_date) AS last_transaction_date,
        SUM(p.quantity) AS total_items
    FROM silver.pos p
    INNER JOIN silver.stores s ON p.store_id = s.store_id
    WHERE p.customer_id <> 'ANONYMOUS'
    GROUP BY p.store_id, s.store_name, s.county, s.format, s.size_sqm
),
store_customers AS (
    SELECT
        p.store_id,
        AVG(cv.customer_value_score) AS avg_customer_value,
        AVG(CASE WHEN cv.value_tier IN ('Platinum', 'Gold') THEN 1.0 ELSE 0.0 END) AS premium_customer_ratio
    FROM silver.pos p
    INNER JOIN gold.customer_value cv ON p.customer_id = cv.customer_id
    WHERE p.customer_id <> 'ANONYMOUS'
    GROUP BY p.store_id
),
store_competition AS (
    SELECT
        s.county,
        s.store_id,
        COUNT(cs.store_id) AS competitors_in_county,
        AVG(cs.store_size_sqm) AS avg_competitor_size
    FROM silver.stores s
    LEFT JOIN silver.competitor_stores cs ON s.county = cs.county
    GROUP BY s.county, s.store_id
),
county_averages AS (
    SELECT
        county,
        AVG(total_revenue_kes) AS avg_county_revenue,
        AVG(revenue_per_sqm) AS avg_county_revenue_per_sqm
    FROM (
        SELECT 
            s.county,
            ss.total_revenue_kes,
            CASE WHEN s.size_sqm > 0 THEN ss.total_revenue_kes / s.size_sqm ELSE 0 END AS revenue_per_sqm
        FROM store_sales ss
        INNER JOIN silver.stores s ON ss.store_id = s.store_id
    ) t
    GROUP BY county
),
calculated AS (
    SELECT
        ss.store_id,
        ss.store_name,
        ss.county,
        ss.store_format,
        ss.size_sqm,
        NULL AS opening_date,
        
        -- Sales performance
        ss.total_transactions,
        ss.total_revenue_kes,
        ss.avg_transaction_value,
        ss.unique_customers,
        ss.last_transaction_date,
        DATEDIFF(DAY, ss.last_transaction_date, GETDATE()) AS days_since_last_sale,
        
        -- Efficiency metrics
        CASE WHEN ss.size_sqm > 0 THEN ss.total_revenue_kes / ss.size_sqm ELSE 0 END AS revenue_per_sqm,
        CASE WHEN ss.unique_customers > 0 THEN ss.total_revenue_kes / ss.unique_customers ELSE 0 END AS revenue_per_customer,
        CASE WHEN ss.total_transactions > 0 THEN CAST(ss.total_items AS DECIMAL(18,2)) / ss.total_transactions ELSE 0 END AS avg_items_per_transaction,
        
        -- Customer quality
        COALESCE(sc.avg_customer_value, 0) AS avg_customer_value,
        COALESCE(sc.premium_customer_ratio, 0) AS premium_customer_ratio,
        
        -- Competition
        COALESCE(stc.competitors_in_county, 0) AS competitors_in_county,
        COALESCE(stc.avg_competitor_size, 0) AS avg_competitor_size,
        
        -- County averages
        COALESCE(ca.avg_county_revenue, 0) AS avg_county_revenue,
        COALESCE(ca.avg_county_revenue_per_sqm, 0) AS avg_county_revenue_per_sqm
    FROM store_sales ss
    LEFT JOIN store_customers sc ON ss.store_id = sc.store_id
    LEFT JOIN store_competition stc ON ss.store_id = stc.store_id
    LEFT JOIN county_averages ca ON ss.county = ca.county
),
percentiles AS (
    SELECT 
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY revenue_per_sqm) OVER () AS p90_revenue_per_sqm
    FROM calculated
    WHERE revenue_per_sqm > 0
)

INSERT INTO gold.fact_store_performance
SELECT
    c.store_id,
    c.store_name,
    c.county,
    c.store_format,
    c.size_sqm,
    c.opening_date,
    c.total_transactions,
    c.total_revenue_kes,
    c.avg_transaction_value,
    c.unique_customers,
    c.last_transaction_date,
    c.days_since_last_sale,
    c.revenue_per_sqm,
    c.revenue_per_customer,
    c.avg_items_per_transaction,
    c.avg_customer_value,
    c.premium_customer_ratio,
    c.competitors_in_county,
    c.avg_competitor_size,
    
    -- Performance tiers
    CASE 
        WHEN c.total_revenue_kes > 1000000 THEN 'High'
        WHEN c.total_revenue_kes > 500000 THEN 'Medium'
        ELSE 'Low'
    END AS revenue_tier,
    
    -- Vs county average
    CASE 
        WHEN c.avg_county_revenue > 0 
        THEN ((c.total_revenue_kes - c.avg_county_revenue) / c.avg_county_revenue) * 100
        ELSE 0 
    END AS vs_county_average,
    
    -- Efficiency score (0-100)
    CASE 
        WHEN c.revenue_per_sqm <= 0 THEN 0
        WHEN c.revenue_per_sqm >= (SELECT DISTINCT p90_revenue_per_sqm FROM percentiles) THEN 100
        ELSE (c.revenue_per_sqm / (SELECT DISTINCT p90_revenue_per_sqm FROM percentiles)) * 100
    END AS efficiency_score,
    
    -- Flags (calculated in final SELECT)
    CASE 
        WHEN c.avg_county_revenue > 0 AND ((c.total_revenue_kes - c.avg_county_revenue) / c.avg_county_revenue) * 100 < -20 
        THEN 1 ELSE 0 
    END AS underperforming_flag,
    
    CASE 
        WHEN c.competitors_in_county > 3 AND c.avg_county_revenue > 0 
             AND ((c.total_revenue_kes - c.avg_county_revenue) / c.avg_county_revenue) * 100 < -10 
        THEN 1 ELSE 0 
    END AS cannibalization_risk,
    
    CASE 
        WHEN c.days_since_last_sale > 30 OR c.unique_customers < 10 THEN 1 ELSE 0 
    END AS at_risk_flag
FROM calculated c;
GO

-- Indexes
CREATE INDEX idx_store_performance_county ON gold.fact_store_performance(county);
CREATE INDEX idx_store_performance_revenue ON gold.fact_store_performance(total_revenue_kes DESC);
CREATE INDEX idx_store_performance_efficiency ON gold.fact_store_performance(efficiency_score DESC);
CREATE INDEX idx_store_performance_underperforming ON gold.fact_store_performance(underperforming_flag);
GO

/*
README: gold.fact_store_performance
PURPOSE: Store-level performance analysis and benchmarking
KEY METRICS:
- revenue_per_sqm: Store efficiency metric
- vs_county_average: Performance relative to county peers (%)
- efficiency_score: Composite efficiency score (0-100)
- underperforming_flag: Stores performing >20% below county average

BUSINESS QUESTIONS ANSWERED:
1. Which stores are most efficient? (high revenue_per_sqm)
2. Which stores underperform relative to their market? (underperforming_flag = 1)
3. What is the optimal store size by format? (size_sqm vs revenue analysis)
4. Are stores cannibalizing each other? (cannibalization_risk = 1)
5. Which stores attract premium customers? (high premium_customer_ratio)

SAMPLE QUERIES:
-- Top 10 most efficient stores
SELECT TOP 10 store_name, county, revenue_per_sqm, efficiency_score, total_revenue_kes
FROM gold.fact_store_performance 
ORDER BY efficiency_score DESC;

-- Underperforming stores by county
SELECT county, COUNT(*) as total_stores,
       SUM(CASE WHEN underperforming_flag = 1 THEN 1 ELSE 0 END) as underperforming_stores
FROM gold.fact_store_performance
GROUP BY county
HAVING SUM(CASE WHEN underperforming_flag = 1 THEN 1 ELSE 0 END) > 0;

-- Store format performance analysis
SELECT store_format, 
       AVG(revenue_per_sqm) as avg_revenue_per_sqm,
       AVG(efficiency_score) as avg_efficiency,
       COUNT(*) as store_count
FROM gold.fact_store_performance
GROUP BY store_format
ORDER BY avg_revenue_per_sqm DESC;

-- Cannibalization risk analysis
SELECT county, store_name, competitors_in_county, vs_county_average
FROM gold.fact_store_performance
WHERE cannibalization_risk = 1
ORDER BY county, vs_county_average;
===============================================================================
*/
select * from gold.fact_store_performance
