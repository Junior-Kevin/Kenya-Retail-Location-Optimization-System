-- DROP TABLE IF EXISTS gold.dim_county;
-- GO

/*
===============================================================================
TABLE: gold.dim_county
PURPOSE: Single source of truth for county attractiveness and expansion potential
BUSINESS QUESTIONS ANSWERED:
1. Which counties have the highest retail demand potential?
2. Where does population density justify large-format stores?
3. Which counties have strong income fundamentals?
4. Where is infrastructure strong enough for scale?
5. Which counties are resilient to inflation/unemployment?
===============================================================================
*/
IF OBJECT_ID('gold.dim_county', 'U') IS NOT NULL
    DROP TABLE gold.dim_county;
GO

CREATE TABLE gold.dim_county (
    county_id NVARCHAR(50) PRIMARY KEY,
    county_name NVARCHAR(100),
    
    -- Demographics
    population_2023 INT,
    population_density_psqkm DECIMAL(10,2),
    urbanization_rate DECIMAL(5,2),
    poverty_rate DECIMAL(5,2),
    literacy_rate DECIMAL(5,2),
    
    -- Economic indicators
    avg_household_income_kes DECIMAL(12,2),
    latest_unemployment_rate DECIMAL(5,2),
    latest_inflation_rate DECIMAL(5,2),
    latest_gdp_growth_rate DECIMAL(5,2),
    latest_retail_sales_index DECIMAL(5,2),
    
    -- Infrastructure
    road_infrastructure_score DECIMAL(5,2),
    internet_penetration DECIMAL(5,2),
    public_transport_score DECIMAL(5,2),
    commercial_rent_kes_psqm DECIMAL(10,2),
    business_registration_days INT,
    security_index DECIMAL(5,2),
    
    -- Customer base
    total_customers INT,
    avg_customer_value_score DECIMAL(5,2),
    high_value_customer_ratio DECIMAL(5,2),
    churn_risk_ratio DECIMAL(5,2),
    
    -- Retail landscape
    store_count INT,
    competitor_density INT,
    store_density DECIMAL(10,4),      -- stores per 100k population
    market_saturation DECIMAL(10,4),  -- competitors per store
    
    -- Composite scores (0-100)
    infrastructure_score DECIMAL(5,2),
    market_attractiveness_score DECIMAL(5,2),
    expansion_readiness_score DECIMAL(5,2),
    risk_score DECIMAL(5,2),
    final_location_score DECIMAL(5,2),
    
    -- Decision flags
    expansion_priority NVARCHAR(10),  -- High, Medium, Low
    premium_store_viable BIT,
    risk_flag BIT,
    
    -- Geographic
    latitude DECIMAL(10,6),
    longitude DECIMAL(10,6),
    major_towns NVARCHAR(500)
);
GO

