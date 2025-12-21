-- DROP TABLE IF EXISTS gold.competitive_intensity;
-- GO

/*
===============================================================================
TABLE: gold.competitive_intensity
PURPOSE: Quantify competitive pressure and identify market entry barriers
BUSINESS QUESTIONS ANSWERED:
1. Where is the market saturated?
2. Which counties are under-served?
3. Who are the dominant competitors by region?
4. Where would new stores face aggressive competition?
===============================================================================
*/
IF OBJECT_ID('gold.competitive_intensity', 'U') IS NOT NULL
    DROP TABLE gold.competitive_intensity;
GO

CREATE TABLE gold.competitive_intensity (
    county_name NVARCHAR(100) PRIMARY KEY,
    
    -- Market structure
    total_stores INT,               -- Our stores + competitors
    our_store_count INT,
    competitor_store_count INT,
    market_share_percentage DECIMAL(5,2),
    
    -- Density metrics
    population INT,
    stores_per_100k DECIMAL(10,4),
    competitors_per_100k DECIMAL(10,4),
    
    -- Concentration metrics
    herfindahl_index DECIMAL(5,4),  -- Market concentration (0-1, higher = more concentrated)
    top_3_competitors NVARCHAR(500),
    avg_competitor_size DECIMAL(10,2),
    
    -- Competitive pressure
    competitive_intensity_score DECIMAL(5,2),  -- 0-100, higher = more competitive
    competitive_intensity_level NVARCHAR(20),  -- Low, Moderate, High, Very High
    entry_barrier_score DECIMAL(5,2),          -- 0-100, higher = harder to enter
    
    -- Strategic insights
    recommended_strategy NVARCHAR(100),
    pricing_pressure_level NVARCHAR(20),       -- Low, Medium, High
    market_growth_potential DECIMAL(5,2),
    
    -- Flags
    saturated_market_flag BIT,
    underserved_market_flag BIT,
    dominant_position_flag BIT
);
GO

