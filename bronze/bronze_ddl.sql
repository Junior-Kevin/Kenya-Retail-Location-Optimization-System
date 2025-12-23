/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates the staging tables in the 'bronze' schema for the 
    KenyaFreshRetail Supermarket. These tables serve as the 
    raw data landing zone before transformation.
    
    Key Features:
    - Drops existing tables if they exist to allow clean recreation
    - Creates 11 tables covering retail operations (POS, HR, CRM, etc.)
    - All columns use NVARCHAR for maximum data type flexibility
    - Includes tables for integration (HR-POS) and optional data enrichment
    
Database Context:
    - Schema: bronze (raw, unprocessed data)
    - Data Types: All NVARCHAR for bronze layer flexibility
    - Relationships: Foreign keys established in higher layers (silver/gold)
    
Usage Instructions:
    1. Run this script first to create the bronze schema and tables
    2. Use bronze.load_bronze stored procedure to populate data
    3. Ensure CSV files exist in the designated directory structure
    
Dependencies:
    - None (creates schema and tables independently)
    
Author: [Your Name/Team]
Version: 1.0
Created: 2025-12-23
===============================================================================
*/

-- ===========================================================================
-- SECTION 1: SCHEMA CREATION
-- ===========================================================================

-- Create the bronze schema if it doesn't exist
-- This schema serves as the raw data landing zone
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA bronze');
    PRINT 'Created schema: bronze';
END
ELSE
BEGIN
    PRINT 'Schema bronze already exists';
END
GO

-- ===========================================================================
-- SECTION 2: CORE RETAIL OPERATIONS TABLES
-- ===========================================================================

-- 1. CRM Raw Table - Customer Relationship Management data
-- Purpose: Stores customer demographic and behavioral data
-- Key Fields: customer_id, customer_segment, lifetime_value_kes
-- Integration: Links to POS transactions via customer_id
IF OBJECT_ID('bronze.crm_raw','U') IS NOT NULL
    DROP TABLE bronze.crm_raw;
CREATE TABLE bronze.crm_raw(
    customer_id                  NVARCHAR(100),  -- Unique customer identifier
    first_name                   NVARCHAR(100),  -- Customer first name
    last_name                    NVARCHAR(100),  -- Customer last name
    gender                       NVARCHAR(100),  -- M/F/Other
    phone                        NVARCHAR(100),  -- Contact phone number
    email                        NVARCHAR(100),  -- Contact email address
    county                       NVARCHAR(100),  -- County of residence
    area                         NVARCHAR(100),  -- Specific area/town
    customer_segment             NVARCHAR(100),  -- Segmentation (Premium/Regular/etc.)
    registration_date            NVARCHAR(100),  -- Date customer registered
    customer_status              NVARCHAR(100),  -- Active/Inactive/Lost
    last_purchase_date           NVARCHAR(100),  -- Date of last purchase
    purchase_frequency_monthly   NVARCHAR(100),  -- Average purchases per month
    avg_transaction_value_kes    NVARCHAR(100),  -- Average transaction amount
    lifetime_value_kes           NVARCHAR(100),  -- Total customer lifetime value
    preferred_store_format       NVARCHAR(100),  -- Preferred store type
    communication_preferences    NVARCHAR(100),  -- SMS/Email/WhatsApp
    feedback_score               NVARCHAR(100),  -- Customer satisfaction score
    data_source                  NVARCHAR(100),  -- Source system identifier
    extracted_date               NVARCHAR(100),  -- Date data was extracted
    record_version               NVARCHAR(100)   -- Version control for updates
);
PRINT 'Created table: bronze.crm_raw';

-- 2. POS Raw Table - Point of Sale transaction data
-- Purpose: Stores detailed sales transactions including line items
-- Key Fields: transaction_id, staff_id, product_id, shift
-- Integration: Links to HR (staff_id), CRM (customer_id), Stores (store_id)
IF OBJECT_ID('bronze.pos_raw','U') IS NOT NULL
    DROP TABLE bronze.pos_raw;
