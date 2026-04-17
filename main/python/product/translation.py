# The translation module for the product module
# 
# Created at 23/10/2025
# 

def get_is_english(text: str) -> bool:
    """Return True if the given text is in English, False otherwise."""
    from langdetect import detect, LangDetectException
    try:
        return detect(text) == "en"
    except LangDetectException:
        return False


def run_translation(text: str) -> str:
    """Run translation on the given text."""
    import json
    from time import sleep
    from pydantic import create_model, Field
    from prompter.prompt import BasePromptModel
    from main.python.product.translation import get_is_english
    
    if get_is_english(text):
        return text
    
    elif not isinstance(text, str) or len(text) == 0:
        return 'Failed to translate'
    
    model = "dashscope+qwen-plus"  # Note: replace with alternative models, "ollama+qwen3:4b" or "openai+gpt-4o-mini", etc.
    system_prompt = """
    You are a professional product translator. 
    Your task is to translate the given content into English. 
    Your answer should be in the JSON format:
    {
        "translation": "The translation of the given content"
    }"""
    json_model = create_model(
        "TranslationOutput", 
        translation=(str, Field(..., description="The translation of the given content"))
    )
    prompt = BasePromptModel(
        which_model=model,
        system_prompt=system_prompt, 
        thinking=False,
        user_prompt=text,
        json_model=json_model
    )
    for i in range(3):
        try:
            response = prompt.prompt(text)
            return json.loads(response.response)['translation']
        except Exception:
            sleep(1)
            continue
    
    return 'Failed to translate'


def run_translation_pipeline() -> None:
    """Run product translation on the entire dataset."""
    from tqdm import tqdm
    from pathlib import Path
    from prompter.base import write_to_jsonl
    from main.python.product.preprocessing import get_product_raw
    from main.python.product.translation import get_is_english, run_translation
    
    # obtain all product data
    f = Path("data") / "replication_classification" / "sample-orderitem-tranlsated.jsonl"
    prod = get_product_raw().drop_duplicates(subset=['itemid_mask', 'skuid_mask'])
    df = prod.copy()
    for _, row in tqdm(df.iterrows(), total=len(df), desc="Running product translation"):
        row = row.astype(str).to_dict()
        # construct a new item
        item = {
            'itemid_mask': row['itemid_mask'],
            'skuid_mask': row['skuid_mask'],
            'venture': row['venture'],
            'original_name': row['product_name'],
            'original_description': row['product_description']
        }
        for field in ['product_name', 'product_description']:
            if row[field] == '' or row[field] == 'nan':
                item[field] = 'Missing product ' + field.replace('_', '')
                continue
            elif get_is_english(row[field]):
                item[field] = row[field]
                continue
        
            item[field] = run_translation(row[field])
        
        # complete the loop
        write_to_jsonl(item, f, overwrite=False, encoding="utf-8")


if __name__ == "__main__":
	# for a quick test
	run_translation_pipeline()
