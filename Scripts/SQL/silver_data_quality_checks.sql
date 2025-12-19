/*
===============================================================================
SCRIPT: data_quality_tests.sql
PURPOSE: Comprehensive Data Quality Assessment for silver Layer
DESCRIPTION:
    This script performs systematic data quality checks across all silver layer
    tables to identify issues before loading to silver layer.
    
SEVERITY LEVELS:
    CRITICAL    - Prevents processing, requires immediate attention
    HIGH        - Significant impact on analytics, needs remediation
    MEDIUM      - Should be addressed, but not blocking
    LOW         - Minor issues, can be monitored
    
AUTHOR: Data Quality Team
CREATED: 2025-12-19
VERSION: 2.2 - Fixed GROUP BY issues
===============================================================================
*/

USE Retail_location;
GO

SET NOCOUNT ON;

PRINT '===============================================================================';
PRINT 'DATA QUALITY ASSESSMENT: silver LAYER';
PRINT 'Start Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '===============================================================================';
GO

-------------------------------------------------------------------------------
-- SECTION 1: CRM DATA QUALITY ASSESSMENT
-------------------------------------------------------------------------------
PRINT CHAR(10) + '1. CRM DATA QUALITY ASSESSMENT';
PRINT REPLICATE('-', 60);

-- 1.1 Customer Uniqueness and Deduplication Analysis
PRINT '1.1 Customer Deduplication Analysis';
SELECT 
    'CRITICAL' as severity,
    'Duplicate customer IDs detected' as issue_description,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(*) as total_records,
    COUNT(*) - COUNT(DISTINCT customer_id) as duplicate_count,
    ROUND(100.0 * (COUNT(*) - COUNT(DISTINCT customer_id)) / COUNT(*), 2) as duplicate_percentage
FROM silver.crm;

-- 1.2 Data Completeness Assessment
PRINT CHAR(10) + '1.2 Data Completeness Analysis';
WITH CompletenessMetrics AS (
    SELECT 
        COUNT(*) as total_records,
        -- Critical fields (contact information)
        SUM(CASE WHEN email IS NULL OR LTRIM(RTRIM(email)) = '' THEN 1 ELSE 0 END) as missing_emails,
        SUM(CASE WHEN phone IS NULL OR LTRIM(RTRIM(phone)) = '' THEN 1 ELSE 0 END) as missing_phones,
        -- Important fields (demographic/geographic)
        SUM(CASE WHEN county IS NULL OR LTRIM(RTRIM(county)) = '' THEN 1 ELSE 0 END) as missing_counties,
        SUM(CASE WHEN gender IS NULL OR LTRIM(RTRIM(gender)) = '' THEN 1 ELSE 0 END) as missing_gender
    FROM silver.crm
)
SELECT 
    CASE 
        WHEN missing_emails > total_records * 0.3 THEN 'HIGH'
        WHEN missing_emails > total_records * 0.1 THEN 'MEDIUM'
        ELSE 'LOW'
    END as email_completeness_severity,
    total_records,
    missing_emails,
    ROUND(100.0 * missing_emails / total_records, 2) as email_missing_pct,
    missing_phones,
    ROUND(100.0 * missing_phones / total_records, 2) as phone_missing_pct,
    missing_counties,
    ROUND(100.0 * missing_counties / total_records, 2) as county_missing_pct
FROM CompletenessMetrics;

