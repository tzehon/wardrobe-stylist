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

## Current release status — 2026-08-22

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
- Current replacement candidate: the archive-time App Store Connect refresh at
  `2026-08-22T01:09:39Z` and final pre-validation refresh at `2026-08-22T03:16:16Z` showed builds
  1–4 only and build 5 absent. `MARKETING_VERSION = 1.0.0` remains unchanged and
  `CURRENT_PROJECT_VERSION = 5`. The exact production-signed build-5 archive is strictly verified,
  Organizer-validated, uploaded, processed, and assigned only to the `Family` Internal Testing
  group. Build 5 is consumed and must never be reused. It has not been installed or physically
  tested; complete build 4's identity-safe handoff before allowing any build-5 install or automatic
  update.
- Build-5 local pre-archive evidence: 221 backend tests and the locked dependency-audit, Bandit,
  Ruff, and mypy gates passed. The regenerated project passed 218 Swift unit tests and all 9 UI
  flows; all 43 release-script tests and the Release simulator/artifact checks also passed. This
  local regression is distinct from the now-retained signed-archive and Apple distribution evidence
  and remains neither processing nor physical-device proof by itself.
- Current production backend baseline: Fly release v8 completed at `2026-08-21T10:45:06Z` and
  serves reviewed PR #23 source `4a75b99dcd49e818ad1d5b198e8c49abba702e18` as a
  `linux/amd64` image at immutable registry digest
  `sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
  Its fresh no-cache local image ID is
  `sha256:3eb95304cb6e97976d2aa8b18dce302a3a908cf1d565b13d511c3fc2ed9d7c84`;
  local and re-resolved registry scans each covered 90 packages and found zero critical/high
  vulnerabilities. UID 10001, no-new-privileges, mounted-volume, and targeted-logging container
  smoke checks passed. The running source label, digest, and architecture match; one healthy
  Singapore Machine runs with `min_machines_running = 1`; production App Attest uses category `2`
  and bundle-build allowlist `4,5`; and the required secrets are deployed without retaining their
  values. The encrypted 1 GB volume is in the below-warning usage band. Schema v4 integrity is `ok`
  with zero foreign-key errors, one installation, zero sessions, and zero challenges. All listed
  snapshots are created; the newest is `2026-08-21T07:32:23Z` and retention remains 14 days. The
  single UID-10001 Uvicorn process enables application `INFO` only for the non-propagating
  `app.auth.service` logger
  and keeps access logging off. Health returns `200`, `/extract` returns `404`, unauthenticated
  `/recommend` returns `401`, and the OpenAPI route set matches the reviewed source.
- Former v7 digest `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
  remains the immediate rollback, and Gmail-free v6 digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  remains the required recovery baseline. Both freshly re-resolved and scanned across 90 packages
  with zero critical/high vulnerabilities. Both are operational recovery only: using either
  reopens the exact-candidate deployment, configuration, and manual-review gates and blocks build-5
  archive/QA until v8 is restored and reverified. Emergency pre-build-4 rollback digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  is App-Attest-only and scan-clean, but it re-exposes `/extract`; using it must halt the release.
- The payload-free v8 post-change review passed at `2026-08-21T11:09:20Z`. The two-day HTTP view
  showed only `401`/`404` and no 5xx series; the bounded ten-minute view had no auth-rejection/rate-
  limit, Anthropic/stylist, maintenance, unhandled, malformed-lifecycle, or access-log event.
  Anthropic status, configured-limit, below-80%-of-limit, expected deployed Wardrobe key/Opus 4.8,
  and no-saturation checks passed, as did the published support pages, contact/response target, and
  retained routing rehearsal. The live logging configuration is deployed, but the bounded query had
  zero `registration_succeeded`, `assertion_succeeded`, and `installation_deleted` events because
  no corresponding lifecycle operation was exercised after v8 deployment. Real production marker
  observation remains open. Protected `/recommend` success intentionally emits no developer event;
  prove it separately through the aggregate `recommend-installation` admission counter and a visible
  non-cached client result.
