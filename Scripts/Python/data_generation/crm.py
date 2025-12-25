# generate_crm_data.py
import pandas as pd
import numpy as np
from faker import Faker
import random
from datetime import datetime, timedelta
import json
import os
from towns import KENYAN_COUNTIES, get_weighted_town, get_random_town

# Initialize Faker for Kenyan context
fake = Faker('en_KE')
np.random.seed(42)
random.seed(42)

# Customer segments for Kenya
customer_segments = [
    'Mass Market', 'Lower Middle', 'Middle Class', 'Upper Middle', 'Premium',
    'Corporate Clients', 'Students', 'Tourists', 'Expatriates'
]

# Generate CRM data with realistic Kenyan context
def generate_crm_dataset(num_customers=150000):
    """Generate synthetic CRM data for Kenyan retail customers"""
    
    print("Generating CRM dataset...")
    
    data = []
    
    for i in range(num_customers):
        customer_id = f"CUST-{2023000000 + i}"
        
        # Personal information
        first_name = fake.first_name()
        last_name = fake.last_name()
        gender = np.random.choice(['Male', 'Female'], p=[0.44, 0.56])
        
        # Kenyan phone numbers
        phone_prefixes = ['070', '071', '072', '073', '074', '075', '076', '077', '078', '079']
        phone = f"+254{random.choice(phone_prefixes)}{random.randint(1000000, 9999999)}"
        email = f"{first_name.lower()}.{last_name.lower()}{random.randint(1, 999)}@gmail.com"
        
        # Location with realistic Kenyan distribution
        weights = []
        for county in KENYAN_COUNTIES:
            if county == 'Nairobi':
                weights.append(25)  # 25 times more likely
            elif county == 'Mombasa':
                weights.append(10)  # 10 times more likely
            elif county in ['Kisumu', 'Nakuru', 'Kiambu', 'Uasin Gishu', 'Meru']:
                weights.append(3)   # 3 times more likely
            else:
                weights.append(1)   # Base weight

        # Convert to probabilities
        county_probs = np.array(weights) / sum(weights)
        county = np.random.choice(KENYAN_COUNTIES, p=county_probs)
        
        # Urban centers within counties
        area = get_random_town(county)
        
        # Customer segmentation based on county and random factors
        if county == 'Nairobi':
            segment_probs = [0.1, 0.15, 0.25, 0.2, 0.1, 0.15, 0.03, 0.01, 0.01]
        elif county == 'Mombasa':
            segment_probs = [0.15, 0.2, 0.25, 0.15, 0.05, 0.1, 0.05, 0.04, 0.01]
        else:
            segment_probs = [0.25, 0.3, 0.25, 0.1, 0.02, 0.03, 0.03, 0.01, 0.01]
            
        segment = np.random.choice(customer_segments, p=segment_probs)
        
        # Registration date (some customers registered years ago)
        registration_date = fake.date_between(start_date='-5y', end_date='today')
        
        # Customer status
        status_probs = [0.85, 0.08, 0.05, 0.02]  # Active, Inactive, Suspended, Churned
        status = np.random.choice(['Active', 'Inactive', 'Suspended', 'Churned'], p=status_probs)
        
        # Last purchase date (if active, more recent)
        if status == 'Active':
            last_purchase = fake.date_between(start_date='-30d', end_date='today')
        elif status == 'Inactive':
            last_purchase = fake.date_between(start_date='-180d', end_date='-90d')
        else:
            last_purchase = fake.date_between(start_date='-365d', end_date='-180d')
        
        # Purchase frequency (times per month)
        if segment in ['Premium', 'Corporate Clients']:
            purchase_freq = np.random.poisson(8)  # 8 times/month
        elif segment in ['Upper Middle', 'Middle Class']:
            purchase_freq = np.random.poisson(4)
        else:
            purchase_freq = np.random.poisson(2)
        
        # Average transaction value (in KES)
        segment_atv = {
            'Mass Market': (200, 500),
            'Lower Middle': (500, 1500),
            'Middle Class': (1500, 5000),
            'Upper Middle': (5000, 15000),
            'Premium': (15000, 50000),
            'Corporate Clients': (10000, 100000),
            'Students': (300, 1000),
            'Tourists': (2000, 10000),
            'Expatriates': (10000, 30000)
        }
        atv_range = segment_atv[segment]
        avg_transaction_value = np.random.uniform(atv_range[0], atv_range[1])
        
        # Total lifetime value
        months_active = (datetime.now().date() - registration_date).days / 30
        lifetime_value = avg_transaction_value * purchase_freq * max(1, months_active)
        
        # Preferred store format
        store_formats = ['Supermarket', 'Mini-mart', 'Express Store', 'All']
        if segment in ['Corporate Clients', 'Premium']:
            format_probs = [0.6, 0.3, 0.1, 0.0]
        elif segment in ['Students', 'Mass Market']:
            format_probs = [0.3, 0.5, 0.2, 0.0]
        else:
            format_probs = [0.4, 0.4, 0.2, 0.0]
        preferred_format = np.random.choice(store_formats, p=format_probs)
        
        # Communication preferences (Kenyan context)
        communication_prefs = np.random.choice([
            'SMS',
            'Email',
            'WhatsApp',
            'Phone Call',
            'All'
        ], size=np.random.randint(1, 4), replace=False)
        
        # Customer feedback score (1-5)
        feedback_score = np.random.normal(4.2, 0.8)
        feedback_score = max(1, min(5, round(feedback_score, 1)))
        
        # Create the record
        record = {
            'customer_id': customer_id,
            'first_name': first_name,
            'last_name': last_name,
            'gender': gender,
            'phone': phone,
            'email': email,
            'county': county,
            'area': area,
            'customer_segment': segment,
            'registration_date': registration_date,
            'customer_status': status,
            'last_purchase_date': last_purchase,
            'purchase_frequency_monthly': purchase_freq,
            'avg_transaction_value_kes': round(avg_transaction_value, 2),
            'lifetime_value_kes': round(lifetime_value, 2),
            'preferred_store_format': preferred_format,
            'communication_preferences': '|'.join(communication_prefs),
            'feedback_score': feedback_score,
            'data_source': 'CRM_System',
            'extracted_date': datetime.now().date(),
            'record_version': 1
        }
        
        data.append(record)
    
    df = pd.DataFrame(data)
    
    # Add some data quality issues (real-world scenarios)
    # 1. Missing values
    missing_mask = np.random.random(len(df)) < 0.05
    df.loc[missing_mask, 'email'] = np.nan
    
    missing_mask = np.random.random(len(df)) < 0.03
    df.loc[missing_mask, 'phone'] = np.nan
    
    # 2. Duplicate records (5% duplication rate)
    duplicates = df.sample(n=int(len(df) * 0.05), random_state=42)
    duplicates = duplicates.copy()
    duplicates['customer_id'] = duplicates['customer_id'] + '-DUP'
    df = pd.concat([df, duplicates], ignore_index=True)
    
    # 3. Inconsistent formats
    date_mask = np.random.random(len(df)) < 0.02
    df.loc[date_mask, 'registration_date'] = df.loc[date_mask, 'registration_date'].astype(str) + 'T00:00:00'
    
    # 4. Outliers in transaction values
    outlier_mask = np.random.random(len(df)) < 0.01
    df.loc[outlier_mask, 'avg_transaction_value_kes'] = df.loc[outlier_mask, 'avg_transaction_value_kes'] * 100
    
    print(f"Generated {len(df)} CRM records")
    print(f"Data quality issues injected: Missing emails ({df['email'].isna().sum()}), "
          f"Duplicates ({len(duplicates)}), Outliers ({outlier_mask.sum()})")
    
    return df

# Generate and save the CRM data
os.makedirs('bronze', exist_ok=True)
crm_df = generate_crm_dataset(150000)
crm_df.to_csv('bronze/crm_raw.csv', index=False)

print("\nSample of CRM data:")
print(crm_df[['customer_id', 'county', 'customer_segment', 'avg_transaction_value_kes', 'customer_status']].head(10))
print(f"\nCounty distribution:\n{crm_df['county'].value_counts().head()}")
print(f"\nSegment distribution:\n{crm_df['customer_segment'].value_counts()}")