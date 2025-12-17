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
	feedback_score DECIMAL,
	data_source   NVARCHAR(30),
	extracted_date  DATE,
	record_version    INT
);
IF OBJECT_ID('bronze.pos_raw','U') IS NOT NULL
 DROP TABLE bronze.pos_raw;
CREATE TABLE bronze.pos_raw (
    transaction_id        NVARCHAR(100),
    transaction_date      NVARCHAR(100),
    store_id              NVARCHAR(100),
    store_county          NVARCHAR(100),
    store_format          NVARCHAR(100),
    customer_id           NVARCHAR(100),
    line_item_id          NVARCHAR(100),
    product_id            NVARCHAR(100),
    category              NVARCHAR(100),
    subcategory           NVARCHAR(100),
    product_name          NVARCHAR(255),
    unit_price_kes        NVARCHAR(100),
    quantity              NVARCHAR(100),
    total_price_kes       NVARCHAR(100),
    discount_kes          NVARCHAR(100),
    final_price_kes       NVARCHAR(100),
    payment_method        NVARCHAR(100),
    staff_id              NVARCHAR(100),
    data_source            NVARCHAR(100),
    extracted_timestamp   NVARCHAR(100)
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
DROP TABLE IF EXISTS bronze.gis_counties_raw;
GO
CREATE TABLE bronze.gis_counties_raw (
    county_id                     NVARCHAR(50),
    county_name                   NVARCHAR(50),
    population_2023               NVARCHAR(50),
    population_density_psqkm      NVARCHAR(50),
    area_sqkm                     NVARCHAR(50),
    poverty_rate                  NVARCHAR(50),
    unemployment_rate             NVARCHAR(50),
    avg_household_income_kes      NVARCHAR(50),
    urbanization_rate             NVARCHAR(50),
    literacy_rate                 NVARCHAR(50),
    road_infrastructure_score     NVARCHAR(50),
    public_transport_score        NVARCHAR(50),
    internet_penetration          NVARCHAR(50),
    commercial_rent_kes_psqm      NVARCHAR(50),
    business_registration_days    NVARCHAR(50),
    security_index                NVARCHAR(50),
    tourist_arrivals_annual       NVARCHAR(50),
    latitude                      NVARCHAR(50),
    longitude                     NVARCHAR(50),
    major_towns                   NVARCHAR(100),
    competitor_counts_json        NVARCHAR(300),
);
IF OBJECT_ID ( 'bronze.gis_locations_raw','U') IS NOT NULL
 DROP TABLE bronze.gis_locations_raw 
CREATE TABLE bronze.gis_locations_raw(
       location_id   NVARCHAR (50),
	   county    NVARCHAR (50), 
	   site_name   NVARCHAR (50), 
	   latitude    NVARCHAR(50),
	   longitude   NVARCHAR(50),
	   visibility_score NVARCHAR(50),
	   accessibility_score  NVARCHAR(50),
	   estimated_daily_traffic  NVARCHAR(50),
	   parking_capacity   NVARCHAR(50),
	   zoning     NVARCHAR (50), 
	   property_size_sqm  NVARCHAR(50),
	   building_condition  NVARCHAR (50),
	   competition_within_1km  NVARCHAR(50),
	   complementary_businesses  NVARCHAR(50),
	   last_survey_date  NVARCHAR(50),
	   data_source  NVARCHAR(50)
);
IF OBJECT_ID ('bronze.competitors_raw','U') IS NOT NULL
  DROP TABLE bronze.competitors_raw
CREATE TABLE  bronze.competitors_raw(
        competitor_id   NVARCHAR(50),
		competitor_name   NVARCHAR(50),
		competitor_type  NVARCHAR(50),
		year_founded  NVARCHAR(50),
		total_stores  NVARCHAR(50),
		estimated_market_share NVARCHAR(50),
		avg_store_revenue_kes_monthly  NVARCHAR(50),
		positioning   NVARCHAR(50),
		target_demographic   NVARCHAR(50),
		pricing_index    NVARCHAR(50),
		store_formats   NVARCHAR(50), 
		key_strengths  NVARCHAR(200), 
		key_weaknesses  NVARCHAR(200), 
		last_updated   NVARCHAR(50),
		data_source   NVARCHAR(50)
);
IF OBJECT_ID ('bronze.competitor_stores_raw','U') IS NOT NULL
 DROP TABLE bronze.competitor_stores_raw
CREATE TABLE bronze.competitor_stores_raw(
          store_id   NVARCHAR(50),
		  competitor_id   NVARCHAR(50),
		  county  NVARCHAR(50),
		  town  NVARCHAR(50),
		  store_size_sqm  NVARCHAR(50),
		  store_format NVARCHAR(50),
		  opening_date    NVARCHAR(50),
		  estimated_monthly_revenue_kes   NVARCHAR(50),
		  estimated_daily_customers  NVARCHAR(50),
		  location_score  NVARCHAR(50),
		  parking_available  NVARCHAR(50),
		  has_delivery  NVARCHAR(50),
		  last_verified  NVARCHAR(50),
		  data_source     NVARCHAR(50)     
);
IF OBJECT_ID ('bronze.economic_raw','U') IS NOT NULL
DROP TABLE bronze.economic_raw
CREATE TABLE bronze.economic_raw(
	county          NVARCHAR(50),
	year_month      NVARCHAR(50),
	year               NVARCHAR(50),
	month                    NVARCHAR(50),
	gdp_growth_rate         NVARCHAR(50),
	inflation_rate  NVARCHAR(50),
	unemployment_rate   NVARCHAR(50),
	consumer_confidence_index  NVARCHAR(50),
	retail_sales_index     NVARCHAR(50),
	business_confidence_index NVARCHAR(50),
	new_business_registrations  NVARCHAR(50),
	commercial_rent_growth     NVARCHAR(50),
	retail_vacancy_rate  NVARCHAR(50),
	avg_fuel_price_kes  NVARCHAR(50),
	usd_kes_exchange_rate NVARCHAR(50),
	data_collection_date   NVARCHAR(50),
	data_source     NVARCHAR(50)
);
