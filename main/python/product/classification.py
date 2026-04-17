# The module for product classification using LLMs
# 
# Created at 23/10/2025
# 

import os
import sys
sys.path.append(os.getcwd())
import warnings
warnings.filterwarnings('ignore')
import pandas as pd


def get_is_english(text: str) -> bool:
    """Return True if the given text is in English, False otherwise."""
    from langdetect import detect, LangDetectException
    try:
        return detect(text) == "en"
    except LangDetectException:
        return False


def get_stopwords():
    """[Function] This function should be moved to prompter."""
    from pathlib import Path
    f = Path('main') / 'python' / 'product' / 'stopwords.txt'
    assert f.exists(), f"The stopwords file does not exist: {f}"
    return f.read_text().splitlines()


# The whole pipeline for n-gram extraction involves the following steps:
# 1. preprocessing the text
# 2. extracting the n-grams
# 3. identitfying the n-grams related to certificates
# 4. mapping the n-grams back to the original text
def run_preprocessing_pipeline(text_or_texts: str | list[str], lowercase: bool = True) -> list[str]:
    """[Function] Run text preprocessing on text(s) using spaCy (en_core_web_sm).
    
    Notes on performance optimisations:
    - Use `nlp.pipe` with disabled components we do not need (e.g. NER) to speed up processing.
    - Precompile regex and convert stopwords / punctuation to sets to reduce per‑token overhead.
    """
    import re
    import spacy
    from tqdm import tqdm
    from main.python.product.classification import get_stopwords

    # speed-up: use stopwords before running as a pipe
    stopwords = set(get_stopwords())
    nlp = spacy.load("en_core_web_sm", disable=["parser", "ner", "tagger"])
    if isinstance(text_or_texts, str):
        text_or_texts = [text_or_texts]

    # note: the testing case is hidden
    # text_or_texts = ['Tah Reua Glass Noodles, Lion Brand, Pack Type, 50g\r\n\r\n Made from 100% mung beans\r\n\r\n Size: 50g\r\n\r\n Packaged in 10 packs per box\r\n\r\n Features: Made from 100% mung beans, no added starch, chewy, soft, and not sticky\r\n\r\n \r\n\r\n Product from Tah Reua Glass Noodle Factory, Kanchanaburi Branch, Tah Reua']
    # Run text preprocessing: remove digits, stopwords, and punctuation using spaCy
    digit_re = re.compile(r"\d")
    piped = nlp.pipe(text_or_texts, n_process=2, batch_size=128)

    processed_texts = []
    for doc in tqdm(piped, total=len(text_or_texts), desc="Preprocessing texts"):
        tokens = []
        for token in doc:
            # remove stopwords, punctuation, digits, and token length < 2 (after stripping)
            if (token.is_stop or
                token.is_punct or
                digit_re.search(token.text) or
                token.text.lower() in stopwords or
                len(token.text.strip()) < 2):
                continue
            tokens.append(token.lemma_.lower() if lowercase else token.lemma_)
        # rejoin the texts
        processed_text = " ".join(tokens)
        processed_texts.append(processed_text)
    
    return processed_texts


def run_ngram_transformation_pipeline(items: list[str],
                                      ngram_range: tuple[int, int],
                                      max_df: float = 0.95,
                                      min_df: float = 0.01,
                                      lowercase: bool = False) -> tuple[list[int], list[str]]:
    """
    Transform the original text into n-grams.
    
    Args:
        items: list[str] - The original text
        ngram_range: tuple[int, int] - The range of n-grams
        max_df: float - The maximum document frequency of n-grams
        min_df: float - The minimum document frequency of n-grams
    Returns:
        tuple[list[int], list[str]] - The counts and features of the n-grams
    """
    from sklearn.feature_extraction.text import CountVectorizer
    from product.classification import get_stopwords

    vectorizer = CountVectorizer(ngram_range=ngram_range, stop_words=get_stopwords(), max_df=max_df, min_df=min_df, lowercase=lowercase)
    vectors = vectorizer.fit_transform(items)
    counts = vectors.sum(axis=0).A1
    features = vectorizer.get_feature_names_out()
    return counts, features


