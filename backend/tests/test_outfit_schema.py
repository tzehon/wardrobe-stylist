"""Contract tests — JSON Schema and Pydantic must agree on the same fixtures.

If these two ever diverge, the iOS app (which decodes against the schema) and
the backend (which validates with Pydantic) will silently disagree on what
counts as a valid outfit recommendation. Keep this test green.
"""

import json
from pathlib import Path
from typing import Any

import jsonschema
import pytest
from pydantic import ValidationError

from app.schemas.recommendation import OutfitRecommendation

SCHEMA_PATH = (
    Path(__file__).resolve().parents[2] / "shared" / "schemas" / "outfit.schema.json"
)

# Stable, valid UUIDs to reference as catalog items.
A = "11111111-1111-4111-8111-111111111111"
B = "22222222-2222-4222-8222-222222222222"
C = "33333333-3333-4333-8333-333333333333"
D = "44444444-4444-4444-8444-444444444444"


@pytest.fixture(scope="module")
def schema() -> dict[str, Any]:
    return json.loads(SCHEMA_PATH.read_text())


VALID_FIXTURES: list[dict[str, Any]] = [
    # Full look with two alternates.
    {
        "occasion": "relaxed weekend",
        "color_story": "earthy neutrals with a pop of rust",
        "rationale": "The oversized tee balances the slim trouser, and suede keeps it soft.",
        "item_ids": [A, B, C],
        "alternates": [
            {"item_ids": [A, D], "rationale": "Swap in the dark denim for an evening edge."},
            {"item_ids": [B, C], "rationale": "Drop the layer when it warms up."},
        ],
    },
    # Minimal: exactly two items, no alternates.
    {
        "occasion": "smart office",
        "color_story": "monochrome charcoal",
        "rationale": "A clean, single-tone column reads sharp without effort.",
        "item_ids": [A, B],
        "alternates": [],
    },
]

INVALID_FIXTURES: list[dict[str, Any]] = [
    # Only one item in the primary look (below minItems 2).
    {
        "occasion": "x",
        "color_story": "x",
        "rationale": "x",
        "item_ids": [A],
        "alternates": [],
    },
    # Missing required rationale.
    {
        "occasion": "x",
        "color_story": "x",
        "item_ids": [A, B],
        "alternates": [],
    },
    # Unknown top-level property.
    {
        "occasion": "x",
        "color_story": "x",
        "rationale": "x",
        "item_ids": [A, B],
        "alternates": [],
        "weather": "sunny",
    },
    # Alternate missing its rationale.
    {
        "occasion": "x",
        "color_story": "x",
        "rationale": "x",
        "item_ids": [A, B],
        "alternates": [{"item_ids": [A, B]}],
    },
    # Too many alternates (above maxItems 4).
    {
        "occasion": "x",
        "color_story": "x",
        "rationale": "x",
        "item_ids": [A, B],
        "alternates": [{"item_ids": [A, B], "rationale": "r"}] * 5,
    },
    # Empty primary look.
    {
        "occasion": "x",
        "color_story": "x",
        "rationale": "x",
        "item_ids": [],
        "alternates": [],
    },
]


@pytest.mark.parametrize("fixture", VALID_FIXTURES)
def test_valid_fixtures_pass_jsonschema(schema: dict[str, Any], fixture: dict[str, Any]) -> None:
    jsonschema.validate(instance=fixture, schema=schema)


@pytest.mark.parametrize("fixture", VALID_FIXTURES)
def test_valid_fixtures_pass_pydantic(fixture: dict[str, Any]) -> None:
    OutfitRecommendation.model_validate(fixture)


@pytest.mark.parametrize("fixture", INVALID_FIXTURES)
def test_invalid_fixtures_fail_jsonschema(
    schema: dict[str, Any], fixture: dict[str, Any]
) -> None:
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(instance=fixture, schema=schema)


@pytest.mark.parametrize("fixture", INVALID_FIXTURES)
def test_invalid_fixtures_fail_pydantic(fixture: dict[str, Any]) -> None:
    with pytest.raises(ValidationError):
        OutfitRecommendation.model_validate(fixture)
