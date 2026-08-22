# App distribution, polish, and feature backlog

This is the implementation source of truth for turning the current personal TestFlight build
into a public App Store product. It deliberately separates work we can complete in this
repository from Apple Developer, Fly.io, and App Store Connect work that needs an external account
or verified production fact. The earlier Google-specific sequence is historical/deferred and is
not a public-v1 gate. Every beta follows the
[`internal TestFlight, always App-Store-ready`](app-store/internal-testflight-runbook.md) runbook:
the tester group is internal, but the archive and upload remain eligible for later App Review.

Statuses:

- **Now** — part of the current implementation tranche.
- **Done** — implemented, focused-tested, and included in a complete regression on this branch.
- **In progress** — a safe foundation is committed, but one or more acceptance details remain.
- **External gate** — repository work is specified here, but Apple Developer, Fly.io, policy, or
  release facts must be completed and evidenced before the item can close.
- **Submission** — repository assets/checks can be prepared now; the final action happens in
  App Store Connect.
- **Enhancement** — product improvement that is valuable but does not by itself unblock review.

## Progress snapshot

Last updated: **2026-08-22**. This table is authoritative when an item's original scope label
below still says “Now.” “Done” means the whole item is complete; partial work is deliberately
kept “In progress.”

| Items | Status | Verified branch outcome |
|---|---|---|
| APP-001–APP-008, APP-010 | **Historical / done** | Completed earlier Gmail-capable implementation work remains valuable history, but APP-036 supersedes its Gmail/OAuth/receipt-import release scope. Preserve applicable security/deletion guarantees while using the separately approved clean-uninstall transition |
| APP-009 | **External gate** | Repository enforcement, exact reviewed Gmail-free v8, manual reviews, an isolated read-only restore rehearsal, and historical build-4 Apple/partial physical evidence are retained. Production registration/assertion success-marker observation, build-5 repeat proof, snapshot-list expiry, deletion-specific recovery, and verified server deletion remain open |
| APP-011 | **Done** | Product identity, Debug/Release split, Gmail-free Release configuration, public URLs, Team ID, and simulator guards remain implemented. The uploaded build-4 archive is retained as history; the exact build-5 production-signed archive passed profile, entitlement, identity, and public-configuration verification |
| APP-012 | **Done** | Dependency/privacy-manifest and removed-capability enforcement remains implemented. The build-5 signed archive passed the privacy-manifest and Gmail-free absence guards plus a separate non-emitting credential scan |
| APP-013 | **Done** | The deterministic offline tour now uses fictional manual/photo data, never opens the production store, and never calls connected AI; its Today/History/catalog flow passed UI automation |
| APP-014 | **In progress** | Build-4 physical QA is partial: clean install, production App Attest, cold renewal, offline/local/demo, manual/edit, open/cancel pickers, reminder scheduling, and wear/history were exercised, but a failed Restyle hid the cached look. Build 5 must repeat the full matrix and close all untested actions |
| APP-015 | **Done** | CI/release gates remain implemented. Current build-5 local pre-archive evidence is green: 221 backend tests plus locked audit/Bandit/Ruff/mypy, 218 Swift unit tests, all 9 UI flows, 43 release-script tests, Release simulator/artifact checks, and a synthetic stored-property/encoded-key request guard |
| APP-016 | **In progress** | The owned-domain Gmail-free privacy/support/Terms pages are published and anonymously verified. Current provider terms, App Privacy reconciliation, and final App Store Connect answers remain open |
| APP-017–APP-019 | **Submission / later milestone** | Historical `1.0.0 (4)` passed production review, unused-build check, validation, upload, processing, and internal distribution with truthful tester wording. The new `1.0.0 (5)` signed archive is strictly verified but has not been Organizer-validated, uploaded, processed, or assigned |
| APP-020–APP-022 | **Historical / partial carry-forward** | Manual add/edit, favorites, archive, filters, and catalog polish carry forward. Imported-item/review/account-scope behavior is historical and is removed through APP-036's owner-approved clean reset |
| APP-023 | **In progress** | Today is explicit-action-only and the cache survives offline relaunch, but build-4 physical QA found that failed Restyle replaces the usable cached look with an error until relaunch/tap. The repository fix passed local regression and needs build-5 physical verification |
| APP-024–APP-028 | **Done / pending** | Outfit History, local insights, 1–5 feedback, preference-aware styling, accessibility-size layouts, friendly bounded states, and branded launch/first-run are done; broader localization remains APP-028 |
| APP-029–APP-035 | **Deferred / pending** | Receipt extraction and Gmail History work (APP-029/030) are deferred beyond public v1. Insights, backup, imagery, localization, and widgets remain independent future enhancements |
| APP-036 | **In progress** | Gmail/Google/OAuth/receipt import remains removed from the repository and signed build-5 archive. The old development build is disconnected/cleared/uninstalled; build 4 was cleanly installed from TestFlight and supplied partial proof. Build-5 physical proof and final Google retirement remain open |

Pre-APP-036 build-4 policy-enforcement baseline: **455 iOS tests** total (**443 Swift tests plus 12
end-to-end UI tests**), **237 backend tests**, locked dependency audit with no known vulnerabilities,
Bandit, Ruff, mypy, and **23/23** release-script tests all passed.