- Pre-APP-036 development proof: App Attest enrollment, assertion renewal, and `/recommend`
  succeeded on an iPhone 16 Pro running iOS 26.6 with build 4. The iOS 27+ runtime category/build
  fields were absent as expected. Repeat the relevant proof against the final Gmail-free build;
  the earlier run is a baseline, not candidate evidence.
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
- APP-009's lifecycle/logging policy is approved in
  [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md), and Fly v8 deploys
  its repository-owned enforcement. On 2026-08-19 the owner accepted Fly's fixed seven-day
  customer-visible logs, undisclosed provider-internal in-service retention, and 14-day
  snapshot-listing boundary with undisclosed all-copy purge timing. An isolated, secret-free,
  read-only restore of the 2026-08-19 snapshot passed aggregate-only schema/integrity checks and
  its temporary resources were removed within 391 seconds of volume creation. Build 4 subsequently
  supplied partial production TestFlight enrollment, assertion-renewal, and protected-call evidence,
  but did not complete the physical QA matrix and exposed a release defect; build 5 must repeat the
  proof. Snapshot-list expiry, deletion-specific recovery, server-deletion UI proof, and real
  registration/assertion success-marker observation are still required. Apple upload/processing
  and internal assignment alone do not satisfy those physical-client checks. The first payload-free
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
  archive is now superseded and cannot satisfy any current gate. The later uploaded build-4
  archive/profile proof is historical. The independent build-5 archive/profile proof is retained
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

The current build-5 replacement path is ordered; Apple distribution is complete and its physical
and identity-handoff gates remain open:

- [x] **Freeze the fixes.** Reviewed PR #23 merged the Today offline-cache fix, its focused
  tests, the production registration/assertion success-marker logging fix, and the TestFlight build
  `4,5` backend allowlist at `2026-08-21T10:29:56Z`. The frozen shipped-code/backend source was
  `4a75b99dcd49e818ad1d5b198e8c49abba702e18`; later docs-only evidence does not change the
  deployed image or iOS bundle. Keep `MARKETING_VERSION = 1.0.0`; both the archive-time and final
  pre-validation unused-build checks passed.
- [x] **Retain local pre-archive regression evidence.** The current build-5 worktree passed 221
  backend tests plus locked dependency audit/Bandit/Ruff/mypy; the regenerated project passed 218
  Swift unit tests and all 9 UI flows; and 43 release-script tests plus Release simulator/artifact
  checks passed. Rerun any affected gate if source or configuration changes before archive.
