# This preprocessing module works for the survey data processing
# 
# Created at 07/10/2025; updated at 04/12/2025
# 

import warnings
warnings.filterwarnings("ignore")
import pandas as pd


def get_lpm(x, inf: float, k: float):
    import numpy as np
    return 1 / (1 + np.exp(-k * (x - inf)))


def get_aligned_cities() -> pd.DataFrame:
    """[Function] Return the aligned cities between the survey and GADM map data. 
    This function calls to utilise the data derived from GADM in `data/replication/sea-city-with-coordinates.shp`."""
    import geopandas as gpd
    from pathlib import Path
    f = Path('data') / 'replication_classification' / 'cities' / 'sea-city-with-coordinates.shp'
    return gpd.read_file(f)


def run_currency_transformation(df: pd.DataFrame) -> pd.DataFrame:
    """Run currency transformation: column=`incomeHousehold`"""
    from main.python.survey.config import mapper_currency
    
    def get_mean_income(x) -> float:
        if x is None:
            return 0
        elif None in x:
            x.remove(None)
            return x[0]
        return sum(x) / len(x)
    
    mapper = {each["source"]: each["target"] for each in mapper_currency}
    df.loc[:, "income_range"] = df.loc[:, "incomeHousehold"].map(mapper)
    df.loc[:, "income_abs"] = df.loc[:, "income_range"].apply(get_mean_income)
    return df[['id', 'income_abs', 'income_range']]


def run_metadata_transformation(df: pd.DataFrame) -> pd.DataFrame:
    """Run metadata transformation"""
    from main.python.survey.config import mapper_age, mapper_education
    
    # age
    mapper_age = {k: v[-1] for k, v in mapper_age.items()}
    df.loc[:, "age_abs"] = df.loc[:, "age"].map(mapper_age)
    # gender and female portion
    df.loc[:, "gender_abs"] = df.loc[:, "gender"].map({'Male': 0, 'Female': 1, 'Other': 2})
    df.loc[:, "isFemale"] = df.loc[:, "gender"].map({'Male': 0, 'Female': 1, 'Other': 0})
    # religion
    mapper_answer2religion = {
        'Prefer not to disclose': 'Other religion',
        'Folk Religion': 'Other religion',
        'Other': 'Other religion',
        'No religion / Spiritual / Atheist': 'No religion'
    }
    df.loc[:, "religion"] = df.loc[:, "religion"].apply(lambda x: mapper_answer2religion.get(x, x))
    df.loc[:, 'isReligious'] = df.loc[:, 'religion'].apply(lambda x: 1 if x != 'No religion' else 0)
    df.loc[df.religion.isna(), 'isReligious'] = 0
    # add major religons 
    religions = [
        'Islam',
        'Buddhism',
        'Christianity',
        'Hinduism',
        'Taoism'
    ]
    for religion in religions:
        df.loc[:, f'is{religion.title()}'] = df.loc[:, 'religion'].apply(lambda x: 1 if x == religion else 0)
    
    # education
    df.loc[:, "education_abs"] = df.loc[:, "education"].map(mapper_education)
    export_keys = [
        'id',
        'country',
        'city',
        'age_abs',
        'gender_abs',
        'religion',
        'isReligious',
        'isIslam',
        'isBuddhism',
        'isChristianity',
        'isHinduism',
        'isTaoism',
        'education_abs'
    ]
    return df[export_keys]


def run_preprocessing(df: pd.DataFrame) -> pd.DataFrame:
    """Run preprocessing"""
    d1 = run_currency_transformation(df).copy(deep=True)
    d2 = run_metadata_transformation(df).copy(deep=True)
    pnl = d1.merge(d2, on="id", how="left")
    return pnl


def get_survey_raw() -> pd.DataFrame:
    """Return the raw survey data from the local file"""
    import pandas as pd
    from pathlib import Path
    from main.python.survey.preprocessing import run_preprocessing
    
    filepath = Path("data") / "replication_classification" / "sample-survey.csv"
    df = pd.read_csv(filepath)
    run_preprocessing(df)  # this transformation is inplace
    return df


