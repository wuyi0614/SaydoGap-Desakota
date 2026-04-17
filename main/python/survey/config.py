# The configuration module for the survey data
# 

capital_cities = [
    "Jakarta Raya",
    "Kuala Lumpur",
    "Metropolitan Manila",
    "Singapore",
    "Bangkok Metropolis",
    "Hà Nội",
]

tier1_cities = [
    "Jakarta Raya",
    "Kuala Lumpur",
    "Metropolitan Manila",
    "Singapore",
    "Bangkok Metropolis",
    "Hồ Chí Minh",
    "Bogor",
    "Selangor",
    "Nonthaburi",
    "Hà Nội",
    "Depok",
    "Putrajaya",
    "Samut Prakan",
    "Tangerang",
    "Pathum Thani",
    "Bekasi",
    "Samut Sakhon",
    "Bandung",
    "Nakhon Pathom",
    "Surabaya"
]

# the rate: 1 USD = [?] Currency
# currency_exchange_rate = [
#   {"source": "USD", "target": "IDR", "value": 16600, "country": "Indonesia"},
#   {"source": "USD", "target": "MYR", "value": 4.2235, "country": "Malaysia"},
#   {"source": "USD", "target": "PHP", "value": 58.2, "country": "Philippines"},
#   {"source": "USD", "target": "SGD", "value": 1.2898, "country": "Singapore"},
#   {"source": "USD", "target": "THB", "value": 32.5, "country": "Thailand"},
#   {"source": "USD", "target": "VND", "value": 26360, "country": "Vietnam"}
# ]

currency_exchange_rate2 = {
    "Indonesia": 16600,
    "Malaysia": 4.2235,
    "Philippines": 58.2,
    "Singapore": 1.2898,
    "Thailand": 32.5,
    "Vietnam": 26360
}

