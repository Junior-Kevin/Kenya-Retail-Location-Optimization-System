-- DROP TABLE IF EXISTS gold.customer_value;
-- GO

/*
===============================================================================
TABLE: gold.customer_value
PURPOSE: Identify who our best customers are and where they're located
BUSINESS QUESTIONS ANSWERED:
1. Who are our highest Lifetime Value (LTV) customers?
2. How concentrated is revenue among top customers?
3. Which counties generate the most valuable customers?
4. Are frequent shoppers also high-value shoppers?
5. Which customers are discount-sensitive?
6. Which counties have high-value but low-frequency customers?
===============================================================================
*/
IF OBJECT_ID('gold.customer_value', 'U') IS NOT NULL
    DROP TABLE gold.customer_value;
GO

CREATE TABLE gold.customer_value (
    customer_id NVARCHAR(50) PRIMARY KEY,
    primary_county NVARCHAR(100),
    customer_segment NVARCHAR(50),
    preferred_store_format NVARCHAR(50),
    registration_date DATE,
    
    -- Monetary metrics
    total_spend_kes DECIMAL(18,2),
    avg_transaction_value_kes DECIMAL(18,2),
    lifetime_value_kes DECIMAL(18,2),
    
    -- Frequency metrics
    total_transactions INT,
    purchase_frequency_monthly DECIMAL(10,2),
    days_since_last_purchase INT,
    customer_tenure_months INT,
    
    -- Behavioral metrics
    feedback_score DECIMAL(5,2),
    mpesa_ratio DECIMAL(5,2),
    cash_ratio DECIMAL(5,2),
    card_ratio DECIMAL(5,2),
    
    -- RFM scores (1-5, 5=best)
    recency_score INT,
    frequency_score INT,
    monetary_score INT,
    
    -- Composite scores
    customer_value_score DECIMAL(5,2),  -- 0-100 scale
    value_tier NVARCHAR(20),            -- Platinum, Gold, Silver, Bronze
    
    -- Business flags
    churn_risk_flag BIT,
    high_value_flag BIT,
    discount_sensitive_flag BIT,
    premium_customer_flag BIT
);
GO

WITH pos_agg AS (
    SELECT
        p.customer_id,
        COUNT(DISTINCT p.transaction_id) AS total_transactions,
        SUM(p.final_price_kes) AS total_spend_kes,
        AVG(p.final_price_kes) AS avg_transaction_value_kes,
        MAX(p.transaction_date) AS last_purchase_date,
        
        -- Payment method ratios
        AVG(CASE WHEN p.payment_method = 'M-Pesa' THEN 1.0 ELSE 0.0 END) AS mpesa_ratio,
        AVG(CASE WHEN p.payment_method = 'Cash' THEN 1.0 ELSE 0.0 END) AS cash_ratio,
        AVG(CASE WHEN p.payment_method = 'Card' THEN 1.0 ELSE 0.0 END) AS card_ratio,
        
        -- Discount sensitivity
        AVG(CASE WHEN p.discount_kes > 0 THEN 1.0 ELSE 0.0 END) AS discount_usage_ratio,
        AVG(p.discount_kes / NULLIF(p.total_price_kes, 0)) AS avg_discount_rate
    FROM silver.pos p
    WHERE p.customer_id <> 'ANONYMOUS'
    GROUP BY p.customer_id
),
customer_base AS (
    SELECT
        c.customer_id,
        c.county AS primary_county,
        c.customer_segment,
        c.preferred_store_format,
        c.registration_date,
        c.feedback_score,
        c.purchase_frequency_monthly,
        c.lifetime_value_kes
    FROM silver.crm c
),
joined AS (
    SELECT
        cb.customer_id,
        cb.primary_county,
        cb.customer_segment,
        cb.preferred_store_format,
        cb.registration_date,
        cb.feedback_score,
        cb.purchase_frequency_monthly,
        cb.lifetime_value_kes,
        
        pa.total_spend_kes,
        pa.avg_transaction_value_kes,
        pa.total_transactions,
        pa.last_purchase_date,
        pa.mpesa_ratio,
        pa.cash_ratio,
        pa.card_ratio,
        pa.discount_usage_ratio,
        pa.avg_discount_rate
    FROM customer_base cb
    JOIN pos_agg pa ON cb.customer_id = pa.customer_id
),
rfm_scored AS (
    SELECT *,
        -- Recency: lower days since last purchase = better
        NTILE(5) OVER (ORDER BY DATEDIFF(DAY, last_purchase_date, GETDATE()) ASC) AS recency_score,
        -- Frequency: more transactions = better
        NTILE(5) OVER (ORDER BY total_transactions DESC) AS frequency_score,
        -- Monetary: higher spend = better
        NTILE(5) OVER (ORDER BY total_spend_kes DESC) AS monetary_score
    FROM joined
),
calculated AS (
    SELECT
        customer_id,
        primary_county,
        customer_segment,
        preferred_store_format,
        registration_date,
        feedback_score,
        purchase_frequency_monthly,
        lifetime_value_kes,
        total_spend_kes,
        avg_transaction_value_kes,
        total_transactions,
        DATEDIFF(DAY, last_purchase_date, GETDATE()) AS days_since_last_purchase,
        DATEDIFF(MONTH, registration_date, GETDATE()) AS customer_tenure_months,
        mpesa_ratio,
        cash_ratio,
        card_ratio,
        recency_score,
        frequency_score,
        monetary_score,
        discount_usage_ratio,
        avg_discount_rate,
        
        -- Customer Value Score (0-100)
        CAST((recency_score * 0.3 + frequency_score * 0.3 + monetary_score * 0.4) * 20 AS DECIMAL(5,2)) AS customer_value_score,
        
        -- Value Tiers
        CASE
            WHEN (recency_score + frequency_score + monetary_score) >= 13 THEN 'Platinum'
            WHEN (recency_score + frequency_score + monetary_score) >= 10 THEN 'Gold'
            WHEN (recency_score + frequency_score + monetary_score) >= 7 THEN 'Silver'
            ELSE 'Bronze'
        END AS value_tier
    FROM rfm_scored
)

