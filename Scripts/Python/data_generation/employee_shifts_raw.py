# employee_shifts_raw.py
import pandas as pd
import numpy as np
from faker import Faker
import random
from datetime import datetime, timedelta, date
import os

fake = Faker('en_KE')
np.random.seed(45)
random.seed(45)

def load_hr_data():
    """Load HR data to get employee information"""
    try:
        hr_df = pd.read_csv('bronze/hr_raw.csv')
        
        # Convert date columns
        date_columns = ['hiredate', 'birthdate', 'termdate', 'extracted_date']
        for col in date_columns:
            if col in hr_df.columns:
                hr_df[col] = pd.to_datetime(hr_df[col], errors='coerce')
        
        print(f"Loaded {len(hr_df)} employees from HR data")
        
        # Get active employees (not terminated or termination in future)
        active_employees = hr_df[
            (hr_df['termdate'].isna()) | 
            (hr_df['termdate'] > pd.Timestamp('2025-12-31'))
        ]
        
        print(f"Active employees: {len(active_employees)}")
        
        # Filter for store employees (those with store assignments)
        store_employees = active_employees[active_employees['store_id'].notna()]
        print(f"Store employees (with store assignments): {len(store_employees)}")
        
        return store_employees
    
    except FileNotFoundError:
        print("ERROR: HR data not found. Please generate HR data first.")
        return pd.DataFrame()
    except Exception as e:
        print(f"ERROR loading HR data: {e}")
        return pd.DataFrame()

