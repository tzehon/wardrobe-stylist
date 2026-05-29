"""POST /extract — receipt snippet -> structured fashion purchase(s).

The iOS app filters Gmail and parses receipts on-device (Tier 0/1). When it
needs the LLM (Tier 2 — long-tail emails / fashion attribute enrichment) it
calls this endpoint with the minimal snippet. The backend never persists email
content.
"""

import logging

import anthropic
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, ValidationError

from app.agents import extractor
from app.agents.extractor import ExtractorError
from app.dependencies import get_anthropic_client, require_device_token
from app.schemas.purchase import FashionPurchaseExtraction

logger = logging.getLogger(__name__)
router = APIRouter()


class ExtractRequest(BaseModel):
    source_msg_id: str = Field(min_length=1, max_length=256)
    sender: str | None = Field(default=None, max_length=512)
    subject: str | None = Field(default=None, max_length=512)
    snippet: str = Field(
        min_length=1,
        max_length=8000,
        description="On-device-stripped receipt text; HTML and boilerplate already removed.",
    )


class ExtractResponse(FashionPurchaseExtraction):
    usage: dict[str, int]


@router.post("/extract", response_model=ExtractResponse)
def extract_endpoint(
    req: ExtractRequest,
    _: None = Depends(require_device_token),
    client: anthropic.Anthropic = Depends(get_anthropic_client),
) -> ExtractResponse:
    try:
        result = extractor.extract(
            client,
            source_msg_id=req.source_msg_id,
            sender=req.sender,
            subject=req.subject,
            snippet=req.snippet,
        )
    except ExtractorError as exc:
        logger.warning("extractor.extract failed: %s", exc)
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    tool_input = result["tool_input"]
    # Trust the caller's id over whatever the model echoed — protects against
    # the model rewriting or hallucinating the source id.
    tool_input["source_msg_id"] = req.source_msg_id
    # Belt-and-braces: drop any items if the model claimed not-fashion.
    if not tool_input.get("is_fashion", False):
        tool_input["items"] = []

    try:
        parsed = FashionPurchaseExtraction.model_validate(tool_input)
    except ValidationError as exc:
        logger.warning("Tool input failed schema validation: %s", exc.errors())
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            detail="Model returned tool input that failed schema validation.",
        ) from exc

    return ExtractResponse(**parsed.model_dump(), usage=result["usage"])
