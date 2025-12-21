-- DROP TABLE IF EXISTS gold.location_scoring;
-- GO

/*
===============================================================================
TABLE: gold.location_scoring
PURPOSE: Score and rank potential store locations for expansion
BUSINESS QUESTIONS ANSWERED:
1. Which locations are top candidates for new stores?
2. Which locations combine traffic, visibility, and accessibility?
3. Where is competition manageable?
4. Which sites are infrastructure-ready?
===============================================================================
*/
IF OBJECT_ID('gold.location_scoring', 'U') IS NOT NULL
    DROP TABLE gold.location_scoring;
GO

CREATE TABLE gold.location_scoring (
    location_id NVARCHAR(50) PRIMARY KEY,
    county NVARCHAR(100),
    site_name NVARCHAR(200),
    latitude DECIMAL(10,6),
    longitude DECIMAL(10,6),
    
    -- Site characteristics
    visibility_score INT,
    accessibility_score INT,
    estimated_daily_traffic INT,
    parking_capacity INT,
    zoning NVARCHAR(100),
    property_size_sqm DECIMAL(10,2),
    building_condition NVARCHAR(50),
    competition_within_1km INT,
    complementary_businesses NVARCHAR(500),
    last_survey_date DATE,
    
    -- County context
    county_population INT,
    county_income_kes DECIMAL(12,2),
    county_unemployment_rate DECIMAL(5,2),
    county_store_count INT,
    county_competitor_density INT,
    county_market_score DECIMAL(5,2),
    
    -- Competition analysis
    nearby_competitors INT,
    avg_competitor_revenue DECIMAL(18,2),
    
    -- Composite scores (0-100)
    site_quality_score DECIMAL(5,2),
    market_potential_score DECIMAL(5,2),
    competition_score DECIMAL(5,2),  -- Higher = less competition
    overall_location_score DECIMAL(5,2),
    
    -- Recommendations
    recommendation NVARCHAR(20),  -- Recommended, Consider, Not Recommended
    suggested_store_format NVARCHAR(50),
    estimated_monthly_potential_kes DECIMAL(18,2),
    
    -- Flags
    quick_win_flag BIT,
    long_term_flag BIT,
    infrastructure_ready_flag BIT
);
GO

WITH location_base AS (
    SELECT
        gl.location_id,
        gl.county,
        gl.site_name,
        gl.latitude,
        gl.longitude,
        gl.visibility_score,
        gl.accessibility_score,
        gl.estimated_daily_traffic,
        gl.parking_capacity,
        gl.zoning,
        gl.property_size_sqm,
        gl.building_condition,
        gl.competition_within_1km,
        gl.complementary_businesses,
        gl.last_survey_date
    FROM silver.gis_locations gl
),
county_context AS (
    SELECT
        county_name,
        population_2023 AS county_population,
        avg_household_income_kes AS county_income_kes,
        latest_unemployment_rate AS county_unemployment_rate,
        store_count AS county_store_count,
        competitor_density AS county_competitor_density,
        market_attractiveness_score AS county_market_score
    FROM gold.dim_county
),
competition_analysis AS (
    SELECT
        gl.county,
        gl.location_id,
        COUNT(cs.store_id) AS nearby_competitors,
        AVG(cs.estimated_monthly_revenue_kes) AS avg_competitor_revenue
    FROM silver.gis_locations gl
    LEFT JOIN silver.competitor_stores cs ON gl.county = cs.county
    GROUP BY gl.county, gl.location_id
),
scoring AS (
    SELECT
        lb.location_id,
        lb.county,
        lb.site_name,
        lb.latitude,
        lb.longitude,
        lb.visibility_score,
        lb.accessibility_score,
        lb.estimated_daily_traffic,
        lb.parking_capacity,
        lb.zoning,
        lb.property_size_sqm,
        lb.building_condition,
        lb.competition_within_1km,
        lb.complementary_businesses,
        lb.last_survey_date,
        
        cc.county_population,
        cc.county_income_kes,
        cc.county_unemployment_rate,
        cc.county_store_count,
        cc.county_competitor_density,
        cc.county_market_score,
        
        COALESCE(ca.nearby_competitors, 0) AS nearby_competitors,
        COALESCE(ca.avg_competitor_revenue, 0) AS avg_competitor_revenue,
        
        -- Site Quality Score (0-100)
        (
            (lb.visibility_score * 0.3) + 
            (lb.accessibility_score * 0.3) + 
            (CASE WHEN lb.parking_capacity >= 20 THEN 100 
                  ELSE lb.parking_capacity * 5 END * 0.4)
        ) AS site_quality_score,
        
        -- Market Potential Score (0-100)
        cc.county_market_score AS market_potential_score,
        
        -- Competition Score (0-100, higher = less competition)
        (100 - CASE 
            WHEN ca.nearby_competitors >= 5 THEN 100
            WHEN ca.nearby_competitors >= 3 THEN 80
            WHEN ca.nearby_competitors >= 1 THEN 60
            ELSE 20
        END) AS competition_score
    FROM location_base lb
    LEFT JOIN county_context cc ON lb.county = cc.county_name
    LEFT JOIN competition_analysis ca ON lb.location_id = ca.location_id
)