def generate_shift_schedule(employees_df, start_date='2023-01-01', end_date='2025-12-31'):
    """Generate shift schedule for employees"""
    
    print("\nGenerating employee shift schedule...")
    
    # Convert dates
    start_dt = datetime.strptime(start_date, '%Y-%m-%d')
    end_dt = datetime.strptime(end_date, '%Y-%m-%d')
    
    # Generate dates for the period
    date_range = pd.date_range(start=start_dt, end=end_dt, freq='D')
    
    # Shift types and their hours
    SHIFT_TYPES = {
        'Day': {'start': '07:00', 'end': '15:00', 'hours': 8},
        'Night': {'start': '15:00', 'end': '23:00', 'hours': 8},
        'Morning': {'start': '06:00', 'end': '14:00', 'hours': 8},
        'Evening': {'start': '14:00', 'end': '22:00', 'hours': 8},
        'Split': {'start': '10:00', 'end': '18:00', 'hours': 8},
        'Manager': {'start': '08:00', 'end': '17:00', 'hours': 9}
    }
    
    # Store operating patterns
    STORE_PATTERNS = {
        'Supermarket': {'shifts': ['Day', 'Night', 'Morning', 'Evening'], 'staff_per_shift': 3},
        'Mini-mart': {'shifts': ['Day', 'Night'], 'staff_per_shift': 2},
        'Express Store': {'shifts': ['Day', 'Evening'], 'staff_per_shift': 1},
        'Hypermarket': {'shifts': ['Day', 'Night', 'Morning', 'Evening', 'Split'], 'staff_per_shift': 5}
    }
    
    # Load store data
    try:
        stores_df = pd.read_csv('bronze/stores_raw.csv')
        print(f"Loaded {len(stores_df)} stores")
    except:
        print("Warning: Could not load store data. Using default patterns.")
        stores_df = pd.DataFrame()
    
    # Group employees by store
    employees_by_store = {}
    for store_id, store_group in employees_df.groupby('store_id'):
        employees_by_store[store_id] = store_group['employee_id'].tolist()
    
    print(f"Employees distributed across {len(employees_by_store)} stores")
    
    # Generate shift data
    shift_data = []
    shift_counter = 1
    
    # Generate shifts for each date
    for shift_date in date_range:
        date_str = shift_date.strftime('%Y-%m-%d')
        
        # Skip some days (holidays, store closures)
        if np.random.random() < 0.02:  # 2% chance of store closure
            continue
        
        # For each store with employees
        for store_id, employee_list in employees_by_store.items():
            if not employee_list:
                continue
            
            # Get store format if available
            store_format = 'Supermarket'  # Default
            if not stores_df.empty:
                store_info = stores_df[stores_df['store_id'] == store_id]
                if not store_info.empty:
                    store_format = store_info.iloc[0]['format']
            
            # Get shift pattern for this store format
            pattern = STORE_PATTERNS.get(store_format, STORE_PATTERNS['Supermarket'])
            shift_types = pattern['shifts']
            staff_per_shift = pattern['staff_per_shift']
            
            # Assign employees to shifts
            assigned_employees = []
            
            for shift_type in shift_types:
                # Skip some shifts randomly (not all shifts run every day)
                if np.random.random() < 0.1:  # 10% chance shift doesn't run
                    continue
                
                # Get shift details
                shift_details = SHIFT_TYPES.get(shift_type, SHIFT_TYPES['Day'])
                
                # Determine how many staff needed for this shift
                actual_staff_needed = max(1, int(staff_per_shift * np.random.uniform(0.7, 1.3)))
                
                # Select employees for this shift (avoid double booking)
                available_employees = [e for e in employee_list if e not in assigned_employees]
                
                if not available_employees:
                    continue
                
                # Select actual staff (could be fewer than needed)
                staff_to_assign = min(actual_staff_needed, len(available_employees))
                selected_employees = random.sample(available_employees, staff_to_assign)
                
                # Add to assigned list to prevent double booking
                assigned_employees.extend(selected_employees)
                
                # Create shift records for each employee
                for employee_id in selected_employees:
                    # Base hours
                    hours_worked = shift_details['hours']
                    
                    # Overtime probability (20% chance)
                    overtime_hours = 0
                    if np.random.random() < 0.2:
                        overtime_hours = np.random.randint(1, 4)
                    
                    shift_id = f"SHIFT-{shift_date.strftime('%Y%m%d')}-{store_id.replace('STR-', '')}-{shift_counter:04d}"
                    shift_counter += 1
                    
                    shift_data.append({
                        'shift_id': shift_id,
                        'employee_id': employee_id,
                        'store_id': store_id,
                        'shift_date': date_str,
                        'shift_type': shift_type,
                        'start_time': shift_details['start'],
                        'end_time': shift_details['end'],
                        'hours_worked': hours_worked,
                        'overtime_hours': overtime_hours,
                        'data_source': 'HR_Shift_System',
                        'extracted_date': datetime.now().strftime('%Y-%m-%d')
                    })
        
        # Progress reporting
        if len(shift_data) % 10000 == 0 and len(shift_data) > 0:
            print(f"  Generated {len(shift_data):,} shift records...")
    
    # Create DataFrame
    df = pd.DataFrame(shift_data)
    
    # Initialize data quality issue counts
    data_quality_issues = {
        'missing_employee': 0,
        'invalid_hours': 0,
        'duplicates': 0,
        'missing_type': 0,
        'invalid_date': 0
    }
    
    # Add data quality issues
    # 1. Missing employee IDs
    missing_employee_mask = np.random.random(len(df)) < 0.01
    df.loc[missing_employee_mask, 'employee_id'] = np.nan
    data_quality_issues['missing_employee'] = missing_employee_mask.sum()
    
    # 2. Invalid hours (negative or too high)
    invalid_hours_mask = np.random.random(len(df)) < 0.005
    df.loc[invalid_hours_mask, 'hours_worked'] = df.loc[invalid_hours_mask, 'hours_worked'] * -1
    data_quality_issues['invalid_hours'] = invalid_hours_mask.sum()
    
    # 3. Duplicate shifts
    duplicate_mask = np.random.random(len(df)) < 0.008
    duplicates = df[duplicate_mask].copy()
    duplicates['shift_id'] = duplicates['shift_id'] + '-DUP'
    df = pd.concat([df, duplicates], ignore_index=True)
    data_quality_issues['duplicates'] = len(duplicates)
    
    # 4. Missing shift types
    missing_type_mask = np.random.random(len(df)) < 0.003
    df.loc[missing_type_mask, 'shift_type'] = np.nan
    data_quality_issues['missing_type'] = missing_type_mask.sum()
    
    # 5. Invalid dates
    invalid_date_mask = np.random.random(len(df)) < 0.002
    df.loc[invalid_date_mask, 'shift_date'] = '2023-13-45'
    data_quality_issues['invalid_date'] = invalid_date_mask.sum()
    
    print(f"\nGenerated {len(df):,} shift records")
    print(f"Time period: {start_date} to {end_date}")
    print(f"Unique employees with shifts: {df['employee_id'].nunique()}")
    print(f"Unique stores with shifts: {df['store_id'].nunique()}")
    
    return df, data_quality_issues

