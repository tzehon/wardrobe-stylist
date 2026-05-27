# Wardrobe Stylist

A **personal, privacy-first** iOS app that learns what you own — primarily by reading purchase receipts in your **Gmail** (inbox, archived, Spam, Trash), and from **photos you take** — then acts as a **fashion stylist**: it recommends a complete daily outfit (clothing + bag + jewelry) that is stylish, matches your style, and avoids repeating recent looks. You can browse your collection by **dynamically generated categories**.

> Working title — "Wardrobe" (app) with stylist agent persona "Aria". Single-user / personal use.

## Non-negotiable constraints

- 🔒 **Gmail is strictly READ-ONLY.** The app can never send, modify, label, trash, draft, or delete mail. This is enforced *structurally* (only read endpoints are reachable) **and** by an automated guard test (`GmailReadOnlyGuardTests`). See [`docs/privacy.md`](docs/privacy.md).
- 🕵️ **Hybrid privacy.** Gmail is fetched and filtered **on-device**; only minimal relevant text (and a few item images) is sent to the cloud AI.
- ✅ **Tests at every stage.** Every feature ships with tests, run before moving on; CI runs them on every push.

## Repository layout

```
wardrobe-stylist/
├─ ios/         SwiftUI + SwiftData app (on-device Gmail, photos, catalog, stylist UI)
├─ backend/     Python FastAPI proxy that holds the Anthropic key and calls Claude
├─ shared/      JSON Schemas shared by iOS + backend (the data contract)
├─ docs/        Setup + architecture docs (start here)
└─ .github/     CI workflows
```

## Quick start

See **[`docs/setup.md`](docs/setup.md)** for the full, step-by-step setup. TL;DR:

```bash
# Backend
cd backend && uv sync && uv run pytest && uv run ruff check . && uv run mypy app

# iOS (generates Wardrobe.xcodeproj from project.yml, then runs tests)
cd ios && xcodegen generate
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'   # or any installed iPhone sim
```

## Documentation

| Doc | What |
|---|---|
| [`docs/setup.md`](docs/setup.md) | End-to-end dev setup (Xcode, uv, Google OAuth, Anthropic key, Fly.io) |
| [`docs/architecture.md`](docs/architecture.md) | System architecture with diagrams (components, data flow, sequences) |
| [`docs/google-setup.md`](docs/google-setup.md) | Read-only Gmail OAuth setup (and the refresh-token gotcha) |
| [`docs/privacy.md`](docs/privacy.md) | Privacy posture + how read-only is guaranteed |
| [`CLAUDE.md`](CLAUDE.md) | Guidance for Claude Code sessions in this repo |

## Status

Built in phases (MVP = Gmail → browsable catalog). See the plan and `docs/` for the roadmap.
