# Internal TestFlight, always App-Store-ready

Use this runbook for every internal beta. The audience is internal, but the binary is treated as
an App Store release candidate from the moment it is archived. This prevents a separate, weaker
"beta build" configuration from drifting away from what will eventually be reviewed.

## Distribution policy

- Upload with Xcode's **TestFlight & App Store** distribution option, then add the processed build
  only to an App Store Connect **Internal Testing** group.
- Do **not** choose **TestFlight Internal Only**. Apple marks that artifact as internal-only, so it
  cannot later be submitted to external testers or customers.
- Do not bypass the device-Release configuration guard. Internal testers must exercise the same
  production identifiers, HTTPS endpoints, privacy manifests, disclosures, and authentication
  architecture intended for App Review.
- Keep Debug/LAN credentials in `Secrets.xcconfig`. Keep non-secret distribution identifiers and
  endpoints in the gitignored `Distribution.xcconfig`. Never place a shared backend bearer or an
  Anthropic key in either public client configuration.
- Adding a build to an internal group is not an App Store submission. Promotion happens later by
  selecting the same processed build on the App Store version and submitting it for review.

## Current release status — 2026-08-28

- Version metadata baseline: PR #12 commit `b000fdfb19ae496a42c6c38565d961a929801c17`
  contains `1.0.0 (4)`. Final Gmail-free product/backend source merged through PR #14 as
  `9a48caebdec67ac26673c3ba51546a5e7edcf0cc`; local and remote `main` were synchronized before
  the release image was built. The archive source is later `dd3d99061321cf91bdce166e7da579b84edb07e8`,
  which adds the signed-profile verifier fix without changing that shipped app bundle. PR #19 then
  rebase-merged the reviewed Swift/backend/contract/verifier fixes as
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`. Documentation-only PR #20 then produced clean
  synchronized archive context `24c17cb9fe643035f9206ee61e2935e086902146`; `ios/`, `backend/`,
  and `shared/` are unchanged from the reviewed code merge. The reviewed backend is deployed and
  the historical build-4 replacement regression/archive are verified.
- Historical uploaded version/build: `1.0.0 (4)`. App Store Connect showed builds 1-3 only at
  `2026-08-21T06:34:50Z` before the replacement archive and again at `2026-08-21T08:12:46Z`
  immediately before validation/upload. Build 4 then uploaded, processed, and entered internal
  testing, so it is consumed and must never be reused. The historical `dd3d990` signed archive
  remains superseded and was not validated or uploaded.
- Historical build-5 distribution and completed build-6 distribution: the archive-time App Store Connect refresh at
  `2026-08-22T01:09:39Z` and final pre-validation refresh at `2026-08-22T03:16:16Z` showed builds
  1–4 only and build 5 absent. That archive used `MARKETING_VERSION = 1.0.0` and
  `CURRENT_PROJECT_VERSION = 5`. The exact production-signed build-5 archive is strictly verified,
  Organizer-validated, uploaded, processed, and assigned only to the `Family` Internal Testing
  group. Build 5 is consumed and must never be reused. Build-4 identity-safe recovery/handoff and
  broad clean build-5 physical QA later completed, but tapping a delivered reminder crashed build 5;
  it is non-promotable and a replacement iOS build was required. A read-only signed-in TestFlight
  **Build Uploads** inspection at `2026-08-22T10:02:31Z` (`18:02:31 SGT`) showed builds 1–5 only,
  build 5 **Complete**, and no build 6, confirming build 6 unused before replacement work.
  Reviewed PR #27 then merged the notification fix and build-6 metadata/allowlist to clean
  synchronized `main` `de7c540275fb16e61aabf1884538b18cf6edf76f`. Fly v9, the strict build-6
  archive, Xcode validation/upload through the normal App-Store-eligible route, Apple processing,
  `Family` assignment, and truthful tester-note save all passed. Build 6 is consumed and must never
  be reused. A later 2026-08-28 Dark Mode screenshot confirmed its styling-consent control
  presentation failure, so build 6 is non-promotable and an unnumbered replacement is underway.
  The root `README.md` remains unchanged by design; this runbook and the release backlog own live
  release state.
- Notification-fix merged evidence: focused tests passed 17/17. Merged-source verification retained
  221 backend tests plus locked dependency audit/Bandit/Ruff/mypy, 231/231 iOS tests (222 Swift unit
  plus 9 UI), and all 43 release-script tests. Clean build-6 physical QA then closed the affected
  delivered-reminder-tap proof: the notification opened Today without a crash or local-state loss.
- Current production backend baseline: Fly release v9 completed at `2026-08-22T11:14:25Z` and
  serves the exact merged build-6 source as `linux/amd64`. The release and running image references
  match; a local-only official Alpine secdb comparison found zero unfixed advisories; and locked
  `pip-audit` passed. One healthy Singapore Machine runs with `min_machines_running = 1`;
  production App Attest uses category `2` and accepted builds `4,5,6`; and the encrypted auth store
  and bounded logging configuration remain healthy. `/health` returns `200`, `/extract` returns
  `404`, unauthenticated `/recommend` returns `401`, and the OpenAPI route set matches the reviewed
  source. Build 5 completed its identity-safe handoff, and build 6 then passed clean physical QA.
  A later automatic snapshot created at `2026-08-25T07:35:53Z` reported `created` with 14-day
  retention and was eligible for the final build-6 handoff. The pre-deletion aggregate was one
  installation, zero sessions, and zero challenges. Assertion-verified deletion emitted
  exactly one bounded deletion-success marker and returned the aggregate to `0/0/0`; it remained
  `0/0/0` after local deletion and uninstall. A clean reinstall, launch, two local wardrobe adds,
  and styling-consent grant also left the backend at `0/0/0`. Only the explicit **Style a look**
  action at `2026-08-28 17:17 SGT` enrolled the new anonymous identity: one active installation,
  one active session, zero pending and zero failed challenges, one completed challenge, and exactly
  one bounded registration-success marker. Signed runtime category/build fields remained absent as
  expected on iOS 26.6.
- The required v9 post-deploy/pre-upload payload-free review was missed and cannot be backdated. A
  late full review completed at `2026-08-23T02:13:12Z`: exact release/runtime/source, public health,
  automatic 14-day snapshot policy and freshness, below-warning volume use, a current Fly HTTP view
  without a 5xx series, zero bounded failure classes, Anthropic public status/configured-limit/
  below-80%-spend/production-Opus-4.8/no-saturation checks, and support/contact/response-target
  checks passed. A separate older Wardrobe-labelled key had no seven-day activity; its earlier-
  month Haiku cost was reviewed as historical non-production usage. No raw metric, provider
  identifier, exact billing amount, key name/value, log sample, screenshot, or provider body is
  retained. Repeat the review before any future archive/upload and after every backend/configuration
  change.
- Former v8, v7, and Gmail-free v6 images remain historical operational recovery evidence. None is
  the exact build-6-compatible candidate: using one reopens deployment/configuration/manual-review
  gates and blocks promotion or further build-6 lifecycle QA until v9 is restored and reverified.
  The emergency pre-build-4 image that re-exposes `/extract` remains a release halt, never a
  public-v1 rollback.
- The historical payload-free v8 post-change review passed at `2026-08-21T11:09:20Z`. The two-day HTTP view
  showed only `401`/`404` and no 5xx series; the bounded ten-minute view had no auth-rejection/rate-
  limit, Anthropic/stylist, maintenance, unhandled, malformed-lifecycle, or access-log event.
  Anthropic status, configured-limit, below-80%-of-limit, expected deployed Wardrobe key/Opus 4.8,
  and no-saturation checks passed, as did the published support pages, contact/response target, and
  retained routing rehearsal. The live logging configuration is deployed, but the bounded query had
  zero `registration_succeeded`, `assertion_succeeded`, and `installation_deleted` events because
  no corresponding lifecycle operation was exercised after v8 deployment at that review point.
  Later physical QA safely observed predecessor deletion and one clean-build registration plus one
  cold assertion success without payloads or identifiers. Protected `/recommend` success
  intentionally emits no developer event; it was proven separately through the aggregate
  `recommend-installation` admission counter and a visible non-cached client result.
- Pre-APP-036 development proof: App Attest enrollment, assertion renewal, and `/recommend`
  succeeded on an iPhone 16 Pro running iOS 26.6 with build 4. The iOS 27+ runtime category/build
  fields were absent as expected. Clean builds 5 and 6 repeated production enrollment, cold
  assertion renewal, and protected styling, with the same expected runtime-field absence. Build 5's
  later notification crash prevents it from being final-candidate evidence; build 6 passed that
  route and has since completed its final deletion/reinstall/new-enrollment handoff. Snapshot-list
  expiry and deletion-specific recovery/non-return proof remain open.
- Superseded Gmail-free repository proof: 202 locked backend tests and all dependency/security/type
  gates passed; 209 unique iOS tests passed (200 Swift tests plus all 9 UI flows); 31/31 release-
  script tests passed; and a clean Release simulator artifact for `1.0.0 (4)` passed public-config,
  plist, dependency, and removed-capability verification. No Google/Gmail/OAuth, `/extract`, or
  receipt-background capability was found in shipped source/configuration, generated project,
  executable, or app bundle. Clean source `dd3d99061321cf91bdce166e7da579b84edb07e8` then produced
  the signed `1.0.0 (4)` App Store archive. Its strict verifier passed the production App Attest
  entitlement, matching distribution profile, public configuration, app privacy manifest, and
  removed-capability checks. Preserve these facts as history only: the shipped Swift/backend and
  merged contract/verifier changes invalidate the old regression and archive as current
  candidate evidence.
- Historical uploaded build-4 proof: clean synchronized source context
  `24c17cb9fe643035f9206ee61e2935e086902146` passed 219 backend tests, 215 Swift tests, all 9 UI
  flows, 43 release-script tests, the locked dependency/security/type gates, and clean Release
  simulator/public-config/privacy/removed-capability verification. Xcode 26.6 with the iOS 26.5
  SDK created the arm64 Apple Distribution archive for `1.0.0 (4)` at
  `2026-08-21T06:36:33Z`. Its strict verifier passed the matching App Store profile/certificate,
  scalar production App Attest, HTTPS public configuration, app privacy manifest, and Gmail-free
  artifact guards. A separate targeted scan found no Anthropic/API-key, shared-bearer, or private-
  key credential marker; separate `dwarfdump --uuid` output matched the arm64 app and dSYM at
  `5BA1F06E-7458-32A4-890F-36C8F22D9C13`. The retained uploaded archive is
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`.
- Final distribution proof: the required payload-free exact-v7 review and final unused-build refresh
  passed at `2026-08-21T08:12:46Z`. The strict verifier passed again before Xcode validation.
  Organizer recorded the archive prepared/validated at 08:16Z and uploaded through the normal App
  Store Connect route at 08:18Z. Apple processing completed by `2026-08-21T08:20:20Z`. Processed
  metadata shows `1.0.0 (4)`, bundle `com.tth.Wardrobe`, arm64, iPhone, minimum iOS 18.0, included
  symbols, no non-exempt encryption, `get-task-allow = false`, and production App Attest. The build
  is assigned to the `Family` Internal Testing group with the saved truthful What to Test wording
  reproduced below. Direct
  Organizer upload produced no standalone exported IPA; retained binary evidence is the exact
  archive above, executable SHA-256
  `81ab249bbab122f549809bc094bdf8bbc450e84db34888b19a3272fe02cd22c6`, and matching app/dSYM UUID.
