# Mappings for the data at the product level

mapper_user_columns = [
    'ds',
    'venture', 
    'salesorderid_mask', 
    'packageid_mask', 
    'buyer_mask',
    'userid_mask', 
    'business_type', 
    'fulfillment_create_date', 
    'delivery_date', 
    'is_return', 
    'paid_price', 
    'paid_price_usd', # unified amt
    'gmv_local', 
    'gmv_usd', 
    'promo_discount_local', 
    'promo_discount_usd',
    'shipping_discount_local', 
    'shipping_discount_usd',
    'shipping_amount_local', 
    'shipping_amount_usd', 
    'package_weight'
]

# for the connection between product and user data, use ['salesorderid_mask', 'buyer_mask', 'userid_mask'] as the key
mapper_product_columns = [
    'ds',
    'venture',
    'salesorderid_mask',
    'itemid_mask',
    'buyer_mask',
    'userid_mask',
    'skuid_mask',
    'product_name',
    'product_description',
    'url_external', 
    'url_lazada',
    'url_main_image',
    'avg_price',
    'stddev_price',
    'unit_price',
    'actual_gmv',
    'industry_name',
    'regional_category1_name',
    'regional_category2_name', 
    'live_date',
    'product_rating_avg_std',
    'rvw_cnt_std'
]

mapper_category1 = {
	'Electronics Parts & Accessories',
	'Beauty',
	'Home Appliances',
	'Groceries', 
    "Kids' Fashion",
	'Tools & Home Improvement',
	'Digital Goods',
	'Stationery, Craft & Gift Cards',
	'Kitchenware & Tableware',
	'Automotive',
	'Bedding & Bath',
	'Mother & Baby',
	'Lingerie, Sleep, Lounge & Thermal Wear',
	'Fashion Accessories',
	'Toys & Games',
	'Lighting & Décor',
	'Health',
    "Men's Clothing",
	'Digital Utilities',
	'Outdoor & Garden',
    "Men's Shoes",
	'Bags and Travel',
	"Women's Clothing",
	'Audio',
	'Cameras & Drones',
	'Mobiles & Tablets',
	'Pet Supplies',
	'Laundry & Cleaning Equipment',
	'Household Supplies',
	'Furniture & Organization',
	'Media, Music & Books',
	"Women's Shoes",
	'Sports & Outdoors Activities Equipment',
	'Computers & Components',
	'Sports Shoes and Clothing',
	'Services',
	'Printers & Scanners',
	'Data Storage',
	'Televisions & Videos',
	'Smart Devices',
	'Gaming Devices & Software',
	'Surprise Box',
	'Special Digital Products',
	'Service Product'
}

mapper_grocery_electronic_category = {
    'electronics': [
        'Electronics Parts & Accessories', 
        'Home Appliances', 
        'Cameras & Drones',
        'Laundry & Cleaning Equipment',
        'Mobiles & Tablets', 
        'Computers & Components', 
        'Printers & Scanners',
        'Automotive'
    ],
    'groceries': [
        'Groceries'
    ]
}

national_green_labels = {
	'Singapore': {
		'url': 'https://globalecolabelling.net/organisation/singapore-green-labelling-scheme/',
		'label': 'SEC',
		'authority': 'Singapore Environment Council'
	},
	'Malaysia': {
		'url': 'https://globalecolabelling.net/organisation/sirim-eco-labelling-scheme/',
		'label': 'SIRIM',
		'authority': 'SIRIM QAS'
	},
	'Indonesia': {
		'url': 'https://globalecolabelling.net/organisation/green-label-indonesia/',
		'label': 'GPC',
		'authority': 'Green Product Council'
	},
	'Phillipines': {
		'url': 'https://globalecolabelling.net/organisation/green-choice-philippines/',
		'label': 'NELP-GCP',
		'authority': 'The Philippine Center for Environmental Protection and Sustainable Development, Inc. (PCEPSDI)'
	},
	'Thailand': {
		'url': 'https://globalecolabelling.net/organisation/green-label-thailand/',
		'label': 'Green Label',
		'authority': 'Thailand Environment Institute Foundation (TEI)'
	},
	'Vietnam': {
		'url': 'https://mae.gov.vn/Pages/chitietvanbandh.aspx?ItemID=224',
		'label': 'NSTVN',
		'authority': 'Vietnam’s Ministry of Natural Resources and Environment (MONRE)'
	}
}

