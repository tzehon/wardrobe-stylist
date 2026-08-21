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

Last updated: **2026-08-21**. This table is authoritative when an item's original scope label
below still says “Now.” “Done” means the whole item is complete; partial work is deliberately
kept “In progress.”

| Items | Status | Verified branch outcome |
|---|---|---|
| APP-001–APP-008, APP-010 | **Historical / done** | Completed earlier Gmail-capable implementation work remains valuable history, but APP-036 supersedes its Gmail/OAuth/receipt-import release scope. Preserve applicable security/deletion guarantees while using the separately approved clean-uninstall transition |
| APP-009 | **External gate** | Repository enforcement, the exact reviewed Gmail-free v7 deployment, its passing post-deploy review, an isolated read-only snapshot-restore rehearsal, and the historical v6 evidence are retained. A fresh pre-upload review, snapshot-list expiry, deletion-specific recovery, and processed-TestFlight proof remain open |
| APP-011 | **Done** | Product identity, Debug/Release split, Gmail-free Release configuration, public URLs, Team ID, and simulator guards are verified. Clean synchronized source `24c17cb` produced the strictly verified replacement Apple Distribution archive for `1.0.0 (4)` after App Store Connect reconfirmed build 4 was unused |
| APP-012 | **Done** | The clean replacement Release artifact and signed archive passed dependency, privacy-manifest, certificate/profile, and removed-capability verification; no Google/Gmail/OAuth/extraction/background component remains |
| APP-013 | **Done** | The deterministic offline tour now uses fictional manual/photo data, never opens the production store, and never calls connected AI; its Today/History/catalog flow passed UI automation |
| APP-014 | **In progress** | All nine Gmail-free simulator UI flows pass, covering local/demo, styling, reminders, history, deletion, offline/relaunch, and removed-capability absence; mandatory physical clean-uninstall/fresh-install QA remains open |
| APP-015 | **Done** | The clean merged-candidate gate passed 219 backend tests, 215 Swift tests, all 9 UI flows, 43 release-script tests, the locked audit/security/type checks, and clean Release/artifact verification |
| APP-016 | **In progress** | The owned-domain Gmail-free privacy/support/Terms pages are published and anonymously verified. Current provider terms, App Privacy reconciliation, and final App Store Connect answers remain open |
| APP-017–APP-019 | **Submission / later milestone** | App Store Connect reconfirmed build 3 highest immediately before the verified replacement `1.0.0 (4)` archive. The pre-upload review, Apple validation/upload/processing, internal distribution, and clean-device evidence remain open |
| APP-020–APP-022 | **Historical / partial carry-forward** | Manual add/edit, favorites, archive, filters, and catalog polish carry forward. Imported-item/review/account-scope behavior is historical and is removed through APP-036's owner-approved clean reset |
| APP-023 | **Done** | Today is explicit-action-only, device-local daily looks survive offline/relaunch, occasion input is bounded, refreshes serialize/cancel safely, and wear recording is idempotent/transactional |
| APP-024–APP-028 | **Done / pending** | Outfit History, local insights, 1–5 feedback, preference-aware styling, accessibility-size layouts, friendly bounded states, and branded launch/first-run are done; broader localization remains APP-028 |
| APP-029–APP-035 | **Deferred / pending** | Receipt extraction and Gmail History work (APP-029/030) are deferred beyond public v1. Insights, backup, imagery, localization, and widgets remain independent future enhancements |
| APP-036 | **In progress** | Gmail/Google/OAuth/receipt import remains removed from the repository candidate and verified replacement archive. The old development build is disconnected, locally cleared, and uninstalled; the exact reviewed Gmail-free backend and public pages are deployed. The processed-TestFlight clean install and physical TestFlight proof remain open |

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
`ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`. The pre-upload
review, Apple validation/upload, processing, and physical TestFlight proof remain open.

