# AGENTS.md

Durable guidance for Codex and other coding agents working in this repository.

## What this is

A **personal, single-user** iOS fashion-stylist app. The approved public v1 is a local-first,
manual/photo wardrobe catalog with optional AI outfit styling. It does **not** connect to Google,
read Gmail, import receipts, or require a human account. The Python FastAPI backend holds the
Anthropic key, calls Claude for styling, and persists only minimum App Attest security metadata
and separate aggregate AI budget/reservation metadata. It must never persist wardrobe payloads.

Git history and the explicitly historical Google setup documents retain the earlier read-only
Gmail/receipt-import design. The active v1 source removes that subsystem. Do not re-expose it in
copy, configuration, screenshots, review notes, network routes, or the signed archive.

## Hard rules (do not violate)

1. **Public v1 is Gmail-free.** The candidate contains no Google Sign-In SDK, Google client
   identifiers or callback scheme, Gmail scope/host/client path, receipt-import UI/background task,
   or `/extract` client path. `RemovedCapabilitiesReleaseGuardTests` and release-artifact checks
   enforce that absence. Any reintroduction is a new, post-v1 product/privacy project and must
   remain strictly read-only if ever approved.
2. **Never embed the Anthropic API key (or any secret) in the iOS app.** Secrets live only in the backend (env/Fly.io secrets). `.env`/credentials are gitignored.
3. **Local-first privacy.** Manual/photo wardrobe data stays on device. Optional styling sends only
   the compact text attributes and recent-wear summaries disclosed to the user. The backend must
   not persist wardrobe, prompt, or model-response payloads.
4. **Backend identity is anonymous and per installation.** Public backend sessions come from an
   Apple-certified App Attest key for one app installation, expire quickly, and are renewed with a
   fresh one-time assertion challenge. App Attest is not a human account and does not survive
   reinstall, migration, or restore. Never reintroduce Google as backend identity, a shared client
   bearer, or an unauthenticated remote-AI fallback. If App Attest is unsupported, local wardrobe
   and Demo Mode keep working while remote AI fails closed with a clear recovery message.
5. **Tests at every stage.** Add/extend tests with each change, and **run the full test suite as a regression after every code change** — backend: locked `pytest` + `pip-audit` + `bandit` + `ruff` + `mypy`; iOS: `xcodebuild test` (see Build & test) — before considering work done. A change isn't complete until the whole suite is green; never mark a task done with failing tests.
6. **Launch and monetization stay staged and budget-bounded.** Public `1.0.0`/build 7 launches
   Free, with no in-app purchases or subscriptions, in the Singapore App Store only. The next
   product milestone is transparent freemium in Singapore; country expansion comes only after that
   model and its operations are proven. A paid release must show the current plan, exact Free and
   paid inclusions, numeric allowances and reset timing, remaining usage, the StoreKit-localized
   price and billing period, and restore/manage controls. Never advertise unlimited AI styling.
   Entitlements and metering must be server-verified, and per-plan limits must sit behind an
   owner-approved global spend envelope and fail-closed circuit breaker independent of subscriber
   count. Do not expand countries until pricing, tax/legal/privacy, localization, support capacity,
   unit economics, and rollback controls pass for the next market cohort.

## Current work order

**23 September public release:** The owner authorized remediation, deployment and public release.
PR #59 merged the AnyIO 4.14.2 fix and short read-only diagnostic; Fly v15 serves exact runtime
source `cb81d7c0e35fd36917bde0a4ab78c8bd456c257b`. PR #60 synchronized the observed operations
lock and recovery guidance. The full clean-main production preflight passed at `14:31:20Z` on
`faea0c664569b3bba1e063083214f1fa5c2d69e9`: exact healthy runtime, auth integrity/capacity/disk,
bounded enabled AI, snapshots/logs, public pages, archive, fresh consoles and zero-High/Critical
recovery scan. The manual release of approved `1.0.0 (7)` was confirmed at approximately
`14:33Z` (22:33 SGT); App Store Connect shows **Ready for Distribution**. Free Singapore-only
scope is unchanged. By `14:44Z` (22:44 SGT), the anonymous public App Store listing was live
with the correct Free app/developer details and Singapore was Available; 174 other territories
remained unavailable. No on-device App Store download was performed; retain the owner-controlled public-store
installation/launch and support handoff as an open follow-up, without repeating routine QA or
deleting the existing installation. See `docs/app-store/launch-check-20260923.md`.
No new iOS build, upload, paid call, ledger reset or resource expansion occurred. Keep daily owner
cost review and rotate the existing production provider key before its 8 October expiry.
Earlier dated rejection/wait-for-clarification and release-hold instructions are historical.


The owner explicitly requested retirement of the two legacy Wardrobe Google Cloud projects on
19 September. Both project shutdown requests were accepted; final provider deletion remains pending
after the recovery period. See `docs/gcp-retirement-20260919.md` for exact scope and evidence.
Do not repeat shutdown, restore these projects or recreate Google/OAuth credentials without a new
owner instruction. This completes the legacy shutdown action, not permanent purge or public release.