-- 1.3 Data Validity: Date Range and Business Logic
PRINT CHAR(10) + '1.3 Date and Business Rule Validation';
WITH DateValidation AS (
    SELECT 
        COUNT(*) as total_customers,
        SUM(CASE WHEN registration_date IS NULL THEN 1 ELSE 0 END) as missing_registration_dates,
        SUM(CASE WHEN last_purchase_date IS NULL THEN 1 ELSE 0 END) as missing_purchase_dates,
        SUM(CASE WHEN registration_date > GETDATE() THEN 1 ELSE 0 END) as future_registration_dates,
        SUM(CASE WHEN last_purchase_date > GETDATE() THEN 1 ELSE 0 END) as future_purchase_dates,
        SUM(CASE WHEN last_purchase_date < registration_date THEN 1 ELSE 0 END) as purchase_before_registration,
        SUM(CASE WHEN registration_date < '2020-01-01' OR registration_date > GETDATE() THEN 1 ELSE 0 END) as invalid_registration_dates
    FROM silver.crm
)
SELECT 
    CASE 
        WHEN invalid_registration_dates > 0 THEN 'HIGH'
        ELSE 'LOW'
    END as severity,
    'Date range validation' as validation_type,
    total_customers,
    missing_registration_dates,
    missing_purchase_dates,
    future_registration_dates,
    future_purchase_dates,
    purchase_before_registration,
    invalid_registration_dates
FROM DateValidation;

-------------------------------------------------------------------------------
-- SECTION 2: POS TRANSACTION DATA QUALITY ASSESSMENT
-------------------------------------------------------------------------------
PRINT CHAR(10) + '2. POS TRANSACTION DATA QUALITY ASSESSMENT';
PRINT REPLICATE('-', 60);

-- 2.1 Transaction Amount Integrity
PRINT '2.1 Transaction Financial Integrity';
WITH FinancialIntegrity AS (
    SELECT 
        COUNT(*) as total_transactions,
        SUM(CASE WHEN TRY_CAST(final_price_kes AS DECIMAL(18,2)) < 0 THEN 1 ELSE 0 END) as negative_amounts,
        SUM(CASE WHEN TRY_CAST(quantity AS INT) < 0 THEN 1 ELSE 0 END) as negative_quantities,
        SUM(CASE WHEN TRY_CAST(discount_kes AS DECIMAL(18,2)) > TRY_CAST(total_price_kes AS DECIMAL(18,2)) 
                 THEN 1 ELSE 0 END) as excessive_discounts,
        SUM(CASE WHEN TRY_CAST(unit_price_kes AS DECIMAL(18,2)) <= 0 THEN 1 ELSE 0 END) as zero_unit_prices,
        AVG(TRY_CAST(final_price_kes AS DECIMAL(18,2))) as avg_transaction_value,
        COUNT(DISTINCT store_id) as unique_stores,
        COUNT(DISTINCT customer_id) as unique_customers
    FROM silver.pos
)
SELECT 
    CASE 
        WHEN negative_amounts > 0 OR excessive_discounts > 0 THEN 'CRITICAL'
        WHEN zero_unit_prices > 0 THEN 'HIGH'
        ELSE 'LOW'
    END as severity,
    total_transactions,
    negative_amounts,
    negative_quantities,
    excessive_discounts,
    zero_unit_prices,
    ROUND(avg_transaction_value, 2) as avg_transaction_value,
    unique_stores,
    unique_customers
FROM FinancialIntegrity;

-- 2.2 Transaction Date Validity
PRINT CHAR(10) + '2.2 Transaction Date Analysis';
WITH DateAnalysis AS (
    SELECT 
        transaction_date,
        TRY_CONVERT(DATE, transaction_date) as parsed_date,
        CASE 
            WHEN TRY_CONVERT(DATE, transaction_date) IS NULL THEN 'INVALID_FORMAT'
            WHEN TRY_CONVERT(DATE, transaction_date) < '2023-01-01' THEN 'OUT_OF_RANGE_LOW'
            WHEN TRY_CONVERT(DATE, transaction_date) > GETDATE() THEN 'FUTURE_DATE'
            ELSE 'VALID'
        END as date_status
    FROM silver.pos
),
DateSummary AS (
    SELECT 
        COUNT(*) as total_transactions,
        SUM(CASE WHEN date_status = 'VALID' THEN 1 ELSE 0 END) as valid_dates,
        SUM(CASE WHEN date_status = 'INVALID_FORMAT' THEN 1 ELSE 0 END) as invalid_format,
        SUM(CASE WHEN date_status = 'OUT_OF_RANGE_LOW' THEN 1 ELSE 0 END) as out_of_range_low,
        SUM(CASE WHEN date_status = 'FUTURE_DATE' THEN 1 ELSE 0 END) as future_dates,
        MIN(parsed_date) as earliest_valid_date,
        MAX(parsed_date) as latest_valid_date,
        SUM(CASE WHEN date_status != 'VALID' THEN 1 ELSE 0 END) as invalid_count
    FROM DateAnalysis
)
SELECT 
    CASE 
        WHEN invalid_count > 0 THEN 'HIGH'
        ELSE 'LOW'
    END as severity,
    total_transactions,
    valid_dates,
    invalid_format,
    out_of_range_low,
    future_dates,
    earliest_valid_date,
    latest_valid_date
