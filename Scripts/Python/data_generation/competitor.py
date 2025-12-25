# generate_competitor_data.py
import pandas as pd
import numpy as np
import random
from faker import Faker
from datetime import datetime, timedelta
import json
import os
from towns import KENYAN_COUNTIES, get_random_town, get_weighted_town

fake = Faker('en_KE')
np.random.seed(45)
random.seed(45)

def generate_competitor_data():
    """Generate competitor intelligence data"""
    
    print("Generating competitor intelligence data...")
    
    # Major competitors in Kenya (operational as of 2025)
    competitors = [
        {'name': 'Naivas', 'type': 'Local Chain', 'founded': 1990, 'store_count': 110},
        {'name': 'Quickmart', 'type': 'Local Chain', 'founded': 2006, 'store_count': 60},
        {'name': 'Carrefour', 'type': 'International', 'founded': 2016, 'store_count': 28},
        {'name': 'Chandarana Foodplus', 'type': 'Local Chain', 'founded': 1964, 'store_count': 29},
        {'name': 'Eastmatt', 'type': 'Local Chain', 'founded': 1990, 'store_count': 11},
        {'name': 'Cleanshelf', 'type': 'Local Chain', 'founded': 2002, 'store_count': 16},
        {'name': 'Khetia\'s Supermarket', 'type': 'Local Chain', 'founded': 1982, 'store_count': 25},
        {'name': 'Magunas Supermarket', 'type': 'Local Chain', 'founded': 1985, 'store_count': 32},
        {'name': 'Tumaini Supermarket', 'type': 'Local Chain', 'founded': 2010, 'store_count': 14},
        {'name': 'Powerstar Supermarket', 'type': 'Local Chain', 'founded': 2012, 'store_count': 10},
        {'name': 'Mathai\'s Supermarket', 'type': 'Local Chain', 'founded': 2015, 'store_count': 9},
        {'name': 'Society Stores', 'type': 'Local Chain', 'founded': 2013, 'store_count': 8},
        {'name': 'Village Supermarket', 'type': 'Local Chain', 'founded': 2005, 'store_count': 5},
        {'name': 'Woolmatt Supermarket', 'type': 'Local Chain', 'founded': 2018, 'store_count': 9},
        {'name': 'Panda Mart', 'type': 'International', 'founded': 2021, 'store_count': 1}
    ]
    
    competitor_data = []
    store_data = []
    
    for comp in competitors:
        comp_id = f"COMP-{comp['name'][:3].upper()}"
        
        # Financial estimates
        if comp['type'] == 'International':
            avg_store_revenue = np.random.uniform(20000000, 50000000)  # 20-50M KES monthly
        else:
            avg_store_revenue = np.random.uniform(5000000, 20000000)  # 5-20M KES monthly
        
        # Market positioning
        positioning = np.random.choice(['Premium', 'Mass Market', 'Value', 'Convenience'], 
                                     p=[0.2, 0.4, 0.3, 0.1])
        
        # Customer demographics
        target_demographic = {
            'Premium': 'Upper Middle & Above',
            'Mass Market': 'All Segments',
            'Value': 'Lower & Middle Class',
            'Convenience': 'Urban Professionals'
        }[positioning]
        
        # Pricing strategy
        pricing_index = np.random.uniform(0.8, 1.2)  # Relative to market average
        
        # Store formats
        formats = []
        if comp['type'] == 'International':
            formats = ['Hypermarket', 'Supermarket']
        else:
            formats = np.random.choice(['Supermarket', 'Mini-mart', 'Express'], 
                                     size=np.random.randint(1, 3), replace=False)
        
        # Strengths and weaknesses
        strengths = np.random.choice([
            'Strong Supply Chain',
            'Customer Loyalty',
            'Prime Locations',
            'Private Label Products',
            'Digital Presence',
            'Fresh Produce Quality',
            'Competitive Pricing'
        ], size=3, replace=False)
        
        weaknesses = np.random.choice([
            'High Prices',
            'Limited Locations',
            'Poor Customer Service',
            'Stock Issues',
            'Aging Stores',
            'Limited Parking',
            'Weak Digital Strategy'
        ], size=2, replace=False)
        
        competitor_record = {
            'competitor_id': comp_id,
            'competitor_name': comp['name'],
            'competitor_type': comp['type'],
            'year_founded': comp['founded'],
            'total_stores': comp['store_count'],
            'estimated_market_share': round(np.random.uniform(0.5, 25), 2),  # Percentage
            'avg_store_revenue_kes_monthly': round(avg_store_revenue, 2),
            'positioning': positioning,
            'target_demographic': target_demographic,
            'pricing_index': round(pricing_index, 2),
            'store_formats': '|'.join(formats),
            'key_strengths': '|'.join(strengths),
            'key_weaknesses': '|'.join(weaknesses),
            'last_updated': datetime.now().date(),
            'data_source': 'Competitor_Intel_System'
        }
        
        competitor_data.append(competitor_record)
        
        # Generate store locations for this competitor
        stores_to_generate = min(comp['store_count'], 20)  # Cap at 20 for data size
        
        for store_num in range(stores_to_generate):
            store_id = f"{comp_id}-STORE-{store_num+1:03d}"
            
            # Select county (biased towards urban counties)
            if comp['type'] == 'International':
                county_probs = [0.6, 0.3, 0.1] + [0] * (len(KENYAN_COUNTIES) - 3)
            else:
                county_probs = [0.3, 0.2, 0.1, 0.1, 0.1] + [0.05] * 5 + [0.01] * (len(KENYAN_COUNTIES) - 10)
            
            # Normalize probabilities
            county_probs = [p/sum(county_probs) for p in county_probs]
            county_probs += [0] * (len(KENYAN_COUNTIES) - len(county_probs))
            
            county = np.random.choice(KENYAN_COUNTIES, p=county_probs)
            town = get_weighted_town(county)
            
            # Store characteristics
            store_size = np.random.choice([300, 800, 1500, 3000, 5000], 
                                        p=[0.2, 0.3, 0.3, 0.15, 0.05])
            store_format = np.random.choice(formats)
            
            # Opening date
            years_old = 2024 - comp['founded']
            opening_year = comp['founded'] + np.random.randint(0, years_old)
            opening_date = datetime(opening_year, np.random.randint(1, 13), np.random.randint(1, 28))
            
            # Estimated performance
            monthly_revenue = avg_store_revenue * np.random.uniform(0.7, 1.3)
            customer_traffic = int(monthly_revenue / 500)  # Rough estimate
            
            # Location score
            location_score = np.random.randint(5, 10)
            
            store_record = {
                'store_id': store_id,
                'competitor_id': comp_id,
                'competitor_name': comp['name'],
                'county': county,
                'town': town,
                'store_size_sqm': store_size,
                'store_format': store_format,
                'opening_date': opening_date.date(),
                'estimated_monthly_revenue_kes': round(monthly_revenue, 2),
                'estimated_daily_customers': customer_traffic,
                'location_score': location_score,
                'parking_available': np.random.choice(['Yes', 'Limited', 'No'], p=[0.6, 0.3, 0.1]),
                'has_delivery': np.random.choice(['Yes', 'No'], p=[0.7, 0.3]),
                'last_verified': fake.date_between(start_date='-180d', end_date='today'),
                'data_source': 'Field_Research'
            }
            
            store_data.append(store_record)
    
    df_competitors = pd.DataFrame(competitor_data)
    df_competitor_stores = pd.DataFrame(store_data)
    
    # Add data quality issues
    # 1. Missing revenue data for some stores
    missing_revenue = np.random.random(len(df_competitor_stores)) < 0.05
    df_competitor_stores.loc[missing_revenue, 'estimated_monthly_revenue_kes'] = np.nan
    
    # 2. Inconsistent date formats
    date_inconsistent = np.random.random(len(df_competitor_stores)) < 0.02
    df_competitor_stores.loc[date_inconsistent, 'opening_date'] = df_competitor_stores.loc[date_inconsistent, 'opening_date'].astype(str) + 'T00:00:00'
    
    # 3. Duplicate stores
    duplicate_stores = df_competitor_stores.sample(n=int(len(df_competitor_stores) * 0.03), random_state=42)
    duplicate_stores = duplicate_stores.copy()
    duplicate_stores['store_id'] = duplicate_stores['store_id'] + '-DUP'
    df_competitor_stores = pd.concat([df_competitor_stores, duplicate_stores], ignore_index=True)
    
    print(f"Generated data for {len(df_competitors)} competitors and {len(df_competitor_stores)} stores")
    print(f"Data quality issues: Missing revenue ({missing_revenue.sum()}), "
          f"Inconsistent dates ({date_inconsistent.sum()}), "
          f"Duplicates ({len(duplicate_stores)})")
    
    return df_competitors, df_competitor_stores

# Generate competitor data
os.makedirs('bronze', exist_ok=True)
competitors_df, competitor_stores_df = generate_competitor_data()

# Save to bronze layer
competitors_df.to_csv('bronze/competitors_raw.csv', index=False)
competitor_stores_df.to_csv('bronze/competitor_stores_raw.csv', index=False)

print("\nSample competitor data:")
print(competitors_df[['competitor_name', 'competitor_type', 'total_stores', 'estimated_market_share', 'positioning']])
print("\nSample competitor store data:")
print(competitor_stores_df[['store_id', 'competitor_name', 'county', 'store_format', 'estimated_monthly_revenue_kes']].head())