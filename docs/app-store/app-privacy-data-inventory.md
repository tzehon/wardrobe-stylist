# App Privacy data inventory

This inventory drives the in-app disclosure, public privacy policy, Apple App Privacy answers,
deletion implementation, request-capture tests, and processor contracts for the approved
Gmail-free public v1. “Collected” below uses Apple's App Privacy concept. Final App Store Connect
publication and any later provider, purpose, or data-flow change still require review. Historical
Gmail/receipt-import data categories are intentionally excluded because the signed v1 must not
contain or invoke that capability.

| Data / source | On-device use | Leaves device? | Recipient / purpose | Intended retention | Consent / control | Apple answer status |
|---|---|---:|---|---|---|---|
| Wardrobe item attributes | Catalog + styling | Yes for AI styling | Backend → Anthropic outfit recommendation | Developer application: request lifetime only, no persistence; verify Anthropic/provider terms | Styling consent | Likely “Other User Content” if retained; pending |
| Wardrobe photos | Catalog display | No in v1 styling path | Local app | Until item/local-data deletion | Photo picker/camera; delete | Not collected if device-only |
| Purchase date/price/currency | Catalog/review/insights | No in v1 styling | Local app | Until item/local-data deletion | Review/edit/delete | Not collected if device-only |
| Outfit and wear history | Anti-repeat/history and explicit 1–5 feedback | Recent item IDs and bounded per-item rating summaries (item ID, average, count) leave for styling; no feedback free text or wear dates | Backend → Anthropic recommendation | Developer application: request lifetime only, no persistence; local history until delete; verify Anthropic/provider terms | Styling consent; delete | Pending retention interpretation |
| Occasion/context text | User-directed recommendation | Yes | Backend → Anthropic recommendation | Developer application: request lifetime only, no persistence; verify Anthropic/provider terms | Styling consent; user submits | “Other User Content” if retained; pending |
| App Attest key ID, verified public key, opaque Apple attestation receipt, anonymous installation ID and assertion counter | Prove a genuine installation and renew backend access without a Wardrobe account | Key ID/attestation/assertions leave; private key never leaves Secure Enclave | Apple App Attest certification → developer backend authentication/security store | Repository limits: 90 days after last successful use; revoked records 30 days; an assertion-verified deletion request synchronously removes the live installation. Encrypted snapshots stop appearing from Fly's customer listing after 14 days; all-copy purge timing is undisclosed and owner-accepted. Production retention enforcement and Fly v9's targeted payload-free auth-service INFO logger are deployed and runtime-verified; the production TestFlight allowlist configuration for builds `4,5,6` is deployed and deployment-verified only. Physical iOS 26.6 evidence shows the expected signed runtime-field absence and does not prove iOS 27+ category/build enforcement. The required v9 post-deploy/pre-upload review was missed and is not backdated; the late full review passed at `2026-08-23T02:13:12Z`. The build-4 and build-5 identity-safe handoffs each reached aggregate zero before local/app deletion. Build 6's final handoff used the eligible `2026-08-25T07:35:53Z` snapshot: the pre-deletion aggregate was `1/0/0`, exactly one bounded deletion marker was observed, and post-deletion/post-uninstall aggregates were `0/0/0`. Clean reinstall and local-only actions remained at zero; explicit Style at `2026-08-28 17:17 SGT` created a new anonymous installation and active session. Listing expiry and deletion-specific restore/non-return remain APP-009 work. Independent Apple-receipt validation/risk-metric policy remains pending. | **Settings → Privacy & Data → Delete Server Security Data** uses a fresh App Attest assertion; reinstall creates a new identity but does not delete the old row | Device ID, App Functionality, linked, not tracking; publish only after final App Store Connect review |
| One-time App Attest challenges, hashed short-lived sessions and coarse rate windows | Replay prevention, authorization, quotas and abuse prevention | Yes | Developer backend security store | Repository maxima: challenge 70 minutes from issue; session hash 20 minutes from issue; rate-window hash five minutes after its one-minute/hourly window, enforced by the deployed one-minute maintenance loop and request-time expiry cleanup | Automatic expiry; a verified server deletion removes current-secret-derived key/installation rows, while unlinkable pre-rotation HMAC rows expire within 65 minutes | Device ID and Other Diagnostic Data; App Functionality; linked; not tracking. Final App Store Connect publication pending |
| IP address, request path/ID and timing | Network delivery/security | Inherent | Host/backend abuse prevention | Raw IP is not stored in SQLite and application access logs are disabled. Fly's customer-visible platform/proxy stream can contain path, request ID and client IP for a fixed seven days. Separate operational/abuse logs can contain source IP with undisclosed, non-configurable in-service retention. The owner accepted this provider boundary on 2026-08-19. | Public policy; remote features are optional | Conservatively: Device ID, Other Diagnostic Data and Product Interaction; App Functionality; linked; not tracking. Final App Store Connect publication pending |
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
  path, receipt-import UI, or receipt-background-task identifier. The exact build-6 source guards,
  strict signed-archive verifier, and separate non-emitting credential/removed-capability scan
  passed for `Wardrobe-1.0.0-6-de7c540-appstore.xcarchive`.
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
- [ ] Reconfirm Fly.io region and encrypted storage; observe the configured 14-day snapshot-list
  disappearance and complete deletion-specific recovery against the final deployment. The secret-
  free, non-serving restore path and immediate temporary-resource cleanup passed on 2026-08-19.
  The eligible `2026-08-25T07:35:53Z` snapshot enabled the completed build-6 live deletion,
  reinstall, and new enrollment, but actual listing expiry and deletion-specific restore/non-return
  are still unobserved. All-copy purge timing is explicitly accepted as undisclosed.
