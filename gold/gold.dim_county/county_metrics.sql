IF OBJECT_ID('gold.dim_county', 'U') IS NOT NULL
    DROP TABLE gold.dim_county;
GO

-- Create the table with explicit data types
CREATE TABLE gold.dim_county (
    county_id NVARCHAR(50) PRIMARY KEY,
    county_name NVARCHAR(100),
    population_2023 INT,
    population_density_psqkm DECIMAL(10,2),
    urbanization_rate DECIMAL(5,2),
    avg_household_income_kes DECIMAL(12,2),
    unemployment_rate DECIMAL(5,2),
    inflation_rate DECIMAL(5,2),
    retail_sales_index DECIMAL(10,2),
    road_infrastructure_score DECIMAL(5,2),
    internet_penetration DECIMAL(5,2),
    public_transport_score DECIMAL(5,2),
    infrastructure_score DECIMAL(5,2),
    total_customers INT,
    avg_customer_value_score DECIMAL(5,2),
    high_value_customer_ratio DECIMAL(5,2),
    churn_risk_ratio DECIMAL(5,2),
    store_count INT,
    competitor_density INT,
    store_density DECIMAL(10,4),
    market_saturation DECIMAL(10,4),
    market_attractiveness_score DECIMAL(5,2),
    expansion_readiness_score DECIMAL(5,2),
    risk_score DECIMAL(5,2),
    final_location_score DECIMAL(5,2),
    expansion_priority NVARCHAR(10),
    premium_store_viable BIT,
    risk_flag BIT
);
GO

