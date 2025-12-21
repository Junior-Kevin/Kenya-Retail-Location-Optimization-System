# Gold Layer - Strategic Analytics Data Warehouse

## 📊 Overview
The Gold Layer is the final, decision-ready layer of our retail analytics data warehouse. It contains aggregated, enriched, and scored data designed specifically for business decision-making and strategic planning.

## 🎯 Purpose
Transform raw operational data into strategic insights that answer key business questions about expansion, customer value, store performance, and market opportunities.

## 📁 Table Structure

| Table | Type | Primary Purpose | Key Questions Answered |
|-------|------|-----------------|------------------------|
| [customer_value](customer_value/) | Dimension | Identify and segment valuable customers | Who are our best customers? Where do they live? |
| [dim_county](dim_county/) | Dimension | County-level market analysis | Where should we expand? Which counties are most attractive? |
| [fact_store_performance](fact_store_performance/) | Fact | Store-level performance benchmarking | How do stores perform? Which stores underperform? |
| [location_scoring](location_scoring/) | Fact | Site selection and scoring | Where should we open new stores? |
| [market_gap_analysis](market_gap_analysis/) | Fact | Market opportunity identification | Where are we under-served? |
| [competitive_intensity](competitive_intensity/) | Fact | Competitive landscape analysis | Where is competition strongest? |

## 🗓️ Data Refresh Schedule
- **Daily**: `customer_value`, `fact_store_performance`
- **Monthly**: `dim_county`, `market_gap_analysis`, `competitive_intensity`
- **As Needed**: `location_scoring` (when new sites are surveyed)

## 🔗 Complete Data Flow: Bronze → Silver → Gold

### Full Data Pipeline Architecture
```mermaid
graph TB
    %% BRONZE LAYER (Raw Data)
    subgraph "Bronze Layer - Raw Data"
        B1[bronze.crm_raw]
        B2[bronze.pos_raw]
        B3[bronze.stores_raw]
        B4[bronze.gis_counties_raw]
        B5[bronze.gis_locations_raw]
        B6[bronze.economic_raw]
        B7[bronze.competitors_raw]
        B8[bronze.competitor_stores_raw]
    end
    
    %% SILVER LAYER (Cleaned Data)
    subgraph "Silver Layer - Cleaned & Validated"
        S1[silver.crm]
        S2[silver.pos]
        S3[silver.stores]
        S4[silver.gis_counties]
        S5[silver.gis_locations]
        S6[silver.economic]
        S7[silver.competitors]
        S8[silver.competitor_stores]
    end
    
    %% GOLD LAYER (Analytical Models)
    subgraph "Gold Layer - Business Intelligence"
        G1[gold.customer_value]
        G2[gold.dim_county]
        G3[gold.fact_store_performance]
        G4[gold.location_scoring]
        G5[gold.market_gap_analysis]
        G6[gold.competitive_intensity]
    end
    
    %% Bronze to Silver Transformations
    B1 -->|Clean & Deduplicate| S1
    B2 -->|Validate & Standardize| S2
    B3 -->|Type Conversion| S3
    B4 -->|Calculate Metrics| S4
    B5 -->|Geocode & Score| S5
    B6 -->|Rollup & Impute| S6
    B7 -->|Profile Analysis| S7
    B8 -->|Correct Mapping| S8
    
    %% Silver to Gold Analytical Models
    S1 -->|RFM Analysis| G1
    S2 -->|Transaction Aggregation| G1
    S2 -->|Sales Performance| G3
    S2 -->|Revenue Calculation| G5
    S3 -->|Store Metrics| G2
    S3 -->|Store Performance| G3
    S4 -->|Demographics| G2
    S4 -->|Infrastructure| G2
    S5 -->|Site Assessment| G4
    S6 -->|Economic Indicators| G2
    S7 -->|Competitor Profiles| G6
    S8 -->|Competitive Presence| G2
    S8 -->|Competitive Analysis| G6
    
    %% Gold Layer Dependencies
    G1 -->|Customer Metrics| G2
    G2 -->|County Context| G4
    G2 -->|Market Analysis| G5
    G2 -->|Competitive Context| G6
    G1 -->|Customer Quality| G3
