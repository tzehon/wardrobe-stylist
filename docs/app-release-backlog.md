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

Last updated: **2026-08-29**. This table is authoritative when an item's original scope label
below still says “Now.” “Done” means the whole item is complete; partial work is deliberately
kept “In progress.”

| Items | Status | Verified branch outcome |
|---|---|---|
| APP-001–APP-008, APP-010 | **Historical / done** | Completed earlier Gmail-capable implementation work remains valuable history, but APP-036 supersedes its Gmail/OAuth/receipt-import release scope. Preserve applicable security/deletion guarantees while using the separately approved clean-uninstall transition |
| APP-009 | **External gate** | Repository enforcement, the exact Gmail-free Fly v10 runtime and post-change review, the late non-backdated historical v9 review, earlier reviews, an isolated read-only restore rehearsal, and the build-4/build-5 identity-safe handoffs are retained. Build 6's final server/local deletion, uninstall, clean reinstall, and explicit-action new anonymous enrollment passed after an eligible snapshot. Snapshot-list expiry and deletion-specific recovery/non-return remain open |
| APP-011 | **Done** | Product identity, Debug/Release split, Gmail-free Release configuration, public URLs, Team ID, and simulator guards remain implemented. Historical build-4/build-5 archives are retained; the exact build-6 production-signed archive passed profile, entitlement, identity, and public-configuration verification |
| APP-012 | **Done** | Dependency/privacy-manifest and removed-capability enforcement remains implemented. The build-6 signed archive passed the privacy-manifest and Gmail-free absence guards plus a separate non-emitting credential scan |
| APP-013 | **Done** | The deterministic offline tour now uses fictional manual/photo data, never opens the production store, and never calls connected AI; its Today/History/catalog flow passed UI automation |
| APP-014 | **In progress** | Clean build-6 QA passed Gmail-free first launch, offline Demo/local catalog, Camera and Photo Library saves, production styling/renewal, Today cache/failure recovery, Wear/History, reminder delivery, reminder-tap routing, final-client server/local deletion, clean reinstall, and explicit-action new enrollment. Automated production process-relaunch coverage still needs to prove the explicit cached-look restoration step |
| APP-015 | **Done** | CI/release gates remain implemented. The notification fix merged through PR #27; focused tests passed 17/17, merged-source verification retained 221 backend tests plus locked audit/Bandit/Ruff/mypy, 231/231 iOS tests, and 43 release-script tests. Fly v9, the strict build-6 archive, and Apple distribution were separately verified |
| APP-016 | **In progress** | The owned-domain Gmail-free privacy/support/Terms pages are published and anonymously verified. Current provider terms, App Privacy reconciliation, and final App Store Connect answers remain open |
| APP-017–APP-019 | **Submission / later milestone** | Historical `1.0.0 (4)` and consumed `1.0.0 (5)` are non-promotable. Processed `1.0.0 (6)` is strictly verified, assigned only to `Family`, and clean-tested through the fixed reminder tap plus final deletion/reinstall/new enrollment, but the confirmed styling-consent control presentation failure makes build 6 non-promotable. PR #31 merged the replacement control implementation. The 2026-08-29 signed-in Build Uploads check selected `1.0.0 (7)`; source preparation, runtime remediation, exact Fly v10 deployment, and the required post-change review now pass. Build-7 regression/archive/distribution/clean visual retest, metadata, and public submission remain open |
| APP-020–APP-022 | **Historical / partial carry-forward** | Manual add/edit, favorites, archive, filters, and catalog polish carry forward. Imported-item/review/account-scope behavior is historical and is removed through APP-036's owner-approved clean reset |
| APP-023 | **In progress** | Clean build 6 physically verified explicit-action styling, cached-look restoration after an offline process relaunch, and preservation through a failed offline Restyle. The initial **Style a look** state before explicit cache restoration is intended, but runbook wording and process-relaunch automation need to make that intermediate step explicit |
| APP-024–APP-028 | **In progress / pending** | Outfit History, local insights, 1–5 feedback, preference-aware styling, accessibility-size layouts, friendly bounded states, and branded launch/first-run are implemented. APP-025 remains open after the build-6 visual failure; PR #31 merged the title-only centered full-width opaque replacement and its contrast/UI coverage, while build-7 distribution and clean physical Dark Mode retest remain open. Broader localization remains APP-028 |
| APP-029–APP-035 | **Deferred / pending** | Receipt extraction and Gmail History work (APP-029/030) are deferred beyond public v1. Insights, backup, imagery, localization, and widgets remain independent future enhancements |
| APP-036 | **In progress** | Gmail/Google/OAuth/receipt import remains removed from the repository and signed build-6 archive. Build 5 was identity-safely retired, and clean build-6 QA retained broad Gmail-free physical proof through the delivered-reminder tap plus final deletion/reinstall/new enrollment. Build 6 is nevertheless non-promotable after the confirmed styling-consent control presentation failure; the replacement implementation, build `1.0.0 (7)` source, exact Fly v10 deployment, and post-change review pass. Build-7 distribution, clean physical visual retest, deletion-specific recovery, final Google retirement, and public submission remain open |

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
the full matrix were still open at that point. Build 5 later appeared installed in place before the
planned handoff, but retained the predecessor's live proof of possession. After the successful
automatic snapshot created at `2026-08-22T07:33:23Z` was verified as post-enrollment with 14-day
retention, the inherited identity used **Delete Server Security Data** successfully; production
installations, sessions, and challenges returned to zero. Local data was then deleted, the app was
removed, and build 5 was installed cleanly. This closes the build-4 identity-safe recovery/handoff,
not upgrade or migration support. Only aggregate counts, times, and outcomes are retained; no
payloads, identifiers, or secrets.