- Build-5 Apple distribution proof: the exact-v8 pre-validation review ran from
  `2026-08-22T02:27:21Z` through `2026-08-22T02:37:08Z` and passed. The final App Store Connect
  refresh at `2026-08-22T03:16:16Z` still showed builds 1–4 only and build 5 absent. Xcode validated
  the exact build-5 archive at `2026-08-22T03:18:30Z` and uploaded it through the normal App Store
  Connect route at `2026-08-22T03:20:59Z`, with zero warnings, errors, or information messages at
  both stages. Symbols were included; **Manage version and build number** and **TestFlight Internal
  Testing Only** were off. Processing reached **Ready to Submit** by
  `2026-08-22T03:24:21Z`. The processed record shows `1.0.0 (5)`, bundle `com.tth.Wardrobe`, SDK
  `23F81a`, arm64 iPhone support, minimum iOS 18.0, included symbols, no non-exempt encryption,
  `get-task-allow = false`, beta reporting active, and production App Attest. It lists exactly the
  `Family` Internal Testing group with one tester and no individual testers; the saved truthful
  build-5 What to Test wording is reproduced below. The separate exact-v8 post-distribution review
  ran from `2026-08-22T03:19:20Z` through `2026-08-22T03:30:33Z` and passed. This closes Apple
  distribution only, not physical, lifecycle-marker, deletion, or snapshot-recovery proof.
- Build-5 physical/crash proof: build 5 appeared installed in place before the planned handoff, but
  retained the predecessor identity's proof of possession. After the successful post-enrollment
  automatic snapshot at `2026-08-22T07:33:23Z` was confirmed with 14-day retention, the inherited
  identity successfully deleted server security data and production aggregates returned to zero.
  Local data was deleted, the app was removed, and build 5 was then installed cleanly. Clean QA
  passed Gmail-free launch/onboarding, empty wardrobe, offline Demo/local flows, Camera and Photo
  Library saves, the catalog matrix, production enrollment/cold renewal, styling/Restyle, Today
  offline-cache preservation, and Wear/History. Tapping a delivered reminder at
  `2026-08-22 17:15:14 SGT` then caused an ordinary `EXC_CRASH`/`SIGABRT`, not jetsam or watchdog.
  The executable exactly matches the retained build-5 dSYM. Safe symbolication reaches the
  generated async Objective-C bridge for
  `DailyReminderNotificationRouter.userNotificationCenter(_:didReceive:)`, which resumed UIKit's
  completion path on a cooperative queue while state restoration was updating. Build 5 is
  non-promotable; do not repeat the reminder tap. Its identity-safe handoff later completed as
  recorded below.
- Build-5 handoff, clean build-6 physical proof, and final build-6 handoff: build 6 appeared
  installed in place before the
  planned handoff, but inherited proof of possession remained available. After the successful
  post-enrollment automatic snapshot at `2026-08-23T07:34:23Z` was confirmed with 14-day retention,
  server security data was deleted, the aggregate returned to `0/0/0`, local data and the app were
  deleted, and build 6 was installed cleanly. On 2026-08-24, clean build 6 passed Gmail-free first
  launch, offline Demo, Camera/Photo Library saves, catalog operations, production registration and
  cold assertion renewal, online styling, explicit cached-look restoration after offline relaunch,
  failed-Restyle preservation, offline Wear/History, and delivered-reminder tap without a crash or
  state loss. Its reminder and styling permission were then turned off. The successful automatic
  snapshot at `2026-08-25T07:35:53Z`, status `created`, retention 14 days, cleared the final handoff
  gate. The owner completed ordered server deletion, aggregate-zero confirmation, local deletion,
  uninstall, and clean reinstall. Launch, local additions, and consent did not create server state;
  the explicit Style action at `2026-08-28 17:17 SGT` created the new anonymous installation and
  session with the expected completed-challenge and registration-success evidence recorded above.
