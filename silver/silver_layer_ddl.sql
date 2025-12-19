/*
===============================================================================
DATABASE: Retail_location
SCHEMA: silver
PURPOSE: Silver Layer Tables for Medallion Architecture
DESCRIPTION: 
    This script creates the silver layer tables which contain cleaned,
    validated, and type-cast data from the bronze layer.
    The silver layer serves as the foundation for business analytics
    and gold layer transformations.
    
MEDALLION ARCHITECTURE:
    Bronze (Raw) → Silver (Cleaned) → Gold (Business Views)
    
AUTHOR: Kevin Junior
CREATED: 2025-12-19
LAST MODIFIED: 2025-12-19
VERSION: 2.0
===============================================================================
*/

USE Retail_location;
GO

-- Create silver schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver')
BEGIN
    EXEC('CREATE SCHEMA silver');
    PRINT 'Schema [silver] created successfully.';
END
GO

/*
===============================================================================
TABLE: silver.crm
DESCRIPTION: Cleaned customer relationship management data
SOURCE: bronze.crm_raw
TRANSFORMATIONS APPLIED:
    1. Customer ID standardization ('CUST_' + substring)
    2. Phone/email NULL handling
    3. Date format standardization
    4. Deduplication based on registration_date
===============================================================================
*/
IF OBJECT_ID('silver.crm', 'U') IS NOT NULL DROP TABLE silver.crm;
CREATE TABLE silver.crm (
    -- Primary identifier
    customer_id NVARCHAR(20) NOT NULL,
    
    -- Customer personal information
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    gender NVARCHAR(10),
    
    -- Contact information
    phone NVARCHAR(50),
    email NVARCHAR(100),
    
    -- Geographic information
    county NVARCHAR(50),
    area NVARCHAR(50),
    
    -- Customer segmentation
    customer_segment NVARCHAR(50),
    registration_date DATE,
    customer_status NVARCHAR(20),
    
    -- Purchase behavior
    last_purchase_date DATE,
    purchase_frequency_monthly INT,
    avg_transaction_value_kes DECIMAL(18,2),
    lifetime_value_kes DECIMAL(18,2),
    
    -- Preferences
    preferred_store_format NVARCHAR(50),
    communication_preferences NVARCHAR(100),
    
    -- Customer feedback
    feedback_score DECIMAL(3,1),
    
    -- Data provenance
    data_source NVARCHAR(30),
    extracted_date DATE,
    record_version INT,
    
    -- Audit columns
    load_timestamp DATETIME DEFAULT GETDATE(),
    
    -- Constraints
    CONSTRAINT PK_crm PRIMARY KEY (customer_id),
    CONSTRAINT CHK_crm_feedback_score CHECK (feedback_score BETWEEN 0 AND 10),
    CONSTRAINT CHK_crm_purchase_frequency CHECK (purchase_frequency_monthly >= 0)
);

/*
===============================================================================
TABLE: silver.pos
DESCRIPTION: Cleaned point-of-sale transaction data
SOURCE: bronze.pos_raw
TRANSFORMATIONS APPLIED:
    1. Date/time parsing from string format
    2. Numeric value validation and type casting
    3. NULL customer handling ('ANONYMOUS')
    4. Payment method standardization
    5. Business rule validation (discount ≤ total price)
===============================================================================
*/
IF OBJECT_ID('silver.pos', 'U') IS NOT NULL DROP TABLE silver.pos;
CREATE TABLE silver.pos (
    -- Transaction identification
    transaction_id NVARCHAR(100) NOT NULL,
    transaction_date DATE NOT NULL,
    
    -- Store information
    store_id NVARCHAR(50) NOT NULL,
    store_county NVARCHAR(50),
    store_format NVARCHAR(50),
    
    -- Customer identification (may be ANONYMOUS)
    customer_id NVARCHAR(50),
    
    -- Product details
    line_item_id NVARCHAR(100),
    product_id NVARCHAR(100),
    category NVARCHAR(100),
    subcategory NVARCHAR(100),
    product_name NVARCHAR(255),
    
    -- Pricing and quantities
    unit_price_kes DECIMAL(18,2),
    quantity INT,
    total_price_kes DECIMAL(18,2),
    discount_kes DECIMAL(18,2),
    final_price_kes DECIMAL(18,2),
    
    -- Transaction details
    payment_method NVARCHAR(50),
    staff_id NVARCHAR(50),
    
    -- Data provenance
    data_source NVARCHAR(100),
    extracted_timestamp NVARCHAR(100),
    
    -- Audit columns
    load_timestamp DATETIME DEFAULT GETDATE(),
    
    -- Constraints
    CONSTRAINT CHK_pos_quantity CHECK (quantity >= 0),
    CONSTRAINT CHK_pos_unit_price CHECK (unit_price_kes >= 0),
    CONSTRAINT CHK_pos_final_price CHECK (final_price_kes >= 0),
    CONSTRAINT CHK_pos_discount CHECK (discount_kes >= 0 AND discount_kes <= total_price_kes)
);