Clean build-5 physical QA on 2026-08-22 then passed Gmail-free first launch and onboarding, an
empty local wardrobe, offline Demo/Today/Wardrobe/History, successful Camera and Photo Library
item saves, the disposable manual catalog edit/favorite/filter/archive/restore/search/delete flow,
production enrollment and cold assertion renewal, initial styling and online Restyle, cached-look
restoration after offline relaunch, preservation of that look through a failed offline Restyle,
and offline **Wear this**/History. The bounded production stream observed one registration success
and one later assertion success without payloads or identifiers; the server remained healthy and
runtime validation-category/build fields were absent as expected on iOS 26.6. A delivered local
reminder then exposed a new release blocker: tapping it crashed build 5 at
`2026-08-22 17:15:14 SGT`. The `.ips` is an ordinary `EXC_CRASH`/`SIGABRT`, not jetsam or watchdog;
its executable exactly matches the retained build-5 dSYM. Safe symbolication reaches the generated
async Objective-C bridge for
`DailyReminderNotificationRouter.userNotificationCenter(_:didReceive:)`, which resumed UIKit's
completion path on a cooperative queue while state restoration was updating. Build 5 is consumed,
non-promotable, and must not receive another reminder-tap attempt.

The notification fix merged through PR #27 to clean synchronized `main`
`de7c540275fb16e61aabf1884538b18cf6edf76f`. It replaces both imported async notification-
delegate bridges with completion-handler delegates, snapshots only Sendable response fields, and
explicitly performs route publication and completion on the main queue. Focused tests passed
17/17. Merged-source evidence retained 221 backend tests plus locked dependency audit, Bandit,
Ruff, and mypy; 231/231 iOS tests (222 Swift unit plus 9 UI); and all 43 release-script tests.