INSERT INTO gold.location_scoring
SELECT
    location_id,
    county,
    site_name,
    latitude,
    longitude,
    visibility_score,
    accessibility_score,
    estimated_daily_traffic,
    parking_capacity,
    zoning,
    property_size_sqm,
    building_condition,
    competition_within_1km,
    complementary_businesses,
    last_survey_date,
    county_population,
    county_income_kes,
    county_unemployment_rate,
    county_store_count,
    county_competitor_density,
    county_market_score,
    nearby_competitors,
    avg_competitor_revenue,
    site_quality_score,
    market_potential_score,
    competition_score,
    
    -- Overall Location Score (0-100)
    (site_quality_score * 0.4 + market_potential_score * 0.4 + competition_score * 0.2) AS overall_location_score,
    
    -- Recommendations
    CASE 
        WHEN (site_quality_score > 70 AND market_potential_score > 70 AND competition_score > 60) THEN 'Recommended'
        WHEN (site_quality_score > 50 AND market_potential_score > 60 AND competition_score > 40) THEN 'Consider'
        ELSE 'Not Recommended'
    END AS recommendation,
    
    -- Suggested store format
    CASE 
        WHEN county_income_kes > 150000 AND property_size_sqm > 500 THEN 'Supermarket'
        WHEN county_income_kes > 80000 AND property_size_sqm > 200 THEN 'Neighborhood Store'
        WHEN property_size_sqm > 100 THEN 'Convenience Store'
        ELSE 'Express Store'
    END AS suggested_store_format,
    
    -- Estimated monthly potential
    CASE 
        WHEN county_income_kes > 150000 THEN estimated_daily_traffic * 0.05 * 30 * 500
        WHEN county_income_kes > 80000 THEN estimated_daily_traffic * 0.03 * 30 * 300
        ELSE estimated_daily_traffic * 0.02 * 30 * 200
    END AS estimated_monthly_potential_kes,
    
    -- Flags
    CASE 
        WHEN site_quality_score > 80 AND market_potential_score > 80 THEN 1 ELSE 0 
    END AS quick_win_flag,
    
    CASE 
        WHEN market_potential_score > 90 AND site_quality_score > 60 THEN 1 ELSE 0 
    END AS long_term_flag,
    
    CASE 
        WHEN zoning IN ('Commercial', 'Mixed Use') AND building_condition IN ('Good', 'Excellent') THEN 1 ELSE 0 
    END AS infrastructure_ready_flag
FROM scoring;
GO

-- Indexes
CREATE INDEX idx_location_score_overall ON gold.location_scoring(overall_location_score DESC);
CREATE INDEX idx_location_recommendation ON gold.location_scoring(recommendation);
CREATE INDEX idx_location_county ON gold.location_scoring(county);
CREATE INDEX idx_location_quick_win ON gold.location_scoring(quick_win_flag);
GO

/*
README: gold.location_scoring
PURPOSE: Evaluate and rank potential store locations for expansion
KEY METRICS:
- overall_location_score (0-100): Composite suitability score
- site_quality_score (0-100): Visibility, accessibility, parking
- market_potential_score (0-100): County market attractiveness
- competition_score (0-100): Lower competition = higher score
- recommendation: Recommended, Consider, Not Recommended

BUSINESS QUESTIONS ANSWERED:
1. Which are the top 10 locations for new stores? (overall_location_score)
2. Where can we open stores quickly? (quick_win_flag = 1)
3. Which locations have good sites but tough competition? (high site_quality, low competition_score)
4. What store format fits each location? (suggested_store_format)
5. Which counties have multiple good locations? (group by county)

SAMPLE QUERIES:
-- Top 10 recommended locations
SELECT TOP 10 site_name, county, overall_location_score, recommendation, estimated_monthly_potential_kes
FROM gold.location_scoring 
WHERE recommendation = 'Recommended'
ORDER BY overall_location_score DESC;

-- Quick win opportunities
SELECT county, COUNT(*) as total_locations,
       SUM(CASE WHEN quick_win_flag = 1 THEN 1 ELSE 0 END) as quick_wins
FROM gold.location_scoring
GROUP BY county
HAVING SUM(CASE WHEN quick_win_flag = 1 THEN 1 ELSE 0 END) > 0;

-- Location analysis by store format
SELECT suggested_store_format, 
       AVG(overall_location_score) as avg_score,
       COUNT(*) as location_count,
       AVG(estimated_monthly_potential_kes) as avg_potential
FROM gold.location_scoring
WHERE recommendation = 'Recommended'
GROUP BY suggested_store_format
ORDER BY avg_score DESC;

-- Competition analysis
SELECT county, 
       AVG(competition_score) as avg_competition_score,
       COUNT(*) as locations,
       SUM(CASE WHEN recommendation = 'Recommended' THEN 1 ELSE 0 END) as recommended_locations
FROM gold.location_scoring
GROUP BY county
ORDER BY avg_competition_score DESC;
===============================================================================
*/  
select * from gold.location_scoring
