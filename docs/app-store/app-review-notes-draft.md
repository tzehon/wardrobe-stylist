# App Review notes — historical operational draft

> **23 September status:** Apple approved build 7 and the owner-authorized manual release
> completed after the full preflight passed. The public Singapore listing is live and availability was verified. Fly v15 was deployed at that checkpoint. See the [launch record](launch-check-20260923.md) for that dated evidence;
> earlier rejection, wait-for-reply and unapproved-release statements below are historical.

For the prepared build-7 submission, use [the concise reviewer notes](review-notes-1.0.0.txt).
The historical placeholders below are not paste-ready and must not be uploaded.

> Reconcile these notes with the exact submitted Gmail-free build. Remove every TODO and
> placeholder before submission.
>
> Historical 12 September checkpoint: `1.0.0 (7)` had completed
> [internal TestFlight distribution](internal-testflight-runbook.md#build-7-distribution--2026-09-10)
> with AI disabled. Handoff, clean installation and scoped local-beta QA passed on 11 September.
> Privacy publication, consent assessment and separately approved bounded v13 activation passed
> on 12 September. Protected-device styling proof passed and build 7 was submitted, reaching
> **Waiting for Review** at that checkpoint. The [19 September assessment](spam-rejection-20260919.md)
> records the subsequent rejection and sent clarification. Do not repeat the completed handoff
> or routine QA.

## Product summary

Wardrobe Stylist is a local-first wardrobe catalog and optional AI styling app. Users add items
manually or from photos, browse and edit the catalog, record worn looks, and can ask Aria for an
outfit suggestion. Public v1 does not connect to Google, read email, import receipts, or require a
Wardrobe account or login.

Version 1.0 is Free and available only in the Singapore App Store. It offers no in-app purchase or
subscription; every feature described for this version is included without payment. Do not attach
or describe the separately planned freemium product until a later binary implements it.

When a user explicitly requests remote AI styling, Apple App Attest verifies that installation and
the backend issues a short-lived anonymous session. Local catalog, history, reminders, and Demo
Mode do not require the backend.

## Reviewer path without personal data

1. Launch the app.
2. Choose **Try the offline demo**. Its banner says **Demo Mode · Fictional Data** and
   **Offline · Changes are discarded**.
3. Open **Wardrobe** to browse, search, edit, and delete fictional manual/photo items.
4. Open **Today** to view the bundled recommendation. This path does not construct an AI network
   client.
5. Open **History** to inspect a fictional previously worn look and its pieces.
6. Open **Settings** to reset the disposable data or exit the tour.

No credentials or review account are required. Demo data uses a dedicated in-memory store and is
discarded on reset or exit; entering the tour does not open or modify the production wardrobe. The
same deterministic path is covered by `--wardrobe-demo`, but reviewers should use the visible
first-run button.

App Attest is not required for this offline reviewer path. If secure installation verification,
the network, or the backend is unavailable, local wardrobe and Demo Mode remain usable and only
remote AI fails closed with a recovery message. The app does not mint an unauthenticated fallback
session.

## Optional AI styling path

Current pilot state: [Fly v16 retains the enabled pilot within the approved global limits](key-rotation-20260929.md).
The first protected TestFlight call passed on 12 September. The connected App Review path below still requires
verification and completion of its placeholders before public submission.

1. Add at least [MINIMUM ITEM COUNT] fictional items manually or from photos, or use the provided
   App Review fixture [VERIFY EXACT SUBMITTED PATH].
2. Open **Today** and request a suggestion.
3. Read and accept the styling disclosure immediately before the first transmission.
4. Optionally enter a short occasion and request the look.
5. Confirm the suggestion resolves only to items already in the local catalog; use **Wear this**
   to add it to local History.

No login is required. If App Review needs a deterministic connected path, describe the exact
submitted fixture here; never provide personal data or a shared backend credential.

## Third-party AI disclosure

Before styling data is transmitted, the app identifies the developer backend and Anthropic and
describes the compact text fields and purpose. With styling consent absent or withdrawn,
request-capture tests verify `/recommend` is not called. Wardrobe photos, purchase metadata, wear
dates, and feedback free text are not included in v1 styling requests.

The developer application does not persist wardrobe, prompt, or model-response payloads. The
backend retains minimum anonymous App Attest authentication and abuse-prevention metadata plus a
separate aggregate AI budget/reservation ledger. That ledger contains global accounting and
unresolved reservation metadata, with no installation or human-account identifier.
Retention, logging, deletion, snapshots, and manual production operations follow the
[APP-009 lifecycle policy](app-attest-data-lifecycle-policy.md). [VERIFY THE SUBMITTED COMMIT AND
EVERY UNCHECKED POLICY-COMPLIANCE ITEM BEFORE SUBMISSION.]
The [12 September privacy review](ai-pilot-privacy-review-20260912.md) records the published policy
and Apple declarations, including this aggregate store. Build 7 and notice version 3 cover the
unchanged flow. Refresh submitted-build/runtime facts before using these notes; privacy
publication does not enable AI or submit the app.

The submitted build exposes **Settings → Privacy & Data → Delete Server Security Data**. It uses a
fresh App Attest assertion to delete the current installation's live anonymous server record and
sessions. This is separate from deleting the local wardrobe and does not reset the global budget
ledger or its unresolved charged exposure.

## Reminders and background behavior

Daily reminders are local notifications, off by default, and requested only after the user enables
them. The notification does not claim that an outfit was generated in the background; opening it
routes to Today. Public v1 has no Gmail or receipt background task. Clean build 6 physically proved
delivery and tap routing: the app opened Today without crashing and preserved local state.

## Backend availability

- Production API: [HTTPS HOST]
- Health URL: [HEALTH URL]
- Review-window minimum instances: [VALUE]
- Support: `https://blog.tth.dev/wardrobe/`
- App Attest environment and tester OS/runtime fields:
  [PRODUCTION / OS VERSION / EXTENSIONS PRESENT OR EXPECTED ABSENT]
- Configured App Attest category/build allowlist (configuration only; do not claim iOS 27+
  enforcement without separate physical evidence): [TESTFLIGHT 2 OR APP STORE 4 / EXACT BUILD]
- Durable auth-store/restore evidence: [REFERENCE]

## Non-obvious implementation assurances

- The signed public-v1 archive contains no Google Sign-In SDK/client configuration, Gmail scope or
  route, receipt-import client path, or receipt background task. [MUST BE TRUE.]
- The server rejects recommendation item IDs not present in the submitted catalog.
- Styling requests and responses are schema-validated.
- The public client contains no Anthropic key or shared backend bearer. [MUST BE TRUE.]
- Backend authorization uses an Apple-certified key unique to this installation and a short-lived
  session. Reinstalling creates a new anonymous installation identity; it does not create or link
  a human account.
- Server authentication-data deletion is distinct from local wardrobe deletion. It requires a
  fresh App Attest assertion, removes the current live identity and sessions, and then clears the
  app's local server-identity reference. The separate aggregate budget ledger remains intact.
- Sign in with Apple is not presented because the app has no human account or login. App Attest is
  installation security, not an account system.

## Build-specific checks before pasting these notes

Build 4 is historical internal-QA evidence and must not be submitted: physical testing found the
Today offline-cache Restyle defect. Build 5 also must not be submitted: its strictly verified
production-signed archive completed Organizer validation, upload, processing, and `Family`
Internal Testing assignment by `2026-08-22T03:24:21Z`, but clean physical QA later found a local-
notification tap crash. At the `2026-08-22T01:09:39Z` archive-time refresh, App Store Connect
showed build 4 as the highest upload and build 5 unused; the final pre-validation refresh at
`2026-08-22T03:16:16Z` again showed builds 1–4 only and build 5 absent. Build 5 is now consumed and
non-promotable. A signed-in TestFlight Build Uploads refresh at `2026-08-22T10:02:31Z` showed
builds 1–5 only, build 5 **Complete**, and no build 6, confirming build 6 unused before replacement
work. PR #27 later merged the fix and build-6 metadata/allowlist; exact Fly v9, strict archive,
normal-route Xcode validation/upload, Apple processing, `Family` assignment, and tester-note checks
passed. Build 6 is consumed and must never be reused. Its later clean physical run passed through
the fixed delivered-reminder tap. The final identity-safe deletion/reinstall and new anonymous
enrollment completed on 2026-08-28. A same-day owner-supplied Dark Mode screenshot then confirmed
that the **Allow AI styling** title is approximately 21 points right of center and its sampled
`#C2DFFC` fill against white is approximately `1.38:1`. Build 6 is therefore non-promotable. PR #31
has since merged and verified the replacement control implementation. At the earlier build-selection
checkpoint on 2026-08-29, the signed-in TestFlight **Build Uploads** view showed build 6 as the
highest upload and **Complete**, with build 7
absent. Build `1.0.0 (7)` is selected while `MARKETING_VERSION` remains `1.0.0`; source configuration
records accepted builds `4,5,6,7`. The exact merged Linux/AMD64 backend deployed as completed Fly
v10 and passed the required post-change review on 2026-08-29; the exact-source regression also
passed. The `04:21:50Z` review and `07:15:57Z` archive are timing-stale/non-uploadable evidence, and
the earlier development-signed archive is separately invalid/non-uploadable. A fresh full review
completed at `11:02:18Z`, followed by the distinct final signed archive at `11:03:10Z` and strict
verification at `11:04:02Z`. The signed-in `11:05:38Z` Build Uploads refresh showed build 6 highest
and **Ready to Submit**, with build 7 absent at that historical checkpoint. The later
[10 September distribution](internal-testflight-runbook.md#build-7-distribution--2026-09-10)
completed build-7 validation/upload, processing, internal assignment and saved/reloaded tester
notes with AI disabled. The 11 September checkpoint records completed handoff and scoped
local-beta QA. The 10 September snapshot-list/deletion-recovery evidence is unproved but owner-
waived only for the Free Singapore v1. The [12 September privacy review](ai-pilot-privacy-review-20260912.md)
completed consent reconciliation and policy/Apple publication. Separately approved bounded
v13 activation and protected-device styling proof passed on 12 September. Build 7 was submitted
and reached **Waiting for Review** at that checkpoint; see the
[19 September assessment](spam-rejection-20260919.md) for the subsequent rejection and sent
clarification. Manual public release remains unapproved. Reviewed
PR #23 remains the historical build-5 source
baseline. Historical build-5 pre-archive gates were green (221
backend tests plus audit/Bandit/Ruff/mypy, 218 Swift unit tests, 9 UI flows, 43 release-script tests,
and Release simulator/artifact checks). Historical Fly v8 deployed that source with production
category `2`, builds `4,5`, and targeted auth-service INFO logging; its post-change review passed at
`2026-08-21T11:09:20Z`, the pre-archive repeat passed at `2026-08-22T01:07:45Z`, the pre-validation
review passed at `2026-08-22T02:37:08Z`, and the separate post-distribution review passed at
`2026-08-22T03:30:33Z`. Later physical flows observed bounded registration, assertion, and deletion
success markers against v8. Historical Fly v9 deployed the exact merged build-6 source with category
`2`, accepted builds `4,5,6`, and matching healthy release/runtime image references. The required v9
post-deploy/pre-upload review was missed and is not backdated; a late full operational review
passed at `2026-08-23T02:13:12Z`. Repeat it before any future archive/upload and after every
backend/configuration change.

- [ ] Replace every backend, health, fixture, and contact placeholder.
- [ ] Confirm Demo Mode labels, item count, and reviewer steps against the exact uploaded build.
- [x] Confirm the exact build-5 signed archive has no Google/Gmail/receipt-import capability. The
  strict verifier and separate non-emitting credential/removed-capability scan passed for
  `Wardrobe-1.0.0-5-695c562-appstore.xcarchive`.
- [x] Confirm the exact build-6 signed archive has no Google/Gmail/receipt-import capability. The
  strict verifier and separate signing, production App Attest, privacy, public-configuration,
  credential-absence, and removed-capability checks passed for
  `Wardrobe-1.0.0-6-de7c540-appstore.xcarchive`.
- [x] Confirm the exact final build-7 signed archive has no Google/Gmail/receipt-import capability.
  The strict verifier and separate Apple Distribution, production App Attest, privacy, public-
  configuration, credential-absence, removed-capability, deep-signature, and app/dSYM checks passed
  for `Wardrobe-1.0.0-7-0cc0fa7-appstore-final-20260829T110218Z.xcarchive` at
  `2026-08-29T11:04:02Z`. Both earlier build-7 archives are explicitly non-uploadable.
- [x] Confirm processed build 6 presents no human-login screen. Its clean first launch showed
  **Your wardrobe, your way** and an empty wardrobe, with no Google/Gmail/receipt-import path.
- [x] Record the pre-upload transition. The installed development build disconnected Google,
  deleted local data, and was uninstalled after production showed zero installations, zero sessions,
  and zero pending challenges. It predated the server-deletion UI, so do not claim that unavailable
  action succeeded or claim in-place migration support.
- [x] Confirm processed build 4 is distributed only to the `Family` Internal Testing group with the
  saved truthful What to Test wording reproduced in the internal runbook.
- [x] Confirm processed build 5 is distributed only to the `Family` Internal Testing group with the
  saved truthful build-specific What to Test wording reproduced in the internal runbook. The build
  lists one tester through that group and no individual testers. This assignment was not physical
  proof and did not authorize installation or update before build 4's identity-safe handoff, which
  later completed as recorded below.
- [x] Retain the historical clean build-4 TestFlight install on iPhone 16 Pro/iOS 26.6 as partial
  evidence only; it was never installed over the older app and is not migration evidence.
- [x] Complete the build-4 identity-safe handoff. An eligible automatic snapshot created at
  `2026-08-22T07:33:23Z` reported `created` with 14-day retention. Build 4 proof remained available
  after build 5 appeared installed in place unexpectedly; assertion-verified server deletion emitted
  exactly one success marker and live installations/sessions/challenges reached `0/0/0`. Local
  data and then the app were deleted, and build 5 was installed cleanly. Do not claim migration.
- [x] Retain clean build-5 physical evidence through notification delivery. Offline Demo Mode,
  Camera and Photo Library saves, the full local catalog flow, online Style at `16:30`, cached
  relaunch, Restyle at `17:04`, failed-offline-Restyle cached-look preservation, and offline Wear
  this/History passed. The local reminder delivered.
- [x] Physically retest the replaced notification response routing. Build 5's delivered tap crashed
  as retained above; do not repeat it. On clean build 6, the reminder delivered at `20:53 SGT` and
  tapping it opened Today without a crash. One explicit **Style a look** tap restored the cached
  look locally, and Wardrobe/History state remained intact.
- [ ] Confirm the production API is healthy throughout the review window.
- [x] Confirm App Attest is enabled for the exact App ID/prefix and the build-6 archive/profile
  contain matching production authorization. The strict verifier matched the prefix, team, bundle,
  Apple Distribution certificate, App Store profile, and scalar production entitlement.
- [x] Confirm processed build 6 completes production registration and assertion renewal on iPhone
  16 Pro/iOS 26.6, with expected signed runtime-field absence. Do not claim iOS 27+ category/build
  enforcement.
- [ ] Confirm durable auth storage, logging/retention claims, rate
  limits, and a retained Gmail-free App-Attest-only recovery image against the deployed backend.
  The current [enabled Fly v16 runtime](key-rotation-20260929.md)
  retains the verified targeted logger and `4,5,6,7` allowlist. The
  [10 September checkpoint](internal-testflight-runbook.md#build-7-distribution--2026-09-10)
  records the completed AI-disabled beta distribution. The monitored 25/28 August snapshots were
  observed absent; the 10 September Build-7 pre-deletion snapshot's later disappearance and
  deletion-specific non-return are unproved but owner-waived only for the Free Singapore v1. Other
  public-release privacy/recovery checks remain open. The historical v10 post-change review passed
  on 2026-08-29. Predecessor v8's payload-free
  review passed, and the late non-backdated historical v9
  review passed at `2026-08-23T02:13:12Z`. The first historical v9 post-
  deploy bounded query was zero because no lifecycle flow had yet been exercised. Later clean
  build-5 Style/Restyle observed `registration_succeeded`/`assertion_succeeded`, and the preceding
  identity-safe handoff observed exactly one `installation_deleted` plus `0/0/0` live aggregates.
  Build 5's later identity-safe handoff also returned aggregates to zero. The eligible
  `2026-08-25T07:35:53Z` snapshot enabled Build 6's final owner-controlled deletion/reinstall: the
  pre-deletion aggregate was `1/0/0`, exactly one bounded deletion marker was observed, and post-
  deletion/post-uninstall aggregates were `0/0/0`. Clean reinstall and local-only actions remained
  at zero; explicit Style at `2026-08-28 17:17 SGT` created one new anonymous installation and
  active session, with zero pending/failed challenges, one completed challenge, and one bounded
  registration marker. Signed runtime fields were absent on iOS 26.6; do not claim iOS 27+
  category/build enforcement. Protected `/recommend` remains aggregate/client-evidenced. The
  monitored 25/28 August snapshots were later observed absent from the customer-visible list. The
  10 September Build-7 pre-deletion snapshot's later disappearance and deletion-specific restore/
  non-return were not proven; the owner waived only that evidence sub-gate for the Free Singapore
  v1 on 2026-09-11 and accepted the residual risk. The former v5 image is only a pre-
  build-4 abort because it re-exposes `/extract` and halts release.
- [x] Confirm live server-security-data deletion using only redacted evidence: build 4 and final
  build 6 each produced exactly one bounded success marker and reached aggregate `0/0/0` before
  local data/app removal. No identifiers, raw logs, or payloads were retained.
- [x] Record the owner-approved snapshot/recovery evidence waiver for Free Singapore v1. The final
  handoff does not prove that the still-listed 10 September pre-deletion snapshot later disappeared
  or that the deleted identity cannot return through recovery. The monitored 25/28 August snapshots
  were separately observed absent. The 2026-09-11 decision accepts the remaining residual risk;
  this marks the waiver, not the missing evidence as passed.
- [x] Confirm the build-6 **Allow AI styling** presentation failure before using these notes for
  submission. The 2026-08-28 owner-supplied Dark Mode screenshot places the title approximately
  21 points right of center and measures the sampled `#C2DFFC` fill against white at approximately
  `1.38:1`. Build 6 is non-promotable; its completed identity and notification proof remains valid.
- [x] Complete and verify the replacement control implementation. PR #31 rebase-merged app commit
  `b7e46e4` to clean `main` `e4a0ae2`. The title-only control is centered, full-width, and opaque;
  enabled/pressed/disabled contrast coverage and the screenshot UI assertion passed. Merged
  verification retained 221 backend tests plus audit/Bandit/Ruff/mypy, 226 Swift unit tests, all
  9 UI tests, and 43 release-script tests; both GitHub iOS checks are green.
- [x] Select and source-prepare build 7 without claiming deployment. The signed-in TestFlight
  **Build Uploads** view on 2026-08-29 showed build 6 as the highest upload and **Complete**, with
  build 7 absent. Select `1.0.0 (7)`, keep `MARKETING_VERSION = 1.0.0`, and prepare source
  configuration for accepted builds `4,5,6,7`. At selection time, Fly v9 still accepted `4,5,6`.
- [x] Deploy and review the archive-era build-7 backend. Fly v10 accepted `4,5,6,7`; exact image,
  health/configuration/storage/snapshot, and payload-free review passed on 2026-08-29. The current
  [enabled Fly v16 runtime](key-rotation-20260929.md) retains
  the verified auth/build allowlist. The later beta-only review and
  [build-7 distribution](internal-testflight-runbook.md#build-7-distribution--2026-09-10) passed;
  Bounded activation is complete; protected-device styling proof passed on 12 September; manual release completed on 23 September; public Singapore storefront availability was confirmed by 14:44Z on 23 September.
- [x] Complete the build-7 exact-source regression. Clean synchronized main
  `f183f074d1a63a4ec46d6d34fa13979a2c8b1fdd` passed 222 backend tests plus
  audit/Bandit/Ruff/mypy, 226 Swift unit tests, all 9 UI tests, 43 release-script tests, and the
  Release simulator/artifact gates.
- [x] Repeat the full operations/recovery review immediately before archive and strictly verify the
  distinct final archive. The exact-v10 review, including a fresh private-registry match and zero-
  High/Critical Docker Scout scan, completed at `2026-08-29T11:02:18Z`; the final archive was
  created at `11:03:10Z` and verified at `11:04:02Z`. The signed-in `11:05:38Z` refresh showed build
  6 highest and **Ready to Submit**, with build 7 absent. The stale-review and development-signed
  archives remain non-uploadable.
- [x] Complete build-7 internal distribution after the beta-only operations review and separate
  owner approval. Normal-route validation/upload and processing passed on 10 September;
  `1.0.0 (7)` is assigned only to `Family` Internal Testing with one group tester and no individual
  testers, and the approved AI-disabled notes persisted after reload. See the
  [distribution checkpoint](internal-testflight-runbook.md#build-7-distribution--2026-09-10).
  Build 7 is consumed; this does not authorize public submission or prove physical QA.
- [x] Complete build-7 handoff, clean installation and scoped local-beta QA. The
  [11 September checkpoint](internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial)
  records the completed owner-controlled sequence and normal-state Dark Mode screenshot.
  Automated tests cover enabled/pressed/disabled contrast; retain unchanged device evidence.
  Do not repeat deletion, uninstall or routine QA. AI activation and public submission remain separate.
- [x] Retain the historical build-6 App Store Connect number check before archive/upload. The
  signed-in TestFlight Build Uploads view at `2026-08-22T10:02:31Z` showed builds 1–5 only,
  build 5 **Complete**, and no build 6. Build 6 is confirmed unused and selected;
  `MARKETING_VERSION` remains `1.0.0`. The subsequent completed upload consumes build 6; never
  reuse it.
- [ ] Confirm the obsolete shared-bearer build is rejected without breaking the submitted build.
- [ ] Attach a short screen recording only if the optional styling path needs clarification.
- [x] Retain explicit synthetic request-capture evidence for the exact allowlisted `/recommend`
  fields. The tests-only guard inventories all stored properties, including nil optionals, and
  separately pins the encoded top-level, catalog-item, and preference keys; the shared schema/
  backend reject extras. Strengthened focused `RecommendClientTests` passed 12/12 at
  `2026-08-22T01:59:08Z`. The post-guard tree then passed the mandatory 221-test backend gate and
  one uninterrupted historical pre-archive 218-unit/9-UI iOS regression whose result bundle finalized at
  `2026-08-22T02:04:17Z`. The exact signed build-5 archive separately passed the public Release,
  privacy-manifest, and artifact-absence verifier. No production payload was inspected or retained.

## Contact

Review contact: [NAME, EMAIL, PHONE, TIME ZONE]  
Escalation contact during review: [NAME, EMAIL, PHONE]
