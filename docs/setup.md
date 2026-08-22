# Setup guide

End-to-end setup for developing the approved Gmail-free Wardrobe Stylist v1 on a Mac. The
monorepo contains an iOS app (`ios/`) and Python backend (`backend/`). Public v1 supports manual
and photo cataloging, local history/reminders, offline Demo Mode, and optional AI styling protected
by App Attest. It does not require Google Cloud or Gmail credentials.

The active checkout removes the earlier read-only Gmail/receipt-import subsystem.
[`google-setup.md`](google-setup.md) and
[`gcp-oauth-production-sequence.md`](gcp-oauth-production-sequence.md) are historical/deferred
references, not v1 setup steps.

- [Prerequisites](#prerequisites)
- [Get the code](#get-the-code)
- [Backend](#backend-fastapi)
- [iOS app](#ios-app)
- [App Attest physical-device setup](#app-attest-physical-device-setup)
- [Anthropic key](#anthropic-key)
- [Deploy the backend](#deploy-the-backend-flyio)
- [TestFlight](#testflight-distribution)
- [Run all tests](#run-all-tests)
- [Troubleshooting](#troubleshooting)

## Prerequisites

| Tool | Version used | Install |
|---|---|---|
| macOS | 14+ | — |
| Xcode | 26.x (Swift 6, iOS 18+ SDK) | App Store / developer.apple.com |
| Homebrew | latest | <https://brew.sh> |
| XcodeGen | 2.45+ | `brew install xcodegen` |
| uv (Python) | 0.11+ | `brew install uv` or `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| git | 2.40+ | `brew install git` |
| flyctl (deploy only) | latest | `brew install flyctl` |

Accounts: a **paid Apple Developer account** for App Attest, signing, and TestFlight; an
**Anthropic API key**; and a **Fly.io** account for the production backend. Google Cloud is not a
public-v1 dependency.

## Get the code

```bash
git clone <your-remote-url> wardrobe-stylist
cd wardrobe-stylist
```

Layout: `ios/` (app), `backend/` (proxy), `shared/schemas/` (data contracts), `docs/`.

## Backend (FastAPI)

```bash
cd backend
uv sync --locked
cp .env.example .env
chmod 600 .env
uv run uvicorn app.main:app --reload --host 0.0.0.0
curl localhost:8000/health
```

`--host 0.0.0.0` lets an iPhone on the same Wi-Fi reach the development server. Tests and
`/health` remain import-safe without release secrets.

Connected styling on a physical development iPhone uses App Attest sandbox identity. Configure
the gitignored `.env` with development values:

```dotenv
ANTHROPIC_API_KEY=sk-ant-...
AUTH_MODE=app_attest
APP_ATTEST_APP_ID_PREFIX=<exact-prefix-from-Apple-registered-App-ID>
APP_ATTEST_BUNDLE_ID=com.tth.Wardrobe
APP_ATTEST_ENVIRONMENT=development
APP_ATTEST_DATABASE_PATH=/absolute/private/path/wardrobe-auth/auth.sqlite3
APP_ATTEST_SESSION_SECRET=<at-least-32-random-bytes>
APP_ATTEST_ALLOWED_VALIDATION_CATEGORIES=3
APP_ATTEST_ALLOWED_BUNDLE_VERSIONS=<installed-development-build>
ENVIRONMENT=dev
```

The build allowlist must match the app actually installed. Public clients use App Attest only;
`AUTH_MODE=legacy` and `DEVICE_TOKEN` are not valid iOS development or release configuration. The
Simulator cannot perform real App Attest, so local catalog and Demo Mode remain usable while live
AI fails closed; tests use an injected fake authorization service.

## iOS app

The Xcode project is generated from `ios/project.yml` by XcodeGen. The `.xcodeproj` is gitignored;
edit `project.yml` and regenerate rather than editing the generated project by hand.

### Local configuration

`ios/Secrets.xcconfig` is gitignored. Local connected styling needs only the backend and optional
public-page values:

```bash
cp ios/Secrets.xcconfig.example ios/Secrets.xcconfig
```

```xcconfig
BACKEND_SCHEME = http
BACKEND_HOST = <Mac-LAN-IP>:8000
PRIVACY_POLICY_URL = https:/$()/blog.tth.dev/wardrobe/privacy/
SUPPORT_URL = https:/$()/blog.tth.dev/wardrobe/
```

xcconfig values cannot contain `//`, so the URL scheme and host are split and composed in
`Info.plist`. For an HTTPS Fly backend use `BACKEND_SCHEME = https` and the `*.fly.dev` host. The
committed production plist must not include an ATS exception; a plain-HTTP LAN exception may be
added locally for development but must not be committed.

Public-v1 configuration contains no `GOOGLE_CLIENT_ID`, reversed Google client ID, Google URL
callback scheme, Gmail scope, or receipt-background-task identifier. The release guards must fail
if any of them returns.

Release builds use a separate gitignored `ios/Distribution.xcconfig`, created from
`ios/Distribution.xcconfig.example`. It supplies the HTTPS backend, stable public privacy/support
URLs, and Apple Developer Team ID. It must contain neither a shared backend bearer nor Google
configuration.

### Build, run, and test

```bash
cd ios
xcodegen generate
open Wardrobe.xcodeproj
```

Or run tests from the command line:

```bash
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

List installed simulators with `xcrun simctl list devices available`.

Vision subject-lift and feature-print APIs do not run in the Simulator. Gate or mock those paths
and verify them on a real device. App Attest is also a physical-device boundary.

## App Attest physical-device setup

1. In Certificates, Identifiers & Profiles, open the explicit App ID `com.tth.Wardrobe` and
   record its exact App ID prefix. Do not infer it from `DEVELOPMENT_TEAM`.
2. Enable App Attest for that App ID. Regenerate invalidated provisioning profiles deliberately or
   allow automatic signing to do so.
3. Regenerate the Xcode project. Debug uses App Attest development/sandbox; TestFlight and App
   Store distributions use production.
4. On a physical iPhone, exercise enrollment and session renewal. On iOS 27+, verify development
   category `3` and the exact installed build. On iOS 18–26, record the expected absence of those
   newer signed fields while proving the complete core flow.
5. Before distribution, inspect the archive's signed entitlement and embedded profile. TestFlight
   production accepts category `2` and the exact uploaded build; category `4` is reserved for App
   Store distribution.

## Anthropic key

The key lives only on the backend—never in the app. Put it in `backend/.env` locally and a Fly
secret in production. Set an owner-approved monthly spend limit and review current-month usage and
cost as part of the manual production check.

## Deploy the backend (Fly.io)

The repository ships `backend/Dockerfile` and `backend/fly.toml`. App Attest requires durable
authentication state, so production needs a private Fly volume or reviewed shared database. Never
use the container filesystem or an in-memory store for production counters and challenges.

```bash
cd backend
fly launch --no-deploy --copy-config
fly volumes create <auth-volume-name> --region <primary-region>
fly secrets set \
  ANTHROPIC_API_KEY=sk-ant-... \
  APP_ATTEST_SESSION_SECRET=<at-least-32-random-bytes>
fly deploy
fly open /health
```

Set and verify `AUTH_MODE=app_attest`, the exact App ID prefix, bundle ID, production environment,
database path under `/data`, TestFlight category `2` (App Store `4` later), and an exact build
allowlist selected from App Store Connect. iOS 18–26 still requires the complete core proof even
though it cannot be category/build-gated.

The durable store may contain only App Attest public keys, opaque Apple attestation receipts,
counters, challenges, hashed sessions, and coarse rate windows—never wardrobe, prompt, or model-
response payloads. Do not trust the opaque Apple receipt as independent fraud evidence until its
separate validation policy is implemented and evidenced.

Production operations follow the
[APP-009 lifecycle and logging policy](app-store/app-attest-data-lifecycle-policy.md):

1. run deadline cleanup on an always-available Machine and purge inactive/revoked installations;
2. provide fresh-assertion deletion through **Settings → Privacy & Data → Delete Server Security
   Data**;
3. keep application access logs disabled and security events payload-free;
4. disclose Fly's fixed seven-day customer-visible logs and undisclosed provider-internal
   in-service retention truthfully; and
5. perform the approved payload-free manual review before archive/upload, after backend or
   production-configuration changes, and at least every 30 days while production remains enabled.

Unchecked snapshot-list, deletion-specific recovery, App Privacy, real registration/assertion
success-marker observation, and complete build-5 processed-client physical proof remain release
gates.
Historical partial build-4 QA, Apple processing/internal assignment, and a healthy `/health`
response do not close them.

## TestFlight distribution

Every internal beta is built as an App Store candidate. Follow the
[internal TestFlight runbook](app-store/internal-testflight-runbook.md):

1. finish the remaining APP-009 external evidence and keep the manual review current;
2. validate the Gmail-free iOS removal, fresh local schema, and artifact-absence guards;
3. populate the HTTPS backend, public-page URLs, and Team ID in `Distribution.xcconfig`;
4. treat processed candidate `1.0.0 (4)` as consumed and never reuse build 4; a later live check
   found build 4 highest, and the build-5 archive-time refresh at `2026-08-22T01:09:39Z` still
   showed builds 1–4 only; refresh App Store Connect again immediately before validation/upload;
5. run the complete backend, Swift, UI, public-config, and artifact suites. Current local build-5
   evidence is green: 221 backend tests plus audit/Bandit/Ruff/mypy, 218 Swift unit tests, 9 UI
   flows, 43 release-script tests, Release simulator/artifact checks, and an exact synthetic
   `/recommend` request-field capture whose focused suite passed 12/12. After that tests-only guard
   was added, the full backend and iOS gates reran on the resulting tree; the uninterrupted iOS
   run completed 227/227 canonical cases at `2026-08-22T01:34:58Z` with no failure, skip, or retry;
6. create and strictly verify a new build-5 signed Release archive. The exact
   `Wardrobe-1.0.0-5-695c562-appstore.xcarchive` was created at `2026-08-22T01:10:32Z`; its strict
   signature/profile, scalar production App Attest, privacy, public-configuration, and Gmail-free
   checks passed at `2026-08-22T01:11:17Z`; its quiet credential/removed-capability scan passed at
   `2026-08-22T01:12:01Z`; and its post-scan signature check passed at
   `2026-08-22T01:12:19Z`. This is not Organizer **Validate App** or upload evidence;
7. after another live build-list refresh and payload-free exact-v8 review, use Organizer **Validate
   App** and upload with **TestFlight & App Store**, not **TestFlight Internal Only**;
8. add the processed build to the Internal Testing group; and
9. complete fresh-install physical-device QA. Build 4 was installed cleanly and produced partial
   historical evidence, but a failed offline
   Restyle hid the cached look until relaunch/tap. Complete the runbook's build-4 identity-safe
   handoff before uninstall, then install build 5 cleanly and repeat the entire matrix.

### Completed clean-uninstall transition before build 4

Build `1.0.0 (4)` is fresh-install-only. On 2026-08-21 the installed development build completed
**Disconnect Google** and **Delete Local Data**. It predated **Delete Server Security Data**, but a
read-only aggregate production query found zero installations, sessions, and pending challenges,
so no live production record existed to delete. The owner then uninstalled it and accepted losing
the earlier local wardrobe.

Build `1.0.0 (4)` was installed only after it processed in TestFlight and never over the earlier
app. On iPhone 16 Pro/iOS 26.6 it enrolled the first production identity from a zero baseline,
completed first and cold-renewal protected calls, and recovered online; runtime category/build
fields were absent as expected. Local/Demo features remained usable offline. This was partial QA,
not build-5 proof.

Fly v8 completed at `2026-08-21T10:45:06Z` from reviewed PR #23 source
`4a75b99dcd49e818ad1d5b198e8c49abba702e18` and immutable `linux/amd64` digest
`sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
Its targeted auth-service INFO logger and TestFlight allowlist for builds `4,5` are live, and the
payload-free post-change review passed at `2026-08-21T11:09:20Z`. The first bounded query returned
zero registration, assertion, and deletion success events because none was exercised, so real
production marker observation remains open. Protected `/recommend` intentionally has no developer
success marker and remains aggregate/client-evidenced. The latest listed 14-day snapshot at
`2026-08-21T07:32:23Z` predates enrollment, so server deletion/reinstall testing remains paused
pending eligible recovery evidence. Build 5 must be installed cleanly after processing and must
close the full physical matrix without claiming upgrade support.

Run `ios/scripts/verify-release-artifact.sh` against the simulator Release product and signed
archive. The Gmail-free verifier must require App Attest and fail if it finds Google frameworks or
client identifiers, Gmail permissions/hosts, receipt-import client paths/background identifiers,
or the shared bearer.

## Run all tests

Run after every code change:

```bash
cd backend
uv run --locked pytest && \
uv run --locked pip-audit && \
uv run --locked bandit -r app container_entrypoint.py -q && \
uv run --locked ruff check . && \
uv run --locked mypy app

cd ../ios
xcodegen generate
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The iOS suite and release-artifact scripts must prove the signed v1 contains no Google, Gmail, or
receipt-import capability.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Unable to find a device matching the provided destination` | Use a simulator from `xcrun simctl list devices available`. |
| `No such module 'Testing'` in the editor | Run `xcodegen generate`; the generated project resolves it. |
| Live AI fails in Simulator | Expected: real App Attest requires a physical device. Use local/Demo Mode or injected tests. |
| Plain-HTTP LAN backend is blocked | Add the ATS exception locally, verify the Mac firewall, and never commit the exception. |
| `uv sync` picks an unexpected Python | Pin the intended Python with `uv python pin 3.12` and rerun. |
| A release artifact contains Google/Gmail configuration | It is not the approved v1 candidate; complete the removal and regenerate before archiving. |
