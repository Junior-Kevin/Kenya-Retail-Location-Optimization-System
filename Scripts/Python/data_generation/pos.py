# generate_pos_data.py (UPDATED - FIXED NAN CATEGORY ERROR)
import pandas as pd
import numpy as np
from faker import Faker
import random
from datetime import datetime, timedelta, date
import os
from towns import KENYAN_COUNTIES, get_random_town

fake = Faker('en_KE')
np.random.seed(43)
random.seed(43)

# Store operating hours (for shift-based transaction timing)
STORE_OPERATING_HOURS = {
    'Supermarket': {'open': 7, 'close': 22},      # 7am-10pm
    'Mini-mart': {'open': 6, 'close': 23},        # 6am-11pm  
    'Express Store': {'open': 5, 'close': 24},    # 5am-12am
    'Hypermarket': {'open': 8, 'close': 21}       # 8am-9pm
}

# Shift hours mapping - EXPANDED to include possible invalid shifts
SHIFT_HOURS = {
    'Day': {'start': 7, 'end': 15},        # 7am-3pm
    'Night': {'start': 15, 'end': 23},     # 3pm-11pm
    'Standard': {'start': 8, 'end': 17},   # 8am-5pm (for managers)
    'Off': None,                           # No transactions
    'Invalid': None,                       # For data quality issues
    'Midnight': {'start': 22, 'end': 6},   # Handle midnight shift
    'Unknown': None                        # For unknown shifts
}

def load_hr_data():
    """Load HR data to get cashier assignments with shifts - UPDATED SHIFT HANDLING"""
    try:
        hr_df = pd.read_csv('bronze/hr_raw.csv')
        
        # Convert date columns properly
        date_columns = ['hiredate', 'birthdate', 'termdate', 'extracted_date']
        for col in date_columns:
            if col in hr_df.columns:
                hr_df[col] = pd.to_datetime(hr_df[col], errors='coerce')
        
        # Filter for active cashiers with store assignments
        # EXCLUDE terminated employees
        cashiers_df = hr_df[
            (hr_df['job_title'] == 'Cashier') & 
            (hr_df['store_id'].notna()) &
            (hr_df['shift'].notna()) &
            ((hr_df['termdate'].isna()) | (hr_df['termdate'] > pd.Timestamp('2025-12-31')))
        ]
        
        print(f"Loaded {len(cashiers_df)} active cashiers from HR data")
        
        # Clean shift values - map invalid shifts to valid ones
        def clean_shift(shift):
            if pd.isna(shift):
                return 'Day'  # Default to Day shift
            shift = str(shift).strip()
            # Map various shift values to standard ones
            if shift in ['Day', 'Night', 'Standard', 'Off']:
                return shift
            elif shift in ['Midnight', 'Late', 'Double', 'Unknown', 'Invalid']:
                # Map to Night shift for transaction generation
                return 'Night'
            else:
                # Default to Day for any other values
                return 'Day'
        
        cashiers_df['shift_clean'] = cashiers_df['shift'].apply(clean_shift)
        
        # Only use cashiers NOT on 'Off' shift for transactions
        active_cashiers_df = cashiers_df[cashiers_df['shift_clean'] != 'Off']
        
        print(f"Active cashiers (not on 'Off' shift): {len(active_cashiers_df)}")
        
        # Group cashiers by store and cleaned shift
        cashiers_by_store_shift = {}
        cashier_pool = []  # Master pool of cashiers
        
        for store_id, store_group in active_cashiers_df.groupby('store_id'):
            cashiers_by_store_shift[store_id] = {}
            for shift, shift_group in store_group.groupby('shift_clean'):
                if shift != 'Off':  # Don't include off-shift cashiers for transactions
                    cashier_ids = shift_group['employee_id'].tolist()
                    cashiers_by_store_shift[store_id][shift] = cashier_ids
                    
                    # Add to master pool
                    for cashier_id in cashier_ids:
                        cashier_pool.append({
                            'store_id': store_id,
                            'shift': shift,
                            'cashier_id': cashier_id,
                            'original_shift': shift_group[shift_group['employee_id'] == cashier_id]['shift'].iloc[0],
                            'from_store': True
                        })
        
        print(f"Created master pool of {len(cashier_pool)} cashiers from HR data")
        
        # Print shift distribution after cleaning
        print("\nShift distribution after cleaning:")
        shift_counts = active_cashiers_df['shift_clean'].value_counts()
        for shift, count in shift_counts.items():
            print(f"  {shift}: {count} cashiers")
        
        # Print cashier distribution summary
        print("\nCashier distribution summary:")
        total_stores = len(cashiers_by_store_shift)
        stores_with_day = sum(1 for store in cashiers_by_store_shift.values() if 'Day' in store)
        stores_with_night = sum(1 for store in cashiers_by_store_shift.values() if 'Night' in store)
        
        print(f"  Total stores with cashiers: {total_stores}")
        print(f"  Stores with Day shift cashiers: {stores_with_day}")
        print(f"  Stores with Night shift cashiers: {stores_with_night}")
        
        if total_stores > 0:
            # Print first few stores as example
            print("\nSample store cashier distribution (first 5 stores):")
            for i, (store_id, shift_dict) in enumerate(cashiers_by_store_shift.items()):
                if i < 5:
                    shift_summary = {shift: len(cashiers) for shift, cashiers in shift_dict.items()}
                    print(f"  {store_id}: {shift_summary}")
        
        return cashiers_by_store_shift, cashier_pool, hr_df, active_cashiers_df
    
    except FileNotFoundError:
        print("ERROR: HR data not found. Please generate HR data first.")
        print("Run: python generate_hr_data.py")
        return {}, [], pd.DataFrame(), pd.DataFrame()
    except Exception as e:
        print(f"ERROR loading HR data: {e}")
        return {}, [], pd.DataFrame(), pd.DataFrame()

