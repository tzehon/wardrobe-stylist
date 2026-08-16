"""Contract parity for the compact iOS -> backend styling request."""

import json
from pathlib import Path
from typing import Any

import jsonschema
import pytest
from pydantic import ValidationError

from app.routes.recommend import RecommendRequest

SCHEMA_PATH = (
    Path(__file__).resolve().parents[2]
    / "shared"
    / "schemas"
    / "recommend-request.schema.json"
)

A = "11111111-1111-4111-8111-111111111111"
B = "22222222-2222-4222-8222-222222222222"


@pytest.fixture(scope="module")
def schema() -> dict[str, Any]:
    return json.loads(SCHEMA_PATH.read_text())


VALID_FIXTURES: list[dict[str, Any]] = [
    {
        "items": [
            {
                "id": A,
                "name": "Oxford Shirt",
                "category": "top",
                "brand": "Example",
                "colors": ["white"],
                "material": "cotton",
            },
            {"id": B, "name": "Trousers", "category": "bottom"},
        ],
        "recently_worn_ids": [B],
        "item_preferences": [
            {"id": A, "average_rating": 4.5, "rating_count": 2}
        ],
        "occasion": "work",
    },
    {
        "items": [
            {"id": A, "name": "Shirt", "category": "top"},
            {"id": B, "name": "Trousers", "category": "bottom"},
        ],
        "recently_worn_ids": [],
        "item_preferences": [],
        "occasion": None,
    },
    {
        "items": [
            {"id": A, "name": "Shirt", "category": "top"},
            {"id": B, "name": "Trousers", "category": "bottom"},
        ]
    },
]

INVALID_FIXTURES: list[dict[str, Any]] = [
    {**VALID_FIXTURES[1], "items": VALID_FIXTURES[1]["items"][:1]},
    {**VALID_FIXTURES[1], "item_preferences": [{"id": A, "average_rating": 0, "rating_count": 1}]},
    {**VALID_FIXTURES[1], "item_preferences": [{"id": A, "average_rating": 5, "rating_count": 0}]},
    {**VALID_FIXTURES[1], "occasion": "x" * 129},
    {**VALID_FIXTURES[1], "unexpected": True},
]


@pytest.mark.parametrize("fixture", VALID_FIXTURES)
def test_valid_fixtures_pass_both_contracts(
    schema: dict[str, Any], fixture: dict[str, Any]
) -> None:
    jsonschema.validate(instance=fixture, schema=schema)
    RecommendRequest.model_validate(fixture)


@pytest.mark.parametrize("fixture", INVALID_FIXTURES)
def test_invalid_fixtures_fail_both_contracts(
    schema: dict[str, Any], fixture: dict[str, Any]
) -> None:
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(instance=fixture, schema=schema)
    with pytest.raises(ValidationError):
        RecommendRequest.model_validate(fixture)
