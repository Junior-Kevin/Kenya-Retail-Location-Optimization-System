📋 Project Overview

A comprehensive end-to-end data analytics project simulating retail location optimization for a fictional supermarket chain "KenyaFresh Markets" expanding across Kenya's 47 counties. This project demonstrates full-stack data skills from synthetic data generation to predictive modeling and interactive dashboards.

🎯 Business Problem: Optimize new store locations in Kenya to maximize revenue while minimizing cannibalization of existing stores.

💡 Solution: A data-driven system combining geospatial analysis, predictive modeling, and market intelligence to score and rank potential locations.

🏗️ Architecture Overview

This project implements a medallion architecture with three layers:
text

┌─────────────────────────────────────────────────────────────┐
│                      DATA GENERATION LAYER                  │
│ 5 Simulated Systems: CRM, POS, GIS, Competitor Intel,       │
│ Economic Indicators → BRONZE Layer (Raw Data)               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                      ETL PROCESSING LAYER                   │
│ Data Cleaning → Validation → Enrichment → SILVER Layer      │
│ (Cleaned & Standardized)                                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                      ANALYTICS LAYER                        │
│ Dimension Tables → Fact Tables → ML Models → GOLD Layer     │
│ (Business-Ready Data)                                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
            ┌──────────▼──────────┐
            │   TABLEAU DASHBOARD │
            │  (Business Insights)│
            └─────────────────────┘

📊 Dataset Specifications
Dataset	Records	Description	Data Quality Challenges
CRM Data	50,000 customers	Customer demographics, segments, purchase behavior	Missing emails, duplicates, outliers
POS Transactions	200,000+ line items	Sales data across 100 simulated stores	Negative quantities, invalid dates
GIS Locations	47 counties + 1,500+ sites	Geographic and economic indicators	Missing coordinates, inconsistent names
Competitor Intel	8 chains + 150+ stores	Market research on competitors	Missing revenue data, date issues
Economic Indicators	Monthly data for 2023	County-level economic metrics	Missing values, outliers

🛠️ Project Structure
kenya-retail-location-optimization/
│
├── README.md                           # Project overview
├── requirements.txt                    # Python dependencies
├── setup.py                            # Installation script
│
├── bronze/                             # Raw data layer
│   ├── crm_raw.parquet
│   ├── pos_raw.parquet
│   ├── gis_counties_raw.parquet
│   ├── gis_locations_raw.parquet
│   ├── competitors_raw.parquet
│   └── economic_raw.parquet
│
├── silver/                             # Cleaned data layer
│   ├── cleaned/
│   └── enriched/
│
├── gold/                               # Business data layer
│   ├── dimensions/
│   ├── facts/
│   └── aggregated/
│
├── scripts/                            # Generation and ETL scripts
│   ├── generate_crm_data.py
│   ├── generate_pos_data.py
│   ├── generate_gis_data.py
│   ├── generate_competitor_data.py
│   ├── generate_economic_data.py
│   ├── etl_pipeline.py
│   └── setup_directories.py
│
├── sql/                                # SQL test queries
│   ├── data_quality_tests.sql
│   ├── transformation_queries.sql
│   └── business_queries.sql
│
├── notebooks/                          # Jupyter notebooks
│   ├── 01_data_exploration.ipynb
│   ├── 02_feature_engineering.ipynb
│   └── 03_model_training.ipynb
│
├── dashboard/                          # Tableau files
│   ├── kenya_retail_dashboard.twbx
│   └── exported_images/
│
├── docs/                               # Documentation
│   ├── project_specification.md
│   ├── methodology.md
│   └── user_guide.md
│
├── tests/                              # Test files
│   ├── test_data_generation.py
│   └── test_etl_pipeline.py
│
└── logs/                               # Pipeline logs
    └── etl_pipeline.log
