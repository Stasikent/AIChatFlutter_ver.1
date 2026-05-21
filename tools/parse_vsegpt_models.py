import json
import re
from pathlib import Path

import requests
from bs4 import BeautifulSoup


URL = "https://vsegpt.ru/Docs/Models"

VALID_PROVIDERS = {
    "openai",
    "deepseek",
    "google",
    "anthropic",
    "meta",
    "mistralai",
    "mistral",
    "cohere",
    "x-ai",
    "xai",
    "qwen",
    "alibaba",
    "moonshot",
    "amazon",
    "nvidia",
    "perplexity",
}


def normalize_model_id(text: str):

    text = text.strip()

    matches = re.findall(
        r'([a-zA-Z0-9\-]+/[a-zA-Z0-9\-_.:]+)',
        text
    )

    for model in matches:

        model = model.lower()

        provider = model.split("/")[0]

        if provider not in VALID_PROVIDERS:
            continue

        if len(model) < 10:
            continue

        return model

    return None


def main():

    response = requests.get(
        URL,
        timeout=30
    )

    response.raise_for_status()

    soup = BeautifulSoup(
        response.text,
        "html.parser"
    )

    basic = set()
    professional = set()

    blocks = soup.find_all(
        ["tr", "li", "div", "p"]
    )

    for block in blocks:

        text = block.get_text(
            " ",
            strip=True
        )

        model_id = normalize_model_id(
            text
        )

        if not model_id:
            continue

        if "профессиональный" in text.lower():

            professional.add(
                model_id
            )

        else:

            basic.add(
                model_id
            )

    basic = basic - professional

    result = {
        "source": URL,
        "basic": sorted(basic),
        "professional": sorted(professional),
    }

    out = Path(
        "assets/models/vsegpt_models.json"
    )

    out.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    out.write_text(
        json.dumps(
            result,
            ensure_ascii=False,
            indent=2
        ),
        encoding="utf-8"
    )

    print()
    print(
        f"Basic: {len(basic)}"
    )

    print(
        f"Professional: {len(professional)}"
    )

    print(
        f"Saved: {out}"
    )


if __name__ == "__main__":
    main()