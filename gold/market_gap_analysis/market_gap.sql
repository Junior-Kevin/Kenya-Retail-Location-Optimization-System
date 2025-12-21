-- DROP TABLE IF EXISTS gold.market_gap_analysis;
-- GO

/*
===============================================================================
TABLE: gold.market_gap_analysis
PURPOSE: Identify underserved markets and expansion opportunities
BUSINESS QUESTIONS ANSWERED:
1. Where does demand exceed store coverage?
2. Which counties have high potential but few stores?
3. Where are customers traveling far to shop?
4. Which counties are over-served?
===============================================================================
*/
IF OBJECT_ID('gold.market_gap_analysis', 'U') IS NOT NULL
    DROP TABLE gold.market_gap_analysis;
GO

CREATE TABLE gold.market_gap_analysis (
    county_name NVARCHAR(100) PRIMARY KEY,
    population_2023 INT,
    avg_household_income_kes DECIMAL(12,2),
    
    -- Current coverage
    store_count INT,
    competitor_density INT,
    total_customers INT,
    current_revenue_kes DECIMAL(18,2),
    
    -- Coverage metrics
    stores_per_100k DECIMAL(10,4),
    competitors_per_100k DECIMAL(10,4),
    customer_penetration_rate DECIMAL(5,2),  -- % of population who are customers
    
    -- Gap analysis
    store_coverage_gap DECIMAL(10,4),       -- vs target of 2 stores per 100k
    customer_penetration_gap INT,           -- vs target of 30% penetration
    revenue_gap_kes DECIMAL(18,2),          -- vs market potential
    
    -- Market potential
    estimated_market_potential_kes DECIMAL(18,2),
    market_attractiveness_score DECIMAL(5,2),
    expansion_priority NVARCHAR(10),
    
    -- Competitive landscape
    competitive_intensity NVARCHAR(50),     -- Low, Moderate, High
    market_saturation DECIMAL(5,2),         -- 0-100, higher = more saturated
    
    -- Opportunity scoring
    opportunity_score DECIMAL(5,2),         -- 0-100, higher = more opportunity
    recommended_action NVARCHAR(100),
    estimated_new_stores_needed INT,
    revenue_opportunity_kes DECIMAL(18,2),
    
    -- Flags
    underserved_flag BIT,
    overserved_flag BIT,
    high_opportunity_flag BIT
);
GO

WITH county_data AS (
    SELECT
        dc.county_name,
        dc.population_2023,
        dc.avg_household_income_kes,
        dc.store_count,
        dc.competitor_density,
        dc.total_customers,
        dc.market_attractiveness_score,
        dc.expansion_priority,
        
        -- Coverage metrics
        CASE WHEN dc.population_2023 > 0 
             THEN dc.store_count * 100000.0 / dc.population_2023 
             ELSE 0 
        END AS stores_per_100k,
        
        CASE WHEN dc.population_2023 > 0 
             THEN dc.competitor_density * 100000.0 / dc.population_2023 
             ELSE 0 
        END AS competitors_per_100k,
        
        CASE WHEN dc.population_2023 > 0 
             THEN (dc.total_customers * 100.0) / dc.population_2023 
             ELSE 0 
        END AS customer_penetration_rate
    FROM gold.dim_county dc
),
revenue_data AS (
    SELECT
        p.store_county,
        SUM(p.final_price_kes) AS current_revenue_kes
    FROM silver.pos p
    WHERE p.store_county IS NOT NULL
    GROUP BY p.store_county
),
analysis AS (
    SELECT
        cd.county_name,
        cd.population_2023,
        cd.avg_household_income_kes,
        cd.store_count,
        cd.competitor_density,
        cd.total_customers,
        COALESCE(rd.current_revenue_kes, 0) AS current_revenue_kes,
        cd.stores_per_100k,
        cd.competitors_per_100k,
        cd.customer_penetration_rate,
        cd.market_attractiveness_score,
        cd.expansion_priority,
        
        -- Gap calculations
        CASE WHEN cd.stores_per_100k < 2 THEN 2 - cd.stores_per_100k ELSE 0 END AS store_coverage_gap,
        
        CASE WHEN cd.population_2023 > 0 
             THEN (cd.population_2023 * 0.3) - cd.total_customers 
             ELSE 0 
        END AS customer_penetration_gap,
        
        -- Market potential (simplified: 5% of total county income)
        cd.population_2023 * cd.avg_household_income_kes * 0.05 AS estimated_market_potential_kes,
        
        -- Competitive intensity
        CASE 
            WHEN cd.competitor_density = 0 THEN 'Low'
            WHEN cd.competitor_density <= cd.store_count THEN 'Moderate'
            ELSE 'High'
        END AS competitive_intensity,
        
        -- Market saturation (0-100, higher = more saturated)
        CASE 
            WHEN cd.stores_per_100k > 5 THEN 100
            WHEN cd.stores_per_100k > 3 THEN 80
            WHEN cd.stores_per_100k > 2 THEN 60
            WHEN cd.stores_per_100k > 1 THEN 40
            WHEN cd.stores_per_100k > 0 THEN 20
            ELSE 0
        END AS market_saturation
    FROM county_data cd
    LEFT JOIN revenue_data rd ON cd.county_name = rd.store_county
),
with_opportunity_score AS (
    SELECT *,
        -- Opportunity Score (0-100)
        (
            (store_coverage_gap * 50 * 0.3) +  -- Store coverage gap component
            (CASE WHEN customer_penetration_gap > 0 
                  THEN (customer_penetration_gap * 100.0 / population_2023) * 30 
                  ELSE 0 END) +  -- Customer penetration gap component
            (market_attractiveness_score * 0.25) +  -- Market attractiveness
            (CASE WHEN competitive_intensity = 'Low' THEN 100
                  WHEN competitive_intensity = 'Moderate' THEN 50
                  ELSE 0 END * 0.15)  -- Competition advantage
        ) AS opportunity_score
    FROM analysis
)

