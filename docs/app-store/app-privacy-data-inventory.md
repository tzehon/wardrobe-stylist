# App Privacy data inventory

> **23 September status:** Apple approved build 7 and the owner-authorized manual release
> completed after the full preflight passed. The public Singapore listing is live and availability was verified. Fly v15 was deployed at that checkpoint. See the [launch record](launch-check-20260923.md) for that dated evidence;
> earlier rejection, wait-for-reply and unapproved-release statements below are historical.

This inventory drives the in-app disclosure, public privacy policy, Apple App Privacy answers,
deletion implementation, request-capture tests, and processor contracts for the approved
Gmail-free public v1. “Collected” below uses Apple's App Privacy concept. The approved App Store
Connect answers were published and reload-verified on 12 September. Later provider, purpose or
data-flow changes require reassessment. Historical
Gmail/receipt-import data categories are intentionally excluded because the signed v1 must not
contain or invoke that capability.

Build `1.0.0 (7)` has completed
[internal TestFlight distribution](internal-testflight-runbook.md#build-7-distribution--2026-09-10)
with AI disabled. Handoff, clean installation and scoped local-beta QA passed on 11 September.
Privacy publication, the consent assessment, bounded activation and protected-device styling
proof passed on 12 September. As of 19 September, build 7 is **Rejected / Unresolved Issues**
under Guideline 4.3(a). The [clarification](spam-rejection-20260919.md) was sent at 15:46 SGT and
verified in Messages (6). Apple approval and owner-authorized release followed on 23 September. This
correspondence does not change the disclosed data flow; do not repeat the completed handoff or
routine QA.

The [current Fly v17 pilot](build8-release-20261016.md)
has AI enabled under the existing private policy and separate aggregate ledger. The owner
separately approved this activation; the first protected-device styling call passed on 12 September.
Styling transmissions below describe the consented optional flow. The 12 September published policy now discloses this additional aggregate store;
publication does not enable styling.

The [12 September review](ai-pilot-privacy-review-20260912.md) confirms standard Anthropic
30-day retention with documented exceptions and no feedback opt-in in the reviewed organization.
The styling content below is collected for Apple purposes despite the content-stateless backend.
The four approved categories are published and reload-verified in App Store Connect.

| Data / source | On-device use | Leaves device? | Recipient / purpose | Intended retention | Consent / control | Apple answer status |
|---|---|---:|---|---|---|---|
| Wardrobe item attributes | Catalog + styling | Yes for AI styling | Backend → Anthropic outfit recommendation | Developer application: request lifetime only, no persistence; Anthropic: standard 30 days with the documented exceptions | Styling consent | Other User Content; App Functionality and Product Personalization; linked; not tracking; published 12 September |
| Wardrobe photos | Catalog display | No in v1 styling path | Local app | Until item/local-data deletion | Photo picker/camera; delete | Not collected if device-only |
| Purchase date/price/currency | Catalog/review/insights | No in v1 styling | Local app | Until item/local-data deletion | Review/edit/delete | Not collected if device-only |
| Outfit and wear history | Anti-repeat/history and explicit 1–5 feedback | Recent item IDs and bounded per-item rating summaries (item ID, average, count) leave for styling; no feedback free text or wear dates | Backend → Anthropic recommendation | Developer application: request lifetime only, no persistence; local history until delete; Anthropic: standard 30 days with the documented exceptions | Styling consent; delete | Other User Content; App Functionality and Product Personalization; linked; not tracking; published 12 September |
| Occasion/context text | User-directed recommendation | Yes | Backend → Anthropic recommendation | Developer application: request lifetime only, no persistence; Anthropic: standard 30 days with the documented exceptions | Styling consent; user submits | Other User Content; App Functionality and Product Personalization; linked; not tracking; published 12 September |
| App Attest key ID, verified public key, opaque Apple attestation receipt, anonymous installation ID and assertion counter | Prove a genuine installation and renew backend access without a Wardrobe account | Key ID/attestation/assertions leave; private key never leaves Secure Enclave | Apple App Attest certification → developer backend authentication/security store | Repository limits: 90 days after last successful use; revoked records 30 days; an assertion-verified deletion request synchronously removes the live installation. Encrypted snapshots stop appearing from Fly's customer listing after 14 days; all-copy purge timing is undisclosed and owner-accepted. The current [enabled Fly v17 runtime](build8-release-20261016.md) retains verified production retention enforcement, the targeted payload-free auth-service INFO logger, and the TestFlight/App Store categories `2,4` and build allowlist `4,5,6,7,8`. The [10 September checkpoint](internal-testflight-runbook.md#build-7-distribution--2026-09-10) records the completed AI-disabled beta distribution. The historical v10 Linux/AMD64 runtime and required post-change review passed on 2026-08-29. Physical iOS 26.6 evidence shows the expected signed runtime-field absence and does not prove iOS 27+ category/build enforcement. The required historical v9 post-deploy/pre-upload review was missed and is not backdated; its late review passed at `2026-08-23T02:13:12Z`. The build-4 and build-5 identity-safe handoffs each reached aggregate zero before local/app deletion. Build 6's final handoff used the eligible `2026-08-25T07:35:53Z` snapshot: the pre-deletion aggregate was `1/0/0`, exactly one bounded deletion marker was observed, and post-deletion/post-uninstall aggregates were `0/0/0`. Clean reinstall and local-only actions remained at zero; explicit Style at `2026-08-28 17:17 SGT` created a new anonymous installation and active session. The monitored 25/28 August snapshots were later observed absent from the customer-visible list. The 10 September Build-7 pre-deletion snapshot's later disappearance and deletion-specific restore/non-return were not proven; on 2026-09-11 the owner waived only that evidence sub-gate for the Free Singapore v1 and accepted the residual risk. Other public-release privacy checks remain pending, including independent Apple-receipt validation/risk-metric policy. | **Settings → Privacy & Data → Delete Server Security Data** uses a fresh App Attest assertion; reinstall creates a new identity but does not delete the old row | Device ID, App Functionality, linked, not tracking; published 12 September |
| One-time App Attest challenges, hashed short-lived sessions and coarse rate windows | Replay prevention, authorization, quotas and abuse prevention | Yes | Developer backend security store | Repository maxima: challenge 70 minutes from issue; session hash 20 minutes from issue; rate-window hash five minutes after its one-minute/hourly window, enforced by the deployed one-minute maintenance loop and request-time expiry cleanup | Automatic expiry; a verified server deletion removes current-secret-derived key/installation rows, while unlinkable pre-rotation HMAC rows expire within 65 minutes | Device ID and Other Diagnostic Data; App Functionality; linked; not tracking. Final App Store Connect published 12 September |
| Aggregate AI budget and unresolved reservation metadata | None; generated on the backend | No device data is added to this ledger | Separate developer backend budget store on the original encrypted volume | A month identifier, aggregate charged-unit/admission totals, private policy/model/pricing fields, halt state, and random pending-reservation IDs with bounded amounts and month; no installation or human-account ID, wardrobe, prompt, or model-response payload. Completed reservations are removed; uncertain work stays conservatively charged until separately reconciled. The existing 14-day snapshot policy is unchanged. | Global accounting survives individual server-security deletion; never reset it to regain allowance | Developer-generated aggregate accounting; no additional device-collected category solely for this store; public disclosure published 12 September |
| IP address, request path/ID and timing | Network delivery/security | Inherent | Host/backend abuse prevention | Raw IP is not stored in SQLite and application access logs are disabled. Fly's customer-visible platform/proxy stream can contain path, request ID and client IP for a fixed seven days. Separate operational/abuse logs can contain source IP with undisclosed, non-configurable in-service retention. The owner accepted this provider boundary on 2026-08-19. | Public policy; remote features are optional | Conservatively: Device ID, Other Diagnostic Data and Product Interaction; App Functionality; linked; not tracking. Final App Store Connect published 12 September |
| Consent and automation preferences | Enforce user choices | No | Local UserDefaults | Until withdrawal/delete | Privacy Center | Not collected if device-only |
| Camera/photo-library selection | Add item photo | Selected asset only, device-local | Local app | Until item/delete | System permission/selection | Not collected if device-only |
| Notification schedule | Daily local reminder | Apple notification system | Local notification delivery | Until disabled | Reminder toggle/system settings | Usually not developer-collected; no push service is used. Clean build-6 delivery and tap routing passed without a crash or local-state loss |
| Crash/analytics diagnostics | None currently planned | No current SDK | N/A | N/A | N/A | Reassess before adding any SDK |

## Release-blocking confirmations

The exact approved developer-controlled schedule and its current compliance status live in
[`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md).

- [x] Use synthetic/local request-capture fixtures to verify the exact allowlisted `/recommend`
  fields. The build-5 guard inventories every stored property on the three Swift request types,
  including nil optionals, and separately pins the complete encoded top-level, catalog-item, and
  preference key sets; the shared schema/backend reject extras. The strengthened focused
  `RecommendClientTests` suite passed 12/12 at `2026-08-22T01:59:08Z`; the post-guard tree then
  passed the complete 221-test backend gate and an uninterrupted historical pre-archive
  218-unit/9-UI iOS regression whose
  result bundle finalized at `2026-08-22T02:04:17Z`. Only field names and synthetic values were
  inspected; never capture or retain production wardrobe, prompt, or model response bodies as
  evidence.
- [x] Verify the signed candidate and its generated configuration contain no Google Sign-In SDK,
  Google client identifier/callback scheme, Gmail permission/host/client path, `/extract` client
  path, receipt-import UI, or receipt-background-task identifier. The exact build-6 source guards
  and archive passed historically. The strict verifier and separate non-emitting credential/
  removed-capability scan passed for the final build-7 archive
  `Wardrobe-1.0.0-7-0cc0fa7-appstore-final-20260829T110218Z.xcarchive` at
  `2026-08-29T11:04:02Z`; both earlier build-7 archives are non-uploadable.
- [x] Confirm the application security-event schema is bounded and excludes payloads, credentials,
  IPs, and installation identifiers; confirm raw IP is absent from SQLite.
- [x] Disable application access logs in the production container command and pin that command with
  a regression.
- [x] Record Fly's provider-controlled logging facts and the explicit 2026-08-19 owner decision
  accepting a fixed seven-day customer-visible stream plus undisclosed provider-internal
  in-service retention. Preserve the old 24-hour requirement as unmet and superseded, not passed.
- [x] Record the 2026-08-20 owner decision to use payload-free manual operations for the initial
  personal single-user release. No monitoring processor, credential, or new backend data flow is
  introduced by that decision.
- [ ] Decide whether to request, review, and sign Fly's optional DPA. The account currently has no
  active DPA; do not treat Fly Security's 30-day post-service deletion and 90-day residual
  encrypted-backup summary as binding unless the exact agreement/version is executed.
- [x] Record the owner-approved snapshot/recovery evidence waiver for Free Singapore v1. The Fly
  region and encrypted storage had already been verified by the retained runtime review; this
  decision did not perform or claim a new infrastructure check. The secret-
  free, non-serving restore path and immediate temporary-resource cleanup passed on 2026-08-19.
  The eligible `2026-08-25T07:35:53Z` snapshot enabled the completed build-6 live deletion,
  reinstall, and new enrollment. The monitored 25/28 August snapshots were later observed absent
  from the customer-visible list, but the 10 September Build-7 pre-deletion snapshot's later
  disappearance and deletion-specific restore/non-return remain unobserved. On 2026-09-11 the owner
  accepted that residual risk and waived only this evidence sub-gate for the Free Singapore v1.
  All-copy purge timing is explicitly accepted as
  undisclosed; the checked item records the waiver decision, not passing evidence.
- [x] Confirm the exact build-6 signed archive's production App Attest App ID prefix, App Store
  profile/certificate match, and scalar production entitlement. The strict verifier matched the
  prefix, team, bundle, certificate, and production grant; `get-task-allow` is false and no
  devices/all-devices are provisioned.
- [x] Confirm the exact final build-7 signed archive's production App Attest, App Store profile/
  certificate identity, public configuration, privacy manifest, and scalar production entitlement.
  Strict and deep verification passed, and the arm64 app/dSYM identifiers match. The
  `2026-08-29T11:05:38Z` signed-in Build Uploads refresh showed build 6 highest and **Ready to
  Submit**, with build 7 absent.
- [ ] From the final processed client, retain tester OS, signed runtime-field behavior, and the
  exact Apple receipt field set retained. Clean build-6 QA on iPhone 16 Pro/iOS 26.6 proved the
  expected runtime-field absence plus physical registration/assertion, but it does not prove iOS
  27+ validation-category/exact-build fields, the remaining receipt evidence, or a promotable build.
- [x] Confirm the durable auth-store schema contains only public keys/opaque Apple attestation
  receipts, anonymous installation IDs, counters, challenges, session hashes and rate windows—
  never wardrobe, prompt, or model-response payloads.
- [x] Enforce deadline cleanup, 90-day inactivity purge, 30-day revoked-record purge, synchronous
  assertion-verified live deletion, safe SQLite/WAL maintenance, and the separate in-app server
  deletion control in the repository.
- [x] Against the then-current reviewed deployment, complete the first owner-approved payload-free
  manual operations review. Preserve it as history and repeat under the lifecycle policy after each
  backend or production-configuration change.
- [x] Record the missed v9 post-deploy/pre-upload review without backdating it. The late complete
  payload-free review passed at `2026-08-23T02:13:12Z`; repeat before every future archive/upload,
  after each backend/configuration change, and otherwise by the next recorded due date.
- [x] Publish and rehearse the monitored support route at `contact@tth.dev`; keep the
  two-business-day response target.
- [x] Record the owner-approved decision not to rehearse deletion-specific restore/recovery for the
  Free Singapore v1. The 2026-09-11 waiver accepts the residual risk and does not count as proof.
- [ ] Confirm unsupported App Attest, offline verification and backend failure preserve local
  wardrobe/Demo Mode while remote AI fails closed without creating an unauthenticated identifier
  or request. Clean build 6 proved offline/backend failure preserves local Wardrobe, Demo, Today
  cache, Wear, and History while remote styling fails closed; the distinct unsupported-App-Attest
  path remains open.
- [x] Confirm the migration bridge is retired, `DEVICE_TOKEN` is unset/rotated, and the obsolete
  shared-token build is rejected. The initial rollback boundary was App-Attest-only; APP-036 now
  additionally requires a Gmail-free recovery image after build 4 distribution.
- [x] Retain historical Gmail-free v6 recovery-image evidence: digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5` and retained v5
  emergency rollback digest `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  both resolved from the registry after fresh authentication at `2026-08-21T01:20:25Z` and passed
  critical/high scans across 90 packages. An isolated old/new/old schema-v4 rehearsal retained
  integrity and zero foreign-key errors; live `/extract` now returns `404`, `/recommend` rejects
  missing authorization, and the obsolete shared bearer remains rejected. The v5 digest is an
  emergency pre-build-4 abort only, and v6 is timestamped historical evidence only.
- [x] Review the published standard Anthropic API terms, retention/training exceptions, human
  access and subprocessors against signed-in organization privacy controls on 12 September.
  See the [review and contract-evidence limits](ai-pilot-privacy-review-20260912.md); no bespoke
  contract or ZDR grant is claimed.
- [x] Reconcile the current data flow with notice version 3 and the published 12 September policy;
  retain the [consent assessment](ai-pilot-privacy-review-20260912.md).
- [x] Publish and reload-verify Apple App Privacy answers on 12 September based on retention,
  linkage and tracking—not on
  whether content merely passes through a content-stateless endpoint. Assess the anonymous App
  Attest installation identifier and retained IP as Device ID, retained provider operational/error
  records as Other Diagnostic Data, and retained request paths as Product Interaction. Use App
  Functionality, linked, and not tracking on the current evidence; do not select location,
  analytics, advertising, marketing, personalization, or other purposes for those security records
  without new evidence. Styling content separately uses Product Personalization as proposed in the
  12 September review.
- [x] Verify the separation and ordering of Delete Server Security Data, Delete Local Data, and app
  deletion against the deployed backend. Build 4's proof remained available after build 5 appeared
  installed in place unexpectedly; server deletion produced exactly one success marker and `0/0/0` live
  installations/sessions/challenges before local data and then the app were deleted. Build 5 was
  subsequently installed cleanly. The final-candidate deletion/reinstall proof is recorded below.
- [x] Retain the complete transition history without claiming migration. The intermediate
  development build completed Disconnect Google and local deletion, and no live production
  identity existed before its uninstall. Build 4 was then installed cleanly from processed
  TestFlight. Its proof later remained available after build 5 appeared installed in place
  unexpectedly; after the eligible `2026-08-22T07:33:23Z` created/14-day snapshot, assertion-
  verified server deletion produced exactly one success marker and `0/0/0` live aggregates. Local
  data and the app were deleted, then build 5 was clean-installed. Build 6 later appeared in place
  unexpectedly, but the inherited build-5 proof likewise remained available. After the eligible
  `2026-08-23T07:34:23Z` snapshot, server deletion returned aggregates to `0/0/0`; local data and
  the app were deleted; and build 6 was installed cleanly. The eligible
  `2026-08-25T07:35:53Z` snapshot later enabled Build 6's final owner-controlled handoff. The
  pre-deletion aggregate was `1/0/0`; server deletion produced exactly one bounded marker; and
  post-deletion/post-uninstall aggregates were `0/0/0`. Clean reinstall, first launch, local item
  additions, and styling consent remained at zero. Explicit Style at `2026-08-28 17:17 SGT`
  enrolled one new anonymous installation and active session, with zero pending/failed challenges,
  one completed challenge, and one bounded registration marker. Signed runtime fields remained
  absent on iOS 26.6, so this is not iOS 27+ category/build enforcement evidence.
- [x] Retain clean build-5 privacy/failure evidence through notification delivery: no login and an
  empty wardrobe at first launch; offline Demo Mode; Camera and Photo Library saves; the full local
  catalog flow; `16:30` registration; cached relaunch; `17:04` assertion renewal; cached-look
  preservation after failed offline Restyle; offline Wear this/History; and local notification
  delivery. Tapping the notification at `2026-08-22T17:15:14+08:00` crashed. Exact-dSYM safe
  symbolication showed `SIGABRT`, a UIKit state-restoration assertion, and an app frame in the
  `DailyReminderNotificationRouter` `didReceive` async bridge. Build 5 is consumed and non-
  promotable. The pre-upload signed-in TestFlight view confirmed build 6 unused; the exact
  production-signed `1.0.0 (6)` archive then passed strict verification, normal-route upload,
  Apple processing, and `Family` Internal Testing assignment.
- [x] Retain clean build-6 privacy/failure proof through the fixed notification route and final
  identity-safe handoff: Gmail-free first launch, empty local state, offline Demo, Camera/Photo
  Library saves, catalog operations, `20:25` registration, `20:45` cold assertion renewal, explicit
  offline cached-look restoration, failed-Restyle preservation, Wear/History, notification delivery,
  notification tap without a crash, and preserved local state passed. The final deletion/reinstall/
  new-enrollment sequence completed on 2026-08-28 using only the coarse evidence above. The
  monitored 25/28 August snapshots were later observed absent from the customer-visible list. The
  10 September Build-7 pre-deletion snapshot's later disappearance and deletion-specific restore/
  non-return were not proven and were owner-waived only for the Free Singapore v1.
- [x] Confirm the build-6 **Allow AI styling** presentation failure. In the 2026-08-28 owner-supplied
  Dark Mode screenshot, the title is approximately 21 points right of center and the sampled
  `#C2DFFC` fill against white is approximately `1.38:1`. Build 6 is non-promotable; the retained
  privacy, identity, and notification evidence remains valid.
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
  [enabled Fly v17 runtime](build8-release-20261016.md) retains
  the verified auth/build allowlist. The later beta-only review and
  [build-7 distribution](internal-testflight-runbook.md#build-7-distribution--2026-09-10) passed;
  Bounded activation is complete; protected-device styling proof passed on 12 September; manual release completed on 23 September; public Singapore storefront availability was confirmed by 14:44Z on 23 September.
- [x] Verify the archive-era recovery reference. At `2026-08-29T03:31:57Z`, fresh private-registry
  authentication re-resolved the exact v10 immutable reference with the expected source identity
  and Linux/AMD64 architecture, and its zero-High/Critical scan passed. The former v6 reference's
  current identity was not independently proven, so it is ineligible; exact v10 was the sole
  recovery reference at that historical checkpoint. The current
  [validated v15 image reference](launch-check-20260923.md)
  is budget-aware and verified to read the existing initialized ledger after restart. Pre-budget v10
  is not a normal rollback target; every later recovery must preserve and reverify that ledger, its
  limits, charges and uncertainty.
- [x] Complete the build-7 exact-source regression. Clean synchronized main
  `f183f074d1a63a4ec46d6d34fa13979a2c8b1fdd` passed 222 backend tests plus
  audit/Bandit/Ruff/mypy, 226 Swift unit tests, all 9 UI tests, 43 release-script tests, and the
  Release simulator/artifact gates.
- [x] Repeat the full operations/recovery review immediately before archive and strictly verify the
  distinct final archive. The exact-v10 review, including a fresh private-registry match and zero-
  High/Critical Docker Scout scan, completed at `2026-08-29T11:02:18Z`; the final archive was
  created at `11:03:10Z` and verified at `11:04:02Z`. The `04:21:50Z` review and `07:15:57Z`
  archive are timing-stale/non-uploadable; the earlier development-signed archive is separately
  invalid/non-uploadable.
- [x] Complete build-7 internal distribution after the beta-only operations review and separate
  owner approval. Normal-route validation/upload and processing passed on 10 September;
  `1.0.0 (7)` is assigned only to `Family` Internal Testing with one group tester and no individual
  testers, and the approved AI-disabled notes persisted after reload. See the
  [distribution checkpoint](internal-testflight-runbook.md#build-7-distribution--2026-09-10).
  Build 7 is consumed; distribution alone does not close the remaining privacy requirements.
- [x] Complete build-7 handoff, clean installation and scoped local-beta QA. The
  [11 September checkpoint](internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial)
  records the completed owner-controlled sequence and normal-state Dark Mode screenshot.
  Automated tests cover enabled/pressed/disabled contrast; retain unchanged device evidence.
  Do not repeat deletion, uninstall or routine QA. AI activation and public submission remain separate.
