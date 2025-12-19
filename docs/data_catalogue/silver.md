# 📘 Silver Layer Data Catalogue

**Project:** Kenya Retail Location Optimization System
**Layer:** Silver (Cleaned & Validated)
**Version:** 1.2
**Date:** December 2025
**Author:** Junior Kevin
**Status:** Active

---

## 📑 Document Control

| Item                | Details                                                 |
| ------------------- | ------------------------------------------------------- |
| Project Name        | Kenya Retail Location Optimization System               |
| Layer               | Silver (Cleaned & Validated)                            |
| Data Classification | Synthetic – For Learning & Portfolio                    |
| Update Frequency    | Daily via ETL pipeline                                  |
| Retention Policy    | Keep for project duration                               |
| Owner               | Data Engineering Team                                   |
| Contact             | [your-email@example.com](mailto:your-email@example.com) |

---

## 📊 Overview

The **Silver Layer** contains cleaned, validated, and standardized datasets derived from the Bronze Layer. It serves as the analytical foundation for BI reporting and Gold-layer transformations.

**Key Principles**

* Cleaned – Data quality issues resolved
* Validated – Business rules enforced
* Standardized – Consistent schemas and formats
* Type-safe – Proper SQL data types applied
* Audited – Load timestamps and transformation tracking

**Storage Specifications**

* **Database:** `Retail_location`
* **Schema:** `silver`
* **Format:** SQL Server tables
* **Compression:** Page compression
* **Backups:** Daily automated backups

---

## 📁 Dataset Inventory

## 1️⃣ CRM Customers (`crm`)

**Source:** `bronze.crm_raw`
**Purpose:** Cleaned customer master data for segmentation and lifecycle analysis

### Transformations

| Bronze Issue           | Silver Resolution                          |
| ---------------------- | ------------------------------------------ |
| Duplicate customer IDs | Deduplication (earliest registration kept) |
| Missing email / phone  | Standardized to `unknown`                  |
| Inconsistent casing    | Proper casing applied                      |
| Multiple date formats  | Standardized to `DATE`                     |
| Numeric outliers       | Validated within ranges                    |

### Schema

| Column                     | Type          | Null | PK | Description         | Transformation         |
| -------------------------- | ------------- | ---- | -- | ------------------- | ---------------------- |
| customer_id                | NVARCHAR(20)  | NO   | ✅  | Standardized ID     | `CUST_` prefix         |
| first_name                 | NVARCHAR(50)  | NO   |    | First name          | Trimmed                |
| last_name                  | NVARCHAR(50)  | NO   |    | Last name           | Trimmed                |
| gender                     | NVARCHAR(10)  | YES  |    | Gender              | —                      |
| phone                      | NVARCHAR(50)  | YES  |    | Phone               | NULL → `unknown`       |
| email                      | NVARCHAR(100) | YES  |    | Email               | NULL → `email@unknown` |
| county                     | NVARCHAR(50)  | YES  |    | County              | Trimmed                |
| area                       | NVARCHAR(50)  | YES  |    | Area                | Trimmed                |
| customer_segment           | NVARCHAR(50)  | YES  |    | Segment             | Trimmed                |
| registration_date          | DATE          | YES  |    | Registration date   | Parsed                 |
| customer_status            | NVARCHAR(20)  | YES  |    | Status              | Trimmed                |
| last_purchase_date         | DATE          | YES  |    | Last purchase       | Parsed                 |
| purchase_frequency_monthly | INT           | YES  |    | Purchases/month     | ≥ 0                    |
| avg_transaction_value_kes  | DECIMAL(18,2) | YES  |    | Avg spend           | Cast                   |
| lifetime_value_kes         | DECIMAL(18,2) | YES  |    | LTV                 | Cast                   |
| preferred_store_format     | NVARCHAR(50)  | YES  |    | Store format        | Trimmed                |
| communication_preferences  | NVARCHAR(100) | YES  |    | Preferences         | Trimmed                |
| feedback_score             | DECIMAL(3,1)  | YES  |    | Satisfaction (0–10) | Range check            |
| data_source                | NVARCHAR(30)  | YES  |    | Source system       | —                      |
| extracted_date             | DATE          | YES  |    | Extract date        | —                      |
| record_version             | INT           | YES  |    | Version             | —                      |
| load_timestamp             | DATETIME      | NO   |    | Load time           | `GETDATE()`            |

**Constraints**

```sql
PRIMARY KEY (customer_id)
CHECK (feedback_score BETWEEN 0 AND 10)
CHECK (purchase_frequency_monthly >= 0)
```

**Indexes**

* `idx_crm_customer_id (customer_id)`
* `idx_crm_county (county)`

---

## 2️⃣ POS Transactions (`pos`)

**Source:** `bronze.pos_raw`
**Purpose:** Cleaned transactional sales data