def load_products_data():
    """Load products data from products_raw.csv"""
    try:
        products_df = pd.read_csv('bronze/products_raw.csv')
        print(f"Loaded {len(products_df)} products from products_raw.csv")
        
        # Clean data - remove products with NaN categories
        original_count = len(products_df)
        products_df = products_df.dropna(subset=['category'])
        cleaned_count = len(products_df)
        
        if original_count != cleaned_count:
            print(f"  Removed {original_count - cleaned_count} products with missing categories")
        
        # Display product distribution
        print("\nProduct distribution by category:")
        category_counts = products_df['category'].value_counts()
        for category, count in category_counts.items():
            percentage = (count / len(products_df)) * 100
            print(f"  {category}: {count} products ({percentage:.1f}%)")
        
        # Create lookup dictionaries for faster access
        products_by_category = {}
        product_details = {}
        
        for _, row in products_df.iterrows():
            category = row['category']
            product_id = row['product_id']
            
            # Skip if category is NaN
            if pd.isna(category):
                continue
                
            # Add to category-based lookup
            if category not in products_by_category:
                products_by_category[category] = []
            products_by_category[category].append(product_id)
            
            # Store product details
            product_details[product_id] = {
                'product_name': row['product_name'],
                'category': row['category'],
                'subcategory': row['subcategory'],
                'brand': row['brand'],
                'retail_price_kes': row['retail_price_kes']
            }
        
        # Calculate category probabilities based on actual distribution
        total_products = len(products_df)
        category_probs = {}
        
        for category, products in products_by_category.items():
            if category and not pd.isna(category):  # Skip NaN categories
                category_probs[category] = len(products) / total_products
        
        # Ensure all probabilities sum to 1
        prob_sum = sum(category_probs.values())
        if prob_sum > 0:
            category_probs = {k: v/prob_sum for k, v in category_probs.items()}
        
        print(f"\nCategory probabilities for POS transactions:")
        for category, prob in sorted(category_probs.items(), key=lambda x: x[1], reverse=True):
            print(f"  {category}: {prob:.3f}")
        
        print(f"\nTotal valid categories: {len(category_probs)}")
        
        return products_by_category, product_details, products_df, category_probs
    
    except FileNotFoundError:
        print("ERROR: Products data not found. Please generate products data first.")
        print("Run: python products_raw.py")
        return {}, {}, pd.DataFrame(), {}
    except Exception as e:
        print(f"ERROR loading products data: {e}")
        return {}, {}, pd.DataFrame(), {}

def load_store_data():
    """Load store data from HR-generated file or generate consistent stores"""
    try:
        # First try to load from HR-generated stores
        stores_df = pd.read_csv('bronze/stores_raw.csv')
        print(f"Loaded {len(stores_df)} stores from stores_raw.csv")
        return stores_df
    except FileNotFoundError:
        print("Generating consistent store data for POS...")
        # Generate stores that match HR data structure
        stores = []
        for i in range(1, 151):  # 150 stores
            county = np.random.choice(KENYAN_COUNTIES)
            town = get_random_town(county)
            
            store_format = np.random.choice(['Supermarket', 'Mini-mart', 'Express Store', 'Hypermarket'], 
                                          p=[0.4, 0.3, 0.2, 0.1])
            
            stores.append({
                'store_id': f"STR-{i:04d}",
                'store_name': f"KenyanFresh {town}",
                'county': county,
                'format': store_format,
                'size_sqm': np.random.choice([100, 300, 800, 2000, 5000], 
                                            p=[0.2, 0.4, 0.25, 0.1, 0.05])
            })
        
        stores_df = pd.DataFrame(stores)
        stores_df.to_csv('bronze/stores_raw.csv', index=False)
        print(f"Generated and saved {len(stores_df)} stores to stores_raw.csv")
        return stores_df

def ensure_all_stores_have_cashiers(cashiers_by_store_shift, cashier_pool, hr_df, active_cashiers_df):
    """Ensure all stores have at least some cashiers assigned - UPDATED"""
    # First, check if we have enough cashiers overall
    total_cashiers_needed = 150 * 2  # Rough estimate: 2 cashiers per store (Day/Night)
    
    if len(cashier_pool) < total_cashiers_needed:
        print(f"\nWarning: Only {len(cashier_pool)} cashiers available. Expanding pool...")
        
        # Strategy 1: Use active cashiers without store assignments
        cashiers_without_store = active_cashiers_df[active_cashiers_df['store_id'].isna()]
        if len(cashiers_without_store) > 0:
            print(f"  Adding {len(cashiers_without_store)} cashiers without store assignments...")
            for _, row in cashiers_without_store.iterrows():
                cashier_id = row['employee_id']
                shift = row['shift_clean']
                
                if not any(c['cashier_id'] == cashier_id for c in cashier_pool):
                    cashier_pool.append({
                        'store_id': None,  # Will be assigned to a random store
                        'shift': shift,
                        'cashier_id': cashier_id,
                        'original_shift': row['shift'],
                        'from_store': False
                    })
        
        # Strategy 2: If still not enough, create realistic fallbacks
        if len(cashier_pool) < total_cashiers_needed * 0.5:  # Less than 50% of needed
            needed = total_cashiers_needed - len(cashier_pool)
            print(f"  Creating {needed} realistic fallback cashiers...")
            
            # Create fallback cashiers using HR format
            for i in range(needed):
                store_id = f"STR-{np.random.randint(1, 151):04d}"
                shift = np.random.choice(['Day', 'Night'], p=[0.6, 0.4])
                year = np.random.choice([2023, 2024], p=[0.4, 0.6])
                random_num = np.random.randint(1000, 9999)
                cashier_id = f"CS-{year}-CAS-{random_num}"
                
                cashier_pool.append({
                    'store_id': store_id,
                    'shift': shift,
                    'cashier_id': cashier_id,
                    'original_shift': shift,
                    'from_store': False,
                    'is_fallback': True
                })
        
        print(f"Expanded cashier pool to {len(cashier_pool)} cashiers")
    
    return cashier_pool