Use `docs/release-plan.md` for the current sequence: retain the completed local-beta QA,
operate the verified bounded AI pilot, and address the 19 September Guideline 4.3(a) rejection
for `1.0.0 (7)` in `docs/app-store/spam-rejection-20260919.md`.
The owner-approved physical-device video and complete reviewer reply were sent on 13 September;
App Review Notes are saved and reload-verified, and resubmission at 11:56 SGT reached
**Waiting for Review** at that checkpoint. The 16 September Guideline 2.1(b) information request returned
the item to **Rejected / Unresolved Issues**; the owner-approved reply was sent unchanged at
16:14 SGT and verified in Messages (4). That step did not resubmit the build. On 19 September
at 07:18 SGT, Apple alleged binary/metadata/concept similarity under **4.3(a) — Design — Spam**,
with an extended-review warning. The owner-approved 1,399-character clarification was sent
unchanged at **15:46 SGT on 19 September**, verified in the desktop app as **Messages (6)**.
It describes implemented behavior and asks for the specific overlap without asserting unverified
provenance. At the 19 September checkpoint, Apple's clarification was awaited and the status was
**Rejected / Unresolved Issues**; approval and release on 23 September supersede that state.
No appeal or resubmission was performed. Do not
assert independent authorship, asset originality or absence of other-account submissions without
evidence, resubmit unchanged, or create another bundle ID to bypass the finding. A clarification
alone needs no new build; decide substantive changes after the concern is understood. There are
no paid features in this build. The owner subsequently approved public release, completed on
23 September; do not request that approval again or repeat the release action. Build `1.0.0 (7)` completed
validation/upload, Apple processing and `Family` internal distribution on 10 September, with
saved/reload-verified AI-disabled tester notes, replaced by verified enabled-pilot notes on
12 September. Build 7 is consumed and must never be reused;
the owner-controlled identity-safe handoff and clean-install first launch passed on 11 September.
The owner confirmed empty Wardrobe/History and version 7 with AI permission off; fresh server
security aggregates remained zero. The normal-state device screenshot and automated regression
complete the scoped local-beta QA; AI/public-release evidence remains separate. Do not repeat the completed
deletion/uninstall sequence; see the 11 September checkpoint in the runbook.
On 11 September the owner explicitly waived the remaining snapshot-list-expiry and deletion-
specific recovery/non-return evidence sub-gate for the Free Singapore v1. The earlier monitored
25/28 August snapshots were no longer customer-visible, but the 10 September Build-7 pre-deletion
snapshot was still listed. Record the waiver as accepted residual risk, never as passed evidence:
that snapshot's later listing disappearance, all-copy purge and deleted-identity non-return through
recovery remain unproved, and Fly's replica/backup/all-copy purge timing remains undisclosed. The
waiver removes only that evidence item as a Singapore-v1 submission
blocker. It does not close the rest of APP-009/APP-036 or authorize a restore, Fly mutation, AI
activation, Google retirement or App Store submission.
The backlog is an inventory and the runbook
retains dated evidence; do not replay completed history or turn every open item into a blocker for
all three milestones. The owner requested this simplification on 10 September 2026.

The owner reiterated on 11 September that repeatable QA belongs in the test suite. Before asking
for another manual step, check the existing test and retained physical evidence. Add an automated
regression for a deterministic coverage gap instead of assigning the user a manual test. Limit
device requests to a concrete uncovered physical boundary or changed visual behavior, and state
why automation and retained evidence cannot cover it. Do not request routine catalog/photo-edit,
relaunch, Demo or button-state contrast checks already assigned to automation.

The hourly GitHub/Healthchecks prototype is deferred and privately archived. Do not rebuild or
activate it merely because an old readiness record mentions monitoring. Use the existing approved
private budgets, fixed Fly resource envelope and owner-run daily pilot review; preserve uncertainty
and disclose residual Fly cost exposure. A new release gate needs a concrete risk and scope.

An intentionally AI-disabled beta uses the explicit `internal-beta-ai-disabled` operations-review
purpose. It may accept only verified disabled, below-warning, idle budget evidence while every
other check passes. The default `ai-launch` purpose remains strict. Beta-only eligibility is never
AI activation or public-submission approval. Perform disabled pre-enable checks before activation
and enabled post-change checks after it; do not require each to precede the other.

See `docs/freemium-model.md` for approved launch terms, planned Free/paid behavior and undecided
prices/allowances. Freemium is post-v1 and must not become a prerequisite for distributing the
current Free candidate. Retain security, privacy, honest disclosures and identity-safe deletion.

## Layout

- `ios/` — SwiftUI + SwiftData app. Project is generated by **XcodeGen** from `ios/project.yml` (the `.xcodeproj` is gitignored; run `xcodegen generate`).
  - `Wardrobe/Models/` — SwiftData `@Model`s (Item, Outfit, WearLog).
  - `Wardrobe/Backend/` — backend HTTP clients using App Attest-backed short-lived sessions.
    `/recommend` is the only v1 connected product path.
  - `Wardrobe/Views/` — SwiftUI screens: Phase 3 catalog (`CatalogView` grid grouped by dynamic categories with search/filter/sort/delete; `ItemDetailView`; pure `CatalogOrganizer`/`CatalogFilter`) and Phase 5 `TodayView` (Aria's daily look + alternates + "Wear this").
  - `Wardrobe/Capture/` — Phase 4 manual photo capture: `ImageProcessor` (pure UIKit downscale/thumbnail), `CameraPicker` (UIImagePickerController wrapper, device-only), `AddItemView` + `ItemDraft` (PhotosPicker/camera → details form → `source = .photo` Item).
  - `Wardrobe/Stylist/` — Phase 5 daily stylist "Aria": pure `CatalogCompactor` (Item → minimal `/recommend` payload, no images) + `WearHistory` (recent-worn ids for anti-repeat), and `OutfitRecommender` (`@Observable`; fetch → `/recommend` → resolve ids back to `Item`s → persist `Outfit` + per-item `WearLog`). The Today UI lives in `Views/TodayView.swift`.
  - `Wardrobe/Notifications/` — local daily nudge via `DailyOutfitNotifier`; opening the
    notification routes to Today, and no outfit is generated in the background.
  - `Wardrobe/Info.plist` — hand-managed; the v1 candidate reads the backend and public-page URLs
    from configuration-specific xcconfig files and must contain neither Google client/callback
    configuration nor `BackendDeviceToken`. xcconfig values can't contain `//` (it starts a
    comment), which is why the backend URL is split into scheme + host and composed in the plist.
  - `Wardrobe/Wardrobe.entitlements` — App Attest environment entitlement supplied by XcodeGen. Debug uses Apple's development/sandbox environment; TestFlight and App Store distribution use production. The registered App ID capability and provisioning profile must match the signed archive.
  - `WardrobeTests/` — Swift Testing unit tests + URLProtocolStub (with body capture), backend/UI
    fixtures, and `RemovedCapabilitiesReleaseGuardTests` proving the removed capability stays absent.