FROM DateSummary;

-- 2.3 Product Data Completeness
PRINT CHAR(10) + '2.3 Product Information Completeness';
WITH ProductCompleteness AS (
    SELECT 
        COUNT(*) as total_line_items,
        SUM(CASE WHEN product_id IS NULL OR LTRIM(RTRIM(product_id)) = '' THEN 1 ELSE 0 END) as missing_product_ids,
        SUM(CASE WHEN product_name IS NULL OR LTRIM(RTRIM(product_name)) = '' THEN 1 ELSE 0 END) as missing_product_names,
        SUM(CASE WHEN category IS NULL OR LTRIM(RTRIM(category)) = '' THEN 1 ELSE 0 END) as missing_categories,
        COUNT(DISTINCT category) as unique_categories,
        COUNT(DISTINCT subcategory) as unique_subcategories
    FROM silver.pos
)
SELECT 
    CASE 
        WHEN missing_product_names > total_line_items * 0.05 THEN 'HIGH'
        ELSE 'LOW'
    END as severity,
    total_line_items,
    missing_product_ids,
    missing_product_names,
    missing_categories,
    unique_categories,
    unique_subcategories
FROM ProductCompleteness;

-------------------------------------------------------------------------------
-- SECTION 3: GEOGRAPHIC DATA QUALITY ASSESSMENT
-------------------------------------------------------------------------------
PRINT CHAR(10) + '3. GEOGRAPHIC DATA QUALITY ASSESSMENT';
PRINT REPLICATE('-', 60);

-- 3.1 GIS Locations Coordinate Validation
PRINT '3.1 Location Coordinate Integrity';
WITH CoordinateValidation AS (
    SELECT 
        COUNT(*) as total_locations,
        SUM(CASE WHEN latitude IS NULL OR longitude IS NULL THEN 1 ELSE 0 END) as missing_coords,
        SUM(CASE 
                WHEN TRY_CAST(latitude AS DECIMAL(10,6)) < -4.5 
                     OR TRY_CAST(latitude AS DECIMAL(10,6)) > 4.0 
                     OR TRY_CAST(longitude AS DECIMAL(10,6)) < 34.0 
                     OR TRY_CAST(longitude AS DECIMAL(10,6)) > 41.0 
                THEN 1 ELSE 0 
            END) as invalid_coords,
        AVG(TRY_CAST(latitude AS DECIMAL(10,6))) as avg_latitude,
        AVG(TRY_CAST(longitude AS DECIMAL(10,6))) as avg_longitude
    FROM silver.gis_locations
)
SELECT 
    CASE 
        WHEN missing_coords > 0 OR invalid_coords > 0 THEN 'HIGH'
        ELSE 'LOW'
    END as severity,
    'Kenya Geographic Bounds: Lat (-4.5 to 4.0), Long (34.0 to 41.0)' as validation_rule,
    total_locations,
    missing_coords,
    invalid_coords,
    avg_latitude,
    avg_longitude
FROM CoordinateValidation;