The current production baseline is Fly release v10, completed at `2026-08-29T01:52:47Z`. It serves
exact merged build-7 backend source `162688ae72d07f06a7a8116249632aa0101e538f` as `linux/amd64`;
release and running image references match privately; local and immutable-registry Docker Scout
scans report zero High/Critical findings; and locked `pip-audit` passed. One healthy Singapore
Machine runs with `min_machines_running = 1`; production App Attest uses validation category `2`
and accepted builds `4,5,6,7`; the encrypted auth store remains healthy; and targeted application
logging remains bounded with access logging off. Production `/health` returns `200`, `/extract`
returns `404`, unauthenticated `/recommend` returns `401`, and the OpenAPI route set matches the
reviewed source. Build 5 was later identity-safely
retired after an eligible automatic snapshot, and build 6 was installed cleanly. A later automatic
snapshot at `2026-08-25T07:35:53Z`, status `created`, retention 14 days, was eligible for build 6's
final-client handoff. The pre-deletion installation/session/challenge aggregate was `1/0/0`;
owner-controlled server deletion produced exactly one bounded deletion marker, and post-deletion
plus post-uninstall aggregates were `0/0/0`. Clean reinstall, first launch, local item additions,
and styling consent alone stayed `0/0/0`. Explicit styling at `2026-08-28 17:17 SGT` then created
one new anonymous installation and one active session, with zero pending/failed challenges, one
completed challenge, one bounded registration marker, and expected signed runtime-field absence on
iOS 26.6. Snapshot-list expiry and deletion-specific recovery/non-return remain open.

The required v9 post-deploy/pre-upload payload-free review was missed and cannot be backdated. A
late full review completed at `2026-08-23T02:13:12Z`: exact release/runtime/source, health,
automatic 14-day snapshot policy and freshness, below-warning volume use, a current Fly HTTP view
without a 5xx series, zero bounded failure classes, Anthropic public status/configured-limit/spend-
band/production-model/no-saturation checks, and support/contact/response-target checks passed. The
production Wardrobe key showed only Opus 4.8; a separate older Wardrobe-labelled key had no seven-
day activity and its earlier-month Haiku cost was reviewed as historical non-production usage. No
raw metric, provider identifier, exact billing amount, key name/value, log sample, screenshot, or
provider body is retained. Repeat this review before every future archive/upload and after every
backend/configuration change.

Former v8, v7, and Gmail-free v6 images remain historical operational recovery evidence. None is
the exact build-6-compatible candidate: using one reopens deployment/configuration/manual-review
gates and blocks build-6 physical QA until v9 is restored and reverified. The emergency pre-build-4
image is App-Attest-only and scan-clean, but it re-exposes `/extract`; using it must halt the release.
The payload-free v8 post-change review passed at `2026-08-21T11:09:20Z`: the two-day HTTP view had
only `401`/`404` and no 5xx series; the bounded ten-minute view had no auth-rejection/rate-limit,
Anthropic/stylist, maintenance, unhandled, malformed-lifecycle, or access-log event. Anthropic
status, configured-limit, below-80%-of-limit, expected deployed Wardrobe key/Opus 4.8, and
no-saturation checks passed, as did the published support pages, contact/response target, and
retained routing rehearsal. The bounded stream contained zero `registration_succeeded`,
`assertion_succeeded`, or `installation_deleted` events because none was exercised after v8
deployment at that review point. Later physical QA observed build-4 identity deletion and clean
build-5 registration/assertion markers without payloads or identifiers. Protected `/recommend`
success intentionally has no developer event and remains aggregate/client-evidenced.

## Immediate next milestone — remaining recovery and release gates