- [x] Confirm the exact build-6 signed archive's production App Attest App ID prefix, App Store
  profile/certificate match, and scalar production entitlement. The strict verifier matched the
  prefix, team, bundle, certificate, and production grant; `get-task-allow` is false and no
  devices/all-devices are provisioned.
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
- [ ] Rehearse deletion-specific restore/recovery behavior against the final deployment.
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
  emergency pre-build-4 abort only; v6 is the retained Gmail-free recovery baseline.
- [ ] Confirm Anthropic API retention, training/model-improvement, human access, subprocessors and
  contract configuration in writing.
- [ ] Match every item above to the exact in-app notice and public policy wording.
- [ ] Complete Apple App Privacy answers based on actual retention, linkage and tracking—not on
  whether content merely passes through a content-stateless endpoint. Assess the anonymous App
  Attest installation identifier and retained IP as Device ID, retained provider operational/error
  records as Other Diagnostic Data, and retained request paths as Product Interaction. Use App
  Functionality, linked, and not tracking on the current evidence; do not select location,
  analytics, advertising, marketing, personalization, or other purposes without new evidence.
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
  new-enrollment sequence completed on 2026-08-28 using only the coarse evidence above. Snapshot-
  list expiry and deletion-specific restore/non-return remain open.
- [x] Confirm the build-6 **Allow AI styling** presentation failure. In the 2026-08-28 owner-supplied
  Dark Mode screenshot, the title is approximately 21 points right of center and the sampled
  `#C2DFFC` fill against white is approximately `1.38:1`. Build 6 is non-promotable; the retained
  privacy, identity, and notification evidence remains valid.
- [x] Complete and verify the replacement control implementation. PR #31 rebase-merged app commit
  `b7e46e4` to clean `main` `e4a0ae2`. The title-only control is centered, full-width, and opaque;
  enabled/pressed/disabled contrast coverage and the screenshot UI assertion passed. Merged
  verification retained 221 backend tests plus audit/Bandit/Ruff/mypy, 226 Swift unit tests, all
  9 UI tests, and 43 release-script tests; both GitHub iOS checks are green.
- [ ] Distribute only a newly numbered replacement after a fresh signed-in App Store Connect check
  proves the next build unused. Do not name or select the replacement number before that check;
  repeat the complete release loop.
- [ ] Clean-install the processed replacement and physically retest title centering, icon-slot
  absence, and enabled/pressed/disabled legibility in Dark Mode before promotion.