-- 3.2 County Demographic Data Consistency
PRINT CHAR(10) + '3.2 County Data Statistical Validation';
WITH CountyValidation AS (
    SELECT 
        COUNT(*) as county_count,
        SUM(CASE WHEN TRY_CAST(population_2023 AS INT) <= 0 THEN 1 ELSE 0 END) as zero_population,
        SUM(CASE WHEN TRY_CAST(area_sqkm AS DECIMAL(18,2)) <= 0 THEN 1 ELSE 0 END) as zero_area,
        SUM(CASE 
                WHEN TRY_CAST(population_density_psqkm AS DECIMAL(10,2)) > 10000 
                THEN 1 ELSE 0 
            END) as extreme_density,
        SUM(CASE 
                WHEN TRY_CAST(unemployment_rate AS DECIMAL(5,2)) > 50 
                THEN 1 ELSE 0 
            END) as high_unemployment,
        SUM(CASE 
                WHEN TRY_CAST(population_density_psqkm AS DECIMAL(10,2)) > 10000 
                OR TRY_CAST(unemployment_rate AS DECIMAL(5,2)) > 50 
                THEN 1 ELSE 0 
            END) as extreme_values,
        SUM(CASE 
                WHEN population_2023 IS NULL 
                OR area_sqkm IS NULL 
                THEN 1 ELSE 0 
            END) as data_gaps
    FROM silver.gis_counties
)
SELECT 
    CASE 
        WHEN extreme_values > 0 OR data_gaps > 0 THEN 'MEDIUM'
        ELSE 'LOW'
    END as severity,
    county_count,
    zero_population,
    zero_area,
    extreme_density,
    high_unemployment,
    extreme_values,
    data_gaps
FROM CountyValidation;

-------------------------------------------------------------------------------
-- SECTION 4: ECONOMIC DATA QUALITY ASSESSMENT
-------------------------------------------------------------------------------
PRINT CHAR(10) + '4. ECONOMIC INDICATORS DATA QUALITY';
PRINT REPLICATE('-', 60);

-- 4.1 Economic Data Consistency Over Time
PRINT '4.1 Time Series Consistency Analysis';
WITH EconomicConsistency AS (
    SELECT 
        county,
        year_month,
        TRY_CAST(year AS INT) as year_num,
        TRY_CAST(month AS INT) as month_num,
        TRY_CAST(gdp_growth_rate AS DECIMAL(5,2)) as gdp_growth,
        TRY_CAST(inflation_rate AS DECIMAL(5,2)) as inflation,
        TRY_CAST(unemployment_rate AS DECIMAL(5,2)) as unemployment
    FROM silver.economic
),
EconomicSummary AS (
    SELECT 
        COUNT(DISTINCT county) as counties_with_data,
        COUNT(DISTINCT year_month) as unique_months,
        MIN(year_num) as earliest_year,
        MAX(year_num) as latest_year,
        AVG(inflation) as avg_inflation_rate,
        MIN(inflation) as min_inflation_rate,
        MAX(inflation) as max_inflation_rate,
        STDEV(inflation) as inflation_volatility,
        COUNT(CASE WHEN year_num IS NULL OR month_num IS NULL THEN 1 END) as missing_months,
        COUNT(CASE WHEN gdp_growth IS NULL OR inflation IS NULL OR unemployment IS NULL THEN 1 END) as data_gaps,
        COUNT(CASE WHEN ABS(inflation) > 20 THEN 1 END) as extreme_volatility
    FROM EconomicConsistency
)
SELECT 
    CASE 
        WHEN missing_months > 0 OR data_gaps > 0 THEN 'HIGH'
        WHEN extreme_volatility > 0 THEN 'MEDIUM'
        ELSE 'LOW'
    END as severity,
    counties_with_data,
    unique_months,
    earliest_year,
    latest_year,
    avg_inflation_rate,
    min_inflation_rate,
    max_inflation_rate,
    inflation_volatility,
    missing_months,
    data_gaps,
    extreme_volatility
