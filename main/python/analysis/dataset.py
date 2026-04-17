# The city-level aggregated codes for the analysis module
# 
# Created at 23/10/2025
# 

import os
import sys
sys.path.append(os.getcwd())
import warnings
warnings.filterwarnings("ignore")
import pandas as pd


def get_geo_metrics():
    import pandas as pd
    from pathlib import Path

    # get desakota & other geographical data ready
    f = Path('data') / 'replication_geometric' / 'processed' / 'GeoIndex.xlsx'
    metric = pd.read_excel(f)
    metric['city'] = metric['city'].str.replace('_', ' ')
    # combine 'Sabah' and 'Sarawak' into one city (according to the official names)
    operator = {
        'Coastal Accessibility': 'mean',
        'Green Space Accessibility_within_300m': 'mean',
        'Park Accessibility_within_500m': 'mean',
        'Blue Exposure Index': 'mean',
        'Patch Density': 'mean',
        'Largest Patch Index': 'mean',
        'Patch Dispersion Index': 'mean',
        'Green Exposure Index': 'mean',
        'Park Proportion': 'mean',
        'Per Capita Park': 'mean',
        'Desakota_Index_CropAndGreen': 'mean',
        'Desakota_Index_CropOnly': 'mean',
        'GDP_sum(PPP)': 'sum',
        'GDP_per': 'mean',
        'crop_Land': 'sum'
    }
    ci = ['Sabah', 'Sarawak']
    metric.loc[120, operator.keys()] = metric.loc[metric.city.isin(ci), :].agg(operator)
    metric.loc[120, 'city'] = 'Sabah & Sarawak'
    metric.drop(index=127, inplace=True)
    metric.reset_index(drop=True, inplace=True)
    return metric


def get_gap_metrics(citypnl: pd.DataFrame) -> tuple[list[str], pd.DataFrame]:
    """Use individual- and city-level data to calculate the gaps"""
    # note: gaps should be calculated only at the city level
    # first, intention-report gap
    prefix = 'intentionReportGap'
    activites = ['Electronic', 'Grocery', 'Delivery', 'Walk']
    gap_columns = []
    for activity in activites:
        citypnl[f'{prefix}{activity}_BPN'] = citypnl[f'stdGreen{activity}Likert_BPN'] - citypnl[f'reportMonthlyGreen{activity}_BPN']
        citypnl[f'{prefix}{activity}_LPM'] = citypnl[f'stdGreen{activity}Likert_LPM'] - citypnl[f'reportMonthlyGreen{activity}_LPM']
        gap_columns.append(f'{prefix}{activity}_BPN')
        gap_columns.append(f'{prefix}{activity}_LPM')
    # second, report-behaviour gap
    activities = ['Electronic', 'Grocery']
    prefix = 'reportBehaviourGap'
    for activity in activities:
        citypnl[f'{prefix}{activity}_BPN'] = citypnl[f'reportMonthlyGreen{activity}_BPN'] - citypnl[f'greenOrdersShare{activity}_BPN']
        citypnl[f'{prefix}{activity}_LPM'] = citypnl[f'reportMonthlyGreen{activity}_LPM'] - citypnl[f'greenOrdersShare{activity}_LPM']
        gap_columns.append(f'{prefix}{activity}_BPN')
        gap_columns.append(f'{prefix}{activity}_LPM')
    # third, intention-behaviour gap
    prefix = 'intentionBehaviourGap'
    for activity in activities:
        citypnl[f'{prefix}{activity}_BPN'] = citypnl[f'stdGreen{activity}Likert_BPN'] - citypnl[f'greenOrdersShare{activity}_BPN']
        citypnl[f'{prefix}{activity}_LPM'] = citypnl[f'stdGreen{activity}Likert_LPM'] - citypnl[f'greenOrdersShare{activity}_LPM']
        gap_columns.append(f'{prefix}{activity}_BPN')
        gap_columns.append(f'{prefix}{activity}_LPM')

    print(f'Gaps calculated: {gap_columns}')
    return gap_columns, citypnl


# requested by Luoxuan on 25 Nov 2025
def get_panel_exported_with_sensitivity():
    from pathlib import Path
    from main.python.survey.preprocessing import get_survey_aggregated
    from main.python.product.preprocessing import get_transaction_aggregated
    from prompter.base import read_from_jsonl
    
    fpnl = Path('data') / 'replication_classification' / 'sample-citypanel-sensitivity-49scenarios.csv'  # the main panel data for the baseline and sensitivity analysis
    fbuyer = Path('data') / 'replication_classification' / 'sample-buyerpanel.csv'
    fparam = Path('data') / 'replication_classification' / 'BPN-LPM-param.jsonl'
    if fparam.exists():
        fparam.unlink()
    
    metric = get_geo_metrics()
    # Note: add sensitivity parameter at 20 Mar 2026
    sensitivities = [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3]  # sensitivities for the LPM parameters from 70% to 130% 
    agg_survey = get_survey_aggregated(sensitivities)
    buyerpnl, survey, citypnl = get_transaction_aggregated(sensitivities)
    buyerpnl.to_csv(fbuyer, index=False)
    pnl = citypnl.merge(agg_survey, on='city', how='left')
    pnl = pnl.merge(metric, on='city', how='left')
    pnl.to_csv(fpnl, index=False)
    param = next(read_from_jsonl(fparam))
    param.to_csv(fparam.with_suffix('.csv'), index=False)
    return buyerpnl, survey, pnl


if __name__ == "__main__":
    # quick test: the panel data for the baseline and sensitivity analysis
    buyerpnl, survey, citypnl = get_panel_exported_with_sensitivity()
