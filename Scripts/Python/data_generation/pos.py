# generate_pos_data.py
import pandas as pd
import numpy as np
from faker import Faker
import random
import os
from datetime import datetime, timedelta
from towns import KENYAN_COUNTIES, get_random_town, get_weighted_town
fake = Faker('en_KE')
np.random.seed(43)
random.seed(43)

# Product categories for Kenyan retail
product_categories = {
    'FMCG': ['Food & Beverages','Snacks & Confectionery','Beverages (Tea, Coffee, Soft Drinks)',
        'Personal Care','Oral Care','Hair Care','Body Care','Household Items','Cleaning Supplies',
        'Laundry Detergents','Cooking Essentials (Oil, Salt, Sugar)'],
    'Fresh': ['Fruits & Vegetables','Exotic Fruits','Root Vegetables','Meat & Poultry',
        'Beef','Chicken','Lamb','Dairy','Milk & Cream','Cheese & Yogurt','Eggs','Bakery',
        'Bread & Rolls','Pastries & Cakes'],
    'Non-Food': ['Electronics','Mobile Phones & Accessories','Computers & Peripherals','Clothing',
        'Men\'s Wear','Women\'s Wear','Children\'s Wear','Footwear','Home Appliances',
        'Kitchen Appliances','Laundry Appliances','Stationery','Office Supplies','School Supplies','Books & Magazines'],
    'Services': ['Money Transfer','Bill Payments','Airtime & Data','Lottery & Betting','Mobile Banking Services',
        'Customer Loyalty Programs','Gift Cards & Vouchers'],
    'Health & Wellness': ['Pharmacy','Vitamins & Supplements','Fitness & Sports Equipment','Personal Protective Equipment'],
    'Beauty & Fashion': ['Cosmetics','Perfumes & Fragrances','Jewelry & Accessories','Eyewear'],
    'Home & Living': ['Furniture','Home Décor','Kitchenware','Gardening Supplies'],
    'Automotive': ['Car Accessories','Motorbike Accessories','Lubricants & Fluids']
}

# Store locations across Kenya (simulated existing stores)
store_locations = []

for i in range(1, 101):  # 100 stores across Kenya
    county = np.random.choice(KENYAN_COUNTIES)
    town = get_random_town(county)  # Assuming you have a function to get a random town in the county
    
    store_locations.append({
        'store_id': f"STORE-{i:03d}",
        'store_name': f"{town} Branch",
        'county': county,
        'format': np.random.choice(
            ['Supermarket', 'Mini-mart', 'Express Store', 'Hypermarket'], 
            p=[0.4, 0.3, 0.2, 0.1]
        ),
        'size_sqm': np.random.choice(
            [100, 300, 800, 2000, 5000], 
            p=[0.2, 0.4, 0.25, 0.1, 0.05]
        )
    })