CREATE TABLE bronze.pos_raw (
    transaction_id        NVARCHAR(100),  -- Unique transaction identifier
    transaction_date      NVARCHAR(100),  -- Date and time of transaction
    store_id              NVARCHAR(100),  -- Store where transaction occurred
    store_county          NVARCHAR(100),  -- County of the store
    store_format          NVARCHAR(100),  -- Store format (Supermarket/Mini-mart/etc.)
    customer_id           NVARCHAR(100),  -- Customer making purchase
    line_item_id          NVARCHAR(100),  -- Unique identifier for line item
    product_id            NVARCHAR(100),  -- Product purchased
    category              NVARCHAR(100),  -- Product category (FMCG/Fresh/etc.)
    subcategory           NVARCHAR(100),  -- Product subcategory
    product_name          NVARCHAR(255),  -- Full product name
    unit_price_kes        NVARCHAR(100),  -- Price per unit in KES
    quantity              NVARCHAR(100),  -- Quantity purchased
    total_price_kes       NVARCHAR(100),  -- Total before discount
    discount_kes          NVARCHAR(100),  -- Discount amount applied
    final_price_kes       NVARCHAR(100),  -- Final amount paid
    payment_method        NVARCHAR(100),  -- Cash/M-Pesa/Card/etc.
    staff_id              NVARCHAR(100),  -- Cashier/employee ID (HR format: CS-2024-CAS-XXXX)
    shift                 NVARCHAR(100),  -- Shift during which transaction occurred
    data_source           NVARCHAR(100),  -- Source system identifier
    extracted_timestamp   NVARCHAR(100)   -- Date and time data was extracted
);
PRINT 'Created table: bronze.pos_raw';

-- 3. Stores Raw Table - Retail store locations
-- Purpose: Store location and format information
-- Key Fields: store_id, county, format
-- Integration: Links to HR (employee assignments) and POS (transactions)
IF OBJECT_ID('bronze.stores_raw','U') IS NOT NULL
    DROP TABLE bronze.stores_raw;
CREATE TABLE bronze.stores_raw (
    store_id    NVARCHAR(100),  -- Unique store identifier (STR-XXXX)
    store_name  NVARCHAR(100),  -- Store display name
    county      NVARCHAR(100),  -- County where store is located
    format      NVARCHAR(100),  -- Store format (Supermarket/Mini-mart/Express/Hypermarket)
    size_sqm    NVARCHAR(100)   -- Store size in square meters
);
PRINT 'Created table: bronze.stores_raw';

-- ===========================================================================
-- SECTION 3: HUMAN RESOURCES TABLES
-- ===========================================================================

-- 4. HR Raw Table - Employee information
-- Purpose: Stores employee data including assignments and shifts
-- Key Fields: employee_id, store_id, shift, job_title
-- Integration: Critical for POS transaction attribution to cashiers
IF OBJECT_ID('bronze.hr_raw','U') IS NOT NULL
    DROP TABLE bronze.hr_raw;
CREATE TABLE bronze.hr_raw(
    employee_id          NVARCHAR(100),  -- Format: DEPT-HIREYEAR-JOBCODE-RANDOM
    first_name           NVARCHAR(100),  -- Employee first name
    last_name            NVARCHAR(100),  -- Employee last name
    gender               NVARCHAR(100),  -- M/F/Other
    county               NVARCHAR(100),  -- County of residence
    town                 NVARCHAR(100),  -- Town of residence
    hiredate             NVARCHAR(100),  -- Date of hire
    department           NVARCHAR(100),  -- Department assignment
    job_title            NVARCHAR(100),  -- Job title/position
    education_level      NVARCHAR(100),  -- Highest education level
    salary               NVARCHAR(100),  -- Monthly salary in KES
    performance_rating   NVARCHAR(100),  -- Performance evaluation score
    overtime             NVARCHAR(100),  -- Overtime hours/compensation
    store_id             NVARCHAR(100),  -- Store assignment (NULL for HQ)
    shift                NVARCHAR(100),  -- Primary shift assignment
    shift_hours          NVARCHAR(100),  -- Shift hours (e.g., "07:00-15:00")
    birthdate            NVARCHAR(100),  -- Date of birth
    termdate             NVARCHAR(100),  -- Termination date (NULL if active)
    data_source          NVARCHAR(100),  -- Source system identifier
    extracted_date       NVARCHAR(100),  -- Date data was extracted
    record_version       NVARCHAR(100)   -- Version control for updates
);
PRINT 'Created table: bronze.hr_raw';

-- 5. Employee Shifts Raw Table - Detailed shift schedule (OPTIONAL)
-- Purpose: Granular shift data for time-based analysis
-- Key Fields: shift_id, employee_id, shift_date, hours_worked
-- Integration: Enhances HR-POS integration with detailed shift timing
IF OBJECT_ID('bronze.employee_shifts_raw','U') IS NOT NULL
    DROP TABLE bronze.employee_shifts_raw;