def analyze_shifts(df, employees_df, data_quality_issues):
    """Analyze shift data"""
    
    print("\n" + "="*60)
    print("SHIFT SCHEDULE ANALYSIS")
    print("="*60)
    
    # Shift distribution by type
    print("\nShift Type Distribution:")
    shift_counts = df['shift_type'].value_counts()
    for shift_type, count in shift_counts.items():
        percentage = (count / len(df)) * 100
        print(f"  {shift_type}: {count:,} shifts ({percentage:.1f}%)")
    
    # Overtime analysis
    total_overtime = df['overtime_hours'].sum()
    print(f"\nTotal overtime hours: {total_overtime:,.0f}")
    print(f"Average overtime per shift: {df['overtime_hours'].mean():.2f} hours")
    
    # Employee workload analysis
    if employees_df is not None and not employees_df.empty:
        # Merge with employee data
        employee_shifts = df.groupby('employee_id').agg({
            'shift_id': 'count',
            'hours_worked': 'sum',
            'overtime_hours': 'sum'
        }).rename(columns={'shift_id': 'total_shifts'})
        
        print(f"\nEmployee Workload Summary:")
        print(f"  Average shifts per employee: {employee_shifts['total_shifts'].mean():.1f}")
        print(f"  Average hours per employee: {employee_shifts['hours_worked'].mean():.1f}")
        print(f"  Average overtime per employee: {employee_shifts['overtime_hours'].mean():.1f}")
        
        # Top 5 busiest employees
        print(f"\nTop 5 Busiest Employees (by shifts):")
        top_employees = employee_shifts.nlargest(5, 'total_shifts')
        for idx, (emp_id, row) in enumerate(top_employees.iterrows(), 1):
            print(f"  {idx}. {emp_id}: {row['total_shifts']} shifts, {row['hours_worked']:.0f} hours")
    
    # Data quality issues
    print(f"\nData Quality Issues:")
    print(f"  Missing employee IDs: {data_quality_issues['missing_employee']}")
    print(f"  Invalid hours: {data_quality_issues['invalid_hours']}")
    print(f"  Duplicate shifts: {data_quality_issues['duplicates']}")
    print(f"  Missing shift types: {data_quality_issues['missing_type']}")
    print(f"  Invalid dates: {data_quality_issues['invalid_date']}")

# Main execution
if __name__ == "__main__":
    os.makedirs('bronze', exist_ok=True)
    
    print("="*60)
    print("EMPLOYEE SHIFT SCHEDULE GENERATION")
    print("="*60)
    
    # Load HR data
    employees_df = load_hr_data()
    
    if employees_df.empty:
        print("\n" + "="*60)
        print("ERROR: Cannot generate shifts without HR data")
        print("="*60)
        print("\nACTION REQUIRED:")
        print("1. Run generate_hr_data.py first")
        print("2. Ensure HR data is generated successfully")
        print("3. Run bronze.load_bronze to load HR data")
        print("="*60)
        exit(1)
    
    # Generate shift schedule
    shifts_df, data_quality_issues = generate_shift_schedule(employees_df, '2023-01-01', '2025-12-31')
    
    # Analyze the data
    analyze_shifts(shifts_df, employees_df, data_quality_issues)
    
    # Save to CSV
    output_path = 'bronze/employee_shifts_raw.csv'
    shifts_df.to_csv(output_path, index=False)
    
    print(f"\n" + "="*60)
    print("SHIFT SCHEDULE GENERATION COMPLETE")
    print("="*60)
    print(f"File saved: {output_path}")
    print(f"File size: {os.path.getsize(output_path) / (1024*1024):.1f} MB")
    
    # Display sample data
    print("\nSample Shift Records:")
    sample_cols = ['shift_id', 'employee_id', 'store_id', 'shift_date', 'shift_type', 'hours_worked']
    sample = shifts_df.head(10)[sample_cols]
    for idx, row in sample.iterrows():
        print(f"  {row['shift_id']}: {row['employee_id']} at {row['store_id']} | {row['shift_date']} | {row['shift_type']} shift ({row['hours_worked']} hrs)")
    
    # Relationship verification
    print(f"\n" + "="*60)
    print("DATA RELATIONSHIP VERIFICATION")
    print("="*60)
    
    # Check HR-Shift relationship
    hr_employee_ids = set(employees_df['employee_id'].unique())
    shift_employee_ids = set(shifts_df['employee_id'].dropna().unique())
    
    matching_ids = shift_employee_ids.intersection(hr_employee_ids)
    non_matching_ids = shift_employee_ids - hr_employee_ids
    
    print(f"Shift records: {len(shifts_df):,}")
    print(f"Unique employees in shifts: {len(shift_employee_ids)}")
    print(f"Employees matching HR records: {len(matching_ids)} ({len(matching_ids)/len(shift_employee_ids)*100:.1f}%)")
    
    if non_matching_ids:
        print(f"Non-matching employee IDs: {len(non_matching_ids)}")
        if len(non_matching_ids) <= 3:
            print(f"  Examples: {list(non_matching_ids)[:3]}")
    
    # Store verification
    try:
        stores_df = pd.read_csv('bronze/stores_raw.csv')
        store_ids = set(stores_df['store_id'].unique())
        shift_store_ids = set(shifts_df['store_id'].dropna().unique())
        
        matching_stores = shift_store_ids.intersection(store_ids)
        print(f"\nStore verification:")
        print(f"  Stores in shifts: {len(shift_store_ids)}")
        print(f"  Stores matching store data: {len(matching_stores)} ({len(matching_stores)/len(shift_store_ids)*100:.1f}%)")
    except:
        print("\nNote: Could not verify store relationships (stores_raw.csv not found)")