App Store Connect showed builds 1–4 only and build 5 absent at the final pre-validation refresh,
`2026-08-22T03:16:16Z`. The exact `1.0.0 (5)` production-signed archive then validated, uploaded,
processed, and reached only the intended `Family` Internal Testing group. Build 5 is consumed and
must never be reused. Build-4 recovery/handoff and broad clean build-5 QA are now retained below,
but the delivered-reminder tap crash makes build 5 non-promotable and the shipped Swift fix requires
a replacement TestFlight candidate. A signed-in TestFlight **Build Uploads** inspection at
`2026-08-22T10:02:31Z` (`18:02:31 SGT`) showed builds 1–5 only, build 5 **Complete**, and no build
6, confirming build 6 unused before replacement work. PR #27 then merged the notification fix and
build-6 metadata/allowlist to clean synchronized `main` `de7c540275fb16e61aabf1884538b18cf6edf76f`.
The full backend, iOS/UI, release-script, optimized Release-build, and simulator-artifact gates
passed on the replacement source/configuration. Fly v9 completed at `2026-08-22T11:14:25Z` with
validation category `2`, accepted builds `4,5,6`, matching source/image revision, one healthy
Singapore Machine, and the exact expected public route behavior. The strict production-signed
`1.0.0 (6)` archive was created at `2026-08-22T11:42:24Z`, validated by Xcode, and uploaded through
the normal **TestFlight & App Store** route at `2026-08-23 08:57 SGT`. By
`2026-08-23T01:22:50Z`, Apple showed it **Ready to Submit**, assigned only to `Family` with one group
tester and no individual testers, with the truthful What to Test notes saved. Build 6 is consumed
and must never be reused. The late non-backdated v9 operational review then passed at
`2026-08-23T02:13:12Z`, while preserving the missed pre-upload timing as a process defect. Build 5's
identity-safe handoff and clean build-6 QA through the delivered-reminder tap have since passed. An
eligible `2026-08-25T07:35:53Z` automatic snapshot then cleared build 6's final-client handoff; the
owner-controlled deletion, zero-aggregate checks, local deletion, uninstall, clean reinstall, and
explicit-action new anonymous enrollment passed on 2026-08-28. The remaining APP-009 evidence is
snapshot-list expiry plus deletion-specific recovery/non-return. A 2026-08-28 owner-supplied Dark
Mode screenshot separately confirmed that the build-6 styling-consent control fails its visual gate,
so build 6 is non-promotable. PR #31 has since merged the replacement implementation. On 2026-08-29,
the signed-in TestFlight **Build Uploads** view showed build 6 as the highest upload and **Complete**,
with build 7 absent. This proves build 7 unused and selects `1.0.0 (7)` while keeping
`MARKETING_VERSION = 1.0.0`. Source configuration now prepares `CURRENT_PROJECT_VERSION = 7` and
accepted builds `4,5,6,7`. PR #34 rebase-merged the runtime remediation to clean main
`162688ae72d07f06a7a8116249632aa0101e538f`; the exact merged Linux/AMD64 image passed local and
immutable-registry zero-High/Critical scans and the runtime smoke gates, then deployed as completed
Fly v10 at `2026-08-29T01:52:47Z`. Exact image/configuration, health/routes, durable auth-store,
volume, snapshot, safe aggregate, bounded logs, official two-day no-5xx metric, Anthropic, and
anonymous public-page checks passed in the required payload-free review at
`2026-08-29T02:21:41Z`. The repeat regression, signed archive and distribution pipeline, plus clean
physical Dark Mode visual retest remain open.

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
- [x] **Validate, upload, process, and internally assign build 5.** The exact-v8 payload-free
  review passed from `2026-08-22T02:27:21Z` through `02:37:08Z`; the final App Store Connect refresh
  at `03:16:16Z` still showed builds 1–4 only and build 5 absent. Organizer **Validate App**
  succeeded at `03:18:30Z` with zero errors, warnings, or informational messages. The exact archive
  uploaded through the normal **TestFlight & App Store**-eligible App Store Connect route at
  `03:20:59Z`, again with zero errors, warnings, or informational messages. Symbols were on;
  **Manage Version and Build Number** and **Internal Testing Only** were off. Processing reached
  **Ready to Submit** by `03:24:21Z`. Processed metadata shows `1.0.0 (5)`,
  `com.tth.Wardrobe`, arm64, minimum iOS 18.0, SDK build `23F81a`, included symbols, no non-exempt
  encryption, scalar production App Attest, `get-task-allow = false`, and beta reporting active.
  Exactly the `Family` Internal Testing group is assigned with one tester and no individual tester
  assignments. The exact-v8 immediate post-distribution review passed from `03:19:20Z` through
  `03:30:33Z`: fixed/coarse state remained healthy, the newest snapshot was under 36 hours old,
  schema v4 integrity/foreign keys passed, the endpoint surface stayed clean, failure bands stayed
  at zero, and the Anthropic/support checks passed. The review interval overlapped upload and is
  retained as post-distribution evidence, not pre-upload evidence.