/*
===============================================================================
TABLE: silver.stores
DESCRIPTION: Company store locations and characteristics
SOURCE: bronze.stores_raw
TRANSFORMATIONS APPLIED:
    1. Size conversion to integer
===============================================================================
*/
IF OBJECT_ID('silver.stores', 'U') IS NOT NULL DROP TABLE silver.stores;
CREATE TABLE silver.stores (
    store_id NVARCHAR(50) NOT NULL,
    store_name NVARCHAR(100),
    county NVARCHAR(50),
    format NVARCHAR(50),
    size_sqm INT,
    load_timestamp DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT PK_stores PRIMARY KEY (store_id),
    CONSTRAINT CHK_stores_size CHECK (size_sqm > 0)
);

/*
===============================================================================
TABLE: silver.gis_counties
DESCRIPTION: Geographic and demographic county-level data
SOURCE: bronze.gis_counties_raw
TRANSFORMATIONS APPLIED:
    1. Population density calculation
    2. Tourist arrivals multiplied by 1000
    3. Numeric type casting
===============================================================================
*/
IF OBJECT_ID('silver.gis_counties', 'U') IS NOT NULL DROP TABLE silver.gis_counties;
CREATE TABLE silver.gis_counties (
    county_id NVARCHAR(50) NOT NULL,
    county_name NVARCHAR(50),
    
    -- Population metrics
    population_2023 INT,
    area_sqkm DECIMAL(18,2),
    population_density_psqkm DECIMAL(18,2),  -- Computed: population/area
    
    -- Economic indicators
    poverty_rate DECIMAL(5,2),
    unemployment_rate DECIMAL(5,2),
    avg_household_income_kes DECIMAL(18,2),
    
    -- Development metrics
    urbanization_rate DECIMAL(5,2),
    literacy_rate DECIMAL(5,2),
    
    -- Infrastructure scores (1-10 scale)
    road_infrastructure_score DECIMAL(3,1),
    public_transport_score DECIMAL(3,1),
    
    -- Technology and business
    internet_penetration DECIMAL(5,2),
    commercial_rent_kes_psqm DECIMAL(18,2),
    business_registration_days INT,
    
    -- Security and tourism
    security_index INT,
    tourist_arrivals_annual INT,  -- Original value × 1000
    
    -- Geographic coordinates
    latitude DECIMAL(10,6),
    longitude DECIMAL(10,6),
    
    -- Additional information
    major_towns NVARCHAR(100),
    competitor_counts_json NVARCHAR(300),
    
    -- Audit columns
    load_timestamp DATETIME DEFAULT GETDATE(),
    
    -- Constraints
    CONSTRAINT PK_gis_counties PRIMARY KEY (county_id),
    CONSTRAINT CHK_gis_scores CHECK (
        road_infrastructure_score BETWEEN 1 AND 10 AND
        public_transport_score BETWEEN 1 AND 10 AND
        security_index BETWEEN 1 AND 10
    )
);