WITH competitor_analysis AS (
    SELECT
        cs.county,
        c.competitor_name,
        c.competitor_type,
        COUNT(cs.store_id) AS store_count,
        AVG(cs.store_size_sqm) AS avg_size,
        AVG(cs.estimated_monthly_revenue_kes) AS avg_revenue
    FROM silver.competitor_stores cs
    INNER JOIN silver.competitors c ON cs.competitor_id = c.competitor_id
    WHERE cs.county IS NOT NULL
    GROUP BY cs.county, c.competitor_name, c.competitor_type
),
county_competition AS (
    SELECT
        ca.county,
        COUNT(DISTINCT ca.competitor_name) AS distinct_competitors,
        SUM(ca.store_count) AS competitor_store_count,
        AVG(ca.avg_size) AS avg_competitor_size,
        STRING_AGG(ca.competitor_name + ' (' + CAST(ca.store_count AS NVARCHAR) + ')', ', ') 
            WITHIN GROUP (ORDER BY ca.store_count DESC) AS competitor_list
    FROM competitor_analysis ca
    GROUP BY ca.county
),
market_structure AS (
    SELECT
        dc.county_name,
        dc.population_2023 AS population,
        dc.store_count AS our_store_count,
        COALESCE(cc.competitor_store_count, 0) AS competitor_store_count,
        dc.store_count + COALESCE(cc.competitor_store_count, 0) AS total_stores,
        
        -- Market share (ensure it doesn't exceed 100)
        CASE 
            WHEN (dc.store_count + COALESCE(cc.competitor_store_count, 0)) > 0
            THEN CAST((dc.store_count * 100.0) / (dc.store_count + COALESCE(cc.competitor_store_count, 0)) AS DECIMAL(5,2))
            ELSE CAST(0 AS DECIMAL(5,2))
        END AS market_share_percentage,
        
        -- Density metrics (cap at reasonable values)
        CASE WHEN dc.population_2023 > 0 
             THEN CAST((dc.store_count * 100000.0) / dc.population_2023 AS DECIMAL(10,4))
             ELSE CAST(0 AS DECIMAL(10,4))
        END AS our_stores_per_100k,
        
        CASE WHEN dc.population_2023 > 0 
             THEN CAST((COALESCE(cc.competitor_store_count, 0) * 100000.0) / dc.population_2023 AS DECIMAL(10,4))
             ELSE CAST(0 AS DECIMAL(10,4))
        END AS competitors_per_100k,
        
        -- Top competitors (limit to top 3)
        COALESCE(cc.competitor_list, 'No Competitors') AS top_competitors,
        CAST(COALESCE(cc.avg_competitor_size, 0) AS DECIMAL(10,2)) AS avg_competitor_size,
        COALESCE(cc.distinct_competitors, 0) AS distinct_competitors
    FROM gold.dim_county dc
    LEFT JOIN county_competition cc ON dc.county_name = cc.county
),
calculated AS (
    SELECT
        ms.county_name,
        ms.population,
        ms.our_store_count,
        ms.competitor_store_count,
        ms.total_stores,
        ms.market_share_percentage,
        ms.our_stores_per_100k,
        ms.competitors_per_100k,
        ms.top_competitors,
        ms.avg_competitor_size,
        ms.distinct_competitors,
        
        -- Herfindahl Index (market concentration) with overflow protection
        CAST(
            POWER(CAST(ms.market_share_percentage/100.0 AS DECIMAL(10,4)), 2) + 
            CASE WHEN ms.competitor_store_count > 0 
                 THEN POWER(CAST((100.0 - ms.market_share_percentage)/100.0 AS DECIMAL(10,4)), 2) / ms.competitor_store_count 
                 ELSE 0 
            END AS DECIMAL(5,4)
        ) AS herfindahl_index,
        
        -- Competitive Intensity Score components (capped)
        -- Competitor density component (max 30 points)
        CASE WHEN ms.competitors_per_100k > 100 THEN 30.0
             ELSE (ms.competitors_per_100k / 100.0) * 30.0 
        END AS density_component,
        
        -- Number of competitors component (max 20 points)
        CASE WHEN ms.distinct_competitors > 10 THEN 20.0
             ELSE ms.distinct_competitors * 2.0 
        END AS competitor_count_component,
        
        -- Competitor size component (max 10 points)
        CASE 
            WHEN ms.avg_competitor_size > 300 THEN 10.0
            WHEN ms.avg_competitor_size > 200 THEN 6.0
            WHEN ms.avg_competitor_size > 100 THEN 3.0
            ELSE 0.0
        END AS size_component,
        
        -- Market share component (max 30 points)
        CASE 
            WHEN ms.market_share_percentage < 30 THEN 30.0
            WHEN ms.market_share_percentage < 50 THEN 20.0
            WHEN ms.market_share_percentage < 70 THEN 10.0
            ELSE 0.0
        END AS market_share_component
    FROM market_structure ms
),
with_intensity_score AS (
    SELECT *,
        -- Total Competitive Intensity Score (0-100)
        CAST(
            density_component + 
            competitor_count_component + 
            size_component + 
            market_share_component AS DECIMAL(5,2)
        ) AS competitive_intensity_score
    FROM calculated
)

INSERT INTO gold.competitive_intensity
SELECT
    county_name,
    total_stores,
    our_store_count,
    competitor_store_count,
    market_share_percentage,
    population,
    our_stores_per_100k + competitors_per_100k AS stores_per_100k,
    competitors_per_100k,
    herfindahl_index,
    top_competitors AS top_3_competitors,
    avg_competitor_size,
    competitive_intensity_score,
    
    -- Competitive intensity level
    CASE 
        WHEN competitive_intensity_score > 80 THEN 'Very High'
        WHEN competitive_intensity_score > 60 THEN 'High'
        WHEN competitive_intensity_score > 40 THEN 'Moderate'
        ELSE 'Low'
    END AS competitive_intensity_level,
    
    -- Entry barrier score (0-100, higher = harder to enter)
    CAST(
        (competitive_intensity_score * 0.6 + herfindahl_index * 100 * 0.4) AS DECIMAL(5,2)
    ) AS entry_barrier_score,
    
    -- Strategic recommendations
    CASE 
        WHEN competitive_intensity_score > 80 THEN 'Avoid - High Competition'
        WHEN competitive_intensity_score > 60 AND market_share_percentage < 20 THEN 'Defend - Strong Competition'
        WHEN competitive_intensity_score > 40 AND market_share_percentage > 50 THEN 'Expand - Dominant Position'
        WHEN competitive_intensity_score < 40 AND market_share_percentage < 30 THEN 'Enter - Low Competition'
        WHEN competitor_store_count = 0 THEN 'Aggressive Expansion - No Competition'
        ELSE 'Selective Growth'
    END AS recommended_strategy,
    
    -- Pricing pressure
    CASE 
        WHEN competitive_intensity_score > 70 THEN 'High'
        WHEN competitive_intensity_score > 50 THEN 'Medium'
        ELSE 'Low'
    END AS pricing_pressure_level,
    
    -- Market growth potential (inverse of saturation)
    CAST(100 - competitive_intensity_score AS DECIMAL(5,2)) AS market_growth_potential,
    
    -- Flags
    CASE WHEN competitive_intensity_score > 70 THEN 1 ELSE 0 END AS saturated_market_flag,
    CASE WHEN competitor_store_count = 0 AND population > 50000 THEN 1 ELSE 0 END AS underserved_market_flag,
    CASE WHEN market_share_percentage > 50 THEN 1 ELSE 0 END AS dominant_position_flag
FROM with_intensity_score;
GO

-- Indexes
CREATE INDEX idx_competitive_intensity_score ON gold.competitive_intensity(competitive_intensity_score DESC);
CREATE INDEX idx_competitive_intensity_level ON gold.competitive_intensity(competitive_intensity_level);
CREATE INDEX idx_competitive_saturated ON gold.competitive_intensity(saturated_market_flag);
CREATE INDEX idx_competitive_strategy ON gold.competitive_intensity(recommended_strategy);
GO

/*
README: gold.competitive_intensity
PURPOSE: Analyze competitive landscape and market entry barriers
KEY METRICS:
- competitive_intensity_score (0-100): Overall competitive pressure
- competitive_intensity_level: Low, Moderate, High, Very High
- entry_barrier_score (0-100): Difficulty of market entry
- herfindahl_index: Market concentration (0-1)
- market_share_percentage: Our share of total stores

BUSINESS QUESTIONS ANSWERED:
1. Which counties have the toughest competition? (high competitive_intensity_score)
2. Where can we enter easily? (low entry_barrier_score)
3. Where do we have dominant market positions? (dominant_position_flag = 1)
4. Which markets are saturated? (saturated_market_flag = 1)
5. Who are our main competitors in each county? (top_3_competitors)

SAMPLE QUERIES:
-- Top 10 most competitive counties
SELECT TOP 10 county_name, competitive_intensity_level, competitive_intensity_score, 
       market_share_percentage, total_stores
FROM gold.competitive_intensity 
ORDER BY competitive_intensity_score DESC;

-- Easy entry opportunities
SELECT county_name, competitive_intensity_level, entry_barrier_score, population
FROM gold.competitive_intensity
WHERE underserved_market_flag = 1 OR competitive_intensity_level = 'Low'
ORDER BY entry_barrier_score;

-- Market concentration analysis
SELECT 
    CASE 
        WHEN herfindahl_index > 0.6 THEN 'Highly Concentrated'
        WHEN herfindahl_index > 0.4 THEN 'Moderately Concentrated'
        WHEN herfindahl_index > 0.2 THEN 'Somewhat Concentrated'
        ELSE 'Fragmented'
    END as concentration_level,
    COUNT(*) as county_count,
    AVG(market_share_percentage) as avg_market_share
FROM gold.competitive_intensity
GROUP BY 
    CASE 
        WHEN herfindahl_index > 0.6 THEN 'Highly Concentrated'
        WHEN herfindahl_index > 0.4 THEN 'Moderately Concentrated'
        WHEN herfindahl_index > 0.2 THEN 'Somewhat Concentrated'
        ELSE 'Fragmented'
    END
ORDER BY avg_market_share DESC;

-- Strategic recommendations summary
SELECT recommended_strategy, 
       COUNT(*) as county_count,
       AVG(competitive_intensity_score) as avg_intensity,
       AVG(market_share_percentage) as avg_market_share
FROM gold.competitive_intensity
GROUP BY recommended_strategy
ORDER BY county_count DESC;
===============================================================================
*/
select * from gold.competitive_intensity
