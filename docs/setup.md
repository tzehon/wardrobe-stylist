# Setup guide

End-to-end setup for developing Wardrobe Stylist on a Mac. The repo is a monorepo with an
iOS app (`ios/`) and a Python backend (`backend/`). This guide covers everything from a
fresh checkout to running all tests; Gmail/Anthropic wiring is staged by phase.

- [Prerequisites](#prerequisites)
- [Get the code](#get-the-code)
- [Backend](#backend-fastapi)
- [iOS app](#ios-app)
- [Google / Gmail (read-only)](#google--gmail-read-only)
- [Anthropic key](#anthropic-key)
- [Deploy the backend (Fly.io)](#deploy-the-backend-flyio)
- [Run all tests](#run-all-tests)
- [Troubleshooting](#troubleshooting)

## Prerequisites

| Tool | Version used | Install |
|---|---|---|
| macOS | 14+ | — |
| Xcode | 26.x (Swift 6, iOS 18+ SDK) | App Store / developer.apple.com |
| Homebrew | latest | https://brew.sh |
| XcodeGen | 2.45+ | `brew install xcodegen` |
| uv (Python) | 0.11+ | `brew install uv` or `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| git | 2.40+ | `brew install git` |
| flyctl (deploy only) | latest | `brew install flyctl` |

Accounts: a **paid Apple Developer account** (for WeatherKit/TestFlight in later phases), a
**Google Cloud** project (read-only Gmail OAuth), an **Anthropic API key**, and a **Fly.io**
account (backend hosting).

## Get the code

```bash
git clone <your-remote-url> wardrobe-stylist   # or use the local repo
cd wardrobe-stylist
```

Layout: `ios/` (app), `backend/` (proxy), `shared/schemas/` (data contract), `docs/`.

## Backend (FastAPI)

```bash
cd backend
uv sync                       # creates .venv and installs deps from uv.lock
cp .env.example .env          # fill in later (only needed to call Claude)
uv run uvicorn app.main:app --reload
curl localhost:8000/health    # {"status":"ok","environment":"dev"}
```

`.env` (gitignored) holds `ANTHROPIC_API_KEY` and `DEVICE_TOKEN`. The config is import-safe,
so tests and the `/health` route work without them.

## iOS app

The Xcode project is **generated** from `ios/project.yml` by XcodeGen (the `.xcodeproj` is
gitignored — never edit it by hand; edit `project.yml` and regenerate).

```bash
cd ios
xcodegen generate            # creates Wardrobe.xcodeproj
open Wardrobe.xcodeproj       # then ⌘R to run, ⌘U to test
```

Or from the command line (pick any installed iPhone simulator):

```bash
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

List installed simulators with `xcrun simctl list devices available`.

> **Note:** Vision subject-lift and feature-print APIs do **not** run in the Simulator.
> Those code paths are gated/mocked in tests and must be verified on a real device.

## Google / Gmail (read-only)

Configure the Google Cloud OAuth client now (the in-app sign-in is wired in Phase 1). Follow
**[`google-setup.md`](google-setup.md)** — the short version:

1. Create a Google Cloud project; enable the **Gmail API**.
2. OAuth consent screen: External; add yourself as a user; request **only**
   `https://www.googleapis.com/auth/gmail.readonly`.
3. Set publishing status to **"In production" (unverified)** to avoid the 7-day refresh-token
   expiry. No CASA assessment is needed for personal/single-user use.
4. Create an **iOS OAuth client** (bundle id `com.tth.Wardrobe`); add the reversed-client-id
   URL scheme to the app (Phase 1).

## Anthropic key

The key lives **only** on the backend — never in the app. Locally, put it in `backend/.env`;
in production, set it as a Fly.io secret (below). Get a key at
https://console.anthropic.com and set a monthly budget alert (personal use is ~$1–5/mo).

## Deploy the backend (Fly.io)

(First needed when the `/extract` route lands in Phase 2.)

```bash
cd backend
fly launch --no-deploy                 # creates fly.toml (first time)
fly secrets set ANTHROPIC_API_KEY=sk-ant-... DEVICE_TOKEN=$(python -c "import secrets;print(secrets.token_urlsafe(32))")
fly deploy
```

The app then talks to `https://<your-app>.fly.dev` using the same `DEVICE_TOKEN` as a Bearer.

## Run all tests

Run after every change (also enforced in CI):

```bash
# Backend
cd backend && uv run pytest && uv run ruff check . && uv run mypy app

# iOS
cd ios && xcodegen generate
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The iOS suite includes **`GmailReadOnlyGuardTests`**, which fails the build if any Gmail
write capability is ever introduced — see [`privacy.md`](privacy.md).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Unable to find a device matching the provided destination` | Use a sim from `xcrun simctl list devices available` (e.g. `iPhone 17`). |
| `No such module 'Testing'` in the editor | Editor-only until the project is generated; run `xcodegen generate`. CI/`xcodebuild` resolves it. |
| Gmail asks to re-auth weekly | Consent screen is in **Testing**; switch to **In production (unverified)** and regenerate credentials ([google-setup.md](google-setup.md)). |
| `uv sync` picks an unexpected Python | Pin with `uv python pin 3.12` (or your target) and re-run. |
| Vision background-removal returns nil | Expected in the Simulator; test on a real device. |