WITH customer_metrics AS (
    SELECT
        primary_county,
        COUNT(*) AS total_customers,
        AVG(customer_value_score) AS avg_customer_value_score,
        AVG(CASE WHEN value_tier IN ('Platinum', 'Gold') THEN 1.0 ELSE 0.0 END) AS high_value_customer_ratio,
        AVG(CASE WHEN churn_risk_flag = 1 THEN 1.0 ELSE 0.0 END) AS churn_risk_ratio
    FROM gold.customer_value
    WHERE primary_county IS NOT NULL
    GROUP BY primary_county
),
store_metrics AS (
    SELECT
        county,
        COUNT(*) AS store_count
    FROM silver.stores
    WHERE county IS NOT NULL
    GROUP BY county
),
competitor_metrics AS (
    SELECT
        county,
        COUNT(*) AS competitor_density
    FROM silver.competitor_stores
    WHERE county IS NOT NULL
    GROUP BY county
),
latest_economic AS (
    SELECT 
        county,
        inflation_rate,
        unemployment_rate,
        retail_sales_index,
        gdp_growth_rate,
        ROW_NUMBER() OVER (PARTITION BY county ORDER BY year_month DESC) AS rn
    FROM silver.economic
    WHERE county IS NOT NULL
),
base_counties AS (
    SELECT DISTINCT
        gc.county_id,
        gc.county_name,
        gc.population_2023,
        gc.population_density_psqkm,
        gc.urbanization_rate,
        gc.poverty_rate,
        gc.literacy_rate,
        gc.avg_household_income_kes,
        gc.road_infrastructure_score,
        gc.internet_penetration,
        gc.public_transport_score,
        gc.commercial_rent_kes_psqm,
        gc.business_registration_days,
        gc.security_index,
        gc.latitude,
        gc.longitude,
        gc.major_towns
    FROM silver.gis_counties gc
),
joined_data AS (
    SELECT
        bc.county_id,
        bc.county_name,
        bc.population_2023,
        bc.population_density_psqkm,
        bc.urbanization_rate,
        bc.poverty_rate,
        bc.literacy_rate,
        bc.avg_household_income_kes,
        le.inflation_rate AS latest_inflation_rate,
        le.unemployment_rate AS latest_unemployment_rate,
        le.retail_sales_index AS latest_retail_sales_index,
        le.gdp_growth_rate AS latest_gdp_growth_rate,
        bc.road_infrastructure_score,
        bc.internet_penetration,
        bc.public_transport_score,
        bc.commercial_rent_kes_psqm,
        bc.business_registration_days,
        bc.security_index,
        bc.latitude,
        bc.longitude,
        bc.major_towns,
        COALESCE(cm.total_customers, 0) AS total_customers,
        COALESCE(cm.avg_customer_value_score, 0) AS avg_customer_value_score,
        COALESCE(cm.high_value_customer_ratio, 0) AS high_value_customer_ratio,
        COALESCE(cm.churn_risk_ratio, 0) AS churn_risk_ratio,
        COALESCE(sm.store_count, 0) AS store_count,
        COALESCE(cp.competitor_density, 0) AS competitor_density
    FROM base_counties bc
    LEFT JOIN latest_economic le ON bc.county_name = le.county AND le.rn = 1
    LEFT JOIN customer_metrics cm ON bc.county_name = cm.primary_county
    LEFT JOIN store_metrics sm ON bc.county_name = sm.county
    LEFT JOIN competitor_metrics cp ON bc.county_name = cp.county
),
calculated AS (
    SELECT *,
        -- Store density
        CASE WHEN population_2023 > 0 
             THEN CAST(store_count AS DECIMAL(18,4)) * 100000 / population_2023 
             ELSE 0 
        END AS store_density,
        
        -- Market saturation
        CASE WHEN store_count > 0 
             THEN CAST(competitor_density AS DECIMAL(18,4)) / store_count 
             ELSE 0 
        END AS market_saturation,
        
        -- Infrastructure Score (0-100)
        (road_infrastructure_score * 0.4 + internet_penetration * 0.3 + public_transport_score * 0.3) * 10 AS infrastructure_score,
        
        -- Market Attractiveness Score (0-100)
        (
            (population_density_psqkm / 50.0 * 0.25) + 
            (urbanization_rate * 0.25) + 
            (CASE WHEN avg_household_income_kes > 200000 THEN 100 
                  ELSE avg_household_income_kes / 2000.0 END * 0.25) + 
            (avg_customer_value_score * 0.25)
        ) AS market_attractiveness_score,
        
        -- Expansion Readiness Score (0-100)
        ((road_infrastructure_score * 0.4 + internet_penetration * 0.3 + public_transport_score * 0.3) * 10 * 0.6) + 
        (urbanization_rate * 0.4) AS expansion_readiness_score,
        
        -- Risk Score (0-100, higher = worse)
        (
            (latest_inflation_rate * 2.0 * 0.5) + 
            (latest_unemployment_rate * 2.0 * 0.3) + 
            (churn_risk_ratio * 100 * 0.2)
        ) AS risk_score
    FROM joined_data
)

