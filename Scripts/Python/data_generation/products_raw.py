# products_raw.py
import pandas as pd
import numpy as np
from faker import Faker
import random
import os
from datetime import datetime

fake = Faker('en_KE')
np.random.seed(44)
random.seed(44)

# Kenyan retail product categories and subcategories
PRODUCT_CATEGORIES = {
    'FMCG': {
        'Food & Beverages': ['Unga wa Ngano', 'Mahindi Flour', 'Sukari', 'Chumvi', 'Mafuta ya Kupikia', 'Maziwa Fresh', 'Chai Leaves', 'Kahawa'],
        'Snacks & Confectionery': ['Biscuits', 'Chocolate Bars', 'Candy', 'Crisps', 'Nuts', 'Popcorn', 'Cookies', 'Sweets'],
        'Beverages': ['Soda', 'Juice', 'Water', 'Energy Drinks', 'Tea Bags', 'Coffee', 'Malt Drinks', 'Flavored Milk'],
        'Personal Care': ['Soap', 'Shampoo', 'Toothpaste', 'Deodorant', 'Sanitary Pads', 'Razors', 'Lotion', 'Perfume'],
        'Household': ['Washing Powder', 'Dish Soap', 'Toilet Cleaner', 'Air Freshener', 'Bleach', 'Hand Wash', 'Fabric Softener'],
        'Cooking Essentials': ['Cooking Oil', 'Salt', 'Sugar', 'Rice', 'Beans', 'Maize Flour', 'Wheat Flour', 'Spices']
    },
    'Fresh': {
        'Fruits & Vegetables': ['Sukuma Wiki', 'Spinach', 'Cabbage', 'Tomatoes', 'Onions', 'Potatoes', 'Carrots', 'Bananas', 'Oranges', 'Mangoes'],
        'Meat & Poultry': ['Beef', 'Chicken', 'Mutton', 'Pork', 'Fish', 'Sausages', 'Minced Meat', 'Goat Meat'],
        'Dairy': ['Milk', 'Yogurt', 'Cheese', 'Butter', 'Cream', 'Margarine', 'Eggs'],
        'Bakery': ['Bread', 'Buns', 'Cakes', 'Pastries', 'Donuts', 'Cookies', 'Rusk']
    },
    'Non-Food': {
        'Electronics': ['Mobile Phones', 'Chargers', 'Headphones', 'Power Banks', 'USB Cables', 'Batteries'],
        'Clothing': ['T-Shirts', 'Trousers', 'Dresses', 'Shirts', 'Skirts', 'Socks', 'Underwear'],
        'Footwear': ['Shoes', 'Sandals', 'Slippers', 'Boots', 'Sports Shoes'],
        'Home Appliances': ['Kettles', 'Toasters', 'Blenders', 'Irons', 'Fans', 'Heaters'],
        'Stationery': ['Notebooks', 'Pens', 'Pencils', 'Files', 'Staplers', 'Calculators']
    },
    'Health & Wellness': {
        'Pharmacy': ['Painkillers', 'Antibiotics', 'Vitamins', 'First Aid', 'Thermometers', 'Bandages'],
        'Supplements': ['Protein Powder', 'Vitamins', 'Minerals', 'Herbal Supplements', 'Energy Boosters'],
        'Fitness': ['Sports Equipment', 'Yoga Mats', 'Dumbbells', 'Exercise Bands', 'Sports Drinks']
    },
    'Beauty & Fashion': {
        'Cosmetics': ['Lipstick', 'Foundation', 'Mascara', 'Nail Polish', 'Makeup Brushes', 'Eyeliner'],
        'Perfumes': ['Men\'s Fragrances', 'Women\'s Fragrances', 'Unisex Scents', 'Body Sprays'],
        'Jewelry': ['Necklaces', 'Earrings', 'Bracelets', 'Watches', 'Rings']
    },
    'Home & Living': {
        'Furniture': ['Chairs', 'Tables', 'Shelves', 'Beds', 'Cabinets', 'Sofas'],
        'Home Décor': ['Curtains', 'Cushions', 'Wall Art', 'Vases', 'Lamps', 'Rugs'],
        'Kitchenware': ['Pots', 'Pans', 'Utensils', 'Cutlery', 'Plates', 'Glasses'],
        'Gardening': ['Seeds', 'Tools', 'Fertilizers', 'Pots', 'Watering Cans', 'Gloves']
    },
    'Automotive': {
        'Car Accessories': ['Car Mats', 'Seat Covers', 'Phone Holders', 'Air Fresheners', 'Cleaning Kits'],
        'Motorbike': ['Helmets', 'Gloves', 'Raincoats', 'Locks', 'Maintenance Kits'],
        'Lubricants': ['Engine Oil', 'Brake Fluid', 'Coolant', 'Transmission Fluid', 'Grease']
    },
    'Services': {
        'Financial': ['Airtime', 'Data Bundles', 'Bill Payments', 'Money Transfer', 'Gift Cards'],
        'Lottery': ['Lottery Tickets', 'Betting Slips', 'Scratch Cards'],
        'Other': ['Printing Services', 'Photocopying', 'Laminating', 'Passport Photos']
    }
}