CREATE TABLE bronze.employee_shifts_raw(
    shift_id            NVARCHAR(100),  -- Unique shift identifier
    employee_id         NVARCHAR(100),  -- Employee working the shift
    store_id            NVARCHAR(100),  -- Store where shift occurred
    shift_date          NVARCHAR(100),  -- Date of the shift
    shift_type          NVARCHAR(100),  -- Shift type (Day/Night/Standard)
    start_time          NVARCHAR(100),  -- Shift start time
    end_time            NVARCHAR(100),  -- Shift end time
    hours_worked        NVARCHAR(100),  -- Total hours worked
    overtime_hours      NVARCHAR(100),  -- Overtime hours
    data_source         NVARCHAR(100),  -- Source system identifier
    extracted_date      NVARCHAR(100)   -- Date data was extracted
);
PRINT 'Created table: bronze.employee_shifts_raw';

-- ===========================================================================
-- SECTION 4: PRODUCT CATALOG TABLE
-- ===========================================================================

-- 6. Products Raw Table - Product catalog information
-- Purpose: Master product data including pricing and inventory
-- Key Fields: product_id, category, retail_price_kes, stock_level
-- Integration: Links to POS transactions via product_id
IF OBJECT_ID('bronze.products_raw','U') IS NOT NULL
    DROP TABLE bronze.products_raw;
CREATE TABLE bronze.products_raw(
    product_id           NVARCHAR(100),  -- Unique product identifier (PROD-XXXX)
    product_name         NVARCHAR(255),  -- Full product name with brand and variant
    category             NVARCHAR(100),  -- Main category (FMCG/Fresh/Non-Food/etc.)
    subcategory          NVARCHAR(100),  -- Subcategory (Food & Beverages/Meat & Poultry/etc.)
    brand                NVARCHAR(100),  -- Product brand
    supplier             NVARCHAR(100),  -- Supplier/vendor
    unit_cost_kes        NVARCHAR(100),  -- Cost per unit in KES
    retail_price_kes     NVARCHAR(100),  -- Selling price per unit
    margin_percentage    NVARCHAR(100),  -- Profit margin percentage
    stock_level          NVARCHAR(100),  -- Current inventory level
    reorder_point        NVARCHAR(100),  -- Minimum stock level before reorder
    seasonality          NVARCHAR(100),  -- Sales seasonality (High/Medium/Low)
    popularity_score     NVARCHAR(100),  -- Product popularity metric (0-100)
    data_source          NVARCHAR(100),  -- Source system identifier
    extracted_date       NVARCHAR(100)   -- Date data was extracted
);
PRINT 'Created table: bronze.products_raw';

-- ===========================================================================
-- SECTION 5: GEOGRAPHIC INFORMATION SYSTEM (GIS) TABLES
-- ===========================================================================

-- 7. GIS Counties Raw Table - County-level geographic and demographic data
-- Purpose: County characteristics for market analysis and segmentation
-- Key Fields: county_id, population_2023, avg_household_income_kes
-- Integration: Used for location-based analysis and market sizing
IF OBJECT_ID('bronze.gis_counties_raw','U') IS NOT NULL
    DROP TABLE bronze.gis_counties_raw;
CREATE TABLE bronze.gis_counties_raw (
    county_id                     NVARCHAR(100),  -- Unique county identifier
    county_name                   NVARCHAR(100),  -- County name
    population_2023               NVARCHAR(100),  -- Latest population estimate
    population_density_psqkm      NVARCHAR(100),  -- Population density
    area_sqkm                     NVARCHAR(100),  -- County area in sq km
    poverty_rate                  NVARCHAR(100),  -- Poverty rate percentage
    unemployment_rate             NVARCHAR(100),  -- Unemployment rate percentage
    avg_household_income_kes      NVARCHAR(100),  -- Average household income
    urbanization_rate             NVARCHAR(100),  -- Urbanization percentage
    literacy_rate                 NVARCHAR(100),  -- Literacy rate percentage
    road_infrastructure_score     NVARCHAR(100),  -- Infrastructure quality score
    public_transport_score        NVARCHAR(100),  -- Public transport score
    internet_penetration          NVARCHAR(100),  -- Internet access percentage
    commercial_rent_kes_psqm      NVARCHAR(100),  -- Commercial rent per sqm
    business_registration_days    NVARCHAR(100),  -- Days to register business
    security_index                NVARCHAR(100),  -- Security/safety index
    tourist_arrivals_annual       NVARCHAR(100),  -- Annual tourist arrivals
    latitude                      NVARCHAR(100),  -- Geographic coordinates
    longitude                     NVARCHAR(100),  -- Geographic coordinates
    major_towns                   NVARCHAR(200),  -- Major towns in county
    competitor_counts_json        NVARCHAR(500)   -- JSON with competitor counts
);
PRINT 'Created table: bronze.gis_counties_raw';

