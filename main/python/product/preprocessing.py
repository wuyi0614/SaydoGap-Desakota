# This module loads and modifies the product dataset
# 
# Created at 23/10/2025
# 

import warnings
warnings.filterwarnings("ignore")
import pandas as pd
from pathlib import Path


def get_product_raw() -> pd.DataFrame:
    """[Dataset] Return the original product data."""
    import pandas as pd
    from pathlib import Path
    
    filepath = Path("data") / "replication_classification" / "sample-orderitem.xlsx"
    df = pd.read_excel(filepath)
    return df


def get_product_translated() -> pd.DataFrame:
    """[Dataset] Return the translated product data."""
    from tqdm import tqdm
    from prompter.base import read_from_jsonl
    
    fspath = Path('data') / 'replication_classification' / 'sample-orderitem-tranlsated.csv'
    if fspath.exists():
        return pd.read_csv(fspath)
    
    f = Path('data') / 'replication_classification' / 'sample-orderitem-tranlsated.jsonl'
    ts = next(read_from_jsonl(f))
    # note: a few operations to ensure a final version of translated products
    # 1. move from original product names & descriptions to the NaNs in translated fields
    ts.loc[ts.product_name.isna(), 'product_name'] = ts.loc[ts.product_name.isna(), 'original_name']
    ts.loc[ts.product_description.isna(), 'product_description'] = ts.loc[ts.product_description.isna(), 'original_description']
    # 2. for itemids that have multiple unique skuids, use the non-na product name as the product name
    itemid_counts = ts.groupby('itemid_mask')['skuid_mask'].nunique()
    multi_sku_itemids = itemid_counts[itemid_counts > 1].index
    subset = ts.loc[ts.itemid_mask.isin(multi_sku_itemids)]
    count_name, count_description = 0, 0  # 1,706 names; 595 descriptions
    for itemid in tqdm(multi_sku_itemids, total=len(multi_sku_itemids), desc="Processing itemids with multiple skuids"):
        group = subset.loc[subset.itemid_mask == itemid]
        # 2.1 for product names
        missing = group.loc[group.product_name.str.startswith('Missing')]
        if not missing.empty and len(missing) < len(group):
            notna = group.loc[~group.product_name.str.startswith('Missing')]
            ts.loc[missing.index, 'product_name'] = notna.product_name.tolist()[0]
            count_name += 1
        
        # 2.2 for product descriptions
        missing = group.loc[group.product_description.str.startswith('Missing')]
        if not missing.empty and len(missing) < len(group):
            notna = group.loc[~group.product_description.str.startswith('Missing')]
            ts.loc[missing.index, 'product_description'] = notna.product_description.tolist()[0]
            count_description += 1
    
    # the final statisitics
    mask1 = ts.product_name.str.startswith('Missing') | ts.product_description.str.startswith('Missing')
    mask2 = ts.product_name.str.startswith('Fail') | ts.product_description.str.startswith('Fail')
    final = ts.loc[~mask1 | ~mask2]
    print(f"Total {len(ts) - len(final)} products are missing in the product name or product description")
    final.to_csv(fspath, index=False, encoding='utf-8')
    return final


def get_product_prepared() -> pd.DataFrame:
    """[Dataset] Return the well-prepared product data."""
    from main.python.product.preprocessing import get_product_raw, get_product_translated
    
    # obtain the translated product data & merging with the original product data
    prod_translated = get_product_translated()
    prod = get_product_raw()
    prod.drop(columns=['product_name', 'product_description'], inplace=True)
    prod = prod.merge(prod_translated[['skuid_mask', 'product_name', 'product_description']].drop_duplicates(),
                      on='skuid_mask', how='left')
    prod.loc[prod.product_name.isna(), 'product_name'] = 'Missing product name'
    prod.loc[prod.product_description.isna(), 'product_description'] = 'Missing product description'
    # skip those with 'Missing' and 'Failed' both in the product name and product description
    mask = prod.product_name.str.startswith('Missing') & prod.product_description.str.startswith('Missing')
    notna = prod.loc[~mask]
    return notna


