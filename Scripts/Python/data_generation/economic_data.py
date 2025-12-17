# generate_economic_data.py
import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta
from towns import KENYAN_COUNTIES, get_random_town, get_weighted_town
np.random.seed(46)
random.seed(46)

def generate_economic_data():
    """Generate economic indicators data for Kenyan counties"""
    
    print("Generating economic indicators data...")
    
    # Monthly economic data for 2023
    months = pd.date_range(start='2023-01-01', end='2023-12-31', freq='MS')
    economic_data = []
    
    for county in KENYAN_COUNTIES:
        # Base economic indicators by county type
        if county == 'Nairobi':
            base_gdp_growth = np.random.uniform(4.5, 6.5)
            base_inflation = np.random.uniform(5.0, 7.5)
            base_unemployment = np.random.uniform(7.0, 12.0)
        elif county == 'Mombasa':
            base_gdp_growth = np.random.uniform(3.5, 5.5)
            base_inflation = np.random.uniform(6.0, 8.5)
            base_unemployment = np.random.uniform(10.0, 18.0)
        else:
            base_gdp_growth = np.random.uniform(2.5, 5.0)
            base_inflation = np.random.uniform(6.5, 9.0)
            base_unemployment = np.random.uniform(12.0, 25.0)
        
        for month in months:
            # Add monthly variation
            month_num = month.month
            
            # Seasonal factors
            if month_num in [12, 1, 6, 7]:  # Holiday and mid-year periods
                seasonal_factor = np.random.uniform(1.05, 1.15)
            else:
                seasonal_factor = np.random.uniform(0.95, 1.05)
            
            # Generate economic indicators with trends and noise
            gdp_growth = base_gdp_growth + np.random.uniform(-1.0, 1.0)
            inflation = base_inflation + np.random.uniform(-0.5, 0.5)
            unemployment = base_unemployment + np.random.uniform(-2.0, 2.0)
            
            # Consumer spending indices
            consumer_confidence = np.random.uniform(40, 80)
            retail_sales_index = np.random.uniform(80, 120) * seasonal_factor
            
            # Business environment
            business_confidence = np.random.uniform(45, 85)
            new_business_registrations = np.random.poisson(50) * seasonal_factor
            
            # Real estate indicators
            commercial_rent_growth = np.random.uniform(-0.5, 1.5)
            retail_vacancy_rate = np.random.uniform(5.0, 20.0)
            
            # External factors
            fuel_price_kes = np.random.uniform(120, 180)
            exchange_rate_usd = np.random.uniform(140, 160)
            
            record = {
                'county': county,
                'year_month': month.strftime('%Y-%m'),
                'year': month.year,
                'month': month.month,
                'gdp_growth_rate': round(gdp_growth, 2),
                'inflation_rate': round(inflation, 2),
                'unemployment_rate': round(unemployment, 2),
                'consumer_confidence_index': round(consumer_confidence, 1),
                'retail_sales_index': round(retail_sales_index, 1),
                'business_confidence_index': round(business_confidence, 1),
                'new_business_registrations': int(new_business_registrations),
                'commercial_rent_growth': round(commercial_rent_growth, 2),
                'retail_vacancy_rate': round(retail_vacancy_rate, 2),
                'avg_fuel_price_kes': round(fuel_price_kes, 2),
                'usd_kes_exchange_rate': round(exchange_rate_usd, 2),
                'data_collection_date': month + timedelta(days=15),  # Mid-month collection
                'data_source': 'CBK_Economic_Indicators'
            }
            
            economic_data.append(record)
    
    df_economic = pd.DataFrame(economic_data)
    
    # Add data quality issues
    # 1. Missing values for some months/counties
    missing_mask = np.random.random(len(df_economic)) < 0.03
    random_col = np.random.choice(['gdp_growth_rate', 'inflation_rate', 'unemployment_rate'], 
                                size=missing_mask.sum())
    for i, idx in enumerate(df_economic[missing_mask].index):
        df_economic.loc[idx, random_col[i]] = np.nan
    
    # 2. Outliers in economic data
    outlier_mask = np.random.random(len(df_economic)) < 0.01
    df_economic.loc[outlier_mask, 'retail_sales_index'] = df_economic.loc[outlier_mask, 'retail_sales_index'] * 10
    
    # 3. Inconsistent date formats
    date_inconsistent = np.random.random(len(df_economic)) < 0.02
    df_economic.loc[date_inconsistent, 'data_collection_date'] = df_economic.loc[date_inconsistent, 'data_collection_date'].astype(str)
    
    print(f"Generated {len(df_economic)} monthly economic records")
    print(f"Data quality issues: Missing values ({missing_mask.sum()}), "
          f"Outliers ({outlier_mask.sum()}), "
          f"Inconsistent dates ({date_inconsistent.sum()})")
    
    return df_economic

# Generate economic data
economic_df = generate_economic_data()

# Save to bronze layer
economic_df.to_csv('economic_raw.csv', index=False)
#economic_df.to_parquet('bronze/economic_raw.parquet', index=False)

print("\nSample economic data:")
print(economic_df[['county', 'year_month', 'gdp_growth_rate', 'inflation_rate', 'retail_sales_index']].head())
print(f"\nCounties covered: {economic_df['county'].nunique()}")
print(f"Time period: {economic_df['year_month'].min()} to {economic_df['year_month'].max()}")