- `backend/` — FastAPI app (`app/`), tests (`tests/`), managed with **uv**.
  - `app/auth/` — App Attest challenge, attestation, assertion, short-lived session, rate-limit, and durable SQLite auth-state logic. The store is security metadata only: public keys, opaque Apple attestation receipts, counters, challenges, session hashes, and coarse rate windows; no wardrobe, prompt, or model-response payload enters it. Do not treat or describe the Apple receipt as independently verified until its PKCS#7/risk-metric validation policy is implemented and evidenced.
  - `app/routes/recommend.py` — `POST /recommend` (short-lived session Bearer, compact catalog + recent-worn ids → one outfit). A server-side guard rejects any item id Aria returns that wasn't in the submitted catalog.
  - `app/agents/stylist.py` — pinned Sonnet 5 candidate ("Aria"), synchronous Messages,
    strict forced `propose_outfit`, no thinking, pinned 1,024 output tokens. Caching stays off
    until production cadence supports the measured warm-cache reuse; user data remains volatile.
  - `app/styling_budget.py` / `app/styling_runtime.py` — separate durable global monthly
    admission/spend ceiling, conservative pre-call reservations, bounded concurrency, and a
    fail-closed server switch. Never auto-create a lost ledger, refund uncertain calls, or
    configure independent ledger copies on separate Machines. Private limits need owner approval.
  - `evaluation/` — fictional-only model/cache/cost evaluation. Paid runs need explicit approval
    of the current source-bound manifest, call count, and maximum cost; no production shadowing.
  - `app/schemas/recommendation.py` — Pydantic mirror of `shared/schemas/outfit.schema.json`
    (`extra=forbid`).
  - `app/dependencies.py` — fail-closed session authorization + Anthropic client provider (overridable in tests). Production must refuse legacy-only auth.
- `shared/schemas/` — JSON Schemas shared by iOS + backend (the data contract; both sides validate against these, contract test pins them to the same golden fixtures).
- `docs/` — setup + architecture (with diagrams). Read these first.

## Build & test

```bash
# Backend
cd backend && uv sync --locked
uv run --locked pytest && uv run --locked pip-audit && uv run --locked bandit -r app container_entrypoint.py -q && uv run --locked ruff check . && uv run --locked mypy app

# iOS
cd ios && xcodegen generate
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'   # or any installed iPhone sim
```

Run the backend with `--host 0.0.0.0` (not the default `127.0.0.1`) when testing from an iPhone on your LAN: `uv run uvicorn app.main:app --reload --host 0.0.0.0`.

Note: Vision feature-print / subject-lift do **not** run in the iOS Simulator — gate or mock those paths in tests and verify on a real device.

App Attest is also a physical-device boundary. Simulator tests use an injected fake service; before distribution, exercise sandbox attestation on a development-signed iPhone and production attestation/assertion/session renewal through TestFlight.

## Release impact, versioning & TestFlight

- After every completed change, explicitly decide and report whether it requires a new TestFlight build. Do not silently omit the release assessment.
- A TestFlight build is required when the change alters the shipped iOS app or its user-visible behavior, including Swift sources, bundled resources, `Info.plist`, entitlements, `ios/project.yml` build settings, or an API-contract change that requires a new iOS client. It is also required whenever the user explicitly asks to distribute a build.
- A TestFlight build is not required for documentation, `AGENTS.md`, GitHub Actions, agent configuration, tests-only changes, or backward-compatible backend-only changes that do not alter the iOS bundle.
- When a build is required, first confirm the latest build already uploaded to App Store Connect, then increment `CURRENT_PROJECT_VERSION` in `ios/project.yml` to the next unused integer. Do not change `MARKETING_VERSION` unless the user requests a new public version or the change belongs to a planned version milestone.
- App Store Connect showed builds 1-3 only immediately before build-4 validation/upload on
  2026-08-21, so the exact Gmail-free `1.0.0 (4)` archive was validated, uploaded, processed, and
  assigned to the intended internal TestFlight group. Build 4 is used and must never be reused.
  The final build-5 pre-validation refresh at `2026-08-22T03:16:16Z` again showed builds 1-4 only,
  with build 5 absent. The exact production-signed `1.0.0 (5)` archive was then validated, uploaded
  through the normal **TestFlight & App Store**-eligible route, processed, and assigned only to the
  intended `Family` Internal Testing group. Build 5 is now used and must never be reused.
  Physical QA later made build 5 non-promotable, so a replacement iOS build was required. A live,
  signed-in TestFlight **Build Uploads** inspection at `2026-08-22T10:02:31Z` showed builds 1–5
  only, build 5 **Complete**, and no build 6, confirming build 6 unused before replacement work.
  Reviewed PR #27 then merged the notification fix and build-6 metadata/allowlist to clean
  synchronized `main` `de7c540275fb16e61aabf1884538b18cf6edf76f`. Historical Fly v9 deployed
  that exact source with validation category `2` and accepted builds `4,5,6`. The exact production-signed
  `1.0.0 (6)` archive passed strict artifact, signing, dSYM, production App Attest, privacy, public-
  configuration, and Gmail-free checks. Xcode validated and uploaded it through the normal
  **TestFlight & App Store** route; Apple processing reached **Ready to Submit**. Build 6 is assigned
  only to the `Family` Internal Testing group with one group tester, no individual testers, and the
  saved truthful What to Test notes. Build 6 is now used and must never be reused. This closes the
  replacement distribution pipeline only. Build 5's identity-safe handoff, clean build-6 QA
  through the delivered-reminder tap, and build 6's final identity-safe deletion/reinstall/new-
  enrollment sequence have since passed. The earlier monitored 25/28 August snapshots were later
  observed absent from the customer-visible list. The 10 September Build-7 pre-deletion snapshot's
  later disappearance and deletion-specific recovery/non-return were not proven; the owner waived
  that evidence sub-gate for the Free Singapore v1 while accepting the documented residual risk.
  The required Fly v9 post-deploy/pre-
  upload payload-free review was missed and is
  not backdated; a late full review passed at `2026-08-23T02:13:12Z`, restoring current operational
  evidence while retaining the process defect. Repeat it before any future archive/upload and after
  every backend/configuration change.
