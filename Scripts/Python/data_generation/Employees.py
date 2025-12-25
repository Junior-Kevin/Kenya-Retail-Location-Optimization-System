# generate_hr_data.py
import pandas as pd
import numpy as np
from faker import Faker
from datetime import datetime, timedelta, date
import random
import os
from towns import KENYAN_COUNTIES, get_random_town, get_weighted_town

# Initialize Faker with Kenyan context
fake = Faker('en_KE')
Faker.seed(42)
np.random.seed(42)
random.seed(42)

# Department codes for employee IDs
DEPT_CODES = {
    'HR': 'HR',
    'IT': 'IT',
    'Sales': 'SAL',
    'Marketing': 'MRK',
    'Finance': 'FIN',
    'Operations': 'OPS',
    'Customer Service': 'CS'
}

# Job title codes for employee IDs
JOB_CODES = {
    # HR
    'HR Manager': 'HRM',
    'HR Coordinator': 'HRC',
    'Recruiter': 'REC',
    'HR Assistant': 'HRA',
    
    # IT
    'IT Manager': 'ITM',
    'Software Developer': 'SDE',
    'System Administrator': 'SYS',
    'Data Lead': 'DTL',
    'Data Engineer': 'DEG',
    'Data Analyst': 'DAN',
    
    # Sales
    'Sales Manager': 'SLM',
    'Sales Consultant': 'SLC',
    'Sales Specialist': 'SLS',
    'Sales Representative': 'SLR',
    
    # Marketing
    'Marketing Manager': 'MKM',
    'Digital Marketer': 'MKD',
    'Content Creator': 'MKC',
    'Marketing Coordinator': 'MKO',
    
    # Finance
    'Finance Manager': 'FNM',
    'Accountant': 'FNA',
    'Financial Analyst': 'FNF',
    'Accounts Payable Specialist': 'FNP',
    
    # Operations
    'Operations Manager': 'OPM',
    'Store Manager': 'STM',  # Store Manager
    'Operations Analyst': 'OPA',
    'Logistics Coordinator': 'OPL',
    'Inventory Specialist': 'OPI',
    
    # Customer Service
    'Customer Service Manager': 'CSM',
    'Customer Service Representative': 'CSR',
    'Support Specialist': 'CSS',
    'Help Desk Technician': 'CSH',
    'Cashier': 'CAS'  # Cashier code
}

# Configuration
total_stores = 150
cashiers_per_store = 3  # Day, Night, Off shifts
store_managers_per_store = 1
headquarters_employees = 3000  # Employees at HQ
total_employees = headquarters_employees + (total_stores * (cashiers_per_store + store_managers_per_store))

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

# Departments & Job Titles (adjusted for Kenyan context)
departments = ['HR', 'IT', 'Sales', 'Marketing', 'Finance', 'Operations', 'Customer Service']
departments_prob = [0.02, 0.15, 0.21, 0.08, 0.05, 0.30, 0.19]

# Headquarters job titles (exclude store-specific roles)
headquarters_jobtitles = {
    'HR': ['HR Manager', 'HR Coordinator', 'Recruiter', 'HR Assistant'],
    'IT': ['IT Manager', 'Software Developer', 'System Administrator', 'Data Lead', 'Data Engineer', 'Data Analyst'],
    'Sales': ['Sales Manager', 'Sales Consultant', 'Sales Specialist', 'Sales Representative'],
    'Marketing': ['Marketing Manager', 'Digital Marketer', 'Content Creator', 'Marketing Coordinator'],
    'Finance': ['Finance Manager', 'Accountant', 'Financial Analyst', 'Accounts Payable Specialist'],
    'Operations': ['Operations Manager', 'Operations Analyst', 'Logistics Coordinator', 'Inventory Specialist'],
    'Customer Service': ['Customer Service Manager', 'Customer Service Representative', 'Support Specialist', 'Help Desk Technician']
}