INSERT INTO gold.customer_value
SELECT
    customer_id,
    primary_county,
    customer_segment,
    preferred_store_format,
    registration_date,
    total_spend_kes,
    avg_transaction_value_kes,
    lifetime_value_kes,
    total_transactions,
    purchase_frequency_monthly,
    days_since_last_purchase,
    customer_tenure_months,
    feedback_score,
    mpesa_ratio,
    cash_ratio,
    card_ratio,
    recency_score,
    frequency_score,
    monetary_score,
    customer_value_score,
    value_tier,
    
    -- Business flags
    CASE WHEN days_since_last_purchase > 90 THEN 1 ELSE 0 END AS churn_risk_flag,
    CASE WHEN monetary_score >= 4 AND frequency_score >= 4 THEN 1 ELSE 0 END AS high_value_flag,
    CASE WHEN discount_usage_ratio > 0.5 THEN 1 ELSE 0 END AS discount_sensitive_flag,
    CASE WHEN value_tier IN ('Platinum', 'Gold') THEN 1 ELSE 0 END AS premium_customer_flag
FROM calculated;
GO

-- Indexes for common queries
CREATE INDEX idx_customer_value_score ON gold.customer_value(customer_value_score DESC);
CREATE INDEX idx_customer_county ON gold.customer_value(primary_county);
CREATE INDEX idx_customer_tier ON gold.customer_value(value_tier);
CREATE INDEX idx_customer_churn ON gold.customer_value(churn_risk_flag);
GO

/*
README: gold.customer_value
PURPOSE: Identify high-value customers and understand customer economics by county
KEY METRICS:
- customer_value_score (0-100): Composite score based on RFM analysis
- value_tier: Customer segmentation (Platinum, Gold, Silver, Bronze)
- lifetime_value_kes: Total customer revenue
- churn_risk_flag: Customers inactive for >90 days

BUSINESS QUESTIONS ANSWERED:
1. Who are our most valuable customers? (high customer_value_score)
2. Which counties have the highest concentration of Platinum customers?
3. Are high-frequency customers also high-value? (frequency_score vs monetary_score)
4. Which customers are at risk of churning? (churn_risk_flag = 1)
5. What is the revenue concentration? (Query top 20% customers by spend)

SAMPLE QUERIES:
-- Top 10 customers by value
SELECT TOP 10 * FROM gold.customer_value 
ORDER BY customer_value_score DESC;

-- Customer distribution by county
SELECT primary_county, value_tier, COUNT(*) as customer_count
FROM gold.customer_value 
GROUP BY primary_county, value_tier 
ORDER BY primary_county, 
    CASE value_tier 
        WHEN 'Platinum' THEN 1 
        WHEN 'Gold' THEN 2 
        WHEN 'Silver' THEN 3 
        ELSE 4 
    END;

-- Churn risk analysis
SELECT primary_county, 
    COUNT(*) as total_customers,
    SUM(CASE WHEN churn_risk_flag = 1 THEN 1 ELSE 0 END) as at_risk_customers,
    AVG(customer_value_score) as avg_value_score
FROM gold.customer_value
GROUP BY primary_county
HAVING SUM(CASE WHEN churn_risk_flag = 1 THEN 1 ELSE 0 END) > 10;
===============================================================================
*/
SELECT * FROM gold.customer_value