def generate_retail_locations():
    """Generate retail locations matching HR store data"""
    
    # Load store data to ensure consistency
    stores_df = load_store_data()
    
    retail_locations = []
    
    for _, store in stores_df.iterrows():
        retail_locations.append({
            'store_id': store['store_id'],
            'store_name': store['store_name'],
            'county': store['county'],
            'format': store['format'],
            'size_sqm': store['size_sqm'],
            'operating_hours': STORE_OPERATING_HOURS.get(store['format'], STORE_OPERATING_HOURS['Supermarket'])
        })
    
    return retail_locations

def generate_transaction_time(store, shift, transaction_date):
    """Generate transaction time based on store operating hours and cashier shift"""
    store_hours = store['operating_hours']
    shift_info = SHIFT_HOURS.get(shift, SHIFT_HOURS['Day'])  # Default to Day if shift not found
    
    if shift_info is None:  # Off, Invalid, Unknown shifts
        # Use store hours as fallback
        hour = np.random.randint(store_hours['open'], store_hours['close'])
    else:
        # For Midnight shift (22:00-6:00), handle wrap-around
        if shift == 'Midnight':
            # Split into two ranges: 22:00-24:00 and 00:00-6:00
            if np.random.random() < 0.7:  # 70% in evening portion
                hour = np.random.randint(22, 24)
            else:  # 30% in early morning
                hour = np.random.randint(0, 6)
        else:
            # Ensure transaction is within both store hours and shift hours
            start_hour = max(store_hours['open'], shift_info['start'])
            end_hour = min(store_hours['close'], shift_info['end'])
            
            if start_hour >= end_hour:
                # If no overlap, use store hours
                hour = np.random.randint(store_hours['open'], store_hours['close'])
            else:
                hour = np.random.randint(start_hour, end_hour)
    
    minute = np.random.randint(0, 60)
    second = np.random.randint(0, 60)
    
    return datetime(
        transaction_date.year, transaction_date.month, transaction_date.day,
        hour, minute, second
    )

def select_product_by_category(products_by_category, product_details, category_probs, store_county):
    """Select a real product from the products table with county-based price adjustment"""
    
    # Filter out NaN categories
    valid_categories = [cat for cat in category_probs.keys() if not pd.isna(cat)]
    valid_probs = [category_probs[cat] for cat in valid_categories]
    
    # Ensure we have valid categories
    if not valid_categories:
        print("ERROR: No valid product categories found!")
        # Create a fallback category
        valid_categories = ['FMCG']
        valid_probs = [1.0]
    
    # Normalize probabilities
    prob_sum = sum(valid_probs)
    if prob_sum > 0:
        valid_probs = [p/prob_sum for p in valid_probs]
    
    # Select category based on actual distribution
    selected_category = np.random.choice(valid_categories, p=valid_probs)
    
    # Ensure selected_category is not NaN
    if pd.isna(selected_category):
        selected_category = 'FMCG'  # Default fallback
    
    # Select a product from this category
    if selected_category in products_by_category and products_by_category[selected_category]:
        product_list = products_by_category[selected_category]
        if product_list:  # Check if list is not empty
            product_id = np.random.choice(product_list)
            
            # Double-check product exists in details
            if product_id in product_details:
                product_info = product_details[product_id]
                
                # Apply county-based price adjustment
                base_price = product_info['retail_price_kes']
                
                if store_county in ['Nairobi', 'Mombasa']:
                    # Major cities: higher prices
                    price_multiplier = np.random.uniform(1.1, 1.3)
                elif store_county in ['Kisumu', 'Nakuru', 'Eldoret']:
                    # Mid-sized cities: moderate prices
                    price_multiplier = np.random.uniform(1.0, 1.15)
                else:
                    # Rural areas: lower prices
                    price_multiplier = np.random.uniform(0.9, 1.05)
                
                adjusted_price = round(base_price * price_multiplier, 2)
                
                return product_id, product_info, adjusted_price
    
    # Fallback: create a generic product
    print(f"Warning: No valid products found for category '{selected_category}'. Using generic product.")
    
    # Create a realistic generic product ID
    year_suffix = np.random.choice(['2023', '2024', '2025'])
    random_num = np.random.randint(10000, 99999)
    product_id = f"PROD-GEN-{year_suffix}-{random_num}"
    
    # Create generic product info based on category
    if selected_category and not pd.isna(selected_category):
        category_name = str(selected_category)
    else:
        category_name = 'FMCG'
    
    # Common product names by category
    generic_names = {
        'FMCG': ['Basic Cooking Oil', 'Standard Sugar', 'Regular Salt', 'Everyday Flour'],
        'Fresh': ['Fresh Vegetables', 'Local Fruits', 'Basic Dairy', 'Daily Bread'],
        'Non-Food': ['Generic Item', 'Basic Supplies', 'Standard Accessory'],
        'Services': ['Service Fee', 'Transaction Charge', 'Basic Service'],
        'Health & Wellness': ['Basic Medicine', 'Standard Supplement', 'Health Product'],
        'Beauty & Fashion': ['Basic Cosmetic', 'Standard Beauty Item'],
        'Home & Living': ['Home Essential', 'Basic Household Item'],
        'Automotive': ['Car Basic', 'Vehicle Essential']
    }
    
    # Select appropriate generic name
    generic_name_list = generic_names.get(category_name, ['Generic Product'])
    product_name = f"{np.random.choice(generic_name_list)} {np.random.randint(1, 100)}"
    
    # Set appropriate price range
    price_ranges = {
        'FMCG': (50, 500),
        'Fresh': (30, 1000),
        'Non-Food': (200, 5000),
        'Services': (10, 500),
        'Health & Wellness': (200, 8000),
        'Beauty & Fashion': (500, 10000),
        'Home & Living': (1000, 50000),
        'Automotive': (300, 20000)
    }
    
    price_range = price_ranges.get(category_name, (100, 1000))
    base_price = np.random.uniform(price_range[0], price_range[1])
    
    # Apply county-based adjustment
    if store_county in ['Nairobi', 'Mombasa']:
        price_multiplier = np.random.uniform(1.1, 1.3)
    elif store_county in ['Kisumu', 'Nakuru', 'Eldoret']:
        price_multiplier = np.random.uniform(1.0, 1.15)
    else:
        price_multiplier = np.random.uniform(0.9, 1.05)
    
    adjusted_price = round(base_price * price_multiplier, 2)
    
    product_info = {
        'product_name': product_name,
        'category': category_name,
        'subcategory': 'General',
        'brand': 'Generic',
        'retail_price_kes': adjusted_price
    }
    
    return product_id, product_info, adjusted_price