# Store-specific job titles
store_jobtitles = {
    'Operations': ['Store Manager', 'Inventory Specialist'],
    'Customer Service': ['Cashier']
}

headquarters_jobtitles_prob = {
    'HR': [0.03, 0.3, 0.47, 0.2],
    'IT': [0.02, 0.35, 0.2, 0.02, 0.15, 0.26],
    'Sales': [0.03, 0.25, 0.32, 0.4],
    'Marketing': [0.04, 0.25, 0.41, 0.3],
    'Finance': [0.03, 0.37, 0.4, 0.2],
    'Operations': [0.02, 0.45, 0.35, 0.18],  # No Store Manager at HQ
    'Customer Service': [0.04, 0.35, 0.35, 0.26]  # No Cashier at HQ
}

store_jobtitles_prob = {
    'Operations': [0.5, 0.5],  # Store Manager, Inventory Specialist
    'Customer Service': [1.0]   # Cashier only
}

# Education levels (Kenyan context)
educations = ['KCSE', 'Diploma', 'Bachelor', 'Master', 'PhD']

education_mapping = {
    'HR Manager': ["Master", "PhD"],
    'HR Coordinator': ["Bachelor", "Master"],
    'Recruiter': ["Diploma", "Bachelor"],
    'HR Assistant': ["KCSE", "Diploma"],
    'IT Manager': ["Master", "PhD"],
    'Software Developer': ["Bachelor", "Master"],
    'Data Engineer': ["Bachelor", "Master"],
    'Data Analyst': ["Bachelor", "Master"],
    'System Administrator': ["Diploma", "Bachelor"],
    'IT Support Specialist': ["KCSE", "Diploma"],
    'Sales Manager': ["Bachelor", "Master"],
    'Sales Consultant': ["Diploma", "Bachelor"],
    'Sales Specialist': ["Diploma", "Bachelor"],
    'Sales Representative': ["KCSE", "Diploma"],
    'Marketing Manager': ["Bachelor", "Master"],
    'Store Manager': ["Bachelor", "Master"],
    'Digital Marketer': ["Diploma", "Bachelor"],
    'Content Creator': ["KCSE", "Diploma"],
    'Marketing Coordinator': ["Diploma", "Bachelor"],
    'Finance Manager': ["Bachelor", "Master"],
    'Accountant': ["Diploma", "Bachelor"],
    'Financial Analyst': ["Bachelor", "Master"],
    'Accounts Payable Specialist': ["Diploma", "Bachelor"],
    'Operations Manager': ["Bachelor", "Master"],
    'Operations Analyst': ["Diploma", "Bachelor"],
    'Logistics Coordinator': ["Diploma", "Bachelor"],
    'Inventory Specialist': ["KCSE", "Diploma"],
    'Customer Service Manager': ["Diploma", "Bachelor"],
    'Customer Service Representative': ["KCSE", "Diploma"],
    'Support Specialist': ["KCSE", "Diploma"],
    'Help Desk Technician': ["KCSE", "Diploma"],
    'Cashier': ["KCSE", "Diploma"],
    'Data Lead': ["Bachelor", "Master"]
}