/*
===============================================================================
TABLE: silver.gis_locations
DESCRIPTION: Site-specific location assessment data
SOURCE: bronze.gis_locations_raw
TRANSFORMATIONS APPLIED:
    1. Location ID standardization
    2. Missing coordinate imputation from previous records
    3. Traffic estimation truncation (>1000 to 3 digits)
===============================================================================
*/
IF OBJECT_ID('silver.gis_locations', 'U') IS NOT NULL DROP TABLE silver.gis_locations;
CREATE TABLE silver.gis_locations (
    -- Transformed ID: 'LOC-' + county_prefix + original_id_suffix
    location_id NVARCHAR(50) NOT NULL,
    
    -- Location details
    county NVARCHAR(50),
    site_name NVARCHAR(100),
    
    -- Geographic coordinates
    latitude DECIMAL(10,6),
    longitude DECIMAL(10,6),
    
    -- Site assessment scores (1-10 scale)
    visibility_score INT,
    accessibility_score INT,
    
    -- Traffic and capacity
    estimated_daily_traffic INT,  -- Truncated to 3 digits if >1000
    parking_capacity INT,
    
    -- Property characteristics
    zoning NVARCHAR(50),
    property_size_sqm DECIMAL(18,2),
    building_condition NVARCHAR(50),
    
    -- Competitive landscape
    competition_within_1km INT,
    complementary_businesses NVARCHAR(100),
    
    -- Data currency
    last_survey_date DATE,
    
    -- Data provenance
    data_source NVARCHAR(50),
    
    -- Audit columns
    load_timestamp DATETIME DEFAULT GETDATE(),
    
    -- Constraints
    CONSTRAINT PK_gis_locations PRIMARY KEY (location_id)
);

/*
===============================================================================
TABLE: silver.competitors
DESCRIPTION: Competitor company profiles and metrics
SOURCE: bronze.competitors_raw
TRANSFORMATIONS APPLIED:
    1. Numeric type casting
    2. Date parsing
===============================================================================
*/
IF OBJECT_ID('silver.competitors', 'U') IS NOT NULL DROP TABLE silver.competitors;
CREATE TABLE silver.competitors (
    competitor_id NVARCHAR(50) NOT NULL,
    competitor_name NVARCHAR(100),
    competitor_type NVARCHAR(50),
    
    -- Company history
    year_founded INT,
    total_stores INT,
    
    -- Market performance
    estimated_market_share DECIMAL(5,2),  -- Percentage
    avg_store_revenue_kes_monthly DECIMAL(18,2),
    
    -- Business strategy
    positioning NVARCHAR(100),
    target_demographic NVARCHAR(100),
    pricing_index DECIMAL(5,2),
    store_formats NVARCHAR(100),
    
    -- SWOT analysis
    key_strengths NVARCHAR(200),
    key_weaknesses NVARCHAR(200),
    
    -- Data currency
    last_updated DATE,
    
    -- Data provenance
    data_source NVARCHAR(50),
    
    -- Audit columns
    load_timestamp DATETIME DEFAULT GETDATE(),
    
    -- Constraints
    CONSTRAINT PK_competitors PRIMARY KEY (competitor_id)
);