Historical post-APP-036 proof on clean source `dd3d99061321cf91bdce166e7da579b84edb07e8`:
**209 unique iOS tests** passed (**200 Swift tests plus all 9 UI flows**), **202 backend tests**
passed, the locked dependency audit found no known vulnerability, Bandit/Ruff/mypy passed, and
**31/31** release-script tests passed. A clean Release simulator artifact for `1.0.0 (4)` passed
public configuration, plist, signature, dependency, and removed-capability checks. At
`2026-08-21T03:34:13Z`, Xcode 26.6 with the iOS 26.5 SDK created the arm64 Apple Distribution
archive for that build. The strict archive verifier confirmed the scalar production App Attest
entitlement, matching App Store distribution profile, public configuration, app privacy manifest,
and absence of shared-bearer, Google/Gmail/OAuth, `/extract`, and receipt-background artifacts.
Live App Store Connect immediately before that archive showed build 3 as the highest upload. This
evidence is retained as history, but the archive was superseded when the subsequent code-review
work changed shipped Swift and backend source. It is not eligible for validation or upload.
Replacement source and backend-deployment evidence are recorded below. At
`2026-08-21T06:34:50Z`, App Store Connect still listed builds 1–3 only, so build 4 remained unused.
Clean synchronized source `24c17cb9fe643035f9206ee61e2935e086902146`, a documentation-only
successor to shipped-code merge `d4637f4b2adf14cd533594aec6060c385f8a5e2b`, then passed 219
backend tests, 215 Swift tests, all 9 UI flows, 43 release-script tests, and the clean Release
simulator/artifact gates. Xcode 26.6 with the iOS 26.5 SDK created and strictly verified the
replacement archive at `2026-08-21T06:36:33Z`:
`ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`. The final
payload-free review and build-list refresh passed at `2026-08-21T08:12:46Z`; Xcode validated the
exact archive at 08:16Z and uploaded it through the normal App Store Connect route at 08:18Z.
Apple processing completed by `2026-08-21T08:20:20Z`; the processed build includes symbols, shows
the expected arm64/iPhone/iOS 18.0 metadata and production App Attest entitlement, and is assigned
to the `Family` Internal Testing group with the saved truthful What to Test wording reproduced in
the runbook. Physical TestFlight proof is partial and cannot satisfy build 5.

Build-4 physical QA on 2026-08-21 is historical and **PARTIAL**. A clean TestFlight install on an
iPhone 16 Pro running iOS 26.6 took the production installation aggregate from 0 to 1. First
assertion/protected calls and cold renewal succeeded; online recovery showed `Styled 17:24`, with
assertions 1→2 and the current recommendation-installation window 0→1. Runtime category/build
fields were absent as expected. Offline remote styling failed closed while Wardrobe, History, and
Demo remained usable. The daily cache survived offline relaunch, but a failed **Restyle** hid the
cached look until another relaunch/tap, which is a release defect. Manual add/edit, picker
open/cancel, Demo, reminder permission/scheduling, and Wear/History were exercised; successful
media selection, notification delivery, consent withdrawal, local/server deletion, and the rest of
the full matrix remain open. The latest listed 14-day snapshot at `2026-08-21T07:32:23Z` predates
enrollment, so server deletion/reinstall is paused pending eligible snapshot recovery evidence.
Only aggregate counts, times, and outcomes are retained; no payloads, identifiers, or secrets.

The current production baseline is Fly release v8, completed at `2026-08-21T10:45:06Z`. It serves
reviewed PR #23 source `4a75b99dcd49e818ad1d5b198e8c49abba702e18` as a `linux/amd64`
image at immutable registry digest
`sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
The fresh no-cache local image ID is
`sha256:3eb95304cb6e97976d2aa8b18dce302a3a908cf1d565b13d511c3fc2ed9d7c84`;
local and re-resolved registry scans each covered 90 packages and found zero critical/high
vulnerabilities. UID 10001, no-new-privileges, mounted-volume, and targeted-logging container smoke
checks passed. The running source label, digest, and architecture match; one healthy Singapore
Machine runs with `min_machines_running = 1`, the required secrets are deployed without retaining
their values, and production App Attest uses category `2` with bundle builds `4,5`. The encrypted
1 GB volume is in the below-warning usage band; schema v4 integrity is `ok` with zero foreign-key
errors, one installation, zero sessions, and zero challenges. All listed snapshots are created; the
newest is `2026-08-21T07:32:23Z`, and the retention setting remains 14 days. The live process is one
UID-10001 Uvicorn worker with application `INFO` enabled only for the non-propagating
`app.auth.service` logger and access logging off. Production health returns `200`, `/extract`
returns `404`, unauthenticated `/recommend` returns `401`, and the OpenAPI route set matches the
reviewed source.

Former v7 digest `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
remains the immediate rollback, and Gmail-free v6 digest
`sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
remains the required recovery baseline; both freshly re-resolved and scanned across 90 packages
with zero critical/high vulnerabilities. Both are operational recovery only: using either reopens
the exact-candidate deployment, configuration, and manual-review gates and blocks build-5 archive/
QA until v8 is restored and reverified. Emergency pre-build-4 rollback digest
`sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17` is
App-Attest-only and scan-clean, but using it would re-expose `/extract` and must halt the release.
The payload-free v8 post-change review passed at `2026-08-21T11:09:20Z`: the two-day HTTP view had
only `401`/`404` and no 5xx series; the bounded ten-minute view had no auth-rejection/rate-limit,
Anthropic/stylist, maintenance, unhandled, malformed-lifecycle, or access-log event. Anthropic
status, configured-limit, below-80%-of-limit, expected deployed Wardrobe key/Opus 4.8, and
no-saturation checks passed, as did the published support pages, contact/response target, and
retained routing rehearsal. The bounded stream contained zero `registration_succeeded`,
`assertion_succeeded`, or `installation_deleted` events because none was exercised after v8
deployment; real production marker observation therefore remains open. Protected `/recommend`
success intentionally has no developer event and remains aggregate/client-evidenced.

## Immediate next milestone — internal TestFlight candidate

App Store Connect showed build 4 as the highest upload and build 5 unused at
`2026-08-22T01:09:39Z`. The exact `1.0.0 (5)` production-signed archive is strictly verified but
has not been Organizer-validated, uploaded, processed, or assigned. These current gates are
ordered:

- [x] **Freeze the current fixes.** Reviewed PR #23 merged the Today offline-cache fix and
  focused tests, the payload-free production registration/assertion success-marker logging fix,
  and source TestFlight allowlist for builds `4,5` at `2026-08-21T10:29:56Z`. The frozen shipped-
  code/backend source was `4a75b99dcd49e818ad1d5b198e8c49abba702e18`; later docs-only
  evidence does not change the deployed image or iOS bundle.
- [x] **Retain local pre-archive regression evidence.** The mandatory backend gate passed 221 pytest
  cases plus the locked dependency audit, Bandit, Ruff, and mypy. The regenerated build-5 project
  passed 218 Swift unit tests and all 9 UI flows. All 43 release-script tests and the Release
  simulator/artifact checks passed. This is local evidence, not signed-archive or distribution proof;
  rerun any affected gate if source/configuration changes before archive.
- [x] **Build, scan, deploy, configure, and review the backend candidate.** Fly v8 serves exact PR
  #23 source and immutable digest
  `sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
  The local and registry scans, runtime/storage/route/configuration checks, `4,5` allowlist, targeted
  INFO logger, retained rollback/recovery checks, and the `2026-08-21T11:09:20Z` payload-free
  post-change review passed. This closes deployment/configuration review only.
