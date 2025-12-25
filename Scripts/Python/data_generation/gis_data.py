# generate_gis_data.py
import pandas as pd
import numpy as np
import random
from faker import Faker
import json
import os
from towns import KENYAN_COUNTIES, get_random_town

fake = Faker('en_KE')
np.random.seed(44)
random.seed(44)

# ===============================
# COUNTY COORDINATES (CENTROIDS)
# ===============================
COUNTY_COORDS = {
    'Mombasa': (-4.043477, 39.668206),
    'Kwale': (-4.1833, 39.4500),
    'Kilifi': (-3.6333, 39.8500),
    'Tana River': (-1.2500, 39.9000),
    'Lamu': (-2.2667, 40.9000),
    'Taita Taveta': (-3.3667, 38.3667),

    'Garissa': (-0.4550, 39.6500),
    'Wajir': (1.7500, 40.0500),
    'Mandera': (3.9375, 41.8569),

    'Marsabit': (2.3333, 37.9833),
    'Isiolo': (0.3500, 37.5833),
    'Meru': (0.0464, 37.6493),
    'Tharaka Nithi': (-0.3500, 37.6500),
    'Embu': (-0.5333, 37.4500),
    'Kitui': (-1.3667, 38.0167),
    'Machakos': (-1.5167, 37.2667),
    'Makueni': (-1.8333, 37.6167),

    'Nyandarua': (-0.5000, 36.4000),
    'Nyeri': (-0.4167, 36.9500),
    'Kirinyaga': (-0.6833, 37.3167),
    "Murang'a": (-0.7833, 37.1500),
    'Kiambu': (-1.1717, 36.8311),

    'Turkana': (3.0000, 35.8667),
    'West Pokot': (2.5000, 35.5000),
    'Samburu': (0.5167, 37.5167),
    'Trans Nzoia': (1.0000, 35.0000),
    'Uasin Gishu': (0.5167, 35.2833),
    'Elgeyo Marakwet': (0.5167, 35.5000),
    'Nandi': (0.1000, 35.1667),
    'Baringo': (0.5000, 35.9667),
    'Laikipia': (0.4000, 36.7667),
    'Nakuru': (-0.3031, 36.0800),
    'Narok': (-1.0833, 35.8667),
    'Kajiado': (-1.9167, 36.7833),
    'Kericho': (-0.3670, 35.2833),
    'Bomet': (-0.7667, 35.3333),
    'Kakamega': (0.2824, 34.7519),
    'Vihiga': (0.0667, 34.7333),
    'Bungoma': (0.5690, 34.5600),
    'Busia': (0.4550, 34.1100),
    'Siaya': (0.0600, 34.2900),
    'Kisumu': (-0.091702, 34.7680),
    'Homa Bay': (-0.5250, 34.4583),
    'Migori': (-1.0667, 34.4833),
    'Kisii': (-0.6736, 34.7718),
    'Nyamira': (-0.5833, 34.9500),

    'Nairobi': (-1.286389, 36.817223)
}

# ==================================
# COUNTY POPULATION (2025 ESTIMATES)
# ==================================
COUNTY_POPULATIONS = {
    'Mombasa': 1368000,
    'Kwale': 988056,
    'Kilifi': 1636510,
    'Tana River': 370332,
    'Lamu': 175705,
    'Taita Taveta': 372907,

    'Garissa': 970917,
    'Wajir': 915139,
    'Mandera': 867457,

    'Marsabit': 539000,
    'Isiolo': 330000,
    'Meru': 1666000,
    'Tharaka Nithi': 434000,
    'Embu': 600000,
    'Kitui': 1136167,
    'Machakos': 1518000,
    'Makueni': 1086180,

    "Nyandarua": 650000,
    "Nyeri": 800000,
    "Kirinyaga": 550000,
    "Murang'a": 1164000,
    "Kiambu": 2754000,

    'Turkana': 926976,
    'West Pokot': 706462,
    'Samburu': 367000,
    'Trans Nzoia': 950000,
    'Uasin Gishu': 1163000,
    'Elgeyo Marakwet': 509000,
    'Nandi': 900000,
    'Baringo': 500000,
    'Laikipia': 583000,
    'Nakuru': 2445000,
    'Narok': 1355000,
    'Kajiado': 1117000,
    'Kericho': 900000,
    'Bomet': 900000,
    'Kakamega': 2073000,
    'Vihiga': 636000,
    'Bungoma': 2073000,
    'Busia': 944464,
    'Siaya': 993000,
    'Kisumu': 1301750,
    'Homa Bay': 1130000,
    'Migori': 1116436,
    'Kisii': 1370000,
    'Nyamira': 735000,

    'Nairobi': 4906000
}

# ===============================
# REALISTIC COUNTY PROFILES
# ===============================
URBAN_COUNTIES = {'Nairobi', 'Mombasa', 'Kiambu', 'Kisumu', 'Nakuru'}
ASAL_COUNTIES = {'Turkana', 'Marsabit', 'Mandera', 'Wajir', 'Samburu', 'Garissa', 'Isiolo'}
TOURISM_COUNTIES = {'Narok', 'Mombasa', 'Kilifi', 'Kwale', 'Lamu'}

COMPETITORS = ['Naivas', 'Quickmart', 'Carrefour', 'Chandarana', 'Eastmatt', 'Cleanshelf', 'Khetia', 'Magunas']