organic_labels = {
	'EU Organic Certified': {
		'name': 'EU Organic Certification',
		'origin': 'EU',
		'label': ['USDA Organic', 'EU Organic', 'IFOAM: Health', 'IFOAM: Ecology', 'IFOAM: Fairness', 'IFOAM: Care'],
		'keywords': ['[EU|European] Organic Standard', '[EU|European] Organic Certifi[ed|cate|cation]', '[EU|European] Organic [Mark|Label]']
	},
	'USDA': {
		'name': 'USDA Organic Certification',
		'origin': 'US',
		'label': ['USDA Organic', 'EU Organic', 'IFOAM: Health', 'IFOAM: Ecology', 'IFOAM: Fairness', 'IFOAM: Care'],
		'keywords': ['USDA Organic Certified', 'USDA Organic', 'USDA Organic Standard', 'NOP']
	},
	'OTOP Certified': {
		'name': 'One Tambon One Product',
		'origin': 'Thailand',
		'label': ['IFOAM:Health', 'IFOAM: Fairness'],
		'keywords': ['OTOP Certified', 'OTOP', 'OTOP Standard']
	},
	'Farm Fresh': {
		'name': 'Farm Fresh',
		'origin': 'Malaysia',
		'label': ['IFOAM:Health', 'IFOAM: Fairness'],
		'keywords': ['Farm Fresh', 'Farm Fresh Certified', 'Farm Fresh Standard']
	},
	'Thailand Organic Standards': {
		'name': 'Organic Thailand Agriculture Standard (TAS 9001-2552)',
		'origin': 'Thailand',
		'label': ['USDA Organic', 'EU Organic', 'IFOAM: Health', 'IFOAM: Ecology', 'IFOAM: Fairness', 'IFOAM: Care'],
		'keywords': ['Thailand Organic Standards', 'Thailand Organic Standard', 'TAS 9001-2552']
	},
	'Malaysia Halal Certification': {
		'name': 'Malaysia Halal Certification by JAKIM', 
		'origin': 'Malaysia',
		'label': ['IFOAM: Health', 'IFOAM: Fairness'],
		'keywords': ['Halal Certification', 'Halal Certified', 'Halal Standard', 'JAKIM', 'HQC']
	},
	'BRC': {
		'name': 'Brand Reputation Compliance Global Standards, BRCGS', 
		'origin': 'UK',
		'label': ['IFOAM: Health'],
		'keywords': ['BRC Standard', 'BRC Certified', 'BRCGS']
	},
	'HACCP Certified': {
		'name': 'Hazard Analysis and Critical Control Points', 
		'origin': 'US',
		'label': ['IFOAM: Health'],
		'keywords': ['HACCP Certified', 'HACCP', 'HACCP Standard']
	},
	'Healthier Choice Symbol': {
		'name': 'Healthier Choice Symbol (HCS)',
		'origin': 'Singapore',
		'label': ['IFOAM: Health'],
		'keywords': ['Healthier Choice Symbol', 'Health Choice Symbol', 'Healthier Choice Symbol Standard']
	},
	'BPOM Certified': {
		'name': 'Badan Pengawas Obat dan Makanan Certified',
		'origin': 'Indonesia',
		'label': ['IFOAM: Health'],
		'keywords': ['BPOM Certified', 'BPOM', 'BPOM Standard']
	},
	'NSF Certified': {
		'name': 'NSF Certified',
		'origin': 'US',
		'label': ['IFOAM: Health'],
		'keywords': ['NSF Certified', 'NSF', 'NSF Standard']
	},
	'FDA Certified': {
		'name': 'US Food and Drug Administration Certified',
		'origin': 'US',
		'label': ['IFOAM: Health'],
		'keywords': ['FDA Certified', 'FDA', 'FDA Standard', 'Food and Drug Administration', 'FDA Approved']
	},
	'HFAC': {
		'name': 'Humane Farm Animal Care',
		'origin': 'US',
		'label': ['USDA Organic', 'IFOAM: Health', 'IFOAM: Ecology'],
		'keywords': ['HFAC Certified', 'HFAC', 'HFAC Standard']
	},
	'Heart Healthy': {
		'name': 'Heart-Healthy Food certification',
		'origin': 'Thailand',
		'label': ['IFOAM: Health'],
		'keywords': ['Heart Healthy', 'Heart Healthy Certified', 'Heart Healthy Standard']
	},
	'Halal MUI Certified': {
		'name': 'Halal Certified by the Majelis Ulama Indonesia',
		'origin': 'Indonesia',
		'label': ['IFOAM: Fairness'],
		'keywords': ['Halal MUI Certified', 'Halal MUI', 'Halal MUI Standard', 'MUI']
	},
	'MESTI': {
		'name': 'MeSTI by KKM’s Food Safety and Quality Division',
		'origin': 'Malaysia',
		'label': ['IFOAM: Health'],
		'keywords': ['MESTI Certified', 'MESTI', 'MESTI Standard', 'MeSTI']
	},
	'KKM Organic': {
		'name': 'Organik KKM Malaysia certified',
		'origin': 'Malaysia',
		'label': ['IFOAM: Health', 'IFOAM: Ecology', 'IFOAM: Fairness', 'IFOAM: Care'],
		'keywords': ['KKM Organic Certified', 'KKM Organic', 'KKM Organic Standard', 'KKM', 'Organik KKM']
	},
	'GHP': {
		'name': 'Good Hygiene Practices',
		'origin': 'International',
		'label': ['IFOAM: Health'],
		'keywords': ['GHP Certified', 'GHP', 'GHP Standard']
	},
	'P-IRT': {
		'name': 'an Indonesian food safety and distribution permit for home‑scale or small food industries (Pangan Industri Rumah Tangga)',
		'origin': 'Indonesia',
		'label': ['IFOAM: Health', 'IFOAM: Fairness'],
		'keywords': ['P-IRT Certified', 'P-IRT', 'P-IRT Standard', 'Pangan Industri Rumah Tangga', 'PIRT']
	},
	'Kosher Certified': {
		'name': 'Kosher Certified by a recognized Jewish rabbinic authority',
		'origin': 'Non-specified',
		'label': ['IFOAM: Fairness'],
		'keywords': ['Kosher Certified', 'Kosher', 'Kosher Standard']
	},
	'Non-GMO Project Verified': {
		'name': 'Non-GMO Project Verified mark',
		'origin': 'US,Canada',
		'label': ['IFOAM: Health', 'IFOAM: Ecology'],
		'keywords': ['Non-GMO Verified', 'Non-GMO Project Verified', 'Non-GMO Project Standard', 'Non-GMO']
	},
	'CGMP': {
		'name': 'Current Good Manufacturing Practice',
		'origin': 'US',
		'label': ['IFOAM: Health'],
		'keywords': ['CGMP Certified', 'CGMP', 'CGMP Standard']
	},
	'RI': {
		'name': 'Republik Indonesia',
		'origin': 'Indonesia',
		'label': ['IFOAM: Fairness'],
		'keywords': ['RI Certified', 'RI', 'RI Standard', 'Republik Indonesia']
	},
	'NKV': {
		'name': 'Nomor Kontrol Veteriner',
		'origin': 'Indonesia',
		'label': ['IFOAM: Health'],
		'keywords': ['NKV Certified', 'NKV', 'NKV Standard', 'Nomor Kontrol Veteriner']
	},
	'SNI': {
		'name': 'Standar Nasional Indonesia',
		'origin': 'Indonesia',
		'label': ['IFOAM: Fairness'],
		'keywords': ['SNI Certified', 'SNI', 'SNI Standard', 'Standar Nasional Indonesia']
	},
	'ISO 22000': {
		'name': 'Food Safety Management System (FSMS)',
		'origin': 'International',
		'label': ['IFOAM: Health'],
		'keywords': ['ISO 22000 Certified', 'ISO 22000', 'ISO 22000 Standard', 'Food Safety Management System']
	},
	'Rainforest Alliance Certified': {
		'name': 'Rainforest Alliance Certified',
		'origin': 'US',
		'label': ['IFOAM: Health', 'IFOAM: Ecology', 'IFOAM: Fairness', 'IFOAM: Care'],
		'keywords': ['Rainforest Alliance Certified', 'Rainforest Alliance', 'Rainforest Alliance Standard']
	},
	'Fair Trade': {
		'name': 'Fair Trade Certification',
		'origin': 'US',
		'label': ['IFOAM: Health', 'IFOAM: Fairness'],
		'keywords': ['Fair Trade Certified', 'Fair Trade', 'Fair Trade Standard', 'Fair Trade Mark']
	},
	'GAP': {
		'name': 'Good Agricultural Practices',
		'origin': 'US',
		'label': ['USDA Organic', 'IFOAM: Health', 'IFOAM: Ecology', 'IFOAM: Care'],
		'keywords': ['GAP Certified', 'GAP', 'GAP Standard', 'Good Agricultural Practices']
	},
	'JAS': {
		'name': 'Japan Agricultural Standards',
		'origin': 'Japan',
		'label': ['IFOAM: Health', 'IFOAM: Ecology', 'IFOAM: Fairness', 'IFOAM: Care'],
		'keywords': ['JAS Certified', 'JAS', 'JAS Standard', 'Japan Agricultural Standards']
	},
	'EFSA': {  # from Qwen-Max
		'name': 'European Food Safety Authority',
		'origin': 'EU',
		'label': ['IFOAM: Health'],
		'keywords': ['EFSA Certified', 'EFSA', 'EFSA Standard', 'European Food Safety Authority']
	},
	'FSSC': {  # from Qwen-Max
		'name': 'Food Safety System Certification',
		'origin': 'EU',
		'label': ['IFOAM: Health'],
		'keywords': ['FSSC Certified', 'FSSC', 'FSSC Standard', 'Food Safety System Certification', 'FSSC 22000']
	}, 
	'SFA': {  # from Qwen-Max
		'name': 'Singapore Food Agency',
		'origin': 'Singapore',
		'label': ['IFOAM: Health'],
		'keywords': ['SFA Certified', 'SFA', 'SFA Standard', 'Singapore Food Agency']
	}
}

