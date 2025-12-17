# generate_gis_data.py
import pandas as pd
import numpy as np
import random
from faker import Faker
import json
from towns import KENYAN_COUNTIES, get_random_town

fake = Faker('en_KE')
np.random.seed(44)
random.seed(44)

# Approximate coordinates for Kenyan counties (centroids)
COUNTY_COORDS = {
    'Nairobi': (-1.286389, 36.817223),
    'Mombasa': (-4.043477, 39.668206),
    'Kisumu': (-0.091702, 34.7680),
    'Nakuru': (-0.3031, 36.0800),
    'Kiambu': (-1.1717, 36.8311),
    'Uasin Gishu': (0.5167, 35.2833),
    'Meru': (0.0464, 37.6493),
    'Kakamega': (0.2824, 34.7519),
    'Machakos': (-1.5167, 37.2667),
    'Kisii': (-0.6736, 34.7718),
    'Nyeri': (-0.4167, 36.9500),
    'Nyandarua': (-0.5000, 36.4000),
    'Kericho': (-0.3670, 35.2833),
    'Embu': (-0.5333, 37.4500),
    'Kajiado': (-1.9167, 36.7833),
    'Bungoma': (0.5690, 34.5600),
    'Busia': (0.4550, 34.1100),
    'Siaya': (0.0600, 34.2900),
    'Homa Bay': (-0.5250, 34.4583),
    'Migori': (-1.0667, 34.4833),
    'Trans Nzoia': (1.0000, 35.0000),
    'Narok': (-1.0833, 35.8667),
    'Tharaka Nithi': (-0.3500, 37.6500),
    'Nyamira': (-0.5833, 34.9500),
    'Kirinyaga': (-0.6833, 37.3167),
    'Kitui': (-1.3667, 38.0167),
    'Taita Taveta': (-3.3667, 38.3667),
    'Laikipia': (0.4000, 36.7667),
    'Kwale': (-4.1833, 39.4500),
    'Makueni': (-1.8333, 37.6167),
    'Isiolo': (0.3500, 37.5833),
    'Lamu': (-2.2667, 40.9000),
    'Marsabit': (2.3333, 37.9833),
    'Samburu': (0.5167, 37.5167),
    'Turkana': (3.0000, 35.8667),
    'West Pokot': (2.5000, 35.5000),
    'Elgeyo Marakwet': (0.5167, 35.5000),
    'Bomet': (-0.7667, 35.3333),
    'Garissa': (-0.4550, 39.6500),
    'Wajir': (1.7500, 40.0500),
    'Mandera': (3.9375, 41.8569),
    'Tana River': (-1.2500, 39.9000),
    'Kilifi': (-3.6333, 39.8500),
    'Vihiga': (0.0667, 34.7333),
    'Baringo': (0.5000, 35.9667),
    'Nandi': (0.1000, 35.1667)
}

# County populations (approximate 2023)
COUNTY_POPULATIONS = {
    'Nairobi': 4800000,
    'Mombasa': 1400000,
    'Kisumu': 1200000,
    'Nakuru': 1300000,
    'Kiambu': 2200000,
    'Uasin Gishu': 1100000,
    'Meru': 1200000,
    'Kakamega': 1800000,
    'Machakos': 1300000,
    'Kisii': 1200000,
    'Nyeri': 800000,
    'Nyandarua': 650000,
    'Kericho': 900000,
    'Embu': 600000,
    'Kajiado': 1100000,
    'Bungoma': 1600000,
    'Busia': 900000,
    'Siaya': 700000,
    'Homa Bay': 600000,
    'Migori': 900000,
    'Trans Nzoia': 950000,
    'Narok': 900000,
    'Tharaka Nithi': 500000,
    'Nyamira': 600000,
    'Kirinyaga': 550000,
    'Kitui': 1300000,
    'Taita Taveta': 400000,
    'Laikipia': 500000,
    'Kwale': 700000,
    'Makueni': 1100000,
    'Isiolo': 300000,
    'Lamu': 150000,
    'Marsabit': 400000,
    'Samburu': 300000,
    'Turkana': 900000,
    'West Pokot': 600000,
    'Elgeyo Marakwet': 400000,
    'Bomet': 900000,
    'Garissa': 800000,
    'Wajir': 600000,
    'Mandera': 500000,
    'Tana River': 300000,
    'Kilifi': 1300000,
    'Vihiga': 600000,
    'Baringo': 500000,
    'Nandi': 900000
}

# Operational competitors
COMPETITORS = ['Naivas', 'Quickmart', 'Carrefour', 'Chandarana', 'Eastmatt', 'Cleanshelf', 'Khetia', 'Magunas']