def run_organic_label_searching(model: str = "dashscope+qwen-max") -> pd.DataFrame:
    """[Function] Search for organic labels in the product data via LLMs."""
    import json
    import numpy as np
    import pandas as pd
    from tqdm import tqdm
    from pathlib import Path
    from pydantic import create_model, Field
    from main.python.product.preprocessing import get_product_prepared
    from main.python.product.config import mapper_grocery_electronic_category
    from main.python.product.classification import run_preprocessing_pipeline
    from prompter.prompt import BasePromptModel
    
    # if the results already exist, return them
    f = Path('data') / 'replication_classification' / f'sample-sustlabel-groceries-{model}.csv'
    if f.exists():
        out = pd.read_csv(f)
        return out
    
    p = get_product_prepared()
    groceries = p.loc[p.regional_category1_name.isin(mapper_grocery_electronic_category['groceries'])]
    groceries = groceries.loc[groceries.product_description.notna()]
    groceries = groceries.loc[~groceries.product_description.str.startswith('Missing', na=True) & ~groceries.product_description.str.startswith('Failed', na=True)]
    groceries.drop_duplicates(subset=['itemid_mask', 'product_description'], inplace=True)
    groceries['processed_product_description'] = run_preprocessing_pipeline(groceries.product_description.tolist(), lowercase=False)    
    # use LLM to search for the sustainability labels
    system_prompt = """
    Your task is to search for authorised sustainability labels and certification schemas for organic grocery products from the given product description.
    **Instruction**: For example, 'USDA' is a widely recognised organic sustainability label. Multiple labels may be present in the product description and you should identify all.
    **Output**: your output must be in the JSON format:
    {
        "labels": ["USDA", "Fair Trade"],
    }"""
    json_model = create_model(
        "SustainabilityLabelOutput", 
        labels=(list[str], Field(..., description="The sustainability labels and certification schemas")),
    )
    prompt = BasePromptModel(
        which_model=model,
        system_prompt=system_prompt,
        thinking=False,
        user_prompt=groceries.processed_product_description.tolist(),
        json_model=json_model
    )
    # identifying the subset of itemids that have not been processed
    gen = list[tuple](zip(groceries.processed_product_description.tolist(), groceries.itemid_mask.tolist()))
    
    results = []
    for text, itemid in tqdm(gen, total=len(gen), desc="Searching for sustainability labels"):
        try:
            response = prompt.prompt(text)
            label = json.loads(response.response)['labels']
            prompt.chat_model.messages = prompt.chat_model.messages[:2]
            prompt.memory = []
        
        except Exception:
            label = []
        
        results.append({
            'itemid_mask': itemid,
            'labels': np.nan if len(label) == 0 else label
        })
    # export identified labels to the output folder
    out = pd.DataFrame(results)
    out.to_csv(f, index=False, encoding='utf-8')
    return out


def run_authentitative_organic_label_searching() -> pd.DataFrame:
    """[Function] Search for organic labels from authentic documents."""
    import re
    import numpy as np
    from tqdm import tqdm
    from pathlib import Path
    from itertools import chain
    from main.python.product.config import mapper_grocery_electronic_category, organic_labels
    from main.python.product.preprocessing import get_product_prepared
    from main.python.product.classification import run_organic_label_searching
    
    df1 = run_organic_label_searching(model="dashscope+qwen-flash")
    df1.loc[:, 'label_string'] = df1['labels'].apply(lambda x: ', '.join(x) if isinstance(x, list) else str(x))
    df1.label_string.replace('nan', np.nan, inplace=True)
    df2 = run_organic_label_searching(model="dashscope+qwen-max")
    df2.loc[:, 'label_string'] = df2['labels'].apply(lambda x: ', '.join(x) if isinstance(x, list) else str(x))
    df2.label_string.replace('nan', np.nan, inplace=True)
    # compare & merge the two results
    mutual_ids = set(df1.itemid_mask.unique()) & set(df2.itemid_mask.unique())
    df1 = df1.loc[df1.itemid_mask.isin(mutual_ids)].drop_duplicates(subset=['itemid_mask', 'labels'])
    df1.loc[:, 'label_length'] = df1['label_string'].apply(lambda x: len(x) if isinstance(x, str) else 0)
    df2 = df2.loc[df2.itemid_mask.isin(mutual_ids)].drop_duplicates(subset=['itemid_mask', 'labels'])
    df2.loc[:, 'label_length'] = df2['label_string'].apply(lambda x: len(x) if isinstance(x, str) else 0)
    df1.sort_values(['itemid_mask', 'label_length'], ascending=False, inplace=True)
    df2.sort_values(['itemid_mask', 'label_length'], ascending=False, inplace=True)
    aggdf1 = df1.groupby('itemid_mask').agg({'labels': 'first', 'label_length': 'first'}).reset_index()
    aggdf2 = df2.groupby('itemid_mask').agg({'labels': 'first', 'label_length': 'first'}).reset_index()
    certs1 = set(chain.from_iterable([eval(i) for i in aggdf1.loc[aggdf1.labels.notna(), 'labels'].tolist()]))
    certs2 = set(chain.from_iterable([eval(i) for i in aggdf2.loc[aggdf2.labels.notna(), 'labels'].tolist()]))
    
    # note: calculate the intersection of the two sets
    print(f'Share of mutual certs: {len(certs1 & certs2) / len(certs1)}')
    print(f'Total unique certs: {len(certs1 | certs2)}')
    
    # the above steps are manually checked and verified
    p = get_product_prepared()
    groceries = p.loc[p.regional_category1_name.isin(mapper_grocery_electronic_category['groceries'])]
    groceries.drop_duplicates(subset=['itemid_mask', 'product_description',], inplace=True)
    groceries.loc[:, 'product_content'] = groceries[['product_description', 'product_name']].apply(lambda x: '\n'.join(x), axis=1)
    for label, params in tqdm(organic_labels.items(), total=len(organic_labels), desc="Searching for sustainability labels"):
        keywords = params['keywords']
        escaped_keywords = [re.escape(k) for k in keywords]
        pattern = r'(?<![\w@])({})(?![\w])'.format('|'.join(escaped_keywords))
        mask = groceries.product_content.str.contains(pattern, case=False, na=False, regex=True)
        print(f'No. of products with {label}: {mask.sum()}')
        groceries.loc[:,f'organic[{label}]'] = 0
        groceries.loc[mask, f'organic[{label}]'] = 1
    
    # check the results
    columns = [f'organic[{label}]' for label in organic_labels.keys()]
    groceries.loc[:, 'is_green'] = groceries[columns].apply(lambda x: int(any(x)), axis=1)
    print(f'No. of green products: {groceries.is_green.sum()}')
    out = groceries[['itemid_mask', 'salesorderid_mask', 'is_green']].drop_duplicates(subset=['itemid_mask', 'salesorderid_mask'])

    outfile = Path('data') / 'replication_classification' / 'sample-groceries-classification.csv'
    out.to_csv(outfile, index=False, encoding='utf-8')
    return groceries