- [x] **Complete build 4's identity-safe recovery/handoff.** Build 5 appeared installed in place
  before the planned handoff, but retained the predecessor's live proof of possession. A successful
  post-enrollment automatic snapshot created at `2026-08-22T07:33:23Z` was confirmed with 14-day
  retention. **Delete Server Security Data** then succeeded, the production installation/session/
  challenge aggregates returned to zero, local data was deleted, and the app was removed before a
  clean build-5 install. This recovery is not upgrade/migration product proof.
- [x] **Run clean build-5 physical QA through the first blocker.** Gmail-free launch/onboarding,
  offline Demo/local flows, successful Camera/Photo Library saves, the disposable catalog matrix,
  production registration/assertion and styling/Restyle, cached-look offline recovery and failed-
  Restyle preservation, and Wear/History passed. A delivered reminder arrived, but tapping it at
  `2026-08-22 17:15:14 SGT` caused `EXC_CRASH`/`SIGABRT`. Build 5 is consumed and non-promotable;
  do not repeat the notification tap on it.
- [x] **Diagnose and fix the notification delegate on a branch.** The crash executable exactly
  matches the retained build-5 dSYM. Safe symbolication reaches the generated async Objective-C
  bridge for `DailyReminderNotificationRouter.userNotificationCenter(_:didReceive:)`; UIKit's
  completion path resumed on a cooperative queue during state restoration. Branch
  `codex/fix-notification-tap-crash`, based on clean synchronized `main` `74ed41ee7077a5a4be616718f99499ffeb52a5ee`,
  replaces both imported async delegate bridges with explicit completion-handler/main-queue
  routing. Focused tests passed 17/17; the post-fix branch regression passed 221 backend tests plus
  audit/Bandit/Ruff/mypy, 222 Swift unit tests, all 9 UI flows, and 43 release-script tests. This
  branch-local evidence was later superseded by the merged-source, Fly v9, strict archive, and
  Apple distribution evidence below.
- [x] **Confirm the replacement build number in live App Store Connect.** The read-only signed-in
  TestFlight **Build Uploads** view at `2026-08-22T10:02:31Z` showed builds 1–5 only, build 5
  **Complete**, and no build 6. Build 6 is confirmed unused and selected; keep
  `MARKETING_VERSION = 1.0.0` and never reuse build 5.
- [x] **Merge, freeze, and run the replacement-candidate pipeline.** PR #27 merged at clean
  synchronized `main` `de7c540275fb16e61aabf1884538b18cf6edf76f`; merged-source regressions and
  release guards passed; exact Fly v9 compatibility and health passed; and
  `Wardrobe-1.0.0-6-de7c540-appstore.xcarchive` passed strict archive/signing verification. Xcode
  validated and uploaded it through the normal **TestFlight & App Store** route. Apple processing
  reached **Ready to Submit**; only `Family` is assigned, with one group tester, no individual
  testers, and saved truthful What to Test notes. This closes distribution, not physical QA.
- [x] **Record the late v9 operational review without backdating it.** The required post-deploy/pre-
  upload review was missed. The complete payload-free review passed at `2026-08-23T02:13:12Z`,
  restoring current operational evidence while retaining the process defect. Repeat it before any
  future archive/upload and after every backend/configuration change.