# Kenyan brands by category
KENYAN_BRANDS = {
    'FMCG': ['Bidco', 'KCC', 'Brookside', 'Tusker', 'Kericho Gold', 'Dormans', 'Eveready', 'Kimbo', 'Cowboy', 'Sunlight'],
    'Fresh': ['Farmers Choice', 'Kenfresh', 'Mukwano', 'Local Farm', 'Fresh Produce Kenya', 'Zucchini', 'Uchumi Fresh'],
    'Non-Food': ['Samsung', 'Tecno', 'Infinix', 'Nokia', 'Mango', 'H&M', 'Bata', 'SafariCom', 'Airtel'],
    'Health & Wellness': ['GlaxoSmithKline', 'Bayer', 'Pfizer', 'GSK', 'Local Pharma', 'HealthyU', 'Wellness Kenya'],
    'Beauty & Fashion': ['MAC', 'Maybelline', 'L\'Oréal', 'Nivea', 'Vaseline', 'Ponds', 'Local Beauty'],
    'Home & Living': ['Mabati', 'Chandaria', 'Mwananchi', 'Home Essentials', 'Kenya Furniture', 'Decor Kenya'],
    'Automotive': ['Castrol', 'Shell', 'Total', 'Mobil', 'Kenya Auto', 'Ride Safe', 'Boda Boda Pro'],
    'Services': ['Safaricom', 'Airtel', 'Telkom', 'Equitel', 'M-Pesa', 'Airtel Money', 'T-Kash', 'Betika', 'SportPesa']
}

# Kenyan suppliers
SUPPLIERS = [
    'Nairobi Wholesalers', 'Mombasa Distributors', 'Kisumu Suppliers', 'Nakuru Merchants',
    'Eldoret Traders', 'Thika Distributors', 'Kenya Imports Ltd', 'Local Producers Co-op',
    'Fresh Farms Kenya', 'Manufacturers Direct', 'Regional Wholesalers', 'County Suppliers'
]

# Seasonality mapping
SEASONALITY = {
    'High': ['December', 'January', 'June', 'July', 'August'],  # Holidays and school breaks
    'Medium': ['April', 'May', 'September', 'October'],
    'Low': ['February', 'March', 'November']
}

def generate_product_id(category, product_num):
    """Generate consistent product ID: PROD-CATEGORY-XXXX"""
    category_prefix = category[:3].upper()
    return f"PROD-{category_prefix}-{product_num:04d}"