FROM EconomicSummary;

-- 4.2 Economic Indicator Reasonableness
PRINT CHAR(10) + '4.2 Indicator Value Reasonableness';
WITH IndicatorValidation AS (
    SELECT 
        COUNT(*) as total_records,
        SUM(CASE 
                WHEN TRY_CAST(gdp_growth_rate AS DECIMAL(5,2)) < -10 
                     OR TRY_CAST(gdp_growth_rate AS DECIMAL(5,2)) > 20 
                THEN 1 ELSE 0 
            END) as unrealistic_gdp,
        SUM(CASE 
                WHEN TRY_CAST(inflation_rate AS DECIMAL(5,2)) < 0 
                     OR TRY_CAST(inflation_rate AS DECIMAL(5,2)) > 50 
                THEN 1 ELSE 0 
            END) as unrealistic_inflation,
        SUM(CASE 
                WHEN TRY_CAST(unemployment_rate AS DECIMAL(5,2)) < 0 
                     OR TRY_CAST(unemployment_rate AS DECIMAL(5,2)) > 50 
                THEN 1 ELSE 0 
            END) as unrealistic_unemployment,
        SUM(CASE 
                WHEN TRY_CAST(gdp_growth_rate AS DECIMAL(5,2)) < -10 OR TRY_CAST(gdp_growth_rate AS DECIMAL(5,2)) > 20 
                OR TRY_CAST(inflation_rate AS DECIMAL(5,2)) < 0 OR TRY_CAST(inflation_rate AS DECIMAL(5,2)) > 50 
                OR TRY_CAST(unemployment_rate AS DECIMAL(5,2)) < 0 OR TRY_CAST(unemployment_rate AS DECIMAL(5,2)) > 50 
            THEN 1 ELSE 0 
        END) as unrealistic_values
    FROM silver.economic
)
SELECT 
    CASE 
        WHEN unrealistic_values > 0 THEN 'MEDIUM'
        ELSE 'LOW'
    END as severity,
    'Validation: GDP (-10% to +20%), Inflation (0-50%), Unemployment (0-50%)' as validation_rules,
    total_records,
    unrealistic_gdp,
    unrealistic_inflation,
    unrealistic_unemployment,
    unrealistic_values
FROM IndicatorValidation;

-------------------------------------------------------------------------------
-- SECTION 5: COMPETITOR DATA QUALITY ASSESSMENT
-------------------------------------------------------------------------------
PRINT CHAR(10) + '5. COMPETITOR DATA QUALITY ASSESSMENT';
PRINT REPLICATE('-', 60);

-- 5.1 Competitor Store Revenue Validation
PRINT '5.1 Store Performance Metrics Reasonableness';
WITH RevenueAnalysis AS (
    SELECT 
        competitor_id,
        store_id,
        county,
        TRY_CAST(estimated_monthly_revenue_kes AS DECIMAL(18,2)) as monthly_revenue,
        TRY_CAST(store_size_sqm AS INT) as store_size,
        TRY_CAST(estimated_monthly_revenue_kes AS DECIMAL(18,2)) / NULLIF(TRY_CAST(store_size_sqm AS INT), 0) as revenue_per_sqm
    FROM silver.competitor_stores
    WHERE estimated_monthly_revenue_kes IS NOT NULL
),
RevenueSummary AS (
    SELECT 
        COUNT(*) as stores_with_revenue_data,
        AVG(monthly_revenue) as avg_monthly_revenue,
        AVG(revenue_per_sqm) as avg_revenue_per_sqm,
        MIN(revenue_per_sqm) as min_revenue_per_sqm,
        MAX(revenue_per_sqm) as max_revenue_per_sqm,
        COUNT(CASE WHEN revenue_per_sqm < 1000 OR revenue_per_sqm > 50000 THEN 1 END) as extreme_outliers,
        COUNT(CASE WHEN revenue_per_sqm < 2000 OR revenue_per_sqm > 30000 THEN 1 END) as potential_outliers
    FROM RevenueAnalysis
)
SELECT 
    CASE 
        WHEN extreme_outliers > 0 THEN 'HIGH'
        WHEN potential_outliers > 0 THEN 'MEDIUM'
        ELSE 'LOW'
    END as severity,
    'Expected Revenue per SQM: 1,000 - 50,000 KES' as expected_range,
    stores_with_revenue_data,
    avg_monthly_revenue,
    avg_revenue_per_sqm,
    min_revenue_per_sqm,
    max_revenue_per_sqm,
    extreme_outliers,
    potential_outliers
