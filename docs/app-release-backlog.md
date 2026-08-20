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

Last updated: **2026-08-20**. This table is authoritative when an item's original scope label
below still says “Now.” “Done” means the whole item is complete; partial work is deliberately
kept “In progress.”

| Items | Status | Verified branch outcome |
|---|---|---|
| APP-001–APP-008, APP-010 | **Historical / done** | Completed earlier Gmail-capable implementation work remains valuable history, but APP-036 supersedes its Gmail/OAuth/receipt-import release scope. Preserve applicable security/deletion guarantees while using the separately approved clean-uninstall transition |
| APP-009 | **External gate** | Repository enforcement, the pre-APP-036 v5 policy-image deployment, an isolated read-only snapshot-restore rehearsal, and the first payload-free manual operations review are complete. The owner accepted Fly's fixed seven-day customer-visible logs, undisclosed provider-internal in-service retention, listing-only 14-day snapshot boundary, and slower manual operations for the personal single-user release. The Gmail-free replacement image, snapshot-list expiry, deletion-specific recovery, and signed archive/TestFlight proof remain open |
| APP-011 | **In progress** | Product identity, Debug/Release split, unused build 4, Gmail-free Release configuration, public URLs, Team ID, and simulator absence guards are verified; the signed production archive/profile remains open |
| APP-012 | **In progress** | Google and its transitive packages are removed from the generated project and verified simulator artifact; repeat the absence/privacy-manifest proof against the signed archive |
| APP-013 | **Done** | The deterministic offline tour now uses fictional manual/photo data, never opens the production store, and never calls connected AI; its Today/History/catalog flow passed UI automation |
| APP-014 | **In progress** | All nine Gmail-free simulator UI flows pass, covering local/demo, styling, reminders, history, deletion, offline/relaunch, and removed-capability absence; mandatory physical clean-uninstall/fresh-install QA remains open |
| APP-015 | **Done** | Full backend/Swift/UI tests, shared-contract routing, Release build, public-config guard, and embedded privacy-manifest artifact checks are active |
| APP-016 | **In progress** | The owned-domain privacy/support/Terms pages are live, but they still describe the earlier Gmail-capable build. Gmail-free local revisions are prepared; republish, verify signed out, reconcile providers/App Privacy, and finish store answers |
| APP-017–APP-019 | **Submission / later milestone** | App Store Connect confirms build 3 is the highest upload, so `1.0.0 (4)` remains the unused Gmail-free candidate. After APP-036 and all binary/config gates, upload through **TestFlight & App Store**, distribute internally, and retain clean-device evidence |
| APP-020–APP-022 | **Historical / partial carry-forward** | Manual add/edit, favorites, archive, filters, and catalog polish carry forward. Imported-item/review/account-scope behavior is historical and is removed through APP-036's owner-approved clean reset |
| APP-023 | **Done** | Today is explicit-action-only, device-local daily looks survive offline/relaunch, occasion input is bounded, refreshes serialize/cancel safely, and wear recording is idempotent/transactional |
| APP-024–APP-028 | **Done / pending** | Outfit History, local insights, 1–5 feedback, preference-aware styling, accessibility-size layouts, friendly bounded states, and branded launch/first-run are done; broader localization remains APP-028 |
| APP-029–APP-035 | **Deferred / pending** | Receipt extraction and Gmail History work (APP-029/030) are deferred beyond public v1. Insights, backup, imagery, localization, and widgets remain independent future enhancements |
| APP-036 | **In progress** | Gmail/Google/OAuth/receipt import is removed from the repository candidate and verified simulator artifact. The old-build cleanup, clean install, Gmail-free Pages republish, immutable backend replacement, signed archive, and TestFlight proof remain open |

Pre-APP-036 build-4 policy-enforcement baseline: **455 iOS tests** total (**443 Swift tests plus 12
end-to-end UI tests**), **237 backend tests**, locked dependency audit with no known vulnerabilities,
Bandit, Ruff, mypy, and **23/23** release-script tests all passed.

