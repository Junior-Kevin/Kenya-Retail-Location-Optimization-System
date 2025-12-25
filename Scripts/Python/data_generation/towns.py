# towns.py
import random

# Authoritative Kenya County → Town mapping
KENYA_COUNTY_TOWNS = {
    "Nairobi": ["CBD", "Westlands", "Kilimani", "Kasarani", "Embakasi", "Lang'ata", "Karen", "Runda", "Lavington", "Parklands"],
    "Mombasa": ["Mvita", "Nyali", "Bamburi", "Likoni", "Changamwe", "Kisauni", "Shanzu"],
    "Kisumu": ["Kisumu CBD", "Milimani", "Manyatta", "Nyamasaria", "Nyalenda", "Kondele"],
    "Nakuru": ["Nakuru CBD", "Naivasha", "Gilgil", "Molo", "Njoro", "Bahati"],
    "Kiambu": ["Thika", "Ruiru", "Juja", "Kiambu Town", "Githurai", "Limuru"],
    "Uasin Gishu": ["Eldoret CBD", "Turbo", "Burnt Forest", "Ziwa", "Moiben"],
    "Meru": ["Meru Town", "Nkubu", "Timau", "Maua", "Laare"],
    "Machakos": ["Machakos Town", "Athi River", "Kangundo", "Mwala", "Masinga"],
    "Kakamega": ["Kakamega Town", "Mumias", "Malava", "Butere", "Shinyalu"],
    "Bungoma": ["Bungoma Town", "Webuye", "Kimilili", "Chwele", "Sirisia"],
    "Kisii": ["Kisii Town", "Ogembo", "Suneka", "Mosocho"],
    "Nyamira": ["Nyamira Town", "Keroka", "Nyansiongo", "Rigoma"],
    "Nyandarua": ["Ol Kalou", "Engineer", "Njabini", "Kinangop"],
    "Nyeri": ["Nyeri Town", "Karatina", "Othaya", "Mathira"],
    "Kirinyaga": ["Kerugoya", "Kutus", "Sagana", "Wang'uru"],
    "Murang'a": ["Murang'a Town", "Kangema", "Maragua", "Gatanga"],
    "Laikipia": ["Nanyuki", "Nyahururu", "Rumuruti"],
    "Nandi": ["Kapsabet", "Mosoriot", "Lessos"],
    "Kericho": ["Kericho Town", "Litein", "Ainamoi"],
    "Bomet": ["Bomet Town", "Sotik", "Longisa"],
    "Kilifi": ["Kilifi Town", "Malindi", "Watamu", "Mariakani"],
    "Kwale": ["Kwale Town", "Ukunda", "Msambweni"],
    "Lamu": ["Lamu Town", "Mpeketoni"],
    "Taita Taveta": ["Voi", "Taveta", "Wundanyi"],
    "Garissa": ["Garissa Town", "Dadaab"],
    "Wajir": ["Wajir Town", "Habaswein"],
    "Mandera": ["Mandera Town", "El Wak"],
    "Marsabit": ["Marsabit Town", "Moyale"],
    "Isiolo": ["Isiolo Town", "Merti"],
    "Kitui": ["Kitui Town", "Mwingi", "Mutomo"],
    "Makueni": ["Wote", "Makindu", "Mtito Andei"],
    "Embu": ["Embu Town", "Runyenjes", "Siakago"],
    "Tharaka Nithi": ["Chuka", "Kathwana"],
    "Busia": ["Busia Town", "Malaba", "Nambale"],
    "Siaya": ["Siaya Town", "Bondo", "Ugunja"],
    "Homa Bay": ["Homa Bay Town", "Mbita", "Ndhiwa", "Oyugis"],
    "Migori": ["Migori Town", "Awendo", "Rongo"],
    "Vihiga": ["Mbale", "Luanda"],
    "Baringo": ["Kabarnet", "Eldama Ravine"],
    "Elgeyo Marakwet": ["Iten", "Chepkorio"],
    "Samburu": ["Maralal", "Baragoi"],
    "Trans Nzoia": ["Kitale", "Kiminini"],
    "Turkana": ["Lodwar", "Lokichoggio"],
    "West Pokot": ["Kapenguria", "Sigor"],
    "Narok": ["Narok Town", "Kilgoris"],
    "Kajiado": ["Kajiado Town", "Ngong", "Kitengela", "Ongata Rongai"],
    "Tana River": ["Hola Town", "Bura", "Garsen", "Madogo"]
}

KENYAN_COUNTIES = list(KENYA_COUNTY_TOWNS.keys())

def get_random_town(county):
    """Return a valid random town for the given county"""
    return random.choice(KENYA_COUNTY_TOWNS[county])

def get_weighted_town(county):
    """Bias selection toward first towns (major urban centers)"""
    towns = KENYA_COUNTY_TOWNS[county]
    weights = [3 if i < 2 else 1 for i in range(len(towns))]
    return random.choices(towns, weights=weights, k=1)[0]

# Retail location formats
RETAIL_LOCATION_TYPES = ['Supermarket', 'Mini-mart', 'Express Store', 'Hypermarket']