- [x] **Identity-safely retire build 5 and install build 6 cleanly.** Build 6 appeared installed in
  place unexpectedly, but the inherited proof of possession remained available. After the
  `2026-08-23T07:34:23Z` successful automatic snapshot was confirmed post-enrollment, the owner
  disabled the reminder, withdrew styling permission, deleted the live server record, observed
  aggregate `0/0/0`, deleted local data, removed the app, and installed processed build 6 cleanly.
  This is deletion evidence, not upgrade/migration proof.
- [x] **Repeat clean physical QA through the notification fix in build 6.** Gmail-free first launch,
  empty local state, offline Demo, Camera and Photo Library saves, the catalog matrix, production
  registration and cold assertion renewal, online styling, explicit cached-look recovery after
  offline relaunch, failed-Restyle preservation, offline Wear/History, reminder delivery, and the
  delivered-reminder tap passed. The reminder opened Today without a crash and Wardrobe/History
  state remained intact.
- [x] **Complete build-6 deletion/reinstall after an eligible snapshot.** The automatic snapshot at
  `2026-08-25T07:35:53Z` reported `created` with 14-day retention and cleared the gate. Before the
  owner-controlled deletion, the installation/session/challenge aggregate was `1/0/0`; exactly one
  bounded deletion marker appeared, and post-deletion plus post-uninstall aggregates were `0/0/0`.
  Clean reinstall, first launch, local item additions, and styling consent alone stayed `0/0/0`.
  Explicit Style at `2026-08-28 17:17 SGT` created one new anonymous installation and one active
  session, with zero pending/failed challenges, one completed challenge, one bounded registration
  marker, and expected signed runtime-field absence on iOS 26.6. This is deletion and fresh-
  installation evidence, not upgrade or migration proof.
- [ ] **Finish snapshot-list expiry and deletion-specific recovery/non-return evidence.** Observe
  the eligible 14-day snapshot leaving the customer-visible list and prove that a deleted production
  identity cannot return. The generic isolated restore-path rehearsal does not close this gate.
- [x] **Confirm that build 6 fails the styling-consent control presentation gate.** In the
  2026-08-28 owner-supplied Dark Mode screenshot, the **Allow AI styling** title is approximately
  21 points right of the button center, and the sampled `#C2DFFC` fill against the white title is
  approximately `1.38:1`. This is a confirmed visual/contrast failure, not an identity failure;
  build 6 is consumed, non-promotable, and must never be reused.
- [x] **Implement and verify the styling-consent control replacement.** PR #31 rebase-merged app
  commit `b7e46e4` to clean `main` `e4a0ae2`. The title-only control is centered, full-width, and
  opaque; focused coverage pins enabled, pressed, and disabled contrast plus the screenshot UI
  assertion. Merged verification passed 221 backend tests plus audit/Bandit/Ruff/mypy, 226 Swift unit
  tests, all 9 UI tests, and 43 release-script tests; both GitHub iOS checks are green.
- [x] **Select and prepare build 7 without claiming deployment.** The signed-in TestFlight **Build
  Uploads** view on 2026-08-29 showed build 6 as the highest upload and **Complete**, with build 7
  absent. Select `1.0.0 (7)` and keep `MARKETING_VERSION = 1.0.0`. Source configuration now records
  `CURRENT_PROJECT_VERSION = 7` and accepted builds `4,5,6,7`. At selection time, live Fly v9 still
  accepted `4,5,6`; the completed v10 deployment is recorded separately below.
- [x] **Remediate the build-7 runtime scan before publication or deployment.** The first local
  Linux/AMD64 candidate scan found seven High-severity OpenSSL findings in the prior pinned runtime,
  so no image was pushed or deployed. Commit `6186018` refreshes the digest-pinned official runtime
  and its two crypto libraries. The rebuilt image reports zero High/Critical Docker Scout findings
  and passes the non-root, no-new-privileges, logging, SQLite, and mounted-volume smoke gates. Full
  verification passed 222 backend tests plus audit/Bandit/Ruff/mypy, 226 Swift unit tests, all 9 UI
  tests, 43 release-script tests, and the clean `1.0.0 (7)` Release simulator artifact check. This is
  local source/image evidence only; deployment evidence is recorded separately below.
