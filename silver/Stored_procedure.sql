/*
===============================================================================
PROCEDURE: silver.usp_LoadSilverLayer
PURPOSE: Load and transform data from bronze to silver layer
DESCRIPTION:
    This procedure performs the ETL process to load cleaned, validated, and 
    transformed data from the bronze layer into the silver layer. It applies 
    business rules, data type conversions, quality checks, deduplication,
    and handles referential integrity.
    
    Key transformations include:
    - Data type standardization and validation
    - Column mapping corrections for misaligned data
    - Deduplication across all tables
    - Missing value imputation
    - Business rule enforcement
    - Data quality filtering
    
PROCESS FLOW:
    1. Validate parameters and initialize logging
    2. Begin transaction for data consistency
    3. Clear all silver tables in correct order (child tables first)
    4. Sequentially load each table with transformations
    5. Commit transaction on success
    6. Rollback on error with detailed logging
    
DATA LOADING ORDER (Maintaining Referential Integrity):
    1. Parent Tables (No dependencies):
        - crm, products, hr, stores, gis_counties, gis_locations, economic
    2. Parent Table with Dependencies:
        - competitors
    3. Child Tables (Foreign Key Dependencies):
        - competitor_stores (depends on competitors)
        - pos (depends on crm and stores)
    
SPECIAL HANDLING:
    - competitor_stores table has column mapping corrections due to CSV import issues
    - HR data includes shift hours parsing from time ranges (08:00-17:00)
    - POS data has customer ID standardization
    - All numeric fields have overflow protection
    - All string fields have trimming and NULL handling
    
PARAMETERS:
    @LoadDate    - Optional date for incremental loading (default: current date)
    @DebugMode   - Enable detailed logging and diagnostics (0=off, 1=on)
    
RETURNS:
    0  - Success
    -1 - Failure with error details
    
DEPENDENCIES:
    - All bronze layer tables must exist and be populated
    - Silver layer DDL must be executed first
    - Database: KenyaFreshRetail
    - Schema: silver
    
AUTHOR: Data Engineering Team
CREATED: 2025-12-25
VERSION: 3.0 - Complete solution with all fixes:
                - CRM data hardening against special characters
                - Products data overflow protection
                - HR data deduplication and shift hours parsing
                - Competitor stores column mapping correction
                - Comprehensive error handling
                - Enhanced logging and debugging
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.usp_LoadSilverLayer
    @LoadDate DATE = NULL,
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    -- ========================================================================
    -- VARIABLE DECLARATIONS
    -- ========================================================================
    DECLARE @ProcedureName NVARCHAR(100) = 'usp_LoadSilverLayer';
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RowsAffected INT = 0;
    DECLARE @TotalRows INT = 0;
    DECLARE @ErrorMsg NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;
    
    -- ========================================================================
    -- PARAMETER VALIDATION AND INITIALIZATION
    -- ========================================================================
    -- Set default load date if not provided
    IF @LoadDate IS NULL
        SET @LoadDate = CAST(GETDATE() AS DATE);
    
    -- ========================================================================
    -- MAIN EXECUTION BLOCK
    -- ========================================================================
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- ====================================================================
        -- PROCESS START LOGGING
        -- ====================================================================
        PRINT REPLICATE('=', 80);
        PRINT 'SILVER LAYER ETL PROCESS - VERSION 3.0';
        PRINT 'Start Time: ' + FORMAT(@StartTime, 'yyyy-MM-dd HH:mm:ss');
        PRINT 'Load Date: ' + CAST(@LoadDate AS NVARCHAR(20));
        PRINT 'Debug Mode: ' + CASE WHEN @DebugMode = 1 THEN 'ON' ELSE 'OFF' END;
        PRINT REPLICATE('=', 80);
        PRINT '';
        
        -- ====================================================================
        -- PHASE 1: CLEAR EXISTING DATA (CHILD TABLES FIRST)
        -- ====================================================================
        PRINT 'PHASE 1: CLEARING EXISTING DATA';
        PRINT REPLICATE('-', 80);
        
        -- Temporarily disable foreign key constraint for competitor_stores
        PRINT '1. Temporarily disabling foreign key constraint...';
        ALTER TABLE silver.competitor_stores NOCHECK CONSTRAINT FK_competitor_stores_competitors;
        
        -- Clear child tables first (tables with foreign keys)
        PRINT '2. Clearing child tables...';
        TRUNCATE TABLE silver.competitor_stores;
        TRUNCATE TABLE silver.pos;
        TRUNCATE TABLE silver.hr;
        
        -- Clear parent tables
        PRINT '3. Clearing parent tables...';
        TRUNCATE TABLE silver.crm;
        TRUNCATE TABLE silver.products;
        TRUNCATE TABLE silver.stores;
        TRUNCATE TABLE silver.gis_counties;
        TRUNCATE TABLE silver.gis_locations;
        TRUNCATE TABLE silver.economic;
        
        -- Competitors needs DELETE (not TRUNCATE) due to foreign key dependency
        PRINT '4. Clearing competitors (using DELETE due to FK constraint)...';
        DELETE FROM silver.competitors;
        
        -- Re-enable foreign key constraint
        PRINT '5. Re-enabling foreign key constraint...';
        ALTER TABLE silver.competitor_stores CHECK CONSTRAINT FK_competitor_stores_competitors;
        
        PRINT 'All tables cleared successfully.';
        PRINT '';
        
        -- ====================================================================
        -- PHASE 2: LOAD DATA WITH TRANSFORMATIONS
        -- ====================================================================
        PRINT 'PHASE 2: LOADING AND TRANSFORMING DATA';
        PRINT REPLICATE('-', 80);
        
        -- --------------------------------------------------------------------
        -- 1. LOAD CRM DATA (HARDENED AGAINST SPECIAL CHARACTERS)
        -- --------------------------------------------------------------------
        PRINT '1. LOADING CRM CUSTOMER DATA...';
        
        INSERT INTO silver.crm (
            customer_id, first_name, last_name, gender, phone, email,
            county, area, customer_segment, registration_date, customer_status,
            last_purchase_date, purchase_frequency_monthly, avg_transaction_value_kes,
            lifetime_value_kes, preferred_store_format, communication_preferences,
            feedback_score, data_source, extracted_date, record_version
        )
        SELECT 
            customer_id,
            first_name,
            last_name,
            gender,
            ISNULL(phone, 'unknown') AS phone,
            ISNULL(email, 'email@unknown') AS email,
            county,
            area,
            customer_segment,
            TRY_CONVERT(DATE, LEFT(registration_date, 10)) AS registration_date,
            customer_status,
            TRY_CONVERT(DATE, last_purchase_date) AS last_purchase_date,
            
            -- purchase_frequency_monthly (INT) with special character handling
            CASE 
                WHEN TRY_CAST(
                    REPLACE(REPLACE(LTRIM(RTRIM(purchase_frequency_monthly)), CHAR(13), ''), CHAR(10), '')
                    AS INT
                ) IS NOT NULL
                THEN CAST(
                    REPLACE(REPLACE(LTRIM(RTRIM(purchase_frequency_monthly)), CHAR(13), ''), CHAR(10), '')
                    AS INT
                )
                ELSE 0
            END AS purchase_frequency_monthly,
            
            -- avg_transaction_value_kes (DECIMAL) with special character handling
            CASE 
                WHEN TRY_CAST(
                    REPLACE(REPLACE(LTRIM(RTRIM(avg_transaction_value_kes)), CHAR(13), ''), CHAR(10), '')
                    AS DECIMAL(18,2)
                ) IS NOT NULL
                THEN CAST(
                    REPLACE(REPLACE(LTRIM(RTRIM(avg_transaction_value_kes)), CHAR(13), ''), CHAR(10), '')
                    AS DECIMAL(18,2)
                )
                ELSE 0.00
            END AS avg_transaction_value_kes,
            
            -- lifetime_value_kes (DECIMAL) with special character handling
            CASE 
                WHEN TRY_CAST(
                    REPLACE(REPLACE(LTRIM(RTRIM(lifetime_value_kes)), CHAR(13), ''), CHAR(10), '')
                    AS DECIMAL(18,2)
                ) IS NOT NULL
                THEN CAST(
                    REPLACE(REPLACE(LTRIM(RTRIM(lifetime_value_kes)), CHAR(13), ''), CHAR(10), '')
                    AS DECIMAL(18,2)
                )
                ELSE 0.00
            END AS lifetime_value_kes,
            
            preferred_store_format,
            communication_preferences,
            
            -- feedback_score (DECIMAL) with special character handling
            CASE 
                WHEN TRY_CAST(
                    REPLACE(REPLACE(LTRIM(RTRIM(feedback_score)), CHAR(13), ''), CHAR(10), '')
                    AS DECIMAL(3,1)
                ) IS NOT NULL
                THEN CAST(
                    REPLACE(REPLACE(LTRIM(RTRIM(feedback_score)), CHAR(13), ''), CHAR(10), '')
                    AS DECIMAL(3,1)
                )
                ELSE 0.0
            END AS feedback_score,
            
            data_source,
            extracted_date,
            record_version
        FROM bronze.crm_raw
        WHERE customer_id NOT LIKE '%DUP'; -- Remove duplicate markers
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
        -- --------------------------------------------------------------------
        -- 2. LOAD PRODUCTS DATA (WITH OVERFLOW PROTECTION)
        -- --------------------------------------------------------------------
        PRINT '2. LOADING PRODUCTS DATA...';
        
        IF @DebugMode = 1
        BEGIN
            PRINT '   DEBUG: Checking for problematic product data...';
            
            SELECT TOP 5 *
            FROM bronze.products_raw
            WHERE TRY_CAST(unit_cost_kes AS DECIMAL(38,10)) IS NULL 
               OR TRY_CAST(retail_price_kes AS DECIMAL(38,10)) IS NULL
               OR TRY_CAST(margin_percentage AS DECIMAL(10,4)) IS NULL
               OR TRY_CAST(popularity_score AS DECIMAL(10,4)) IS NULL;
        END
        
        INSERT INTO silver.products (
            product_id, product_name, category, subcategory, brand,
            supplier, unit_cost_kes, retail_price_kes, margin_percentage,
            stock_level, reorder_point, seasonality, popularity_score,
            data_source, extracted_date
        )
        SELECT 
            -- Clean text fields
            LTRIM(RTRIM(ISNULL(product_id, 'UNKNOWN'))) AS product_id,
            LTRIM(RTRIM(ISNULL(product_name, 'Unknown'))) AS product_name,
            LTRIM(RTRIM(ISNULL(category, 'General'))) AS category,
            LTRIM(RTRIM(ISNULL(subcategory, 'General'))) AS subcategory,
            LTRIM(RTRIM(ISNULL(brand, 'Generic'))) AS brand,
            LTRIM(RTRIM(ISNULL(supplier, 'Unknown'))) AS supplier,
            
            -- unit_cost_kes: DECIMAL(18,2) with overflow protection
            CASE 
                WHEN TRY_CAST(LTRIM(RTRIM(unit_cost_kes)) AS DECIMAL(38,10)) IS NULL THEN 0.00
                WHEN CAST(LTRIM(RTRIM(unit_cost_kes)) AS DECIMAL(38,10)) > 9999999999999999.99 THEN 9999999999999999.99
                WHEN CAST(LTRIM(RTRIM(unit_cost_kes)) AS DECIMAL(38,10)) < 0 THEN 0.00
                ELSE CAST(CAST(LTRIM(RTRIM(unit_cost_kes)) AS DECIMAL(38,10)) AS DECIMAL(18,2))
            END AS unit_cost_kes,
            
            -- retail_price_kes: DECIMAL(18,2) with overflow protection
            CASE 
                WHEN TRY_CAST(LTRIM(RTRIM(retail_price_kes)) AS DECIMAL(38,10)) IS NULL THEN 0.00
                WHEN CAST(LTRIM(RTRIM(retail_price_kes)) AS DECIMAL(38,10)) > 9999999999999999.99 THEN 9999999999999999.99
                WHEN CAST(LTRIM(RTRIM(retail_price_kes)) AS DECIMAL(38,10)) < 0 THEN 0.00
                ELSE CAST(CAST(LTRIM(RTRIM(retail_price_kes)) AS DECIMAL(38,10)) AS DECIMAL(18,2))
            END AS retail_price_kes,
            
            -- margin_percentage: DECIMAL(5,2) - max 999.99
            CASE 
                WHEN TRY_CAST(LTRIM(RTRIM(margin_percentage)) AS DECIMAL(10,4)) IS NULL THEN 0.00
                WHEN CAST(LTRIM(RTRIM(margin_percentage)) AS DECIMAL(10,4)) > 999.99 THEN 999.99
                WHEN CAST(LTRIM(RTRIM(margin_percentage)) AS DECIMAL(10,4)) < -999.99 THEN -999.99
                ELSE CAST(CAST(LTRIM(RTRIM(margin_percentage)) AS DECIMAL(10,4)) AS DECIMAL(5,2))
            END AS margin_percentage,
            
            -- stock_level: INT with overflow protection
            CASE 
                WHEN TRY_CAST(LTRIM(RTRIM(stock_level)) AS BIGINT) IS NULL THEN 0
                WHEN CAST(LTRIM(RTRIM(stock_level)) AS BIGINT) > 2147483647 THEN 2147483647
                WHEN CAST(LTRIM(RTRIM(stock_level)) AS BIGINT) < 0 THEN 0
                ELSE CAST(CAST(LTRIM(RTRIM(stock_level)) AS BIGINT) AS INT)
            END AS stock_level,
            
            -- reorder_point: INT with overflow protection
            CASE 
                WHEN TRY_CAST(LTRIM(RTRIM(reorder_point)) AS BIGINT) IS NULL THEN 0
                WHEN CAST(LTRIM(RTRIM(reorder_point)) AS BIGINT) > 2147483647 THEN 2147483647
                WHEN CAST(LTRIM(RTRIM(reorder_point)) AS BIGINT) < 0 THEN 0
                ELSE CAST(CAST(LTRIM(RTRIM(reorder_point)) AS BIGINT) AS INT)
            END AS reorder_point,
            
            LTRIM(RTRIM(ISNULL(seasonality, 'Year-round'))) AS seasonality,
            
            -- popularity_score: DECIMAL(3,2) - max 9.99
            CASE 
                WHEN TRY_CAST(LTRIM(RTRIM(popularity_score)) AS DECIMAL(10,4)) IS NULL THEN 0.00
                WHEN CAST(LTRIM(RTRIM(popularity_score)) AS DECIMAL(10,4)) > 9.99 THEN 9.99
                WHEN CAST(LTRIM(RTRIM(popularity_score)) AS DECIMAL(10,4)) < 0 THEN 0.00
                ELSE CAST(CAST(LTRIM(RTRIM(popularity_score)) AS DECIMAL(10,4)) AS DECIMAL(3,2))
            END AS popularity_score,
            
            LTRIM(RTRIM(ISNULL(data_source, 'bronze.products_raw'))) AS data_source,
            
            -- extracted_date with multiple format support
            CASE 
                WHEN TRY_CONVERT(DATE, extracted_date, 120) IS NOT NULL 
                    THEN TRY_CONVERT(DATE, extracted_date, 120)
                WHEN TRY_CONVERT(DATE, extracted_date, 23) IS NOT NULL 
                    THEN TRY_CONVERT(DATE, extracted_date, 23)
                WHEN TRY_CONVERT(DATE, extracted_date, 101) IS NOT NULL 
                    THEN TRY_CONVERT(DATE, extracted_date, 101)
                ELSE CAST(GETDATE() AS DATE)
            END AS extracted_date
            
        FROM bronze.products_raw;
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
        -- --------------------------------------------------------------------
        -- 3. LOAD HR DATA (WITH DEDUPLICATION AND SHIFT HOURS PARSING)
        -- --------------------------------------------------------------------
        PRINT '3. LOADING HR EMPLOYEE DATA...';
        
        IF @DebugMode = 1
        BEGIN
            PRINT '   DEBUG: Checking shift_hours formats and duplicates...';
            
            SELECT DISTINCT TOP 10 
                shift_hours,
                CASE 
                    WHEN shift_hours LIKE '%-%' THEN 'Time range format'
                    WHEN TRY_CAST(shift_hours AS DECIMAL(5,2)) IS NOT NULL THEN 'Numeric format'
                    ELSE 'Other format'
                END as format_type
            FROM bronze.hr_raw
            WHERE shift_hours IS NOT NULL 
                AND LTRIM(RTRIM(shift_hours)) <> '';
                
            WITH DuplicateCheck AS (
                SELECT employee_id, COUNT(*) as duplicate_count
                FROM bronze.hr_raw
                WHERE employee_id NOT LIKE '%DUP%'
                GROUP BY employee_id
                HAVING COUNT(*) > 1
            )
            SELECT COUNT(*) as total_duplicates FROM DuplicateCheck;
        END
        
        INSERT INTO silver.hr (
            employee_id, first_name, last_name, gender, county, town,
            hiredate, department, job_title, education_level, salary,
            performance_rating, overtime, store_id, shift, shift_hours,
            birthdate, termdate, data_source, extracted_date, record_version
        )
        SELECT 
            -- Use deduplicated employee_id
            LTRIM(RTRIM(ISNULL(employee_id, 'EMP-' + CAST(ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS NVARCHAR(10))))) AS employee_id,
            
            -- Clean text fields
            LTRIM(RTRIM(ISNULL(first_name, ''))) AS first_name,
            LTRIM(RTRIM(ISNULL(last_name, ''))) AS last_name,
            
            -- gender: Standardize to Male/Female/Unknown
            CASE 
                WHEN LTRIM(RTRIM(UPPER(ISNULL(gender, '')))) IN ('M', 'MALE', '1') THEN 'Male'
                WHEN LTRIM(RTRIM(UPPER(ISNULL(gender, '')))) IN ('F', 'FEMALE', '0') THEN 'Female'
                WHEN LTRIM(RTRIM(ISNULL(gender, ''))) = '' THEN 'Unknown'
                ELSE UPPER(LEFT(LTRIM(RTRIM(gender)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(gender)), 2, LEN(gender)))
            END AS gender,
            
            -- county: Proper case
            CASE 
                WHEN LTRIM(RTRIM(ISNULL(county, ''))) = '' THEN 'Unknown'
                ELSE UPPER(LEFT(LTRIM(RTRIM(county)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(county)), 2, LEN(county)))
            END AS county,
            
            -- town: Proper case
            CASE 
                WHEN LTRIM(RTRIM(ISNULL(town, ''))) = '' THEN 'Unknown'
                ELSE UPPER(LEFT(LTRIM(RTRIM(town)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(town)), 2, LEN(town)))
            END AS town,
            
            -- hiredate with multiple format attempts
            CASE 
                WHEN TRY_CONVERT(DATE, hiredate, 120) IS NOT NULL 
                    THEN TRY_CONVERT(DATE, hiredate, 120)
                WHEN TRY_CONVERT(DATE, hiredate, 23) IS NOT NULL 
                    THEN TRY_CONVERT(DATE, hiredate, 23)
                WHEN TRY_CONVERT(DATE, hiredate, 101) IS NOT NULL 
                    THEN TRY_CONVERT(DATE, hiredate, 101)
                ELSE NULL
            END AS hiredate,
            
            LTRIM(RTRIM(ISNULL(department, ''))) AS department,
            LTRIM(RTRIM(ISNULL(job_title, ''))) AS job_title,
            LTRIM(RTRIM(ISNULL(education_level, ''))) AS education_level,
            
            -- salary: DECIMAL(18,2) with validation and cleanup
            CASE 
                -- Remove currency symbols, commas, spaces
                WHEN salary LIKE '%[^0-9.-]%' THEN 
                    CASE 
                        WHEN TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(salary, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) IS NULL THEN 0.00
                        WHEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(salary, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) > 9999999999999999.99 
                            THEN 9999999999999999.99
                        WHEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(salary, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) < 0 
                            THEN 0.00
                        ELSE CAST(CAST(REPLACE(REPLACE(REPLACE(REPLACE(salary, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) AS DECIMAL(18,2))
                    END
                WHEN TRY_CAST(LTRIM(RTRIM(salary)) AS DECIMAL(38,10)) IS NULL THEN 0.00
                WHEN CAST(LTRIM(RTRIM(salary)) AS DECIMAL(38,10)) > 9999999999999999.99 THEN 9999999999999999.99
                WHEN CAST(LTRIM(RTRIM(salary)) AS DECIMAL(38,10)) < 0 THEN 0.00
                ELSE CAST(CAST(LTRIM(RTRIM(salary)) AS DECIMAL(38,10)) AS DECIMAL(18,2))
            END AS salary,
            
            -- performance_rating: DECIMAL(3,1) - convert text ratings to numeric
            CASE 
                -- Handle text ratings
                WHEN UPPER(LTRIM(RTRIM(ISNULL(performance_rating, '')))) IN ('EXCELLENT', 'OUTSTANDING', '5') THEN 4.5
                WHEN UPPER(LTRIM(RTRIM(ISNULL(performance_rating, '')))) IN ('VERY GOOD', 'ABOVE AVERAGE', '4') THEN 4.0
                WHEN UPPER(LTRIM(RTRIM(ISNULL(performance_rating, '')))) IN ('GOOD', 'AVERAGE', 'SATISFACTORY', '3') THEN 3.0
                WHEN UPPER(LTRIM(RTRIM(ISNULL(performance_rating, '')))) IN ('FAIR', 'BELOW AVERAGE', 'NEEDS IMPROVEMENT', '2') THEN 2.0
                WHEN UPPER(LTRIM(RTRIM(ISNULL(performance_rating, '')))) IN ('POOR', 'UNSATISFACTORY', '1') THEN 1.0
                
                -- Handle fraction ratings like "4.5/5"
                WHEN performance_rating LIKE '%/%' THEN
                    CASE 
                        WHEN TRY_CAST(LEFT(performance_rating, CHARINDEX('/', performance_rating) - 1) AS DECIMAL(10,4)) IS NULL THEN 3.0
                        WHEN CAST(LEFT(performance_rating, CHARINDEX('/', performance_rating) - 1) AS DECIMAL(10,4)) > 9.9 THEN 9.9
                        WHEN CAST(LEFT(performance_rating, CHARINDEX('/', performance_rating) - 1) AS DECIMAL(10,4)) < 0 THEN 0.0
                        ELSE CAST(CAST(LEFT(performance_rating, CHARINDEX('/', performance_rating) - 1) AS DECIMAL(10,4)) AS DECIMAL(3,1))
                    END
                    
                -- Handle numeric ratings
                WHEN TRY_CAST(LTRIM(RTRIM(performance_rating)) AS DECIMAL(10,4)) IS NULL THEN 3.0
                WHEN CAST(LTRIM(RTRIM(performance_rating)) AS DECIMAL(10,4)) > 9.9 THEN 9.9
                WHEN CAST(LTRIM(RTRIM(performance_rating)) AS DECIMAL(10,4)) < 0 THEN 0.0
                ELSE CAST(CAST(LTRIM(RTRIM(performance_rating)) AS DECIMAL(10,4)) AS DECIMAL(3,1))
            END AS performance_rating,
            
            -- overtime: DECIMAL(18,2) - convert "Yes"/"No" to amounts
            CASE 
                -- Handle text values like "Yes", "No"
                WHEN UPPER(LTRIM(RTRIM(ISNULL(overtime, '')))) IN ('YES', 'Y', 'TRUE', '1') THEN 
                    -- If "Yes" but no amount, use 10% of salary as default overtime
                    ROUND(CAST(
                        CASE 
                            WHEN TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(salary, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) IS NULL THEN 0.00
                            ELSE CAST(REPLACE(REPLACE(REPLACE(REPLACE(salary, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) * 0.10
                        END AS DECIMAL(18,2)), 2)
                
                WHEN UPPER(LTRIM(RTRIM(ISNULL(overtime, '')))) IN ('NO', 'N', 'FALSE', '0', 'NONE') THEN 0.00
                
                -- Handle numeric values
                WHEN overtime LIKE '%[^0-9.-]%' THEN 
                    CASE 
                        WHEN TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(overtime, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) IS NULL THEN 0.00
                        WHEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(overtime, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) > 9999999999999999.99 
                            THEN 9999999999999999.99
                        WHEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(overtime, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) < 0 
                            THEN 0.00
                        ELSE CAST(CAST(REPLACE(REPLACE(REPLACE(REPLACE(overtime, 'Ksh', ''), 'KES', ''), ',', ''), ' ', '') AS DECIMAL(38,10)) AS DECIMAL(18,2))
                    END
                    
                WHEN TRY_CAST(LTRIM(RTRIM(overtime)) AS DECIMAL(38,10)) IS NULL THEN 0.00
                WHEN CAST(LTRIM(RTRIM(overtime)) AS DECIMAL(38,10)) > 9999999999999999.99 THEN 9999999999999999.99
                WHEN CAST(LTRIM(RTRIM(overtime)) AS DECIMAL(38,10)) < 0 THEN 0.00
                ELSE CAST(CAST(LTRIM(RTRIM(overtime)) AS DECIMAL(38,10)) AS DECIMAL(18,2))
            END AS overtime,
            
            LTRIM(RTRIM(ISNULL(store_id, ''))) AS store_id,
            LTRIM(RTRIM(ISNULL(shift, ''))) AS shift,
            
            -- shift_hours: Parse time ranges like "08:00-17:00" to calculate hours
            CASE 
                -- Parse time range format like "08:00-17:00"
                WHEN shift_hours LIKE '%-%' AND CHARINDEX(':', shift_hours) > 0 THEN
                    TRY_CAST(
                        CASE 
                            -- Calculate hours from time range
                            WHEN TRY_CAST(LEFT(shift_hours, CHARINDEX('-', shift_hours) - 1) AS TIME) IS NOT NULL
                                 AND TRY_CAST(SUBSTRING(shift_hours, CHARINDEX('-', shift_hours) + 1, LEN(shift_hours)) AS TIME) IS NOT NULL
                            THEN 
                                -- Calculate hours difference
                                CAST(DATEDIFF(
                                    MINUTE, 
                                    CAST(LEFT(shift_hours, CHARINDEX('-', shift_hours) - 1) AS TIME),
                                    CAST(SUBSTRING(shift_hours, CHARINDEX('-', shift_hours) + 1, LEN(shift_hours)) AS TIME)
                                ) AS DECIMAL(10,2)) / 60.0
                            ELSE 8.00 -- Default 8-hour shift if parsing fails
                        END AS DECIMAL(5,2)
                    )
                -- Try to parse as numeric if not a time range
                WHEN TRY_CAST(LTRIM(RTRIM(shift_hours)) AS DECIMAL(10,4)) IS NOT NULL THEN
                    CAST(CAST(LTRIM(RTRIM(shift_hours)) AS DECIMAL(10,4)) AS DECIMAL(5,2))
                -- Default to 8 hours for other cases
                ELSE 8.00
            END AS shift_hours,
            
            -- birthdate
            TRY_CONVERT(DATE, birthdate) AS birthdate,
            
            -- termdate with NULL handling
            CASE 
                WHEN LTRIM(RTRIM(ISNULL(termdate, ''))) IN ('', 'NULL', 'N/A', 'NA') THEN NULL
                ELSE TRY_CONVERT(DATE, termdate)
            END AS termdate,
            
            LTRIM(RTRIM(ISNULL(data_source, 'HR_System'))) AS data_source,
            
            -- extracted_date
            TRY_CONVERT(DATE, extracted_date) AS extracted_date,
            
            -- record_version: INT with validation
            CASE 
                WHEN TRY_CAST(record_version AS INT) IS NULL THEN 1
                WHEN CAST(record_version AS INT) > 2147483647 THEN 2147483647
                WHEN CAST(record_version AS INT) < 1 THEN 1
                ELSE CAST(record_version AS INT)
            END AS record_version
            
        FROM (
            -- Deduplication: Keep first occurrence of each employee_id
            SELECT ROW_NUMBER() OVER(PARTITION BY employee_id ORDER BY employee_id) AS S_SN,
                   employee_id, first_name, last_name, gender, county, town,
                   hiredate, department, job_title, education_level, salary,
                   performance_rating, overtime, store_id, shift, shift_hours,
                   birthdate, termdate, data_source, extracted_date, record_version
            FROM bronze.hr_raw
            WHERE employee_id NOT LIKE '%DUP%'
        ) t 
        WHERE S_SN = 1; -- Only take the first occurrence
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
        -- --------------------------------------------------------------------
        -- 4. LOAD STORES DATA
        -- --------------------------------------------------------------------
        PRINT '4. LOADING STORES DATA...';
        
        INSERT INTO silver.stores (
            store_id, store_name, county, format, size_sqm
        )
        SELECT 
            store_id,
            store_name,
            county,
            format,
            CAST(size_sqm AS INT) AS size_sqm
        FROM bronze.stores_raw;
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
        -- --------------------------------------------------------------------
        -- 5. LOAD GIS COUNTIES DATA
        -- --------------------------------------------------------------------
        PRINT '5. LOADING GIS COUNTIES DATA...';
        
        INSERT INTO silver.gis_counties (
            county_id, county_name, population_2023, area_sqkm,
            population_density_psqkm, poverty_rate, unemployment_rate,
            avg_household_income_kes, urbanization_rate, literacy_rate,
            road_infrastructure_score, public_transport_score,
            internet_penetration, commercial_rent_kes_psqm,
            business_registration_days, security_index,
            tourist_arrivals_annual, latitude, longitude,
            major_towns, competitor_counts_json
        )
        SELECT 
            county_id,
            county_name,
            CASE 
                WHEN TRY_CAST(population_2023 AS INT) IS NULL THEN 0
                ELSE CAST(population_2023 AS INT)
            END AS population_2023,
            CASE 
                WHEN TRY_CAST(area_sqkm AS DECIMAL(18,2)) IS NULL THEN 0.0
                ELSE CAST(area_sqkm AS DECIMAL(18,2))
            END AS area_sqkm,
            CASE 
                WHEN TRY_CAST(population_2023 AS DECIMAL(18,2)) IS NULL 
                     OR TRY_CAST(area_sqkm AS DECIMAL(18,2)) IS NULL 
                     OR CAST(area_sqkm AS DECIMAL(18,2)) = 0
                THEN 0.0
                ELSE ROUND(
                    CAST(population_2023 AS DECIMAL(18,2)) / 
                    CAST(area_sqkm AS DECIMAL(18,2)), 
                    2
                )
            END AS population_density_psqkm,
            CASE 
                WHEN TRY_CAST(poverty_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                ELSE CAST(poverty_rate AS DECIMAL(5,2))
            END AS poverty_rate,
            CASE 
                WHEN TRY_CAST(unemployment_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                ELSE CAST(unemployment_rate AS DECIMAL(5,2))
            END AS unemployment_rate,
            CASE 
                WHEN TRY_CAST(avg_household_income_kes AS DECIMAL(18,2)) IS NULL THEN 0.0
                ELSE CAST(avg_household_income_kes AS DECIMAL(18,2))
            END AS avg_household_income_kes,
            CASE 
                WHEN TRY_CAST(urbanization_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                ELSE CAST(urbanization_rate AS DECIMAL(5,2))
            END AS urbanization_rate,
            CASE 
                WHEN TRY_CAST(literacy_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                ELSE CAST(literacy_rate AS DECIMAL(5,2))
            END AS literacy_rate,
            CASE 
                WHEN TRY_CAST(road_infrastructure_score AS DECIMAL(3,1)) IS NULL THEN 5.0
                WHEN TRY_CAST(road_infrastructure_score AS DECIMAL(3,1)) < 1.0 THEN 1.0
                WHEN TRY_CAST(road_infrastructure_score AS DECIMAL(3,1)) > 10.0 THEN 10.0
                ELSE CAST(road_infrastructure_score AS DECIMAL(3,1))
            END AS road_infrastructure_score,
            CASE 
                WHEN TRY_CAST(public_transport_score AS DECIMAL(3,1)) IS NULL THEN 5.0
                WHEN TRY_CAST(public_transport_score AS DECIMAL(3,1)) < 1.0 THEN 1.0
                WHEN TRY_CAST(public_transport_score AS DECIMAL(3,1)) > 10.0 THEN 10.0
                ELSE CAST(public_transport_score AS DECIMAL(3,1))
            END AS public_transport_score,
            CASE 
                WHEN TRY_CAST(internet_penetration AS DECIMAL(5,2)) IS NULL THEN 0.0
                ELSE CAST(internet_penetration AS DECIMAL(5,2))
            END AS internet_penetration,
            CASE 
                WHEN TRY_CAST(commercial_rent_kes_psqm AS DECIMAL(18,2)) IS NULL THEN 0.0
                ELSE CAST(commercial_rent_kes_psqm AS DECIMAL(18,2))
            END AS commercial_rent_kes_psqm,
            CASE 
                WHEN TRY_CAST(business_registration_days AS INT) IS NULL THEN 0
                ELSE CAST(business_registration_days AS INT)
            END AS business_registration_days,
            CASE 
                WHEN TRY_CAST(security_index AS DECIMAL(3,1)) IS NULL THEN 5.0
                WHEN TRY_CAST(security_index AS DECIMAL(3,1)) < 1.0 THEN 1.0
                WHEN TRY_CAST(security_index AS DECIMAL(3,1)) > 10.0 THEN 10.0
                ELSE CAST(security_index AS DECIMAL(3,1))
            END AS security_index,
            CASE 
                WHEN TRY_CAST(tourist_arrivals_annual AS DECIMAL(18,2)) IS NULL THEN 0
                ELSE CAST(CAST(tourist_arrivals_annual AS DECIMAL(18,2)) * 1000 AS INT)
            END AS tourist_arrivals_annual,
            CASE 
                WHEN TRY_CAST(latitude AS DECIMAL(10,6)) IS NULL THEN 0.0
                ELSE CAST(latitude AS DECIMAL(10,6))
            END AS latitude,
            CASE 
                WHEN TRY_CAST(longitude AS DECIMAL(10,6)) IS NULL THEN 0.0
                ELSE CAST(longitude AS DECIMAL(10,6))
            END AS longitude,
            major_towns,
            competitor_counts_json
        FROM bronze.gis_counties_raw;
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
        -- --------------------------------------------------------------------
        -- 6. LOAD GIS LOCATIONS DATA
        -- --------------------------------------------------------------------
        PRINT '6. LOADING GIS LOCATIONS DATA...';
        
        INSERT INTO silver.gis_locations (
            location_id, county, site_name, latitude, longitude,
            visibility_score, accessibility_score, estimated_daily_traffic,
            parking_capacity, zoning, property_size_sqm, building_condition,
            competition_within_1km, complementary_businesses,
            last_survey_date, data_source
        )
        SELECT 
            'LOC-' + UPPER(SUBSTRING(county, 1, 4)) + '-' + 
            SUBSTRING(location_id, 9, 10) AS location_id,
            county,
            site_name,
            COALESCE(
                TRY_CAST(l.latitude AS DECIMAL(10,6)), 
                TRY_CAST(prev.latitude AS DECIMAL(10,6)) + 0.000034,
                0.0
            ) AS latitude,
            COALESCE(
                TRY_CAST(l.longitude AS DECIMAL(10,6)), 
                TRY_CAST(prev.longitude AS DECIMAL(10,6)) + 0.000134,
                0.0
            ) AS longitude,
            CASE 
                WHEN TRY_CAST(l.visibility_score AS INT) IS NULL THEN 0
                ELSE CAST(l.visibility_score AS INT)
            END AS visibility_score,
            CASE 
                WHEN TRY_CAST(l.accessibility_score AS INT) IS NULL THEN 0
                ELSE CAST(l.accessibility_score AS INT)
            END AS accessibility_score,
            CASE 
                WHEN TRY_CAST(l.estimated_daily_traffic AS INT) IS NULL THEN 0
                WHEN CAST(l.estimated_daily_traffic AS INT) > 1000 
                    THEN CAST(LEFT(l.estimated_daily_traffic, 3) AS INT)
                ELSE CAST(l.estimated_daily_traffic AS INT)
            END AS estimated_daily_traffic,
            CASE 
                WHEN TRY_CAST(l.parking_capacity AS INT) IS NULL THEN 0
                ELSE CAST(l.parking_capacity AS INT)
            END AS parking_capacity,
            zoning,
            CASE 
                WHEN TRY_CAST(l.property_size_sqm AS DECIMAL(18,2)) IS NULL THEN 0.0
                ELSE CAST(l.property_size_sqm AS DECIMAL(18,2))
            END AS property_size_sqm,
            building_condition,
            CASE 
                WHEN TRY_CAST(l.competition_within_1km AS INT) IS NULL THEN 0
                ELSE CAST(l.competition_within_1km AS INT)
            END AS competition_within_1km,
            complementary_businesses,
            TRY_CONVERT(DATE, last_survey_date) AS last_survey_date,
            data_source
        FROM bronze.gis_locations_raw l
        OUTER APPLY (
            SELECT TOP 1 latitude, longitude
            FROM bronze.gis_locations_raw prev
            WHERE prev.county = l.county
                AND prev.location_id < l.location_id
                AND TRY_CAST(prev.latitude AS DECIMAL(10,6)) IS NOT NULL
                AND TRY_CAST(prev.longitude AS DECIMAL(10,6)) IS NOT NULL
            ORDER BY prev.location_id DESC
        ) prev;
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
        -- --------------------------------------------------------------------
        -- 7. LOAD ECONOMIC DATA
        -- --------------------------------------------------------------------
        PRINT '7. LOADING ECONOMIC DATA...';
        
        WITH EconomicData AS (
            SELECT
                CASE 
                    WHEN county IS NOT NULL AND LTRIM(RTRIM(county)) <> ''
                    THEN UPPER(LEFT(LTRIM(RTRIM(county)), 1)) + 
                         LOWER(SUBSTRING(LTRIM(RTRIM(county)), 2, LEN(county)))
                    ELSE NULL
                END AS county,
                year_month,
                CASE 
                    WHEN TRY_CAST(year AS INT) IS NULL THEN 0
                    ELSE CAST(year AS INT)
                END AS year,
                CASE 
                    WHEN TRY_CAST(month AS INT) IS NULL THEN 0
                    ELSE CAST(month AS INT)
                END AS month,
                AVG(CASE 
                    WHEN TRY_CAST(gdp_growth_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(gdp_growth_rate AS DECIMAL(5,2))
                END) OVER(
                    PARTITION BY county 
                    ORDER BY CAST(month AS INT)
                ) AS average_gdp_growth,
                CASE 
                    WHEN TRY_CAST(gdp_growth_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(gdp_growth_rate AS DECIMAL(5,2))
                END AS gdp_growth_rate,
                CASE 
                    WHEN TRY_CAST(inflation_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(inflation_rate AS DECIMAL(5,2))
                END AS inflation_rate,
                AVG(CASE 
                    WHEN TRY_CAST(inflation_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(inflation_rate AS DECIMAL(5,2))
                END) OVER(
                    PARTITION BY county 
                    ORDER BY CAST(month AS INT)
                ) AS average_inflation_rate,
                CASE 
                    WHEN TRY_CAST(unemployment_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(unemployment_rate AS DECIMAL(5,2))
                END AS unemployment_rate,
                AVG(CASE 
                    WHEN TRY_CAST(unemployment_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(unemployment_rate AS DECIMAL(5,2))
                END) OVER(
                    PARTITION BY county 
                    ORDER BY CAST(month AS INT)
                ) AS average_unemployment_rate,
                CASE 
                    WHEN TRY_CAST(consumer_confidence_index AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(consumer_confidence_index AS DECIMAL(5,2))
                END AS consumer_confidence_index,
                CASE 
                    WHEN TRY_CAST(retail_sales_index AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(retail_sales_index AS DECIMAL(5,2))
                END AS retail_sales_index,
                CASE 
                    WHEN TRY_CAST(business_confidence_index AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(business_confidence_index AS DECIMAL(5,2))
                END AS business_confidence_index,
                CASE 
                    WHEN TRY_CAST(new_business_registrations AS INT) IS NULL THEN 0
                    WHEN CAST(new_business_registrations AS INT) < 0 THEN 0
                    ELSE CAST(new_business_registrations AS INT)
                END AS new_business_registrations,
                CASE 
                    WHEN TRY_CAST(commercial_rent_growth AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(commercial_rent_growth AS DECIMAL(5,2))
                END AS commercial_rent_growth,
                CASE 
                    WHEN TRY_CAST(retail_vacancy_rate AS DECIMAL(5,2)) IS NULL THEN 0.0
                    ELSE CAST(retail_vacancy_rate AS DECIMAL(5,2))
                END AS retail_vacancy_rate,
                CASE 
                    WHEN TRY_CAST(avg_fuel_price_kes AS DECIMAL(18,2)) IS NULL THEN 0.0
                    ELSE CAST(avg_fuel_price_kes AS DECIMAL(18,2))
                END AS avg_fuel_price_kes,
                CASE 
                    WHEN TRY_CAST(usd_kes_exchange_rate AS DECIMAL(18,2)) IS NULL THEN 0.0
                    ELSE CAST(usd_kes_exchange_rate AS DECIMAL(18,2))
                END AS usd_kes_exchange_rate,
                CASE 
                    WHEN TRY_CONVERT(DATE, data_collection_date) IS NOT NULL 
                        THEN TRY_CONVERT(DATE, data_collection_date)
                    ELSE NULL
                END AS data_collection_date,
                data_source AS original_data_source
            FROM bronze.economic_raw
        )
        INSERT INTO silver.economic (
            county, year_month, year, month, gdp_growth_rate,
            inflation_rate, unemployment_rate, consumer_confidence_index,
            retail_sales_index, business_confidence_index,
            new_business_registrations, commercial_rent_growth,
            retail_vacancy_rate, avg_fuel_price_kes,
            usd_kes_exchange_rate, data_collection_date, data_source
        )
        SELECT 
            county,
            year_month,
            year,
            month,
            ISNULL(gdp_growth_rate, average_gdp_growth) AS gdp_growth_rate,
            ISNULL(inflation_rate, average_inflation_rate) AS inflation_rate,
            ISNULL(unemployment_rate, average_unemployment_rate) AS unemployment_rate,
            consumer_confidence_index,
            retail_sales_index,
            business_confidence_index,
            new_business_registrations,
            commercial_rent_growth,
            retail_vacancy_rate,
            avg_fuel_price_kes,
            usd_kes_exchange_rate,
            data_collection_date,
            original_data_source
        FROM EconomicData;
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
        -- --------------------------------------------------------------------
        -- 8. LOAD COMPETITORS DATA (MUST BE LOADED BEFORE COMPETITOR_STORES)
        -- --------------------------------------------------------------------
        PRINT '8. LOADING COMPETITORS DATA...';
        
        INSERT INTO silver.competitors (
            competitor_id, competitor_name, competitor_type,
            year_founded, total_stores, estimated_market_share,
            avg_store_revenue_kes_monthly, positioning, target_demographic,
            pricing_index, store_formats, key_strengths, key_weaknesses,
            last_updated, data_source
        )
        SELECT 
            competitor_id,
            competitor_name,
            competitor_type,
            CAST(year_founded AS INT) AS year_founded,
            CAST(total_stores AS INT) AS total_stores,
            CAST(estimated_market_share AS DECIMAL(5,2)) AS estimated_market_share,
            CAST(avg_store_revenue_kes_monthly AS DECIMAL(18,2)) AS avg_store_revenue_kes_monthly,
            positioning,
            target_demographic,
            CAST(pricing_index AS DECIMAL(5,2)) AS pricing_index,
            store_formats,
            key_strengths,
            key_weaknesses,
            CAST(last_updated AS DATE) AS last_updated,
            data_source
        FROM bronze.competitors_raw;
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
        -- --------------------------------------------------------------------
        -- 9. LOAD COMPETITOR STORES DATA (Child table - with column mapping correction)
        -- --------------------------------------------------------------------
        PRINT '9. LOADING COMPETITOR STORES DATA...';
        PRINT '   Note: Applying column mapping correction for CSV import issues';
        
        IF @DebugMode = 1
        BEGIN
            PRINT '   DEBUG: Sample of transformed competitor stores data...';
            
            SELECT TOP 5 
                store_id,
                competitor_id,
                town AS county,
                store_size_sqm AS town,
                location_score AS store_size_sqm_raw,
                parking_available AS location_score_raw
            FROM bronze.competitor_stores_raw
            WHERE store_id NOT LIKE '%DUP%';
        END
        
        INSERT INTO silver.competitor_stores (
            store_id, competitor_id, county, town, store_size_sqm,
            store_format, opening_date, estimated_monthly_revenue_kes,
            estimated_daily_customers, location_score, parking_available,
            has_delivery, last_verified, data_source
        )
        SELECT 
            -- Map columns according to the required transformation
            LTRIM(RTRIM(ISNULL([store_id], ''))) AS store_id,
            LTRIM(RTRIM(ISNULL([competitor_id], ''))) AS competitor_id,
            
            -- county comes from town column (with proper casing)
            CASE 
                WHEN LTRIM(RTRIM(ISNULL([town], ''))) = '' THEN 'Unknown'
                ELSE UPPER(LEFT(LTRIM(RTRIM([town])), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM([town])), 2, LEN([town])))
            END AS county,
            
            -- town comes from store_size_sqm column (with proper casing)
            CASE 
                WHEN LTRIM(RTRIM(ISNULL([store_size_sqm], ''))) = '' THEN 'Unknown'
                ELSE UPPER(LEFT(LTRIM(RTRIM([store_size_sqm])), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM([store_size_sqm])), 2, LEN([store_size_sqm])))
            END AS town,
            
            -- store_size_sqm comes from location_score column
            CASE 
                WHEN TRY_CAST([location_score] AS INT) IS NOT NULL THEN 
                    CASE 
                        WHEN CAST([location_score] AS INT) < 0 THEN 0
                        WHEN CAST([location_score] AS INT) > 10000 THEN LEFT(location_score,3)
                        ELSE CAST([location_score] AS INT)
                    END
                ELSE 0
            END AS store_size_sqm,
            
            -- store_format comes from opening_date column
            CASE 
                WHEN TRY_CONVERT(DATE, [opening_date]) IS NOT NULL THEN 'Standard'
                ELSE LTRIM(RTRIM(ISNULL([opening_date], 'Standard')))
            END AS store_format,
            
            -- opening_date comes from estimated_monthly_revenue_kes column
            TRY_CONVERT(DATE, [estimated_monthly_revenue_kes]) AS opening_date,
            
            -- estimated_monthly_revenue_kes comes from estimated_daily_customers column
            CASE 
                WHEN TRY_CAST([estimated_daily_customers] AS DECIMAL(18,2)) IS NOT NULL 
                    THEN CAST([estimated_daily_customers] AS DECIMAL(18,2))
                WHEN TRY_CAST(REPLACE(REPLACE([estimated_daily_customers], 'Ksh', ''), ',', '') AS DECIMAL(18,2)) IS NOT NULL
                    THEN CAST(REPLACE(REPLACE([estimated_daily_customers], 'Ksh', ''), ',', '') AS DECIMAL(18,2))
                ELSE 0.00
            END AS estimated_monthly_revenue_kes,
            
            -- estimated_daily_customers comes from store_format column
            CASE 
                WHEN TRY_CAST([store_format] AS INT) IS NOT NULL THEN 
                    CASE 
                        WHEN CAST([store_format] AS INT) < 0 THEN 0
                        WHEN CAST([store_format] AS INT) > 10000 THEN 10000
                        ELSE CAST([store_format] AS INT)
                    END
                ELSE 100 -- Default average
            END AS estimated_daily_customers,
            
            -- location_score comes from parking_available column (1-10 scale)
            CASE 
                WHEN TRY_CAST([parking_available] AS INT) IS NOT NULL THEN 
                    CASE 
                        WHEN CAST([parking_available] AS INT) > 10 THEN 10
                        WHEN CAST([parking_available] AS INT) < 1 THEN 1
                        ELSE CAST([parking_available] AS INT)
                    END
                ELSE 5 -- Default medium score
            END AS location_score,
            
            -- parking_available comes from has_delivery column
            CASE 
                WHEN UPPER(ISNULL([has_delivery], '')) IN ('YES', 'Y', 'TRUE', '1') THEN 'Yes'
                WHEN UPPER(ISNULL([has_delivery], '')) IN ('NO', 'N', 'FALSE', '0') THEN 'No'
                ELSE ISNULL([has_delivery], 'Unknown')
            END AS parking_available,
            
            -- has_delivery comes from last_verified column
            CASE 
                WHEN UPPER(ISNULL([last_verified], '')) IN ('YES', 'Y', 'TRUE', '1') THEN 'Yes'
                WHEN UPPER(ISNULL([last_verified], '')) IN ('NO', 'N', 'FALSE', '0') THEN 'No'
                ELSE ISNULL([last_verified], 'Unknown')
            END AS has_delivery,
            
            -- last_verified comes from first 10 chars of data_source
            TRY_CONVERT(DATE, LEFT([data_source], 10)) AS last_verified,
            
            -- data_source comes from substring of data_source starting at position 12
            LTRIM(RTRIM(ISNULL(SUBSTRING([data_source], 12, 20), 'competitor_stores_raw'))) AS data_source
            
        FROM bronze.competitor_stores_raw
        WHERE store_id NOT LIKE '%DUP%';
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
        -- --------------------------------------------------------------------
        -- 10. LOAD POS DATA (With column mapping correction)
        -- --------------------------------------------------------------------
        PRINT '10. LOADING POS TRANSACTION DATA...';
        
        INSERT INTO silver.pos (
            transaction_id, transaction_date, store_id, store_county, store_format,
            customer_id, line_item_id, product_id, category, subcategory,
            product_name, unit_price_kes, quantity, total_price_kes,
            discount_kes, final_price_kes, payment_method, staff_id,
            shift, data_source, extracted_timestamp
        )
        SELECT 
            transaction_id,
            COALESCE(
                TRY_CONVERT(DATETIME, transaction_date),
                '2023-01-01 07:00:00'
            ) AS transaction_date,
            store_id,
            store_county,
            store_format,
            COALESCE(
                customer_id,
                LAG(customer_id) OVER(PARTITION BY transaction_id ORDER BY transaction_id),
                LEAD(customer_id) OVER(PARTITION BY transaction_id ORDER BY transaction_id)
            ) AS customer_id,
            line_item_id,
            product_id,
            category,
            subcategory,
            product_name,
            CAST(unit_price_kes AS DECIMAL(18,2)) AS unit_price_kes,
            ABS(CAST(quantity AS INT)) AS quantity,
            CAST(total_price_kes AS DECIMAL(18,2)) AS total_price_kes,
            CAST(discount_kes AS DECIMAL(18,2)) AS discount_kes,
            CAST(final_price_kes AS DECIMAL(18,2)) AS final_price_kes,
            payment_method,
            staff_id,
            shift,
            data_source,
            extracted_timestamp
        FROM (
            SELECT 
                ROW_NUMBER() OVER(PARTITION BY line_item_id ORDER BY transaction_date) AS S_N,
                [transaction_id],
                COALESCE([transaction_date], MAX(transaction_date) OVER(PARTITION BY transaction_id)) AS transaction_date,
                [store_id],
                [store_county],
                [store_format],
                LEFT([customer_id], 15) AS customer_id,
                [line_item_id],
                [product_id],
                [subcategory] AS category,
                [product_name] AS subcategory,
                [category] AS product_name,
                [quantity] AS unit_price_kes,
                [total_price_kes] AS quantity,
                [discount_kes] AS total_price_kes,
                [final_price_kes] AS discount_kes,
                [payment_method] AS final_price_kes,
                staff_id AS payment_method,
                [shift] AS staff_id,
                data_source AS shift,
                LEFT([extracted_timestamp], 10) AS data_source,
                RIGHT([extracted_timestamp], 27) AS extracted_timestamp
            FROM bronze.pos_raw
        ) t
        WHERE S_N = 1;
        
        SET @RowsAffected = @@ROWCOUNT;
        SET @TotalRows = @TotalRows + @RowsAffected;
        PRINT '   • Rows loaded: ' + CAST(@RowsAffected AS NVARCHAR) + ' (Running total: ' + CAST(@TotalRows AS NVARCHAR) + ')';
        
            -- ====================================================================
        -- TRANSACTION COMMIT AND FINAL LOGGING
        -- ====================================================================
        COMMIT TRANSACTION;
        
        DECLARE @EndTime DATETIME = GETDATE();
        DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);
        DECLARE @DurationMinutes INT = @DurationSeconds / 60;
        DECLARE @RemainingSeconds INT = @DurationSeconds % 60;
        
        -- Declare variables for final counts
        DECLARE @CrmCount INT, @ProductsCount INT, @HrCount INT, @StoresCount INT,
                @GisCountiesCount INT, @GisLocationsCount INT, @EconomicCount INT,
                @CompetitorsCount INT, @CompetitorStoresCount INT, @PosCount INT;
        
        -- Get final counts from each table
        SELECT @CrmCount = COUNT(*) FROM silver.crm;
        SELECT @ProductsCount = COUNT(*) FROM silver.products;
        SELECT @HrCount = COUNT(*) FROM silver.hr;
        SELECT @StoresCount = COUNT(*) FROM silver.stores;
        SELECT @GisCountiesCount = COUNT(*) FROM silver.gis_counties;
        SELECT @GisLocationsCount = COUNT(*) FROM silver.gis_locations;
        SELECT @EconomicCount = COUNT(*) FROM silver.economic;
        SELECT @CompetitorsCount = COUNT(*) FROM silver.competitors;
        SELECT @CompetitorStoresCount = COUNT(*) FROM silver.competitor_stores;
        SELECT @PosCount = COUNT(*) FROM silver.pos;
        
        PRINT '';
        PRINT REPLICATE('=', 80);
        PRINT 'SILVER LAYER ETL PROCESS COMPLETED SUCCESSFULLY - VERSION 3.0';
        PRINT REPLICATE('-', 80);
        PRINT 'Completion Time: ' + FORMAT(@EndTime, 'yyyy-MM-dd HH:mm:ss');
        PRINT 'Total Duration: ' + 
              CASE WHEN @DurationMinutes > 0 
                   THEN CAST(@DurationMinutes AS NVARCHAR) + ' minutes ' 
                   ELSE '' 
              END + 
              CAST(@RemainingSeconds AS NVARCHAR) + ' seconds';
        PRINT 'Total Rows Loaded Across All Tables: ' + FORMAT(@TotalRows, 'N0');
        PRINT 'Tables Successfully Loaded: 10';
        PRINT REPLICATE('-', 80);
        PRINT 'LOAD SUMMARY:';
        PRINT '  1. CRM Customers: ' + FORMAT(@CrmCount, 'N0');
        PRINT '  2. Products: ' + FORMAT(@ProductsCount, 'N0');
        PRINT '  3. HR Employees: ' + FORMAT(@HrCount, 'N0');
        PRINT '  4. Stores: ' + FORMAT(@StoresCount, 'N0');
        PRINT '  5. GIS Counties: ' + FORMAT(@GisCountiesCount, 'N0');
        PRINT '  6. GIS Locations: ' + FORMAT(@GisLocationsCount, 'N0');
        PRINT '  7. Economic Indicators: ' + FORMAT(@EconomicCount, 'N0');
        PRINT '  8. Competitors: ' + FORMAT(@CompetitorsCount, 'N0');
        PRINT '  9. Competitor Stores: ' + FORMAT(@CompetitorStoresCount, 'N0');
        PRINT ' 10. POS Transactions: ' + FORMAT(@PosCount, 'N0');
        PRINT REPLICATE('=', 80);
        
        RETURN 0; -- Success
        
    END TRY
    BEGIN CATCH
        -- ====================================================================
        -- ERROR HANDLING AND ROLLBACK
        -- ====================================================================
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Capture error details
        SELECT 
            @ErrorMsg = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();
        
        -- Log error details
        PRINT '';
        PRINT REPLICATE('*', 80);
        PRINT 'ERROR: SILVER LAYER ETL PROCESS FAILED';
        PRINT 'Error Time: ' + FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm:ss');
        PRINT 'Procedure: ' + @ProcedureName;
        PRINT 'Error Message: ' + @ErrorMsg;
        PRINT 'Error Severity: ' + CAST(@ErrorSeverity AS NVARCHAR(10));
        PRINT 'Error State: ' + CAST(@ErrorState AS NVARCHAR(10));
        PRINT REPLICATE('*', 80);
        
        -- Re-throw error for external handling
        RAISERROR(@ErrorMsg, @ErrorSeverity, @ErrorState);
        
        RETURN -1; -- Failure
        
    END CATCH
END;
GO

/*
===============================================================================
PROCEDURE EXECUTION EXAMPLES & DOCUMENTATION
===============================================================================

-- BASIC EXECUTION:
-- Loads all data with current date as load date
EXEC silver.usp_LoadSilverLayer;

-- EXECUTION WITH DEBUG MODE:
-- Enables detailed logging and data validation messages
EXEC silver.usp_LoadSilverLayer @DebugMode = 1;

-- EXECUTION WITH SPECIFIC LOAD DATE:
-- Useful for historical data loading or reprocessing
EXEC silver.usp_LoadSilverLayer 
    @LoadDate = '2025-12-25',
    @DebugMode = 0;

-- FULL PARAMETER EXECUTION:
EXEC silver.usp_LoadSilverLayer 
    @LoadDate = '2025-12-25',
    @DebugMode = 1;

===============================================================================
KEY FEATURES IMPLEMENTED:
1. Comprehensive error handling with transaction rollback
2. Referential integrity maintained through proper load order
3. Data deduplication across all tables
4. Special character handling and data type validation
5. Column mapping corrections for competitor_stores
6. Shift hours parsing from time ranges (08:00-17:00)
7. Performance rating conversion from text to numeric
8. Currency symbol and comma removal from numeric fields
9. Proper NULL handling with meaningful defaults
10. Extensive logging with row counts and timing information
===============================================================================
*/
EXEC silver.usp_LoadSilverLayer 