def get_product_classified() -> pd.DataFrame:
    """[Dataset] Return the classified product data. 
    The table should at least have the following columns:
    - salesorderid_mask (for usercart merging)
    - itemid_mask
    - is_green (derived from 'is_green_grocery' and 'is_green_electronics')
    """
    from pathlib import Path
    from main.python.product.preprocessing import get_product_prepared
    
    # classified product data are separated into two files:
    f1 = Path('data') / 'replication_classification' / 'sample-electronics-classification.csv'
    f2 = Path('data') / 'replication_classification' / 'sample-groceries-classification.csv'
    d1 = pd.read_csv(f1)
    d2 = pd.read_csv(f2)
    d = pd.concat([d1, d2])
    prod = get_product_prepared()
    prod = prod.merge(d, on=['itemid_mask', 'salesorderid_mask'], how='left')
    return prod


def get_usercart() -> pd.DataFrame:
    import pandas as pd
    from pathlib import Path
    
    filepath = Path("data") / "replication_classification" /  "sample-usercart.csv"
    df = pd.read_csv(filepath)
    return df


def get_usercart_crossby_survey() -> tuple[pd.DataFrame, pd.DataFrame]:
    import pandas as pd
    from pathlib import Path
    from main.python.survey.preprocessing import get_survey_prepared
    from main.python.product.preprocessing import get_usercart
    
    # stick to user `id` in survey as the primary key for merging
    survey = get_survey_prepared()
    mappingfile = Path("data") / "replication_classification" / "sample-userorder-mapping.xlsx"
    mapping = pd.read_excel(mappingfile)
    mapping = mapping.rename(columns={"Peusdo_ID": "id", "Buyer_mask": "buyer_mask"})
    survey = survey.merge(mapping, on="id", how="left")
    user = get_usercart()
    user = user.loc[user.buyer_mask.isin(survey.buyer_mask)]
    return survey, user


