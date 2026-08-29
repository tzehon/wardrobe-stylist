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
4. On a physical iPhone, exercise enrollment and session renewal. On iOS 18–26, record the expected
   absence of the newer signed category/build fields while proving the complete core flow. If a
   future iOS 27+ device supplies those fields, separately verify configured category/build rejection
   behavior before claiming enforcement; Build 6's iOS 26.6 evidence does not prove it.
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

Unchecked snapshot-list expiry, deletion-specific restore/non-return, App Privacy, build-7 backend
deployment/distribution, and clean physical Dark Mode visual retest remain release gates. Real
registration, assertion, and deletion success markers have now been observed;
build 5 is non-promotable, while clean build 6 passed the fixed notification route and completed
final deletion/reinstall/new enrollment. A 2026-08-28 Dark Mode screenshot separately confirmed the
build-6 visual-control failure, making build 6 non-promotable; PR #31 has since merged and verified
the replacement implementation. A signed-in TestFlight **Build Uploads** inspection on 2026-08-29
showed build 6 as the highest upload and **Complete**, with build 7 absent. Build `1.0.0 (7)` is
selected while `MARKETING_VERSION` remains `1.0.0`; source configuration is prepared for accepted
builds `4,5,6,7`, while live Fly v9 remains on `4,5,6` until deployment. Historical Apple
processing/internal assignment and a healthy `/health` response do not close the remaining gates.

## TestFlight distribution

Every internal beta is built as an App Store candidate. Follow the
[internal TestFlight runbook](app-store/internal-testflight-runbook.md):

1. keep the remaining APP-009 snapshot-list expiry and deletion-specific recovery/non-return
   evidence explicitly open and the manual review current.
2. validate the Gmail-free iOS removal, fresh local schema, and artifact-absence guards.
3. populate the HTTPS backend, public-page URLs, and Team ID in `Distribution.xcconfig`.
4. treat processed candidates `1.0.0 (4)`, `1.0.0 (5)`, and `1.0.0 (6)` as consumed and never
   reuse any build number. Build 5 is also non-promotable after its physical notification-tap
   crash. The final build-5 pre-validation refresh at `2026-08-22T03:16:16Z` showed builds 1–4
   only and build 5 absent. A later signed-in TestFlight Build Uploads refresh at
   `2026-08-22T10:02:31Z` showed builds 1–5 only, build 5 **Complete**, and no build 6, confirming
   build 6 unused before the replacement. PR #27 later merged `CURRENT_PROJECT_VERSION = 6` and
   accepted builds `4,5,6` while keeping `MARKETING_VERSION = 1.0.0`; the completed upload now
   consumes build 6. On 2026-08-29, a fresh signed-in view showed build 6 as the highest upload and
   **Complete**, with build 7 absent. Select `1.0.0 (7)` and prepare source configuration with
   `CURRENT_PROJECT_VERSION = 7` and accepted builds `4,5,6,7`; live Fly v9 remains on `4,5,6`
   until the exact updated backend is deployed and verified.
5. run the complete backend, Swift, UI, public-config, and artifact suites. Retained historical
   pre-archive build-5 evidence is green: 221 backend tests plus audit/Bandit/Ruff/mypy, 218 Swift
   unit tests, 9 UI flows, 43 release-script tests, Release simulator/artifact checks, and an exact
   synthetic `/recommend` request guard that inventories stored properties including nil optionals
   and pins encoded keys; its strengthened focused suite passed 12/12. The full backend and iOS
   gates reran on that tree; the uninterrupted iOS result bundle finalized 227/227 canonical cases
   at `2026-08-22T02:04:17Z` with no failure, skip, or retry.
6. create and strictly verify a new build-5 signed Release archive. The exact
   `Wardrobe-1.0.0-5-695c562-appstore.xcarchive` was created at `2026-08-22T01:10:32Z`; its strict
   signature/profile, scalar production App Attest, privacy, public-configuration, and Gmail-free
   checks passed at `2026-08-22T01:11:17Z`; its quiet credential/removed-capability scan passed at
   `2026-08-22T01:12:01Z`; and its post-scan signature check passed at
   `2026-08-22T01:12:19Z`. This evidence preceded Organizer validation and upload.