- Build 4 was installed only as a clean processed TestFlight build. Partial physical QA found that
  a failed Restyle could hide the cached Today look until relaunch, so build 4 is historical and
  non-promotable. Build 5 appeared installed in place before the planned handoff, but the inherited
  live identity remained available: after a successful post-enrollment automatic snapshot was
  confirmed, **Delete Server Security Data** succeeded while proof of possession remained, the
  production aggregates returned to zero, local data was deleted, and the app was removed. Build 5
  was then installed cleanly. This recovery closes build 4's identity-safe handoff; it is not
  upgrade, migration, or in-place-install product evidence.
- Clean build-5 physical QA passed Gmail-free first launch, empty local wardrobe, offline Demo,
  successful Camera and Photo Library saves, the catalog flow, production enrollment and cold
  assertion renewal, online styling/Restyle, cached-look offline relaunch and failed-Restyle
  preservation, and offline Wear/History. Tapping a delivered local reminder then crashed build 5
  at `2026-08-22 17:15:14 SGT`. The crash report exactly matches the retained build-5 app/dSYM and
  safely symbolicates to the generated async Objective-C bridge for
  `DailyReminderNotificationRouter.userNotificationCenter(_:didReceive:)`, which resumed UIKit's
  completion path from a cooperative queue and triggered `SIGABRT` during state restoration. Do
  not repeat the notification tap on build 5.
- The notification fix merged through PR #27. It replaces both imported async notification-
  delegate bridges with completion-handler delegates, snapshots only Sendable response fields,
  and explicitly performs routing and completion on the main queue. Focused tests passed 17/17;
  merged-source verification retained 221 backend tests plus the locked audit/Bandit/Ruff/mypy
  gates, 231/231 iOS tests (222 Swift unit plus 9 UI), and all 43 release-script tests. The exact
  build-6 backend, archive, and App Store Connect distribution evidence is recorded above.
- Build 6 first appeared installed in place before the planned build-5 handoff. The inherited live
  identity remained available, so the app stayed installed until a successful post-enrollment
  automatic snapshot at `2026-08-23T07:34:23Z` was confirmed. **Delete Server Security Data** then
  succeeded, the production aggregates returned to zero, local data was deleted, and the app was
  removed. Build 6 was then installed cleanly. This recovery closes build 5's identity-safe handoff;
  it is not upgrade, migration, or in-place-install evidence.
- Clean build-6 physical QA on 2026-08-24 passed Gmail-free first launch, empty local state, offline
  Demo, Camera and Photo Library saves, the catalog matrix, production enrollment and cold assertion
  renewal, online styling, explicit-action cached-look recovery after offline relaunch, failed-
  Restyle preservation, offline Wear/History, and delivered-reminder routing. Tapping the reminder
  opened Today without crashing and preserved Wardrobe/History state. Today initially showing
  **Style a look** before the cached look is explicitly restored is the intended no-call-on-tab-
  appearance behavior. Deterministic DEBUG-only process-relaunch UI automation now pins that idle
  state, zero-request explicit cache restoration, failed-Restyle preservation, and Wear/History.
  A later eligible automatic snapshot at `2026-08-25T07:35:53Z`, status
  `created`, retention 14 days, cleared the final-client handoff gate. Before deletion, the live
  installation/session/challenge aggregate was `1/0/0`. Owner-controlled server deletion produced
  exactly one bounded deletion marker; post-deletion and post-uninstall aggregates were `0/0/0`.
  Clean reinstall, first launch, local item additions, and styling consent alone remained `0/0/0`.
  Explicit **Style a look** at `2026-08-28 17:17 SGT` then created one new anonymous installation
  and one active session, with zero pending/failed challenges, one completed challenge, and one
  bounded registration marker. Expected signed runtime build/category fields remained absent on
  iOS 26.6. This closes deletion/reinstall/new-enrollment proof, not snapshot-list expiry or
  deletion-specific recovery/non-return.