def generate_pos_transactions(retail_locations, cashier_pool, hr_df, 
                             products_by_category, product_details, category_probs,
                             num_transactions=400000, start_date='2023-01-01', end_date='2025-12-31'):
    """Generate POS transaction data using real products from products table"""
    
    print("\nGenerating POS transaction data...")
    print(f"Using {len(cashier_pool)} cashiers from HR data pool")
    print(f"Using {sum(len(prods) for prods in products_by_category.values())} real products")
    
    start_dt = datetime.strptime(start_date, '%Y-%m-%d')
    end_dt = datetime.strptime(end_date, '%Y-%m-%d')
    
    data = []
    transaction_counter = 1
    
    # Track transactions by shift for analysis - EXPANDED to handle all possible shifts
    shift_transaction_counts = {
        'Day': 0, 'Night': 0, 'Standard': 0, 'Off': 0,
        'Invalid': 0, 'Midnight': 0, 'Unknown': 0, 'Other': 0
    }
    
    # Track cashier usage
    cashier_usage_count = {}
    
    # Track product sales
    product_sales_count = {}
    
    # Track generic products created
    generic_products_created = 0
    
    # Track stores with cashiers
    stores_with_direct_cashiers = {}
    for cashier in cashier_pool:
        if cashier['store_id'] and cashier.get('from_store', True):
            store_id = cashier['store_id']
            if store_id not in stores_with_direct_cashiers:
                stores_with_direct_cashiers[store_id] = []
            stores_with_direct_cashiers[store_id].append(cashier['cashier_id'])
    
    print(f"Stores with directly assigned cashiers: {len(stores_with_direct_cashiers)}/{len(retail_locations)}")
    
    # Prepare cashiers without store assignments
    cashiers_without_store = [c for c in cashier_pool if c['store_id'] is None]
    if cashiers_without_store:
        print(f"  {len(cashiers_without_store)} cashiers available for store assignment")
    
    for i in range(num_transactions):
        if i % 50000 == 0 and i > 0:
            print(f"  Generated {i:,} transactions...")
        
        transaction_id = f"TXN-{2023000000 + transaction_counter}"
        transaction_counter += 1
        
        # Select retail location
        store = random.choice(retail_locations)
        store_id = store['store_id']
        store_county = store['county']
        store_format = store['format']
        
        # Generate transaction date
        transaction_date_only = fake.date_between(start_date=start_dt, end_date=end_dt)
        
        # Determine shift (more transactions during day shift)
        # Adjust shift probability based on store format
        if store_format in ['Express Store', 'Mini-mart']:
            # Smaller stores have more night transactions
            shift_prob = [0.55, 0.45]  # 55% day, 45% night
        else:
            shift_prob = [0.65, 0.35]  # 65% day, 35% night transactions
        
        shift_choice = np.random.choice(['Day', 'Night'], p=shift_prob)
        
        # STRATEGY 1: Find cashiers directly assigned to this store with matching shift
        store_cashiers = [c for c in cashier_pool if c['store_id'] == store_id and c['shift'] == shift_choice]
        
        # STRATEGY 2: If none found, find any cashier for this store (any shift)
        if not store_cashiers:
            store_cashiers = [c for c in cashier_pool if c['store_id'] == store_id]
        
        # STRATEGY 3: If still none, find any cashier with this shift (any store)
        if not store_cashiers:
            store_cashiers = [c for c in cashier_pool if c['shift'] == shift_choice]
        
        # STRATEGY 4: Use cashiers without store assignments
        if not store_cashiers:
            store_cashiers = cashiers_without_store
        
        # STRATEGY 5: Last resort - find any cashier from the pool
        if not store_cashiers:
            store_cashiers = cashier_pool
        
        # Select a cashier
        if store_cashiers:
            selected_cashier = random.choice(store_cashiers)
            staff_id = selected_cashier['cashier_id']
            shift_used = selected_cashier['shift']
            
            # Track usage
            cashier_usage_count[staff_id] = cashier_usage_count.get(staff_id, 0) + 1
            
            # Safely increment shift count - handle any shift value
            if shift_used in shift_transaction_counts:
                shift_transaction_counts[shift_used] += 1
            else:
                shift_transaction_counts['Other'] += 1
                # Add this new shift to our tracking
                shift_transaction_counts[shift_used] = 1
        else:
            # This should rarely happen now with our expanded pool
            staff_id = f"CS-2024-CAS-{random.randint(1000, 9999)}"
            shift_used = 'Unknown'
            shift_transaction_counts['Unknown'] += 1
            if i < 10:  # Only print first few warnings
                print(f"  Warning: Had to create new cashier for transaction {transaction_id}")
        
        # Generate transaction time based on shift
        transaction_datetime = generate_transaction_time(store, shift_used, transaction_date_only)
        
        # Generate customer (some will be anonymous)
        if np.random.random() < 0.95:  # 95% with customer ID
            customer_id = f"CUST-{2023000000 + np.random.randint(0, 150000)}"
        else:
            customer_id = 'ANONYMOUS'
        
        # Generate items in transaction (1-30 items, based on store format)
        if store_format == 'Hypermarket':
            num_items = np.random.poisson(15) + 1  # Larger baskets
        elif store_format == 'Supermarket':
            num_items = np.random.poisson(10) + 1
        else:
            num_items = np.random.poisson(5) + 1  # Smaller stores
        
        # Adjust number of items based on transaction time (rush hours have fewer items)
        transaction_hour = transaction_datetime.hour
        if transaction_hour in [7, 8, 17, 18]:  # Rush hours
            num_items = max(1, int(num_items * 0.7))
        
        # Single payment method per transaction
        # Adjust payment methods based on store location and format
        if store_county in ['Nairobi', 'Mombasa']:
            payment_methods = ['Cash', 'M-Pesa', 'Card', 'Airtel Money', 'Bank Transfer']
            payment_probs = [0.3, 0.4, 0.2, 0.05, 0.05]  # More mobile money in cities
        else:
            payment_methods = ['Cash', 'M-Pesa', 'Card', 'Airtel Money', 'T-Kash']
            payment_probs = [0.4, 0.35, 0.15, 0.05, 0.05]
        
        # Adjust based on store format
        if store_format == 'Hypermarket':
            payment_probs = [0.25, 0.35, 0.3, 0.05, 0.05]  # More cards in hypermarkets
        
        payment_method = np.random.choice(payment_methods, p=payment_probs)
        
        # Track transaction cashier for consistency
        transaction_cashier = staff_id
        
        # Track transaction total for discount calculation
        transaction_total = 0
        
        for item_num in range(num_items):
            # Select REAL product from products table
            product_id, product_info, unit_price = select_product_by_category(
                products_by_category, product_details, category_probs, store_county
            )
            
            # Track if this is a generic product
            if product_id.startswith('PROD-GEN-'):
                generic_products_created += 1
            
            # Track product sales
            product_sales_count[product_id] = product_sales_count.get(product_id, 0) + 1
            
            # Determine quantity (based on product category)
            category = product_info.get('category', 'FMCG')
            if category in ['FMCG', 'Fresh']:
                # Everyday items: 1-5 units
                quantity = np.random.randint(1, 6)
            elif category in ['Non-Food', 'Home & Living', 'Automotive']:
                # Bigger items: usually 1 unit
                quantity = 1
            else:
                quantity = np.random.randint(1, 3)
            
            # Special handling for sale items
            sale_probability = 0.15  # 15% of items are on sale
            if np.random.random() < sale_probability:
                # Apply sale discount (5-30%)
                discount_percentage = np.random.uniform(0.05, 0.30)
            else:
                discount_percentage = 0
            
            total_price = round(unit_price * quantity, 2)
            discount = round(total_price * discount_percentage, 2)
            final_price = total_price - discount
            
            transaction_total += final_price
            
            record = {
                'transaction_id': transaction_id,
                'transaction_date': transaction_datetime,
                'store_id': store_id,
                'store_county': store_county,
                'store_format': store_format,
                'customer_id': customer_id,
                'line_item_id': f"{transaction_id}-{item_num+1:03d}",
                'product_id': product_id,
                'product_name': product_info['product_name'],
                'category': product_info['category'],
                'subcategory': product_info.get('subcategory', 'General'),
                'brand': product_info.get('brand', 'Generic'),
                'unit_price_kes': unit_price,
                'quantity': quantity,
                'total_price_kes': total_price,
                'discount_kes': discount,
                'final_price_kes': final_price,
                'payment_method': payment_method,  # Same for all items in transaction
                'staff_id': transaction_cashier,  # Same cashier for all items in transaction
                'shift': shift_used,  # Record which shift this transaction occurred in
                'data_source': 'POS_System',
                'extracted_timestamp': datetime.now()
            }
            
            data.append(record)
        
        # Apply transaction-level discount for larger purchases
        if transaction_total > 5000 and np.random.random() < 0.3:  # 30% chance for large transactions
            transaction_discount = round(transaction_total * np.random.uniform(0.03, 0.10), 2)
            # Apply discount proportionally to items
            for j in range(-num_items, 0):
                item_final_price = data[j]['final_price_kes']
                proportion = item_final_price / transaction_total
                item_discount = round(transaction_discount * proportion, 2)
                data[j]['discount_kes'] += item_discount
                data[j]['final_price_kes'] -= item_discount
    
    df = pd.DataFrame(data)
    
    # Add data quality issues (controlled amounts)
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
    
    # 4. Invalid dates - FIXED: Use NaT instead of invalid string
    invalid_date_mask = np.random.random(len(df)) < 0.003
    df.loc[invalid_date_mask, 'transaction_date'] = pd.NaT
    
    # 5. Missing staff IDs (some transactions without cashier)
    missing_staff_mask = np.random.random(len(df)) < 0.01
    df.loc[missing_staff_mask, 'staff_id'] = np.nan
    
    # 6. Invalid shift assignments (should match HR data)
    invalid_shift_mask = np.random.random(len(df)) < 0.005
    df.loc[invalid_shift_mask, 'shift'] = 'Invalid'
    
    # 7. Product ID mismatch (introduce some fake product IDs)
    fake_product_mask = np.random.random(len(df)) < 0.002
    df.loc[fake_product_mask, 'product_id'] = 'FAKE-PROD-' + df.loc[fake_product_mask, 'product_id']
    
    print(f"\nGenerated {len(df):,} POS transaction line items")
    print(f"Total transactions: {df['transaction_id'].nunique():,}")
    print(f"Retail locations used: {df['store_id'].nunique()}")
    print(f"Unique cashiers used: {len(cashier_usage_count)}")
    print(f"Unique products sold: {len(product_sales_count)}")
    print(f"Generic products created: {generic_products_created:,}")
    
    # Product sales analysis
    print(f"\nTop 10 best-selling products:")
    top_products = sorted(product_sales_count.items(), key=lambda x: x[1], reverse=True)[:10]
    for i, (product_id, count) in enumerate(top_products, 1):
        if product_id in product_details:
            product_name = product_details[product_id]['product_name'][:50]
            print(f"  {i}. {product_id}: {product_name}... ({count:,} sales)")
        else:
            print(f"  {i}. {product_id}: Generic Product ({count:,} sales)")
    
    # Calculate shift distribution
    total_transactions = df['transaction_id'].nunique()
    print(f"\nTransactions by shift:")
    
    # Sort shifts by count (descending)
    sorted_shifts = sorted([(shift, count) for shift, count in shift_transaction_counts.items() if count > 0],
                          key=lambda x: x[1], reverse=True)
    
    for shift, count in sorted_shifts:
        if count > 0:
            percentage = (count / total_transactions) * 100
            print(f"  {shift}: {count:,} transactions ({percentage:.1f}%)")
    
    print(f"\nData quality issues:")
    print(f"  Missing customer IDs: {missing_cust_mask.sum():,}")
    print(f"  Negative quantities: {negative_qty_mask.sum():,}")
    print(f"  Invalid dates: {invalid_date_mask.sum():,}")
    print(f"  Missing staff IDs: {missing_staff_mask.sum():,}")
    print(f"  Invalid shifts: {invalid_shift_mask.sum():,}")
    print(f"  Fake product IDs: {fake_product_mask.sum():,}")
    
    # Analyze cashier transaction distribution
    if not df.empty and 'staff_id' in df.columns:
        cashier_stats = df.groupby('staff_id').agg({
            'transaction_id': 'nunique',
            'final_price_kes': 'sum',
            'shift': lambda x: x.mode()[0] if not x.mode().empty else 'Unknown'
        }).rename(columns={'transaction_id': 'transactions', 'final_price_kes': 'total_sales'})
        
        print(f"\nCashier performance (top 5 by transactions):")
        if not cashier_stats.empty:
            top_cashiers = cashier_stats.sort_values('transactions', ascending=False).head()
            for idx, (cashier_id, row) in enumerate(top_cashiers.iterrows(), 1):
                print(f"  {idx}. {cashier_id}: {row['transactions']} transactions, KES {row['total_sales']:,.0f} sales")
        else:
            print("  No cashier data available")
    
    # Check employee ID format compliance
    if 'staff_id' in df.columns:
        hr_format_mask = df['staff_id'].astype(str).str.contains(r'^[A-Z]{2,3}-\d{4}-[A-Z]{3}-\d{4}$', na=False)
        hr_format_ids = df.loc[hr_format_mask, 'staff_id']
        non_hr_format_ids = df.loc[~hr_format_mask, 'staff_id']
        
        print(f"\nEmployee ID format compliance:")
        print(f"  HR format (CS-2024-CAS-XXXX): {len(hr_format_ids):,} ({len(hr_format_ids)/len(df)*100:.1f}%)")
        print(f"  Non-HR format: {len(non_hr_format_ids):,} ({len(non_hr_format_ids)/len(df)*100:.1f}%)")
    
    # Cashier utilization analysis
    print(f"\nCashier utilization:")
    print(f"  Total cashiers in pool: {len(cashier_pool)}")
    print(f"  Cashiers actually used: {len(cashier_usage_count)}")
    if cashier_usage_count:
        avg_transactions_per_cashier = sum(cashier_usage_count.values()) / len(cashier_usage_count)
        print(f"  Average transactions per cashier: {avg_transactions_per_cashier:.1f}")
        
        # Find most and least used cashiers
        if cashier_usage_count:
            max_cashier = max(cashier_usage_count.items(), key=lambda x: x[1])
            min_cashier = min(cashier_usage_count.items(), key=lambda x: x[1])
            print(f"  Most active cashier: {max_cashier[0]} ({max_cashier[1]} transactions)")
            print(f"  Least active cashier: {min_cashier[0]} ({min_cashier[1]} transactions)")
    
    # Product category analysis
    if not df.empty and 'category' in df.columns:
        category_sales = df.groupby('category').agg({
            'final_price_kes': 'sum',
            'quantity': 'sum',
            'transaction_id': 'nunique'
        }).rename(columns={'transaction_id': 'transactions'})
        
        print(f"\nSales by category:")
        for category, row in category_sales.sort_values('final_price_kes', ascending=False).iterrows():
            print(f"  {category}: KES {row['final_price_kes']:,.0f} ({row['quantity']:,} units, {row['transactions']:,} transactions)")
    
    return df