7. retain the completed build-5 distribution evidence. The exact-v8 payload-free review passed
   from `2026-08-22T02:27:21Z` through `02:37:08Z`; Organizer **Validate App** succeeded at
   `03:18:30Z` with zero errors, warnings, or informational messages. Upload through the normal
   **TestFlight & App Store**-eligible App Store Connect route succeeded at `03:20:59Z`, also with
   zero errors, warnings, or informational messages. Symbols were on, while **Manage Version and
   Build Number** and **Internal Testing Only** were off.
8. retain the processed/internal-assignment evidence. Build-5 processing reached **Ready to Submit** by
   `03:24:21Z`. The exact `1.0.0 (5)` build for `com.tth.Wardrobe` is arm64, minimum iOS 18.0, SDK
   build `23F81a`, includes symbols, reports no non-exempt encryption, and retains scalar production
   App Attest with `get-task-allow = false` and beta reporting active. Exactly the `Family` Internal
   Testing group is assigned, with one tester and no individual tester assignments.
9. retain the completed build-4 identity-safe handoff and partial clean build-5 physical QA. The
   eligible automatic snapshot created at `2026-08-22T07:33:23Z` reported `created` and 14-day
   retention. Build-4 proof remained available after build 5 appeared installed in place
   unexpectedly; server deletion emitted exactly one success marker and live
   installations/sessions/challenges reached `0/0/0`. Local data and the app were deleted, and
   build 5 was clean-installed. Its no-login empty first launch, offline Demo Mode, Camera/Library
   saves, full catalog flow, Style at `16:30`, cached relaunch, Restyle at `17:04`, failed-offline-
   Restyle cached-look preservation, offline Wear/History, and notification delivery passed.
   Tapping the notification crashed at `2026-08-22T17:15:14+08:00`; exact-dSYM safe symbolication
   showed `SIGABRT`, a UIKit state-restoration assertion, and a `DailyReminderNotificationRouter`
   `didReceive` async-bridge frame. Do not repeat the tap. Build 5 later completed an eligible
   identity-safe handoff before the replacement was installed cleanly.
10. retain the completed build-6 candidate/distribution evidence. Clean synchronized source
   `de7c540275fb16e61aabf1884538b18cf6edf76f` passed the merged-source gates; Fly v9 serves accepted
   builds `4,5,6`; and `Wardrobe-1.0.0-6-de7c540-appstore.xcarchive` passed strict signing,
   production App Attest, privacy, public-configuration, and Gmail-free verification. Xcode
   validation and normal-route upload succeeded; Apple processing reached **Ready to Submit**; and
   exactly `Family` is assigned with one group tester, no individual testers, and saved truthful
   tester notes.
11. retain clean build-6 physical evidence through the fixed notification route and final identity-
   safe handoff. Build 6 initially appeared in place and was not counted as QA. After the eligible
   build-5 snapshot and ordered
   server/local deletion plus app removal, build 6 was installed cleanly. Gmail-free launch,
   offline Demo, Camera/Library saves, catalog operations, production registration/cold assertion,
   online styling, explicit cached-look restoration after offline relaunch, failed-Restyle
   preservation, Wear/History, reminder delivery, and reminder tap passed without a crash or local-
   state loss. The eligible automatic snapshot at `2026-08-25T07:35:53Z` reported `created` with
   14-day retention. The owner-controlled final handoff moved from pre-deletion aggregate `1/0/0`
   through exactly one bounded deletion marker to `0/0/0` after deletion and uninstall. Clean
   reinstall, first launch, local item additions, and styling consent remained at zero; explicit
   Style at `2026-08-28 17:17 SGT` created one new anonymous installation and active session, with
   zero pending/failed challenges, one completed challenge, and one bounded registration marker.
   Signed runtime fields were absent on iOS 26.6, so do not claim iOS 27+ category/build enforcement.