- [x] **Recheck App Store Connect, archive, and strictly verify build 5.** The final archive-time
  refresh at `2026-08-22T01:09:39Z` showed builds 1–4 only, with build 4 highest and build 5
  unused. Fresh private-registry authentication re-resolved the exact Gmail-free v6 recovery
  digest and its zero-critical/high scan completed at `2026-08-22T01:00:09Z`; the exact-v8
  payload-free pre-archive review passed at `2026-08-22T01:07:45Z`. Clean source context
  `695c562b7b18e4a0b7f8a72b814af59efdd0cf3a`, a documentation-only successor to frozen
  shipped-code/backend source
  `4a75b99dcd49e818ad1d5b198e8c49abba702e18`, produced
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-5-695c562-appstore.xcarchive` at
  `2026-08-22T01:10:32Z`. Xcode 26.6 (`17F113`) with the iOS 26.5 SDK created the arm64,
  minimum-iOS-18.0 `1.0.0 (5)` app for `com.tth.Wardrobe`. The Apple Distribution signature and
  App Store profile `Wardrobe App Store App Attest 2026-08-21`
  (`2b11bc90-0194-4fe6-8dcc-413c6dc5ccd2`, expires `2027-08-21T02:07:47Z`) matched the App ID
  prefix, team, bundle, and certificate; `get-task-allow` is false, beta reporting is active, the
  profile grants production App Attest, and the signed entitlement is scalar `production`. The
  strict verifier completed at `2026-08-22T01:11:17Z` with the public URLs, privacy manifest, and
  Gmail-free/shared-bearer absence guards passing. A separate non-emitting scan of credential and
  removed-capability markers passed at `2026-08-22T01:12:01Z`, and post-scan deep signature verification
  passed at `2026-08-22T01:12:19Z`. App and dSYM UUIDs match at
  `DA20FD8D-64C3-3B7A-9990-19EAF050AF04` (arm64); executable SHA-256 is
  `a9f01231025874d331e76be40ebe6f493b3f36051902b66b0ad03c35206bb3b9`.
- [x] **Retain exact synthetic `/recommend` request-capture evidence.** The tests-only boundary
  inventories every stored property on the three Swift request types, including nil optionals, and
  separately pins the encoded top-level keys (`items`, `recently_worn_ids`, `item_preferences`,
  `occasion`), catalog-item keys (`id`, `name`, `category`, `brand`, `colors`, `material`), and
  preference keys (`id`, `average_rating`, `rating_count`). The shared schema/backend reject extra
  fields. The strengthened focused `RecommendClientTests` suite passed 12/12 at
  `2026-08-22T01:59:08Z` on an iPhone 17/iOS 26.5 simulator. After this tests-only change, the
  mandatory backend gate passed 221 tests plus audit/Bandit/Ruff/mypy, and one uninterrupted full
  iOS run passed 218 Swift unit tests plus all 9 UI tests (227/227 canonical cases), whose result
  bundle finalized at `2026-08-22T02:04:17Z`, with no failures, skips, or retries. Only field names
  and synthetic values were inspected; no production wardrobe, prompt, model response, token, or
  identifier was retained. This tests-only evidence does not alter the signed iOS bundle or require
  another TestFlight build.
- [ ] **Validate, upload, process, and internally assign build 5.** Immediately beforehand,
  refresh App Store Connect again and repeat the payload-free review against exact Fly v8. Use the
  normal **TestFlight & App Store** route and save truthful build-5 tester wording.
- [ ] **Complete the build-4 identity-safe handoff before uninstall.** Preserve the remaining local
  evidence, withdraw styling consent and disable reminders, wait for an eligible automatic snapshot
  created after build-4 enrollment, then use build 4's **Delete Server Security Data** control and
  confirm the production aggregate returns to zero. Complete separate local deletion only after its
  evidence is no longer needed. Stop on any ambiguous result; uninstall build 4 only after every
  preceding check passes.
- [ ] **Repeat the complete clean physical QA matrix on build 5.** Close every build-4 gap, observe
  real bounded `registration_succeeded`/`assertion_succeeded` production events without payloads or
  identifiers, and verify the Today cache remains usable across failed Restyle/recovery. Then
  complete build-5 deletion/reinstall, snapshot-specific recovery/expiry, and final Google-
  retirement gates. The zero-event post-deploy query did not close this gate.

Do not archive early and plan to repair the same binary later. The checked sequence below records
the historical build-4 path and does not close any build-5 gate.

- [x] **Publish the candidate source.** PR #7 merged the reviewed `codex/app-store-readiness`
  scope to `main` at `f2a02825fd4178478bfc130525463165f12d648c`.
- [x] **Implement the repository portion of APP-009.** Anonymous per-installation App Attest
  enrollment and short-lived sessions now replace `BackendDeviceToken`; the backend verifies
  attestations/assertions, persists only auth/security metadata, rejects replay, applies bounded
  quotas, and retains only a time-bounded legacy bridge for deployment migration. APP-036 now
  removes the separate Google/Gmail product capability from public v1.
- [x] **Complete the APP-009 development, infrastructure, and legacy-retirement gates.** App
  Attest is enabled with prefix `29NT767Y9P`; physical development enrollment/renewal passed;
  production Fly is App-Attest-only on one encrypted volume; restart and snapshot restore passed;
  and the retired shared credential returns `401`.
- [x] **Adopt the APP-009 data-lifecycle and logging policy.** The approved limits, prohibited log
  fields, deletion/restore behavior, manual operations requirements, verified controls, and open
  compliance gaps are recorded in
  [`app-attest-data-lifecycle-policy.md`](app-store/app-attest-data-lifecycle-policy.md).
- [x] **Enforce the repository-owned APP-009 lifecycle policy.** A one-minute maintenance loop on
  the configured minimum-one-Machine topology performs deadline cleanup, repeats bounded
  transactions until drained, purges inactive/revoked installations at 90/30 days, and safely
  checkpoints/truncates SQLite WAL state. A fresh App Attest assertion deletes the proven
  installation through the new in-app server-security-data control. Structural review guardrails
  cover the current persistence/logging boundaries, and a tested production command keeps Uvicorn
  access logs disabled.
- [x] **Build, scan, and deploy the policy-enforced backend.** On 2026-08-19, Fly release v5
  deployed immutable digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  from source `7b6acb83960e2cd69458489ab5f5fe0e04cd9f85`. The exact `linux/amd64`
  image passed local and registry high/critical scans across 90 packages; the live schema is v4
  with SQLite integrity `ok`, the encrypted volume remains attached, the Machine is healthy, and
  `min_machines_running = 1`. Rollback digest
  `sha256:f4758e08046e187161b992ad34530c3c41c89375c9277522015628ec9306eef1`
  was restored to the private registry, re-scanned, and passed an isolated v3/v4 round-trip.
- [x] **Implement APP-036's repository and simulator-artifact cut.** Google Sign-In and client/
  callback configuration, Gmail/receipt-import UI and client paths, receipt background work, and
  active `/extract` route/client capability are absent from the candidate and verified Release
  simulator artifact. Intentional negative guards and legacy-rate cleanup remain. Build 4 used the
  approved fresh local schema. The full backend and iOS regressions and release-script suite passed
  for that historical source; rerun them for the merged review-fix candidate.
- [x] **Configure the simulator portion of APP-011.** Gitignored `Distribution.xcconfig` contains
  only the HTTPS backend, live public links, and Team ID; resolved Release settings and the clean
  simulator artifact prove Google/Gmail/receipt-import configuration is absent.
- [x] **Retain the candidate-metadata checks.** Live App Store Connect inspection before the
  superseded archive found build 3 as the highest uploaded build. The replacement archive-time
  check at `2026-08-21T06:34:50Z` and final pre-validation check at
  `2026-08-21T08:12:46Z` again showed builds 1-3 only, so `1.0.0 (4)` and the App Attest build
  allowlist correctly remained at 4. Build 4 has since uploaded and must never be reused. A later
  final archive-time refresh at `2026-08-22T01:09:39Z` showed builds 1–4 only, so build 5 was
  unused. Its signed archive is now strictly verified; another immediate refresh remains required
  before Organizer validation/upload.
- [x] **Freeze and publish the Gmail-free candidate source.** PR #14 merged at
  `9a48caebdec67ac26673c3ba51546a5e7edcf0cc`; the remote feature branch was deleted and local
  `main` was synchronized to the same `origin/main` SHA by fast-forward before the release image
  was built.
- [x] **Complete APP-036's pre-upload production cutover.** The installed intermediate
  development build `0.1.0 (4)` completed Google disconnection and local deletion, but predated
  the server-deletion UI. A read-only production check found zero installations, sessions, and
  pending challenges, so no live production identity existed to delete; the app was then
  uninstalled. Exact source `9a48caebdec67ac26673c3ba51546a5e7edcf0cc` now runs as immutable
  `linux/amd64` digest `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`.
  Local and registry scans found zero critical/high vulnerabilities across 90 packages; the
  restored v5 emergency rollback digest `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  resolved after fresh private-registry authentication at `2026-08-21T01:20:25Z`, re-scanned clean,
  and passed an isolated old/new/old schema-v4 rehearsal. Release v6 was healthy as the cutover
  baseline, production `/extract` returned `404`, unauthenticated `/recommend` returned `401`, and
  the payload-free post-deploy manual review passed at `2026-08-21T01:11:43Z`. Build 4 was later
  installed only from processed TestFlight and only after the older app was removed.
