"""Aria, the daily stylist (Phase 5).

Stateless single Claude call per request:
- model: ``claude-opus-4-8`` — the most capable model, which fits a taste /
  reasoning task like outfit styling. Cost is a non-issue for a single-user app.
- ``tool_choice`` forces the ``propose_outfit`` tool so we always get a
  structured outfit back (same pattern as the extractor).
- ``cache_control: ephemeral`` on the system block caches ``tools`` + ``system``
  together (render order is tools → system → messages, so one marker on the last
  system block is enough). The styling rubric is the stable, cacheable prefix;
  the per-request catalog + wear history go in the volatile user message after
  it. Caching activates once the prefix passes Opus 4.8's ~4096-token threshold.

The backend persists nothing — the catalog and wear history live on-device on
the iOS side; we receive a compact, text-only snapshot (item ids + attributes,
no images), call Claude, and return the structured recommendation. The route
additionally rejects any item id Aria returns that wasn't in the submitted
catalog.
"""

from typing import Any

import anthropic
from anthropic.types import ToolUseBlock

MODEL = "claude-opus-4-8"
MAX_TOKENS = 2048
TOOL_NAME = "propose_outfit"

CATEGORY_ENUM = [
    "top", "bottom", "dress", "outerwear", "shoe", "bag", "jewelry", "accessory",
]

SYSTEM_PROMPT = """You are Aria, a personal stylist for a single user's wardrobe app. Each day you propose one outfit from the user's own catalog of clothing.

The iOS app sends you a compact snapshot of the catalog (each item has an id, name, category, and optionally brand, colors, and material) plus the ids of items worn in the last couple of weeks. Your job is to call the `propose_outfit` tool exactly once with a complete, wearable look.

Rules:

1. Build a real, wearable outfit from the items provided. A complete look is usually a top + bottom + shoes, or a dress + shoes, plus optional outerwear, bag, and jewelry/accessories. Use at least two items.

2. Reference items only by the exact `id` strings from the catalog — never invent an id, and never reference an item that isn't in the snapshot.

3. Don't repeat recent looks. Favor items the user hasn't worn recently (the `recently_worn_ids` list); it's fine to reuse a staple when the catalog is small, but vary the overall combination from day to day.

4. Make it cohesive: colors should work together, the formality should match the occasion (when one is given), and the pieces should plausibly be worn together.

5. Provide 1–3 `alternates` — distinct alternative looks (different mood, formality, or palette) so the user can shuffle to another option. Each alternate is a complete outfit (at least two items) with a one-line note on what makes it different. If the catalog is too small to vary meaningfully, return fewer (or no) alternates rather than near-duplicates.

6. Write the `rationale` and `color_story` in your own warm, concise voice — why this look works today. `occasion` is a short label like "relaxed weekend" or "smart office"."""

PROPOSE_OUTFIT_TOOL: dict[str, Any] = {
    "name": TOOL_NAME,
    "description": (
        "Record the outfit Aria recommends for the user today, drawn entirely from "
        "the catalog items supplied in the user message. Always called exactly once."
    ),
    "input_schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["occasion", "color_story", "rationale", "item_ids", "alternates"],
        "properties": {
            "occasion": {
                "type": "string",
                "description": "Short label for the kind of day this look suits.",
            },
            "color_story": {
                "type": "string",
                "description": "One line on the palette and how the colors play together.",
            },
            "rationale": {
                "type": "string",
                "description": "Why this outfit works, in Aria's voice.",
            },
            "item_ids": {
                "type": "array",
                "description": "Catalog item ids making up the primary look (top, bottom, shoe, ...).",
                "minItems": 2,
                "maxItems": 8,
                "items": {"type": "string"},
            },
            "alternates": {
                "type": "array",
                "description": "Alternative complete looks for 'show me another'. May be empty.",
                "maxItems": 4,
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["item_ids", "rationale"],
                    "properties": {
                        "item_ids": {
                            "type": "array",
                            "minItems": 2,
                            "maxItems": 8,
                            "items": {"type": "string"},
                        },
                        "rationale": {
                            "type": "string",
                            "description": "What makes this alternative distinct.",
                        },
                    },
                },
            },
        },
    },
}


class StylistError(RuntimeError):
    """Raised when Claude's response isn't usable (missing tool call, bad shape, etc.)."""


def _format_item(item: dict[str, Any]) -> str:
    """One compact line per catalog item — id first so Aria can echo it verbatim."""
    parts = [f"id={item['id']}", f"category={item['category']}", f"name={item['name']}"]
    if item.get("brand"):
        parts.append(f"brand={item['brand']}")
    colors = item.get("colors") or []
    if colors:
        parts.append("colors=" + "/".join(colors))
    if item.get("material"):
        parts.append(f"material={item['material']}")
    return "- " + ", ".join(parts)


def build_user_message(
    *,
    items: list[dict[str, Any]],
    recently_worn_ids: list[str],
    occasion: str | None,
) -> str:
    """Compose the single user-turn string: the compact catalog + wear history + context."""
    lines: list[str] = []
    if occasion:
        lines.append(f"Occasion: {occasion}")
    lines.append(
        "Recently worn item ids (avoid repeating these looks): "
        + (", ".join(recently_worn_ids) if recently_worn_ids else "none")
    )
    lines.append("")
    lines.append("Catalog:")
    lines.extend(_format_item(item) for item in items)
    lines.append("")
    lines.append("Propose today's outfit by calling propose_outfit exactly once.")
    return "\n".join(lines)


def recommend(
    client: anthropic.Anthropic,
    *,
    items: list[dict[str, Any]],
    recently_worn_ids: list[str],
    occasion: str | None,
) -> dict[str, Any]:
    """Run one recommendation. Returns ``{"tool_input": dict, "usage": dict}``.

    Raises :class:`StylistError` if the model fails to call ``propose_outfit``
    or the tool input isn't a JSON object.
    """
    user_message = build_user_message(
        items=items, recently_worn_ids=recently_worn_ids, occasion=occasion
    )
    # The Anthropic SDK's `messages.create` overloads are typed with strict TypedDicts that
    # don't cover every JSON-Schema-valid input shape (e.g. `additionalProperties`/`minItems`
    # aren't in `InputSchemaParam`). Runtime behaviour is correct and exercised by tests.
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
        tools=[PROPOSE_OUTFIT_TOOL],
        tool_choice={"type": "tool", "name": TOOL_NAME},
        messages=[{"role": "user", "content": user_message}],
    )

    tool_block: ToolUseBlock | None = None
    for block in response.content:
        if isinstance(block, ToolUseBlock) and block.name == TOOL_NAME:
            tool_block = block
            break
    if tool_block is None:
        raise StylistError(f"Model did not call {TOOL_NAME}")
    if not isinstance(tool_block.input, dict):
        raise StylistError(f"{TOOL_NAME} input was not a JSON object")

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