# Salary ranges adjusted for Kenyan market (in KSh)
def generate_salary(department, job_title):
    salary_dict = {
        'HR': {
            'HR Manager': np.random.randint(120000, 250000),
            'HR Coordinator': np.random.randint(80000, 150000),
            'Recruiter': np.random.randint(70000, 120000),
            'HR Assistant': np.random.randint(40000, 80000)
        },
        'IT': {
            'IT Manager': np.random.randint(150000, 350000),
            'Data Lead': np.random.randint(150000, 350000),
            'Software Developer': np.random.randint(100000, 250000),
            'System Administrator': np.random.randint(80000, 180000),
            'IT Support Specialist': np.random.randint(50000, 100000),
            'Data Engineer': np.random.randint(100000, 150000),
            'Data Analyst': np.random.randint(100000, 130000)
        },
        'Sales': {
            'Sales Manager': np.random.randint(120000, 300000),
            'Sales Consultant': np.random.randint(80000, 180000),
            'Sales Specialist': np.random.randint(70000, 150000),
            'Sales Representative': np.random.randint(40000, 90000)
        },
        'Marketing': {
            'Marketing Manager': np.random.randint(120000, 280000),
            'Digital Marketer': np.random.randint(70000, 160000),
            'Content Creator': np.random.randint(50000, 120000),
            'Marketing Coordinator': np.random.randint(60000, 130000)
        },
        'Finance': {
            'Finance Manager': np.random.randint(150000, 320000),
            'Accountant': np.random.randint(80000, 180000),
            'Financial Analyst': np.random.randint(90000, 200000),
            'Accounts Payable Specialist': np.random.randint(50000, 100000)
        },
        'Operations': {
            'Operations Manager': np.random.randint(130000, 270000),
            'Store Manager': np.random.randint(130000, 230000),
            'Operations Analyst': np.random.randint(70000, 150000),
            'Logistics Coordinator': np.random.randint(50000, 110000),
            'Inventory Specialist': np.random.randint(40000, 80000)
        },
        'Customer Service': {
            'Customer Service Manager': np.random.randint(100000, 200000),
            'Customer Service Representative': np.random.randint(30000, 70000),
            'Support Specialist': np.random.randint(40000, 90000),
            'Help Desk Technician': np.random.randint(45000, 95000),
            'Cashier': np.random.randint(55000, 95000)
        }
    }
    return salary_dict[department][job_title]

# Generate employee ID with format: DEPT-HIREYEAR-JOBCODE-RANDOM
def generate_employee_id(department, hire_year, job_title, employee_counter):
    dept_code = DEPT_CODES[department]
    job_code = JOB_CODES[job_title]
    random_num = random.randint(1000, 9999)
    return f"{dept_code}-{hire_year}-{job_code}-{random_num}"

# Generate work shift for store employees
def generate_work_shift(job_title, store_id=None):
    """Generate work shift for store employees"""
    if job_title == 'Cashier' and store_id:
        # Cashiers work in 3 shifts: Day (7am-3pm), Night (3pm-11pm), Off
        shift = random.choice(['Day', 'Night', 'Off'])
        shift_hours = {
            'Day': '07:00-15:00',
            'Night': '15:00-23:00',
            'Off': '00:00-00:00'
        }
        return shift, shift_hours[shift]
    elif job_title == 'Store Manager' and store_id:
        # Store Managers typically work day shifts
        return 'Day', '08:00-17:00'
    else:
        # HQ employees standard hours
        return 'Standard', '08:00-17:00'

# Load existing store data
def load_store_data():
    """Load store data from stores_raw.csv or generate placeholder"""
    try:
        stores_df = pd.read_csv('bronze/stores_raw.csv')
        return stores_df
    except:
        print("Warning: Could not load store data. Generating placeholder stores.")
        # Create placeholder stores
        stores = []
        for i in range(1, total_stores + 1):
            county = np.random.choice(KENYAN_COUNTIES)
            town = get_random_town(county)
            stores.append({
                'store_id': f"STR-{i:04d}",
                'store_name': f"KenyanFresh {town}",
                'county': county,
                'format': np.random.choice(['Supermarket', 'Mini-mart', 'Express Store', 'Hypermarket']),
                'size_sqm': np.random.choice([100, 300, 800, 2000, 5000])
            })
        return pd.DataFrame(stores)