- APP-009's lifecycle/logging policy is approved in
  [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md), and Fly v9 deploys
  its repository-owned enforcement. On 2026-08-19 the owner accepted Fly's fixed seven-day
  customer-visible logs, undisclosed provider-internal in-service retention, and 14-day
  snapshot-listing boundary with undisclosed all-copy purge timing. An isolated, secret-free,
  read-only restore of the 2026-08-19 snapshot passed aggregate-only schema/integrity checks and
  its temporary resources were removed within 391 seconds of volume creation. Build 4 subsequently
  supplied partial production TestFlight enrollment, assertion-renewal, and protected-call evidence,
  then its inherited identity was safely deleted before a clean build-5 install. Build 5 repeated
  enrollment, assertion renewal, protected styling, server markers, media flows, and the Today
  regression before its reminder-tap crash. Build 5's handoff and clean build-6 replacement proof
  through the fixed reminder tap later passed, and build 6 subsequently completed its final ordered
  deletion/reinstall/new-enrollment handoff. Snapshot-list expiry and deletion-specific recovery/
  non-return evidence are still required.
  Apple upload/processing and internal assignment alone do not satisfy those lifecycle
  checks. The first payload-free
  manual operations review passed at `2026-08-20T00:15:07Z`; the required post-v6 review passed at
  `2026-08-21T01:11:43Z`; and the historical pre-archive repeat passed at
  `2026-08-21T03:30:33Z`. The reviewed v7 post-deploy review passed at
  `2026-08-21T06:00:21Z`; the required final pre-upload repeat passed against that exact deployment
  at `2026-08-21T08:12:46Z`. The v8 post-change review passed at
  `2026-08-21T11:09:20Z`; the build-5 pre-validation and post-distribution reviews passed at
  `2026-08-22T02:37:08Z` and `2026-08-22T03:30:33Z`. The next routine review remains due no later
  than 2026-09-21.
- Fly Security summarized optional DPA termination periods of 30/90 days, but the account's
  Compliance page says the DPA is inactive until the customer signs it. Exact agreement review and
  any execution remain an APP-016 processor-contract gate, not proof of active log/snapshot purge.

## One-time gates before the next internal build

- [x] Push the readiness branch, review it, and merge the intended release scope so the uploaded
  commit is recoverable from the remote repository. PR #7 merged it to `main` at
  `f2a02825fd4178478bfc130525463165f12d648c`.
- [x] Implement the repository portion of `APP-009`: enroll one anonymous App Attest key per installation, validate fresh
  challenges/attestations/assertions at the backend, issue short-lived sessions, persist only
  durable auth/security metadata, enforce build/category allowlists when iOS 27+ supplies those
  signed fields, enforce rate limits, remove `BackendDeviceToken`, and retire/rotate the legacy
  backend token in the client contract. iOS 18–26 still requires core App Attest. Local wardrobe
  and Demo Mode remain available when secure verification is unsupported; remote AI fails closed.
- [x] Enable App Attest for `com.tth.Wardrobe`, confirm App ID prefix `29NT767Y9P`, exercise
  regenerated development signing, and retain physical-device sandbox enrollment and assertion
  renewal evidence.
- [x] Provision one encrypted Fly volume for the single production Machine; verify private
  ownership/modes, SQLite integrity, restart persistence, automatic daily snapshots, a retained
  snapshot, and an isolated restore rehearsal. These snapshots are not a separate backup system.
- [x] Adopt the APP-009
  [data-lifecycle and logging policy](app-attest-data-lifecycle-policy.md), including exact target
  periods, prohibited log fields, deletion/restore rules, manual operations requirements, and an
  explicit current-compliance checklist.
- [x] Enforce the repository-owned policy: a one-minute deadline-maintenance loop on a pinned
  minimum-one-Machine topology, repeat-until-drained cleanup, 90-day inactive and 30-day revoked
  installation purge, assertion-verified in-app deletion, SQLite secure-delete/WAL maintenance,
  structural persistence/logging guards, and a pinned no-access-log production command are all
  implemented and covered by focused tests.
- [x] After policy enforcement, build and scan the exact reviewed `linux/amd64` container image,
  including OS packages, for high/critical known vulnerabilities; push and re-scan its immutable
  registry digest, then deploy only that digest. At this historical build-4 gate, Fly v7 served
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
  from source `d4637f4b2adf14cd533594aec6060c385f8a5e2b`; both scans covered 90
  packages and found no critical/high vulnerability. Gmail-free v6 digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  remains the recovery baseline and passed a fresh registry scan. The emergency v5 rollback digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  was restored to the registry, re-scanned, and passed an isolated old/new/old schema-v4
  round-trip. The locked Python audit is already enforced in CI; the local Docker Scout command is
  `docker scout cves --only-severity critical,high --exit-code local://wardrobe-backend-local-verify`
  and requires an authenticated Docker Desktop/Docker ID session.
- [x] Rotate and verify the Anthropic API key, retire `DEVICE_TOKEN`, deploy App-Attest-only auth,
  and prove the retired credential returns `401`. No credential value is retained in evidence.
- [x] Treat the opaque Apple receipt as untrusted fraud evidence, not session authorization. The
  current release neither redeems nor trusts it; before any future use, implement and evidence
  Apple's receipt signature/chain, App ID, freshness, and attested-public-key checks.
- [x] Complete the repository and simulator-artifact portion of `APP-036`: Google Sign-In, Google
  client/callback configuration, Gmail/receipt-import UI and network paths, active `/extract`
  route/client capability, and receipt background scheduling are absent; build 4 used the approved
  fresh local-only schema; Demo Mode and in-app disclosures are Gmail-free; and Release/artifact
  checks fail if a removed capability returns. Intentional negative guards and legacy-rate cleanup
  remain. The historical Google OAuth sequence is deferred and is not a public-v1 gate.
- [x] Create gitignored `ios/Distribution.xcconfig` from
  `ios/Distribution.xcconfig.example` with the HTTPS backend host, public privacy/support URLs, and
  Apple Developer Team ID. It contains no Google client identifiers or callback scheme; resolved
  Release settings and the simulator artifact passed the public configuration guard. The later
  per-build archive/profile proof also passed for historical `1.0.0 (4)` source `dd3d990`; that
  archive is now superseded and cannot satisfy any current gate. The later uploaded build-4 and
  build-5 archive/profile proofs are historical. The exact build-6 archive/profile proof is retained
  in the current evidence section below.
- [x] Freeze and publish the Gmail-free source. PR #14 merged as
  `9a48caebdec67ac26673c3ba51546a5e7edcf0cc`; its remote branch was deleted, and local `main` was
  fast-forwarded to the same `origin/main` SHA before the release image was built.