- [x] **Deploy and review the selected build-7 backend candidate.** PR #34 rebase-merged the runtime
  remediation to clean main `162688ae72d07f06a7a8116249632aa0101e538f`. The exact merged
  Linux/AMD64 image passed local and immutable-registry zero-High/Critical scans and the runtime
  smoke gates, then deployed as completed Fly v10 at `2026-08-29T01:52:47Z`. Live image/configuration,
  health/routes, App-Attest-only auth, schema-v4 integrity, low-band volume use, automatic snapshot,
  and safe aggregate `1/0/0` pass. The payload-free review passed at `2026-08-29T02:21:41Z`: the
  official two-day metric has only `2xx`/`4xx` classes and no `5xx`; bounded failure classes,
  Anthropic status/limit/spend/model/saturation, and anonymous public support/privacy/Terms checks
  pass. No raw provider body, identifier, metric, billing amount, key, log, or screenshot is retained.
- [ ] **Repeat regression and distribute only build 7.** Create and strictly verify the signed
  archive, repeat the pre-upload review, obtain explicit owner approval immediately before upload,
  validate/upload through the normal App-Store-eligible route, wait for Apple processing, assign
  only `Family`, and save truthful tester notes.
- [ ] **Clean-install and physically retest the build-7 control.** On the processed TestFlight build,
  confirm the title is centered with no invisible icon slot and that enabled, pressed,
  and disabled presentation remains legible in Dark Mode before promotion.

Do not archive early and plan to repair the same binary later. The checked sequence below records
the historical build-4 path and does not close any replacement-candidate physical, deletion,
recovery, APP-019, APP-036, or public-submission gate.

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
  archive-time refresh at `2026-08-22T01:09:39Z` showed builds 1–4 only, and the final
  pre-validation refresh at `2026-08-22T03:16:16Z` again showed build 5 absent. The exact signed
  archive subsequently validated, uploaded, processed, and reached the intended internal group.
  Build 5 is now used and must never be reused.
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
- [x] **Complete predecessor identity handoff and retain build-5 partial production proof.** The
  eligible post-enrollment snapshot, proof-of-possession server deletion, zero aggregate, local
  deletion, uninstall, and clean build-5 install are retained above. Clean build 5 subsequently
  supplied production registration/assertion markers and protected-client proof before the
  delivered-reminder crash made it non-promotable.
- [ ] **Complete replacement post-upload APP-009/APP-036 proof and cleanup.** Clean build 6 has
  passed through the delivered-reminder tap and completed final-client server/local deletion,
  uninstall, clean reinstall, and explicit-action new anonymous enrollment after an eligible
  snapshot. Finish deletion-specific recovery/non-return and eligible 14-day snapshot-list
  disappearance. After the replacement is proven and with a separate final owner confirmation,
  retire only the inventoried Wardrobe Google Cloud/OAuth projects; do not touch unrelated projects.

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
  build-6 archive and its completed validation/upload/processing/internal-assignment evidence are
  retained above. Physical-device and public-submission gates remain separate.
- [x] **APP-012 · Done · Pin/audit dependencies and archive privacy metadata.** Historical
  work pinned and audited Google Sign-In. For the Gmail-free candidate, remove that SDK and its
  transitive bundles, keep only actually integrated dependencies/privacy manifests, and make the
  artifact verifier fail if Google/AppAuth/GTM components remain. Rerun dependency, privacy-
  manifest, and removed-capability verification against the replacement Release artifact and
  signed archive before release. The repository task remains complete: build-6 Release simulator/
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
  for Google/Gmail/receipt import. Clean build-5 physical QA closed the former media-selection and
  Today-Restyle gaps but exposed a `SIGABRT` when a delivered reminder was tapped. Clean build 6
  passed the fixed delivered-tap route, preserved local state, and completed final deletion/
  reinstall/new-enrollment proof. Automated coverage still lacks a production process-relaunch case
  that proves the explicit cached-look restoration step.