- A 2026-08-28 owner-supplied Dark Mode screenshot confirms that the shipped build-6 **Allow AI
  styling** control fails its visual presentation gate: the title is approximately 21 points right
  of the button center, and the sampled `#C2DFFC` fill against the white title is approximately
  `1.38:1`. This does not invalidate the passed identity or notification evidence, but build 6 is
  non-promotable. PR #31 rebase-merged app commit `b7e46e4` to clean `main` `e4a0ae2`, completing the
  replacement implementation gate with a title-only, centered, full-width opaque control,
  enabled/pressed/disabled contrast coverage, and a screenshot UI assertion. Merged verification
  passed 221 backend tests plus the locked audit/Bandit/Ruff/mypy gates, 226 Swift unit tests, 9 UI
  tests, and 43 release-script tests; both GitHub iOS checks are green. At the earlier build-selection
  checkpoint on 2026-08-29, the signed-in TestFlight **Build Uploads** view showed build 6 as the
  highest upload and **Complete**,
  with build 7 absent. Build `1.0.0 (7)` is therefore selected while `MARKETING_VERSION` remains
  `1.0.0`; source configuration is prepared with `CURRENT_PROJECT_VERSION = 7` and accepted builds
  `4,5,6,7`. A pre-deploy scan then found seven High-severity OpenSSL findings in the prior pinned
  runtime; no candidate image was pushed or deployed. Commit `6186018` refreshes the digest-pinned
  official runtime and its two crypto libraries. The rebuilt Linux/AMD64 image passed Docker Scout
  with zero High/Critical findings plus the non-root, no-new-privileges, logging, SQLite, and mounted-
  volume smoke gates. Full verification passed 222 backend tests plus locked audit/Bandit/Ruff/mypy,
  226 Swift unit tests, 9 UI tests, 43 release-script tests, and the clean `1.0.0 (7)` Release
  simulator artifact check. PR #34 rebase-merged that remediation to clean main
  `162688ae72d07f06a7a8116249632aa0101e538f`. The exact merged Linux/AMD64 image passed local and
  immutable-registry zero-High/Critical scans and the runtime smoke gates, then deployed as completed
  Fly v10 at `2026-08-29T01:52:47Z`. Live release and Machine image references match privately;
  production accepts builds `4,5,6,7` in TestFlight validation category `2`; health, route,
  App-Attest-only configuration, durable auth-store integrity, encrypted-volume use, automatic
  snapshot policy, and safe aggregate `1/0/0` all pass. The required payload-free post-change review
  passed at `2026-08-29T02:21:41Z`: the official two-day Fly metric has only `2xx`/`4xx` classes and
  no `5xx`; bounded logs have no application `5xx`, auth/App Attest, Anthropic, or rate-limit failure
  class; Anthropic status, configured-limit, below-80%-spend, production Opus 4.8, and no-saturation
  checks pass; and the public Gmail-free support/privacy/Terms pages pass anonymously. At the
  `2026-08-29T03:31:57Z` recovery-baseline checkpoint, fresh private-registry authentication re-resolved
  the exact v10 recovery reference with the expected source identity and Linux/AMD64 architecture,
  and its zero-High/Critical scan passed. The former Gmail-free v6 reference remains timestamped
  historical evidence, but its current platform/source identity was not independently proven and
  it is ineligible for rollback or recovery. At that historical checkpoint, the exact v10 immutable
  reference was the sole recovery reference; identity or scan mismatches blocked further release
  work. The disabled v11 cutover recorded below supersedes v10 as a normal recovery target.
  Post-merge exact-source regression on
  clean synchronized main `f183f074d1a63a4ec46d6d34fa13979a2c8b1fdd` passed 222 backend tests
  plus audit/Bandit/Ruff/mypy, 226 Swift unit tests, 9 UI tests, 43 release-script tests, and the
  Release simulator/artifact gates. The `2026-08-29T04:21:50Z` review was too old to satisfy the
  immediate pre-archive gate for the archive created at `07:15:57Z`; that technically verified
  Apple Distribution archive is preserved as
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-7-0cc0fa7-prearchive-review-stale-nonuploadable.xcarchive`
  and must not be uploaded. The earlier automatic-signing archive used a development profile and is
  separately retained as invalid/non-uploadable. A new full operations/recovery review against exact
  Fly v10 completed at `2026-08-29T11:02:18Z`, including a fresh private-registry match and Docker
  Scout scan with zero High/Critical findings. Clean synchronized documentation-only successor main
  `0cc0fa7eadac998d32022e3e6a9dba2a62db64c4` then produced the distinct exact `1.0.0 (7)` archive
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-7-0cc0fa7-appstore-final-20260829T110218Z.xcarchive`
  at `2026-08-29T11:03:10Z` using Xcode 26.6 and the iOS 26.5 SDK. The archive uses manual Apple
  Distribution signing with the existing App Store profile and passed the strict artifact verifier,
  production App Attest/profile/identity, public configuration, privacy, Gmail-free and non-emitting
  credential guards, deep signature verification, and matching arm64 app/dSYM evidence at
  `2026-08-29T11:04:02Z`; its minimum OS is iOS 18.0. A signed-in post-archive Build Uploads refresh
  at `2026-08-29T11:05:38Z` showed build 6 as the highest upload and **Ready to Submit**, with build 7
  absent. Validation/upload, Apple processing, `Family` assignment and tester notes remained open
  at that archive-era checkpoint. The 10 September beta-only review, separate owner approval and
  completed distribution are recorded in `docs/app-store/internal-testflight-runbook.md`.
  Build 7 is consumed. The 11 September handoff/clean installation and normal-state device
  screenshot are recorded in the runbook; routine regression belongs to automation.
- The 2026-08-29 APP-014/APP-023 automation tranche passed 222 backend tests plus locked
  audit/Bandit/Ruff/mypy, 236/236 iOS tests (226 Swift unit plus 10 UI), all 44 release-script tests,
  and the clean Release simulator/artifact gate. The isolated process-relaunch harness and transport
  are DEBUG-only; the Release verifier rejects any UI-test launch marker in a shipped executable.
  This test-only change does not alter Release code paths or the preserved build-7 archive and does
  not require build 8.