- [x] Complete the pre-upload `APP-036` cutover. The installed intermediate development build
  `0.1.0 (4)` completed Google disconnection and local deletion, but it predated the
  server-deletion UI. Production had zero installations, zero sessions, and zero pending challenges
  before it was uninstalled, so no live production identity existed to delete. Exact-source
  `linux/amd64` digest
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0` passed local and registry
  critical/high scans across 90 packages and was healthy as Fly release v7 from source
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`. The registry-resolved
  v5 emergency rollback digest `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  resolved after fresh private-registry authentication at `2026-08-21T01:20:25Z`, re-scanned clean,
  and passed an isolated old/new/old schema-v4 rehearsal. Production `/extract`
  returned `404`, `/recommend` failed closed without authorization, and the payload-free
  reviewed v7 post-deploy manual review passed at `2026-08-21T06:00:21Z`. Build 4 was later
  installed only after TestFlight processing and never over the older app.
- [x] Republish accurate Gmail-free privacy-policy, support, and Terms pages on the final owned
  HTTPS domain and verify all three while signed out. `tzehon.github.io` PR #5 merged as
  `c5da090a0417bcda99fc6d328a0cdff808ea597d` at `2026-08-21T01:42:01Z`; the matching Pages run
  completed successfully at `2026-08-21T01:42:39Z`. Anonymous HTTPS requests at
  `2026-08-21T01:45:27Z` returned `200` for `https://blog.tth.dev/wardrobe/`,
  `https://blog.tth.dev/wardrobe/privacy/`, and `https://blog.tth.dev/wardrobe/terms/`. The rendered
  pages showed the 21 August 2026 effective date where applicable, linked to each other, and
  contained no Gmail/Google/OAuth/import capability claim. This closes the publication sub-gate;
  provider terms, App Privacy, and final store answers remain separate APP-016 work.
- [x] Explicitly defer the remaining App Store Connect record/media work in `APP-016` through
  `APP-018` for the internal TestFlight build only. Those items remain open and must be completed
  before App Store submission; this sequencing decision permits no binary, signing,
  configuration, privacy, or review-evidence shortcut.

The following ordered gates record the completed build-4 replacement/upload path. They replaced the
superseded `dd3d990` archive but are historical now that physical QA requires build 5:

- [x] **Merge and freeze the review fixes.** PR #19 rebase-merged the reviewed Swift, backend,
  shared-contract, release-verifier, and focused-test changes. The remote branch was deleted and
  clean synchronized `main` was `d4637f4b2adf14cd533594aec6060c385f8a5e2b` at that historical
  gate.
- [x] **Build, scan, and deploy the exact reviewed backend.** The exact frozen `linux/amd64` image
  passed local and immutable-registry critical/high scans across 90 packages and was deployed only
  as digest `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`.
  Production health, auth-store/configuration, encrypted storage, snapshot policy, and Gmail-free
  route behavior passed, followed by the payload-free review at `2026-08-21T06:00:21Z`.
- [x] **Run a clean Release regression and create the replacement signed archive.** App Store
  Connect showed builds 1–3 only at `2026-08-21T06:34:50Z`. Clean source context `24c17cb` passed
  219 backend tests, 215 Swift tests, all 9 UI flows, 43 release-script tests, and every Release,
  request-capture, dependency, privacy-manifest, and removed-capability gate. Xcode 26.6/iOS SDK
  26.5 created `Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive` at
  `2026-08-21T06:36:33Z`; strict certificate/profile, production App Attest, public-config,
  privacy-manifest, and Gmail-free artifact verification passed. Separate targeted credential-
  pattern and app/dSYM UUID checks also passed.
- [x] **Repeat the pre-upload review, then validate and upload.** The exact-v7 payload-free review
  and immediately refreshed App Store Connect list passed at `2026-08-21T08:12:46Z`, with builds
  1-3 still the only uploads. Xcode validated only the replacement `24c17cb` archive at 08:16Z and
  uploaded it through the normal **TestFlight & App Store**-eligible route at 08:18Z. Processing
  completed by `2026-08-21T08:20:20Z`; processed metadata, symbols, the `Family` internal group,
  and the saved truthful What to Test wording reproduced below were verified. Neither `dd3d990`
  archive was used.

The historical build-5 path and build-6 replacement path are ordered. Build-5 Apple distribution,
build-4 identity-safe recovery, partial clean build-5 physical QA, the build-6 availability check,
review/merge, Fly v9, strict archive, Apple internal distribution, clean build-6 physical QA, and
the final build-6 deletion/reinstall/new-enrollment handoff are complete. Snapshot-list expiry and
deletion-specific recovery/non-return remain open. The visual-control assessment is complete and
failed; unnumbered replacement implementation, distribution, and clean physical visual retest are
now open:

- [x] **Freeze the fixes.** Reviewed PR #23 merged the Today offline-cache fix, its focused
  tests, the production registration/assertion success-marker logging fix, and the TestFlight build
  `4,5` backend allowlist at `2026-08-21T10:29:56Z`. The frozen shipped-code/backend source was
  `4a75b99dcd49e818ad1d5b198e8c49abba702e18`; later docs-only evidence does not change the
  deployed image or iOS bundle. Keep `MARKETING_VERSION = 1.0.0`; both the archive-time and final
  pre-validation unused-build checks passed.
- [x] **Retain historical build-5 pre-archive regression evidence.** The frozen build-5 worktree passed 221
  backend tests plus locked dependency audit/Bandit/Ruff/mypy; the regenerated project passed 218
  Swift unit tests and all 9 UI flows; and 43 release-script tests plus Release simulator/artifact
  checks passed. Rerun any affected gate if source or configuration changes before archive.
