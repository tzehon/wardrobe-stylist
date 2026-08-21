"""Pydantic mirrors of `shared/schemas/outfit.schema.json`.

These models are the runtime guard on every `/recommend` response. Aria's tool
output is first validated as an :class:`OutfitRecommendation`, then combined
with bounded token counts as a :class:`RecommendResponse`. The contract test in
`tests/test_outfit_schema.py` pins the JSON Schema and the wire-response model
against the same golden fixtures so they can't drift.

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


class TokenUsage(BaseModel):
    model_config = ConfigDict(extra="forbid")

    input_tokens: Annotated[int, Field(ge=0)]
    output_tokens: Annotated[int, Field(ge=0)]
    cache_creation_input_tokens: Annotated[int, Field(ge=0)]
    cache_read_input_tokens: Annotated[int, Field(ge=0)]


class RecommendResponse(OutfitRecommendation):
    usage: TokenUsage