- [x] **Close the publication portion of APP-016.** `tzehon.github.io` PR #5 merged the Gmail-free
  privacy/support/Terms copy as `c5da090a0417bcda99fc6d328a0cdff808ea597d` at
  `2026-08-21T01:42:01Z`; the matching Pages deployment completed successfully at
  `2026-08-21T01:42:39Z`. Anonymous HTTPS requests at `2026-08-21T01:45:27Z` returned `200` for all
  three owned-domain routes, showed the 21 August 2026 policy/Terms date, linked the pages to each
  other, and contained no Gmail/Google/OAuth/import capability claim. Provider-contract evidence,
  App Privacy reconciliation, and final App Store Connect answers remain separate APP-016 work.
- [x] **Retain the superseded APP-011 signed-archive history.** Live App Store Connect still showed build
  3 as the highest upload. After the v6 Gmail-free recovery digest resolved under fresh private-
  registry authentication and the payload-free manual review passed, clean source
  `dd3d99061321cf91bdce166e7da579b84edb07e8` produced the Apple Distribution archive for
  `1.0.0 (4)` at `2026-08-21T03:34:13Z`. The strict verifier passed the signed scalar production
  App Attest entitlement, matching App Store distribution profile, HTTPS public configuration,
  app privacy manifest, and removed-capability absence. Subsequent review-fix work changes shipped
  Swift and backend source, so this archive is historical and must not be validated or uploaded:
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-dd3d990-appstore.xcarchive`. The earlier
  automatic-signing archive `Wardrobe-1.0.0-4-dd3d990.xcarchive` used a development profile, failed
  verification, and is not eligible for validation or upload.
- [x] **Merge and freeze the review fixes.** PR #19 rebase-merged the reviewed Swift, backend,
  contract, release-verifier, and focused-test changes. The remote branch was deleted and clean
  synchronized `main` was `d4637f4b2adf14cd533594aec6060c385f8a5e2b` at that historical gate.
- [x] **Build, scan, and deploy the exact reviewed backend.** The exact frozen `linux/amd64` image
  passed local and immutable-registry critical/high scans across 90 packages and was deployed only
  by immutable digest `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
  as Fly release v7. Health, auth-store integrity, production configuration, encrypted storage,
  snapshot policy, and Gmail-free route behavior passed, followed by the payload-free review at
  `2026-08-21T06:00:21Z`.
