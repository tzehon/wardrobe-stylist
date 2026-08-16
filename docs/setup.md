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

Accounts: a **paid Apple Developer account** (App Attest capability, signing, and TestFlight), a
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
uv sync --locked              # creates .venv exactly from uv.lock
cp .env.example .env
chmod 600 .env                 # keep local backend secrets owner-readable only
uv run uvicorn app.main:app --reload --host 0.0.0.0   # 0.0.0.0 = listen on all interfaces
curl localhost:8000/health    # {"status":"ok","environment":"dev"}
```

`--host 0.0.0.0` lets the iPhone on the same Wi-Fi reach the dev server (at your Mac's LAN
IP). For sim-only dev you can drop it. The config is import-safe, so tests and `/health` work
without release secrets.

Live connected AI on a physical development iPhone uses App Attest sandbox identity. Configure
the gitignored `.env` with development values, never production placeholders:

```dotenv
ANTHROPIC_API_KEY=sk-ant-...
AUTH_MODE=app_attest
APP_ATTEST_APP_ID_PREFIX=<exact-prefix-from-Apple-registered-App-ID>
APP_ATTEST_BUNDLE_ID=com.tth.Wardrobe
APP_ATTEST_ENVIRONMENT=development
APP_ATTEST_DATABASE_PATH=/absolute/private/path/wardrobe-auth/auth.sqlite3
APP_ATTEST_SESSION_SECRET=<at-least-32-random-bytes>
APP_ATTEST_ALLOWED_VALIDATION_CATEGORIES=3
APP_ATTEST_ALLOWED_BUNDLE_VERSIONS=3
ENVIRONMENT=dev
```

The build string allowlist must match the app actually installed. The current iOS app has no
shared token and cannot use backend legacy auth. `AUTH_MODE=legacy` + `DEVICE_TOKEN` are limited to
backend-only curl/test compatibility; `AUTH_MODE=bridge` exists only for a time-bounded production
migration of already-installed legacy builds. Neither is an iOS development setup. The iOS
Simulator cannot perform real App Attest, so local/Demo Mode remains usable there while connected
AI fails closed; tests use an injected fake authorization service. Connected-app development
requires a physical iPhone, development App Attest, and the development configuration above.

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
#   PRIVACY_POLICY_URL         = https:/$()/your-domain.example/privacy
#   SUPPORT_URL                = https:/$()/your-domain.example/support
```