def generate_products(num_products=5000):
    """Generate product catalog data"""
    
    print("Generating product catalog data...")
    print(f"Target: {num_products} products")
    
    products = []
    product_counter = 1
    
    # Generate products for each category
    for category, subcategories in PRODUCT_CATEGORIES.items():
        for subcategory, product_list in subcategories.items():
            # Determine how many products in this subcategory
            base_count = max(2, int(num_products * 0.01))  # At least 2 products per subcategory
            num_in_subcategory = np.random.randint(base_count, base_count * 3)
            
            for _ in range(num_in_subcategory):
                # Select specific product name
                product_name = random.choice(product_list)
                
                # Add brand and variant
                brand = random.choice(KENYAN_BRANDS.get(category, ['Generic']))
                variant = random.choice(['Regular', 'Large', 'Small', 'Family Pack', 'Economy', 'Premium'])
                
                full_product_name = f"{brand} {product_name} {variant}"
                
                # Generate product ID
                product_id = generate_product_id(category, product_counter)
                product_counter += 1
                
                # Determine unit cost based on category
                unit_cost_ranges = {
                    'FMCG': (50, 500),
                    'Fresh': (30, 1000),
                    'Non-Food': (200, 5000),
                    'Health & Wellness': (200, 3000),
                    'Beauty & Fashion': (500, 5000),
                    'Home & Living': (1000, 20000),
                    'Automotive': (300, 10000),
                    'Services': (10, 500)
                }
                
                cost_min, cost_max = unit_cost_ranges.get(category, (100, 1000))
                unit_cost = round(np.random.uniform(cost_min, cost_max), 2)
                
                # Retail price with margin (30-100% markup)
                margin = np.random.uniform(0.3, 1.0)
                retail_price = round(unit_cost * (1 + margin), 2)
                
                # Calculate margin percentage
                margin_percentage = round(((retail_price - unit_cost) / unit_cost) * 100, 1)
                
                # Stock level (based on popularity)
                stock_level = np.random.randint(10, 1000)
                reorder_point = int(stock_level * 0.2)
                
                # Seasonality
                month_seasonality = {}
                for month in range(1, 13):
                    season_level = 'Low'
                    if month in [12, 1, 6, 7, 8]:  # High season months
                        season_level = 'High'
                    elif month in [4, 5, 9, 10]:  # Medium season months
                        season_level = 'Medium'
                    month_seasonality[month] = season_level
                
                # Overall seasonality classification
                if any(season == 'High' for season in month_seasonality.values()):
                    seasonality_class = 'High'
                elif any(season == 'Medium' for season in month_seasonality.values()):
                    seasonality_class = 'Medium'
                else:
                    seasonality_class = 'Low'
                
                # Popularity score (0-100)
                popularity_score = np.random.randint(20, 95)
                
                # Supplier
                supplier = random.choice(SUPPLIERS)
                
                products.append({
                    'product_id': product_id,
                    'product_name': full_product_name,
                    'category': category,
                    'subcategory': subcategory,
                    'brand': brand,
                    'supplier': supplier,
                    'unit_cost_kes': unit_cost,
                    'retail_price_kes': retail_price,
                    'margin_percentage': margin_percentage,
                    'stock_level': stock_level,
                    'reorder_point': reorder_point,
                    'seasonality': seasonality_class,
                    'popularity_score': popularity_score,
                    'data_source': 'Product_Catalog',
                    'extracted_date': datetime.now().strftime('%Y-%m-%d')
                })
                
                if len(products) >= num_products:
                    break
            if len(products) >= num_products:
                break
        if len(products) >= num_products:
            break
    
    # Create DataFrame
    df = pd.DataFrame(products)
    
    # Initialize data quality issue counts
    data_quality_issues = {
        'missing_supplier': 0,
        'negative_stock': 0,
        'duplicates': 0,
        'invalid_prices': 0,
        'missing_categories': 0
    }
    
    # Add some data quality issues
    # 1. Missing supplier information
    missing_supplier_mask = np.random.random(len(df)) < 0.02
    df.loc[missing_supplier_mask, 'supplier'] = np.nan
    data_quality_issues['missing_supplier'] = missing_supplier_mask.sum()
    
    # 2. Negative stock levels (data entry errors)
    negative_stock_mask = np.random.random(len(df)) < 0.005
    df.loc[negative_stock_mask, 'stock_level'] = df.loc[negative_stock_mask, 'stock_level'] * -1
    data_quality_issues['negative_stock'] = negative_stock_mask.sum()
    
    # 3. Duplicate products
    duplicate_mask = np.random.random(len(df)) < 0.01
    duplicates = df[duplicate_mask].copy()
    duplicates['product_id'] = duplicates['product_id'] + '-DUP'
    df = pd.concat([df, duplicates], ignore_index=True)
    data_quality_issues['duplicates'] = len(duplicates)
    
    # 4. Invalid prices
    invalid_price_mask = np.random.random(len(df)) < 0.003
    df.loc[invalid_price_mask, 'retail_price_kes'] = -999
    data_quality_issues['invalid_prices'] = invalid_price_mask.sum()
    
    # 5. Missing categories
    missing_category_mask = np.random.random(len(df)) < 0.005
    df.loc[missing_category_mask, 'category'] = np.nan
    data_quality_issues['missing_categories'] = missing_category_mask.sum()
    
    print(f"Generated {len(df)} products")
    print(f"Categories: {df['category'].nunique()}")
    print(f"Subcategories: {df['subcategory'].nunique()}")
    print(f"Unique brands: {df['brand'].nunique()}")
    
    return df, data_quality_issues