# calculate the metrics
def add_green_attitude_metrics(df: pd.DataFrame) -> pd.DataFrame:
    """Add the green attitude metrics to the dataframe"""
    from main.python.survey.config import gap_columns
    
    # genGreenAttitude and genGreenHumanLikert are ordinal variables, convert them to a range of 0-1
    df['genGreenAttitude'] = df['genGreenAttitude'].map({1: 0, 2: 0.25, 3: 0.5, 4: 0.75, 5: 1})
    df['genGreenHumanLikert'] = df['genGreenHumanLikert'].map({1: 0, 2: 0.25, 3: 0.5, 4: 0.75, 5: 1})    
    # 'Divide' metrics must be calculated at the individual level
    df['genAwarenessActionDivide'] = df['genGreenAttitude'] - df['genGreenHumanLikert']
    df['genNatureConnectionActionDivide'] = df['genGreenAttitude'] - df['genGreenConnectness']
    # add std action Likert scores
    df['stdGreenElectronicLikert'] = (df['actGreenElectronicLikert'].values -1) / 4  # 0-1 scale
    df['stdGreenGroceryLikert'] = (df['actGreenGroceryLikert'].values -1) / 4  # 0-1 scale
    df['stdGreenWalkLikert'] = (df['actGreenWalkLikert'].values -1) / 4  # 0-1 scale
    df['stdGreenDeliveryLikert'] = (df['actGreenDeliveryLikert'].values -1) / 4  # 0-1 scale
    # rename gap columns
    gap_columns = {col: col.replace('gap', 'gapReported') for col in gap_columns}
    df.rename(columns=gap_columns, inplace=True)
    return df


def add_unified_citynames(df: pd.DataFrame) -> pd.DataFrame:
    """Add the unified city names to the dataframe. The original city names will be named as `city`,
    and the unified city names are in the `city_gadm`."""
    from main.python.survey.preprocessing import get_aligned_cities
    
    citynames = get_aligned_cities()
    city_to_gadm = {'Other': 'Other'}
    for _, row in citynames.iterrows():
        if row['is_city']:
            city_to_gadm[row["city"]] = row["gadm_city"]
        else:
            city_to_gadm[row["city"]] = row["gadm_provi"]
    
    df['city_gadm'] = df['city'].map(city_to_gadm)
    return df


def add_gap_metrics(df: pd.DataFrame, sensitivities: list[float] = [1.0]) -> pd.DataFrame:
    from pathlib import Path
    from main.python.survey.preprocessing import get_lpm
    from prompter.base import write_to_jsonl
    
    f = Path('data') / 'replication_classification' / 'BPN-LPM-param.jsonl'
    # note: rename the columns to be consistent with the latest variable notations at 03 Feb 2026
    ints = ['stdGreenElectronicLikert', 'stdGreenGroceryLikert', 'stdGreenDeliveryLikert', 'stdGreenWalkLikert']
    behs = ['reportMonthlyGreenElectronic', 'reportMonthlyGreenGrocery', 'reportMonthlyGreenDelivery', 'reportMonthlyGreenWalk']
    for i, b in zip(ints, behs):
        # update Intention-Behaviour Gap calculation at 03 Feb 2026
        df[f'{i}_BPN'] = df[i].copy()
        df[f'{b}_BPN'] = df[b].apply(lambda x: x / 10).clip(upper=1)  # B_max = 10 for all behaviours
        df[b.replace('reportMonthly', 'gapReported')+'_BPN'] = df[i] - df[f'{b}_BPN']        
        # update the Logistic Probablity Mapping (LPM) at 03 Feb 2026
        # add sensitivity parameter at 20 Mar 2026
        for s1 in sensitivities:      # loop for x0
            for s2 in sensitivities:  # loop for k
                if int(s1*100) == 100 and int(s2*100) == 100:
                    df[f'{i}_LPM'] = get_lpm(df[i], 0.5, k=(1 / df[i].std())).clip(upper=1)
                    df[f'{b}_LPM'] = get_lpm(df[b], 4, k=(1 / df[b].std())).clip(upper=1)
                    df[b.replace('reportMonthly', 'gapReported')+'_LPM'] = df[f'{i}_LPM'] - df[f'{b}_LPM']
                    param = [
                        {'variable': f'{i}_BPN', 'type': 'BPN', 'b_max': 10},
                        {'variable': f'{b}_BPN', 'type': 'BPN', 'b_max': 10},
                        {'variable': f'{i}_LPM', 'type': 'LPM', 'x0': 0.5, 'k': (1 / float(df[i].std()))},
                        {'variable': f'{b}_LPM', 'type': 'LPM', 'x0': 4, 'k': (1 / float(df[b].std()))}
                    ]
                else:
                    tag1 = f'{int(s1*100)}%'
                    tag2 = f'{int(s2*100)}%'
                    df[f'{i}_LPM_x0{tag1}_k{tag2}'] = get_lpm(df[i], s1 * 0.5, k=s2 * (1 / df[i].std())).clip(upper=1)
                    df[f'{b}_LPM_x0{tag1}_k{tag2}'] = get_lpm(df[b], s1 * 4, k=s2 * (1 / df[b].std())).clip(upper=1)
                    name_gap = b.replace('reportMonthly', 'gapReported')
                    df[name_gap + f'_LPM_x0{tag1}_k{tag2}'] = df[f'{i}_LPM_x0{tag1}_k{tag2}'] - df[f'{b}_LPM_x0{tag1}_k{tag2}']
                    param = [
                        {'variable': f'{i}_BPN', 'type': 'BPN', 'b_max': 10},
                        {'variable': f'{b}_BPN', 'type': 'BPN', 'b_max': 10},
                        {'variable': f'{i}_LPM_x0{tag1}_k{tag2}', 'type': 'LPM', 'x0': s1 * 0.5, 'k': s2 * (1 / float(df[i].std()))},
                        {'variable': f'{b}_LPM_x0{tag1}_k{tag2}', 'type': 'LPM', 'x0': s1 * 4, 'k': s2 * (1 / float(df[b].std()))}
                    ]
                write_to_jsonl(param, f, overwrite=False)
        # remove excessive variables
        df.drop(columns=[i, b], inplace=True)

    return df