- [x] **Build, scan, deploy, configure, and review the backend candidate.** Fly v8 serves exact PR
  #23 source and immutable digest
  `sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
  Local/registry scans, runtime/storage/route/configuration checks, the `4,5` allowlist, targeted
  INFO logger, retained rollback/recovery checks, and the `2026-08-21T11:09:20Z` payload-free
  post-change review passed. This closes deployment/configuration review only; the real lifecycle-
  marker observation remains in the physical-device gate below.
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
  is consumed; do not install or automatically update to it before build 4's identity-safe handoff.
- [ ] **Complete build 4's identity-safe handoff before uninstall.** Follow the ordered stop gate in
  Post-upload APP-009 closure: preserve remaining local evidence, wait for an eligible post-
  enrollment snapshot, delete server security data with aggregate confirmation, and only then
  clear local data and remove build 4. Stop on any ambiguous result.
- [ ] **Repeat complete physical QA on build 5.** Use a clean TestFlight install, close every gap
  listed in the partial build-4 record, observe real bounded `registration_succeeded`/
  `assertion_succeeded` events without payloads or identifiers, and verify the Today cache remains
  usable through a failed Restyle and recovery. Then finish deletion/reinstall and snapshot-specific
  recovery evidence. The zero-event post-deploy query did not close this gate.

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
historical build-4 evidence, not upgrade or migration support and not permission to install build 5
over an older app.

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
   a build number.
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

   Current build-5 archive evidence: fresh private-registry authentication re-resolved exact
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
8. **Run fresh-install QA.** Never install a fresh-reset candidate over an older app. Build 4 was
   installed cleanly and supplied only the partial historical evidence recorded below. For the
   current replacement, complete the build-4 identity-safe handoff below before uninstall. Then test
   build 5 as a separate clean physical-device install and repeat the complete matrix: launch/icon, local
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
| Today cache / release defect | The cached look survived an offline relaunch, but tapping **Restyle** while offline replaced the usable look with the error state. The look returned only after another relaunch and a tap. Build 4 is not promotable; build 5 must contain and verify the fix |
| Online recovery | Styling recovered online and showed `Styled 17:24`; aggregate assertion total advanced from 1 to 2 and the current recommendation-installation rate window from 0 to 1 |
| Signed runtime fields | Validation category/build fields were absent, as expected on iOS 26.6; this is not category/build-enforcement evidence |
| Local flows | Manual add/edit, Demo Mode, **Wear this**, and History passed. Camera and Photo Library opened and cancelled only; successful media selection remains untested. Reminder permission and scheduling passed; delivery remains untested |
| Production marker stream | The build-4 bounded stream had no `registration_succeeded` or `assertion_succeeded` matches because live v7 suppressed INFO lifecycle events at the time. `installation_deleted` was not expected because deletion was paused. Protected `/recommend` intentionally has no developer success event and was proven separately by the aggregate admission counter plus the non-cached client result. Fly v8 now deploys the targeted logger and build `4,5` allowlist, but its post-deploy lifecycle-event counts remain zero because those operations have not yet been exercised against v8 |
| Snapshot / deletion boundary | The latest listed 14-day snapshot, `2026-08-21T07:32:23Z`, predates this enrollment. Server deletion and reinstall testing are paused until eligible recovery evidence can be retained without risking restoration of the enrolled identity |

Still open: successful Camera and Photo Library selection, notification delivery, styling-consent
withdrawal, local deletion, server-security-data deletion, a complete clean build-5 repeat,
real registration/assertion success-marker production observation, snapshot-list expiry
and deletion-specific recovery, and final owner-confirmed Google retirement.

- [x] Retain historical build-4 signed production App Attest entitlement, matching embedded App
  Store profile and certificate, and strict artifact-verifier result. The verified uploaded archive
  is `Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`; historical `dd3d990` archives are superseded and
  cannot satisfy any later upload or processed-build gate.
- [ ] From processed internal TestFlight build 5, repeat production enrollment and cold assertion/
  session renewal, and observe the bounded `registration_succeeded`/`assertion_succeeded` markers.
  Prove a protected `/recommend` separately with its aggregate admission-counter delta and a visible
  non-cached client result. Record the tester OS and signed runtime-field presence; do not claim
  category/build enforcement when iOS 18–26 omits those fields. Build-4 partial evidence does not
  close this current-candidate gate.
- [ ] Before uninstalling build 4, preserve any remaining local-flow evidence, withdraw styling
  consent, and disable reminders. Wait for and verify an eligible automatic snapshot created after
  build-4 enrollment. While build 4 still holds proof of possession, use **Delete Server Security
  Data**, confirm the production installation/session aggregates return to zero, and retain only the
  redacted outcome. Complete the separate local-data deletion after its evidence is no longer
  needed. Stop on any ambiguous deletion or aggregate result; do not uninstall or re-enroll.
- [ ] Only after the build-4 identity-safe handoff passes, uninstall build 4, install processed build
  5 cleanly, and complete the entire fresh-install QA matrix, including the build-4 gaps and the
  Today offline-cache regression. Never install build 5 over build 4.
- [ ] Finish the remaining observable operations evidence: eligible 14-day snapshot-list
  disappearance and deletion-specific recovery. The generic isolated restore-path rehearsal does
  not prove that a deleted production identity cannot return.
- [ ] After processed build 5 and its replacement backend are proven, obtain a separate final
  owner confirmation and retire only the inventoried Wardrobe Google Cloud/OAuth projects. Do not
  touch unrelated Google Cloud or Search Console resources.

## Promoting an internally tested build

Build 4 is not promotable because physical QA found the Today offline-cache defect. When build 5 is
fully approved for public release, do not rebuild unless something changed:

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
`2026-08-22T03:24:21Z`. Assignment does not authorize installation: keep build 5 uninstalled and
automatic updates disabled until build 4's identity-safe handoff is complete.

## Official Apple references

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
- [View builds and upload status](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata)
- [Establishing your app's integrity with App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Validating App Attest at your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Preparing App Attest environments and rollout](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
