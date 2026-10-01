"""Shared corpus: structural JSON Schema plus Pydantic/Swift semantic checks."""

import json
from pathlib import Path
from typing import Any

import jsonschema
import pytest
from pydantic import ValidationError

from app.schemas.commerce import CommerceUsage

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / "shared/schemas/commerce-usage.schema.json").read_text())
CORPUS = json.loads((ROOT / "shared/fixtures/commerce-usage.json").read_text())


def test_schema_is_valid_and_matches_the_wire_model_shape() -> None:
    jsonschema.Draft202012Validator.check_schema(SCHEMA)
    generated = CommerceUsage.model_json_schema()
    assert {key: SCHEMA[key] for key in generated} == generated


@pytest.mark.parametrize("fixture", CORPUS["valid"], ids=lambda row: row["name"])
def test_shared_valid_snapshots(fixture: dict[str, Any]) -> None:
    value = fixture["value"]
    jsonschema.validate(value, SCHEMA)
    assert CommerceUsage.model_validate(value).model_dump(mode="json") == value


@pytest.mark.parametrize("fixture", CORPUS["invalid_structure"], ids=lambda row: row["name"])
def test_shared_structurally_invalid_snapshots(fixture: dict[str, Any]) -> None:
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(fixture["value"], SCHEMA)
    with pytest.raises(ValidationError):
        CommerceUsage.model_validate(fixture["value"])


@pytest.mark.parametrize("fixture", CORPUS["invalid_semantics"], ids=lambda row: row["name"])
def test_shared_inconsistent_counters_and_periods(fixture: dict[str, Any]) -> None:
    # Standard JSON Schema cannot compare sibling counters/timestamps. These
    # fixtures MUST also be rejected by CommerceUsageTests on iOS.
    jsonschema.validate(fixture["value"], SCHEMA)
    with pytest.raises(ValidationError):
        CommerceUsage.model_validate(fixture["value"])