- [x] **Build, scan, deploy, configure, and review the backend candidate.** Fly v8 serves exact PR
  #23 source and immutable digest
  `sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
  Local/registry scans, runtime/storage/route/configuration checks, the `4,5` allowlist, targeted
  INFO logger, retained rollback/recovery checks, and the `2026-08-21T11:09:20Z` payload-free
  post-change review passed. This closed deployment/configuration review only at that stage; later
  physical QA observed the bounded lifecycle markers recorded below.
- [x] **Recheck App Store Connect, archive, and verify build 5.** Fresh registry recovery checks,
  the exact-v8 payload-free review, and the archive-time build-list refresh passed at
  `2026-08-22T01:00:09Z`, `2026-08-22T01:07:45Z`, and `2026-08-22T01:09:39Z` respectively.
  Build 4 remained highest and build 5 unused. The exact new production-signed archive passed the
  strict verifier, profile/entitlement/identity checks, separate non-emitting credential and
  removed-capability scans, and matching app/dSYM evidence recorded below.
- [x] **Retain exact synthetic `/recommend` request-capture evidence.** A tests-only assertion pins
  every stored property on the three Swift request types, including nil optionals, and separately
  pins the exact encoded top-level, catalog-item, and preference key sets. The shared schema/backend
  reject extras. The strengthened focused `RecommendClientTests` suite passed 12/12 at
  `2026-08-22T01:59:08Z` on an iPhone 17/iOS 26.5 simulator. After adding that guard, the mandatory
  backend gate passed 221 tests plus audit/Bandit/Ruff/mypy, and one uninterrupted full iOS run
  passed 218 Swift unit tests and all 9 UI tests (227/227 canonical cases); its result bundle
  finalized at `2026-08-22T02:04:17Z`, with no failures, skips, or retries. No production payload,
  token, or identifier was inspected or retained; the test-only change does not alter the signed
  archive or require a new build number.
- [x] **Validate, upload, process, and assign build 5.** The exact-v8 pre-validation review passed at
  `2026-08-22T02:37:08Z`, and the final `2026-08-22T03:16:16Z` App Store Connect refresh still showed
  builds 1–4 only with build 5 absent. Xcode validation succeeded at `03:18:30Z` and the normal App
  Store Connect upload succeeded at `03:20:59Z`, both with zero warnings, errors, or information
  messages. Symbols were included; **Manage version and build number** and **TestFlight Internal
  Testing Only** were off. Processing reached **Ready to Submit** by `03:24:21Z` with the expected
  version/build, bundle, SDK, architecture, minimum OS, symbols, encryption, production App Attest,
  `get-task-allow`, and beta-reporting metadata. The build lists only the `Family` Internal Testing
  group with one tester and no individual testers, and the truthful build-5 What to Test wording
  reproduced below is saved. The post-distribution exact-v8 review passed at `03:30:33Z`. Build 5
  is consumed and must never be reused.
- [x] **Complete build 4's identity-safe recovery/handoff.** Build 5 appeared installed in place,
  but the predecessor's live proof of possession remained available. A successful post-enrollment
  automatic snapshot created at `2026-08-22T07:33:23Z` was confirmed with 14-day retention;
  **Delete Server Security Data** succeeded; production installation/session/challenge aggregates
  returned to zero; and local deletion plus app removal preceded the clean build-5 install. This is
  safe recovery evidence, not upgrade/migration product proof.
- [x] **Run clean build-5 physical QA through the first blocker.** The launch/local/media/catalog,
  production auth/styling, Today offline-cache/failed-Restyle, and Wear/History boundaries passed,
  including one registration and one later assertion marker without payloads or identifiers. A
  delivered reminder tap at `2026-08-22 17:15:14 SGT` then caused `EXC_CRASH`/`SIGABRT`; build 5
  is non-promotable and must not receive another notification-tap attempt.
- [x] **Diagnose and implement the source fix on a branch.** The crash exactly matches the build-5
  dSYM and safely symbolicates to the generated async bridge for
  `DailyReminderNotificationRouter.userNotificationCenter(_:didReceive:)`. Branch
  `codex/fix-notification-tap-crash` replaces both imported async notification-delegate bridges
  with explicit completion-handler/main-queue routing. Focused tests passed 17/17 and the full
  branch regression passed 221 backend tests plus audit/Bandit/Ruff/mypy, 222 Swift unit tests,
  all 9 UI flows, and 43 release-script tests. This branch evidence was later superseded by the
  merged-source, Fly v9, archive, and Apple distribution evidence below.
- [x] **Confirm the replacement build number in live App Store Connect.** The read-only signed-in
  TestFlight **Build Uploads** view at `2026-08-22T10:02:31Z` showed builds 1–5 only, build 5
  **Complete**, and no build 6. Build 6 is confirmed unused and selected; the branch records
  `CURRENT_PROJECT_VERSION = 6`, source allowlist `4,5,6`, and `MARKETING_VERSION = 1.0.0`.
- [x] **Complete the replacement candidate pipeline.** PR #27 merged to clean synchronized `main`
  `de7c540275fb16e61aabf1884538b18cf6edf76f`. Merged-source regressions/release guards, exact Fly
  v9 compatibility and health, and strict verification of
  `Wardrobe-1.0.0-6-de7c540-appstore.xcarchive` passed. Xcode validation and normal-route upload
  succeeded; Apple processing reached **Ready to Submit**; only `Family` is assigned, with one group
  tester, no individual testers, and saved truthful What to Test notes.
- [x] **Record the missed v9 operational review honestly and restore current evidence.** The
  required post-deploy/pre-upload review was missed and is not backdated. The complete payload-free
  review passed late at `2026-08-23T02:13:12Z`; repeat before any future archive/upload and after
  every backend/configuration change.
- [x] **Identity-safely replace build 5 and repeat clean build-6 QA through the fixed route.** The
  eligible snapshot, ordered server/local deletion, aggregate-zero check, removal, clean build-6
  install, production auth, local/offline matrix, and delivered-reminder tap passed. The unexpected
  in-place build-6 installation was not counted as QA or migration evidence.
- [x] **Complete the final build-6 deletion/reinstall boundary.** A successful automatic snapshot
  created at `2026-08-25T07:35:53Z` reported `created` with 14-day retention. Before deletion, the
  installation/session/challenge aggregate was `1/0/0`. Assertion-verified server deletion
  emitted exactly one bounded success marker and returned the aggregate to `0/0/0`; it remained
  `0/0/0` after local deletion and uninstall. After a clean reinstall, launch, two local additions,
  and styling-consent grant also left it at `0/0/0`. Explicit Style at
  `2026-08-28 17:17 SGT` then created one active installation and one active session, with zero
  pending and zero failed challenges, one completed challenge, exactly one registration-success
  marker, and expected runtime-field absence on iOS 26.6. This closes the owner-controlled handoff,
  not snapshot-list expiry, deletion-specific recovery/non-return, the unnumbered replacement
  implementation/distribution/clean physical visual retest, or final Google retirement.

## Mandatory clean-uninstall transition for build 4

Build `1.0.0 (4)` is fresh-install-only and must never be installed over an earlier app. The owner
explicitly accepted losing the earlier local wardrobe and adding items again.

The pre-upload portion completed on 2026-08-21. The installed intermediate development build was
`0.1.0 (4)`, not an uploaded TestFlight candidate. It completed **Disconnect Google** and
**Delete Local Data**, but predated **Delete Server Security Data**. A read-only aggregate query
reported zero production installations, sessions, and pending challenges, so there was no live
production identity to delete. The app was then uninstalled. This exception is evidence about that
one retired build, not permission to skip verified server deletion when a future installed build
has a live identity or exposes the control.

Build `1.0.0 (4)` was installed only after it processed in TestFlight and only after the older app
was removed. That clean install enrolled a new anonymous production App Attest identity. This is
historical build-4 evidence, not upgrade or migration support.

The planned handoff was recovered after build 5 appeared installed in place: the predecessor's
proof of possession remained live, an eligible successful post-enrollment snapshot was confirmed,
server security data was deleted with zero aggregate confirmation, and local deletion plus app
removal followed. Build 5 was then installed cleanly. This completes the predecessor handoff but
does not validate the in-place installation as a supported upgrade. Build 5 later completed the
same identity-safe sequence before build 6 was installed cleanly. The original clean build-6
identity later completed the same ordered deletion after an eligible snapshot, followed by local
deletion, uninstall, clean reinstall, and a new anonymous enrollment only when the owner explicitly
styled a look. These are fresh-install and deletion proofs, not upgrade or migration support.

## Per-build release-candidate loop

1. **Freeze the candidate.** Use a clean, reviewed commit. Record its hash, the backend image that
   will serve it, App Attest environment/category/build allowlist, iOS-version compatibility policy,
   durable auth-store version, and the policy-compliance evidence linked from
   [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md). Re-resolve the v6
   Gmail-free recovery digest after fresh private-registry authentication immediately before
   archive/upload.
2. **Confirm version/build from App Store Connect.** The archive-time inspection at
   `2026-08-21T06:34:50Z` and final pre-validation refresh at `2026-08-21T08:12:46Z` showed builds
   1-3 only, so the replacement archive correctly preserved `1.0.0 (4)`. Its completed upload now
   consumes build 4. For build 5, the archive-time refresh at `2026-08-22T01:09:39Z` showed builds
   1–4 only and build 5 unused. The final pre-validation refresh at `2026-08-22T03:16:16Z` again
   showed builds 1–4 only and build 5 absent. Its completed upload now consumes build 5; never reuse
   a build number. The read-only live TestFlight **Build Uploads** inspection at
   `2026-08-22T10:02:31Z` showed builds 1–5 only, build 5 **Complete**, and no build 6; build 6 is
   confirmed unused and selected with `MARKETING_VERSION = 1.0.0`. The later completed normal-route
   upload consumes build 6; never reuse it.
3. **Regenerate and verify.** Run the locked backend pytest/pip-audit/Bandit/Ruff/mypy suite, full Swift and UI suite,
   public Release configuration tests, request-capture/privacy guards, Release build, and simulator
   artifact preflight. Xcode strips App Attest from simulator signatures, so the signed entitlement
   is checked after archiving. Any config, auth allowlist, or build-number change happens before
   this final run.
4. **Create a signed device archive.** In Xcode select the `Wardrobe` scheme and a generic physical
   iOS device, then choose **Product → Archive**. The archive must pass the strict public Release
   post-build check without bypasses. Before validation or upload, run
   `ios/scripts/verify-release-artifact.sh DerivedData/ReleaseValidation
   "/path/to/Wardrobe.xcarchive/Products/Applications/Wardrobe.app"`; this pass must confirm the
   signed production App Attest entitlement; absence of the shared bearer, Google/GoogleSignIn/
   AppAuth/GTM bundles, Google client identifiers/callback scheme, Gmail permission/host/client
   paths, `/extract` client path, and receipt background-task identifier; and correct public URLs.
   Retain the archive entitlement and embedded-profile inspection as APP-009/APP-036 evidence.

   Current build-6 archive and distribution evidence: clean synchronized source context
   `de7c540275fb16e61aabf1884538b18cf6edf76f` produced
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-6-de7c540-appstore.xcarchive` at
   `2026-08-22T11:42:24Z`. The strict verifier, deep signature check, matching app/dSYM check,
   production App Attest entitlement/profile, privacy manifest, public configuration, credential
   absence, and Gmail-free removed-capability guards passed. Xcode validated the exact archive and
   uploaded it through **TestFlight & App Store** at `2026-08-23 08:57 SGT`, with symbols enabled,
   automatic version/build management disabled, and **TestFlight Internal Testing Only** disabled.
   Apple processing reached **Ready to Submit**. The processed record shows `1.0.0 (6)`, arm64
   iPhone support, minimum iOS 18.0, included symbols, and no non-exempt encryption. Exactly the
   `Family` Internal Testing group is assigned with one group tester and no individual testers; the
   build-6 What to Test wording reproduced below is saved. Distribution remains distinct from the
   later clean physical proof. The final build-6 deletion/reinstall/new-enrollment handoff is now
   complete; snapshot-list expiry and deletion-specific recovery/non-return remain open.

   Historical build-5 archive evidence: fresh private-registry authentication re-resolved exact
   Gmail-free v6 recovery digest
   `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`, whose
   zero-critical/high scan completed at `2026-08-22T01:00:09Z`. The exact-v8 payload-free review
   passed at `2026-08-22T01:07:45Z`; the final App Store Connect refresh at
   `2026-08-22T01:09:39Z` showed builds 1–4 only. Clean source context
   `695c562b7b18e4a0b7f8a72b814af59efdd0cf3a`, a documentation-only successor to frozen
   shipped-code/backend source `4a75b99dcd49e818ad1d5b198e8c49abba702e18`, produced
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-5-695c562-appstore.xcarchive` at
   `2026-08-22T01:10:32Z`. Xcode 26.6 (`17F113`) and the iOS 26.5 SDK produced exact
   `1.0.0 (5)`, `com.tth.Wardrobe`, `iphoneos`, arm64, minimum iOS 18.0 metadata. Apple
   Distribution profile `Wardrobe App Store App Attest 2026-08-21`
   (`2b11bc90-0194-4fe6-8dcc-413c6dc5ccd2`, expires `2027-08-21T02:07:47Z`) has no device or
   all-device grant, has `get-task-allow = false` and beta reporting active, and matches the App ID
   prefix, team, bundle, and signing certificate. The profile grants production App Attest and the
   signed app carries scalar `production`. The strict verifier completed at
   `2026-08-22T01:11:17Z` with public HTTPS configuration, app privacy manifest, shared-bearer, and
   Gmail-free artifact guards passing. A separate non-emitting scan found no Anthropic/API-key,
   shared-bearer, private-key, Google/Gmail/OAuth, `/extract`, or receipt-import/background marker
   at `2026-08-22T01:12:01Z`; post-scan deep signature verification passed at
   `2026-08-22T01:12:19Z`. The arm64 app/dSYM UUID is
   `DA20FD8D-64C3-3B7A-9990-19EAF050AF04`; executable SHA-256 is
   `a9f01231025874d331e76be40ebe6f493b3f36051902b66b0ad03c35206bb3b9`. At that stage this was
   signed-archive evidence only; the later Organizer validation, upload, processing, and assignment
   evidence is retained above. Physical proof remains open.

   Historical evidence: for build `1.0.0 (4)`, clean source
   `dd3d99061321cf91bdce166e7da579b84edb07e8`
   produced the Apple Distribution archive at `2026-08-21T03:34:13Z` using Xcode 26.6 and the iOS
   26.5 SDK. The signed app carried scalar production App Attest, and the embedded App Store profile
   matched its team, App ID, certificate, and production grant. The strict artifact verifier passed
   public configuration, app privacy manifest, and Gmail-free artifact checks. Subsequent
   shipped Swift/backend changes supersede
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-dd3d990-appstore.xcarchive`; retain it only
   as history and never validate or upload it. A separate earlier automatic-signing archive,
   `Wardrobe-1.0.0-4-dd3d990.xcarchive`, used a development profile and failed verification; it
   also must never be validated or uploaded. Historical uploaded build-4 replacement evidence:
   clean synchronized
   source context `24c17cb9fe643035f9206ee61e2935e086902146` (a documentation-only successor to
   shipped-code merge `d4637f4b2adf14cd533594aec6060c385f8a5e2b`) produced
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive` at
   `2026-08-21T06:36:33Z`. It is arm64, minimum iOS 18.0, Xcode 26.6/iOS SDK 26.5, and signed by
   `Apple Distribution: Tan Tze Hon (29NT767Y9P)` with profile
   `Wardrobe App Store App Attest 2026-08-21` (`2b11bc90-0194-4fe6-8dcc-413c6dc5ccd2`). The signed
   app carries scalar production App Attest; the profile is App Store distribution, grants
   production, and contains the matching certificate. The strict verifier passed HTTPS public
   configuration, app privacy manifest, and Gmail-free artifact guards. A separate targeted scan
   found no Anthropic/API-key, shared-bearer, or private-key credential marker. Separate
   `dwarfdump --uuid` output matched the arm64 app and dSYM at
   `5BA1F06E-7458-32A4-890F-36C8F22D9C13`.
5. **Validate and upload.** In Organizer choose **Validate App**, then **Distribute App →
   TestFlight & App Store → Upload**. Upload symbols and use the intended distribution signing.
6. **Wait for processing.** In App Store Connect review Build Upload status, warnings, privacy
   manifests, entitlements, supported devices, version/build, and export-compliance state. Resolve
   every error before testing.
7. **Distribute internally.** Add the processed build only to the chosen Internal Testing group,
   enter truthful **What to Test** notes, and keep automatic distribution off when a deliberate QA
   gate is desired.
8. **Run fresh-install QA.** Never install a fresh-reset candidate over an older app. Build 4 and
   build 5 each completed an identity-safe handoff before the next clean install. Build 6 has passed
   the replacement matrix through the fixed delivered-reminder tap and its final owner-controlled
   server/local deletion, uninstall, clean reinstall, and new anonymous enrollment. The complete
   matrix is: launch/icon, local
   onboarding, offline Demo Mode, manual add, camera/photo library,
   catalog edit/delete, App Attest enrollment/session renewal, styling consent/withdrawal,
   Today/History, local reminders, Settings/privacy, local deletion, separate server-security
   deletion, offline/relaunch, backend failure, and reinstall creating a new anonymous
   installation. Confirm no Google/Gmail/receipt-import UI or request exists. Verify
   local/demo behavior remains available when secure remote AI is unavailable. Through the
   processed internal TestFlight build, retain production enrollment, assertion renewal, and a
   protected API call. On iOS 18–26, record signed runtime-field absence without claiming
   category/build enforcement.
9. **Retire the bridge.** If a legacy compatibility bridge was used, switch the validated backend
   to App-Attest-only mode, unset/rotate `DEVICE_TOKEN`, and prove an old build is rejected while
   the candidate still succeeds. After build 4 is distributed, recovery must use the retained v6
   Gmail-free digest or a later validated Gmail-free App-Attest-only image while preserving the auth
   store. The former v5 image is a pre-build-4 abort only: it re-exposes `/extract` and must halt the
   release. Rolling back to the shared bearer is never acceptable.
10. **Record evidence.** Retain the commit, archive, build/version, Xcode and SDK, test results,
   validation/upload logs, processed-build metadata, backend image/config, exact App ID prefix,
   entitlement/profile, tester OS/runtime-field presence, category/build values when supplied,
   auth-store volume and snapshot/restore evidence, Apple-receipt validation/risk-metric policy,
   APP-036 artifact-absence output, pre-uninstall Google disconnection and local deletion, the exact
   zero-installation/zero-session/zero-pending-challenge production check, clean-install proof,
   bridge retirement, old-build rejection,
   and physical-device QA. Do not claim build/category
   rejection on iOS 18–26, where Apple omits those fields; the pre-App-Attest shared-token build
   must still be rejected.

## Post-upload APP-009 closure

Production App Attest proof is necessarily post-upload; it is not a pre-build gate.

### Build 4 physical QA — 2026-08-21 (historical, PARTIAL)

This aggregate-only record describes processed TestFlight build `1.0.0 (4)`. It does not satisfy
the build-5 release gate and retains no device identifier, App Attest identifier, credential,
request body, database row, wardrobe payload, or raw log sample.

| Boundary | Redacted result |
|---|---|
| Installation | Clean TestFlight install on iPhone 16 Pro running iOS 26.6; production aggregate baseline was zero installations, then one installation after enrollment |
| App Attest / protected API | First production assertion and protected calls succeeded; a cold-app assertion/session renewal also succeeded |
| Offline behavior | Remote styling failed closed with a friendly offline message while Wardrobe, History, and Demo Mode remained usable |
| Today cache / release defect | The cached look survived an offline relaunch, but tapping **Restyle** while offline replaced the usable look with the error state. The look returned only after another relaunch and a tap. Build 4 is not promotable; clean build 5 later verified the fix |
| Online recovery | Styling recovered online and showed `Styled 17:24`; aggregate assertion total advanced from 1 to 2 and the current recommendation-installation rate window from 0 to 1 |
| Signed runtime fields | Validation category/build fields were absent, as expected on iOS 26.6; this is not category/build-enforcement evidence |
| Local flows | Manual add/edit, Demo Mode, **Wear this**, and History passed. Camera and Photo Library opened and cancelled only; successful media selection remains untested. Reminder permission and scheduling passed; delivery remains untested |
| Production marker stream | The build-4 bounded stream had no `registration_succeeded` or `assertion_succeeded` matches because live v7 suppressed INFO lifecycle events at the time. Fly v8 later emitted the bounded build-4 deletion and clean build-5 registration/assertion evidence without payloads or identifiers |
| Snapshot / deletion boundary | The initially listed snapshot predated enrollment. A later successful post-enrollment snapshot at `2026-08-22T07:33:23Z` cleared the recovery gate, after which server and local deletion completed safely |

### Build 5 physical QA — 2026-08-22 (historical, BLOCKED)

Clean build `1.0.0 (5)` passed Gmail-free launch/onboarding, empty wardrobe, offline Demo and local
tabs, successful Camera/Photo Library saves, the catalog matrix, production enrollment and cold
renewal, initial styling/Restyle, Today offline-cache and failed-Restyle preservation, and offline
Wear/History. Production markers and aggregates corroborated the connected operations without
retaining payloads or identifiers. Tapping a delivered reminder at `17:15:14 SGT` then caused
`EXC_CRASH`/`SIGABRT`. The executable exactly matches the retained build-5 dSYM; safe symbolication
reaches the generated async bridge for
`DailyReminderNotificationRouter.userNotificationCenter(_:didReceive:)` as UIKit updated state
restoration. Build 5 is consumed and non-promotable. Do not repeat the tap.

### Build 6 physical QA — 2026-08-24–28 (current, PARTIAL)

This aggregate-only record describes clean processed TestFlight build `1.0.0 (6)`. Build 6 first
appeared installed in place unexpectedly, so that installation was not counted as clean QA. After
an eligible post-build-5-enrollment snapshot was confirmed, the inherited server identity was
deleted with aggregate confirmation, local data and the app were deleted, and build 6 was installed
cleanly. This is not upgrade or migration evidence.

| Boundary | Redacted result |
|---|---|
| Launch / Gmail-free | **Your wardrobe, your way** led to an empty local wardrobe with no account, Google, Gmail, or receipt-import path |
| Offline local flows | Offline Demo, Camera and Photo Library saves, and the disposable catalog add/edit/search/filter/sort/delete matrix passed |
| Production App Attest | Style at `20:25 SGT` registered one anonymous installation; after session expiry, Style at `20:45 SGT` renewed with an assertion and a fresh challenge. Expected runtime build/category fields remained absent on iOS 26.6 |
| Today cache / failure | After an offline process relaunch, Today initially showed **Style a look**; one explicit tap restored the cached `20:25` look without a backend call. Failed offline Restyle showed **Couldn't refresh this look** while the cached look remained visible |
| Wear / History | Offline **Wear this** and History passed and persisted across the notification route |
| Reminder fix | The local reminder delivered at `20:53 SGT`; tapping it opened Today without crashing. The explicit **Style a look** action restored the cached `20:45` look, and Wardrobe/History state remained intact |
| Final deletion / uninstall | The `2026-08-25T07:35:53Z` automatic snapshot was `created` with 14-day retention and postdated enrollment. The pre-deletion aggregate was `1/0/0`; assertion-verified deletion emitted exactly one bounded success marker and returned it to `0/0/0`, which persisted after local deletion and uninstall |
| Clean reinstall / new identity | Clean reinstall, launch, two local wardrobe additions, and styling-consent grant left the backend at `0/0/0`. Explicit **Style a look** at `2026-08-28 17:17 SGT` created one active installation and one active session, zero pending and zero failed challenges, one completed challenge, and exactly one registration-success marker. Runtime category/build fields remained absent as expected on iOS 26.6 |
| Remaining lifecycle boundary | Eligible 14-day snapshot-list disappearance and deletion-specific recovery/non-return evidence remain open |

The intermediate idle state before explicit cache restoration matches the no-network-call-on-tab-
appearance design. The runbook wording and production process-relaunch automation should make the
required explicit tap clear. Separately, the 2026-08-28 owner-supplied Dark Mode screenshot confirms
that build 6's **Allow AI styling** title is approximately 21 points right of the button center and
that the sampled `#C2DFFC` fill against the white title is approximately `1.38:1`. Build 6 therefore
fails the visual presentation gate and is non-promotable; this does not invalidate its completed
identity or notification evidence.