def get_survey_prepared(sensitivities: list[float] = [1.0]) -> pd.DataFrame:
    """Return the prepared survey data with added metrics from the raw survey"""
    from main.python.survey.preprocessing import get_survey_raw, add_green_attitude_metrics, add_unified_citynames, add_gap_metrics

    df = get_survey_raw()
    df = add_green_attitude_metrics(df)
    df = add_gap_metrics(df, sensitivities)
    df = add_unified_citynames(df)
    return df


def get_survey_aggregated(sensitivities: list[float] = [1.0]) -> pd.DataFrame:
    import numpy as np
    from main.python.survey.preprocessing import get_survey_prepared

    # 1. According to the latest variable notation, the survey data should be averaged at the individual level and then aggregated by city
    survey = get_survey_prepared(sensitivities)
    # 1.1 individual attitudes and intentions
    attitude_func = {
        'stdGreenElectronicLikert_BPN': np.nanmean,  # BPN-based
        'stdGreenGroceryLikert_BPN': np.nanmean,
        'stdGreenDeliveryLikert_BPN': np.nanmean,
        'stdGreenWalkLikert_BPN': np.nanmean,
        'reportMonthlyGreenElectronic_BPN': np.nanmean,  # BPN-based
        'reportMonthlyGreenGrocery_BPN': np.nanmean,
        'reportMonthlyGreenDelivery_BPN': np.nanmean,
        'reportMonthlyGreenWalk_BPN': np.nanmean
    }
    attitude_func.update({c: np.nanmean for c in survey.columns if c.endswith('_LPM') or c.endswith('%')})

    # 1.2 demographic data
    demographic_func = {
        'isHighIncome': np.nanmean,
        'isHighEdu': np.nanmean,
        'isFemale': np.nanmean,
        'ageMid': np.nanmean,
        'onlineShoppingExperience': np.nanmean,
        'socialMediaHrs': np.nanmean,
        'isReligious': sum,
        'isIslam': sum,
        'isBuddhism': sum,
        'isChristianity': sum,
        'isHinduism': sum,
        'isTaoism': sum
    }
    # 1.3 action data
    action_func = {
        'intentGreenRecycle': np.nanmean,
        'intentGreenSaving': np.nanmean,
        'reportGreenRecycle': np.nanmean,
        'reportGreenSaving': np.nanmean,
    }
    func = dict(**attitude_func, **demographic_func, **action_func)
    pnl = survey.groupby('city').agg(func).reset_index()
    # 1.4 calculate size of variables
    size_func = {
        'sizeAttitude': list(attitude_func.keys())[0:5],  # 2-6
        'sizeIntention': list(attitude_func.keys())[5:9],  # 7-10
        'sizeReportedBehavior': list(attitude_func.keys())[13:17],  # 15-18
        'sizeDemo': list(demographic_func.keys())[0:4],  # demograhpic
        'sizeDigital': list(demographic_func.keys())[4:],  # digital
        'sizeReligion': list(demographic_func.keys())[5:],  # religion
    }
    for key, value in size_func.items():
        pnl[key] = survey[value + ['city']].groupby('city').count().min(axis=1).tolist()
    
    return pnl


if __name__ == "__main__":
    # quick test: the aggregated survey data
    pnl = get_survey_aggregated()