- [x] **Run the clean Release regression and replace APP-011/APP-012 archive proof.** App Store
  Connect showed builds 1–3 only at `2026-08-21T06:34:50Z`, so `1.0.0 (4)` remained unused. Clean
  source context `24c17cb9fe643035f9206ee61e2935e086902146` passed 219 backend tests, 215 Swift
  tests, all 9 UI flows, 43 release-script tests, the locked audit/security/type gates, and clean
  Release/public-config/privacy/removed-capability verification. Xcode 26.6 with the iOS 26.5 SDK
  created the arm64 Apple Distribution archive at `2026-08-21T06:36:33Z`:
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`. The strict
  verifier passed the matching App Store profile and signing certificate, scalar production App
  Attest, HTTPS public configuration, app privacy manifest, and Gmail-free artifact guards. A
  separate targeted scan of the signed app found no Anthropic/API-key, shared-bearer, or private-
  key credential marker, and separate `dwarfdump --uuid` output matched the arm64 app and dSYM at
  `5BA1F06E-7458-32A4-890F-36C8F22D9C13`.
- [x] **Repeat the pre-upload review, then validate and upload only the replacement archive.** At
  `2026-08-21T08:12:46Z`, the payload-free review passed against exact Fly v7 and the immediately
  refreshed App Store Connect list still contained only builds 1-3. Xcode validated only
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive` at 08:16Z and
  uploaded it through the normal **TestFlight & App Store**-eligible App Store Connect route at
  08:18Z. Apple processing completed by `2026-08-21T08:20:20Z`; the expected processed metadata,
  included symbols, `Family` Internal Testing group, and the saved truthful What to Test wording
  reproduced in the runbook were verified.
  Neither superseded `dd3d990` archive was validated or uploaded. Build 4 is now used and must never
  be reused.
- [ ] **Complete post-upload APP-009/APP-036 proof and cleanup.** Retain build 4's historical partial
  clean-install and production enrollment/assertion/protected-API evidence, then repeat the full
  matrix from processed build 5 after its backend markers are deployed and verified. Prove
  deletion-specific recovery and eligible 14-day snapshot-list disappearance. After build 5 is
  proven and with a separate final owner
  confirmation, retire only the inventoried Wardrobe Google Cloud/OAuth projects; do not touch
  unrelated projects.

Using an internal tester group does not relax the binary standard. **TestFlight Internal Only** is
not used because Apple prevents that artifact from being submitted to customers later.

## P0 — privacy, security, and trustworthy data handling

APP-001 through APP-008 below record the completed Gmail-capable implementation. APP-036
supersedes their Gmail/OAuth/receipt-import product scope for public v1. Keep the entries as
historical evidence; applicable privacy and deletion lessons remain, while the active candidate is
governed by APP-036's Gmail-free guards.

- [x] **APP-001 · Done · Make the core app local-first.** Gmail connection must be optional.
  A user—and App Review—can add photos, browse the catalog, and understand the product without
  granting mailbox access. Replace the current sign-in gate with a clear tab shell, onboarding,
  and an optional “Connect Gmail” path.
- [x] **APP-002 · Done · Add versioned, affirmative AI/data-use consent.** Immediately before any
  receipt or wardrobe data is sent, explain the on-device selection, developer backend,
  Anthropic processing, exact data categories and purposes. Gate manual sync, styling, and
  background work; restored sessions do not inherit a notice they never accepted. Consent is
  revocable and scoped to the connected account where possible.