# ===============================
# MAIN GENERATOR
# ===============================
def generate_gis_data():
    county_data = []

    for county in KENYAN_COUNTIES:
        pop = COUNTY_POPULATIONS[county]

        # Density
        if county in URBAN_COUNTIES:
            density = np.random.randint(1200, 9000)
        elif county in ASAL_COUNTIES:
            density = np.random.randint(5, 50)
        else:
            density = np.random.randint(100, 800)

        # Poverty
        poverty = (
            np.random.uniform(0.15, 0.30) if county in URBAN_COUNTIES else
            np.random.uniform(0.45, 0.70) if county in ASAL_COUNTIES else
            np.random.uniform(0.25, 0.50)
        )

        # Income
        income = (
            np.random.randint(60000, 150000) if county in URBAN_COUNTIES else
            np.random.randint(15000, 40000) if county in ASAL_COUNTIES else
            np.random.randint(25000, 60000)
        )

        # Urbanization
        urban = (
            np.random.uniform(0.7, 0.98) if county in URBAN_COUNTIES else
            np.random.uniform(0.2, 0.45) if county in ASAL_COUNTIES else
            np.random.uniform(0.35, 0.65)
        )

        lat, lon = COUNTY_COORDS[county]

        towns = [get_random_town(county) for _ in range(np.random.randint(3, 8))]
        competitors = {c: int(np.random.poisson(2)) for c in COMPETITORS}

        county_data.append({
            'county_id': f"CNTY-{county.upper().replace(' ', '_')[:8]}",
            'county_name': county,
            'population_2023': pop,
            'population_density_psqkm': density,
            'area_sqkm': round(pop / density, 2),
            'poverty_rate': round(poverty, 3),
            'unemployment_rate': round(np.random.uniform(0.05, 0.25), 3),
            'avg_household_income_kes': income,
            'urbanization_rate': round(urban, 3),
            'literacy_rate': round(np.random.uniform(0.65, 0.95), 3),
            'road_infrastructure_score': round(np.random.uniform(3, 9), 1),
            'public_transport_score': round(np.random.uniform(2, 8), 1),
            'internet_penetration': round(np.random.uniform(0.3, 0.9), 3),
            'commercial_rent_kes_psqm': np.random.randint(300, 2500),
            'business_registration_days': np.random.randint(7, 30),
            'security_index': round(np.random.uniform(4.5, 9), 1),
            'tourist_arrivals_annual': (
                np.random.randint(200000, 2000000) if county in TOURISM_COUNTIES else
                np.random.randint(2000, 50000)
            ),
            'latitude': lat,
            'longitude': lon,
            'major_towns': '|'.join(towns),
            'competitor_counts_json': json.dumps(competitors),
            'data_collection_date': '2025-12-31',
            'data_source': 'KNBS_GIS_SYNTHETIC'
        })

    df_counties = pd.DataFrame(county_data)

    # ===============================
    # LOCATION DATA
    # ===============================
    location_data = []

    for _, row in df_counties.iterrows():
        for i in range(np.random.randint(10, 50)):
            location_data.append({
                'location_id': f"LOC-{row['county_name'][:3].upper()}-{i+1:04d}",
                'county': row['county_name'],
                'site_name': f"{get_random_town(row['county_name'])} Site {i+1}",
                'latitude': row['latitude'] + np.random.uniform(-0.05, 0.05),
                'longitude': row['longitude'] + np.random.uniform(-0.05, 0.05),
                'visibility_score': np.random.randint(1, 11),
                'accessibility_score': np.random.randint(1, 11),
                'estimated_daily_traffic': int(np.random.poisson(row['population_density_psqkm'] / 5)),
                'parking_capacity': np.random.randint(0, 120),
                'zoning': np.random.choice(['Commercial', 'Mixed Use', 'Residential'], p=[0.6, 0.3, 0.1]),
                'property_size_sqm': np.random.choice([100, 300, 500, 1000, 2000, 5000]),
                'building_condition': np.random.choice(['New', 'Good', 'Fair', 'Needs Renovation']),
                'competition_within_1km': np.random.poisson(row['population_density_psqkm'] / 4000),
                'complementary_businesses': np.random.poisson(row['population_density_psqkm'] / 8000),
                'last_survey_date': fake.date_between('-1y', 'today'),
                'data_source': 'GIS_FIELD_SURVEY'
            })

    df_locations = pd.DataFrame(location_data)

    # ===============================
    # INTENTIONAL DATA QUALITY ISSUES
    # ===============================
    df_locations.loc[np.random.random(len(df_locations)) < 0.02, ['latitude', 'longitude']] = np.nan
    df_locations.loc[np.random.random(len(df_locations)) < 0.01, 'county'] = df_locations['county'].str.upper()
    df_locations.loc[np.random.random(len(df_locations)) < 0.005, 'estimated_daily_traffic'] *= 100

    return df_counties, df_locations


if __name__ == "__main__":
    os.makedirs('bronze', exist_ok=True)
    counties_df, locations_df = generate_gis_data()
    counties_df.to_csv("bronze/gis_counties_raw.csv", index=False)
    locations_df.to_csv("bronze/gis_locations_raw.csv", index=False)

    print("\nGenerated GIS data:")
    print(counties_df.head())
    print(f"\nTotal counties: {len(counties_df)}")
    print(f"Total locations: {len(locations_df)}")