WITH customer_metrics AS (
    SELECT
        primary_county,
        COUNT(DISTINCT customer_id) AS total_customers,
        AVG(TRY_CAST(customer_value_score AS DECIMAL(5,2))) AS avg_customer_value_score,
        AVG(CASE WHEN TRY_CAST(customer_value_score AS DECIMAL(5,2)) >= 70 THEN 1.0 ELSE 0.0 END)
            AS high_value_customer_ratio,
        AVG(CASE WHEN TRY_CAST(churn_risk_flag AS DECIMAL(5,2)) >= 70 THEN 1.0 ELSE 0.0 END)
            AS churn_risk_ratio
    FROM gold.customer_value
    WHERE customer_id IS NOT NULL 
        AND TRY_CAST(customer_value_score AS DECIMAL(5,2)) IS NOT NULL
    GROUP BY primary_county
),
store_metrics AS (
    SELECT
        county,
        COUNT(*) AS store_count
    FROM silver.stores
    WHERE county IS NOT NULL AND county <> ''
    GROUP BY county
),
competitor_metrics AS (
    SELECT
        county,
        COUNT(*) AS competitor_density
    FROM silver.competitor_stores
    WHERE county IS NOT NULL AND county <> ''
    GROUP BY county
),
-- Deduplicate economic data (this is likely where duplicates come from)
deduplicated_economic AS (
    SELECT 
        county,
        AVG(TRY_CAST(unemployment_rate AS DECIMAL(5,2))) AS unemployment_rate,
        AVG(TRY_CAST(inflation_rate AS DECIMAL(5,2))) AS inflation_rate,
        AVG(TRY_CAST(retail_sales_index AS DECIMAL(10,2))) AS retail_sales_index
    FROM silver.economic
    WHERE county IS NOT NULL AND county <> ''
    GROUP BY county
),
base_data AS (
    SELECT DISTINCT
        TRY_CAST(gc.county_id AS NVARCHAR(50)) AS county_id,
        gc.county_name,
        gc.population_2023,
        gc.population_density_psqkm,
        gc.urbanization_rate,
        gc.avg_household_income_kes,
        gc.road_infrastructure_score,
        gc.internet_penetration,
        gc.public_transport_score
    FROM silver.gis_counties gc
    WHERE gc.county_id IS NOT NULL 
        AND gc.population_2023 > 0
        AND gc.county_name IS NOT NULL
),
joined_data AS (
    SELECT
        bd.county_id,
        bd.county_name,
        bd.population_2023,
        bd.population_density_psqkm,
        bd.urbanization_rate,
        bd.avg_household_income_kes,
        COALESCE(de.unemployment_rate, 0) AS unemployment_rate,
        COALESCE(de.inflation_rate, 0) AS inflation_rate,
        COALESCE(de.retail_sales_index, 0) AS retail_sales_index,
        TRY_CAST(bd.road_infrastructure_score AS DECIMAL(5,2)) AS road_infrastructure_score,
        TRY_CAST(bd.internet_penetration AS DECIMAL(5,2)) AS internet_penetration,
        TRY_CAST(bd.public_transport_score AS DECIMAL(5,2)) AS public_transport_score,
        COALESCE(cm.total_customers, 0) AS total_customers,
        COALESCE(cm.avg_customer_value_score, 0) AS avg_customer_value_score,
        COALESCE(cm.high_value_customer_ratio, 0) AS high_value_customer_ratio,
        COALESCE(cm.churn_risk_ratio, 0) AS churn_risk_ratio,
        COALESCE(sm.store_count, 0) AS store_count,
        COALESCE(cp.competitor_density, 0) AS competitor_density
    FROM base_data bd
    LEFT JOIN deduplicated_economic de
        ON bd.county_name = de.county
    LEFT JOIN customer_metrics cm
        ON bd.county_name = cm.primary_county
    LEFT JOIN store_metrics sm
        ON bd.county_name = sm.county
    LEFT JOIN competitor_metrics cp
        ON bd.county_name = cp.county
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
                 public_transport_score * 0.3)
            ELSE 0
        END AS infrastructure_score,
        
        -- Market Attractiveness Score (normalized to 0-100)
        (
            -- Population density normalized (assuming max 5000 per sqkm)
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
                      public_transport_score * 0.3)
                ELSE 0
            END * 0.6 +
            
            -- Urbanization component (0-100)
            urbanization_rate * 0.4
        ) AS expansion_readiness_score,
        
        -- Risk Score (0-100, higher = more risk)
        (
            -- Inflation risk (0-100, assuming max 50% inflation = 100 score)
            CASE WHEN inflation_rate > 50 THEN 100 
                 ELSE inflation_rate * 2.0 
            END * 0.5 +
            
            -- Unemployment risk (0-100, assuming max 50% unemployment = 100 score)
            CASE WHEN unemployment_rate > 50 THEN 100 
                 ELSE unemployment_rate * 2.0 
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
    population_2023,
    population_density_psqkm,
    urbanization_rate,
    avg_household_income_kes,
    unemployment_rate,
    inflation_rate,
    retail_sales_index,
    road_infrastructure_score,
    internet_penetration,
    public_transport_score,
    infrastructure_score,
    total_customers,
    avg_customer_value_score,
    high_value_customer_ratio,
    churn_risk_ratio,
    store_count,
    competitor_density,
    store_density,
    market_saturation,
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
        WHEN inflation_rate > 10 OR unemployment_rate > 12
        THEN 1 ELSE 0
    END AS risk_flag
FROM calculated_metrics;
GO

-- Create indexes for performance
CREATE INDEX idx_dim_county_name ON gold.dim_county(county_name);
CREATE INDEX idx_dim_expansion_priority ON gold.dim_county(expansion_priority);
CREATE INDEX idx_dim_final_location_score ON gold.dim_county(final_location_score DESC);
CREATE INDEX idx_dim_market_attractiveness ON gold.dim_county(market_attractiveness_score DESC);
CREATE INDEX idx_dim_risk_flag ON gold.dim_county(risk_flag);
CREATE INDEX idx_dim_store_density ON gold.dim_county(store_density DESC);
CREATE INDEX idx_dim_market_saturation ON gold.dim_county(market_saturation);
GO

-- Add a comment documenting the weighting logic
EXEC sys.sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'County dimension table with composite scores for expansion analysis.
    
Scoring Methodology:
1. Market Attractiveness Score (40% weight in final score):
   - Population Density: 25% (normalized: 5000/sqkm = 100)
   - Urbanization Rate: 25% (0-100 scale)
   - Average Household Income: 25% (normalized: KES 200,000 = 100)
   - Customer Value Score: 25% (0-100 scale)

2. Expansion Readiness Score (40% weight in final score):
   - Infrastructure: 60% (Roads 40%, Internet 30%, Transport 30%)
   - Urbanization Rate: 40% (0-100 scale)

3. Risk Score (20% weight in final score, subtracted):
   - Inflation Rate: 50% (normalized: 50% = 100)
   - Unemployment Rate: 30% (normalized: 50% = 100)
   - Churn Risk Ratio: 20% (0-100 scale)

4. Final Location Score = (Market Attractiveness * 0.4) + (Expansion Readiness * 0.4) - (Risk Score * 0.2)
    
All scores normalized to 0-100 scale where higher is better (except Risk Score where higher is worse).',
    @level0type = N'SCHEMA', @level0name = N'gold',
    @level1type = N'TABLE', @level1name = N'dim_county';
GO

-- Add comments for key columns
EXEC sys.sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Composite score (0-100) evaluating county suitability for expansion. Higher scores indicate better locations.',
    @level0type = N'SCHEMA', @level0name = N'gold',
    @level1type = N'TABLE', @level1name = N'dim_county',
    @level2type = N'COLUMN', @level2name = N'final_location_score';

EXEC sys.sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Number of competitor stores per existing store. Values > 3 indicate high market saturation.',
    @level0type = N'SCHEMA', @level0name = N'gold',
    @level1type = N'TABLE', @level1name = N'dim_county',
    @level2type = N'COLUMN', @level2name = N'market_saturation';
GO

-- Diagnostic query to check for duplicates
PRINT 'Checking for duplicates in source tables...';
GO

SELECT 'silver.economic duplicates:' AS TableName, county, COUNT(*) as DuplicateCount
FROM silver.economic
WHERE county IS NOT NULL
GROUP BY county
HAVING COUNT(*) > 1
UNION ALL
SELECT 'silver.gis_counties duplicates:' AS TableName, county_id, COUNT(*) as DuplicateCount
FROM silver.gis_counties
WHERE county_id IS NOT NULL
GROUP BY county_id
HAVING COUNT(*) > 1
UNION ALL
SELECT 'gold.customer_value duplicates:' AS TableName, primary_county, COUNT(*) as DuplicateCount
FROM gold.customer_value
WHERE primary_county IS NOT NULL
GROUP BY primary_county
HAVING COUNT(*) > 1;
GO