- [x] **APP-003 · Done · Add a Privacy & Data center.** Keep Sign out, Disconnect Gmail/revoke,
  Withdraw AI consent, and Delete Local Data distinct. Show the connected account, sync and
  reminder controls, data flow, policy/support links, and destructive confirmations. A delete
  operation must cancel work and verify completion before reporting success.
- [x] **APP-004 · Done · Stop automatic background and notification enrollment.** Both are off by
  default and user-controlled. Disabling, disconnecting, withdrawing consent, or deleting data
  cancels pending work. Background execution re-checks sign-in, consent, and opt-in before a
  Gmail or backend call. Notification copy must not claim an outfit already exists; allow a
  reminder time and route the tap to Today.
- [x] **APP-005 · Done · Revalidate restored Gmail authorization.** A restored Google session is
  usable only if `gmail.readonly` remains granted. Map SDK/network failures to friendly recovery
  states and keep the one-scope, GET-only guard intact. Use the official Google sign-in control
  and label the action as an optional Gmail connection.
- [x] **APP-006 · Done · Make persistence failures visible and recoverable.** Replace user-facing
  `try?` save/delete paths with throwing operations, rollback, alerts, and no false success or
  dismissal. Replace launch-time `fatalError` with a recoverable store error screen. Define a
  versioned SwiftData migration plan before evolving persisted models.
- [x] **APP-007 · Done · Prevent cross-account catalog mixing.** Gmail-derived records, sync
  history, preferences, and consent must have an explicit stable owner. Account A must never see
  account B's data. Existing unscoped data requires an explicit migrate-or-delete choice; it is
  never silently assigned. Local photo items may remain in a clearly identified device-local
  wardrobe if that is the chosen product model.
- [x] **APP-008 · Done · Minimize and deduplicate receipt transmission.** Use structured JSON-LD
  before raw text; select only product-relevant lines; redact obvious email, phone, card,
  shipping, address, and order identifiers; send a sender domain instead of a full address; and
  never expose a Gmail message ID to the model. Exclude Spam and Trash by default. Persist
  per-account processed IDs/history state so background runs do not retransmit the same mail.
- [ ] **APP-009 · External gate · Replace the shared bearer with App Attest-backed anonymous
  sessions.** A token in `Info.plist` is extractable even if copied to Keychain. The chosen
  identity is one Apple-certified app installation, not a human account; reinstall, migration, or
  restore starts a new Wardrobe backend identity. Complete all of the following before marking
  this item done:
  - Enroll an App Attest Secure Enclave key from a fresh, single-use server challenge; verify the
    Apple certificate chain, nonce, exact registered App ID prefix + `com.tth.Wardrobe`, key ID,
    environment, and zero attestation counter. On iOS 27+, require and allowlist Apple's signed
    validation-category and bundle-build extensions; accept their signed absence on iOS 18–26.
    Persist only the verified public key, the opaque Apple receipt carried by that successful
    attestation, anonymous installation ID, and security metadata. Do not describe the receipt
    itself as verified until its Apple receipt validation/risk-metric policy is implemented and
    evidenced.
  - Renew short-lived backend sessions with assertions over canonical client data and a fresh
    challenge. Consume challenges exactly once and advance each assertion counter atomically.
    Apply bounded enrollment/session/API rate limits, quotas, manual operational review, and
    negative tests.
  - Keep local wardrobe and Demo Mode working when App Attest is unavailable or verification is
    offline; remote AI must fail closed with clear recovery. Never trust a client-declared
    unsupported state as permission to mint an unauthenticated session.
  - Enable App Attest on the explicit Apple App ID, confirm the real App ID prefix instead of
    assuming it equals the Team ID, regenerate provisioning profiles, and inspect the archive's
    entitlement. Test sandbox enrollment on a development-signed physical iPhone and production
    category `2` through TestFlight; reserve category `4` for App Store builds. Simulator fakes do
    not clear this gate.
  - Provision durable, private Fly auth storage before enabling the new flow. Record the SQLite
    volume or shared-database topology, atomicity, backup/snapshot behavior, retention/deletion
    criteria, and restore rehearsal. Scan the exact release image (OS and language packages) for
    high/critical known vulnerabilities and retain the report with its digest. Receipt text and
    wardrobe payloads must never enter the auth store.
  - Enforce and evidence the approved
    [App Attest data lifecycle and logging policy](app-store/app-attest-data-lifecycle-policy.md):
    deadline cleanup, inactive/revoked installation deletion, assertion-verified in-app deletion,
    no application access logs, bounded sanitized security logs, 14-day snapshot listing,
    restore-after-deletion handling, payload-free manual operations, and monitored support routing.
  - Use a time-bounded bridge deployment only if needed to move existing testers. Record its
    expiry, then deploy App-Attest-only auth, unset/rotate `DEVICE_TOKEN`, prove an old build is
    rejected, retain a validated App-Attest-only rollback image, and record commit/image,
    categories/build allowlist, tester OS/runtime-field presence, volume, tests, and physical-device
    evidence. Build/category rejection is enforceable only when iOS 27+ supplies those signed fields;
    the pre-App-Attest shared-token build must be rejected on every OS. After APP-036, the retained
    recovery image must also be Gmail-free; the former v5 image is only a release-halting abort
    before build 4 distribution because it restores `/extract`.
  No public build is releasable with the shared bearer or an in-memory-only production auth store.
