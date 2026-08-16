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
from app.anthropic_safety import anthropic_request_slot, raise_anthropic_http_error
from app.auth.service import BackendIdentity
from app.dependencies import get_anthropic_client, require_backend_identity
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
    _: BackendIdentity = Depends(require_backend_identity),
    client: anthropic.Anthropic = Depends(get_anthropic_client),
) -> ExtractResponse:
    try:
        safe_subject = extractor.redact_transport_metadata(
            req.subject, source_msg_id=req.source_msg_id, sender=req.sender
        )
        safe_snippet = extractor.redact_transport_metadata(
            req.snippet, source_msg_id=req.source_msg_id, sender=req.sender
        )
        if safe_snippet is None:
            # ``snippet`` is required by the wire schema, so this indicates an
            # internal preprocessing contract regression. Fail closed without
            # forwarding unredacted receipt content or logging caller data.
            logger.error("Receipt snippet preprocessing returned no content.")
            raise HTTPException(
                status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Receipt preprocessing failed.",
            )
        with anthropic_request_slot():
            result = extractor.extract(
                client,
                sender_domain=extractor.sender_domain(req.sender),
                subject=safe_subject,
                snippet=safe_snippet,
            )
    except anthropic.APIError as exc:
        raise_anthropic_http_error(exc)
    except ExtractorError as exc:
        logger.warning("extractor.extract failed: %s", exc)
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    tool_input = dict(result["tool_input"])
    # The source id is transport metadata and never crosses the model boundary.
    # Add it only here so the installed iOS client's response contract remains stable.
    tool_input.pop("source_msg_id", None)
    tool_input["source_msg_id"] = req.source_msg_id
    # Belt-and-braces: drop any items if the model claimed not-fashion.
    if not tool_input.get("is_fashion", False):
        tool_input["items"] = []

    try:
        parsed = FashionPurchaseExtraction.model_validate(tool_input)
    except ValidationError as exc:
        # Pydantic includes the complete rejected input in `errors()` by default.
        # That input contains caller-owned Gmail correlation metadata and may
        # contain receipt-derived product text, neither of which belongs in logs.
        # Do not log `loc` either: an `extra_forbidden` location may contain an
        # arbitrary model-supplied property name and therefore user data.
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

    return ExtractResponse(**parsed.model_dump(), usage=result["usage"])