-- 8. GIS Locations Raw Table - Site-specific location data
-- Purpose: Detailed location characteristics for site selection
-- Key Fields: location_id, latitude, longitude, visibility_score
-- Integration: Used for potential new store location analysis
IF OBJECT_ID('bronze.gis_locations_raw','U') IS NOT NULL
    DROP TABLE bronze.gis_locations_raw;
CREATE TABLE bronze.gis_locations_raw(
    location_id                NVARCHAR(100),  -- Unique location identifier
    county                    NVARCHAR(100),   -- County where located
    site_name                 NVARCHAR(100),   -- Location name/description
    latitude                  NVARCHAR(100),   -- Geographic coordinates
    longitude                 NVARCHAR(100),   -- Geographic coordinates
    visibility_score          NVARCHAR(100),   -- Visibility from main roads
    accessibility_score       NVARCHAR(100),   -- Ease of access score
    estimated_daily_traffic   NVARCHAR(100),   -- Estimated daily traffic/pedestrians
    parking_capacity          NVARCHAR(100),   -- Available parking spaces
    zoning                    NVARCHAR(100),   -- Zoning classification
    property_size_sqm         NVARCHAR(100),   -- Property size in square meters
    building_condition        NVARCHAR(100),   -- Condition of existing buildings
    competition_within_1km    NVARCHAR(100),   -- Number of competitors nearby
    complementary_businesses  NVARCHAR(100),   -- Complementary businesses nearby
    last_survey_date          NVARCHAR(100),   -- Date of last site survey
    data_source               NVARCHAR(100)    -- Source system identifier
);
PRINT 'Created table: bronze.gis_locations_raw';

-- ===========================================================================
-- SECTION 6: COMPETITOR ANALYSIS TABLES
-- ===========================================================================

-- 9. Competitors Raw Table - Competitor company information
-- Purpose: Competitor profiling and market positioning
-- Key Fields: competitor_id, competitor_name, estimated_market_share
-- Integration: Used for competitive intelligence and market analysis
IF OBJECT_ID('bronze.competitors_raw','U') IS NOT NULL
    DROP TABLE bronze.competitors_raw;
CREATE TABLE bronze.competitors_raw(
    competitor_id                    NVARCHAR(100),  -- Unique competitor identifier
    competitor_name                  NVARCHAR(100),  -- Competitor company name
    competitor_type                  NVARCHAR(100),  -- Type (Supermarket/Convenience/etc.)
    year_founded                     NVARCHAR(100),  -- Year company was founded
    total_stores                     NVARCHAR(100),  -- Total number of stores
    estimated_market_share           NVARCHAR(100),  -- Estimated market share percentage
    avg_store_revenue_kes_monthly    NVARCHAR(100),  -- Average monthly store revenue
    positioning                      NVARCHAR(100),  -- Market positioning
    target_demographic               NVARCHAR(100),  -- Target customer demographic
    pricing_index                    NVARCHAR(100),  -- Relative pricing (Low/Medium/High)
    store_formats                    NVARCHAR(100),  -- Store formats operated
    key_strengths                    NVARCHAR(500),  -- Competitor strengths
    key_weaknesses                   NVARCHAR(500),  -- Competitor weaknesses
    last_updated                     NVARCHAR(100),  -- Date information was last updated
    data_source                      NVARCHAR(100)   -- Source system identifier
);
PRINT 'Created table: bronze.competitors_raw';

-- 10. Competitor Stores Raw Table - Individual competitor store data
-- Purpose: Detailed competitor store locations and characteristics
-- Key Fields: store_id, competitor_id, county, estimated_monthly_revenue_kes
-- Integration: Links to competitors_raw and used for proximity analysis
IF OBJECT_ID('bronze.competitor_stores_raw','U') IS NOT NULL
    DROP TABLE bronze.competitor_stores_raw;