INSERT INTO gold.market_gap_analysis
SELECT
    county_name,
    population_2023,
    avg_household_income_kes,
    store_count,
    competitor_density,
    total_customers,
    current_revenue_kes,
    stores_per_100k,
    competitors_per_100k,
    customer_penetration_rate,
    store_coverage_gap,
    customer_penetration_gap,
    estimated_market_potential_kes - current_revenue_kes AS revenue_gap_kes,
    estimated_market_potential_kes,
    market_attractiveness_score,
    expansion_priority,
    competitive_intensity,
    market_saturation,
    opportunity_score,
    
    -- Recommended action
    CASE 
        WHEN store_coverage_gap > 1 AND customer_penetration_gap > 10000 THEN 'High Priority - Open New Store'
        WHEN store_coverage_gap > 0.5 AND market_attractiveness_score > 70 THEN 'Medium Priority - Expand Existing'
        WHEN customer_penetration_gap > 5000 AND competitive_intensity = 'Low' THEN 'High Priority - Market Entry'
        WHEN store_coverage_gap > 0 AND expansion_priority = 'High' THEN 'Consider - Market Development'
        WHEN market_saturation > 80 THEN 'Monitor - Market Saturated'
        ELSE 'Maintain - Adequate Coverage'
    END AS recommended_action,
    
    -- Estimated new stores needed
    CEILING(store_coverage_gap * population_2023 / 100000) AS estimated_new_stores_needed,
    
    -- Revenue opportunity
    estimated_market_potential_kes - current_revenue_kes AS revenue_opportunity_kes,
    
    -- Flags
    CASE WHEN store_coverage_gap > 0.5 AND customer_penetration_rate < 20 THEN 1 ELSE 0 END AS underserved_flag,
    CASE WHEN market_saturation > 80 THEN 1 ELSE 0 END AS overserved_flag,
    CASE WHEN opportunity_score > 70 THEN 1 ELSE 0 END AS high_opportunity_flag
FROM with_opportunity_score;
GO

-- Indexes
CREATE INDEX idx_market_gap_opportunity ON gold.market_gap_analysis(opportunity_score DESC);
CREATE INDEX idx_market_gap_action ON gold.market_gap_analysis(recommended_action);
CREATE INDEX idx_market_gap_underserved ON gold.market_gap_analysis(underserved_flag);
CREATE INDEX idx_market_gap_county ON gold.market_gap_analysis(county_name);
GO

/*
README: gold.market_gap_analysis
PURPOSE: Identify underserved markets and quantify expansion opportunities
KEY METRICS:
- opportunity_score (0-100): Overall expansion opportunity
- store_coverage_gap: Stores needed to reach target density
- customer_penetration_gap: Potential new customers
- revenue_opportunity_kes: Untapped revenue potential
- recommended_action: Strategic recommendation

BUSINESS QUESTIONS ANSWERED:
1. Which counties are most underserved? (high opportunity_score)
2. How many new stores does each county need? (estimated_new_stores_needed)
3. Where is competition low but demand high? (competitive_intensity = 'Low')
4. Which counties are saturated? (overserved_flag = 1)
5. What is the total revenue opportunity? (revenue_opportunity_kes)

SAMPLE QUERIES:
-- Top 10 underserved counties
SELECT TOP 10 county_name, opportunity_score, recommended_action, estimated_new_stores_needed, revenue_opportunity_kes
FROM gold.market_gap_analysis 
WHERE underserved_flag = 1
ORDER BY opportunity_score DESC;

-- Revenue opportunity by county
SELECT county_name, current_revenue_kes, estimated_market_potential_kes, revenue_opportunity_kes,
       (revenue_opportunity_kes / estimated_market_potential_kes * 100) as opportunity_percentage
FROM gold.market_gap_analysis
WHERE revenue_opportunity_kes > 0
ORDER BY revenue_opportunity_kes DESC;

-- Market saturation analysis
SELECT competitive_intensity, 
       AVG(market_saturation) as avg_saturation,
       COUNT(*) as county_count,
       SUM(CASE WHEN overserved_flag = 1 THEN 1 ELSE 0 END) as overserved_counties
FROM gold.market_gap_analysis
GROUP BY competitive_intensity
ORDER BY avg_saturation DESC;

-- Expansion planning summary
SELECT recommended_action, 
       COUNT(*) as county_count,
       SUM(estimated_new_stores_needed) as total_new_stores_needed,
       SUM(revenue_opportunity_kes) as total_revenue_opportunity
FROM gold.market_gap_analysis
GROUP BY recommended_action
ORDER BY total_revenue_opportunity DESC;
===============================================================================
*/
select * from gold.market_gap_analysis