# Main execution
if __name__ == "__main__":
    os.makedirs('bronze', exist_ok=True)
    
    print("="*60)
    print("POS DATA GENERATION (USING REAL PRODUCTS FROM PRODUCTS TABLE)")
    print("="*60)
    
    # Load HR data including shift information
    cashiers_by_store_shift, cashier_pool, hr_df, active_cashiers_df = load_hr_data()
    
    if hr_df.empty:
        print("\n" + "="*60)
        print("ERROR: HR data not loaded. POS generation cannot continue.")
        print("="*60)
        print("\nACTION REQUIRED:")
        print("1. Run generate_hr_data.py first")
        print("2. Ensure HR data is generated successfully")
        print("="*60)
        exit(1)
    
    # Load products data
    products_by_category, product_details, products_df, category_probs = load_products_data()
    
    if not products_by_category:
        print("\n" + "="*60)
        print("ERROR: Products data not loaded. POS generation cannot continue.")
        print("="*60)
        print("\nACTION REQUIRED:")
        print("1. Run products_raw.py first")
        print("2. Ensure products data is generated successfully")
        print("="*60)
        exit(1)
    
    # Generate retail locations (consistent with HR data)
    retail_locations = generate_retail_locations()
    
    # Ensure all stores have cashiers (expands cashier pool if needed)
    cashier_pool = ensure_all_stores_have_cashiers(cashiers_by_store_shift, cashier_pool, hr_df, active_cashiers_df)
    
    print(f"\nFinal cashier pool size: {len(cashier_pool)} cashiers")
    print(f"Real products available: {len(product_details)}")
    print(f"Valid product categories: {len(category_probs)}")
    
    # Generate POS data with real products
    pos_df = generate_pos_transactions(retail_locations, cashier_pool, hr_df, 
                                      products_by_category, product_details, category_probs, 
                                      400000)
    
    # Save to bronze layer
    pos_df.to_csv('bronze/pos_raw.csv', index=False)
    
    # Save stores data (ensure it's saved)
    stores_df = pd.DataFrame([{k: v for k, v in loc.items() if k != 'operating_hours'} 
                             for loc in retail_locations])
    stores_df.to_csv('bronze/stores_raw.csv', index=False)
    
    print("\n" + "="*60)
    print("POS DATA GENERATION COMPLETE")
    print("="*60)
    
    # Display sample data
    print("\nSample POS transactions (showing real products):")
    if not pos_df.empty:
        sample_cols = ['transaction_id', 'store_id', 'product_id', 'product_name', 
                      'category', 'quantity', 'final_price_kes', 'staff_id']
        available_cols = [col for col in sample_cols if col in pos_df.columns]
        
        if available_cols:
            sample_data = pos_df.head(5)[available_cols].copy()
            
            # Format for display
            for idx, row in sample_data.iterrows():
                parts = []
                if 'transaction_id' in available_cols:
                    parts.append(f"TXN: {row['transaction_id']}")
                if 'store_id' in available_cols:
                    parts.append(f"Store: {row['store_id']}")
                if 'product_id' in available_cols:
                    parts.append(f"Product: {row['product_id']}")
                if 'product_name' in available_cols:
                    # Truncate long product names
                    prod_name = str(row['product_name'])
                    if len(prod_name) > 30:
                        prod_name = prod_name[:27] + "..."
                    parts.append(f"'{prod_name}'")
                if 'quantity' in available_cols and 'final_price_kes' in available_cols:
                    parts.append(f"Qty: {row['quantity']}, Price: KES {row['final_price_kes']:,.2f}")
                
                print(f"  {' | '.join(parts)}")
    
    if not pos_df.empty and 'payment_method' in pos_df.columns:
        print(f"\nPayment method distribution:")
        payment_dist = pos_df['payment_method'].value_counts()
        for method, count in payment_dist.items():
            percentage = (count / len(pos_df)) * 100
            print(f"  {method}: {count:,} ({percentage:.1f}%)")
    
    # Verify relationships with HR data
    print("\n" + "="*60)
    print("DATA RELATIONSHIP VERIFICATION")
    print("="*60)
    
    if not pos_df.empty and 'staff_id' in pos_df.columns:
        # Check if POS staff IDs exist in HR data
        pos_staff_ids = set(pos_df['staff_id'].dropna().unique())
        hr_cashier_ids = set(hr_df[hr_df['job_title'] == 'Cashier']['employee_id'].unique())
        
        matching_ids = pos_staff_ids.intersection(hr_cashier_ids)
        non_matching_ids = pos_staff_ids - hr_cashier_ids
        
        print(f"POS transactions: {pos_df['transaction_id'].nunique():,}")
        print(f"Unique cashiers in POS: {len(pos_staff_ids)}")
        
        if len(pos_staff_ids) > 0:
            match_percentage = len(matching_ids) / len(pos_staff_ids) * 100
            print(f"Cashiers matching HR records: {len(matching_ids)} ({match_percentage:.1f}%)")
        else:
            print(f"Cashiers matching HR records: 0 (0.0%)")
        
        if non_matching_ids:
            print(f"Non-matching cashier IDs (fallback/created): {len(non_matching_ids)}")
            if len(non_matching_ids) <= 3:
                print(f"  Examples: {list(non_matching_ids)[:3]}")
    
    # Verify product relationships
    if not pos_df.empty and 'product_id' in pos_df.columns:
        pos_product_ids = set(pos_df['product_id'].dropna().unique())
        real_product_ids = set(products_df['product_id'].unique())
        
        matching_products = pos_product_ids.intersection(real_product_ids)
        non_matching_products = pos_product_ids - real_product_ids
        
        print(f"\nProduct verification:")
        print(f"  Unique products in POS: {len(pos_product_ids)}")
        print(f"  Products matching products table: {len(matching_products)} ({len(matching_products)/len(pos_product_ids)*100:.1f}%)")
        print(f"  Non-matching products (generic/fallback): {len(non_matching_products)}")
        
        if len(matching_products) > 0:
            # Show coverage by category
            print(f"\nProduct category coverage in POS:")
            for category in products_df['category'].unique():
                if pd.isna(category):
                    continue
                category_products = set(products_df[products_df['category'] == category]['product_id'])
                pos_category_products = pos_product_ids.intersection(category_products)
                if len(category_products) > 0:
                    percentage = len(pos_category_products) / len(category_products) * 100
                    print(f"  {category}: {len(pos_category_products)}/{len(category_products)} products ({percentage:.1f}%)")
    
    # Analyze transaction times
    print(f"\nAnalyzing transaction times...")
    if not pos_df.empty and 'transaction_date' in pos_df.columns:
        try:
            # Ensure transaction_date is datetime
            pos_df['transaction_date'] = pd.to_datetime(pos_df['transaction_date'], errors='coerce')
            
            # Only analyze valid dates
            valid_dates_mask = pos_df['transaction_date'].notna()
            if valid_dates_mask.any():
                pos_df.loc[valid_dates_mask, 'transaction_hour'] = pos_df.loc[valid_dates_mask, 'transaction_date'].dt.hour
                
                hour_distribution = pos_df.loc[valid_dates_mask, 'transaction_hour'].value_counts().sort_index()
                
                print(f"\nTransaction hour distribution (24-hour clock) - based on {valid_dates_mask.sum():,} valid timestamps:")
                print("  Hour  | Transactions")
                print("  " + "-" * 25)
                for hour in range(0, 24):  # Full 24 hours
                    count = hour_distribution.get(hour, 0)
                    if count > 0:
                        percentage = (count / valid_dates_mask.sum()) * 100
                        print(f"  {hour:02d}:00 | {count:8,} ({percentage:5.1f}%)")
        except Exception as e:
            print(f"  Could not analyze transaction times: {e}")
    
    # Final summary
    print("\n" + "="*60)
    print("DATASET SUMMARY")
    print("="*60)
    
    if not pos_df.empty:
        # Calculate file size
        try:
            file_size = os.path.getsize('bronze/pos_raw.csv') / (1024*1024)  # MB
            print(f"File saved: bronze/pos_raw.csv ({len(pos_df):,} records, {file_size:.1f} MB)")
        except:
            print(f"File saved: bronze/pos_raw.csv ({len(pos_df):,} records)")
        
        print(f"Time period: 2023-01-01 to 2025-12-31")
        print(f"Stores covered: {pos_df['store_id'].nunique()}/{len(retail_locations)}")
        
        # Data quality summary
        if 'staff_id' in pos_df.columns:
            quality_issues = {
                'Missing staff IDs': pos_df['staff_id'].isna().sum(),
                'Invalid shifts': (pos_df['shift'] == 'Invalid').sum() if 'shift' in pos_df.columns else 0,
                'Missing customer IDs': pos_df['customer_id'].isna().sum() if 'customer_id' in pos_df.columns else 0,
                'Negative quantities': (pos_df['quantity'] < 0).sum() if 'quantity' in pos_df.columns else 0,
                'Invalid dates': pos_df['transaction_date'].isna().sum() if 'transaction_date' in pos_df.columns else 0,
                'Fake product IDs': pos_df['product_id'].str.contains('FAKE-PROD-', na=False).sum() if 'product_id' in pos_df.columns else 0
            }
            
            total_issues = sum(quality_issues.values())
            print(f"Data quality issues: {total_issues:,} total")
            
            # Success metrics
            if 'staff_id' in pos_df.columns and len(pos_staff_ids) > 0:
                hr_match_percentage = len(matching_ids) / len(pos_staff_ids) * 100
            else:
                hr_match_percentage = 0
            
            if 'shift' in pos_df.columns:
                valid_shift_mask = (~pos_df['shift'].isin(['Invalid', 'Unknown'])) & (pos_df['shift'].notna())
                valid_shift_percentage = valid_shift_mask.sum() / len(pos_df) * 100
            else:
                valid_shift_percentage = 0
            
            if 'product_id' in pos_df.columns and len(pos_product_ids) > 0:
                product_match_percentage = len(matching_products) / len(pos_product_ids) * 100
            else:
                product_match_percentage = 0
            
            print(f"\nINTEGRATION SUCCESS METRICS:")
            print(f"  HR-POS Cashier Match: {hr_match_percentage:.1f}% (target: >95%)")
            print(f"  Product-POS Match: {product_match_percentage:.1f}% (target: >98%)")
            print(f"  Valid Shift Assignments: {valid_shift_percentage:.1f}% (target: >95%)")
            print(f"  Stores with Transactions: {pos_df['store_id'].nunique()}/{len(retail_locations)} ({pos_df['store_id'].nunique()/len(retail_locations)*100:.1f}%)")
            
            # Business metrics
            total_sales = pos_df['final_price_kes'].sum() if 'final_price_kes' in pos_df.columns else 0
            avg_transaction_value = total_sales / pos_df['transaction_id'].nunique() if pos_df['transaction_id'].nunique() > 0 else 0
            avg_items_per_transaction = len(pos_df) / pos_df['transaction_id'].nunique() if pos_df['transaction_id'].nunique() > 0 else 0
            
            print(f"\nBUSINESS METRICS:")
            print(f"  Total Sales: KES {total_sales:,.0f}")
            print(f"  Average Transaction Value: KES {avg_transaction_value:,.2f}")
            print(f"  Average Items per Transaction: {avg_items_per_transaction:.1f}")