FROM RevenueSummary;

-- 5.2 Competitor Data Completeness
PRINT CHAR(10) + '5.2 Competitor Profile Completeness';
WITH CompetitorCompleteness AS (
    SELECT 
        COUNT(*) as total_competitors,
        SUM(CASE WHEN competitor_name IS NULL OR LTRIM(RTRIM(competitor_name)) = '' THEN 1 ELSE 0 END) as missing_names,
        SUM(CASE WHEN competitor_type IS NULL OR LTRIM(RTRIM(competitor_type)) = '' THEN 1 ELSE 0 END) as missing_types,
        SUM(CASE WHEN total_stores IS NULL OR TRY_CAST(total_stores AS INT) <= 0 THEN 1 ELSE 0 END) as missing_store_counts,
        SUM(CASE WHEN estimated_market_share IS NULL THEN 1 ELSE 0 END) as missing_market_share,
        SUM(CASE 
                WHEN competitor_name IS NULL OR LTRIM(RTRIM(competitor_name)) = ''
                OR competitor_type IS NULL OR LTRIM(RTRIM(competitor_type)) = ''
                THEN 1 ELSE 0 
            END) as missing_critical_info
    FROM silver.competitors
)
SELECT 
    CASE 
        WHEN missing_critical_info > 0 THEN 'MEDIUM'
        ELSE 'LOW'
    END as severity,
    total_competitors,
    missing_names,
    missing_types,
    missing_store_counts,
    missing_market_share
FROM CompetitorCompleteness;

-------------------------------------------------------------------------------
-- SECTION 6: CROSS-TABLE DATA INTEGRITY CHECKS
-------------------------------------------------------------------------------
PRINT CHAR(10) + '6. CROSS-TABLE DATA INTEGRITY CHECKS';
PRINT REPLICATE('-', 60);

-- 6.1 Geographic Coverage Alignment
PRINT '6.1 Market Coverage Analysis: Customers vs Stores';
WITH MarketAnalysis AS (
    SELECT 
        c.county as customer_county,
        COUNT(DISTINCT c.customer_id) as customer_count,
        COUNT(DISTINCT s.store_id) as store_count,
        COUNT(DISTINCT cs.competitor_id) as competitor_store_count
    FROM silver.crm c
    LEFT JOIN silver.stores s ON c.county = s.county
    LEFT JOIN silver.competitor_stores cs ON c.county = cs.county
    WHERE c.customer_status = 'Active'
    GROUP BY c.county
),
MarketSummary AS (
    SELECT 
        COUNT(*) as counties_with_customers,
        SUM(customer_count) as total_customers,
        SUM(store_count) as total_our_stores,
        SUM(competitor_store_count) as total_competitor_stores,
        AVG(customer_count / NULLIF(store_count + 0.0, 0)) as avg_customers_per_store,
        COUNT(CASE WHEN store_count = 0 THEN 1 END) as markets_without_stores,
        COUNT(CASE WHEN customer_count / NULLIF(store_count + 0.0, 0) > 10000 THEN 1 END) as underserved_markets,
        COUNT(CASE WHEN customer_count / NULLIF(store_count + 0.0, 0) < 1000 THEN 1 END) as overserved_markets
    FROM MarketAnalysis
)
SELECT 
    CASE 
        WHEN markets_without_stores > 0 OR underserved_markets > 0 OR overserved_markets > 0 THEN 'MEDIUM'
        ELSE 'LOW'
    END as severity,
    'Target: 1 store per 5,000 customers' as market_target,
    counties_with_customers,
    total_customers,
    total_our_stores,
    total_competitor_stores,
    avg_customers_per_store,
    markets_without_stores,
    underserved_markets,
    overserved_markets
