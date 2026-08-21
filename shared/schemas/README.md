# Shared schemas (data contract)

JSON Schemas here are the **single source of truth** for the data that crosses the
iOS ↔ backend boundary. Both sides validate against them so they can't drift:

- the backend validates Claude tool outputs and complete wire responses against
  language-native mirrors of these schemas before returning them;
- the iOS app encodes and decodes matching language-native wire models;
- tests on both sides assert golden fixtures conform.

Planned schemas (added with their phase):

| File | Phase | Describes |
|---|---|---|
| `category.schema.json` | 3 | the dynamic browsable taxonomy |
| `outfit.schema.json` | 5 | the complete `/recommend` response (outfit plus token usage) — **added** |
| `recommend-request.schema.json` | 5+ | the compact catalog, wear IDs, rating aggregates, and optional occasion sent to `/recommend` |

Keep field names and constraints identical to the Swift wire models in
[`ios/Wardrobe/Backend/RecommendAPI.swift`](../../ios/Wardrobe/Backend/RecommendAPI.swift) and the
backend Pydantic models in [`backend/app/`](../../backend/app/).