### Transformations

| Bronze Issue        | Silver Resolution           |
| ------------------- | --------------------------- |
| Invalid dates       | Corrected / parsed          |
| Negative prices     | Set to 0                    |
| Excessive discounts | Capped at total price       |
| Anonymous customers | Standardized to `ANONYMOUS` |

### Schema (Core Fields)

| Column           | Type          | Null | Description      |
| ---------------- | ------------- | ---- | ---------------- |
| transaction_id   | NVARCHAR(100) | NO   | Transaction ID   |
| transaction_date | DATE          | NO   | Transaction date |
| store_id         | NVARCHAR(50)  | NO   | Store ID         |
| customer_id      | NVARCHAR(50)  | YES  | Customer ID      |
| product_id       | NVARCHAR(100) | YES  | Product ID       |
| quantity         | INT           | YES  | Quantity ≥ 0     |
| unit_price_kes   | DECIMAL(18,2) | YES  | Unit price       |
| discount_kes     | DECIMAL(18,2) | YES  | Discount         |
| final_price_kes  | DECIMAL(18,2) | YES  | Final price      |
| payment_method   | NVARCHAR(50)  | YES  | Payment type     |
| load_timestamp   | DATETIME      | NO   | Load timestamp   |

**Indexes**

* `idx_pos_transaction_date`
* `idx_pos_customer_id`
* `idx_pos_store_id`

---

## 3️⃣ Store Locations (`stores`)

**Source:** `bronze.stores_raw`

| Column         | Type          | Null | PK | Description  |
| -------------- | ------------- | ---- | -- | ------------ |
| store_id       | NVARCHAR(50)  | NO   | ✅  | Store ID     |
| store_name     | NVARCHAR(100) | YES  |    | Store name   |
| county         | NVARCHAR(50)  | YES  |    | County       |
| format         | NVARCHAR(50)  | YES  |    | Store format |
| size_sqm       | INT           | YES  |    | Store size   |
| load_timestamp | DATETIME      | NO   |    | Load time    |

---

## 4️⃣ GIS Counties (`gis_counties`)

**Source:** `bronze.gis_counties_raw`

Standardized county-level demographic and economic indicators.

| Column                   | Type          | Description        |
| ------------------------ | ------------- | ------------------ |
| county_id                | NVARCHAR(50)  | County ID          |
| county_name              | NVARCHAR(50)  | County name        |
| population_2023          | INT           | Population         |
| area_sqkm                | DECIMAL(18,2) | Area               |
| population_density_psqkm | DECIMAL(18,2) | Calculated density |
| poverty_rate             | DECIMAL(5,2)  | Poverty %          |
| unemployment_rate        | DECIMAL(5,2)  | Unemployment %     |
| urbanization_rate        | DECIMAL(5,2)  | Urban %            |
| latitude                 | DECIMAL(10,6) | Centroid latitude  |
| longitude                | DECIMAL(10,6) | Centroid longitude |
| load_timestamp           | DATETIME      | Load time          |

---

## 🔗 Data Relationships

| Dataset           | Primary Key          | Foreign Keys                |
| ----------------- | -------------------- | --------------------------- |
| crm               | customer_id          | —                           |
| pos               | transaction_id       | customer_id → crm           |
| pos               | transaction_id       | store_id → stores           |
| stores            | store_id             | —                           |
| gis_counties      | county_id            | —                           |
| gis_locations     | location_id          | county → gis_counties       |
| competitors       | competitor_id        | —                           |
| competitor_stores | store_id             | competitor_id → competitors |
| economic          | (county, year_month) | —                           |

---

## ⚙️ ETL Process

* **Procedure:** `silver.usp_LoadSilverLayer`
* **Frequency:** Daily incremental loads
* **Transaction Handling:** Full atomic transaction
* **Logging:** Load timestamps & debug prints

```text
Bronze → Validation → Cleaning → Transformation → Silver
```

---

## 📈 Performance Metrics

| Metric            | Target | Status     |
| ----------------- | ------ | ---------- |
| Data Completeness | >95%   | ✅ Achieved |
| Data Accuracy     | >99%   | ✅ Achieved |
| Processing Time   | <5 min | ~49 sec    |
| Error Rate        | <0.1%  | 0%         |

---

## 🔐 Data Governance

* **Confidentiality:** Public (Synthetic)
* **Integrity:** High
* **Availability:** High
* **Modification:** ETL-controlled only

---

## 📋 Change Log

| Date       | Version | Description              |
| ---------- | ------- | ------------------------ |
| 2025-12-19 | 1.0     | Initial Silver layer     |
| 2025-12-19 | 1.1     | Competitor store mapping |
| 2025-12-19 | 1.2     | Decimal score fixes      |

---

**End of Silver Layer Data Catalogue**