def run_energy_label_searching(model: str = "dashscope+qwen-max") -> pd.DataFrame:
    """[Function] Search for energy-efficient labels in the product data via LLMs."""
    import json
    import numpy as np
    import pandas as pd
    from tqdm import tqdm
    from pathlib import Path
    from pydantic import create_model, Field
    from main.python.product.preprocessing import get_product_prepared
    from main.python.product.config import mapper_grocery_electronic_category
    from main.python.product.classification import run_preprocessing_pipeline
    from prompter.prompt import BasePromptModel
    
    # if the results already exist, return them
    f = Path('data') / 'replication_classification' / f'sample-sustlabel-electronics-{model}.csv'
    if f.exists():
        out = pd.read_csv(f)
        return out
    
    p = get_product_prepared()
    electronics = p.loc[p.regional_category1_name.isin(mapper_grocery_electronic_category['electronics'])]
    mask_missing_or_failed = electronics.product_description.str.startswith('Missing', na=True) | electronics.product_description.str.startswith('Failed', na=True) | electronics.product_name.str.startswith('Missing', na=True) | electronics.product_name.str.startswith('Failed', na=True)
    mask_isna = electronics.product_description.isna() & electronics.product_name.isna()
    electronics = electronics.loc[~mask_missing_or_failed & ~mask_isna]
    electronics.drop_duplicates(subset=['itemid_mask', 'product_description', 'product_name'], inplace=True)  # 11,526
    electronics['processed_product_description'] = run_preprocessing_pipeline(electronics.product_description.tolist(), lowercase=False)
    electronics['processed_product_name'] = run_preprocessing_pipeline(electronics.product_name.tolist(), lowercase=False)
    electronics['processed_content'] = electronics[['processed_product_description', 'processed_product_name']].apply(lambda x: "\n".join(x), axis=1)
    
    # configure the LLM prompt
    system_prompt = """
    Your task is to search for nationally or internationally authorised labels, standards and certifications for electronic devices, appliances and parts from the given product content.
    **Instruction**
    1. You should identify all possible labels, standards and certifications but exclude those that are not nationally or internationally authorised. 
    2. If no energy-efficient labels are found, return an empty list `[]`.
    3. Identify labels, standards and certifications from various product categories, e.g., automotive, cameras & drones, computers & components, electronics parts & accessories, home appliances, laundry & cleaning equipment, mobiles & tablets, printers & scanners, etc.
    **Output**: your output must be in the JSON format:
    {
        "labels": ["Energy Star", "NEA Energy Label", ..., "TISI", "ISO14001"]
    }"""
    json_model = create_model(
        "SustainabilityLabelOutput", 
        labels=(list[str], Field(..., description="Recognising labels, standards and certifications")),
    )
    prompt = BasePromptModel(
        which_model=model,
        system_prompt=system_prompt,
        thinking=False,
        user_prompt=electronics.processed_content.tolist(),
        json_model=json_model
    )
    # identifying the subset of itemids that have not been processed
    gen = list[tuple](zip(electronics.processed_content.tolist(), electronics.itemid_mask.tolist()))
    results = []
    for text, itemid in tqdm(gen, total=len(gen), desc="Searching for sustainability labels"):
        try:
            response = prompt.prompt(text)
            label = json.loads(response.response)['labels']
            prompt.chat_model.messages = prompt.chat_model.messages[:2]
            prompt.memory = []
        
        except Exception:
            label = []
        
        results.append({
            'itemid_mask': itemid,
            'labels': np.nan if len(label) == 0 else label
        })
    # export identified labels to the output folder
    out = pd.DataFrame(results)
    out.to_csv(f, index=False, encoding='utf-8')
    return out