- [x] Retain historical build-4 signed production App Attest entitlement, matching embedded App
  Store profile and certificate, and strict artifact-verifier result. The verified uploaded archive
  is `Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`; historical `dd3d990` archives are superseded and
  cannot satisfy any later upload or processed-build gate.
- [x] Retain build-4 identity-safe recovery: eligible snapshot, assertion-verified server deletion,
  zero installation/session/challenge aggregates, local deletion, app removal, and subsequent clean
  build-5 install. This is not upgrade/migration proof.
- [x] Retain the clean build-5 production enrollment, cold assertion, protected styling, bounded
  markers, media/catalog, Today regression, and reminder-crash evidence above.
- [x] Confirm the replacement build number through fresh live App Store Connect inspection. At
  `2026-08-22T10:02:31Z`, builds 1–5 were the only uploads, build 5 was **Complete**, and build 6
  was absent. Build 6 is confirmed unused and selected; `MARKETING_VERSION` stays `1.0.0`.
- [x] Finish review/merge and the entire replacement build/archive/upload/processing/assignment
  loop. PR #27, merged-source verification, Fly v9, the strict build-6 archive, Xcode validation/
  upload, Apple processing, `Family` assignment, and saved tester notes are retained above.
- [x] Complete build 5's identity-safe handoff: after the eligible
  `2026-08-23T07:34:23Z` snapshot, disable its reminder, withdraw styling permission, delete its live
  server security record with aggregate confirmation, delete local data, remove the app, and install
  build 6 cleanly. Build 6 appearing in place before this sequence was not counted as QA.