energy_labels = {
	'TISI':{
		'name': 'Thailand Industrial Standards Institute',
		'origin': 'Thailand',
		'label': ['Energy Efficiency', 'Safety', 'Enviornmental Protection'],
		'keywords': ['TISI', 'TISI Certified', 'TISI Standard', 'Thailand Industrial Standards Institute']
	},
	'SIRIM':{
		'name': 'SIRIM QAS',
		'origin': 'Malaysia',
		'label': ['Energy Efficiency', 'Safety'],
		'keywords': ['SIRIM', 'SIRIM Certified', 'SIRIM Standard', 'SIRIM QAS']
	},
	'SGS MIL Standard Certified':{
		'name': 'SGS MIL Standard Certified',
		'origin': 'International',
		'label': ['Durability/Reliability', 'Safety'],
		'keywords': ['SGS MIL', 'SGS MIL Certified', 'SGS MIL Standard', 'MIL-STD-810']
	},
	'RoHS':{
		'name': 'Restriction of Hazardous Substances Directive',
		'origin': 'EU',
		'label': ['Environmental Protection', 'Reduced Hazardous'],
		'keywords': ['RoHS', 'RoHS Compliant', 'RoHS EIA/TIA', 'RoHS Standard', 'Restriction of Hazardous Substances Directive', 'Certification: RoHS']
	},
	'WEEE':{
		'name': 'Waste Electrical and Electronic Equipment Directive',
		'origin': 'European Union',
		'label': ['Environmental Protection', 'Recyclable Material'],
		'keywords': ['WEEE', 'WEEE Directive', 'Waste Electrical and Electronic Equipment Directive', 'Certification: WEEE']
	},
	'Energy Efficiency Label':{
		'name': 'Energy Efficiency Label (5 Grades)',
		'origin': 'Thailand,Malaysia',
		'label': ['Energy Efficiency'],
		'keywords': ['Energy Efficiency Label', 'Energy Efficiency Class', '5-star energy efficiency', 'Energy Efficiency Rating', 'energy-saving 5-star', ]
	},
	'EPEAT':{
		'name': 'Electronic Product Environmental Assessment Tool',
		'origin': 'US',
		'label': ['Environmental Protection', 'Energy Efficiency'],
		'keywords': ['EPEAT', 'EPEAT Registered', 'EPEAT Certified', 'Certification: EPEAT']
	},
	'UKCA Mark':{
		'name': 'UK Conformity Assessed Mark',
		'origin': 'UK',
		'label': ['Environmental Protection', 'Reduced Hazardous', 'Safety'],
		'keywords': ['UKCA', 'UK Conformity Assessed', 'UKCA Mark', 'UKCA Certified', 'Certification: UKCA']
	},
	'CE Mark':{
		'name': 'Conformité Européenne Mark',
		'origin': 'EU',
		'label': ['Environmental Protection', 'Reduced Hazardous', 'Safety'],
		'keywords': ['CE Marked', 'CE Mark', 'CE Certified', 'Conformité Européenne', 'CE Standard', 'Certification: CE', 'CE']
	},
	'E-mark':{
		'name': 'European E-mark compliance with UNECE',
		'origin': 'EU',
		'label': ['Environmental Protection', 'Safety'],
		'keywords': ['European E-mark', 'E-Mark', 'E-mark UNECE', 'Certification: E-mark']
	},
	'MSDS':{
		'name': 'Material Safety Data Sheet',
		'origin': 'International',
		'label': ['Environmental Protection', 'Reduced Hazardous'],
		'keywords': ['MSDS', 'Material Safety Data Sheet', 'Certification: MSDS']
	},
	'ISO 14001':{
		'name': 'ISO 14001 Environmental Management System',
		'origin': 'International',
		'label': ['Environmental Management', 'Reduced Hazardous'],
		'keywords': ['ISO 14001', 'ISO14001', 'ISO-14001']
	},
	'NSF/ANSI':{
		'name': 'NSF/ANSI Standards',
		'origin': 'US',
		'label': ['Safety', 'Reduced Hazardous'],
		'keywords': ['NSF/ANSI', 'NSF', 'NSF/ANSI Standard', 'Certification: NSF']
	},
	'Energy Star':{
		'name': 'ENERGY STAR Energy Efficiency Certification',
		'origin': 'US',
		'label': ['Energy Efficiency', 'Environmental Protection'],
		'keywords': ['Energy Star', 'ENERGY STAR', 'ENERGY STAR Certified', 'Energy Star Label', 'Energy Star Standard', 'SEER']
	},
	'ISO/TS 16949':{
		'name': 'ISO/TS 16949 Automotive Quality Management System (replaced by IATF 16949)',
		'origin': 'International',
		'label': ['Durability/Reliability'],
		'keywords': ['ISO/TS 16949', '16949 Automotive QMS', 'IATF 16949']
	},
	'WQA':{
		'name': 'Water Quality Association Certification',
		'origin': 'US',
		'label': ['Environmental Protection', 'Safety'],
		'keywords': ['WQA', 'WQA Certified']
	},
 	'ISO 9001':{  # reliability-focused standard
		'name': 'ISO 9001 Quality Management System',
		'origin': 'International',
		'label': ['Durability/Reliability'],
		'keywords': ['ISO 9001', 'ISO9001', 'ISO-9001']
	}
}

safe_labels = {
	'GB/T 18268.1-2010': 'Electrical equipment for measurement, control and laboratory use - EMC requirements',
 	'GB 4706.18': 'Safety of household and similar electrical appliances - Part 18: Particular requirements for battery chargers',
	'IEC 60335-2-21': 'Household and similar electrical appliances - Safety - Part 2-21: Particular requirements for storage water heaters',
	'ISO 45001': 'Occupational health and safety management systems - Requirements with guidance for use'
}