def generate_gis_data():
    print("Generating GIS data for Kenyan counties...")
    
    county_data = []
    
    for county in KENYAN_COUNTIES:
        population = COUNTY_POPULATIONS.get(county, np.random.randint(200000, 5000000))
        density = np.random.randint(100, 7000)
        
        poverty_rate = np.round(np.random.uniform(0.15, 0.65), 3)
        unemployment_rate = np.round(np.random.uniform(0.05, 0.35), 3)
        avg_income = np.random.randint(20000, 120000)
        urbanization = np.round(np.random.uniform(0.2, 0.95), 3)
        literacy_rate = np.round(np.random.uniform(0.7, 0.95), 3)
        road_infra = np.round(np.random.uniform(3, 9), 1)
        public_transport = np.round(np.random.uniform(2, 8), 1)
        internet_penetration = np.round(np.random.uniform(0.3, 0.9), 3)
        commercial_rent = np.round(np.random.uniform(200, 2000), 2)
        business_days = np.random.randint(7, 30)
        security_index = np.round(np.random.uniform(5, 9), 1)
        tourist_arrivals = np.random.randint(10, 500)
        
        lat, lon = COUNTY_COORDS.get(county, (fake.latitude(), fake.longitude()))
        lat = float(lat)
        lon = float(lon)
        
        towns = [get_random_town(county) for _ in range(np.random.randint(3,8))]
        competitor_counts = {comp: np.random.poisson(2) for comp in COMPETITORS}
        
        county_data.append({
            'county_id': f"CNTY-{county.upper().replace(' ','_')[:8]}",
            'county_name': county,
            'population_2023': population,
            'population_density_psqkm': density,
            'area_sqkm': round(population / density * 1000, 2) if density > 0 else 0,
            'poverty_rate': poverty_rate,
            'unemployment_rate': unemployment_rate,
            'avg_household_income_kes': avg_income,
            'urbanization_rate': urbanization,
            'literacy_rate': literacy_rate,
            'road_infrastructure_score': road_infra,
            'public_transport_score': public_transport,
            'internet_penetration': internet_penetration,
            'commercial_rent_kes_psqm': commercial_rent,
            'business_registration_days': business_days,
            'security_index': security_index,
            'tourist_arrivals_annual': tourist_arrivals,
            'latitude': lat,
            'longitude': lon,
            'major_towns': '|'.join(towns),
            'competitor_counts_json': json.dumps(competitor_counts),
            'data_collection_date': '2025-12-31',
            'data_source': 'KNBS_GIS_System'
        })
    
    df_counties = pd.DataFrame(county_data)
    
    # Generate potential store locations
    print("Generating potential store locations...")
    location_data = []
    
    for county in KENYAN_COUNTIES:
        county_info = df_counties[df_counties['county_name']==county].iloc[0]
        num_locations = np.random.randint(10, 50)
        for loc_num in range(num_locations):
            loc_lat = float(county_info['latitude']) + np.random.uniform(-0.5, 0.5)
            loc_lon = float(county_info['longitude']) + np.random.uniform(-0.5, 0.5)
            zoning_types = ['Commercial','Mixed Use','Industrial','Residential']
            
            location_data.append({
                'location_id': f"LOC-{county[:3].upper()}-{loc_num+1:04d}",
                'county': county,
                'site_name': f"{get_random_town(county)} Site {loc_num+1}",
                'latitude': round(loc_lat, 6),
                'longitude': round(loc_lon, 6),
                'visibility_score': np.random.randint(1, 11),
                'accessibility_score': np.random.randint(1, 11),
                'estimated_daily_traffic': np.random.poisson(county_info['population_density_psqkm']/10),
                'parking_capacity': np.random.randint(0, 100),
                'zoning': np.random.choice(zoning_types, p=[0.6,0.3,0.05,0.05]),
                'property_size_sqm': np.random.choice([100,300,500,1000,2000,5000], p=[0.3,0.3,0.2,0.1,0.05,0.05]),
                'building_condition': np.random.choice(['New','Good','Fair','Needs Renovation'], p=[0.2,0.4,0.3,0.1]),
                'competition_within_1km': np.random.poisson(county_info['population_density_psqkm']/5000),
                'complementary_businesses': np.random.poisson(county_info['population_density_psqkm']/10000),
                'last_survey_date': fake.date_between(start_date='-1y', end_date='today'),
                'data_source': 'GIS_Field_Survey'
            })
    
    df_locations = pd.DataFrame(location_data)
    
    # Inject data quality issues
    df_locations.loc[np.random.random(len(df_locations))<0.02, ['latitude','longitude']] = np.nan
    df_locations.loc[np.random.random(len(df_locations))<0.01, 'county'] = df_locations['county'].str.upper()
    outlier_mask = np.random.random(len(df_locations))<0.005
    df_locations.loc[outlier_mask,'estimated_daily_traffic'] *= 100
    
    print(f"Generated {len(df_counties)} counties and {len(df_locations)} potential locations")
    return df_counties, df_locations

if __name__ == "__main__":
    counties_gis_df, locations_gis_df = generate_gis_data()
    counties_gis_df.to_csv('gis_counties_raw.csv', index=False)
    locations_gis_df.to_csv('gis_locations_raw.csv', index=False)
    
    print("\nSample county data:")
    print(counties_gis_df.head())
    print("\nSample location data:")
    print(locations_gis_df.head())