Current post-APP-036 repository-candidate proof: **209 unique iOS tests** passed (**200 Swift tests
plus all 9 UI flows**), **202 backend tests** passed, the locked dependency audit found no known
vulnerability, Bandit/Ruff/mypy passed, and **24/24** release-script tests passed. A clean Release
simulator artifact for `1.0.0 (4)` passed public configuration, plist, signature, dependency, and
removed-capability checks; source, generated project, executable, and bundle scans found no
Google/Gmail/OAuth, `/extract`, or receipt-background capability. This proof is from an unmerged
working tree, not the signed distribution archive. Live App Store Connect inspection confirms build
3 is the highest upload, so `1.0.0 (4)` remains unused and selected. Record the final merged SHA and
repeat the signed-archive checks before uploading.

The Gmail-free backend source is tested but not deployed. Production Fly release v5 still serves
the pre-APP-036 image and `/extract`; build, scan, push, and deploy the exact merged Gmail-free
`linux/amd64` image before using build 4.
Fly release v5 serves the policy-enforced `linux/amd64` image from `main`
`7b6acb83960e2cd69458489ab5f5fe0e04cd9f85` at immutable digest
`sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`.
Its local and registry scans found no critical/high vulnerability across 90 packages. The retained
App-Attest-only rollback digest is
`sha256:f4758e08046e187161b992ad34530c3c41c89375c9277522015628ec9306eef1`.

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
- [x] **Build, scan, and deploy the policy-enforced backend.** Fly v5 serves only immutable digest
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
  approved fresh local schema. The full backend and iOS regressions and release-script suite pass.
- [x] **Configure the simulator portion of APP-011.** Gitignored `Distribution.xcconfig` contains
  only the HTTPS backend, live public links, and Team ID; resolved Release settings and the clean
  simulator artifact prove Google/Gmail/receipt-import configuration is absent.
- [x] **Choose candidate metadata from external truth.** Live App Store Connect inspection confirms
  build 3 is the highest uploaded build, so `1.0.0 (4)` remains unused and selected for the
  Gmail-free candidate. Keep the App Attest allowlist at build 4 unless a later upload changes the
  external fact; do not upload before APP-036 and all remaining gates pass.
- [ ] **Freeze and publish the Gmail-free candidate source.** Review the combined diff, rebase it
  onto current `origin/main`, retain the green gates, publish it through a reviewable PR, merge it,
  synchronize local `main` by fast-forward, and record the exact merged SHA. Do not build or deploy
  a release image from this unmerged working tree.
- [ ] **Complete APP-036's pre-upload production cutover.** On the old build, complete **Disconnect
  Google** and **Delete Server Security Data** and wait for both successes, then uninstall the old
  local wardrobe. From the exact merged SHA, build/scan/push/deploy the Gmail-free immutable
  `linux/amd64` image, prove production `/extract` is retired, and repeat the payload-free manual
  operations review. Do not install build 4 yet; it must come from processed TestFlight.
- [ ] **Complete APP-011's signed device-archive proof.** Freeze the merged source, create the
  production-signed archive, and verify its App Attest entitlement, embedded profile, public
  configuration, privacy manifests, and removed-capability absence.
- [ ] **Close the publication portion of APP-016.** The final owned-domain
  privacy/support/Terms URLs are live and previously verified with the earlier product copy.
  Republish the locally prepared Gmail-free revisions, verify all three while signed out, and
  reconcile their claims with current Anthropic/Fly/Apple terms, the App Privacy inventory, and
  final App Store Connect answers.
- [ ] **Run and upload the candidate.** Follow
  [`internal-testflight-runbook.md`](app-store/internal-testflight-runbook.md): complete regression,
  signed archive/profile inspection, validation, normal **TestFlight & App Store** upload,
  processing review, and internal-group assignment.
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
    the pre-App-Attest shared-token build must be rejected on every OS.
  No public build is releasable with the shared bearer or an in-memory-only production auth store.