# Generate the dataset
def generate_hr_dataset():
    print("Generating HR dataset...")
    print(f"Total employees to generate: {total_employees}")
    print(f"  - HQ employees: {headquarters_employees}")
    print(f"  - Store Managers: {total_stores}")
    print(f"  - Cashiers: {total_stores * cashiers_per_store}")
    
    stores_df = load_store_data()
    data = []
    employee_counter = 1
    
    # Track store assignments
    store_assignments = {
        'managers': {store_id: 0 for store_id in stores_df['store_id']},
        'cashiers': {store_id: 0 for store_id in stores_df['store_id']}
    }
    
    # 1. FIRST: Generate store employees (Store Managers and Cashiers)
    print("\nGenerating store employees...")
    
    # Create Store Managers (1 per store)
    for store_idx, store in stores_df.iterrows():
        store_id = store['store_id']
        county = store['county']
        
        # Generate Store Manager
        hire_year = np.random.choice([2020, 2021, 2022, 2023, 2024], p=[0.1, 0.15, 0.25, 0.3, 0.2])
        department = 'Operations'
        job_title = 'Store Manager'
        
        employee_id = generate_employee_id(department, hire_year, job_title, employee_counter)
        employee_counter += 1
        
        first_name = fake.first_name()
        last_name = fake.last_name()
        gender = np.random.choice(['Female', 'Male'], p=[0.46, 0.54])
        town = get_random_town(county)
        
        # FIX: Use date_between with date objects
        hiredate = fake.date_between(
            start_date=date(hire_year, 1, 1),
            end_date=date(hire_year, 12, 31)
        )
        
        education_level = np.random.choice(education_mapping.get(job_title, ['Bachelor', 'Master']))
        performance_rating = np.random.choice(['Excellent', 'Good', 'Satisfactory'], p=[0.15, 0.6, 0.25])
        overtime = np.random.choice(['Yes', 'No'], p=[0.4, 0.6])
        salary = generate_salary(department, job_title)
        
        shift, shift_hours = generate_work_shift(job_title, store_id)
        
        data.append([
            employee_id,
            first_name,
            last_name,
            gender,
            county,
            town,
            hiredate,
            department,
            job_title,
            education_level,
            salary,
            performance_rating,
            overtime,
            store_id,
            shift,
            shift_hours
        ])
        
        store_assignments['managers'][store_id] += 1
    
    # Create Cashiers (3 per store - Day, Night, Off shifts)
    for store_idx, store in stores_df.iterrows():
        store_id = store['store_id']
        county = store['county']
        
        for cashier_num in range(cashiers_per_store):
            hire_year = np.random.choice([2022, 2023, 2024], p=[0.2, 0.4, 0.4])
            department = 'Customer Service'
            job_title = 'Cashier'
            
            employee_id = generate_employee_id(department, hire_year, job_title, employee_counter)
            employee_counter += 1
            
            first_name = fake.first_name()
            last_name = fake.last_name()
            gender = np.random.choice(['Female', 'Male'], p=[0.55, 0.45])  # More female cashiers
            town = get_random_town(county)
            
            # FIX: Use date_between with date objects
            hiredate = fake.date_between(
                start_date=date(hire_year, 1, 1),
                end_date=date(hire_year, 12, 31)
            )
            
            education_level = np.random.choice(education_mapping.get(job_title, ['KCSE', 'Diploma']))
            performance_rating = np.random.choice(['Excellent', 'Good', 'Satisfactory', 'Needs Improvement'], 
                                                p=[0.1, 0.6, 0.25, 0.05])
            overtime = np.random.choice(['Yes', 'No'], p=[0.6, 0.4])
            salary = generate_salary(department, job_title)
            
            shift, shift_hours = generate_work_shift(job_title, store_id)
            
            data.append([
                employee_id,
                first_name,
                last_name,
                gender,
                county,
                town,
                hiredate,
                department,
                job_title,
                education_level,
                salary,
                performance_rating,
                overtime,
                store_id,
                shift,
                shift_hours
            ])
            
            store_assignments['cashiers'][store_id] += 1
    
    print(f"Generated {store_assignments['managers'][list(store_assignments['managers'].keys())[0]]} store managers and {store_assignments['cashiers'][list(store_assignments['cashiers'].keys())[0]]} cashiers per store")
    
    # 2. SECOND: Generate HQ employees
    print("\nGenerating HQ employees...")
    
    # HQ is in Nairobi
    hq_county = 'Nairobi'
    hq_town = 'Westlands'
    
    for i in range(headquarters_employees):
        department = np.random.choice(departments, p=departments_prob)
        job_title = np.random.choice(headquarters_jobtitles[department], 
                                   p=headquarters_jobtitles_prob[department])
        
        hire_year = np.random.choice([2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024],
                                   p=[0.02, 0.03, 0.05, 0.07, 0.08, 0.10, 0.15, 0.20, 0.15, 0.15])
        
        employee_id = generate_employee_id(department, hire_year, job_title, employee_counter)
        employee_counter += 1
        
        first_name = fake.first_name()
        last_name = fake.last_name()
        gender = np.random.choice(['Female', 'Male'], p=[0.46, 0.54])
        
        # FIX: Use date_between with date objects
        hiredate = fake.date_between(
            start_date=date(hire_year, 1, 1),
            end_date=date(hire_year, 12, 31)
        )
        
        education_level = np.random.choice(education_mapping.get(job_title, ['Bachelor', 'Master']))
        performance_rating = np.random.choice(['Excellent', 'Good', 'Satisfactory', 'Needs Improvement'], 
                                            p=[0.12, 0.5, 0.3, 0.08])
        overtime = np.random.choice(['Yes', 'No'], p=[0.3, 0.7])
        salary = generate_salary(department, job_title)
        
        shift, shift_hours = generate_work_shift(job_title)
        
        data.append([
            employee_id,
            first_name,
            last_name,
            gender,
            hq_county,
            hq_town,
            hiredate,
            department,
            job_title,
            education_level,
            salary,
            performance_rating,
            overtime,
            None,  # No store assignment for HQ employees
            shift,
            shift_hours
        ])
    
    # Create DataFrame
    columns = [
        'employee_id',
        'first_name',
        'last_name',
        'gender',
        'county',
        'town',
        'hiredate',
        'department',
        'job_title',
        'education_level',
        'salary',
        'performance_rating',
        'overtime',
        'store_id',
        'shift',
        'shift_hours'
    ]
    
    df = pd.DataFrame(data, columns=columns)
    
    # Add Birthdate
    def generate_birthdate(row):
        age_distribution = {
            'under_25': 0.15,
            '25_34': 0.30,
            '35_44': 0.28,
            '45_54': 0.20,
            'over_55': 0.07
        }
        age_groups = list(age_distribution.keys())
        age_probs = list(age_distribution.values())
        age_group = np.random.choice(age_groups, p=age_probs)
        
        if any('Manager' in str(title) for title in [row['job_title']]):
            age = np.random.randint(30, 65)
        elif row['education_level'] == 'PhD':
            age = np.random.randint(28, 65)
        elif row['job_title'] == 'Cashier':
            age = np.random.randint(18, 45)  # Cashiers tend to be younger
        elif age_group == 'under_25':
            age = np.random.randint(20, 25)
        elif age_group == '25_34':
            age = np.random.randint(25, 35)
        elif age_group == '35_44':
            age = np.random.randint(35, 45)
        elif age_group == '45_54':
            age = np.random.randint(45, 55)
        else:
            age = np.random.randint(55, 65)
        
        birthdate = fake.date_of_birth(minimum_age=age, maximum_age=age)
        return birthdate
    
    df['birthdate'] = df.apply(generate_birthdate, axis=1)
    
    # Add termination dates
    termination_year_weights = {
        2015: 5, 2016: 7, 2017: 10, 2018: 12, 2019: 9,
        2020: 10, 2021: 20, 2022: 10, 2023: 7, 2024: 10
    }
    
    total_employees_count = len(df)
    termination_percentage = 0.112
    total_terminated = int(total_employees_count * termination_percentage)
    
    termination_dates = []
    for year, weight in termination_year_weights.items():
        num_terminations = int(total_terminated * (weight / 100))
        termination_dates.extend([year] * num_terminations)
    
    random.shuffle(termination_dates)
    
    terminated_indices = df.index[:total_terminated]
    df['termdate'] = None
    
    for i, year in enumerate(termination_dates[:total_terminated]):
        term_date = date(year, 1, 1) + timedelta(days=random.randint(0, 365))
        df.at[terminated_indices[i], 'termdate'] = term_date
    
    # Ensure termdate is at least 6 months after hiredate
    def adjust_termdate(row):
        if pd.isna(row['termdate']):
            return None
        
        # Convert to datetime objects for comparison
        termdate = pd.to_datetime(row['termdate'])
        hiredate = pd.to_datetime(row['hiredate'])
        
        min_term_date = hiredate + timedelta(days=180)
        
        if termdate < min_term_date:
            new_date = min_term_date + timedelta(days=random.randint(0, 365))
            return new_date.date()  # Return as date object
        return row['termdate']
    
    df['termdate'] = df.apply(adjust_termdate, axis=1)
    
    # Education multiplier adjusted for Kenyan context
    education_multiplier = {
        'KCSE': {'Male': 1.0, 'Female': 0.95},
        'Diploma': {'Male': 1.05, 'Female': 1.0},
        'Bachelor': {'Male': 1.10, 'Female': 1.0},
        'Master': {'Male': 1.0, 'Female': 1.08},
        'PhD': {'Male': 1.0, 'Female': 1.15}
    }
    
    def calculate_age(birthdate):
        if pd.isna(birthdate):
            return np.random.randint(25, 45)
        today = date.today()
        age = today.year - birthdate.year - ((today.month, today.day) < (birthdate.month, birthdate.day))
        return age
    
    def calculate_adjusted_salary(row):
        base_salary = row['salary']
        gender = row['gender']
        education = row['education_level']
        
        # Calculate age safely
        try:
            age = calculate_age(row['birthdate'])
        except:
            age = np.random.randint(25, 45)
        
        multiplier = education_multiplier.get(education, {}).get(gender, 1.0)
        adjusted_salary = base_salary * multiplier
        
        age_increment = 1 + np.random.uniform(0.001, 0.003) * age
        adjusted_salary *= age_increment
        
        adjusted_salary = max(adjusted_salary, base_salary)
        return round(adjusted_salary)
    
    # Apply salary adjustments
    df['salary'] = df.apply(calculate_adjusted_salary, axis=1)
    
    # Add data quality issues
    # 1. Missing store IDs for some store employees
    store_employees = df[df['store_id'].notna()]
    missing_store_mask = (df['store_id'].notna()) & (np.random.random(len(df)) < 0.03)
    df.loc[missing_store_mask, 'store_id'] = np.nan
    
    # 2. Duplicate employee records
    duplicates = df.sample(n=int(len(df) * 0.02), random_state=42)
    duplicates = duplicates.copy()
    duplicates['employee_id'] = duplicates['employee_id'] + '-DUP'
    df = pd.concat([df, duplicates], ignore_index=True)
    
    # 3. Invalid dates
    invalid_date_mask = np.random.random(len(df)) < 0.01
    df.loc[invalid_date_mask, 'hiredate'] = pd.NaT
    
    # 4. Invalid employee IDs (missing hyphens, wrong format)
    invalid_id_mask = np.random.random(len(df)) < 0.005
    df.loc[invalid_id_mask, 'employee_id'] = df.loc[invalid_id_mask, 'employee_id'].str.replace('-', '')
    
    # 5. Invalid shift assignments
    invalid_shift_mask = np.random.random(len(df)) < 0.005
    invalid_shifts = ['Unknown', 'Midnight', 'Double']
    df.loc[invalid_shift_mask, 'shift'] = np.random.choice(invalid_shifts, size=invalid_shift_mask.sum())
    
    # Convert dates to string format for CSV
    df['hiredate'] = pd.to_datetime(df['hiredate'], errors='coerce').dt.strftime('%Y-%m-%d')
    df['birthdate'] = pd.to_datetime(df['birthdate'], errors='coerce').dt.strftime('%Y-%m-%d')
    df['termdate'] = pd.to_datetime(df['termdate'], errors='coerce').dt.strftime('%Y-%m-%d')
    
    # Add metadata columns
    df['data_source'] = 'HR_System'
    df['extracted_date'] = datetime.now().strftime('%Y-%m-%d')
    df['record_version'] = 1
    
    # Summary statistics
    print(f"\nHR Dataset Summary:")
    print(f"  Total employees: {len(df)}")
    print(f"  HQ employees: {df['store_id'].isna().sum()}")
    print(f"  Store employees: {df['store_id'].notna().sum()}")
    print(f"  Store Managers: {(df['job_title'] == 'Store Manager').sum()}")
    print(f"  Cashiers: {(df['job_title'] == 'Cashier').sum()}")
    print(f"  Unique employee IDs: {df['employee_id'].nunique()}")
    
    print(f"\nData quality issues:")
    print(f"  Missing store IDs: {missing_store_mask.sum()}")
    print(f"  Duplicates: {len(duplicates)}")
    print(f"  Invalid dates: {invalid_date_mask.sum()}")
    print(f"  Invalid employee IDs: {invalid_id_mask.sum()}")
    print(f"  Invalid shifts: {invalid_shift_mask.sum()}")
    
    # Print sample employee IDs
    print(f"\nSample Employee IDs:")
    
    # Get samples safely
    hq_manager_sample = df[df['job_title'] == 'HR Manager']
    if not hq_manager_sample.empty:
        print(f"  HQ Manager: {hq_manager_sample['employee_id'].iloc[0]}")
    
    store_manager_sample = df[df['job_title'] == 'Store Manager']
    if not store_manager_sample.empty:
        print(f"  Store Manager: {store_manager_sample['employee_id'].iloc[0]}")
    
    cashier_sample = df[df['job_title'] == 'Cashier']
    if not cashier_sample.empty:
        print(f"  Cashier: {cashier_sample['employee_id'].iloc[0]}")
    
    developer_sample = df[df['job_title'] == 'Software Developer']
    if not developer_sample.empty:
        print(f"  Developer: {developer_sample['employee_id'].iloc[0]}")
    
    return df