12. retain the completed-failed build-6 **Allow AI styling** assessment. In the 2026-08-28 owner-
   supplied Dark Mode screenshot, the title is approximately 21 points right of the button center,
   and the sampled `#C2DFFC` fill against the white title is approximately `1.38:1`. Build 6 is
   non-promotable; its completed identity and notification evidence remains valid.

- [x] Complete and verify the replacement control implementation. PR #31 rebase-merged app commit
  `b7e46e4` to clean `main` `e4a0ae2`. The title-only control is centered, full-width, and opaque;
  enabled/pressed/disabled contrast coverage and the screenshot UI assertion passed. Merged
  verification retained 221 backend tests plus audit/Bandit/Ruff/mypy, 226 Swift unit tests, all
  9 UI tests, and 43 release-script tests; both GitHub iOS checks are green.
- [x] Retain the 2026-08-29 build-number selection and source-preparation evidence above without
  claiming backend deployment or Apple distribution.
- [ ] Deploy and distribute build 7 through the exact backend/configuration, live health/manual-
  review, full regression, archive, validation/upload, processing, `Family` assignment, and truthful
  tester-note loop.
- [ ] Clean-install processed build 7 and physically retest title centering, icon-slot
  absence, and enabled/pressed/disabled legibility in Dark Mode before promotion.

The notification-router source fix merged through PR #27. Focused tests passed 17/17; merged-source
evidence retained 221 backend tests plus locked audit/Bandit/Ruff/mypy, 231/231 iOS tests, and all
43 release-script tests. The exact build-6 archive, internal distribution, clean physical proof
through notification tap, and final identity-safe deletion/reinstall/new enrollment are retained
above. Snapshot-list expiry and deletion-specific restore/non-return remain open.

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

Historical Fly v8 completed at `2026-08-21T10:45:06Z` from reviewed PR #23 source
`4a75b99dcd49e818ad1d5b198e8c49abba702e18` and immutable `linux/amd64` digest
`sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
Its targeted auth-service INFO logger and TestFlight allowlist for builds `4,5` supplied the
historical runtime baseline; the payload-free post-change review passed at
`2026-08-21T11:09:20Z`. A fresh exact-v8 post-
distribution review also passed from `2026-08-22T03:19:20Z` through `03:30:33Z`; fixed/coarse
health, recent snapshots, schema/integrity, endpoint surface, zero failure bands, Anthropic, and
support checks remained green. The first bounded query returned zero registration, assertion, and
deletion successes because none had yet been exercised; later clean build-5 Style/Restyle observed
registration/assertion markers, and the build-4 handoff observed exactly one deletion marker plus
`0/0/0` live aggregates. Fly v9 is now live on the exact merged build-6 source with accepted builds
`4,5,6`, matching release/running image references, and one healthy Singapore Machine. Protected
`/recommend` intentionally has no developer success marker and
remains aggregate/client-evidenced. Eligible snapshots enabled the build-4 and build-5 handoffs.
The eligible `2026-08-25T07:35:53Z` snapshot then enabled Build 6's completed final handoff: the
pre-deletion aggregate was `1/0/0`, exactly one bounded deletion marker was observed, post-deletion/
post-uninstall aggregates were `0/0/0`, and the explicit `2026-08-28 17:17 SGT` Style action created
a new anonymous installation/session after reinstall. Actual listing expiry and deletion-specific
restore/non-return remain open; the handoff does not prove that the deleted identity cannot return
from retained snapshot copies.

The required v9 post-deploy/pre-upload payload-free review was missed and is not backdated. A late
full review passed at `2026-08-23T02:13:12Z`, restoring current operational evidence while retaining
the process defect. Repeat the review before every future archive/upload, after every backend or
production-configuration change, and otherwise no later than 2026-09-22.

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