- Treat the complete release matrix as an inventory, not a manual script to replay for every build.
  Automation owns repeatable local/Gmail-free, Demo, catalog, consent/Settings, Today/History,
  reminder-control, isolated deletion, offline/relaunch, and backend-failure behavior. A processed
  TestFlight candidate still needs the owner-controlled identity-safe handoff, clean install,
  production App Attest/protected-call proof, signed runtime fields, any open live deletion/snapshot/
  recovery step, real system permission/notification/connectivity behavior, and the candidate-
  specific visual or assistive delta. Repeat an unchanged physical row only when its source or
  configuration changed, retained proof is missing, or targeted smoke exposes a regression.
- Keep the root `README.md` up to date after every relevant implementation, configuration,
  workflow, or release-state change. Include an accurate current overview and open gates, and
  keep detailed ordered evidence synchronized with this file and the release backlog/runbook.
- When an iOS candidate depends on backend source or configuration, first freeze and merge both
  sides, build and scan the exact immutable backend image, deploy it, verify the live configuration,
  health, and bounded logging, and complete the post-change manual review before archive/upload.
  Repository `fly.toml`, container/logging configuration, local tests, and a planned Fly release
  number are not production truth; confirm the live release, configuration, and digest before
  updating release evidence.
- Use `python3 backend/verify_production_operations.py --refresh-registry-auth` from clean,
  synchronized `main` to automate the repeatable read-only part of that live review. It verifies
  the locked archive, exact Fly runtime/source/configuration, read-only auth-store integrity and
  safe aggregate bands, encrypted-volume and snapshot policy, public backend/pages, Claude public
  status, and the exact recovery image's Linux/AMD64 identity plus zero-High/Critical Docker Scout
  result without emitting provider identifiers, digests, raw output, or secrets. This is an owner-
  triggered live preflight, not an offline regression or background monitor. Fly's official
  aggregate HTTP metric, signed-in Anthropic limit/spend/model/key/saturation state, and signed-in
  App Store Connect Build Uploads remain fresh manual inputs; a log-buffer check cannot substitute
  for the Fly metric. The command never accepts or performs upload approval.
- Before uploading, run the full backend and iOS regression suites, regenerate the Xcode project, create a signed Release archive, validate it, upload it to App Store Connect, add it to the internal TestFlight group, and confirm processing succeeds. Never reuse a build number.
- Before an App Attest build can ship, confirm the exact App ID prefix from Certificates, Identifiers & Profiles (do not assume it equals the Team ID), enable the capability for `com.tth.Wardrobe`, regenerate signing profiles, provision durable production auth storage, and configure explicit production allowlists for validation category (`2` for TestFlight, `4` for App Store) and accepted bundle builds. Apple adds those signed runtime fields on iOS 27+; iOS 18–26 still requires the complete core App Attest proof but cannot be build/category-gated. Retain the archive's entitlement, tester OS version, runtime-field presence, and physical-device evidence.
- If release impact, the next unused build number, signing state, or distribution intent is uncertain, ask the user before changing version metadata or uploading a build.

## Conventions

