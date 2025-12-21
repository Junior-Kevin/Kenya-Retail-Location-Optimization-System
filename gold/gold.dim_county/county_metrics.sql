
IF OBJECT_ID('gold.dim_county', 'U') IS NOT NULL
    DROP TABLE gold.dim_county;
GO

-- Create the county dimension table
CREATE TABLE gold.dim_county (
    county_id NVARCHAR(50) PRIMARY KEY,
    county_name NVARCHAR(100),
    
    -- Demographics
    population_2023 INT,
    population_density_psqkm DECIMAL(10,2),
    urbanization_rate DECIMAL(5,2),
    poverty_rate DECIMAL(5,2),
    literacy_rate DECIMAL(5,2),
    
    -- Economy (latest values)
    avg_household_income_kes DECIMAL(12,2),
    latest_unemployment_rate DECIMAL(5,2),
    latest_inflation_rate DECIMAL(5,2),
    latest_gdp_growth_rate DECIMAL(5,2),
    latest_retail_sales_index DECIMAL(5,2),
    latest_consumer_confidence_index DECIMAL(5,2),
    
    -- Infrastructure
    road_infrastructure_score DECIMAL(5,2),
    internet_penetration DECIMAL(5,2),
    public_transport_score DECIMAL(5,2),
    commercial_rent_kes_psqm DECIMAL(10,2),
    business_registration_days INT,
    security_index DECIMAL(5,2),
    
    -- Customer metrics
    total_customers INT,
    avg_customer_value_score DECIMAL(5,2),
    high_value_customer_ratio DECIMAL(5,2),
    churn_risk_ratio DECIMAL(5,2),
    
    -- Store metrics
    store_count INT,
    competitor_density INT,
    store_density DECIMAL(10,4),
    market_saturation DECIMAL(10,4),
    
    -- Composite scores
    infrastructure_score DECIMAL(5,2),
    market_attractiveness_score DECIMAL(5,2),
    expansion_readiness_score DECIMAL(5,2),
    risk_score DECIMAL(5,2),
    final_location_score DECIMAL(5,2),
    
    -- Decision flags
    expansion_priority NVARCHAR(10),
    premium_store_viable BIT,
    risk_flag BIT,
    
    -- Geographic info
    latitude DECIMAL(10,6),
    longitude DECIMAL(10,6),
    major_towns NVARCHAR(500)
);
GO

