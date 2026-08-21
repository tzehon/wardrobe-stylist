# Wardrobe Stylist

A **personal, privacy-first** iOS app for cataloging clothing manually or from photos, browsing a
local wardrobe, and optionally asking **Aria** for a non-repeating daily outfit. Public v1 does not
connect to Google, read Gmail, import receipts, or require an account.

> Working title — "Wardrobe" (app) with stylist agent persona "Aria". Single-user / personal use.

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

For current candidate status, consumed build numbers, clean-install requirements, and physical
TestFlight QA evidence, see [`docs/app-release-backlog.md`](docs/app-release-backlog.md) and
[`docs/app-store/internal-testflight-runbook.md`](docs/app-store/internal-testflight-runbook.md).