mapper_currency = [
	{"source": "Rp 2,500,000 - Rp 3,499,999", "src_currency": "IDR", "country": "Indonesia", "target": [151, 211], "tar_currency": "USD"},
	{"source": "Less than Rp 1,400,000", "src_currency": "IDR", "country": "Indonesia", "target": [0, 84], "tar_currency": "USD"},
	{"source": "Rp 3,500,000 - Rp 4,999,999", "src_currency": "IDR", "country": "Indonesia", "target": [211, 301], "tar_currency": "USD"},
	{"source": "Rp 5,000,000 - Rp 6,999,999", "src_currency": "IDR", "country": "Indonesia", "target": [301, 422], "tar_currency": "USD"},
	{"source": "Rp 9,000,000 - Rp 9,999,999", "src_currency": "IDR", "country": "Indonesia", "target": [542, 602], "tar_currency": "USD"},
	{"source": "Don't know/ Not sure", "src_currency": None, "country": None, "target": None, "tar_currency": "USD"},
	{"source": "Rp 1,400,000 - Rp 2,499,999", "src_currency": "IDR", "country": "Indonesia", "target": [84, 151], "tar_currency": "USD"},
	{"source": "Prefer not to answer", "src_currency": None, "country": None, "target": None, "tar_currency": "USD"},
	{"source": "Rp 15,000,000 and above", "src_currency": "IDR", "country": "Indonesia", "target": [904, None], "tar_currency": "USD"},
	{"source": "Rp 7,000,000 - Rp 8,999,999", "src_currency": "IDR", "country": "Indonesia", "target": [422, 542], "tar_currency": "USD"},
	{"source": "Rp 10,000,000 - Rp 14,999,999", "src_currency": "IDR", "country": "Indonesia", "target": [602, 904], "tar_currency": "USD"},
	{"source": "Less than RM 3,000", "src_currency": "MYR", "country": "Malaysia", "target": [0, 710], "tar_currency": "USD"},
	{"source": "RM 4,000 - RM 4,999", "src_currency": "MYR", "country": "Malaysia", "target": [947, 1184], "tar_currency": "USD"},
	{"source": "RM 3,000 - RM 3,999", "src_currency": "MYR", "country": "Malaysia", "target": [710, 947], "tar_currency": "USD"},
	{"source": "RM 7,000 - RM 7,999", "src_currency": "MYR", "country": "Malaysia", "target": [1657, 1894], "tar_currency": "USD"},
	{"source": "RM 8,000 - RM 8,999", "src_currency": "MYR", "country": "Malaysia", "target": [1894, 2131], "tar_currency": "USD"},
	{"source": "RM 5,000 - RM 5,999", "src_currency": "MYR", "country": "Malaysia", "target": [1184, 1420], "tar_currency": "USD"},
	{"source": "RM 6,000 - RM 6,999", "src_currency": "MYR", "country": "Malaysia", "target": [1421, 1657], "tar_currency": "USD"},
	{"source": "RM 10,000 - 10,999", "src_currency": "MYR", "country": "Malaysia", "target": [2368, 2604], "tar_currency": "USD"},
	{"source": "RM 12,000 or above", "src_currency": "MYR", "country": "Malaysia", "target": [2841, None], "tar_currency": "USD"},
	{"source": "RM 11,000 - 11,999", "src_currency": "MYR", "country": "Malaysia", "target": [2604, 2841], "tar_currency": "USD"},
	{"source": "RM 9,000 - RM 9,999", "src_currency": "MYR", "country": "Malaysia", "target": [2131, 2367], "tar_currency": "USD"},
	{"source": "PHP 125,000 - PHP 149,999", "src_currency": "PHP", "country": "Philippines", "target": [2148, 2577], "tar_currency": "USD"},
	{"source": "PHP 8,000 - PHP 29,999", "src_currency": "PHP", "country": "Philippines", "target": [137, 515], "tar_currency": "USD"},
	{"source": "Below PHP 8,000", "src_currency": "PHP", "country": "Philippines", "target": [0, 137], "tar_currency": "USD"},
	{"source": "PHP 30,000 - PHP 49,999", "src_currency": "PHP", "country": "Philippines", "target": [515, 859], "tar_currency": "USD"},
	{"source": "PHP 70,000 - PHP 99,999", "src_currency": "PHP", "country": "Philippines", "target": [1203, 1718], "tar_currency": "USD"},
	{"source": "PHP 100,000 - PHP 124,999", "src_currency": "PHP", "country": "Philippines", "target": [1718, 2148], "tar_currency": "USD"},
	{"source": "PHP 50,000 - PHP 69,999", "src_currency": "PHP", "country": "Philippines", "target": [859, 1203], "tar_currency": "USD"},
	{"source": "PHP 250,000 and above", "src_currency": "PHP", "country": "Philippines", "target": [4296, None], "tar_currency": "USD"},
	{"source": "PHP 175,000 - PHP 199,999", "src_currency": "PHP", "country": "Philippines", "target": [3007, 3436], "tar_currency": "USD"},
	{"source": "PHP 200,000 - PHP 224,999", "src_currency": "PHP", "country": "Philippines", "target": [3436, 3866], "tar_currency": "USD"},
	{"source": "PHP 225,000 - PHP 249,999", "src_currency": "PHP", "country": "Philippines", "target": [3866, 4296], "tar_currency": "USD"},
	{"source": "PHP 150,000 - PHP 174,999", "src_currency": "PHP", "country": "Philippines", "target": [2577, 3007], "tar_currency": "USD"},
	{"source": "SGD 15,000 or above", "src_currency": "SGD", "country": "Singapore", "target": [11630, None], "tar_currency": "USD"},
	{"source": "Below SGD 3,000", "src_currency": "SGD", "country": "Singapore", "target": [0, 2326], "tar_currency": "USD"},
	{"source": "SGD 10,500 - SGD 11,999", "src_currency": "SGD", "country": "Singapore", "target": [8141, 9303], "tar_currency": "USD"},
	{"source": "SGD 6,000 - SGD 7,499", "src_currency": "SGD", "country": "Singapore", "target": [4652, 5814], "tar_currency": "USD"},
	{"source": "SGD 4,500 - SGD 5,999", "src_currency": "SGD", "country": "Singapore", "target": [3489, 4651], "tar_currency": "USD"},
	{"source": "SGD 3,000 - SGD 4,499", "src_currency": "SGD", "country": "Singapore", "target": [2326, 3488], "tar_currency": "USD"},
	{"source": "SGD 7,500 - SGD 8,999", "src_currency": "SGD", "country": "Singapore", "target": [5815, 6977], "tar_currency": "USD"},
	{"source": "SGD 9,000 - SGD 10,499", "src_currency": "SGD", "country": "Singapore", "target": [6978, 8140], "tar_currency": "USD"},
	{"source": "SGD 12,000 - SGD 13,499", "src_currency": "SGD", "country": "Singapore", "target": [9304, 10466], "tar_currency": "USD"},
	{"source": "SGD 13,500 - SGD 14,999", "src_currency": "SGD", "country": "Singapore", "target": [10467, 11629], "tar_currency": "USD"},
	{"source": "25,001 - 40,000 THB", "src_currency": "THB", "country": "Thailand", "target": [769, 1231], "tar_currency": "USD"},
	{"source": "15,000 - 25,000 THB", "src_currency": "THB", "country": "Thailand", "target": [462, 769], "tar_currency": "USD"},
	{"source": "Less than 15,000 THB", "src_currency": "THB", "country": "Thailand", "target": [0, 462], "tar_currency": "USD"},
	{"source": "40,001 - 50,000 THB", "src_currency": "THB", "country": "Thailand", "target": [1231, 1538], "tar_currency": "USD"},
	{"source": "125,001 - 175,000 THB", "src_currency": "THB", "country": "Thailand", "target": [3846, 5385], "tar_currency": "USD"},
	{"source": "75,001 - 125,000 THB", "src_currency": "THB", "country": "Thailand", "target": [2308, 3846], "tar_currency": "USD"},
	{"source": "50,001 - 75,000 THB", "src_currency": "THB", "country": "Thailand", "target": [1538, 2308], "tar_currency": "USD"},
	{"source": "175,001 - 250,000 THB", "src_currency": "THB", "country": "Thailand", "target": [5385, 7692], "tar_currency": "USD"},
	{"source": "300,001 THB or above", "src_currency": "THB", "country": "Thailand", "target": [9231, None], "tar_currency": "USD"},
	{"source": "250,001 - 300,000 THB", "src_currency": "THB", "country": "Thailand", "target": [7692, 9231], "tar_currency": "USD"},
	{"source": "4,999,999 VND or below", "src_currency": "VND", "country": "Vietnam", "target": [0, 190], "tar_currency": "USD"},
	{"source": "50,000,001 - 60,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [1897, 2276], "tar_currency": "USD"},
	{"source": "10,000,001 - 20,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [379, 759], "tar_currency": "USD"},
	{"source": "30,000,001 - 40,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [1138, 1517], "tar_currency": "USD"},
	{"source": "5,000,000 - 10,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [190, 379], "tar_currency": "USD"},
	{"source": "20,000,001 - 30,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [759, 1138], "tar_currency": "USD"},
	{"source": "200,000,001 VND or above", "src_currency": "VND", "country": "Vietnam", "target": [7587, None], "tar_currency": "USD"},
	{"source": "40,000,001 - 50,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [1517, 1897], "tar_currency": "USD"},
	{"source": "100,000,001 - 150,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [3794, 5690], "tar_currency": "USD"},
	{"source": "60,000,001 - 70,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [2276, 2656], "tar_currency": "USD"},
	{"source": "90,000,001 - 100,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [3414, 3794], "tar_currency": "USD"},
	{"source": "70,000,001 - 80,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [2656, 3035], "tar_currency": "USD"},
	{"source": "80,000,001 - 90,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [3035, 3414], "tar_currency": "USD"},
	{"source": "150,000,001 - 200,000,000 VND", "src_currency": "VND", "country": "Vietnam", "target": [5690, 7587], "tar_currency": "USD"}
]

mapper_age = {
    "16-17 years": [16, 17, 16.5],
    "18-24 years": [18, 24, 21],
    "25-29 years": [25, 29, 27],
    "30-34 years": [30, 34, 32],
    "35-39 years": [35, 39, 37],
    "40 - 44 years": [40, 44, 42],
    "45 - 49 years": [45, 49, 47],
    "50 - 54 years": [50, 54, 52],
    "55 - 59 years": [55, 57, 56],
    "60 years and above": [60, None, 60],
    "Below 16 years": [None, 16, 16]
}

mapper_education = {
    'No formal education': 0, 
    'Primary education (Elementary school)': 0,
    'Secondary education (High school)': 1,
    'Vocational or technical training': 1, 
    'Associate degree': 1,
    'Bachelor’s degree': 2,
    'Master’s degree': 2,
    'Doctorate or professional degree (e.g., Ph.D., MD, JD)': 2,
}

gap_columns = [
    'gapGreenDelivery',
    'gapGreenElectronic',
    'gapGreenGrocery',
    'gapGreenWalk'
]