- [x] Repeat the fresh-install matrix in clean build 6 through delivered-reminder tap. Launch,
  offline/local media and catalog flows, production enrollment/assertion renewal, Today cache and
  failure preservation, Wear/History, reminder delivery, tap routing, and local-state preservation
  passed as recorded above.
- [x] Complete the final build-6 handoff in owner-controlled order. The eligible
  `2026-08-25T07:35:53Z` snapshot reported `created` with 14-day retention; the `1/0/0` baseline,
  exactly one deletion-success marker, post-delete/uninstall `0/0/0`, clean-reinstall local-only
  `0/0/0`, and explicit `2026-08-28 17:17 SGT` Style enrollment evidence are retained above. The
  new identity has one active installation and one active session, zero pending/failed challenges, one
  completed challenge, one registration-success marker, and expected iOS 26.6 runtime-field
  absence. No identifier, payload, credential, or raw log sample is retained.
- [ ] Finish the remaining observable operations evidence: eligible 14-day snapshot-list
  disappearance and deletion-specific recovery/non-return. The generic isolated restore-path
  rehearsal does not prove that a deleted production identity cannot return.
- [x] Confirm that build 6 fails the **Allow AI styling** presentation gate. The 2026-08-28 owner-
  supplied Dark Mode screenshot places the title approximately 21 points right of center and
  measures the sampled `#C2DFFC` fill against white at approximately `1.38:1`. Build 6 is consumed,
  non-promotable, and must never be reused.