- [x] **APP-010 · Done · Restrict remote images.** Do not load arbitrary model-derived URLs. Apply
  HTTPS-only validation, a conservative host policy, bounded image decoding/caching, and a safe
  placeholder.

## P0 — release and App Review readiness

- [ ] **APP-011 · In progress · Align product identity and release configuration.** Use “Wardrobe
  Stylist” consistently in the app, help text, public pages, and store copy. Split development and
  production configuration. A Release archive must fail if required HTTPS endpoints, policy/
  support URLs, or Apple signing identifiers are absent; it must also prove no shared backend
  credential, Google Sign-In SDK/client configuration, Gmail permission/route, receipt-import
  client path, or receipt background task is embedded. The Apple Team/App ID capability, App
  Attest entitlement, backend URL, and accepted release build must match the deployment/archive.
- [ ] **APP-012 · In progress · Pin/audit dependencies and archive privacy metadata.** Historical
  work pinned and audited Google Sign-In. For the Gmail-free candidate, remove that SDK and its
  transitive bundles, keep only actually integrated dependencies/privacy manifests, and make the
  artifact verifier fail if Google/AppAuth/GTM components remain.
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
  full locked pytest/pip-audit/Bandit/Ruff/mypy plus Swift test regressions.
- [ ] **APP-016 · In progress · Prepare accurate public-facing documents.** Republish the live
  privacy/support/Terms pages for the Gmail-free candidate and reconcile the backend, Anthropic,
  Apple, Fly, purposes, retention, styling-consent withdrawal, deletion, security, contact, and
  changes. Remove Gmail/Google/Limited Use/receipt-import claims. Do not publish unverified
  retention or “no training” claims.
- [ ] **APP-017 · Submission · Complete the App Store Connect record.** Final name/bundle ID/SKU,
  category, content rights, age rating, DSA status, privacy nutrition labels, support/privacy
  URLs, description, keywords, copyright, review contact, review notes, build, pricing/tax,
  availability, export compliance, release method, agreements, and any EU trader information.
- [ ] **APP-018 · Submission · Produce final store media.** Supply 1–10 screenshots per required
  device class using fictional/demo data, plus optional preview video. The narrative should show
  manual/photo wardrobe building, editing/organization, Today, History, and privacy controls. It
  must not show or imply Google, Gmail, receipt import, or a login.
- [ ] **APP-019 · Submission · Final distribution verification.** Use the confirmed unused
  candidate `1.0.0 (4)`. Archive with the currently required Xcode/iOS SDK;
  validate and upload using
  **TestFlight & App Store** rather than **TestFlight Internal Only**; distribute the processed
  build to the internal group; test the approved clean-uninstall transition and fresh install on a
  physical device; retain the
  evidence needed to promote that same binary; keep backend health available through review.
- [ ] **APP-036 · In progress · Cut Gmail-free public v1.** Google Sign-In, Google client/callback
  configuration, Gmail scope/network code, receipt-import UI/pipeline/background scheduling, and
  the `/extract` client from the shipped app. Build 4 uses a fresh local-only schema and is never
  installed over builds 1–3. The user accepted losing the old local wardrobe and re-adding items.
  On the old build, complete **Disconnect Google**, then **Delete Server Security Data**, wait for
  both to succeed, uninstall, and only then install build 4. Make an explicit old-build backend
  retirement decision. Update in-app disclosures, Demo Mode, public pages, App
  Privacy answers, review notes, metadata, screenshots, and Release checks. The final archive must
  prove the removed capability is absent. This iOS behavior/configuration change requires a new
  TestFlight build and the full regression/release-artifact/physical-device loop. Repository,
  simulator-artifact, and full-regression work is complete; the old-build cleanup, production
  backend cutover, public-page republish, signed archive, and processed TestFlight proof remain.

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