def get_transaction_aggregated(sensitivities: list[float] = [1.0]) -> tuple[pd.DataFrame, pd.DataFrame]:    
    """[Dataset] Return the user-product panel data."""
    import pandas as pd
    from tqdm import tqdm
    from pathlib import Path
    from main.python.survey.preprocessing import get_lpm
    from main.python.survey.config import currency_exchange_rate2, capital_cities, tier1_cities
    from main.python.product.config import mapper_grocery_electronic_category
    from main.python.product.preprocessing import get_product_classified, get_usercart_crossby_survey
    from prompter.base import write_to_jsonl

    # merge 'product-level' data with 'individual-level' data
    prod = get_product_classified()
    # merge with individual-level, city and id information
    survey, _ = get_usercart_crossby_survey()
    survey.sort_values(by=['id'], inplace=True)
    survey.dropna(subset=['buyer_mask'], inplace=True) 
    prod = prod.merge(survey[['buyer_mask', 'id', 'city', 'city_gadm', 'country']], on='buyer_mask', how='left')
    prod['year'] = prod['ds'].astype(str).apply(lambda x: x[:4])
    prod['month'] = prod['ds'].astype(str).apply(lambda x: x[4:6])
    prod['day'] = prod['ds'].astype(str).apply(lambda x: x[6:])
    # 1. loop at the salesoderid & buyer_mask level, fields: buyer_mask, year, month, day
    countries = {"ID": "Indonesia", "MY": "Malaysia", "PH": "Philippines", "SG": "Singapore", "TH": "Thailand", "VN": "Vietnam"}
    rows_by_buyer = []
    for iid, g in tqdm(prod.groupby('id'), total=prod.id.nunique(), desc="Constructing data by buyer"):
        # 1.1 for variables [56-61], we calculate `total` stuffs
        c = g['venture'].unique()[0]  # country code is unique!
        rate = currency_exchange_rate2[countries[c]]
        mask_grocery = g.regional_category1_name.isin(mapper_grocery_electronic_category['groceries'])
        mask_electronics = g.regional_category1_name.isin(mapper_grocery_electronic_category['electronics'])
        item = {
            # basic information
            'id': iid,
            'buyer_mask': g.buyer_mask.unique()[0],
            'city': g.city.unique()[0],
            'city_gadm': g.city_gadm.unique()[0],
            'country': g.country.unique()[0],
            # order-level information
            'Orders': g.salesorderid_mask.nunique(),
            'OrdersElectronic': g.salesorderid_mask.loc[mask_electronics].nunique(),
            'OrdersGrocery': g.salesorderid_mask.loc[mask_grocery].nunique(),
            'Spending': float(g.actual_gmv.sum() / rate),
            'SpendingElectronic': float(g.actual_gmv.loc[mask_electronics].sum() / rate),
            'SpendingGrocery': float(g.actual_gmv.loc[mask_grocery].sum() / rate),
            'Items': g.itemid_mask.nunique(),
            'ItemsElectronic': g.itemid_mask.loc[mask_electronics].nunique(),
            'ItemsGrocery': g.itemid_mask.loc[mask_grocery].nunique(),
            # sustainability information
            'greenOrders': g.loc[g.is_green == 1, 'salesorderid_mask'].nunique(),
            'greenSpending': float(g.loc[g.is_green == 1, 'actual_gmv'].sum() / rate),
            'greenItems': g.loc[g.is_green == 1, 'itemid_mask'].nunique(),
            # category-level information
            'greenOrdersElectronic': g.loc[(mask_electronics) & (g.is_green == 1)].salesorderid_mask.nunique(),
            'greenOrdersGrocery': g.loc[(mask_grocery) & (g.is_green == 1)].salesorderid_mask.nunique(),
            'greenItemsElectronic': g.loc[(mask_electronics) & (g.is_green == 1)].itemid_mask.nunique(),
            'greenItemsGrocery': g.loc[(mask_grocery) & (g.is_green == 1)].itemid_mask.nunique(),
            'greenSpendingElectronic': float(g.loc[(mask_electronics) & (g.is_green == 1), 'actual_gmv'].sum() / rate),
            'greenSpendingGrocery': float(g.loc[(mask_grocery) & (g.is_green == 1), 'actual_gmv'].sum() / rate)
        }
        # add individual-level shares
        for name in ['Electronic', 'Grocery', '']:
            for var in ['SpendingShare', 'ItemsShare', 'OrdersShare', 
                        'MonthlySpending', 'MonthlyItems', 'MonthlyOrders']:
                tar = f'green{var}{name}'
                if var.endswith('Share'):
                    type_ = var.replace("Share", "")
                    src = f'green{type_}{name}'
                    item[tar] = item[src] / item[f'{type_}{name}'] if item[f'Spending{name}'] > 0 else 0
                else:
                    src = f'green{var.replace("Monthly", "")}{name}'
                    item[tar] = item[src] / 12
        if item['Orders'] > 0:
            item['isOrderer'] = 1
        else:
            item['isOrderer'] = 0
        if item['greenOrders'] > 0:
            item['isGreen'] = 1
        else:
            item['isGreen'] = 0
        if item['greenOrdersElectronic'] > 0:
            item['isGreenElectronic'] = 1
        else:
            item['isGreenElectronic'] = 0
        if item['greenOrdersGrocery'] > 0:
            item['isGreenGrocery'] = 1
        else:
            item['isGreenGrocery'] = 0
        # append items to the list
        rows_by_buyer.append(item)
    # create the individual-level data table
    buyerpnl = pd.DataFrame(rows_by_buyer)
    # note: add _BPN and _LPM variables for the individual level variables at 05 Feb 2026
    f = Path('data') / 'replication_classification' / 'BPN-LPM-param.jsonl'
    keys = []
    for name in ['Electronic', 'Grocery', '']:
        for var in ['SpendingShare', 'ItemsShare', 'OrdersShare']:
            key = f'green{var}{name}'
            # BPN-based variables: b_max = 0.06; use the 90th quantile, updated at 13 Feb 2026
            # M' = Participants * m';
            mask = buyerpnl[f'isGreen{name}'] == 1
            b_max = buyerpnl.loc[mask, key].quantile(q=0.9)
            buyerpnl[f'{key}_BPN'] = (buyerpnl[key] / b_max).clip(upper=1)
            # LPM-based variables: x0 = 0.01, k = 1 / std(x)
            x0 = float(buyerpnl.loc[mask, key].quantile(q=0.5))
            k = 1 / float(buyerpnl[key].std())
            for s1 in sensitivities:      # loop for x0
                for s2 in sensitivities:  # loop for k
                    if int(s1*100) == 100 and int(s2*100) == 100:
                        buyerpnl[f'{key}_LPM'] = get_lpm(buyerpnl[key], inf=x0, k=k).clip(upper=1)
                        keys += [f'{key}_BPN', f'{key}_LPM']
                        param = [{'variable': f'{key}_BPN', 'type': 'BPN', 'b_max': float(b_max)}, 
                                {'variable': f'{key}_LPM', 'type': 'LPM', 'x0': x0, 'k': k}]      
                    else:
                        tag1 = f'{int(s1*100)}%'
                        tag2 = f'{int(s2*100)}%'
                        buyerpnl[f'{key}_LPM_x0{tag1}_k{tag2}'] = get_lpm(buyerpnl[key], inf=x0 * s1, k=s2 * k).clip(upper=1)
                        keys += [f'{key}_BPN', f'{key}_LPM_x0{tag1}_k{tag2}']
                        param = [{'variable': f'{key}_BPN', 'type': 'BPN', 'b_max': float(b_max)}, 
                                {'variable': f'{key}_LPM_x0{tag1}_k{tag2}', 'type': 'LPM', 'x0': x0 * s1, 'k': s2 * k}]      
                    write_to_jsonl(param, f, overwrite=False)

    # 1.2 aggregate the information at the city level
    # note: 
    #       use `GreenOrder` to calculate `greenOrderShare`
    #       use `GreenSpending` to calculate `greenSpendingShare`
    #       use `greenItemElectronic` and `greenItemGrocery` to calculate `greenItemShareElectronic` and `greenItemShareGrocery`
    #       use `GreenItem` to calculate `greenItemShare`
    # note: calculate `totalCitizenNumber`
    operator = {
        'city_gadm': 'first',
        'country': 'first',
        'Orders': 'sum',
        'OrdersElectronic': 'sum',
        'OrdersGrocery': 'sum',
        'Spending': 'sum',
        'SpendingElectronic': 'sum',
        'SpendingGrocery': 'sum',
        'Items': 'sum',
        'ItemsElectronic': 'sum',
        'ItemsGrocery': 'sum',
        'greenOrders': 'sum',
        'greenOrdersElectronic': 'sum',
        'greenOrdersGrocery': 'sum',
        'greenSpending': 'sum',
        'greenItems': 'sum',
        'greenItemsElectronic': 'sum',
        'greenItemsGrocery': 'sum',
        'greenItemsElectronic': 'sum',
        'greenItemsGrocery': 'sum',
        'greenSpendingElectronic': 'sum',
        'greenSpendingGrocery': 'sum',
        'isGreen': 'sum',
        'isOrderer': 'sum',
        'isGreenElectronic': 'sum',
        'isGreenGrocery': 'sum',
    }
    # include _BPN and _LPM variables into aggregation operations
    operator.update({k: 'mean' for k in keys})
    citypnl = buyerpnl.groupby('city').agg(operator).reset_index()
    # add penetration rate of 'orders' and 'green orders'
    citypnl['greenOrderRate'] = citypnl['isGreen'] / citypnl['isOrderer']
    for key in keys:
        citypnl[key] = citypnl[key] * (citypnl['greenOrderRate'])**(0.4)
    
    rename = {
        'Orders': 'totalOrders',
        'OrdersElectronic': 'totalOrdersElectronic',
        'OrdersGrocery': 'totalOrdersGrocery',
        'Spending': 'totalSpending',
        'SpendingElectronic': 'totalSpendingElectronic',
        'SpendingGrocery': 'totalSpendingGrocery',
        'Items': 'totalItems',
        'ItemsElectronic': 'totalItemsElectronic',
        'ItemsGrocery': 'totalItemsGrocery',
        'greenOrders': 'totalGreenOrders',
        'greenOrdersElectronic': 'totalGreenOrdersElectronic',
        'greenOrdersGrocery': 'totalGreenOrdersGrocery',
        'greenSpending': 'totalGreenSpending',
        'greenSpendingElectronic': 'totalGreenSpendingElectronic',
        'greenSpendingGrocery': 'totalGreenSpendingGrocery',
        'greenItems': 'totalGreenItems',
        'greenItemsElectronic': 'totalGreenItemsElectronic',
        'greenItemsGrocery': 'totalGreenItemsGrocery',
        'isGreen': 'sizeGreenCitizen',
        'isGreenElectronic': 'sizeElectronicCitizen',
        'isGreenGrocery': 'sizeGroceryCitizen'
    }
    citypnl = citypnl.rename(columns=rename)
    # 1.3 calculate the share of the variables
    citypnl['totalCitizenNumber'] = buyerpnl.groupby('city').agg({'buyer_mask': 'count'}).reset_index()['buyer_mask']
    citypnl['greenOrdersShare'] = citypnl['totalGreenOrders'] / citypnl['totalOrders']
    citypnl['greenOrdersShareElectronic'] = citypnl['totalGreenOrdersElectronic'] / citypnl['totalOrdersElectronic']
    citypnl['greenOrdersShareGrocery'] = citypnl['totalGreenOrdersGrocery'] / citypnl['totalOrdersGrocery']
    citypnl['greenSpendingShare'] = citypnl['totalGreenSpending'] / citypnl['totalSpending']
    citypnl['greenSpendingShareElectronic'] = citypnl['totalGreenSpendingElectronic'] / citypnl['totalSpendingElectronic']
    citypnl['greenSpendingShareGrocery'] = citypnl['totalGreenSpendingGrocery'] / citypnl['totalSpendingGrocery']
    citypnl['greenItemsShare'] = citypnl['totalGreenItems'] / citypnl['totalItems']
    citypnl['greenItemsShareElectronic'] = citypnl['totalGreenItemsElectronic'] / citypnl['totalItemsElectronic']
    citypnl['greenItemsShareGrocery'] = citypnl['totalGreenItemsGrocery'] / citypnl['totalItemsGrocery']
    # 1.4 calculate green consumption per capita
    citypnl['greenMonthlySpendingElectronic'] = citypnl['totalGreenSpendingElectronic'] / citypnl['totalCitizenNumber'] / 12
    citypnl['greenMonthlySpendingGrocery'] = citypnl['totalGreenSpendingGrocery'] / citypnl['totalCitizenNumber'] / 12
    citypnl['greenMonthlySpending'] = citypnl['totalGreenSpending'] / citypnl['totalCitizenNumber'] / 12
    citypnl['greenMonthlyItems'] = citypnl['totalGreenItems'] / citypnl['totalCitizenNumber'] / 12
    citypnl['greenMonthlyItemsElectronic'] = citypnl['totalGreenItemsElectronic'] / citypnl['totalItemsElectronic'] / 12
    citypnl['greenMonthlyItemsGrocery'] = citypnl['totalGreenItemsGrocery'] / citypnl['totalItemsGrocery'] / 12
    citypnl['greenMonthlyOrders'] = citypnl['totalGreenOrders'] / citypnl['totalCitizenNumber'] / 12
    citypnl['greenMonthlyOrdersElectronic'] = citypnl['totalGreenOrdersElectronic'] / citypnl['totalOrdersElectronic'] / 12
    citypnl['greenMonthlyOrdersGrocery'] = citypnl['totalGreenOrdersGrocery'] / citypnl['totalOrdersGrocery'] / 12
    # 1.5 isCapitalCity and isTierOneCity
    citypnl['isCapitalCity'] = citypnl['city_gadm'].apply(lambda x: 1 if x in capital_cities else 0)
    citypnl['isTierOneCity'] = citypnl['city_gadm'].apply(lambda x: 1 if x in tier1_cities else 0)
    return buyerpnl, survey, citypnl


if __name__ == "__main__":
    # quick test: the aggregated product data
    buyerpnl, survey, citypnl = get_transaction_aggregated()
    print(buyerpnl.head())
    print(survey.head())
    print(citypnl.head())
