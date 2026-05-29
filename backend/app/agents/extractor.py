"""Fashion-purchase extractor (Phase 2a).

Stateless single Claude call per request:
- model: ``claude-haiku-4-5`` — right cost/speed point for structured extraction
- ``tool_choice`` forces the ``record_purchase`` tool so we always get structured input
- ``cache_control: ephemeral`` on the system block caches ``tools`` + ``system``
  together (render order is tools → system → messages, so one marker on the
  last system block is enough). Caching activates once the stable prefix passes
  Haiku 4.5's ~4096-token threshold — the markers are wired now; cache hits
  show up in ``usage.cache_read_input_tokens`` as the system prompt grows.

The backend persists nothing — email content lives only on-device on the iOS
side; we receive the minimal snippet, call Claude, and return the structured
result.
"""

from typing import Any

import anthropic
from anthropic.types import ToolUseBlock

MODEL = "claude-haiku-4-5"
MAX_TOKENS = 2048
TOOL_NAME = "record_purchase"

SYSTEM_PROMPT = """You extract fashion purchases from receipt email snippets for a personal-wardrobe app.

The iOS app has already filtered the user's Gmail to candidate receipts on-device, stripped the HTML to a minimal snippet, and sent only that snippet (plus optionally the sender and subject). Your job is to call the `record_purchase` tool exactly once with the structured result.

Rules:

1. Fashion = clothing, footwear, bags, jewelry, or accessories worn on the person. Electronics, groceries, household goods, services, books, and gift cards are NOT fashion: set `is_fashion: false` and emit `items: []`.

2. Map `category` to the controlled vocabulary exactly: `top` | `bottom` | `dress` | `outerwear` | `shoe` | `bag` | `jewelry` | `accessory`. If a fashion item doesn't map cleanly, choose the closest category and mark `confidence: low`.

3. Only fill optional fields you can read directly from the snippet. Leave `brand`, `color`, `material`, `style_notes`, `price`, `currency`, `image_url` as null when uncertain — never guess. `currency` is the 3-letter ISO code (USD, GBP, EUR, ...).

4. `confidence` per item: `high` when every required field is unambiguous in the snippet, `medium` when category and name are clear but one or two optional fields are inferred, `low` when even the core fields are uncertain.

5. Echo `source_msg_id` verbatim from the user message.

6. One entry per distinct product line. Two of the same shirt in different sizes is one entry; the iOS catalog dedupes upstream.

7. Skip shipping, gift wrap, samples, and free promo items."""

RECORD_PURCHASE_TOOL: dict[str, Any] = {
    "name": TOOL_NAME,
    "description": (
        "Record the fashion items extracted from a single receipt email. Always called "
        "exactly once per request, even if the email turns out not to be a fashion purchase "
        "(in which case items is an empty array)."
    ),
    "input_schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["is_fashion", "items", "source_msg_id"],
        "properties": {
            "is_fashion": {
                "type": "boolean",
                "description": "True iff this email represents a fashion purchase.",
            },
            "source_msg_id": {
                "type": "string",
                "description": "Gmail message id from the user message, echoed verbatim.",
            },
            "items": {
                "type": "array",
                "description": "Fashion items in the order; empty when is_fashion is false.",
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["name", "category", "confidence"],
                    "properties": {
                        "name": {"type": "string", "minLength": 1},
                        "category": {
                            "type": "string",
                            "enum": [
                                "top", "bottom", "dress", "outerwear",
                                "shoe", "bag", "jewelry", "accessory",
                            ],
                        },
                        "confidence": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                        },
                        "brand": {"type": ["string", "null"]},
                        "color": {"type": ["string", "null"]},
                        "material": {"type": ["string", "null"]},
                        "style_notes": {"type": ["string", "null"]},
                        "price": {"type": ["number", "null"], "minimum": 0},
                        "currency": {
                            "type": ["string", "null"],
                            "pattern": "^[A-Z]{3}$",
                        },
                        "image_url": {"type": ["string", "null"]},
                    },
                },
            },
        },
    },
}


class ExtractorError(RuntimeError):
    """Raised when Claude's response isn't usable (missing tool call, bad shape, etc.)."""


def build_user_message(
    *, source_msg_id: str, sender: str | None, subject: str | None, snippet: str
) -> str:
    """Compose the single user-turn string. Kept tiny on purpose — Tier 0/1 work happens on-device."""
    parts: list[str] = []
    if sender:
        parts.append(f"From: {sender}")
    if subject:
        parts.append(f"Subject: {subject}")
    parts.append(f"Source message id: {source_msg_id}")
    parts.append("")
    parts.append(snippet)
    return "\n".join(parts)


def extract(
    client: anthropic.Anthropic,
    *,
    source_msg_id: str,
    sender: str | None,
    subject: str | None,
    snippet: str,
) -> dict[str, Any]:
    """Run one extraction. Returns ``{"tool_input": dict, "usage": dict}``.

    Raises :class:`ExtractorError` if the model fails to call ``record_purchase``
    or the tool input isn't a JSON object.
    """
    user_message = build_user_message(
        source_msg_id=source_msg_id, sender=sender, subject=subject, snippet=snippet
    )
    # The Anthropic SDK's `messages.create` overloads are typed with strict TypedDicts that
    # don't cover every JSON-Schema-valid input shape (e.g. `additionalProperties` isn't in
    # `InputSchemaParam`). Runtime behaviour is correct and exercised by tests.
    response = client.messages.create(  # type: ignore[call-overload]
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=[
            {
                "type": "text",
                "text": SYSTEM_PROMPT,
                # Caches tools + system together (tools render before system).
                "cache_control": {"type": "ephemeral"},
            }
        ],
        tools=[RECORD_PURCHASE_TOOL],
        tool_choice={"type": "tool", "name": TOOL_NAME},
        messages=[{"role": "user", "content": user_message}],
    )

    tool_block: ToolUseBlock | None = None
    for block in response.content:
        if isinstance(block, ToolUseBlock) and block.name == TOOL_NAME:
            tool_block = block
            break
    if tool_block is None:
        raise ExtractorError(f"Model did not call {TOOL_NAME}")
    if not isinstance(tool_block.input, dict):
        raise ExtractorError(f"{TOOL_NAME} input was not a JSON object")

    usage = response.usage
    return {
        "tool_input": dict(tool_block.input),
        "usage": {
            "input_tokens": usage.input_tokens,
            "output_tokens": usage.output_tokens,
            "cache_creation_input_tokens": getattr(
                usage, "cache_creation_input_tokens", 0
            ) or 0,
            "cache_read_input_tokens": getattr(
                usage, "cache_read_input_tokens", 0
            ) or 0,
        },
    }
