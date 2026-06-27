# Shared schemas (data contract)

JSON Schemas here are the **single source of truth** for the data that crosses the
iOS ↔ backend boundary. Both sides validate against them so they can't drift:

- the backend validates Claude tool outputs against these schemas before returning them;
- the iOS app validates payloads it sends/receives;
- tests on both sides assert golden fixtures conform.

Planned schemas (added with their phase):

| File | Phase | Describes |
|---|---|---|
| `purchase.schema.json` | 2 | a structured purchase extracted from a receipt (`record_purchase`) |
| `category.schema.json` | 3 | the dynamic browsable taxonomy |
| `outfit.schema.json` | 5 | a daily outfit recommendation (`propose_outfit`) — **added** |

Keep field names and enums identical to the Swift models in
[`ios/Wardrobe/Models/`](../../ios/Wardrobe/Models) and the backend Pydantic models in
`backend/app/schemas/`.