xcconfig values can't contain `//` (the rest of the line gets treated as a comment), so
the backend URL is split into `BACKEND_SCHEME` and `BACKEND_HOST` and composed in
`Info.plist` at build time. `ios/Debug.xcconfig` (committed) `#include?`s your local file
and feeds the values into `Info.plist` (`GIDClientID`, `CFBundleURLTypes`, `BackendBaseURL`,
and the public privacy/support links). Backend sessions are established at runtime with an
App Attest key; no shared backend credential belongs in `Info.plist` or either xcconfig. Now that
the backend is HTTPS on Fly.io, `Info.plist` carries no App
Transport Security exception. To point the app back at a **plain-HTTP LAN dev backend**, set
`BACKEND_SCHEME = http` + `BACKEND_HOST = <Mac-LAN-IP>:8000` and temporarily add an
`NSAppTransportSecurity` → `NSAllowsArbitraryLoads = YES` block to `Info.plist` (don't commit it).

`PRIVACY_POLICY_URL` and `SUPPORT_URL` are optional during local development, so their Settings
rows remain visibly unavailable until configured. An installable device **Release** archive is
stricter: its post-build configuration guard requires real non-placeholder HTTPS destinations, a
matching Google client/callback scheme, an HTTPS backend, and no legacy `BackendDeviceToken` key;
the candidate additionally requires the signed App Attest entitlement/profile. Passing local
checks does not prove the external Apple capability, durable Fly store, production backend, or
physical TestFlight flow.

Release builds use a separate gitignored `ios/Distribution.xcconfig`, created from
`ios/Distribution.xcconfig.example`. They never inherit LAN hosts or test OAuth values from
`Secrets.xcconfig`. Do not add a shared bearer to that file. Google identifiers configure only
optional Gmail; anonymous backend identity is App Attest-based and independent from Google.

### App Attest physical-device setup

1. In Certificates, Identifiers & Profiles, open the explicit App ID `com.tth.Wardrobe` and record
   its exact App ID prefix. Do not infer it from `DEVELOPMENT_TEAM`.
2. Enable App Attest for that App ID. Existing provisioning profiles may become invalid; allow
   automatic signing to regenerate them or recreate them deliberately.
3. Regenerate the Xcode project. `Wardrobe.entitlements` uses the sandbox environment for Debug
   and production for Release; TestFlight/App Store distributions use production regardless.
4. Run on a physical iPhone and exercise enrollment plus session renewal. On iOS 27+, verify that
   the development backend accepts signed validation category `3` and the exact installed build.
   On iOS 18–26, record the expected absence of those newer runtime fields while proving the full
   core App Attest flow. Simulator fakes do not replace this test.
5. Before distribution, inspect both the archive's signed entitlement and embedded provisioning
   profile. The TestFlight production backend must accept category `2` and the exact uploaded
   build; category `4` is reserved for App Store distribution.

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

The repo ships a `backend/Dockerfile` and `backend/fly.toml`. App Attest adds durable authentication
state, so a production deploy also needs a private Fly volume (or reviewed shared database) before
`AUTH_MODE=app_attest` can start. Never use the container filesystem or an in-memory store for
production counters/challenges.

```bash
cd backend
fly launch --no-deploy --copy-config   # reuses the committed fly.toml; pick a unique app name + region
fly volumes create <auth-volume-name> --region <primary-region>
fly secrets set \
  ANTHROPIC_API_KEY=sk-ant-... \
  APP_ATTEST_SESSION_SECRET=<at-least-32-random-bytes>
fly deploy
fly open /health                        # should return {"status":"ok","environment":"production"}
```

Before deploying, make the committed Fly mount source match the created volume and set reviewed
production configuration: `AUTH_MODE=app_attest`, `APP_ATTEST_APP_ID_PREFIX` from the Apple portal,
`APP_ATTEST_BUNDLE_ID=com.tth.Wardrobe`, `APP_ATTEST_ENVIRONMENT=production`,
`APP_ATTEST_DATABASE_PATH` under `/data`, validation category `2` for the next TestFlight build
(and `4` only when serving App Store builds), and an exact bundle-build allowlist chosen from App
Store Connect. These signed category/build fields are enforced whenever Apple supplies them on
iOS 27+; older supported OS versions still require the complete core App Attest proof. These are
release facts, not values to guess from this repository.

Record the volume/machine topology, atomic SQLite behavior, snapshot and backup configuration,
restore rehearsal, and retention/deletion criteria. Fly volumes are single-machine local storage;
do not scale to multiple independent volumes without a designed shared/replicated auth store. The
database may contain only App Attest public keys, opaque Apple attestation receipts, counters,
challenges, hashed sessions, and coarse rate windows—never Gmail receipt or wardrobe payloads.
The core certificate/key/nonce proof authorizes an installation; do not trust or redeem the separate
Apple receipt for a fraud metric until its PKCS#7 signature/chain, App ID, creation time, and
attested-public-key binding are independently validated with official-format evidence.

The image build is verifiable locally first: `docker build -t wb backend && docker run --rm -p 8080:8080 wb`, then `curl localhost:8080/health`.

Then point the app at the deployed backend and drop the dev-only HTTP exception:

1. In `ios/Secrets.xcconfig`, set `BACKEND_SCHEME = https` and
   `BACKEND_HOST = <your-app>.fly.dev` (no port).
2. In `ios/Wardrobe/Info.plist`, **remove the `NSAppTransportSecurity` /
   `NSAllowsArbitraryLoads` block** — it exists only so the iPhone can reach the
   Mac dev backend over plain HTTP. Once the backend is HTTPS on Fly.io it's no
   longer needed (and App Store review flags it).
3. `cd ios && xcodegen generate` and rebuild.

For an existing installation, a bridge may temporarily accept both mechanisms only with a recorded
expiry and deployment evidence. After the App Attest TestFlight client is verified, deploy
App-Attest-only mode, unset/rotate `DEVICE_TOKEN`, and prove the old client is rejected. Retain a
known-good App-Attest-only image and preserve the auth volume for rollback; never roll back by
re-enabling the shared bearer.

## TestFlight (Phase 6 distribution)

Every internal beta is built as an App Store candidate. Follow the full
[internal TestFlight runbook](app-store/internal-testflight-runbook.md); the short version is:

1. Finish `APP-009`: App Attest per-installation sessions, durable Fly auth state, physical-device
   sandbox/production verification, no `BackendDeviceToken`, and retired legacy backend auth.
2. Put the production Google identifiers, HTTPS backend, public privacy/support URLs, and real
   `DEVELOPMENT_TEAM` in gitignored `Distribution.xcconfig`.
3. Check App Store Connect for the highest uploaded build, then set the next unused
   `CURRENT_PROJECT_VERSION`. Set the intended public `MARKETING_VERSION` before archiving if the
   exact beta may be promoted.
4. Regenerate, run the complete backend/Swift/UI/Release validation, and create a signed device
   archive with **Product ▸ Archive**.
5. In Organizer choose **Validate App**, then **Distribute App ▸ TestFlight & App Store ▸ Upload**.
   Do not choose **TestFlight Internal Only**: Apple prevents that artifact from later being
   submitted to customers.
6. After processing, add the build only to the Internal Testing group and complete upgrade plus
   clean-device QA, including enrollment/session renewal, tester OS/runtime-field evidence,
   production category/build evidence on iOS 27+, reinstall identity reset, offline local/demo
   behavior, and rejection of the pre-App-Attest shared-token build. Adding it to an internal group
   does not submit it for App Review.

Before choosing a build number or archiving, run `ios/scripts/verify-release-artifact.sh` against
the generated simulator Release artifact. Xcode omits App Attest from simulator signatures, so this
is only a structural preflight. After creating the signed device archive, run the same verifier with
the archived app as its second argument; that pass requires the signed production App Attest
entitlement and no shared bearer:

```bash
cd ios
./scripts/verify-release-artifact.sh DerivedData/ReleaseValidation
./scripts/verify-release-artifact.sh DerivedData/ReleaseValidation \
  "/path/to/Wardrobe.xcarchive/Products/Applications/Wardrobe.app"
```

Device Release archives also run the strict public-configuration guard automatically; never bypass
it.

## Run all tests

Run after every change (also enforced in CI):

```bash
# Backend
cd backend && uv run --locked pytest && uv run --locked pip-audit && uv run --locked bandit -r app container_entrypoint.py -q && uv run --locked ruff check . && uv run --locked mypy app

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
