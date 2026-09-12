# App Store submission checklist

This is the final operational checklist, not proof that an item is already complete. Attach the
release evidence beside each checked item and use the exact uploaded build throughout.

For internal beta distribution, follow
[`internal-testflight-runbook.md`](internal-testflight-runbook.md). Internal describes the tester
audience, not a weaker binary: use Xcode's **TestFlight & App Store** route and add the processed
build only to an Internal Testing group. Do not use **TestFlight Internal Only** when the build may
later be promoted to customers.

Use the [release plan](../release-plan.md) to distinguish the three milestones: the internal
local-first beta with AI disabled, separately approved AI activation for the small pilot, and the
public Singapore release. The beta uses the explicit `internal-beta-ai-disabled` operations
review; its result does not authorize AI activation or public submission. Applicable signing,
auth/storage, privacy and distribution checks remain required for each milestone.

Build `1.0.0 (7)` has completed internal distribution: **Complete / Ready to Submit**, only
`Family` Internal Testing with one group tester and no individual testers. Approved enabled-pilot
notes were saved/reload-verified on 12 September, replacing the initial AI-disabled notes.
Build 7 is consumed and must never be reused. The
[distribution record](internal-testflight-runbook.md#build-7-distribution--2026-09-10) retains proof;
the [11 September checkpoint](internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial)
records completed handoff, clean installation and scoped local-beta QA. AI activation and public
submission remain separate. Apple's **Ready to Submit** status is not public-release approval.

## 12 September preparation checkpoint

See the [prepared package](submission-preparation-20260912.md) for current account observations,
listing and assets. Existing bundle/SKU, agreements and bank/tax/DSA status are verified. The
bounded pilot and first protected call are complete. The approved listing, reviewer instructions,
no-sign-in/manual-release settings, age/content-rights declarations and build 7 are saved. Five
fictional screenshots are uploaded, ordered and reload-verified. Free pricing, Singapore-only
availability and disabled Mac/Vision availability are also saved and reload-verified. Categories
`2,4` are deployed as Fly v14, with independent configuration postcheck PASS at
`2026-09-12T06:36:24Z`. Full post-change operations at `2026-09-12T07:09:37Z` completed with
the approved Cowork-only status exception; every other operational check passed. Public submission
awaits the owner's final submission decision. Inventoried Google project retirement remains
open, unperformed and subject to separate owner confirmation; that deferred cleanup is not a
public-v1 submission gate. Apple's
version `1.0.0`/build-7 draft passed Add for Review validation and is Ready for Review; Submit for
Review has not been clicked. Older unchecked historical checklist
rows do not require replaying the completed handoff, local QA or pilot.

## 1. External decisions and account readiness

- [ ] Confirm legal seller name/entity, copyright owner, postal address, support/privacy/security
  contacts, and review phone number.
- [x] Decide the initial version, price, and territory: public `1.0.0`/build 7 is Free, has no in-app
  purchase or subscription, and is available only in Singapore. The sequenced follow-up is
  freemium in Singapore, then controlled country expansion.
- [x] Retain App Store software as the tax category and the existing active DSA trader status;
  manual release after Apple approval is saved for the 1.0.0 draft.
- [x] Confirm current Apple agreements, tax, banking and DSA status: active/complete in the
  signed-in 12 September inspection; refresh any new Apple notice before submission.
- [x] Confirm the existing bundle ID and immutable SKU: both `com.tth.Wardrobe`, inspected
  12 September. Do not create another app record.
- [ ] Confirm the approved public-v1 scope is Gmail-free and no Google OAuth verification,
  restricted-scope, or review-account dependency remains in the candidate.
- [x] Approve the private Singapore-launch AI spend/admission envelope and daily monitoring policy.
  The owner approved those limits on 6 September and the finite disabled setup, Fly hosting policy
  and private capacity-review bounds on 8 September. Preserve those approvals; do not request or
  initialize them again merely because later launch gates remain open.
- [x] Complete the controlled AI pilot (enabled review and first protected call passed
  12 September; public submission remains separate): verify the fail-closed global spend/admission ceiling,
  bounded request/token/retry exposure, approved daily owner cost review and emergency-disable
  response. Retain the recorded Sonnet acceptance and verify the exact locked SDK/model/API
  configuration. Review privacy/provider terms and consent before requesting approval of the
  bounded enablement and verification call; confirm the enabled state afterward. Daily review
  has detection delay and cannot hard-cap Fly charges. Provider notification settings do not
  prove delivery; hourly monitoring and a new alert service remain deferred under the
  [current cost routine](../release-plan.md#small-pilot-cost-routine). Keep exact billing values
  private. This AI milestone does not block the explicitly AI-disabled internal beta or close
  the public release's separate privacy, recovery and App Store requirements.
  Local model/SDK migration, synthetic evaluation tooling, and durable spend controls are
  prepared; see [model evaluation](../model-evaluation.md) and
  [spend controls](../ai-spend-controls.md). The first approved evaluation stopped after its
  first request timed out, with no returned output/usage or automatic retry. A separately approved
  office-case diagnostic succeeded in 5.86 seconds at $0.004222 before tax; it does not close
  the full acceptance gate. A fresh approved 28-call run subsequently completed for $0.136602
  before tax but failed completeness (23/24) and distinct looks (22/24). Caching had no reads
  and stays off. Prompt clarification passed full local regressions, but its separately approved
  28-call rerun also failed: distinct looks and required alternates each passed 23/24, at
  $0.133243 before tax. Sonnet 5 comparison support is prepared and tested. The owner approved
  its first 28-call run within an additional $58 pre-tax ceiling on 2026-09-06; it completed
  for $0.333305 before tax but failed required alternates 23/24.
  Completeness/distinctness passed 24/24 and p95 was 13.266 seconds. A general optional-item
  clarification is implemented and fully tested with the acceptance floor
  unchanged. Warm cache savings do not yet prove production reuse. On 2026-09-06 the owner
  approved one revised 28-call Sonnet run from `10e837b`, within an additional $58 pre-tax
  ceiling, under manifest
  `ae2479794e5aa40dc79ed4c555c9f89c9b8bfb4d451bce29120563357931fa06`. The revised run
  completed all 28 calls without provider errors or retries for $0.360167 before tax and passed
  the unchanged automatic floor: all six hard checks 24/24, avoidance 4/4, preference 3/4,
  and p95 latency 12.665 seconds. Its quality-call cost was $0.012839 per mechanically usable
  recommendation, with human acceptance pending at that evaluation checkpoint. The cache pair saved about 20.85% on
  input, but real production reuse remains unproven and caching stays off. All prior failures
  remain recorded. After providing one complete numeric scorecard, the owner said "all are ok,
  proceed" and accepted all proposals qualitatively. Preserve that decision separately from
  the incomplete numeric rubric; no scores were inferred and no numeric pass is claimed.
  The selected Sonnet runtime, now enabled under the approved bounded pilot, has aligned 2-input/10-output micro-USD pricing,
  full-context reservations, and a v2 model/rate-bound ledger. All 28 request hashes match the
  accepted run; full migration regression passed (505 backend, 236 iOS, 44 release-script
  tests, security/type/lint checks, and Release simulator/artifact checks). No additional
  paid call was required.
  The owner expects up to 10 AI users in month one and approved the private spend/admission
  limits and owner-operated daily monitoring policy on 2026-09-06. Exact limits remain in ignored
  private release records. The approved 8 September setup provisioned the ledger once, applied
  the policy and workspace key in Fly v12 with AI false, verified usable prepaid credit with
  auto-reload off, and passed the approved public-capacity review. Preserve the existing ledger;
  do not repeat provisioning. Actual provider alert delivery remains unproven. Under the
  10 September reset, the small pilot uses daily owner review of AI/provider spend, Fly billing
  and resources, with discrepancies and unknown coverage retained; new monitoring infrastructure
  is deferred. The later beta-only review and internal distribution are complete. Key rotation
  before 8 October and fresh checks for later changes remain required. Separately approved
  v13 activation and enabled verification passed; protected-device styling proof passed on 12 September.
  The ordinary diagnostic correction passed live
  read-only verification on 9 September;
  that historical budget check returned OPEN `styling-disabled`. Earlier excluded
  evaluation uncertainty remains separate from the launch ledger. This disabled setup is not
  public-launch authorization; see the
  [launch-readiness follow-up](internal-testflight-runbook.md#launch-readiness-follow-up--2026-09-09).
  The later local capacity-preflight extension passed 551 backend tests, full security/type/lint
  checks, 236 iOS tests, 44 release-script tests, and fresh Release simulator/artifact checks.
  No shared-contract/iOS/runtime-auth source or live release lock changed in that extension;
  the preserved Build 7 archive remains unchanged and no new TestFlight build is required.
  Source publication and the review/merge cycle are separately owner-approved in
  [PR #41](https://github.com/tzehon/wardrobe-stylist/pull/41), created as a draft and immediately
  marked ready. The PR records its checks, current-head Codex review, and final merge state;
  those source gates confer no production or distribution approval.
  Review fixes now pin runtime/preflight output to integer 1,024 and reject numeric scoring
  against a stale or altered source/model manifest. Final verification passed 583 backend tests,
  full security/type/lint checks, 236 iOS tests, 44 release-script tests, and fresh Release
  simulator/artifact checks. All accepted request hashes remain unchanged; no new paid call or
  TestFlight build is required. The PR records the fixes' required review and merge outcome.

PR #41 merged to `e3a837b`; the subsequent local image scan found four High-severity findings
in inherited `util-linux`. The `libuuid>=2.42.3-r1` remediation preserves the pinned bases
and crypto refresh, and its rebuilt image passes the zero-High/Critical scan and isolated runtime,
logging, separate-storage and restart checks.
[PR #42](https://github.com/tzehon/wardrobe-stylist/pull/42) records the owner-approved source
publication, required checks, Codex review, and merge state. The earlier read-only production
preflight retained OPEN source, budget, recovery-scan and manual gates. See the
[runtime security checkpoint](internal-testflight-runbook.md#runtime-security-follow-up--2026-09-06).
The remediation passed all 583 backend tests and security/type/lint gates, 236 iOS tests,
44 release-script tests, and fresh Release simulator/artifact checks.
The preserved Build 7 archive is unchanged; no new TestFlight build is required.

- [x] Retain the historical 7 September patched-runtime rollout **with AI disabled only**. The owner separately
  approved private publication/deployment of merged source
  `d2866a2375dd4795f40a3ab13d273ed138cedd7e`. Fly v11 was healthy on the original Machine and volume
  at `2026-09-07T10:36:34Z`; the disabled-only review completed at `2026-09-07T10:39:08Z`.
  Exact source/architecture/private-registry matching, zero-High/Critical scans, App Attest/auth
  integrity, privilege/logging controls, snapshots, and public pages passed. At that checkpoint
  the budget policy was unapplied and no budget storage or paid call was created. Budget and
  manual rows remained OPEN. The subsequent v12 setup below supersedes that unprovisioned state;
  it does not backdate the earlier credit, capacity or recovery evidence. See the historical
  [disabled rollout checkpoint](internal-testflight-runbook.md#disabled-runtime-rollout--2026-09-07).
- [x] Complete the approved budget/provider setup and verify **Fly v12 with AI disabled**.
  Independent review passed at `2026-09-08T09:32:49Z` on the unchanged source/image and original
  Machine/volume. All six private AI settings and the workspace key are deployed; the session
  secret is preserved. The service-identity probe reads the intact, zero-state v2 ledger and
  confirms the disabled 503 guard. Auth storage, approved public-capacity bounds, snapshots,
  bounded logs and public pages pass. The provider cap/notification settings, usable credit and
  auto-reload-off state are verified; actual alert delivery is still unproven. The same image
  reads the existing ledger after restart without initialization/reset and remains the private
  recovery baseline; pre-budget v10 is not a normal rollback target. Never reinitialize this
  ledger to regain allowance. At that checkpoint the ordinary checker reported
  `styling-budget-evidence-open` because of its ownership-context gap; the independent configured
  probe did not close that checker or the full pre-upload gate. Preserve this historical outcome
  alongside the later correction below. See the
  [approved disabled setup](internal-testflight-runbook.md#approved-disabled-budget-setup--2026-09-08).
- [x] Correct and verify the ordinary budget diagnostic's service identity. At
  `2026-09-09T00:05:29Z`, the standard read-only check returned OPEN `styling-disabled` against the
  same healthy v12 image, Machine and configuration. It now connects as `wardrobe`, requires
  real/effective UID and GID 10001 before inspecting status, and uses `-B` to avoid bytecode writes.
  No runtime, provider or ledger mutation and no paid call occurred. The local correction passed
  590 backend tests and the locked security/type/lint checks. At that diagnostic checkpoint the
  broader launch and pre-upload gates remained open; the later beta-only review and distribution
  are recorded above. Preserve the historical
  [launch-readiness follow-up](internal-testflight-runbook.md#launch-readiness-follow-up--2026-09-09).

## 2. Public pages and truthful data declarations

- [x] Republish the homepage, support page, privacy policy, Terms, and deletion/help instructions
  on the same stable owned HTTPS domain with Gmail/receipt-import language removed; remove every
  bracketed placeholder from the publication sources. `tzehon.github.io` PR #5 merged as
  `c5da090a0417bcda99fc6d328a0cdff808ea597d` at `2026-08-21T01:42:01Z`, and its matching Pages
  deployment completed successfully at `2026-08-21T01:42:39Z`.
- [x] Verify each public URL on a signed-out browser and configure the exact values in Release.
  At `2026-08-21T01:49:21Z`, the signed-out in-app browser rendered the support, privacy, and Terms
  pages with the expected Gmail-free copy and reciprocal links. `ios/Distribution.xcconfig`
  contains the exact support and privacy URLs; the file remains gitignored.
- [x] Reconcile the policy, in-app disclosures, request captures, backend/host logs, provider
  terms and [`app-privacy-data-inventory.md`](app-privacy-data-inventory.md). The
  [12 September review](ai-pilot-privacy-review-20260912.md) retains build 7/notice version 3,
  records the provider terms and publishes the policy including aggregate accounting.
- [x] Publish and reload-verify the policy URL and four App Privacy categories on 12 September.
  All are linked and not tracking; all use App Functionality, with Product Personalization only
  for Other User Content. Reassess these answers if a provider, purpose or data flow changes;
  [Apple guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).
- [x] Complete the age-rating questionnaire from observed final behavior. Apple calculated 9+
  for the lifestyle-content answers, with medical content None; Kids was not selected.

## 3. Product-page record

- [x] Enter the final name, subtitle, primary language, categories, description, keywords,
  promotional text, copyright, support URL, and optional marketing URL from
  [`metadata-draft.md`](metadata-draft.md).
- [x] Complete content rights, export compliance, DSA, tax category, and region-specific
  declarations; verify App Store Connect shows price **Free**, only **Singapore** enabled, and no
  in-app purchase or subscription offered with version 1.0. Content rights, DSA and tax category
  are saved; Free price (Singapore base SGD 0.00), only Singapore/174 unavailable territories and
  disabled Mac/Vision availability are reload-verified. Add for Review validation passed with no
  blocking metadata/compliance prompt; refresh any new Apple notice before submission.
- [x] Upload and reload-verify the five fictional screenshots in Catalog/editor/detail/Today/History
  order using [`screenshot-plan.md`](screenshot-plan.md). The 6.5-inch slot automatically uses
  the 6.9-inch images.
- [x] Save the owner-confirmed private review contact and exact no-login reviewer instructions from
  [`review-notes-1.0.0.txt`](review-notes-1.0.0.txt). Confirm App Review needs no Google,
  Wardrobe, or shared test account.

Apple's current field matrix is the source of truth for which properties are required, localizable,
or editable: [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties).

## 4. Historical build-4 and current replacement evidence

Checked historical items in this section preserve the uploaded build-4 and build-5 records.
`1.0.0 (5)` was strictly verified, Organizer-validated, uploaded, processed, and assigned to the
`Family` Internal Testing group. Its clean-install physical matrix reached local and connected
flows, but tapping the delivered local reminder crashed at `2026-08-22T17:15:14+08:00`. Build 5
is consumed and non-promotable. A signed-in App Store Connect TestFlight Build Uploads refresh at
`2026-08-22T10:02:31Z` showed builds 1–5 only, build 5 **Complete**, and no build 6, confirming
build 6 unused before replacement work. Build 6 has since completed strict verification, normal-
route validation/upload, Apple processing, and `Family` Internal Testing assignment. It is consumed
and must never be reused. Clean build-6 QA passed through the fixed delivered-reminder tap without
a crash or local-state loss. Its final owner-controlled deletion/reinstall/new-enrollment handoff is
also complete. A 2026-08-28 owner-supplied Dark Mode screenshot separately confirmed that the
**Allow AI styling** title is approximately 21 points right of center and its sampled `#C2DFFC` fill
against white is approximately `1.38:1`; build 6 is therefore non-promotable. PR #31 has since merged
and verified the replacement control implementation. At the earlier build-selection checkpoint on
2026-08-29, the signed-in TestFlight **Build Uploads** view showed build 6 as the highest upload and
**Complete**, with build 7 absent.
That checkpoint selected `1.0.0 (7)` with `MARKETING_VERSION = 1.0.0`; source configuration records
accepted builds `4,5,6,7`. The exact merged Linux/AMD64 backend deployed as Fly v10 and passed the
required post-change review on 2026-08-29, and the exact-source regression passed. The `04:21:50Z`
review and `07:15:57Z` archive are timing-stale/non-uploadable evidence; the earlier development-
signed archive is separately invalid/non-uploadable. A fresh full review completed at `11:02:18Z`,
followed by the distinct final signed archive at `11:03:10Z` and strict verification at `11:04:02Z`.
The signed-in `11:05:38Z` Build Uploads refresh showed build 6 highest and **Ready to Submit**, with
build 7 absent. The later internal distribution and 11 September handoff/clean local-beta QA are
complete. The monitored 25/28 August snapshots were later observed absent from the customer-visible
list. The 10 September Build-7 pre-deletion snapshot's later disappearance and deletion-specific
recovery/non-return were not proven; the owner waived only that evidence sub-gate for the Free
Singapore v1 and accepted the residual risk. The
archive-era absence is not permission to reuse build 7.

- [x] Review and freeze the Today offline-cache fix, its focused tests, the backend registration/
  assertion success-marker logging fix, and source `4,5` TestFlight allowlist. Reviewed PR #23
  merged at `2026-08-21T10:29:56Z`; frozen shipped-code/backend source was
  `4a75b99dcd49e818ad1d5b198e8c49abba702e18`. Later docs-only evidence does not change the
  deployed image or iOS bundle.
- [x] Retain the historical build-5 pre-archive regression: 221 backend tests plus locked audit/
  Bandit/Ruff/mypy, 218 Swift unit tests, all 9 UI flows, all 43 release-script tests, and Release
  simulator/artifact checks passed after project regeneration. Rerun affected gates if source or
  configuration changes; this local regression is distinct from the retained signed archive and
  is not distribution evidence.
- [x] Retain the notification-router fix regression separately from the historical signed build-5
  archive: 17 focused tests passed; merged-source verification retained 221 backend tests plus the
  locked audit/Bandit/Ruff/mypy gates, 231/231 iOS tests, and all 43 release-script tests.
- [x] Retain the historical build-5 backend evidence. Fly v8 completed at
  `2026-08-21T10:45:06Z` with exact source and immutable registry digest
  `sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
  Local/registry zero-critical/high scans, runtime/storage/route checks, production App Attest
  category `2` and builds `4,5`, targeted INFO logging, rollback/recovery checks, and the payload-
  free post-change review at `2026-08-21T11:09:20Z` passed. This is not lifecycle-event, upload,
  or physical-device proof.
- [x] Build, verify locally, deploy, configure, and runtime-check the exact build-6 backend.
  Historical Fly v9 served clean merged source `de7c540275fb16e61aabf1884538b18cf6edf76f`;
  a local-only official Alpine secdb comparison found zero unfixed advisories and locked
  `pip-audit` passed. Release and running image references matched; one Singapore Machine was
  healthy; and category `2`, accepted
  builds `4,5,6`, storage, logging, route, and failure-boundary checks passed. No external private-
  image/SBOM scan was run. The required post-deploy/pre-upload operational review was missed and is
  not backdated; the late full review passed at `2026-08-23T02:13:12Z`. Historical Fly v10 state is
  recorded in the build-7 section below. The current
  [Fly v14 bounded pilot is enabled](internal-testflight-runbook.md#app-store-compatibility-deployment--12-september-2026).
  Repeat the full review before any future archive/upload and after every backend/configuration change.
- [x] After the live build-list refresh and exact backend review, create and strictly verify a new
  production-signed `1.0.0 (5)` archive. Fresh authenticated v6 recovery resolution/scan completed
  at `2026-08-22T01:00:09Z`, and the exact-v8 pre-archive review passed at
  `2026-08-22T01:07:45Z`. At `2026-08-22T01:09:39Z`, App Store Connect showed
  builds 1–4 only. Clean source context `695c562b7b18e4a0b7f8a72b814af59efdd0cf3a`, a docs-only
  successor to frozen shipped source `4a75b99dcd49e818ad1d5b198e8c49abba702e18`, produced
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-5-695c562-appstore.xcarchive` at
  `2026-08-22T01:10:32Z` with Xcode 26.6/iOS SDK 26.5. Exact version/build, bundle, arm64, minimum
  iOS 18.0, Apple Distribution profile/certificate identity, App ID prefix/team, scalar production
  App Attest, public HTTPS configuration, privacy manifest, and Gmail-free/shared-bearer guards
  passed when the strict verifier completed at `2026-08-22T01:11:17Z`. The profile UUID is
  `2b11bc90-0194-4fe6-8dcc-413c6dc5ccd2` and expires `2027-08-21T02:07:47Z`. A separate quiet
  credential/removed-capability scan passed at `2026-08-22T01:12:01Z`, followed by deep
  signature verification at `2026-08-22T01:12:19Z`. The app/dSYM UUID is
  `DA20FD8D-64C3-3B7A-9990-19EAF050AF04`; executable SHA-256 is
  `a9f01231025874d331e76be40ebe6f493b3f36051902b66b0ad03c35206bb3b9`. Do not reuse build-4
  evidence.
- [x] Retain exact synthetic build-5 `/recommend` request-capture evidence. The tests-only guard
  inventories every stored property on the Swift request types, including nil optionals, and
  separately pins every encoded top-level, catalog-item, and preference key; the shared schema/
  backend reject extras. The strengthened focused `RecommendClientTests` suite passed 12/12 at
  `2026-08-22T01:59:08Z`. The resulting tree then passed the complete mandatory backend gate (221
  tests plus audit/Bandit/Ruff/mypy) and one uninterrupted historical pre-archive iOS run (218 Swift
  unit tests plus
  all 9 UI tests; 227/227 canonical cases), whose result bundle finalized at
  `2026-08-22T02:04:17Z`, with no failures, skips, or retries. No production payload, credential,
  token, or identifier was inspected or retained, and the test does not alter the signed bundle.

- [x] Merge and freeze the reviewed Swift/backend/contract/verifier fixes on clean synchronized
  `main`. PR #19 rebase-merged source `d4637f4b2adf14cd533594aec6060c385f8a5e2b`.
- [x] Build and scan the exact frozen `linux/amd64` backend image, deploy only its recorded digest,
  verify production health/configuration/Gmail-free behavior, and complete the required payload-
  free post-deploy manual review. At this historical build-4 gate, Fly v7 served
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`;
  the review passed at `2026-08-21T06:00:21Z`.
- [x] Confirm the latest build already uploaded to App Store Connect, then select the next unused
  `CURRENT_PROJECT_VERSION`. If this exact internal build may be promoted, set the intended public
  `MARKETING_VERSION` before archiving; do not rely on Xcode to invent either value during upload.
  The fresh check at `2026-08-21T06:34:50Z` showed builds 1–3 only, so the replacement archive
  correctly uses `1.0.0 (4)`.
- [x] Immediately before the build-5 archive, refresh App Store Connect and confirm build 5 is
  still unused. The `2026-08-22T01:09:39Z` refresh showed builds 1–4 only and build 4 highest.
- [x] Refresh App Store Connect again immediately before build-5 validation/upload and stop if
  build 5 is no longer unused. At `2026-08-22T03:16:16Z`, builds 1–4 remained the only uploads and
  build 5 was absent.
- [x] Regenerate the project and run the complete backend, Swift unit, UI, public-config,
  request-capture, artifact/privacy-manifest, and Release-build checks from the repository runbook.
  Clean source context `24c17cb` passed 219 backend tests, 215 Swift tests, all 9 UI flows, and 43
  release-script tests plus the locked audit/security/type and Release artifact gates.
- [x] Confirm the build-4 replacement archive contains no Google Sign-In SDK/client configuration,
  Gmail permission or route, `/extract` client path, receipt-import UI/background task, Anthropic/shared
  backend secret, non-HTTPS production endpoint, or placeholder public link.
- [x] Build the build-4 replacement archive with an accepted production Xcode/SDK. Xcode 26.6 with
  the iOS 26.5 SDK created the verified archive at `2026-08-21T06:36:33Z`. As of 28 April 2026,
  Apple requires uploads to use the iOS 26 SDK or later:
  [current SDK minimum](https://developer.apple.com/news/?id=ueeok6yw).
- [x] Confirm the launch-screen key remains present in the build-4 replacement archive. Uploads
  built with the iOS 27 SDK or later are validated for a launch-screen configuration:
  [TN3208](https://developer.apple.com/documentation/technotes/tn3208-preparing-your-apps-launch-screen-to-meet-app-store-requirements).
- [x] Create and verify the historical uploaded build-4 production-signed archive; record commit,
  version/build, Xcode/SDK, dependency resolution, entitlements, privacy manifests, and signed-
  artifact output.
  The retained uploaded archive is
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`; strict
  certificate/profile, scalar production App Attest, public-config, privacy-manifest, and Gmail-
  free artifact verification passed. A separate targeted scan found no Anthropic/API-key, shared-
  bearer, or private-key credential marker; separate `dwarfdump --uuid` output matched the arm64
  app and dSYM at `5BA1F06E-7458-32A4-890F-36C8F22D9C13`.
- [x] Refresh App Store Connect's build-upload list immediately before validation/upload. At
  `2026-08-21T08:12:46Z`, builds 1-3 remained the only uploads, so build 4 was still unused at the
  final stop check. Build 4 has since uploaded and must never be reused.
- [x] Repeat the payload-free manual operations review against the exact deployed backend
  immediately before validation/upload. The exact-v7 review passed at
  `2026-08-21T08:12:46Z` with no remediation required.
- [x] Validate and export/upload exactly the newly recorded build-4 replacement archive; retain
  validation and upload status, symbols, and an exported-artifact hash when an artifact is exported.
  Direct Organizer upload of the exact build-4 replacement archive validated at 08:16Z and
  uploaded at 08:18Z; App Store Connect reports symbols included. No standalone IPA was exported,
  so the retained binary identity is executable SHA-256
  `81ab249bbab122f549809bc094bdf8bbc450e84db34888b19a3272fe02cd22c6` plus matching app/dSYM UUID
  `5BA1F06E-7458-32A4-890F-36C8F22D9C13`. The formerly verified
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-dd3d990-appstore.xcarchive` was superseded by
  shipped Swift/backend changes, was not the build-4 upload target, and remains ineligible for any
  later upload. The development-signed
  `Wardrobe-1.0.0-4-dd3d990.xcarchive` is also ineligible.
- [x] Distribute from Organizer using **TestFlight & App Store**. The exact build-4 replacement
  archive used Xcode's normal App Store Connect route and processed successfully; **TestFlight
  Internal Only** was not used, and the device-Release public configuration guard was not bypassed.
- [x] Complete the build-4 identity-safe handoff. The eligible automatic snapshot created at
  `2026-08-22T07:33:23Z` reported `created` with 14-day retention. Build 4's proof of possession
  remained available after build 5 appeared installed in place unexpectedly. With that inherited
  identity still installed, **Delete Server Security Data** emitted exactly one bounded
  `installation_deleted` success marker and the live installations/sessions/challenges aggregates
  became `0/0/0`. Local data and then the app were deleted, and build 5 was installed cleanly.
  This recovery is deletion evidence, not in-place upgrade or migration support.
- [x] Retain the clean build-5 physical QA completed before the reminder-tap blocker. On iPhone 16
  Pro/iOS 26.6, first launch showed no login and an empty wardrobe; offline Demo Mode, Camera and
  Photo Library saves, and the complete add/edit/favorite/filter/archive/restore/search/delete
  catalog flow passed. Online Style at `16:30` exercised registration; cached relaunch passed;
  Restyle at `17:04` exercised assertion renewal; a failed offline Restyle preserved the cached
  look; offline Wear this/History passed; and the local reminder was delivered. The connected
  lifecycle markers and coarse server aggregates were observed without retaining identifiers.
- [x] Repeat the affected clean physical matrix using the replaced reminder response implementation
  in processed build 6. The build-5 crash evidence remains historical. Build 5 completed its
  identity-safe handoff, build 6 was installed cleanly, and launch/offline/media/catalog,
  production registration/assertion, Today cache/failure, Wear/History, reminder delivery, and the
  delivered-reminder tap passed without a crash or local-state loss.
- [x] Complete the final build-6 deletion/reinstall/new-enrollment handoff in owner-controlled order.
  The eligible automatic snapshot created at `2026-08-25T07:35:53Z` reported `created` with 14-day
  retention. The pre-deletion installation/session/challenge aggregate was `1/0/0`;
  assertion-verified deletion emitted exactly one bounded success marker and returned it to
  `0/0/0`, which persisted after local deletion and uninstall. Clean reinstall, launch, two local
  additions, and styling-consent grant kept the backend at `0/0/0`. Explicit **Style a look** at
  `2026-08-28 17:17 SGT` created one active installation and one active session, zero pending and
  zero failed challenges, one completed challenge, exactly one registration-success marker, and
  expected runtime category/build-field absence on iOS 26.6. No identifiers, payloads, credentials,
  or raw log samples are retained.
- [x] Record the owner-approved snapshot/recovery evidence waiver for Free Singapore v1. The
  monitored 25/28 August snapshots were observed absent from the customer-visible list, while the
  10 September Build-7 pre-deletion snapshot remained listed. The completed final-client handoff
  and generic isolated restore rehearsal do not prove that a deleted production identity cannot
  return. On 2026-09-11 the owner accepted that snapshot's unproved later listing disappearance and
  the non-return residual risk; this checks the waiver decision, not the missing evidence as passed.
- [x] Confirm that build 6 fails the **Allow AI styling** presentation gate. The 2026-08-28 owner-
  supplied Dark Mode screenshot places the title approximately 21 points right of center and
  measures the sampled `#C2DFFC` fill against white at approximately `1.38:1`. Build 6 is consumed,
  non-promotable, and must never be reused; its completed identity and notification evidence remains
  valid.
- [x] Complete and verify the replacement control implementation. PR #31 rebase-merged app commit
  `b7e46e4` to clean `main` `e4a0ae2`. The title-only control is centered, full-width, and opaque;
  focused coverage pins enabled, pressed, and disabled contrast plus the screenshot UI assertion.
  Merged verification passed 221 backend tests plus audit/Bandit/Ruff/mypy, 226 Swift unit tests,
  all 9 UI tests, and 43 release-script tests; both GitHub iOS checks are green.
- [x] Select and source-prepare build 7 without claiming deployment. The signed-in TestFlight
  **Build Uploads** view on 2026-08-29 showed build 6 as the highest upload and **Complete**, with
  build 7 absent. That selected `1.0.0 (7)`, kept `MARKETING_VERSION = 1.0.0` and prepared source
  configuration for accepted builds `4,5,6,7`. At selection time, Fly v9 still accepted `4,5,6`.
- [x] Deploy and review the archive-era build-7 backend candidate. Fly v10 accepted
  `4,5,6,7`; exact image, health/configuration/storage/snapshot, and payload-free review passed on
  2026-08-29. The [current Fly v14 bounded pilot is enabled](internal-testflight-runbook.md#app-store-compatibility-deployment--12-september-2026)
  and retains the verified auth/build allowlist. The 10 September beta-only review and internal
  distribution subsequently passed; bounded activation is complete; protected-device styling proof passed on 12 September; public-submission gates remain open.
- [x] Complete the build-7 exact-source regression. Clean synchronized main
  `f183f074d1a63a4ec46d6d34fa13979a2c8b1fdd` passed 222 backend tests plus
  audit/Bandit/Ruff/mypy, 226 Swift unit tests, all 9 UI tests, 43 release-script tests, and the
  Release simulator/artifact gates.
- [x] Complete the build-7 pre-archive review and strict signed-archive gate. The `04:21:50Z` review
  and `07:15:57Z` technically verified archive are retained as timing-stale/non-uploadable evidence;
  the earlier automatic-signing archive is development-signed and separately invalid/non-uploadable.
  A fresh full operations/recovery review against exact Fly v10 completed at
  `2026-08-29T11:02:18Z`, including a fresh private-registry match and zero-High/Critical Docker
  Scout scan. Clean synchronized main `0cc0fa7` then created the distinct final archive
  `Wardrobe-1.0.0-7-0cc0fa7-appstore-final-20260829T110218Z.xcarchive` at `11:03:10Z`; strict
  production App Attest/profile/identity, public-configuration, privacy, Gmail-free, non-emitting
  credential, deep-signature, and matching arm64 app/dSYM verification passed at `11:04:02Z`. The
  signed-in `11:05:38Z` post-archive Build Uploads refresh showed build 6 highest and **Ready to
  Submit**, with build 7 absent.
- [x] Validate and distribute only the exact verified build-7 archive. The 10 September beta-only
  review preceded separate owner approval and normal-route validation/upload. Apple processing,
  `Family` assignment and saved/reloaded AI-disabled notes passed; see the
  [canonical distribution record](internal-testflight-runbook.md#build-7-distribution--2026-09-10).
  Build 7 is consumed; do not repeat this upload.
- [x] Complete build-7 handoff, clean installation and scoped local-beta QA. The
  [11 September checkpoint](internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial)
  records the completed owner-controlled sequence and normal-state Dark Mode screenshot.
  Automated tests cover enabled/pressed/disabled contrast; retain unchanged device evidence.
  Do not repeat deletion, uninstall or routine QA. AI activation and public submission remain separate.
- [x] Complete the pre-upload clean-uninstall transition. The installed development build
  disconnected Google and deleted local data, but predated the server-deletion UI; production had
  zero installations, zero sessions, and zero pending challenges before uninstall, so no live
  identity existed to delete. Build 4 was installed only from processed TestFlight and never over
  the older app; do not claim migration.
- [x] Observe the three real payload-free lifecycle success markers against Fly v8. The clean
  build-5 Style at `16:30` produced the bounded `registration_succeeded` observation and Restyle at
  `17:04` produced `assertion_succeeded`; the preceding build-4 identity-safe handoff produced
  exactly one `installation_deleted` marker and `0/0/0` live aggregates. Protected `/recommend`
  remains aggregate/client-evidenced. This closes marker observation only: actual 14-day snapshot-
  list disappearance of the later 10 September Build-7 pre-deletion snapshot and deletion-specific
  restore/non-return were not proven and were owner-waived for the Free Singapore v1 with the
  residual risk accepted. The monitored 25/28 August snapshots were separately observed absent.
- [x] Retain the historical build-6 App Store Connect check performed before changing
  `CURRENT_PROJECT_VERSION` or archiving that replacement. The signed-in TestFlight Build Uploads
  view at `2026-08-22T10:02:31Z` showed builds
  1–5 only, build 5 **Complete**, and no build 6. Build 6 is confirmed unused and selected;
  the branch records `CURRENT_PROJECT_VERSION = 6`, source allowlist `4,5,6`, and unchanged
  `MARKETING_VERSION = 1.0.0`. The required regression, Release-build, and simulator-artifact gates
  passed again after those changes. The subsequent Fly v9, archive, and Apple distribution gates
  are retained below.

## 5. Upload, review, and release

The first checked item below preserves build-5 distribution evidence; it does not make build 5
promotable after the physical reminder-tap crash. Build 6 distribution and its identity/notification
physical evidence are also complete, but the confirmed styling-consent control presentation failure
makes it non-promotable. Its final deletion/reinstall/new-enrollment handoff remains valid. PR #31
merged and verified the replacement implementation; build `1.0.0 (7)` is selected/source-prepared,
and its exact Fly v10 backend deployment, post-change/pre-archive reviews, exact-source regression,
and strict signed-archive verification passed at the archive checkpoint. The 10 September
validation/upload, processing, `Family` assignment and saved-note loop are complete. The
11 September handoff, clean installation and scoped local-beta QA have since passed. Snapshot
lifecycle non-return evidence is unproved but owner-waived only for the Free Singapore v1; protected-device styling proof passed on 12 September; public submission remains open; bounded AI activation is complete.

- [x] Validate, upload, process, and internally assign only the verified build-5 archive using the
  normal **TestFlight & App Store**-eligible route, then save truthful build-5 What to Test wording.
  The exact-v8 pre-validation review ran from `2026-08-22T02:27:21Z` through `02:37:08Z` and passed.
  The final live build-list refresh at `03:16:16Z` still showed builds 1–4 only and build 5 absent.
  Xcode validation succeeded at `03:18:30Z` and the normal App Store Connect upload succeeded at
  `03:20:59Z`, each with zero warnings, errors, or information messages. Symbols were included;
  **Manage version and build number** and **TestFlight Internal Testing Only** were off. Processing
  reached **Ready to Submit** by `03:24:21Z`; the record shows exact `1.0.0 (5)`, bundle
  `com.tth.Wardrobe`, SDK `23F81a`, arm64 iPhone support, iOS 18.0 minimum, included symbols, no
  non-exempt encryption, production App Attest, `get-task-allow = false`, and beta reporting active.
  The build lists exactly the `Family` Internal Testing group with one tester and no individual
  testers, and the build-specific What to Test wording reproduced in the runbook is saved. The
  exact-v8 post-distribution review ran from `03:19:20Z` through `03:30:33Z` and passed. Build 5 is
  consumed, but distribution is not physical, lifecycle-marker, deletion, or snapshot proof.

- [x] Validate, upload, process, and internally assign only the verified build-6 archive using the
  normal **TestFlight & App Store**-eligible route, then save truthful build-6 What to Test wording.
  `Wardrobe-1.0.0-6-de7c540-appstore.xcarchive` passed strict signing, production App Attest,
  privacy, public-configuration, credential-absence, and Gmail-free verification. Xcode validation
  and upload succeeded with symbols on, automatic version/build management off, and **TestFlight
  Internal Testing Only** off. Processing reached **Ready to Submit**; the record shows `1.0.0 (6)`,
  arm64 iPhone support, iOS 18.0 minimum, included symbols, and no non-exempt encryption. Exactly
  `Family` is assigned with one group tester, no individual testers, and saved truthful tester notes.

- [x] Complete build-7 internal distribution with AI disabled. The
  [canonical record](internal-testflight-runbook.md#build-7-distribution--2026-09-10) verifies
  normal-route validation/upload, **Complete / Ready to Submit**, only `Family` with one group
  tester and no individual testers, and saved/reloaded notes. The existing automatic Xcode
  distribution setting was preserved. Physical installation and QA are not completed by delivery.

- [x] Upload exactly the verified archive; wait for processing and resolve any compliance prompts.
  Build `1.0.0 (4)` completed processing by `2026-08-21T08:20:20Z` with no unresolved prompt.
- [x] Select the processed build and re-check its device requirements and displayed metadata. The
  processed record shows the expected version/build and bundle, arm64 iPhone support, minimum iOS
  18.0, included symbols, no non-exempt encryption, and production App Attest entitlement.
- [x] For the internal QA phase, add the processed build only to the intended Internal Testing
  group and enter truthful What to Test notes. Build 4 is in the `Family` group and the saved
  truthful wording reproduced in the runbook was saved on 2026-08-21. Build 5's separate
  distribution evidence is retained above; its clean physical-device evidence is partial and
  ended at the notification-tap crash described in section 4. Build 6 is also assigned only to
  `Family`; its later clean physical evidence through the fixed notification route is retained in
  the runbook.
- [x] Add version `1.0.0` with build 7 to a draft review submission. Add for Review validation
  passed; Apple shows Ready for Review with manual release retained.
- [x] Complete the full post-change operations review. The v14 review at `2026-09-12T07:09:37Z`
  completed with the approved Cowork-only exception; every other operational check passed.
  See the [final review record](internal-testflight-runbook.md#final-v14-operations-review--12-september-2026).
- [ ] Obtain the owner's final submission decision and retain the reviewed draft settings, then
  choose **Submit for Review** if approved. It has not been clicked:
  [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
- [ ] Keep the production backend healthy and the review contact reachable during review; respond
  to App Review in the App Review section.
- [ ] After approval, execute the chosen release method, verify the live product page/install, and
  retain the final evidence and support handoff.
