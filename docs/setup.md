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
cp .env.example .env          # then fill in:
                              #   ANTHROPIC_API_KEY=sk-ant-...
                              #   DEVICE_TOKEN=$(python3 -c "import secrets;print(secrets.token_urlsafe(32))")
uv run uvicorn app.main:app --reload --host 0.0.0.0   # 0.0.0.0 = listen on all interfaces
curl localhost:8000/health    # {"status":"ok","environment":"dev"}
```

`--host 0.0.0.0` lets the iPhone on the same Wi-Fi reach the dev server (at your Mac's LAN
IP). For sim-only dev you can drop it. The same `DEVICE_TOKEN` value must be pasted into
`ios/Secrets.xcconfig` (see iOS section below). `.env` (gitignored) holds `ANTHROPIC_API_KEY`
and `DEVICE_TOKEN`. The config is import-safe, so tests and `/health` work without them.

> macOS firewall blocking port 8000? System Settings → Network → Firewall → allow incoming
> for the Python process the first time it asks, or temporarily turn the firewall off for dev.

## iOS app

The Xcode project is **generated** from `ios/project.yml` by XcodeGen (the `.xcodeproj` is
gitignored — never edit it by hand; edit `project.yml` and regenerate).

### One-time: fill in your local secrets

`ios/Secrets.xcconfig` is **gitignored**. The build (and all tests) succeeds without it,
but live Gmail sign-in and live backend calls need values pasted in:

```bash
cp ios/Secrets.xcconfig.example ios/Secrets.xcconfig
# then edit ios/Secrets.xcconfig and replace the placeholders with:
#   GOOGLE_CLIENT_ID           = 123…-…apps.googleusercontent.com
#   GOOGLE_REVERSED_CLIENT_ID  = com.googleusercontent.apps.123…-…
#   BACKEND_SCHEME             = http     (or `https` for Fly.io)
#   BACKEND_HOST               = <Mac-LAN-IP>:8000   (iPhone on same Wi-Fi)
#                                localhost:8000      (simulator only)
#                                your-app.fly.dev    (Fly.io deploy)
#   BACKEND_DEVICE_TOKEN       = (the same string as DEVICE_TOKEN in backend/.env)
#   PRIVACY_POLICY_URL         = https:/$()/your-domain.example/privacy
#   SUPPORT_URL                = https:/$()/your-domain.example/support
```

xcconfig values can't contain `//` (the rest of the line gets treated as a comment), so
the backend URL is split into `BACKEND_SCHEME` and `BACKEND_HOST` and composed in
`Info.plist` at build time. `ios/Debug.xcconfig` (committed) `#include?`s your local file
and feeds the values into `Info.plist` (`GIDClientID`, `CFBundleURLTypes`, `BackendBaseURL`,
`BackendDeviceToken`, and the public privacy/support links). Now that the backend is HTTPS on
Fly.io, `Info.plist` carries no App
Transport Security exception. To point the app back at a **plain-HTTP LAN dev backend**, set
`BACKEND_SCHEME = http` + `BACKEND_HOST = <Mac-LAN-IP>:8000` and temporarily add an
`NSAppTransportSecurity` → `NSAllowsArbitraryLoads = YES` block to `Info.plist` (don't commit it).

`PRIVACY_POLICY_URL` and `SUPPORT_URL` are optional during local development, so their Settings
rows remain visibly unavailable until configured. An installable device **Release** archive is
stricter: its post-build guard requires real non-placeholder HTTPS destinations, a matching
Google client/callback scheme, and an HTTPS backend. It also refuses to archive while the legacy
`BackendDeviceToken` key remains in the public target. That last blocker is intentional and is
resolved only by the per-user backend identity cutover in
[`gcp-oauth-production-sequence.md`](gcp-oauth-production-sequence.md).

Release builds use a separate gitignored `ios/Distribution.xcconfig`, created from
`ios/Distribution.xcconfig.example`. They never inherit LAN hosts or test OAuth values from
`Secrets.xcconfig`. Do not add a shared bearer to that file; public identity is completed later
in the GCP production sequence.

### Build / run / test

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

The repo ships a `backend/Dockerfile` (uv-based) and `backend/fly.toml` (HTTPS,
scale-to-zero, `/health` check), so you don't run `fly launch` from scratch —
just claim an app name, set secrets, and deploy:

```bash
cd backend
fly launch --no-deploy --copy-config   # reuses the committed fly.toml; pick a unique app name + region
fly secrets set \
  ANTHROPIC_API_KEY=sk-ant-... \
  DEVICE_TOKEN=$(python -c "import secrets;print(secrets.token_urlsafe(32))")
fly deploy
fly open /health                        # should return {"status":"ok","environment":"production"}
```

The image build is verifiable locally first: `docker build -t wb backend && docker run --rm -p 8080:8080 wb`, then `curl localhost:8080/health`.

Then point the app at the deployed backend and drop the dev-only HTTP exception:

1. In `ios/Secrets.xcconfig`, set `BACKEND_SCHEME = https` and
   `BACKEND_HOST = <your-app>.fly.dev` (no port).
2. In `ios/Wardrobe/Info.plist`, **remove the `NSAppTransportSecurity` /
   `NSAllowsArbitraryLoads` block** — it exists only so the iPhone can reach the
   Mac dev backend over plain HTTP. Once the backend is HTTPS on Fly.io it's no
   longer needed (and App Store review flags it).
3. `cd ios && xcodegen generate` and rebuild.

The app then talks to `https://<your-app>.fly.dev` using the same `DEVICE_TOKEN` as a Bearer.

## TestFlight (Phase 6 distribution)

Requires an **Apple Developer Program** membership ($99/yr) and the production
backend above (a real device can't reach your Mac's LAN IP). In Xcode: set a real
`DEVELOPMENT_TEAM` in `Secrets.xcconfig`, bump `CURRENT_PROJECT_VERSION`, then
**Product ▸ Archive** → **Distribute App** → **App Store Connect** → **Upload**.
Add the build to a TestFlight internal-tester group in App Store Connect.

Before choosing a build number or archiving, run `ios/scripts/verify-release-artifact.sh` against
the generated Release artifact. Device Release archives also run the strict public-configuration
guard automatically; do not bypass it for an App Store candidate.

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