WITH customer_metrics AS (
    SELECT
        cv.primary_county,
        COUNT(DISTINCT cv.customer_id) AS total_customers,
        AVG(cv.customer_value_score) AS avg_customer_value_score,
        AVG(CASE WHEN cv.customer_value_score >= 70 THEN 1.0 ELSE 0.0 END) AS high_value_customer_ratio,
        AVG(CASE WHEN cv.churn_risk_flag = 1 THEN 1.0 ELSE 0.0 END) AS churn_risk_ratio
    FROM gold.customer_value cv
    WHERE cv.primary_county IS NOT NULL
    GROUP BY cv.primary_county
),
store_metrics AS (
    SELECT
        UPPER(LTRIM(RTRIM(county))) AS county,
        COUNT(*) AS store_count
    FROM silver.stores
    WHERE county IS NOT NULL AND county <> ''
    GROUP BY UPPER(LTRIM(RTRIM(county)))
),
competitor_metrics AS (
    SELECT
        UPPER(LTRIM(RTRIM(county))) AS county,
        COUNT(*) AS competitor_density
    FROM silver.competitor_stores
    WHERE county IS NOT NULL AND county <> ''
    GROUP BY UPPER(LTRIM(RTRIM(county)))
),
-- Get the LATEST economic data for each county
latest_economic AS (
    SELECT 
        UPPER(LTRIM(RTRIM(county))) AS county,
        inflation_rate,
        unemployment_rate,
        retail_sales_index,
        consumer_confidence_index,
        gdp_growth_rate,
        ROW_NUMBER() OVER (PARTITION BY UPPER(LTRIM(RTRIM(county))) ORDER BY year_month DESC) AS recency_rank
    FROM silver.economic
    WHERE county IS NOT NULL
),
county_base AS (
    SELECT DISTINCT
        gc.county_id,
        UPPER(LTRIM(RTRIM(gc.county_name))) AS county_name,
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
    WHERE gc.county_id IS NOT NULL 
        AND gc.population_2023 > 0
        AND gc.county_name IS NOT NULL
),
joined_data AS (
    SELECT
        cb.county_id,
        cb.county_name,
        cb.population_2023,
        cb.population_density_psqkm,
        cb.urbanization_rate,
        cb.poverty_rate,
        cb.literacy_rate,
        cb.avg_household_income_kes,
        le.inflation_rate AS latest_inflation_rate,
        le.unemployment_rate AS latest_unemployment_rate,
        le.retail_sales_index AS latest_retail_sales_index,
        le.consumer_confidence_index AS latest_consumer_confidence_index,
        le.gdp_growth_rate AS latest_gdp_growth_rate,
        cb.road_infrastructure_score,
        cb.internet_penetration,
        cb.public_transport_score,
        cb.commercial_rent_kes_psqm,
        cb.business_registration_days,
        cb.security_index,
        cb.latitude,
        cb.longitude,
        cb.major_towns,
        COALESCE(cm.total_customers, 0) AS total_customers,
        COALESCE(cm.avg_customer_value_score, 0) AS avg_customer_value_score,
        COALESCE(cm.high_value_customer_ratio, 0) AS high_value_customer_ratio,
        COALESCE(cm.churn_risk_ratio, 0) AS churn_risk_ratio,
        COALESCE(sm.store_count, 0) AS store_count,
        COALESCE(cp.competitor_density, 0) AS competitor_density
    FROM county_base cb
    LEFT JOIN latest_economic le
        ON cb.county_name = le.county AND le.recency_rank = 1
    LEFT JOIN customer_metrics cm
        ON cb.county_name = UPPER(LTRIM(RTRIM(cm.primary_county)))
    LEFT JOIN store_metrics sm
        ON cb.county_name = sm.county
    LEFT JOIN competitor_metrics cp
        ON cb.county_name = cp.county
),
calculated_metrics AS (
    SELECT
        *,
        -- Store density (stores per 100k population)
        CASE 
            WHEN population_2023 > 0 
            THEN CAST(store_count AS DECIMAL(18,4)) * 100000 / population_2023
            ELSE 0 
        END AS store_density,
        
        -- Market saturation (competitors per store)
        CASE 
            WHEN store_count > 0 
            THEN CAST(competitor_density AS DECIMAL(18,4)) / store_count
            WHEN competitor_density > 0 
            THEN CAST(competitor_density AS DECIMAL(18,4))
            ELSE 0 
        END AS market_saturation,
        
        -- Infrastructure Score (normalized to 0-100)
        CASE 
            WHEN road_infrastructure_score IS NOT NULL 
                AND internet_penetration IS NOT NULL 
                AND public_transport_score IS NOT NULL
            THEN 
                (road_infrastructure_score * 0.4 +
                 internet_penetration * 0.3 +
                 public_transport_score * 0.3) * 10
            ELSE 0
        END AS infrastructure_score,
        
        -- Market Attractiveness Score (normalized to 0-100)
        (
            -- Population density normalized (assuming max 5000 per sqkm = 100)
            CASE WHEN population_density_psqkm > 5000 THEN 100 
                 ELSE population_density_psqkm / 50.0 
            END * 0.25 +
            
            -- Urbanization rate (already 0-100 scale)
            urbanization_rate * 0.25 +
            
            -- Income normalized (KES 200,000 = 100 score)
            CASE WHEN avg_household_income_kes > 200000 THEN 100
                 ELSE avg_household_income_kes / 2000.0 
            END * 0.25 +
            
            -- Customer value score (already 0-100 scale)
            avg_customer_value_score * 0.25
        ) AS market_attractiveness_score,
        
        -- Expansion Readiness Score (normalized to 0-100)
        (
            -- Infrastructure component (0-100)
            CASE 
                WHEN road_infrastructure_score IS NOT NULL 
                    AND internet_penetration IS NOT NULL 
                    AND public_transport_score IS NOT NULL
                THEN (road_infrastructure_score * 0.4 +
                      internet_penetration * 0.3 +
                      public_transport_score * 0.3) * 10
                ELSE 0
            END * 0.6 +
            
            -- Urbanization component (0-100)
            urbanization_rate * 0.4
        ) AS expansion_readiness_score,
        
        -- Risk Score (0-100, higher = more risk)
        (
            -- Inflation risk (0-100, assuming max 50% inflation = 100 score)
            CASE WHEN latest_inflation_rate > 50 THEN 100 
                 ELSE latest_inflation_rate * 2.0 
            END * 0.5 +
            
            -- Unemployment risk (0-100, assuming max 50% unemployment = 100 score)
            CASE WHEN latest_unemployment_rate > 50 THEN 100 
                 ELSE latest_unemployment_rate * 2.0 
            END * 0.3 +
            
            -- Churn risk (0-100)
            churn_risk_ratio * 100 * 0.2
        ) AS risk_score
    FROM joined_data
)

INSERT INTO gold.dim_county
SELECT
    county_id,
    county_name,
    
    -- Demographics
    population_2023,
    population_density_psqkm,
    urbanization_rate,
    poverty_rate,
    literacy_rate,
    
    -- Economy (latest values)
    avg_household_income_kes,
    latest_unemployment_rate,
    latest_inflation_rate,
    latest_gdp_growth_rate,
    latest_retail_sales_index,
    latest_consumer_confidence_index,
    
    -- Infrastructure
    road_infrastructure_score,
    internet_penetration,
    public_transport_score,
    commercial_rent_kes_psqm,
    business_registration_days,
    security_index,
    
    -- Customer metrics
    total_customers,
    avg_customer_value_score,
    high_value_customer_ratio,
    churn_risk_ratio,
    
    -- Store metrics
    store_count,
    competitor_density,
    store_density,
    market_saturation,
    
    -- Composite scores
    infrastructure_score,
    market_attractiveness_score,
    expansion_readiness_score,
    risk_score,
    
    -- Final Location Score (normalized to 0-100)
    (
        -- Positive factors (weighted 80%)
        (
            -- Market attractiveness component (40% of total)
            market_attractiveness_score * 0.4 +
            
            -- Expansion readiness component (40% of total)
            expansion_readiness_score * 0.4
        ) -
        
        -- Negative factors (risk, weighted 20%)
        (risk_score * 0.2)
    ) AS final_location_score,
    
    -- Decision Flags
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
    
    -- Geographic info
    latitude,
    longitude,
    major_towns
FROM calculated_metrics;
GO
SELECT * FROM gold.dim_county