INSERT INTO gold.dim_county
SELECT
    county_id,
    county_name,
    population_2023,
    population_density_psqkm,
    urbanization_rate,
    poverty_rate,
    literacy_rate,
    avg_household_income_kes,
    latest_unemployment_rate,
    latest_inflation_rate,
    latest_gdp_growth_rate,
    latest_retail_sales_index,
    road_infrastructure_score,
    internet_penetration,
    public_transport_score,
    commercial_rent_kes_psqm,
    business_registration_days,
    security_index,
    total_customers,
    avg_customer_value_score,
    high_value_customer_ratio,
    churn_risk_ratio,
    store_count,
    competitor_density,
    store_density,
    market_saturation,
    infrastructure_score,
    market_attractiveness_score,
    expansion_readiness_score,
    risk_score,
    
    -- Final Location Score (0-100)
    (market_attractiveness_score * 0.4 + expansion_readiness_score * 0.4 - risk_score * 0.2) AS final_location_score,
    
    -- Decision flags
    CASE 
        WHEN market_attractiveness_score > 70 THEN 'High'
        WHEN market_attractiveness_score BETWEEN 40 AND 70 THEN 'Medium'
        ELSE 'Low'
    END AS expansion_priority,
    
    CASE 
        WHEN avg_household_income_kes >= 80000 
             AND high_value_customer_ratio >= 0.25 
             AND market_saturation < 3 
        THEN 1 ELSE 0 
    END AS premium_store_viable,
    
    CASE 
        WHEN latest_inflation_rate > 10 OR latest_unemployment_rate > 12 
        THEN 1 ELSE 0 
    END AS risk_flag,
    
    latitude,
    longitude,
    major_towns
FROM calculated;
GO

-- Indexes
CREATE INDEX idx_county_location_score ON gold.dim_county(final_location_score DESC);
CREATE INDEX idx_county_expansion_priority ON gold.dim_county(expansion_priority);
CREATE INDEX idx_county_market_attractiveness ON gold.dim_county(market_attractiveness_score DESC);
CREATE INDEX idx_county_risk ON gold.dim_county(risk_flag);
GO

/*
README: gold.dim_county
PURPOSE: County-level master data for expansion planning and market analysis
KEY METRICS:
- final_location_score (0-100): Overall suitability for expansion
- market_attractiveness_score (0-100): Demand potential
- expansion_readiness_score (0-100): Infrastructure and operating environment
- risk_score (0-100): Economic vulnerability (higher = worse)

BUSINESS QUESTIONS ANSWERED:
1. Which counties should be prioritized for expansion? (final_location_score)
2. Where is infrastructure strong enough for large stores? (expansion_readiness_score)
3. Which counties have wealthy but underserved markets? (high income, low store_density)
4. Where are economic risks high? (risk_flag = 1)
5. Which counties can support premium stores? (premium_store_viable = 1)

SAMPLE QUERIES:
-- Top 10 counties for expansion
SELECT TOP 10 county_name, final_location_score, expansion_priority, store_count
FROM gold.dim_county 
ORDER BY final_location_score DESC;

-- Counties with high income but low competition
SELECT county_name, avg_household_income_kes, competitor_density, store_count
FROM gold.dim_county 
WHERE avg_household_income_kes > 100000 
  AND competitor_density < 5
ORDER BY avg_household_income_kes DESC;

-- Risk analysis by county
SELECT county_name, latest_inflation_rate, latest_unemployment_rate, risk_flag
FROM gold.dim_county 
WHERE risk_flag = 1
ORDER BY latest_inflation_rate DESC;

-- Infrastructure gaps analysis
SELECT county_name, infrastructure_score, road_infrastructure_score, 
       internet_penetration, public_transport_score
FROM gold.dim_county 
WHERE infrastructure_score < 50
ORDER BY infrastructure_score;
===============================================================================
*/
select * from gold.dim_county
