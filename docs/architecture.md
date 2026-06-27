# Architecture

Wardrobe Stylist is a **local-first, privacy-first** personal app. Almost everything
happens on the iPhone; a thin stateless backend exists only to hold the Anthropic API key
and call Claude. This document explains the components, the data flows, and how the
**read-only Gmail** and **hybrid-privacy** guarantees are realized.

- [System overview](#system-overview)
- [Privacy & trust boundaries](#privacy--trust-boundaries)
- [Receipt extraction pipeline](#receipt-extraction-pipeline-gmail--catalog)
- [Daily recommendation flow](#daily-recommendation-flow)
- [Data model](#data-model)
- [Read-only Gmail guarantee](#read-only-gmail-guarantee)
- [Tech stack](#tech-stack)
- [Deployment topology](#deployment-topology)

## System overview

Three actors: the **iPhone** (does the real work), **Google** (OAuth + read-only Gmail),
and a **stateless backend** that proxies to the **Anthropic API**.

```mermaid
flowchart TB
    subgraph Device["iPhone — on-device (privacy boundary)"]
        UI["SwiftUI app<br/>catalog · Today · capture"]
        Store[("SwiftData<br/>Item · Outfit · WearLog<br/>images on disk")]
        Gmail["GmailReadOnlyClient<br/>read-only endpoints only"]
        Filter["Candidate filter<br/>schema.org · Vision OCR"]
        VisionML["Vision<br/>cutout · color · feature-print"]
        Keychain[["Keychain<br/>OAuth tokens · device token"]]
        UI --- Store
        Gmail --> Filter
        Filter --> Store
        VisionML --> Store
        Gmail -. tokens .- Keychain
    end

    subgraph Google["Google"]
        OAuth["OAuth<br/>scope: gmail.readonly"]
        GmailAPI["Gmail REST API<br/>read endpoints"]
    end

    subgraph Cloud["Backend on Fly.io — stateless"]
        API["FastAPI proxy<br/>/extract · /categorize · /recommend"]
        Key[["ANTHROPIC_API_KEY<br/>secret, never on device"]]
        API -. reads .- Key
    end

    Anthropic["Anthropic API<br/>Haiku · Sonnet · Opus"]

    Gmail <-->|GET only| GmailAPI
    Gmail -. OAuth .-> OAuth
    Filter -->|minimal text + few images<br/>Bearer device token| API
    API --> Anthropic
```

**Key idea:** raw email never leaves the phone. On-device filtering reduces a mailbox to a
few candidate receipts, and only **minimal extracted text** (plus the occasional product
image) is sent to the backend. The backend keeps no email data.

## Privacy & trust boundaries

```mermaid
flowchart LR
    subgraph OnDevice["Stays on device"]
        direction TB
        Mail["Full email bodies"]
        Imgs["Item photos"]
        Cat["Catalog + wear history"]
        Tok["OAuth + device tokens (Keychain)"]
    end

    subgraph Leaves["Leaves device (minimized)"]
        direction TB
        Snip["Minimal receipt snippets"]
        Few["A few product/item images"]
        Attrs["Item attributes (ids, colors, categories)"]
    end

    OnDevice -->|on-device filtering| Leaves
    Leaves -->|HTTPS + Bearer| Backend["Backend (no persistence)"]
    Backend --> LLM["Claude (Anthropic)"]
```

| Data | Where it lives | Leaves device? |
|---|---|---|
| Full email bodies | Phone (transient, during sync) | ❌ never |
| OAuth + device tokens | Keychain | ❌ never |
| Catalog, images, wear history | SwiftData + on-disk | ❌ never (optional iCloud later) |
| Minimal receipt snippets | sent to backend → Claude | ✅ minimized |
| Item attributes for styling | sent to backend → Claude | ✅ ids + attributes |

## Receipt extraction pipeline (Gmail → catalog)

A tiered pipeline: deterministic and free on-device first, Claude only for the long tail.
See the design rationale in the plan — dedicated receipt parsers are the wrong tool for
*HTML order emails* and *fashion attributes*.

```mermaid
flowchart TD
    A["New email (on-device)"] --> B{"Tier 0:<br/>likely purchase?"}
    B -- no --> X["Ignore — stays on device"]
    B -- yes --> C{"Tier 1:<br/>schema.org JSON-LD<br/>or microdata present?"}
    C -- found --> D["Deterministic fields:<br/>item · brand · price · image URL"]
    C -- none --> E["Strip HTML to minimal snippet<br/>Vision OCR for PDF/image attachments"]
    D --> F{"Need fashion<br/>attributes?"}
    E --> G["Tier 2: POST /extract<br/>Claude Haiku · record_purchase tool"]
    F -- yes --> G
    F -- no --> H["Create Item (source = email)"]
    G --> I{"Validate vs schema<br/>+ confidence"}
    I -- high --> H
    I -- low --> J["Queue for 1-tap confirm"]
    J --> H
    H --> K[("Catalog (SwiftData)")]
```

### Dedup

Ingestion dedups **catalog-wide** on a normalized `brand + name + category`
identity (scoped to email-sourced items), not per-email. One order often arrives
across several emails — an order confirmation *and* a dispatch email, sometimes
via a fulfiller like Global-e — each listing the same product; identity dedup
collapses them into a single catalog entry and keeps re-syncs idempotent. A sweep
at the start of each sync also heals any duplicates already in the store.

## Catalog browse (Phase 3)

The catalog UI reads the SwiftData store the pipeline populates — no backend
involved. Grouping, filtering, and sorting live in pure, unit-tested helpers
(`CatalogOrganizer`, `CatalogFilter`) so the SwiftUI views stay thin.

- **Dynamic categories** — sections are derived from the data; known fashion
  categories sort in a canonical order, unknown/blank ones (`uncategorized`)
  after, alphabetically.
- **Browse** — `CatalogView` shows an adaptive grid grouped by category with
  pinned headers; `.searchable` (name/brand), category filter chips, and a sort
  menu (recent / name / brand). Items are deletable via context menu and from the
  detail view (with confirmation).
- **Images** — `ItemThumbnail` renders a local image (Phase 4 photo capture) →
  the receipt's `imageURL` via `AsyncImage` → a category-symbol placeholder.
- **Detail** — `ItemDetailView`: brand, color swatches, material, purchase date,
  and source.

See [`ios/Wardrobe/Views/`](../ios/Wardrobe/Views).

## Manual photo capture (Phase 4)

Add items that never came from a receipt — photograph a garment (camera) or pick
one from the library (`PhotosPicker`), fill in a short form, and save it as a
`source = .photo` `Item`. `ImageProcessor` (pure UIKit) downscales to a bounded
full image + thumbnail stored on the item, so the same `ItemThumbnail` that
renders email items shows the real photo. Camera capture is device-only and
declares `NSCameraUsageDescription`; library picking needs no permission key.
Vision subject-lift / feature-print are intentionally out of scope here.

See [`ios/Wardrobe/Capture/`](../ios/Wardrobe/Capture).

## Daily recommendation flow (Phase 5)

The stylist agent **"Aria"** proposes one wearable, non-repeating outfit from the
user's own catalog. v1 is a **single Claude Opus 4.8 call** with a forced
`propose_outfit` tool (the cached styling rubric is the stable prefix; the
per-request catalog rides in the user message) — no subagents and no weather
yet. The app sends only a **compact, text-only** snapshot (item ids + attributes,
no images) plus the ids worn in the last ~14 days; the backend persists nothing.

```mermaid
sequenceDiagram
    actor User
    participant App as iOS app
    participant API as FastAPI /recommend
    participant Aria as Claude Opus 4.8 — Aria

    User->>App: Open "Today"
    App->>App: Compact catalog + recent-worn ids (WearLog)
    App->>API: POST /recommend (Bearer device token)
    API->>Aria: propose_outfit (forced tool · cached rubric)
    Aria-->>API: outfit + alternates + rationale (structured)
    API->>API: Guard — drop any id not in the submitted catalog
    API-->>App: Outfit + alternates + rationale
    App->>App: Resolve ids → Items; render look
    User->>App: "Wear this"
    App->>App: Persist Outfit + per-item WearLog (feeds anti-repeat)
```

On-device, `CatalogCompactor` builds the payload, `WearHistory` derives the
recent-worn ids, and `OutfitRecommender` resolves Aria's returned ids back to
`Item`s. "Show me another" cycles the returned alternates without a new call.
The server-side guard (`/recommend`) rejects any id Aria didn't receive, so a
hallucinated or stale id can never reach the app. **Weather (WeatherKit) and a
multi-subagent composer are deferred** — the request struct leaves room for a
weather field without a breaking change.

See [`ios/Wardrobe/Stylist/`](../ios/Wardrobe/Stylist) and
[`backend/app/agents/stylist.py`](../backend/app/agents/stylist.py).

## Data model

SwiftData models (optionals and collections noted in prose to keep the diagram readable).

```mermaid
classDiagram
    class Item {
        UUID id
        String name
        String category
        String brand
        String colors
        ItemSource source
        Date purchaseDate
        Data featurePrint
    }
    class Outfit {
        UUID id
        Date createdAt
        String occasion
        String colorStory
    }
    class WearLog {
        UUID id
        Date date
        Int feedback
    }
    Item "1" --> "many" WearLog : wears
    Outfit "many" --> "many" Item : items
    WearLog "many" --> "one" Item : item
    WearLog "many" --> "one" Outfit : outfit
```

- `Item.source` is `email | photo | manual`. `brand`, `subcategory`, `material`,
  `styleNotes`, `purchaseDate`, `sourceMsgId`, `imageURL`, image data, and
  `featurePrint` are optional. `imageURL` is the product image from the receipt,
  loaded on demand in the catalog (local image data, when present, takes priority).
- `colors` is `[String]`; images use `@Attribute(.externalStorage)`.
- `featurePrint` is an archived `VNFeaturePrintObservation` used for visual
  similarity/dedup (compare via `computeDistance(_:to:)`, not as a plain vector).

See [`ios/Wardrobe/Models/`](../ios/Wardrobe/Models).

## Read-only Gmail guarantee

Two independent layers (see [`docs/privacy.md`](privacy.md) and the guard test):

1. **Structural.** All Gmail traffic is expressed through
   [`GmailReadEndpoint`](../ios/Wardrobe/Gmail/GmailReadEndpoint.swift) — an enum whose
   every case is an HTTP **GET** to a read path. There is no case for any mutating
   operation, so a write request is *unrepresentable*. The only OAuth scope requested is
   `gmail.readonly` ([`GmailScope`](../ios/Wardrobe/Gmail/GmailScope.swift)).
2. **Test backstop.**
   [`GmailReadOnlyGuardTests`](../ios/WardrobeTests/GmailReadOnlyGuardTests.swift) asserts
   the scope set, that every endpoint is a GET on the allowlist, and scans the Gmail source
   directory for any mutating HTTP method or write path fragment. CI keeps it green.

## Tech stack

| Layer | Technology |
|---|---|
| iOS UI | SwiftUI (iOS 18 target, min 17) |
| Persistence | SwiftData; images via `.externalStorage` |
| Gmail auth | GoogleSignIn-iOS (scope `gmail.readonly`), tokens in Keychain |
| Gmail API | URLSession → read-only REST endpoints |
| On-device ML | Vision (subject lift, color, feature-print), Vision OCR |
| Context | WeatherKit, EventKit |
| Backend | FastAPI + Anthropic SDK (uv, ruff, mypy, pytest) |
| AI | Claude Haiku 4.5 (extraction) / Opus 4.8 (stylist "Aria"); tool use + prompt caching |
| Tests | Swift Testing, swift-snapshot-testing, pytest |
| CI | GitHub Actions (+ Xcode Cloud for TestFlight) |

## Deployment topology

```mermaid
flowchart LR
    Dev["Developer Mac<br/>Xcode · uv"] -->|TestFlight / device| Phone["iPhone (the app)"]
    Dev -->|fly deploy| Fly["Fly.io<br/>FastAPI"]
    Phone <-->|HTTPS Bearer| Fly
    Fly -->|HTTPS| Anthropic["Anthropic API"]
    Phone <-->|HTTPS OAuth + GET| Google["Google / Gmail"]
```

- The backend stores secrets as Fly.io secrets (`ANTHROPIC_API_KEY`, `DEVICE_TOKEN`).
- The app stores only the user's OAuth tokens and the backend device token (Keychain).
