"""Contract tests — JSON Schema and Pydantic must agree on the same fixtures.

If these two ever diverge, the iOS app (which decodes against the schema) and
the backend (which validates with Pydantic) will silently disagree on what
counts as a valid extraction. Keep this test green.
"""

import json
from pathlib import Path
from typing import Any

import jsonschema
import pytest
from pydantic import ValidationError

from app.schemas.purchase import FashionPurchaseExtraction

SCHEMA_PATH = (
    Path(__file__).resolve().parents[2] / "shared" / "schemas" / "purchase.schema.json"
)


@pytest.fixture(scope="module")
def schema() -> dict[str, Any]:
    return json.loads(SCHEMA_PATH.read_text())


VALID_FIXTURES: list[dict[str, Any]] = [
    {
        "is_fashion": True,
        "source_msg_id": "msg_001",
        "items": [
            {
                "name": "Classic Oxford Shirt",
                "category": "top",
                "brand": "Everlane",
                "color": "white",
                "material": "cotton",
                "style_notes": "minimalist",
                "price": 78.0,
                "currency": "USD",
                "image_url": "https://example.com/shirt.jpg",
                "confidence": "high",
            }
        ],
    },
    {"is_fashion": False, "source_msg_id": "msg_002", "items": []},
    {
        "is_fashion": True,
        "source_msg_id": "msg_003",
        "items": [
            {"name": "Suede crossbody", "category": "bag", "confidence": "medium"},
            {
                "name": "Gold hoop earrings",
                "category": "jewelry",
                "color": "gold",
                "price": 24.99,
                "currency": "GBP",
                "confidence": "high",
            },
        ],
    },
]

INVALID_FIXTURES: list[dict[str, Any]] = [
    # category not in enum
    {
        "is_fashion": True,
        "source_msg_id": "x",
        "items": [{"name": "x", "category": "headwear", "confidence": "high"}],
    },
    # confidence not in enum
    {
        "is_fashion": True,
        "source_msg_id": "x",
        "items": [{"name": "x", "category": "top", "confidence": "certain"}],
    },
    # negative price
    {
        "is_fashion": True,
        "source_msg_id": "x",
        "items": [
            {"name": "x", "category": "top", "confidence": "high", "price": -1}
        ],
    },
    # bad currency code
    {
        "is_fashion": True,
        "source_msg_id": "x",
        "items": [
            {
                "name": "x",
                "category": "top",
                "confidence": "high",
                "currency": "dollars",
            }
        ],
    },
    # missing required source_msg_id
    {"is_fashion": False, "items": []},
    # additional property at item level
    {
        "is_fashion": True,
        "source_msg_id": "x",
        "items": [
            {
                "name": "x",
                "category": "top",
                "confidence": "high",
                "made_up_field": "nope",
            }
        ],
    },
]


@pytest.mark.parametrize("fixture", VALID_FIXTURES)
def test_valid_fixtures_pass_jsonschema(schema: dict[str, Any], fixture: dict[str, Any]) -> None:
    jsonschema.validate(instance=fixture, schema=schema)


@pytest.mark.parametrize("fixture", VALID_FIXTURES)
def test_valid_fixtures_pass_pydantic(fixture: dict[str, Any]) -> None:
    FashionPurchaseExtraction.model_validate(fixture)


@pytest.mark.parametrize("fixture", INVALID_FIXTURES)
def test_invalid_fixtures_fail_jsonschema(
    schema: dict[str, Any], fixture: dict[str, Any]
) -> None:
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(instance=fixture, schema=schema)


@pytest.mark.parametrize("fixture", INVALID_FIXTURES)
def test_invalid_fixtures_fail_pydantic(fixture: dict[str, Any]) -> None:
    with pytest.raises(ValidationError):
        FashionPurchaseExtraction.model_validate(fixture)