FROM MarketSummary;

-- 6.2 Transaction Store Validation
PRINT CHAR(10) + '6.2 Store Reference Integrity';
WITH StoreValidation AS (
    SELECT 
        COUNT(DISTINCT p.store_id) as unique_stores_in_transactions,
        COUNT(DISTINCT s.store_id) as unique_stores_in_master,
        SUM(CASE WHEN s.store_id IS NULL THEN 1 ELSE 0 END) as orphaned_transactions,
        COUNT(*) as total_transactions
    FROM silver.pos p
    LEFT JOIN silver.stores s ON p.store_id = s.store_id
)
SELECT 
    CASE 
        WHEN orphaned_transactions > 0 THEN 'HIGH'
        ELSE 'LOW'
    END as severity,
    unique_stores_in_transactions,
    unique_stores_in_master,
    unique_stores_in_transactions - unique_stores_in_master as store_id_gap,
    orphaned_transactions,
    ROUND(100.0 * orphaned_transactions / total_transactions, 2) as orphaned_pct
FROM StoreValidation;

-------------------------------------------------------------------------------
-- SECTION 7: SUMMARY AND ACTIONABLE INSIGHTS
-------------------------------------------------------------------------------
PRINT CHAR(10) + '7. DATA QUALITY SUMMARY AND RECOMMENDATIONS';
PRINT REPLICATE('=', 80);

-- 7.1 Overall Data Quality Score
PRINT '7.1 Overall Data Quality Scorecard';
WITH QualityMetrics AS (
    -- CRM Duplicates
    SELECT 'CRM Duplicates' as category, 
           CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM silver.crm) > 0 
                THEN 'CRITICAL' ELSE 'LOW' END as severity, 
           1 as weight UNION ALL
    
    -- CRM Missing Emails
    SELECT 'CRM Missing Emails' as category, 
           CASE WHEN (SELECT COUNT(*) FROM silver.crm WHERE email IS NULL) > 
                     (SELECT COUNT(*) * 0.3 FROM silver.crm) 
                THEN 'HIGH' ELSE 'LOW' END, 
           2 UNION ALL
    
    -- Negative Transaction Amounts
    SELECT 'Negative Transaction Amounts' as category, 
           CASE WHEN EXISTS (SELECT 1 FROM silver.pos WHERE TRY_CAST(final_price_kes AS DECIMAL(18,2)) < 0) 
                THEN 'CRITICAL' ELSE 'LOW' END, 
           3 UNION ALL
    
    -- Invalid Transaction Dates
    SELECT 'Invalid Transaction Dates' as category, 
           CASE WHEN (SELECT COUNT(*) FROM silver.pos WHERE TRY_CONVERT(DATE, transaction_date) IS NULL) > 0 
                THEN 'HIGH' ELSE 'LOW' END, 
           2 UNION ALL
    
    -- Missing Geographic Coordinates
    SELECT 'Missing Geographic Coordinates' as category, 
           CASE WHEN (SELECT COUNT(*) FROM silver.gis_locations WHERE latitude IS NULL OR longitude IS NULL) > 0 
                THEN 'MEDIUM' ELSE 'LOW' END, 
           1
)
SELECT 
    'OVERALL' as assessment,
    CASE 
        WHEN SUM(CASE WHEN severity = 'CRITICAL' THEN weight ELSE 0 END) > 0 THEN 'CRITICAL'
        WHEN SUM(CASE WHEN severity = 'HIGH' THEN weight ELSE 0 END) > 3 THEN 'HIGH'
        WHEN SUM(CASE WHEN severity = 'MEDIUM' THEN weight ELSE 0 END) > 5 THEN 'MEDIUM'
        ELSE 'GOOD'
    END as overall_quality_status,
    COUNT(*) as total_checks,
    SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) as critical_issues,
    SUM(CASE WHEN severity = 'HIGH' THEN 1 ELSE 0 END) as high_issues,
    SUM(CASE WHEN severity = 'MEDIUM' THEN 1 ELSE 0 END) as medium_issues,
    SUM(CASE WHEN severity = 'LOW' THEN 1 ELSE 0 END) as low_issues