# Generate HR data
os.makedirs('bronze', exist_ok=True)
hr_df = generate_hr_dataset()

# Save to bronze layer
hr_df.to_csv('bronze/hr_raw.csv', index=False)

print("\n" + "="*60)
print("HR DATA GENERATION COMPLETE")
print("="*60)
print("\nEmployee ID Format: DEPT-HIREYEAR-JOBCODE-RANDOM")
print("Examples:")
print("  HR-2023-HRM-4582 (HR Manager hired in 2023)")
print("  OPS-2022-STM-7124 (Store Manager hired in 2022)")
print("  CS-2024-CAS-9315 (Cashier hired in 2024)")
print("  IT-2021-SDE-6248 (Software Developer hired in 2021)")

print("\nStore Employee Distribution:")
store_employees = hr_df[hr_df['store_id'].notna()]
if not store_employees.empty:
    store_summary = store_employees.groupby('store_id').agg({
        'employee_id': 'count',
        'job_title': lambda x: (x == 'Store Manager').sum()
    }).rename(columns={'employee_id': 'total', 'job_title': 'managers'})
    store_summary['cashiers'] = store_summary['total'] - store_summary['managers']
    
    print(f"\nFirst 10 stores:")
    print(store_summary.head(10))
    print(f"\nAverage per store: {store_summary['total'].mean():.1f} employees")
    print(f"  Store Managers: {store_summary['managers'].mean():.1f}")
    print(f"  Cashiers: {store_summary['cashiers'].mean():.1f}")

print("\nShift Distribution for Cashiers:")
cashiers = hr_df[hr_df['job_title'] == 'Cashier']
if not cashiers.empty:
    shift_counts = cashiers['shift'].value_counts()
    print(shift_counts)

print("\nDepartment Distribution:")
dept_counts = hr_df['department'].value_counts()
print(dept_counts)