- [x] **APP-010 · Done · Restrict remote images.** Do not load arbitrary model-derived URLs. Apply
  HTTPS-only validation, a conservative host policy, bounded image decoding/caching, and a safe
  placeholder.

## P0 — release and App Review readiness

- [x] **APP-011 · Done · Align product identity and release configuration.** Use “Wardrobe
  Stylist” consistently in the app, help text, public pages, and store copy. Split development and
  production configuration. A Release archive must fail if required HTTPS endpoints, policy/
  support URLs, or Apple signing identifiers are absent; it must also prove no shared backend
  credential, Google Sign-In SDK/client configuration, Gmail permission/route, receipt-import
  client path, or receipt background task is embedded. The Apple Team/App ID capability, App
  Attest entitlement, backend URL, and accepted release build must match the deployment/archive.
  The `dd3d990` archive is retained only as superseded historical evidence. The uploaded build-4
  archive `Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive` is also historical. The new verified
  build-5 archive is retained above; Organizer validation/upload remain separate gates.
- [x] **APP-012 · Done · Pin/audit dependencies and archive privacy metadata.** Historical
  work pinned and audited Google Sign-In. For the Gmail-free candidate, remove that SDK and its
  transitive bundles, keep only actually integrated dependencies/privacy manifests, and make the
  artifact verifier fail if Google/AppAuth/GTM components remain. Rerun dependency, privacy-
  manifest, and removed-capability verification against the replacement Release artifact and
  signed archive before release. The repository task remains complete: build-5 Release simulator/
  artifact checks and the exact per-build signed-archive verification pass.
- [x] **APP-013 · Done · Give App Review a deterministic product tour.** Keep the seeded, offline demo
  mode or equivalent UI-test fixture that exercises Today, wardrobe browsing, item editing, and
  data controls without personal data or an account. Replace the synthetic pending import with
  fictional manual/photo data. It is visually distinct from real data, never calls the backend,
  and its catalog, Today, History, editing, deletion, relaunch, and offline behavior pass UI
  automation.
- [ ] **APP-014 · In progress · Add end-to-end UI coverage.** Preserve first launch, styling
  disclosure/consent, demo entry, manual/photo add/edit/delete, catalog search/filter, Today/
  History, reminder controls, local deletion, server-security deletion, and offline/relaunch
  coverage. Add mandatory clean-uninstall/fresh-install plus signed-artifact/network absence checks
  for Google/Gmail/receipt import.
- [x] **APP-015 · Done · Strengthen CI/release gates.** Run backend contract tests when `shared/**`
  changes; build/test a Release configuration; run an archive/privacy report guard; and retain
  full locked pytest/pip-audit/Bandit/Ruff/mypy plus Swift test regressions. The clean complete
  historical build-4 regression and artifact/archive verification are recorded above. Current
  build-5 local pre-archive evidence is also green: 221 backend tests plus all mandatory analysis/
  security gates, 218 Swift unit tests, all 9 UI flows, 43 release-script tests, and Release
  simulator/artifact checks. Its signed-archive evidence is retained separately above; this remains
  a per-build gate for future candidates.
- [ ] **APP-016 · In progress · Prepare accurate public-facing documents.** The live
  privacy/support/Terms pages now describe the Gmail-free candidate and omit Google/Gmail/Limited
  Use/receipt-import claims. Finish reconciling current Anthropic, Apple, and Fly terms, purposes,
  retention, App Privacy answers, and final store fields. Do not publish unverified retention or
  “no training” claims.
- [ ] **APP-017 · Submission · Complete the App Store Connect record.** Final name/bundle ID/SKU,
  category, content rights, age rating, DSA status, privacy nutrition labels, support/privacy
  URLs, description, keywords, copyright, review contact, review notes, build, pricing/tax,
  availability, export compliance, release method, agreements, and any EU trader information.
- [ ] **APP-018 · Submission · Produce final store media.** Supply 1–10 screenshots per required
  device class using fictional/demo data, plus optional preview video. The narrative should show
  manual/photo wardrobe building, editing/organization, Today, History, and privacy controls. It
  must not show or imply Google, Gmail, receipt import, or a login.
- [ ] **APP-019 · Submission · Final distribution verification.** The fresh archive-time and
  immediate pre-validation App Store Connect checks confirmed build 4 was unused. The exact
  `1.0.0 (4)` replacement archive used the required Xcode/iOS SDK, validated, uploaded through the
  normal **TestFlight & App Store**-eligible route rather than **TestFlight Internal Only**,
  processed, and reached the intended internal group with truthful tester wording. Physical QA was
  partial and exposed the Today offline-cache defect, so build 4 is not promotable. The build-5
  archive is strictly verified; complete its validation/upload/clean-device remainder and keep
  backend health available through review.
- [ ] **APP-036 · In progress · Cut Gmail-free public v1.** Remove Google Sign-In, Google client/callback
  configuration, Gmail scope/network code, receipt-import UI/pipeline/background scheduling, and
  the `/extract` client from the shipped app. Build 4 used a fresh local-only schema and was never
  installed over builds 1–3. The user accepted losing the old local wardrobe and re-adding items.
  The pre-upload old-build cleanup and production backend retirement are complete: the installed
  intermediate build had no server-deletion UI, but the production auth store contained no live
  identity before it was uninstalled. Build 4 was installed only from processed TestFlight. The explicit
  old-build backend retirement decision is complete. Update in-app disclosures, Demo Mode, public pages, App
  Privacy answers, review notes, metadata, screenshots, and Release checks. The final archive must
  prove the removed capability is absent. This iOS behavior/configuration change requires a new
  TestFlight build and the full regression/release-artifact/physical-device loop. Repository,
  historical simulator-artifact, regression, production-backend, signed-archive, upload, and partial
  physical evidence is retained. The current build-5 regression and signed-archive evidence are
  retained; validation/upload, complete physical proof, deletion/recovery, and final Google
  retirement remain open.