FROM QualityMetrics;

-- 7.2 Priority Action Items
PRINT CHAR(10) + '7.2 Priority Action Recommendations';
SELECT 
    ROW_NUMBER() OVER (ORDER BY 
        CASE severity 
            WHEN 'CRITICAL' THEN 1
            WHEN 'HIGH' THEN 2
            WHEN 'MEDIUM' THEN 3
            ELSE 4
        END,
        impact_score DESC
    ) as priority_rank,
    action_item,
    severity,
    recommended_action,
    estimated_effort
FROM (
    VALUES 
        (1, 'Fix negative transaction amounts in POS data', 'CRITICAL', 'UPDATE silver.pos SET final_price_kes = ABS(final_price_kes) WHERE final_price_kes < 0', '30 minutes'),
        (2, 'Resolve duplicate customer records', 'CRITICAL', 'Implement deduplication logic in silver layer transformation', '2 hours'),
        (3, 'Clean invalid transaction dates', 'HIGH', 'Standardize date formats and validate date ranges', '1 hour'),
        (4, 'Complete missing customer contact information', 'MEDIUM', 'Data enrichment or source system correction', '4 hours'),
        (5, 'Validate geographic coordinates', 'MEDIUM', 'Coordinate range validation and correction', '2 hours')
) AS Actions(id, action_item, severity, recommended_action, estimated_effort)
CROSS APPLY (
    SELECT CASE severity 
        WHEN 'CRITICAL' THEN 100
        WHEN 'HIGH' THEN 80
        WHEN 'MEDIUM' THEN 60
        ELSE 40
    END as impact_score
) s;

-- 7.3 Data Quality Improvement Tracking
PRINT CHAR(10) + '7.3 Quality Metrics for Monitoring';
SELECT 
    metric_name,
    current_value,
    target_value,
    CASE 
        WHEN current_value <= target_value THEN 'MET'
        WHEN current_value <= target_value * 1.1 THEN 'NEAR_MISS'
        ELSE 'FAILED'
    END as status,
    ROUND(100.0 * current_value / target_value, 2) as achievement_pct
FROM (
    SELECT 'Data Completeness (CRM Email)' as metric_name,
           (SELECT 100.0 - ROUND(100.0 * SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) 
            FROM silver.crm) as current_value,
           95.0 as target_value
    UNION ALL
    SELECT 'Transaction Data Validity',
           (SELECT ROUND(100.0 * SUM(CASE WHEN TRY_CAST(final_price_kes AS DECIMAL(18,2)) >= 0 THEN 1 ELSE 0 END) / COUNT(*), 2) 
            FROM silver.pos),
           99.9
    UNION ALL
    SELECT 'Geographic Data Completeness',
           (SELECT ROUND(100.0 * SUM(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) 
            FROM silver.gis_locations),
           98.0
    UNION ALL
    SELECT 'Time Series Continuity',
           (SELECT ROUND(100.0 * COUNT(DISTINCT year_month) / 12.0, 2) 
            FROM silver.economic WHERE TRY_CAST(year AS INT) = 2023),
           100.0
) AS Metrics;

PRINT CHAR(10) + '===============================================================================';
PRINT 'DATA QUALITY ASSESSMENT COMPLETED';
PRINT 'End Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '===============================================================================';