CREATE TABLE bronze.competitor_stores_raw(
    store_id                         NVARCHAR(100),  -- Unique competitor store identifier
    competitor_id                    NVARCHAR(100),  -- Parent competitor company
    county                           NVARCHAR(100),  -- County location
    town                             NVARCHAR(100),  -- Town location
    store_size_sqm                   NVARCHAR(100),  -- Store size in square meters
    store_format                     NVARCHAR(100),  -- Store format
    opening_date                     NVARCHAR(100),  -- Date store opened
    estimated_monthly_revenue_kes    NVARCHAR(100),  -- Estimated monthly revenue
    estimated_daily_customers        NVARCHAR(100),  -- Estimated daily customer count
    location_score                   NVARCHAR(100),  -- Location quality score
    parking_available                NVARCHAR(100),  -- Parking availability (Yes/No)
    has_delivery                     NVARCHAR(100),  -- Delivery service availability
    last_verified                    NVARCHAR(100),  -- Date information was verified
    data_source                      NVARCHAR(100)   -- Source system identifier
);
PRINT 'Created table: bronze.competitor_stores_raw';

-- ===========================================================================
-- SECTION 7: ECONOMIC DATA TABLE
-- ===========================================================================

-- 11. Economic Raw Table - Time-series economic indicators
-- Purpose: Monthly economic data for market trend analysis
-- Key Fields: county, year_month, inflation_rate, retail_sales_index
-- Integration: Used for macroeconomic analysis and sales forecasting
IF OBJECT_ID('bronze.economic_raw','U') IS NOT NULL
    DROP TABLE bronze.economic_raw;
CREATE TABLE bronze.economic_raw(
    county                          NVARCHAR(100),  -- County reference
    year_month                      NVARCHAR(100),  -- Year-month period (YYYY-MM)
    year                            NVARCHAR(100),  -- Year component
    month                           NVARCHAR(100),  -- Month component
    gdp_growth_rate                 NVARCHAR(100),  -- GDP growth rate percentage
    inflation_rate                  NVARCHAR(100),  -- Inflation rate percentage
    unemployment_rate               NVARCHAR(100),  -- Unemployment rate percentage
    consumer_confidence_index       NVARCHAR(100),  -- Consumer confidence index
    retail_sales_index              NVARCHAR(100),  -- Retail sales index
    business_confidence_index       NVARCHAR(100),  -- Business confidence index
    new_business_registrations      NVARCHAR(100),  -- New business registrations count
    commercial_rent_growth          NVARCHAR(100),  -- Commercial rent growth rate
    retail_vacancy_rate             NVARCHAR(100),  -- Retail space vacancy rate
    avg_fuel_price_kes              NVARCHAR(100),  -- Average fuel price
    usd_kes_exchange_rate           NVARCHAR(100),  -- USD to KES exchange rate
    data_collection_date            NVARCHAR(100),  -- Date economic data was collected
    data_source                     NVARCHAR(100)   -- Source system identifier
);
PRINT 'Created table: bronze.economic_raw';

-- ===========================================================================
-- SECTION 8: COMPLETION SUMMARY
-- ===========================================================================
PRINT '==============================================================';
PRINT 'BRONZE LAYER DDL CREATION COMPLETE';
PRINT '==============================================================';
PRINT '';
PRINT 'SUMMARY OF CREATED TABLES:';
PRINT '1.  bronze.crm_raw          - Customer Relationship Management';
PRINT '2.  bronze.pos_raw          - Point of Sale Transactions';
PRINT '3.  bronze.stores_raw       - Store Locations';
PRINT '4.  bronze.hr_raw           - Human Resources';
PRINT '5.  bronze.employee_shifts_raw - Detailed Shift Schedule (Optional)';
PRINT '6.  bronze.products_raw     - Product Catalog';
PRINT '7.  bronze.gis_counties_raw - County-level Geographic Data';
PRINT '8.  bronze.gis_locations_raw - Site-specific Location Data';
PRINT '9.  bronze.competitors_raw  - Competitor Companies';
PRINT '10. bronze.competitor_stores_raw - Competitor Store Locations';
PRINT '11. bronze.economic_raw     - Economic Time-series Data';
PRINT '';
PRINT 'KEY DESIGN PRINCIPLES:';
PRINT '• All columns use NVARCHAR for maximum data type flexibility';
PRINT '• Data validation and type conversion happen in silver/gold layers';
PRINT '• Foreign key relationships established in higher data layers';
PRINT '• Optional tables marked for enhanced analysis capabilities';
PRINT '';
PRINT 'NEXT STEPS:';
PRINT '1. Run bronze.load_bronze stored procedure to populate tables';
PRINT '2. Ensure CSV files exist in the designated directory';
PRINT '3. Execute silver layer transformations after data loading';
PRINT '==============================================================';
GO
