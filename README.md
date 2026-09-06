# Wardrobe Stylist

A **personal, privacy-first** iOS app for cataloging clothing manually or from photos, browsing a
local wardrobe, and optionally asking **Aria** for a non-repeating daily outfit. Public v1 does not
connect to Google, read Gmail, import receipts, or require an account.

The approved launch is **Free, Singapore only, version 1.0.0 / Build 7**, with no in-app
purchases or subscriptions. Transparent freemium in Singapore comes next; country expansion
follows only after its pricing, budget controls, and operations are proven.

## Non-negotiable constraints

- 🔒 **Local-first catalog.** Wardrobe items, selected photos, outfits, and wear history stay on
  the device. There is no developer-operated wardrobe sync in v1.
- 🕵️ **Optional, minimized AI.** Styling happens only after an explicit action and consent. The app
  sends compact text attributes and recent-wear summaries—not wardrobe photos—to the backend and
  Anthropic; the developer application does not persist the request or response payload.
- 🛡️ **Anonymous backend access.** Apple App Attest authorizes one installation without a human
  account. Local wardrobe and Demo Mode remain available when connected AI is unavailable.
- ✅ **Tests at every stage.** Every feature ships with tests, run before moving on; CI runs them on every push.

## Repository layout

```
wardrobe-stylist/
├─ ios/         SwiftUI + SwiftData app (photos, local catalog, stylist UI)
├─ backend/     Python FastAPI proxy that holds the Anthropic key and calls Claude
├─ shared/      JSON Schemas shared by iOS + backend (the data contract)
├─ docs/        Setup + architecture docs (start here)
└─ .github/     CI workflows
```

## Quick start

See **[`docs/setup.md`](docs/setup.md)** for the full, step-by-step setup. TL;DR:

```bash
# Backend
cd backend && uv sync --locked && uv run --locked pytest && uv run --locked pip-audit && uv run --locked bandit -r app container_entrypoint.py -q && uv run --locked ruff check . && uv run --locked mypy app

# iOS (generates Wardrobe.xcodeproj from project.yml, then runs tests)
cd ios && xcodegen generate
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'   # or any installed iPhone sim
```

## Documentation

| Doc | What |
|---|---|
| [`docs/setup.md`](docs/setup.md) | End-to-end dev setup (Xcode, uv, App Attest, Anthropic key, Fly.io) |
| [`docs/architecture.md`](docs/architecture.md) | System architecture with diagrams (components, data flow, sequences) |
| [`docs/model-evaluation.md`](docs/model-evaluation.md) | Fictional model quality, latency, cost, and cache evaluation; paid-call approval procedure |
| [`docs/ai-spend-controls.md`](docs/ai-spend-controls.md) | Durable monthly AI ceiling, private provisioning, alerts, and disable/recovery procedure |
| [`docs/google-setup.md`](docs/google-setup.md) | Historical/deferred read-only Gmail OAuth setup; not used by public v1 |
| [`docs/privacy.md`](docs/privacy.md) | Current local-first and App Attest privacy architecture |
| [`docs/app-release-backlog.md`](docs/app-release-backlog.md) | App fixes, polish, features, and App Store readiness checklist |
| [`docs/gcp-oauth-production-sequence.md`](docs/gcp-oauth-production-sequence.md) | Historical/deferred Google OAuth production sequence; not a v1 release gate |
| [`docs/app-store/`](docs/app-store/) | Draft privacy/support copy, data inventory, review notes, metadata, and screenshot narrative |
| [`AGENTS.md`](AGENTS.md) | Durable guidance for Codex and other coding agents in this repo |

## Status

The approved public-v1 cut is manual/photo cataloging, browse/edit/history, local reminders,
offline Demo Mode, and optional AI styling protected by App Attest. The earlier read-only Gmail/
receipt-import subsystem has been removed from active v1 source and is deferred to a separately
reviewed future release.

The local backend candidate uses pinned `claude-haiku-4-5-20251001` with Anthropic SDK 1.4.0,
the synchronous Messages API at the standard service tier, strict forced tool output,
no extended thinking or retries, and
a default 1,024-token response limit. Prompt caching is off until measured reads justify it.
A separate SQLite accounting store reserves worst-case cost before each request, enforces a
global monthly admission/spend ceiling and concurrency, and retains uncertain charges across
restarts. It stores no wardrobe, prompt, response, or installation payload. Remote styling is
disabled by default until an explicit private budget is provisioned and enabled.

This candidate is **local and not deployed**. Both full Haiku evaluations and the first Sonnet 5
comparison failed the fixed automatic quality gate. Sonnet completed all 28 calls on
6 September 2026 for US$0.333305 before tax: complete and distinct looks passed 24/24, but
required alternates passed only 23/24. P95 latency was 13.266 seconds. A general clarification
that optional-item changes can create distinct alternates is implemented and fully tested;
no acceptance threshold changed. Sonnet's warm cache pair saved about 20% of input cost, but
production reuse remains unproven and caching stays off. No paid call is running; a revised run needs
separate approval of 28 calls and an additional US$58 pre-tax ceiling (US$0.92 planning estimate).
Its evaluation profile does not switch the production model or the Haiku-priced budget controls.
Human quality acceptance, owner budget approval, public capacity/operations acceptance, source
review, and verified deployment remain open before Build 7 distribution. The earlier timeout's
cost remains unconfirmed, conservatively bounded by US$0.205120; a separate successful diagnostic
cost US$0.004222. See the [evaluation record](docs/model-evaluation.md#sonnet-5-comparison--completed-and-failed).
No new iOS build is needed: the request/response schemas and shipped iOS sources are unchanged.
The preserved Build 7 archive still needs fresh operational review, owner-approved upload, Apple
processing, internal assignment, and its clean physical visual retest. Snapshot expiry remains a
separate deletion/recovery evidence gate.

Optional-alternate prompt verification on 6 September 2026 passed 472 backend tests plus dependency/security/lint/type
checks, 226 Swift tests and all 10 UI tests, 44 release-script tests, the Release simulator build
and artifact checks. The preserved Build 7 archive is unchanged; its earlier local
signature/privacy verification remains recorded in the release evidence.
These results do not substitute for live model acceptance or fresh production release evidence.

For current candidate status, consumed build numbers, clean-install requirements, and physical
TestFlight QA evidence, see [`docs/app-release-backlog.md`](docs/app-release-backlog.md) and
[`docs/app-store/internal-testflight-runbook.md`](docs/app-store/internal-testflight-runbook.md).
