"""POST /recommend — compact catalog + wear history -> a daily outfit.

The iOS app builds a compact, text-only snapshot of the catalog (item ids +
attributes, no images) plus the ids worn recently, and asks Aria for one
wearable, non-repeating look. The backend never persists any of it.

A server-side guard sanitizes Aria's output against the submitted catalog:
every returned item id must be one the caller actually sent, so a hallucinated
or stale id can never reach the app.
"""

import logging
from typing import Any

import anthropic
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, ValidationError

from app.agents import stylist
from app.agents.stylist import StylistError
from app.dependencies import get_anthropic_client, require_device_token
from app.schemas.recommendation import OutfitRecommendation

logger = logging.getLogger(__name__)
router = APIRouter()


class CatalogItem(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    name: str = Field(min_length=1, max_length=256)
    category: str = Field(min_length=1, max_length=64)
    brand: str | None = Field(default=None, max_length=128)
    colors: list[str] = Field(default_factory=list, max_length=16)
    material: str | None = Field(default=None, max_length=128)


class RecommendRequest(BaseModel):
    items: list[CatalogItem] = Field(min_length=2, max_length=1000)
    recently_worn_ids: list[str] = Field(default_factory=list, max_length=1000)
    occasion: str | None = Field(default=None, max_length=128)


class RecommendResponse(OutfitRecommendation):
    usage: dict[str, int]


def _sanitize_ids(ids: list[str], valid: set[str]) -> list[str]:
    """Keep only ids present in the catalog, de-duplicated, preserving order."""
    seen: set[str] = set()
    out: list[str] = []
    for item_id in ids:
        if item_id in valid and item_id not in seen:
            seen.add(item_id)
            out.append(item_id)
    return out


def _sanitize_outfit(tool_input: dict[str, Any], valid_ids: set[str]) -> dict[str, Any]:
    """Drop any item id the caller didn't send; drop alternates left with < 2 items.

    Mutates a copy of the model's tool input into something that should pass the
    OutfitRecommendation schema, or raises if the primary look can't be salvaged.
    """
    primary = _sanitize_ids(tool_input.get("item_ids", []), valid_ids)
    if len(primary) < 2:
        raise StylistError("Primary outfit had fewer than 2 valid catalog items.")

    alternates = []
    for alt in tool_input.get("alternates", []) or []:
        alt_ids = _sanitize_ids(alt.get("item_ids", []), valid_ids)
        if len(alt_ids) >= 2:
            alternates.append({"item_ids": alt_ids, "rationale": alt.get("rationale", "")})

    return {**tool_input, "item_ids": primary, "alternates": alternates[:4]}


@router.post("/recommend", response_model=RecommendResponse)
def recommend_endpoint(
    req: RecommendRequest,
    _: None = Depends(require_device_token),
    client: anthropic.Anthropic = Depends(get_anthropic_client),
) -> RecommendResponse:
    try:
        result = stylist.recommend(
            client,
            items=[item.model_dump() for item in req.items],
            recently_worn_ids=req.recently_worn_ids,
            occasion=req.occasion,
        )
    except StylistError as exc:
        logger.warning("stylist.recommend failed: %s", exc)
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    valid_ids = {item.id for item in req.items}
    try:
        sanitized = _sanitize_outfit(result["tool_input"], valid_ids)
    except StylistError as exc:
        logger.warning("Aria returned an outfit we couldn't sanitize: %s", exc)
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    try:
        parsed = OutfitRecommendation.model_validate(sanitized)
    except ValidationError as exc:
        logger.warning("Tool input failed schema validation: %s", exc.errors())
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            detail="Model returned tool input that failed schema validation.",
        ) from exc

    return RecommendResponse(**parsed.model_dump(), usage=result["usage"])