- **Models in use:** Fly v15, source `cb81d7c0e35fd36917bde0a4ab78c8bd456c257b`,
  selects pinned `claude-sonnet-5` with AI styling enabled under the approved bounded pilot.
  The 23 September AnyIO repair preserves categories `2,4`, builds `4,5,6,7`, the original
  Machine, volume, keys, private policy and intact ledger. Exact-image identity and zero-High/Critical
  scans passed; independent live verification passed health, auth integrity/capacity/disk and
  ready, below-warning, idle budget checks. See `docs/app-store/launch-check-20260923.md` for the
  final full-review and release state. Only the validated v15 image is eligible for recovery;
  the v11–v14 image has a Critical AnyIO finding and must not be restored.
  Historical v13 activation and v14 compatibility reviews passed on 12 September with the
  approved Cowork-only status exception. Physical protected-device styling passed that day.
  Disable AI under the approved response if protected-call or enabled verification fails;
  never retry uncertain work or clear liability.
  Historical v12 setup: the owner-approved configuration
  deployment retains the v11 immutable image and original Machine/volume. Independent review
  passed at `2026-09-08T09:32:49Z`: all six private policy settings and the new provider key are
  deployed, the serving UID/GID 10001 reads the existing intact zero-state v2 ledger after restart,
  and the disabled guard returns 503. All eight expected secrets, App Attest configuration/store,
  approved public-capacity review, snapshots, bounded logs, archive and public pages pass.
  The 9 September ordinary diagnostic correction selects SSH user `wardrobe`, verifies
  real/effective UID/GID 10001 before ledger access and disables Python bytecode writes. A targeted
  live read-only check passed on unchanged v12 at `2026-09-09T00:05:29Z`; that historical budget check
  returned OPEN `styling-disabled`. The earlier ownership-context failure is corrected without
  relaxing storage guards or enabling AI. No paid call was made.
  This does not close migration acceptance or the full pre-upload review. Retained Fly v10
  evidence describes the historical Opus 4.8 deployment and archive baseline. Verify SDK syntax and
  pricing against current official Anthropic documentation, use strict structured tool output
  plus authoritative local/shared validation, and retain caching only after measured cache reads
  justify it. Sonnet was evaluated only after Haiku failed the recorded quality floor.
  Do not deploy or claim migration complete before paid evaluation and the release gates pass.
  Both complete 2026-09-06 Haiku pilots failed the fixed floor. General prompt clarification
  improved completeness to 24/24, but distinct looks and required alternates each remained
  23/24; cache reads/writes were zero. The first Sonnet 5 run passed completeness/distinctness
  24/24 but failed required alternates 23/24. Its warm cache pair saved input cost; real reuse
  remains unproven and production caching stays off. The optional-item clarification's revised
  Sonnet run passed all automatic gates on 2026-09-06. The owner then said "all are ok, proceed"
  and accepted all proposals qualitatively. Preserve that separate owner decision and the
  partial numeric scorecard; never invent the missing scores or claim the numeric rubric passed.
  Preserve earlier failures and the unchanged automatic floor; see `docs/model-evaluation.md`.
  Sonnet runtime, pricing, full-context reservations, and preflight must remain aligned before
  budget approval/deployment. One unit is USD 0.000001; Sonnet costs 2 input / 10 output units and
  reserves the full 1M input context. The v2 ledger binds the model/rates/units/bounds and rejects
  old or mismatched storage without reset, upgrade, or refund. Never use Haiku-priced controls
  for a Sonnet runtime.
  Runtime admission and preflight must pin the configured output cap to the evaluated integer
  1,024 even though the ledger's general storage bound is 2,048. Numeric evaluation acceptance
  must validate the saved complete manifest and hash against the current selected source/profile;
  historical reports and qualitative owner decisions remain separate evidence.
  The owner approved the private launch spend/admission limits and owner-operated daily
  monitoring policy on 2026-09-06, based on up to 10 initial AI users. Preserve the exact limits
  in ignored private release records; do not publish them or ask for the same policy approval
  again. The policy was applied to the disabled v12 runtime and is retained by enabled v15; its original approval did not authorize source publication, provisioning,
  provider-console changes, deployment, or distribution by itself. The separate 2026-09-07
  approval covered private image publication, disabled deployment and its evidence PR only.
  The later 2026-09-07 preparation review supports first-ever storage and zero prior liability
  within the approved selected-model production scope, subject to a fresh pre-creation check.
  Fictional evaluations and earlier Opus production are excluded by that policy; preserve their
  unresolved account-level charges separately. Do not infer settlement from rounded costs or
  initialize from file absence alone. Any contradictory in-scope charge/pending work or
  lost/restored/partial ledger stops the zero-only initializer. On 2026-09-08 the owner approved
  the exact billing-reviewed finite setup proposal; the ignored approval record binds its
  manifest. Fresh automated checks, including the recovery image/scan, passed at
  `2026-09-08T08:54:09Z` except the expected OPEN budget gate; manual rows remained OPEN.
  First-ever ledger creation succeeded at `2026-09-08T08:56:32Z`, and independent read-only
  verification under service UID/GID 10001 passed at `2026-09-08T09:00:32Z`: approved policy,
  zero current-month charges/admissions, no reservations, parent 0700 and database 0600.
  Never repeat initialization or reset that ledger. The approved public-capacity file is
  installed locally as review bounds only. The dedicated production workspace now exists in the
  approved US geography; its monthly limit and two email-notification settings were saved and
  verified after reload. One approved credit purchase is paid, sufficient usable balance was
  verified, and auto-reload remains off. Exact amounts, balance, workspace/key names and provider
  identifiers remain private. Actual alert delivery remains OPEN; no native test control was seen.
  The workspace-scoped key was created with no Admin API access, transferred through hidden owner
  input and staged at `2026-09-08T09:19:59Z` without local secret persistence, then deployed in v12.
  It expires at `2026-10-08T09:13Z`; rotation before expiry is required. The finite disabled setup
  and independent post-review are complete.
  Provider alert delivery, separate AI enablement, full pre-upload review and distribution
  remained open at that setup checkpoint. The 10 September beta-only review and build-7 internal
  distribution have since passed. Separately approved AI activation completed on 12 September;
  protected-device styling proof passed on 12 September; manual public release completed on
  23 September, with public Singapore storefront availability confirmed by 14:44Z.
  The 10 September reset defers the external Fly monitor and uses the owner-run
  daily review in `docs/fly-spend-controls.md`; unproven alert delivery is not relied on.
  On 2026-09-08 the owner required Fly hosting cost protection in that pending plan. The revised
  private policy adds a separate hosting envelope and warning/hold thresholds; those private
  amounts are now approved with the finite setup. Follow `docs/fly-spend-controls.md`: keep the existing Machine/size/region/
  volume/IP envelope, cost any expansion or paid service separately, reconcile organization-wide
  charges through the current daily review. Never claim the AI ledger, prepaid credit, autostop or a bare
  Machine stop caps the Fly invoice. A reviewed service hold must prevent autostart/restart while
  preserving durable data and uncertainty. No automated monitor or hold is active; the current
  operating review must disclose detection delay and variable charges. Hold execution requires
  separate approval, and no absolute invoice cap has been established.
  The initial signed-in 2026-09-08 billing review matched the invoice preview and Cost Explorer;
  the later pre-deployment refresh diverged across the same five products. Use the higher private
  preview for planning and retain feed reconciliation OPEN; no cutoff or lag guarantee is proven.
  The September 9 refresh showed an increased preview and unchanged same-period Cost Explorer;
  read-only CLI inventory still matched the original resources. A private monitoring-readiness
  proposal separates inventory, traffic and billing evidence. `backend/verify_fly_spend.py`
  assesses supplied private records locally; it does not authenticate their origin, collect live
  data, forecast charges, send alerts or execute holds. Unknown coverage and unreconciled totals
  remain OPEN even if the separately reported observed amount crosses a warning/hold threshold.
  The September 9 runner, delivery, missed-run and source-freshness proposal was superseded by
  the 10 September manual-review plan; these are deferred automation requirements, not active
  launch gates. The September 9 privacy proposal, reconciled on 12 September, is approved and
  published through website PR #6. The four reviewed Apple privacy categories are published and
  reload-verified. The unchanged flow retains build 7/consent version 3; see
  `docs/app-store/ai-pilot-privacy-review-20260912.md`. Disabled pre-enable checks and separate AI
  activation completed on 12 September; the physical protected call passed at 13:34 SGT. Build
  `1.0.0 (7)` was resubmitted on 13 September; the 16 September business-model reply was sent at
  16:14 SGT. The later Guideline 4.3(a) clarification was sent at 15:46 SGT on 19 September and
  verified in Messages (6). The 19 September checkpoint remained Rejected / Unresolved Issues with release unapproved;
  Apple approval and owner-authorized release completed on 23 September as recorded above.
  Compare pre-tax service consumption
  before discretionary waivers and prepaid/promotional credits; show net payable separately.
  A previous invoice waiver is not a future allowance. Preserve the frozen preparation records;
  the later ignored approval record authorizes only the bound finite setup, not AI enablement.
  The old v11–v14 image is historical and ineligible for recovery after the Critical AnyIO
  finding. Only the validated v15 image is eligible, subject to fresh identity/security and
  ledger-compatibility verification before recovery.
  Preserve that ledger, approved policy and liability across recovery. Pre-budget v10 ignores
  these controls and is not a normal rollback target after
  this cutover; its retained recovery evidence describes the earlier baseline.