def run_authentitative_electronic_label_searching() -> pd.DataFrame:
    """[Function] Search for organic labels from authentic documents."""
    import re
    import numpy as np
    from tqdm import tqdm
    from pathlib import Path
    from itertools import chain
    from main.python.product.config import mapper_grocery_electronic_category, energy_labels
    from main.python.product.preprocessing import get_product_prepared
    from main.python.product.classification import run_energy_label_searching

    # obtain the results from the first model (qwen-flash)
    df1 = run_energy_label_searching(model="dashscope+qwen-flash")
    df1.loc[:, 'label_string'] = df1['labels'].apply(lambda x: ', '.join(x) if isinstance(x, list) else str(x))
    df1.loc[:, 'label_length'] = df1['label_string'].apply(lambda x: len(x) if isinstance(x, str) else 0)
    # obtain the results from the second model (qwen-max)
    df2 = run_energy_label_searching(model="dashscope+qwen-max")
    df2.loc[:, 'label_string'] = df2['labels'].apply(lambda x: ', '.join(x) if isinstance(x, list) else str(x))
    df2.label_string.replace('nan', np.nan, inplace=True)
    df2.loc[:, 'label_length'] = df2['label_string'].apply(lambda x: len(x) if isinstance(x, str) else 0)

    # compare the two results by unique certs
    certs1 = set(chain.from_iterable([eval(i) for i in df1.loc[df1.labels.notna(), 'labels'].tolist()]))
    certs2 = set(chain.from_iterable([eval(i) for i in df2.loc[df2.labels.notna(), 'labels'].tolist()]))
    # note: calculate the intersection of the two sets
    print(f'Share of mutual certs: {len(certs1 & certs2) / len(certs1)}')
    print(f'Total unique certs: {len(certs1 | certs2)}')

    p = get_product_prepared()
    elec = p.loc[p.regional_category1_name.isin(mapper_grocery_electronic_category['electronics'])]
    mask_missing_or_failed = elec.product_description.str.startswith('Missing', na=True) | \
                             elec.product_description.str.startswith('Failed', na=True) | \
                             elec.product_name.str.startswith('Missing', na=True) | \
                             elec.product_name.str.startswith('Failed', na=True)
    mask_isna = elec.product_description.isna() & elec.product_name.isna()
    elec = elec.loc[~mask_missing_or_failed & ~mask_isna]
    elec.drop_duplicates(subset=['itemid_mask', 'product_description', 'product_name'], inplace=True)
    elec['processed_content'] = elec[['product_name', 'product_description']].apply(lambda x: "\n".join(x), axis=1)
    for label, params in tqdm(energy_labels.items(), total=len(energy_labels), desc="Searching for sustainability labels"):
        keywords = sorted(params['keywords'], key=len, reverse=True)
        # keywords=['5-star']
        escaped_keywords = [re.escape(kw) for kw in keywords]
        pattern = r'(?<![\w@])({})(?![\w])'.format('|'.join(escaped_keywords))
        mask = elec.processed_content.str.contains(pattern, case=False, na=False, regex=True)
        # elec.loc[mask, 'processed_content'].tolist()
        print(f'No. of products with {label}: {mask.sum()}')
        elec.loc[:, f'electronics[{label}]'] = 0
        elec.loc[mask, f'electronics[{label}]'] = 1

    # check the results
    columns = [f'electronics[{label}]' for label in energy_labels.keys()]
    elec.loc[:, 'is_green'] = elec[columns].apply(lambda x: int(any(x)), axis=1)
    print(f'No. of energy-efficient products: {elec.is_green.sum()}')
    out = elec[['itemid_mask', 'salesorderid_mask', 'is_green']].drop_duplicates(subset=['itemid_mask', 'salesorderid_mask'])

    outfile = Path('data') / 'replication_classification' / 'sample-electronics-classification.csv'
    out.to_csv(outfile, index=False, encoding='utf-8')
    return elec

    
if __name__ == "__main__":
    # individual pipelines are called by the last step of the replication pipeline
    # create two output files for two alternative LLM models, and the unified final classification file with identified labels (certificates)
    run_authentitative_organic_label_searching()
    run_authentitative_electronic_label_searching()
