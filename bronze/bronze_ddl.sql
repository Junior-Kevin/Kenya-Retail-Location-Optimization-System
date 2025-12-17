use Retail_location
/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables 
    if they already exist.
	  Run this script to re-define the DDL structure of 'bronze' Tables
===============================================================================
*/
IF OBJECT_ID('bronze.crm_raw','U') IS NOT NULL
	DROP TABLE bronze.crm_raw;
CREATE TABLE bronze.crm_raw(
    customer_id              NVARCHAR(50),
    first_name            NVARCHAR(50),
    last_name       NVARCHAR(50),
    gender        NVARCHAR(50),
    phone  NVARCHAR(50),
    email           NVARCHAR(50),
    county     NVARCHAR(50),
	area     NVARCHAR(50),
	customer_segment  NVARCHAR(50),
	registration_date   DATE,
	customer_status    NVARCHAR(50),
	last_purchase_date   DATE,
	purchase_frequency_monthly INT,
	avg_transaction_value_kes  FLOAT,
	lifetime_value_kes      FLOAT,
	preferred_store_format  NVARCHAR(50),
	communication_preferences   NVARCHAR(50),
	feedback_score INT,
	data_source   NVARCHAR(30),
	extracted_date  DATE,
	record_version    INT
);
IF OBJECT_ID('bronze.pos_raw','U') IS NOT NULL
 DROP TABLE bronze.pos_raw;
CREATE TABLE bronze.pos_raw (
    transaction_id      NVARCHAR(50),
    transaction_date     DATETIME,
    store_id     NVARCHAR(50),
    store_county    NVARCHAR(50),
    store_format     NVARCHAR(50),
    customer_id       NVARCHAR(50),
    line_item_id   NVARCHAR(50),
	product_id   NVARCHAR(50),
	category  NVARCHAR(50),
	subcategory   NVARCHAR(50),
	product_name   NVARCHAR(50),
    unit_price_kes   FLOAT,
    quantity           INT,
    total_price_kes   FLOAT,
	discount_kes     FLOAT,
	final_price_kes   FLOAT,
	payment_method     NVARCHAR(50),
	staff_id         NVARCHAR(50),
	data_source      NVARCHAR(50),
	extracted_timestamp     DATETIME

);
IF OBJECT_ID('bronze.stores_raw','U') IS NOT NULL
 DROP TABLE bronze.stores_raw;
CREATE TABLE bronze.stores_raw (
    store_id  NVARCHAR(50),
    store_name  NVARCHAR(50),
    county NVARCHAR(50),
    format   NVARCHAR(50),
    size_sqm  INT,

);
IF OBJECT_ID ('bronze.gis_counties_raw','U') IS NOT NULL
  DROP TABLE bronze.gis_counties_raw
CREATE TABLE bronze.gis_counties_raw(
    county_id   NVARCHAR(50),
	county_name    NVARCHAR(50),
	population_2023 INT,
	population_density_psqkm INT,
	area_sqkm  INT,
	poverty_rate FLOAT,
	unemployment_rate  FLOAT,
	avg_household_income_kes INT,
	urbanization_rate FLOAT,
	literacy_rate   DECIMAL,
	road_infrastructure_score DECIMAL,
	public_transport_score DECIMAL,
	internet_penetration   DECIMAL,
	commercial_rent_kes_psqm   DECIMAL,
	business_registration_days  INT,
	security_index   DECIMAL,
	tourist_arrivals_annual  INT,
	latitude        FLOAT,
	longitude       FLOAT,
	major_towns   NVARCHAR(50),
	competitor_counts_json  NVARCHAR(150),
	data_collection_date  DATE,
	data_source  NVARCHAR(50)
);
IF OBJECT_ID ( 'bronze.gis_locations_raw','U') IS NOT NULL
 DROP TABLE bronze.gis_locations_raw 
CREATE TABLE bronze.gis_locations_raw(
       location_id   NVARCHAR (50),
	   county    NVARCHAR (50), 
	   site_name   NVARCHAR (50), 
	   latitude    DECIMAL,
	   longitude   DECIMAL,
	   visibility_score INT,
	   accessibility_score  INT,
	   estimated_daily_traffic  INT,
	   parking_capacity   INT,
	   zoning     NVARCHAR (50), 
	   property_size_sqm  INT,
	   building_condition  NVARCHAR (50),
	   competition_within_1km  INT,
	   complementary_businesses  INT,
	   last_survey_date  DATE,
	   data_source  NVARCHAR(50)

);
IF OBJECT_ID ('bronze.competitors_raw','U') IS NOT NULL
  DROP TABLE bronze.competitors_raw
CREATE TABLE  bronze.competitors_raw(
        competitor_id   NVARCHAR(50),
		competitor_name   NVARCHAR(50),
		competitor_type  NVARCHAR(50),
		year_founded  INT,
		total_stores  INT,
		estimated_market_share INT,
		avg_store_revenue_kes_monthly  FLOAT,
		positioning   NVARCHAR(50),
		target_demographic   NVARCHAR(50),
		pricing_index    FLOAT,
		store_formats   NVARCHAR(50), 
		key_strengths  NVARCHAR(50), 
		key_weaknesses  NVARCHAR(50), 
		last_updated  DATE,
		data_source   NVARCHAR(50)

);
IF OBJECT_ID ('bronze.competitor_stores_raw','U') IS NOT NULL
 DROP TABLE bronze.competitor_stores_raw
CREATE TABLE bronze.competitor_stores_raw(
          store_id   NVARCHAR(50),
		  competitor_id   NVARCHAR(50),
		  county  NVARCHAR(50),
		  town  NVARCHAR(50),
		  store_size_sqm  INT,
		  store_format NVARCHAR(50),
		  opening_date    DATE,
		  estimated_monthly_revenue_kes   FLOAT,
		  estimated_daily_customers  INT,
		  location_score  INT,
		  parking_available  NVARCHAR(50),
		  has_delivery  NVARCHAR(50),
		  last_verified  DATE,
		  data_source     NVARCHAR(50)     
);
IF OBJECT_ID ('bronze.economic_raw','U') IS NOT NULL
DROP TABLE bronze.economic_raw
CREATE TABLE bronze.economic_raw(
	county   NVARCHAR(50),
	year_month NVARCHAR(50),
	year    INT,
	month  INT,
	gdp_growth_rate  DECIMAL,
	inflation_rate  DECIMAL,
	unemployment_rate   DECIMAL,
	consumer_confidence_index  DECIMAL,
	retail_sales_index     DECIMAL,
	business_confidence_index DECIMAL,
	new_business_registrations  INT,
	commercial_rent_growth     DECIMAL,
	retail_vacancy_rate  DECIMAL,
	avg_fuel_price_kes  DECIMAL,
	usd_kes_exchange_rate DECIMAL,
	data_collection_date   DATE,
	data_source     NVARCHAR(50)
);
