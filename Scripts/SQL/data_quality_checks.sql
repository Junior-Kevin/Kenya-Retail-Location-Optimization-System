-- scripts/data_quality_tests.sql

-- 1. Check for duplicate customers in CRM data
SELECT 
    customer_id,
    COUNT(*) as duplicate_count,
    MIN(registration_date) as first_registration,
    MAX(registration_date) as last_registration
FROM bronze.crm_raw
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 2. Check for missing critical fields in CRM
SELECT 
    COUNT(*) as total_records,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) as missing_emails,
    SUM(CASE WHEN phone IS NULL THEN 1 ELSE 0 END) as missing_phones,
    SUM(CASE WHEN county IS NULL THEN 1 ELSE 0 END) as missing_counties,
    ROUND(100.0 * SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) as email_missing_pct
FROM bronze.crm_raw;

-- 3. Validate POS transaction amounts
SELECT 
    COUNT(*) as total_transactions,
    SUM(CASE WHEN final_price_kes < 0 THEN 1 ELSE 0 END) as negative_prices,
    SUM(CASE WHEN quantity < 0 THEN 1 ELSE 0 END) as negative_quantities,
    SUM(CASE WHEN discount_kes > total_price_kes THEN 1 ELSE 0 END) as excessive_discounts,
    AVG(final_price_kes) as avg_transaction_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY final_price_kes) as median_value
FROM bronze.pos_raw;

-- 4. Check for invalid dates in POS data
SELECT 
    COUNT(*) as invalid_dates,
    MIN(transaction_date) as earliest_date,
    MAX(transaction_date) as latest_date
FROM bronze.pos_raw
WHERE transaction_date < '2023-01-01' 
   OR transaction_date > '2023-12-31'
   OR transaction_date IS NULL;

-- 5. Validate GIS location coordinates
SELECT 
    county,
    COUNT(*) as total_locations,
    SUM(CASE WHEN latitude IS NULL OR longitude IS NULL THEN 1 ELSE 0 END) as missing_coords,
    SUM(CASE WHEN latitude < -4.5 OR latitude > 4.0 THEN 1 ELSE 0 END) as invalid_lat,
    SUM(CASE WHEN longitude < 34.0 OR longitude > 41.0 THEN 1 ELSE 0 END) as invalid_long
FROM bronze.gis_locations_raw
GROUP BY county
ORDER BY missing_coords DESC;

-- 6. Check economic data consistency
SELECT 
    county,
    year_month,
    COUNT(*) as monthly_records,
    AVG(inflation_rate) as avg_inflation,
    MIN(inflation_rate) as min_inflation,
    MAX(inflation_rate) as max_inflation,
    CASE WHEN MAX(inflation_rate) - MIN(inflation_rate) > 5 THEN 'HIGH_VARIANCE' ELSE 'OK' END as variance_flag
FROM bronze.economic_raw
GROUP BY county, year_month
HAVING COUNT(*) > 1  -- Should be 1 per county per month
   OR MAX(inflation_rate) - MIN(inflation_rate) > 5
ORDER BY variance_flag DESC, county, year_month;

-- 7. Identify competitor stores with unrealistic revenue
SELECT 
    competitor_name,
    store_id,
    county,
    estimated_monthly_revenue_kes,
    store_size_sqm,
    estimated_monthly_revenue_kes / NULLIF(store_size_sqm, 0) as revenue_per_sqm,
    CASE 
        WHEN estimated_monthly_revenue_kes / NULLIF(store_size_sqm, 0) > 50000 THEN 'UNREALISTIC_HIGH'
        WHEN estimated_monthly_revenue_kes / NULLIF(store_size_sqm, 0) < 1000 THEN 'UNREALISTIC_LOW'
        ELSE 'REASONABLE'
    END as revenue_quality_flag
FROM bronze.competitor_stores_raw
WHERE estimated_monthly_revenue_kes IS NOT NULL
ORDER BY revenue_per_sqm DESC;

-- 8. Cross-source validation: Customer locations vs store locations
SELECT 
    c.county as customer_county,
    COUNT(DISTINCT c.customer_id) as customer_count,
    COUNT(DISTINCT s.store_id) as store_count,
    CASE 
        WHEN COUNT(DISTINCT s.store_id) = 0 THEN 'NO_STORES'
        WHEN COUNT(DISTINCT c.customer_id) / NULLIF(COUNT(DISTINCT s.store_id), 0) > 10000 THEN 'UNDERSERVED'
        WHEN COUNT(DISTINCT c.customer_id) / NULLIF(COUNT(DISTINCT s.store_id), 0) < 1000 THEN 'OVERSERVED'
        ELSE 'BALANCED'
    END as market_balance
FROM bronze.crm_raw c
LEFT JOIN bronze.stores_raw s ON c.county = s.county
WHERE c.customer_status = 'Active'
GROUP BY c.county
ORDER BY customer_count DESC;
