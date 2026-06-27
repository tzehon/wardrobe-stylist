"""Pydantic mirrors of `shared/schemas/outfit.schema.json`.

These models are the runtime guard on every `/recommend` response — Aria's tool
output is validated through them before anything leaves the backend. The
contract test in `tests/test_outfit_schema.py` pins the JSON Schema and these
classes against the same golden fixtures so they can't drift.

Item references are catalog UUIDs (validated as non-empty strings here; the
route additionally rejects any id the caller didn't supply).
"""

from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

ItemId = Annotated[str, Field(min_length=1)]


class AlternateOutfit(BaseModel):
    model_config = ConfigDict(extra="forbid")

    item_ids: Annotated[list[ItemId], Field(min_length=2, max_length=8)]
    rationale: Annotated[str, Field(min_length=1)]


class OutfitRecommendation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    occasion: Annotated[str, Field(min_length=1)]
    color_story: Annotated[str, Field(min_length=1)]
    rationale: Annotated[str, Field(min_length=1)]
    item_ids: Annotated[list[ItemId], Field(min_length=2, max_length=8)]
    alternates: Annotated[list[AlternateOutfit], Field(max_length=4)]