- [x] **APP-015 · Done · Strengthen CI/release gates.** Run backend contract tests when `shared/**`
  changes; build/test a Release configuration; run an archive/privacy report guard; and retain
  full locked pytest/pip-audit/Bandit/Ruff/mypy plus Swift test regressions. The clean complete
  historical build-4 and build-5 regression/artifact/archive verification is recorded above. The
  build-6 fix passed 17/17 focused tests; merged-source evidence retained 221 backend tests plus all
  mandatory audit/analysis/security/type gates, 231/231 iOS tests, and 43 release-script tests.
  Exact Fly v9, signed-archive, and processed-build checks passed separately.
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
  archive has also passed validation, normal-route upload, processing, and assignment only to the
  intended internal group. Build-4 handoff and broad clean build-5 QA subsequently completed, but
  tapping a delivered reminder crashed build 5, making it non-promotable. The exact build-6 archive
  passed strict verification, normal-route validation/upload, processing, `Family` assignment, and
  truthful tester-note checks. Build 5's handoff and clean build-6 proof through delivered-reminder
  tap plus final deletion/reinstall/new enrollment are complete, but the confirmed styling-consent
  control presentation failure makes build 6 non-promotable. The replacement implementation is
  merged and verified; build `1.0.0 (7)` is selected/source-prepared, and its exact Fly v10 backend
  deployment plus post-change review pass. Finish snapshot lifecycle evidence, build-7 regression/
  archive/distribution, and the clean visual retest, then keep backend health available through review.
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
  historical simulator-artifact, regression, production-backend, signed-archive, upload, and
  physical evidence is retained. Build-4 and build-5 handoffs completed; clean build 5 provided
  broad Gmail-free proof and production markers before its notification-tap crash. The fix is
  merged, historical Fly v9 compatibility and the current Fly v10 deployment pass, and clean build 6
  passed broad Gmail-free physical QA through the fixed notification tap and final identity-safe
  deletion/reinstall/new enrollment. Deletion-
  specific recovery/non-return, final Google retirement, and public submission remain open.

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
  and acknowledged only after persistence succeeds. Build-4 physical QA found that a failed
  Restyle hid the usable cached look until relaunch. Clean builds 5 and 6 physically verified the
  fix: the cached look restored offline and remained visible through failed Restyle. After a
  process relaunch, build 6 intentionally showed **Style a look** until one explicit tap restored
  the cached look locally; document and automate that intermediate explicit-action state.
- [x] **APP-024 · Done · Add outfit history and feedback.** Show worn looks, dates, and
  item details. Let users rate/save/skip a recommendation and feed those preferences into future
  prompts without weakening the catalog-ID hallucination guard.
- [ ] **APP-025 · In progress · Finish accessibility and adaptive layout.** VoiceOver names/hints and
  traversal, Dynamic Type through accessibility sizes, minimum tap targets, sufficient contrast,
  non-color-only status, Reduce Motion, keyboard/focus behavior, and meaningful image labels.
  Test the smallest supported phone and large text. The 2026-08-28 owner-supplied Dark Mode
  screenshot confirms that build 6's **Allow AI styling** title is approximately 21 points right of
  center and its sampled `#C2DFFC` fill against white is approximately `1.38:1`. Build 6 is therefore
  non-promotable. PR #31 merged the title-only centered full-width opaque replacement with
  enabled/pressed/disabled contrast coverage and a screenshot UI assertion; close APP-025 only after
  build 7 is distributed and passes a clean physical visual retest.
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
