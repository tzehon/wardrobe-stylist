"""POST /recommend — compact catalog + wear history -> a daily outfit.

The iOS app builds a compact, text-only snapshot of the catalog (item ids +
attributes, no images) plus the ids worn recently, and asks Aria for one
wearable, non-repeating look. The backend never persists any of it.

A server-side guard sanitizes Aria's output against the submitted catalog:
every returned item id must be one the caller actually sent, so a hallucinated
or stale id can never reach the app.
"""

import logging
from typing import Annotated, Any

import anthropic
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.agents import stylist
from app.agents.stylist import StylistError
from app.auth.service import BackendIdentity
from app.dependencies import get_anthropic_client, require_backend_identity
from app.schemas.recommendation import OutfitRecommendation

logger = logging.getLogger(__name__)
router = APIRouter()

ItemReference = Annotated[str, Field(min_length=1, max_length=64)]


class CatalogItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=1, max_length=64)
    name: str = Field(min_length=1, max_length=256)
    category: str = Field(min_length=1, max_length=64)
    brand: str | None = Field(default=None, max_length=128)
    colors: list[str] = Field(default_factory=list, max_length=16)
    material: str | None = Field(default=None, max_length=128)


class ItemPreference(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=1, max_length=64)
    average_rating: float = Field(ge=1, le=5)
    rating_count: int = Field(ge=1)


class RecommendRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[CatalogItem] = Field(min_length=2, max_length=1000)
    recently_worn_ids: list[ItemReference] = Field(default_factory=list, max_length=1000)
    item_preferences: list[ItemPreference] = Field(default_factory=list, max_length=1000)
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
    _: BackendIdentity = Depends(require_backend_identity),
    client: anthropic.Anthropic = Depends(get_anthropic_client),
) -> RecommendResponse:
    valid_ids = {item.id for item in req.items}
    if any(item_id not in valid_ids for item_id in req.recently_worn_ids):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Recently worn items must reference items in the submitted catalog.",
        )
    if any(preference.id not in valid_ids for preference in req.item_preferences):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Item preferences must reference items in the submitted catalog.",
        )
    try:
        result = stylist.recommend(
            client,
            items=[item.model_dump() for item in req.items],
            recently_worn_ids=req.recently_worn_ids,
            item_preferences=[preference.model_dump() for preference in req.item_preferences],
            occasion=req.occasion,
        )
    except StylistError as exc:
        logger.warning("stylist.recommend failed: %s", exc)
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    try:
        sanitized = _sanitize_outfit(result["tool_input"], valid_ids)
    except StylistError as exc:
        logger.warning("Aria returned an outfit we couldn't sanitize: %s", exc)
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    try:
        parsed = OutfitRecommendation.model_validate(sanitized)
    except ValidationError as exc:
        # Pydantic validation errors include rejected values by default, and
        # `loc` can contain an arbitrary model-supplied extra-field name. Both
        # may contain wardrobe text or identifiers, so logs retain only a
        # bounded count and the framework-defined error types.
        validation_types = sorted(
            {
                str(error["type"])
                for error in exc.errors(
                    include_url=False,
                    include_context=False,
                    include_input=False,
                )
            }
        )
        logger.warning(
            "Tool input failed schema validation: count=%d types=%s",
            exc.error_count(),
            validation_types,
        )
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            detail="Model returned tool input that failed schema validation.",
        ) from exc

    return RecommendResponse(**parsed.model_dump(), usage=result["usage"])