- [ ] Complete and verify the replacement control implementation with a centered title and opaque,
  sufficiently contrasting enabled, pressed, and disabled states.
- [ ] Distribute only a newly numbered replacement candidate. First inspect the live signed-in App
  Store Connect Build Uploads list and prove the next build number unused; do not name or select the
  replacement number before that check. Then repeat the exact backend/configuration, full regression,
  signed archive, normal-route validation/upload, processing, `Family` assignment, and truthful
  tester-note gates.
- [ ] Clean-install the processed replacement and physically retest title centering, icon-slot
  absence, and enabled/pressed/disabled legibility in Dark Mode before promotion.
- [ ] After the processed replacement and its backend are proven, obtain a separate final
  owner confirmation and retire only the inventoried Wardrobe Google Cloud/OAuth projects. Do not
  touch unrelated Google Cloud or Search Console resources.

## Promoting an internally tested build

Build 4 is not promotable because of the Today offline-cache defect, and build 5 is not promotable
because of the delivered-reminder tap crash. Build 6 passed the affected identity and notification
routes but is non-promotable because it failed the styling-consent control presentation gate. The
replacement remains unnumbered until live App Store Connect proves the next build unused. When that
replacement candidate is fully approved for public release, do not rebuild unless something changed:

- Finish `APP-016` through `APP-018`, agreements, pricing/availability, Gmail-free privacy answers,
  screenshots, review contact, and review notes. Google restricted-scope verification/CASA is not
  a public-v1 gate.
- Select the already-tested build on the matching App Store version.
- Re-check the binary, live backend and auth store, App Attest compatibility policy plus iOS 27+
  build/category allowlist, public URLs, Gmail-free archive evidence, disclosures, and metadata
  against the retained evidence.
- Choose **Add for Review**, inspect the complete submission, then **Submit for Review**.

If code, resources, configuration, backend contract, disclosures, or version metadata changes,
increment the build number and repeat the full loop. Never "patch" an uploaded candidate in place.

## Saved truthful What to Test wording for build 4

> Verify the new Wardrobe Stylist icon, add an item with both Camera and Photo Library, and confirm
> each picker remains open until completion or cancellation. Review the simplified Settings hub
> and its Connected Features, Wardrobe & Demo, Privacy & Data, and Help & Support destinations.
> Install build 4 only as a clean processed-TestFlight install; the earlier development app was
> already disconnected, locally cleared, and uninstalled after production was verified to contain
> zero installations, zero sessions, and zero pending challenges. Exercise manual/photo cataloging,
> styling/history, reminders, styling-consent withdrawal, verified local deletion, and separate
> server-security deletion. On a clean physical install, confirm there is no Google/Gmail or login
> path, secure installation verification completes anonymously, and local/demo features remain
> usable during an offline backend failure.

Saved on processed build `1.0.0 (4)` for its intended Internal Testing group on 2026-08-21.

## Saved truthful What to Test wording for build 5

> Build 5 is a clean-install replacement for build 4. Do not install it until the owner confirms build 4’s identity-safe handoff is complete, and never install it over build 4.
>
> After approval, test launch/icon, onboarding, manual catalog/photo/camera flows, editing/deletion, Demo Mode, styling consent/withdrawal, Today/Wear/History, and reminder delivery. Today regression: style online, relaunch offline, tap Restyle; the cached look must stay visible with a friendly failure, then recover after reconnecting. Wardrobe, History, and Demo Mode must remain usable while remote styling is unavailable. Confirm there is no Google, Gmail, login, receipt-import, or /extract path.
>
> Do not perform local/server deletion or reinstall until the runbook clears those stages.

Saved on processed build `1.0.0 (5)` for the `Family` Internal Testing group by
`2026-08-22T03:24:21Z`. This preserves the truthful pre-install instruction shown at assignment.
The later recovered handoff and clean build-5 QA are recorded above; the reminder-tap crash now
makes build 5 non-promotable.

## Saved truthful What to Test wording for build 6

> Build 6 is a clean-install replacement for build 5 and fixes the crash when tapping a delivered reminder. Keep build 5 installed until the owner confirms its identity-safe handoff is complete; do not install or update build 6 over build 5.
>
> After approval and a clean install, test launch/icon, onboarding, manual catalog/photo/camera flows, editing/deletion, Demo Mode, styling consent/withdrawal, Today/Wear/History, and reminder delivery. Tap the delivered reminder: it must open Wardrobe Stylist on Today without crashing, and existing local state must remain intact. Today regression: style online, relaunch offline, tap Restyle; the cached look must remain visible with a friendly failure, then recover after reconnecting. Wardrobe, History, and Demo Mode must remain usable while remote styling is unavailable. Confirm there is no Google, Gmail, login, receipt-import, or /extract path.
>
> Do not perform local/server deletion, uninstall, or reinstall until the runbook clears those stages.

Saved and reload-verified on processed build `1.0.0 (6)` for the `Family` Internal Testing group on
2026-08-23. The build has one group tester and no individual tester assignments. This preserves the
pre-install identity-safe handoff instruction; the later clean physical evidence is recorded above
and does not rewrite the historically saved note.

## Official Apple references

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
- [View builds and upload status](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata)
- [Establishing your app's integrity with App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Validating App Attest at your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Preparing App Attest environments and rollout](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