The current production baseline is Fly release v7, which serves the exact reviewed source
`d4637f4b2adf14cd533594aec6060c385f8a5e2b` as a `linux/amd64` image at immutable digest
`sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`.
Local and immutable-registry Docker Scout scans each covered 90 packages and found no
critical/high vulnerability. Production health and the Fly service check pass, `/extract` returns
`404`, and unauthenticated `/recommend` returns `401`. Gmail-free v6 digest
`sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
remains the required recovery baseline and also passed a fresh immutable-registry scan. Both exact
v7 and v6 digests resolved after fresh registry authentication at `2026-08-21T06:06:01Z`. Emergency
pre-build-4 rollback digest
`sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17` is
App-Attest-only and scan-clean, but using it would re-expose `/extract` and must halt the release.
The payload-free v7 post-deploy review passed at `2026-08-21T06:00:21Z`; repeat it immediately
before archive upload.

## Immediate next milestone — internal TestFlight candidate

These items are ordered. Do not archive early and plan to repair the same binary later.

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
  simulator artifact. Intentional negative guards and legacy-rate cleanup remain. Build 4 uses the
  approved fresh local schema. The full backend and iOS regressions and release-script suite passed
  for that historical source; rerun them for the merged review-fix candidate.
- [x] **Configure the simulator portion of APP-011.** Gitignored `Distribution.xcconfig` contains
  only the HTTPS backend, live public links, and Team ID; resolved Release settings and the clean
  simulator artifact prove Google/Gmail/receipt-import configuration is absent.
- [x] **Retain the historical candidate-metadata check.** Live App Store Connect inspection before
  the superseded archive found build 3 as the highest uploaded build. Refresh that external fact
  immediately before the replacement archive: keep `1.0.0 (4)` and the App Attest build allowlist
  at 4 only if build 4 is still unused; otherwise stop and select the next unused integer. Do not
  upload before APP-036 and all remaining gates pass.
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
  the payload-free post-deploy manual review passed at `2026-08-21T01:11:43Z`. Do not install build
  4 yet; it must come from processed TestFlight.
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
  synchronized `main` is `d4637f4b2adf14cd533594aec6060c385f8a5e2b`.
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
  Attest, HTTPS public configuration, app privacy manifest, matching dSYM, and Gmail-free/secret-
  absence checks.
- [ ] **Repeat the pre-upload review, then validate and upload only the replacement archive.**
  Follow [`internal-testflight-runbook.md`](app-store/internal-testflight-runbook.md), repeat the
  payload-free manual review against the exact deployed backend and refresh App Store Connect's
  build-upload list immediately before validation/upload. Stop if build 4 is no longer unused;
  otherwise validate, use normal **TestFlight & App Store** upload, wait for processing, and assign
  the processed build to the internal group. The superseded `dd3d990` archives are never upload
  targets.
- [ ] **Complete post-upload APP-009/APP-036 proof and cleanup.** Install build 4 cleanly from the
  processed internal TestFlight build, retain production enrollment/assertion/protected-API and
  physical QA evidence, then prove deletion-specific recovery and the eligible 14-day snapshot-
  list disappearance. After the replacement is proven and with a separate final owner
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
  The `dd3d990` archive is retained only as superseded historical evidence. The verified replacement
  archive is `Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`.
- [x] **APP-012 · Done · Pin/audit dependencies and archive privacy metadata.** Historical
  work pinned and audited Google Sign-In. For the Gmail-free candidate, remove that SDK and its
  transitive bundles, keep only actually integrated dependencies/privacy manifests, and make the
  artifact verifier fail if Google/AppAuth/GTM components remain. Rerun dependency, privacy-
  manifest, and removed-capability verification against the replacement Release artifact and
  signed archive before completing this item. The clean replacement artifact and archive passed.
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
  post-review-fix regression and replacement artifact/archive verification are recorded above.
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
- [ ] **APP-019 · Submission · Final distribution verification.** Use candidate `1.0.0 (4)` only
  if a fresh App Store Connect check immediately before archiving confirms build 4 is still unused.
  Archive with the currently required Xcode/iOS SDK;
  validate and upload using
  **TestFlight & App Store** rather than **TestFlight Internal Only**; distribute the processed
  build to the internal group; test the approved clean-uninstall transition and fresh install on a
  physical device; retain the
  evidence needed to promote that same binary; keep backend health available through review.
- [ ] **APP-036 · In progress · Cut Gmail-free public v1.** Remove Google Sign-In, Google client/callback
  configuration, Gmail scope/network code, receipt-import UI/pipeline/background scheduling, and
  the `/extract` client from the shipped app. Build 4 uses a fresh local-only schema and is never
  installed over builds 1–3. The user accepted losing the old local wardrobe and re-adding items.
  The pre-upload old-build cleanup and production backend retirement are complete: the installed
  intermediate build had no server-deletion UI, but the production auth store contained no live
  identity before it was uninstalled. Install build 4 only from processed TestFlight. The explicit
  old-build backend retirement decision is complete. Update in-app disclosures, Demo Mode, public pages, App
  Privacy answers, review notes, metadata, screenshots, and Release checks. The final archive must
  prove the removed capability is absent. This iOS behavior/configuration change requires a new
  TestFlight build and the full regression/release-artifact/physical-device loop. Repository,
  historical simulator-artifact, regression, production-backend, and signed-archive evidence is
  retained, while the old-build cleanup, reviewed backend deployment, clean current regression,
  replacement signed archive, and public-page work are complete. The clean physical install and
  processed TestFlight proof remain open.

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
- [x] **APP-023 · Done · Polish Today.** Cache a recommendation for the day, let users refresh
  intentionally, accept occasion/context input, explain empty/error/offline states, and never
  make a backend call merely because a tab appeared. Saving “Wear this” must be transactional
  and acknowledged only after persistence succeeds.
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