def generate_pos_transactions(num_transactions=200000, start_date='2023-01-01', end_date='2023-12-31'):
    """Generate POS transaction data"""
    
    print("Generating POS transaction data...")
    
    start_dt = datetime.strptime(start_date, '%Y-%m-%d')
    end_dt = datetime.strptime(end_date, '%Y-%m-%d')
    
    data = []
    
    # Generate base transactions
    for i in range(num_transactions):
        transaction_id = f"TXN-{2023000000 + i}"
        
        # Select store
        store = random.choice(store_locations)
        store_id = store['store_id']
        store_county = store['county']
        
        # Generate transaction date/time
        transaction_date = fake.date_time_between(start_date=start_dt, end_date=end_dt)
        
        # Generate customer (some will be anonymous)
        if np.random.random() < 0.7:  # 70% with customer ID
            customer_id = f"CUST-{2023000000 + np.random.randint(0, 50000)}"
        else:
            customer_id = 'ANONYMOUS'
        
        # Generate items in transaction
        num_items = np.random.poisson(8) + 1  # 1-20 items
        
        for item_num in range(num_items):
            # Select product category and item
            category = np.random.choice(list(product_categories.keys()), 
                                      p=[0.25, 0.15, 0.1,0.21, 0.05,0.04,0.1,0.1])
            subcategory = np.random.choice(product_categories[category])
            
            # Generate product details
            product_id = f"PROD-{category[:3].upper()}-{np.random.randint(1000, 9999)}"
            
            # Price based on category and county
            base_price = {
                'FMCG': np.random.uniform(50, 500),
                'Fresh': np.random.uniform(30, 1000),
                'Non-Food': np.random.uniform(200, 5000),
                'Services': np.random.uniform(10, 500),
                'Health & Wellness': np.random.uniform(200, 8000),
                'Beauty & Fashion': np.random.uniform(500, 10000),
                'Home & Living': np.random.uniform(1000, 50000),
                'Automotive': np.random.uniform(300, 20000)
            }[category]
            
            # Adjust for county (Nairobi/Mombasa more expensive)
            if store_county in ['Nairobi', 'Mombasa']:
                price_multiplier = np.random.uniform(1.1, 1.3)
            else:
                price_multiplier = np.random.uniform(0.9, 1.1)
            
            unit_price = round(base_price * price_multiplier, 2)
            quantity = np.random.randint(1, 10)
            total_price = round(unit_price * quantity, 2)
            
            # Payment method (Kenyan context)
            payment_methods = ['Cash', 'M-Pesa', 'Card', 'Airtel Money', 'T-Kash', 'Bank Transfer']
            payment_probs = [0.4, 0.35, 0.15, 0.05, 0.03, 0.02]
            payment_method = np.random.choice(payment_methods, p=payment_probs)
            
            # Discount (some transactions have discounts)
            discount = 0
            if np.random.random() < 0.2:  # 20% of items have discount
                discount = round(total_price * np.random.uniform(0.05, 0.3), 2)
            
            final_price = total_price - discount
            
            # Staff ID
            staff_id = f"STAFF-{store_id.split('-')[1]}-{np.random.randint(1, 20):03d}"
            
            record = {
                'transaction_id': transaction_id,
                'transaction_date': transaction_date,
                'store_id': store_id,
                'store_county': store_county,
                'store_format': store['format'],
                'customer_id': customer_id,
                'line_item_id': f"{transaction_id}-{item_num+1:03d}",
                'product_id': product_id,
                'category': category,
                'subcategory': subcategory,
                'product_name': f"{subcategory} Product {np.random.randint(1, 100)}",
                'unit_price_kes': unit_price,
                'quantity': quantity,
                'total_price_kes': total_price,
                'discount_kes': discount,
                'final_price_kes': final_price,
                'payment_method': payment_method,
                'staff_id': staff_id,
                'data_source': 'POS_System',
                'extracted_timestamp': datetime.now()
            }
            
            data.append(record)
    
    df = pd.DataFrame(data)
    
    # Add data quality issues
    # 1. Missing customer IDs for some records that should have them
    missing_cust_mask = (df['customer_id'] != 'ANONYMOUS') & (np.random.random(len(df)) < 0.02)
    df.loc[missing_cust_mask, 'customer_id'] = np.nan
    
    # 2. Negative quantities (data entry errors)
    negative_qty_mask = np.random.random(len(df)) < 0.005
    df.loc[negative_qty_mask, 'quantity'] = df.loc[negative_qty_mask, 'quantity'] * -1
    
    # 3. Duplicate line items
    duplicate_mask = np.random.random(len(df)) < 0.01
    duplicates = df[duplicate_mask].copy()
    df = pd.concat([df, duplicates], ignore_index=True)
    
    # 4. Invalid dates
    invalid_date_mask = np.random.random(len(df)) < 0.003
    df.loc[invalid_date_mask, 'transaction_date'] = '2023-13-45 25:61:61'
    
    print(f"Generated {len(df)} POS transaction line items")
    print(f"Total transactions: {df['transaction_id'].nunique()}")
    print(f"Data quality issues: Missing customer IDs ({missing_cust_mask.sum()}), "
          f"Negative quantities ({negative_qty_mask.sum()}), "
          f"Invalid dates ({invalid_date_mask.sum()})")
    
    return df, pd.DataFrame(store_locations)

# Generate POS data
pos_df, stores_df = generate_pos_transactions(200000)

# Save to bronze layer
#os.makedirs('bronze', exist_ok=True)

pos_df.to_csv('pos_raw.csv', index=False)
#pos_df.to_parquet('pos_raw.parquet', index=False)

stores_df.to_csv('stores_raw.csv', index=False)
#stores_df.to_parquet('stores_raw.parquet', index=False)

print("\nSample POS data:")
print(pos_df[['transaction_id', 'store_county', 'category', 'quantity', 'final_price_kes']].head())
print(f"\nTransactions per county:\n{pos_df.groupby('store_county')['transaction_id'].nunique().sort_values(ascending=False).head()}")
print(f"\nPayment method distribution:\n{pos_df['payment_method'].value_counts()}")