## P1 — core experience polish

Imported-item language in APP-020 through APP-022 records historical implementation. Public v1
keeps the reusable manual/photo edit, catalog organization, favorites, archive, and filter work;
APP-036 removes receipt-import-specific states through the approved clean reset.

- [x] **APP-020 · Historical / done · Review and correct imported items.** Receipt-derived entries land in a
  visible review state. Users can edit name, brand, category, color, size, purchase metadata,
  and image before accepting. Surface duplicates and extraction uncertainty instead of silently
  saving an incorrect catalog.
- [x] **APP-021 · Done · Make every item editable.** Reuse one validated item form for manual add,
  import review, and edit. Preserve the existing photo when editing and confirm destructive
  deletion. Show specific save/validation failures.
- [x] **APP-022 · Historical / partial carry-forward · Improve catalog information architecture.** Add clear local/imported and
  pending-review cues, useful empty/search-zero states, stable sorting, favorites, archive, and
  bulk review where it materially reduces effort.
- [ ] **APP-023 · In progress · Polish Today.** Cache a recommendation for the day, let users refresh
  intentionally, accept occasion/context input, explain empty/error/offline states, and never
  make a backend call merely because a tab appeared. Saving “Wear this” must be transactional
  and acknowledged only after persistence succeeds. Build-4 physical QA proved the cache survives
  offline relaunch but found that a failed Restyle replaces the usable cached look with an error
  until relaunch/tap. The current fix passed local regression and requires build-5 physical proof.
- [x] **APP-024 · Done · Add outfit history and feedback.** Show worn looks, dates, and
  item details. Let users rate/save/skip a recommendation and feed those preferences into future
  prompts without weakening the catalog-ID hallucination guard.
- [x] **APP-025 · Done · Finish accessibility and adaptive layout.** VoiceOver names/hints and
  traversal, Dynamic Type through accessibility sizes, minimum tap targets, sufficient contrast,
  non-color-only status, Reduce Motion, keyboard/focus behavior, and meaningful image labels.
  Test the smallest supported phone and large text.
- [x] **APP-026 · Done · Standardize loading, empty, failure, offline, and retry states.** Avoid raw
  SDK/backend errors and indefinite spinners. Preserve user input on failure and make destructive
  or privacy-impacting actions explicit.
- [x] **APP-027 · Done · Add a branded first-run and launch experience.** Explain the value before
  permissions, include transparent privacy positioning, offer demo/local/manual-photo paths, and replace
  the empty launch treatment while preserving fast startup.
- [ ] **APP-028 · Enhancement · Localize user-visible copy.** Start with a complete development
  language catalog and locale-aware dates/times, then choose additional App Store localizations
  based on target markets.

## P2 — feature enhancements after the public-release foundation

- [ ] **APP-029 · Deferred after v1 · Reintroduce structured receipt extraction end to end.** The
  earlier implementation and tests remain in Git history; any separately approved future version
  must restore or redesign on-device JSON-LD/OCR handling, confidence, review UI, and cloud
  fallback under the new product/privacy decision.
- [ ] **APP-030 · Deferred after v1 · Scalable incremental Gmail sync.** Replace the 1,000-message
  ceiling/full rescans with an initial resumable backfill and Gmail History API cursor while
  retaining strict read-only endpoints and cancellation.
- [ ] **APP-031 · Enhancement · Rich styling preferences.** Add dress code, weather/context (only
  with separate permission), color/fit preferences, avoid/prefer items, laundry/unavailable
  state, packing/travel capsules, and calendar-aware occasions only as explicit opt-ins.
- [ ] **APP-032 · In progress · Wardrobe insights.** A local snapshot now covers looks worn,
  pieces in rotation, unworn pieces, favorites, and most-worn items. Extend it with cost-per-wear,
  category gaps, repeat rate, and purchase trends where the underlying data is reliable.
- [ ] **APP-033 · Enhancement · Import/export and backup.** Export a user-readable archive,
  restore it safely, and optionally sync via the user's iCloud account. Define conflict handling,
  encryption, and deletion semantics before implementation.
- [ ] **APP-034 · Enhancement · Better imagery.** Photo crop/reorder/replace, background cleanup,
  duplicate-photo detection, and a consistent thumbnail pipeline with full accessibility.
- [ ] **APP-035 · Enhancement · Widgets/Shortcuts.** A privacy-safe Today widget and App Intent
  for “What should I wear?” only after cached recommendations work reliably offline.

## Acceptance gates for this branch

Each logical slice gets a focused test and the complete regression suites before its commit:

```bash
cd backend && uv run --locked pytest && uv run --locked pip-audit && uv run --locked bandit -r app container_entrypoint.py -q && uv run --locked ruff check . && uv run --locked mypy app

cd ios && xcodegen generate
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Before calling the branch public-release-ready, also complete a clean simulator UI run, physical
device permission/auth QA, a signed Release archive/validation, request-capture privacy tests,
durable Fly auth-store/deployment evidence, and the external Apple Developer, Fly.io, and App
Store submission gates. Google Cloud is not a public-v1 gate. Simulator App Attest fakes never
replace the physical-device gate.

## Current external references

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple required App Store Connect properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)
- [Apple App Privacy guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple submission flow](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Apple App Attest client integration](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Apple App Attest server validation](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Fly volume persistence and single-machine boundary](https://fly.io/docs/volumes/overview/)