def analyze_products(df, data_quality_issues):
    """Analyze product data"""
    
    print("\n" + "="*60)
    print("PRODUCT CATALOG ANALYSIS")
    print("="*60)
    
    # Price analysis by category
    print("\nAverage Prices by Category:")
    price_summary = df.groupby('category').agg({
        'unit_cost_kes': 'mean',
        'retail_price_kes': 'mean',
        'margin_percentage': 'mean',
        'product_id': 'count'
    }).round(2)
    
    price_summary = price_summary.rename(columns={'product_id': 'product_count'})
    print(price_summary)
    
    # Stock analysis
    print(f"\nTotal inventory value: KES {df['stock_level'].sum() * df['retail_price_kes'].mean():,.0f}")
    print(f"Average stock per product: {df['stock_level'].mean():.0f} units")
    
    # Seasonality distribution
    print(f"\nSeasonality Distribution:")
    season_counts = df['seasonality'].value_counts()
    for season, count in season_counts.items():
        percentage = (count / len(df)) * 100
        print(f"  {season}: {count} products ({percentage:.1f}%)")
    
    # Data quality issues
    print(f"\nData Quality Issues:")
    print(f"  Missing suppliers: {data_quality_issues['missing_supplier']}")
    print(f"  Negative stock: {data_quality_issues['negative_stock']}")
    print(f"  Duplicates: {data_quality_issues['duplicates']}")
    print(f"  Invalid prices: {data_quality_issues['invalid_prices']}")
    print(f"  Missing categories: {data_quality_issues['missing_categories']}")

# Main execution
if __name__ == "__main__":
    os.makedirs('bronze', exist_ok=True)
    
    print("="*60)
    print("PRODUCT CATALOG GENERATION")
    print("="*60)
    
    # Generate products
    products_df, data_quality_issues = generate_products(5000)
    
    # Analyze the data
    analyze_products(products_df, data_quality_issues)
    
    # Save to CSV
    output_path = 'bronze/products_raw.csv'
    products_df.to_csv(output_path, index=False)
    
    print(f"\n" + "="*60)
    print("PRODUCT DATA GENERATION COMPLETE")
    print("="*60)
    print(f"File saved: {output_path}")
    print(f"File size: {os.path.getsize(output_path) / 1024:.1f} KB")
    
    # Display sample data
    print("\nSample Products:")
    sample = products_df.head(10)[['product_id', 'product_name', 'category', 'brand', 'retail_price_kes', 'stock_level']]
    for idx, row in sample.iterrows():
        print(f"  {row['product_id']}: {row['product_name'][:40]}... | {row['category']} | KES {row['retail_price_kes']:,.0f} | Stock: {row['stock_level']}")