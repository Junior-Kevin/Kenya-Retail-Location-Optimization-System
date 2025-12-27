# 🛒 Kenya Retail Location Optimization System

## 📋 Project Overview

A comprehensive end-to-end data analytics project simulating retail location optimization for a fictional supermarket chain **KenyaFresh Markets** expanding across Kenya’s **47 counties**.

This project demonstrates **full-stack data skills**:
- Synthetic data generation
- Data engineering (Bronze → Silver → Gold)
- Geospatial analytics
- Predictive modeling
- Business-ready dashboards

### 🎯 Business Problem
Optimize new store locations in Kenya to:
- Maximize projected revenue
- Minimize cannibalization of existing stores
- Ensure data-driven expansion decisions

### 💡 Solution
A scalable analytics system combining:
- Geospatial intelligence
- Demographic & economic indicators
- Predictive modeling
- Location scoring & ranking

---

## 🏗️ Architecture Overview

The system follows a **modern layered data architecture** designed for analytics, scalability, and decision support.

![Kenya Retail Location Optimization – Data Architecture](docs/Files/data_architecture.pdf)

---

## 🛠️ Project Structure

```text
kenya-retail-location-optimization/
│
├── README.md                     # Project overview
├── requirements.txt              # Python dependencies
├── setup.py                      # Installation script
│
├── bronze/                       # Raw data layer
│   ├── crm_raw.parquet
│   ├── pos_raw.parquet
│   ├── gis_counties_raw.parquet
│   ├── gis_locations_raw.parquet
│   ├── competitors_raw.parquet
│   └── economic_raw.parquet
│
├── silver/                       # Cleaned data layer
│   ├── cleaned/
│   └── enriched/
│
├── gold/                         # Business data layer
│   ├── dimensions/
│   ├── facts/
│   └── aggregated/
│
├── scripts/                      # Data generation & ETL scripts
│   ├── generate_crm_data.py
│   ├── generate_pos_data.py
│   ├── generate_gis_data.py
│   ├── generate_competitor_data.py
│   ├── generate_economic_data.py
│   ├── etl_pipeline.py
│   └── setup_directories.py
│
├── sql/                          # SQL validation & business queries
│   ├── data_quality_tests.sql
│   ├── transformation_queries.sql
│   └── business_queries.sql
│
├── notebooks/                    # Jupyter notebooks
│   ├── 01_data_exploration.ipynb
│   ├── 02_feature_engineering.ipynb
│   └── 03_model_training.ipynb
│
├── dashboard/                    # Tableau dashboards
│   ├── kenya_retail_dashboard.twbx
│   └── exported_images/
│
├── docs/                         # Documentation
│   ├── project_specification.md
│   ├── methodology.md
│   └── user_guide.md
│
├── tests/                        # Unit & pipeline tests
│   ├── test_data_generation.py
│   └── test_etl_pipeline.py
│
└── logs/                         # Pipeline execution logs
    └── etl_pipeline.log
📊 Key Outputs
Location suitability scores

County and town-level demand projections

Cannibalization risk analysis

Executive-ready dashboards

🚀 Tech Stack
Database: SQL Server

Data Engineering: Python, SQL

Analytics: Pandas, GeoPandas, Scikit-learn

Visualization: Tableau

Architecture Design: draw.io

Version Control: Git & GitHub

👤 Author
Junior Kevin
Data Analyst | Data Engineer | Analytics Enthusiast

yaml
Copy code