/*
===============================================================================
TABLE: silver.competitor_stores
DESCRIPTION: Individual competitor store locations and metrics
SOURCE: bronze.competitor_stores_raw
IMPORTANT NOTE: Column mapping correction due to CSV import issues
COLUMN MAPPING (Bronze → Silver):
    county → competitor_name (discarded)
    town → county
    store_size_sqm → town
    store_format → store_size_sqm
    opening_date → store_format
    estimated_monthly_revenue_kes → opening_date
    estimated_daily_customers → estimated_monthly_revenue_kes
    location_score → estimated_daily_customers
    parking_available → location_score
    has_delivery → parking_available
    last_verified → has_delivery
    LEFT(data_source,10) → last_verified
    SUBSTRING(data_source,12) → data_source
===============================================================================
*/
IF OBJECT_ID('silver.competitor_stores', 'U') IS NOT NULL DROP TABLE silver.competitor_stores;
CREATE TABLE silver.competitor_stores (
    store_id NVARCHAR(50) NOT NULL,
    competitor_id NVARCHAR(50),
    
    -- Geographic information
    county NVARCHAR(50),      -- Derived from [town] column
    town NVARCHAR(100),       -- Derived from [store_size_sqm] column
    
    -- Store characteristics
    store_size_sqm INT,       -- Derived from [store_format] column
    store_format NVARCHAR(50), -- Derived from [opening_date] column
    
    -- Historical data
    opening_date DATE,        -- Derived from [estimated_monthly_revenue_kes] column
    
    -- Performance metrics
    estimated_monthly_revenue_kes DECIMAL(18,2),  -- From [estimated_daily_customers]
    estimated_daily_customers INT,                -- From [location_score]
    
    -- Location assessment
    location_score INT,       -- Derived from [parking_available] column
    
    -- Amenities
    parking_available NVARCHAR(10),   -- Derived from [has_delivery] column
    has_delivery NVARCHAR(10),        -- Derived from [last_verified] column
    
    -- Data currency
    last_verified DATE,       -- Derived from LEFT(data_source,10)
    
    -- Data provenance
    data_source NVARCHAR(100),-- Derived from SUBSTRING(data_source,12)
    
    -- Audit columns
    load_timestamp DATETIME DEFAULT GETDATE(),
    
    -- Constraints
    CONSTRAINT PK_competitor_stores PRIMARY KEY (store_id),
    CONSTRAINT CHK_location_score CHECK (location_score BETWEEN 1 AND 10),
    CONSTRAINT FK_competitor_stores_competitors 
        FOREIGN KEY (competitor_id) REFERENCES silver.competitors(competitor_id)
);

/*
===============================================================================
TABLE: silver.economic
DESCRIPTION: County-level economic indicators over time
SOURCE: bronze.economic_raw
TRANSFORMATIONS APPLIED:
    1. County name capitalization
    2. Missing value imputation using rolling averages
    3. Negative value correction for new business registrations
===============================================================================
*/
IF OBJECT_ID('silver.economic', 'U') IS NOT NULL DROP TABLE silver.economic;
CREATE TABLE silver.economic (
    -- Geographic and temporal dimensions
    county NVARCHAR(50),
    year_month NVARCHAR(10),
    year INT,
    month INT,
    
    -- Macroeconomic indicators
    gdp_growth_rate DECIMAL(5,2),          -- Percentage
    inflation_rate DECIMAL(5,2),           -- Percentage
    unemployment_rate DECIMAL(5,2),        -- Percentage
    
    -- Confidence indices
    consumer_confidence_index DECIMAL(5,2),
    retail_sales_index DECIMAL(5,2),
    business_confidence_index DECIMAL(5,2),
    
    -- Business activity
    new_business_registrations INT,
    
    -- Real estate indicators
    commercial_rent_growth DECIMAL(5,2),   -- Percentage
    retail_vacancy_rate DECIMAL(5,2),      -- Percentage
    
    -- Cost indicators
    avg_fuel_price_kes DECIMAL(18,2),
    usd_kes_exchange_rate DECIMAL(18,2),
    
    -- Data collection metadata
    data_collection_date DATE,
    data_source NVARCHAR(100),
    
    -- Audit columns
    load_timestamp DATETIME DEFAULT GETDATE()
);

-- Create performance indexes
PRINT 'Creating performance indexes...';
CREATE INDEX idx_crm_customer_id ON silver.crm(customer_id);
CREATE INDEX idx_crm_county ON silver.crm(county);
CREATE INDEX idx_pos_transaction_date ON silver.pos(transaction_date);
CREATE INDEX idx_pos_customer_id ON silver.pos(customer_id);
CREATE INDEX idx_pos_store_id ON silver.pos(store_id);
CREATE INDEX idx_gis_counties_county_name ON silver.gis_counties(county_name);
CREATE INDEX idx_gis_locations_county ON silver.gis_locations(county);
CREATE INDEX idx_competitor_stores_competitor_id ON silver.competitor_stores(competitor_id);
CREATE INDEX idx_competitor_stores_county ON silver.competitor_stores(county);
CREATE INDEX idx_economic_county_year_month ON silver.economic(county, year_month);

PRINT 'Silver layer tables created successfully.';
GO