- **Gmail-free guard:** `RemovedCapabilitiesReleaseGuardTests` and artifact/configuration scripts must fail if
  Google/Gmail/receipt-import source, configuration, SDK bundles, routes, or background identifiers
  return.
- **Code signing:** simulator builds use ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`) so Keychain works without a team. Device builds use automatic signing; local Debug values come from `Secrets.xcconfig`, while distribution Team ID and identifiers come from the separate gitignored `Distribution.xcconfig`. Adding App Attest to the registered App ID invalidates old profiles, so inspect both archive entitlements and the embedded profile.
- **App Transport Security:** the backend is on HTTPS (Fly.io), so `Info.plist` carries **no** ATS exception — the dev-only `NSAllowsArbitraryLoads` + `NSLocalNetworkUsageDescription` keys were removed once production went HTTPS. If you need to point the app back at a plain-HTTP LAN dev backend, re-add an `NSAppTransportSecurity` exception locally (don't commit it).
- **Commits:** Use logically independent Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `ci:`). Do not add AI co-author or attribution trailers unless the user explicitly requests one.
- **Linear Git history:** Before opening or updating any PR, fetch `origin` and rebase the feature branch onto the latest `origin/main`; do not merge `main` into a PR branch. Prefer `git pull --rebase` for pulls. If rebasing an already-published PR branch rewrites it, verify that the branch is not shared and update it with `git push --force-with-lease`—never plain `--force`.
- **PR review lifecycle:** Push new PRs as drafts, then immediately mark them ready for review. Wait
  for Codex review to finish before merging; 👀 means review is still running and 👍 on the current
  head means no findings. Address every actionable current-head finding, run the required focused
  and full regression gates, push the fixes, request another Codex review, and repeat until the
  current head receives 👍 with no actionable review thread. Then rebase-merge the PR, delete its
  remote feature branch, fetch/prune `origin`, switch to `main`, and fast-forward only to
  `origin/main`. Finally audit local branches for reachability, upstream state, other worktree use,
  and unique commits/tree changes; delete only branches proven merged or tree-equivalent, and
  preserve anything ambiguous or containing unique work.
- **iOS target:** iOS 18 deployment, Swift 6 language mode, Swift Testing for new tests, XCTest only where needed (UI flows / `URLProtocol` stubbing).

## Code review rules

- Treat any Google/Gmail/receipt-import capability in the public-v1 source or archive as a release
  blocker.
- Flag secrets, API keys, device tokens, OAuth credentials, or production configuration embedded in the iOS target or committed files. Anthropic credentials belong only in backend environment/Fly.io secrets.
- Treat any shared client bearer, Google-backed Wardrobe account requirement, client-asserted
  "unsupported App Attest" bypass, reusable challenge, non-monotonic assertion counter, sandbox
  credential accepted in production, or in-memory-only production auth state as a release
  blocker. Auth-state updates must be atomic and survive Fly restarts/deploys.
- App Attest's core certificate/key/nonce proof authorizes the installation. The opaque Apple receipt is separate fraud-risk evidence: never claim or consume it as trusted until its Apple receipt signature, chain, App ID, freshness, and public-key binding checks are implemented against official fixtures.
- Flag backend/iOS payload changes that are not reflected in the JSON Schemas, their Pydantic and Swift mirrors, golden fixtures, and contract tests.
- Flag recommendation paths that accept item ids not present in the submitted catalog or otherwise weaken the server-side hallucination guard.
- Review Swift 6 concurrency boundaries carefully, especially `@MainActor`, `@Sendable`, background-task callbacks, and non-Sendable system framework types.
- Flag behavior changes without focused tests. Require the full backend and iOS regression suites
  described above after every code, runtime, configuration or test change. Documentation-only
  evidence updates may retain the completed regression when all tested code/configuration inputs
  are unchanged; require documentation consistency review for those updates. This does not exempt
  executable, configuration or test changes from the full regression requirement in hard rule 5.

## Roadmap (phases)

The original phases 1–2 and receipt-sync portion of phase 6 implemented read-only Gmail import;
that work is now historical and deferred from public v1. The approved v1 cut is: local/manual and
photo catalog, browse/edit/history, optional explicit-action AI styling, local reminders, offline
Demo Mode, and anonymous App Attest backend authorization. Gmail/OAuth/receipt import may be
reconsidered only as a later, separately reviewed release. See `docs/app-release-backlog.md`.
