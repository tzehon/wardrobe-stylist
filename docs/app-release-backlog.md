# App distribution, polish, and feature backlog

This is the implementation source of truth for turning the current personal TestFlight build
into a public App Store product. It deliberately separates work we can complete in this
repository from Apple Developer, Fly.io, Google Cloud, and App Store Connect work that needs an
external account or verified production fact. The Google-specific order lives in
[`gcp-oauth-production-sequence.md`](gcp-oauth-production-sequence.md). Every beta now follows the
[`internal TestFlight, always App-Store-ready`](app-store/internal-testflight-runbook.md) runbook:
the tester group is internal, but the archive and upload remain eligible for later App Review.

Statuses:

- **Now** — part of the current implementation tranche.
- **Done** — implemented, focused-tested, and included in a complete regression on this branch.
- **In progress** — a safe foundation is committed, but one or more acceptance details remain.
- **External gate** — repository work is specified here, but Apple Developer, Fly.io, Google
  Cloud, policy, or release facts must be completed and evidenced before the item can close.
- **Submission** — repository assets/checks can be prepared now; the final action happens in
  App Store Connect.
- **Enhancement** — product improvement that is valuable but does not by itself unblock review.

## Progress snapshot

Last updated: **2026-08-20**. This table is authoritative when an item's original scope label
below still says “Now.” “Done” means the whole item is complete; partial work is deliberately
kept “In progress.”

| Items | Status | Verified branch outcome |
|---|---|---|
| APP-001–APP-008, APP-010, APP-012 | **Done** | Local-first shell; versioned consent; complete Privacy & Data controls; default-off reminder/background work; restored-scope validation; transactional persistence; V2 account isolation; minimized/deduplicated receipt import; bounded remote images; pinned SDK/privacy manifests |
| APP-009 | **External gate** | Repository enforcement, final policy-image deployment, and an isolated read-only snapshot-restore rehearsal are complete. The owner accepted Fly's fixed seven-day customer-visible logs, undisclosed provider-internal in-service retention, listing-only 14-day snapshot boundary, and slower manual operations for the personal single-user release. The first manual review, snapshot-list expiry, deletion-specific recovery, and signed archive/TestFlight proof remain open |
| APP-011 | **In progress** | Product identity, Debug/Release split, guards, compatible production backend, and build-4 allowlist are ready; `Distribution.xcconfig`, production Gmail IDs, Team ID, public URLs, and signed archive remain open |
| APP-013 | **Done** | Reviewer launch and in-app entry use a labeled, disposable, offline seven-item tour with a synthetic pending import and worn look; reviewer launch does not open or migrate the production store; reset/exit preserve real data |
| APP-014 | **Done** | Twelve deterministic UI flows cover local onboarding, offline demo/edit/delete/reset, pending-import review, History, the simplified Settings hub, disclosures, reminder time, sign-out, disconnect, separate server-security deletion, and verified local deletion; connected tests use deny-network fakes |
| APP-015 | **Done** | Full backend/Swift/UI tests, shared-contract routing, Release build, public-config guard, and embedded privacy-manifest artifact checks are active |
| APP-016 | **In progress** | Accurate data inventory and privacy/support/review drafts exist; final owned-domain publication, legal owner/effective date, processor/DPA terms, and store answers remain |
| APP-017–APP-019 | **Submission / next milestone** | Candidate `1.0.0 (4)` is selected; finish binary/config gates, upload through **TestFlight & App Store**, distribute only to an internal group, and retain clean-device evidence |
| APP-020–APP-022 | **Done** | V3 migration, pending-import confidence review, one validated add/edit/review form, favorites, archive, duplicate cues, useful filters, and individual/bulk acceptance are implemented and account-scoped |
| APP-023 | **Done** | Today is explicit-action-only, account-scoped daily looks survive offline/relaunch, occasion input is bounded, refreshes serialize/cancel safely, and wear recording is idempotent/transactional |
| APP-024–APP-028 | **Done / pending** | Outfit History, local insights, 1–5 feedback, preference-aware styling, accessibility-size layouts, friendly bounded states, and branded launch/first-run are done; broader localization remains APP-028 |
| APP-029–APP-035 | **Pending / in progress** | JSON-LD-first minimized import, resumable per-account ledgering, and the first local insights are live; OCR routing, Gmail History execution, richer preferences/insights, backup, imagery tools, and widgets remain |

Latest policy-enforcement branch verification: **455 iOS tests** total (**443 Swift tests plus 12
end-to-end UI tests**), **237 backend tests**, locked dependency audit with no known vulnerabilities,
Bandit, Ruff, mypy, and **23/23** release-script tests all passed. Candidate `1.0.0 (4)` remains
selected. The final `main` archive source is not frozen; record its merged SHA before archiving or
uploading.
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
  quotas, and retains only a time-bounded legacy bridge for deployment migration. Google remains
  an optional Gmail connection and is not the Wardrobe backend identity.
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
- [ ] **Verify APP-009 production operations externally.** Retain the redacted Fly response and
  owner decisions, perform the payload-free manual production review, then prove the observable
  14-day snapshot-list disappearance, restore-after-deletion handling, and monitored support
  routing. An isolated,
  secret-free, read-only restore of the 2026-08-19 snapshot passed SQLite integrity/schema checks
  using aggregate-only evidence, and its temporary volume/app disappeared from the control plane
  within 391 seconds of volume creation; this does not yet prove deletion-specific recovery. The
  accepted boundary records the customer-visible stream as seven days and provider-internal
  retention/all-copy snapshot purge timing as undisclosed; do not substitute those accepted
  unknowns for the remaining observable operations evidence.
- [ ] **Complete the production-client portion of APP-011.** Populate production Gmail IDs, HTTPS
  endpoint, public links, and Team ID in gitignored `Distribution.xcconfig`, then pass the signed
  device-archive guards.
- [ ] **Close the publication portion of APP-016.** Publish and verify the final privacy/support
  pages and reconcile their claims with the code, Anthropic terms, Google Limited Use, and App
  Privacy inventory.
- [x] **Choose candidate metadata from external truth.** Candidate `1.0.0 (4)` is selected so the
  exact internal binary can later be promoted.
- [ ] **Run and upload the candidate.** Follow
  [`internal-testflight-runbook.md`](app-store/internal-testflight-runbook.md): complete regression,
  signed archive/profile inspection, validation, normal **TestFlight & App Store** upload,
  processing review, and internal-group assignment.
- [ ] **Complete APP-009 production proof and clean-device QA.** From the processed internal
  TestFlight build, retain production enrollment, assertion renewal, and protected API evidence,
  then finish upgrade/clean-device QA and the complete release-evidence record.

Using an internal tester group does not relax the binary standard. **TestFlight Internal Only** is
not used because Apple prevents that artifact from being submitted to customers later.

## P0 — privacy, security, and trustworthy data handling

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
  identity is one Apple-certified app installation, not a human account: Google remains solely
  the optional `gmail.readonly` connection, and reinstall/migration/restore starts a new Wardrobe
  backend identity. Complete all of the following before marking this item done:
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
  Stylist” consistently in the app, OAuth screen, help text, and store copy. Split development
  and production configuration. A Release archive must fail if required non-secret identifiers,
  HTTPS endpoints, policy/support URLs, or URL schemes are absent; it must also prove no shared
  backend credential is embedded. Google client configuration authorizes only optional Gmail;
  the Apple Team/App ID capability, App Attest entitlement, backend URL, and accepted release
  build must also match the production deployment and signed archive.
- [x] **APP-012 · Done · Pin/audit dependencies and archive privacy metadata.** Pin the Google Sign
  In SDK to a reviewed version, commit a reproducible resolution where practical, and validate
  the exact archive's SDK signatures/privacy manifests. Add an app privacy manifest only for
  required-reason APIs the app actually uses.
- [x] **APP-013 · Done · Give App Review a deterministic product tour.** Add a seeded, offline demo
  mode or equivalent UI-test fixture that exercises Today, wardrobe browsing, item editing, and
  data controls without a reviewer sharing a personal mailbox. It must be visually and
  functionally distinct from real user data and never call Gmail or the backend.
- [x] **APP-014 · Done · Add end-to-end UI coverage.** Cover first launch, skipped Gmail,
  disclosure/consent, demo entry, add/edit/delete item, catalog search/filter, Today states,
  reminder controls, disconnect, and local data deletion. Keep request-capture tests proving no
  network path runs without consent and no prohibited Gmail operation is representable.
- [x] **APP-015 · Done · Strengthen CI/release gates.** Run backend contract tests when `shared/**`
  changes; build/test a Release configuration; run an archive/privacy report guard; and retain
  full locked pytest/pip-audit/Bandit/Ruff/mypy plus Swift test regressions.
- [ ] **APP-016 · In progress · Prepare accurate public-facing documents.** Replace the stale internal
  privacy note with policy-source text covering Google data, the backend, Anthropic, purposes,
  retention, consent withdrawal, deletion, Limited Use, security, contact, and changes. Add
  support/FAQ and App Review notes. Do not publish unverified retention or “no training” claims.
- [ ] **APP-017 · Submission · Complete the App Store Connect record.** Final name/bundle ID/SKU,
  category, content rights, age rating, DSA status, privacy nutrition labels, support/privacy
  URLs, description, keywords, copyright, review contact, review notes, build, pricing/tax,
  availability, export compliance, release method, agreements, and any EU trader information.
- [ ] **APP-018 · Submission · Produce final store media.** Supply 1–10 screenshots per required
  device class using fictional/demo data, plus optional preview video. The narrative should show
  optional Gmail consent, wardrobe building, correction/review, Today, and privacy controls—not
  only a login screen.
- [ ] **APP-019 · Submission · Final distribution verification.** Use candidate `1.0.0 (4)`;
  archive with the currently required Xcode/iOS SDK; validate and upload using
  **TestFlight & App Store** rather than **TestFlight Internal Only**; distribute the processed
  build to the internal group; test upgrade and clean install on a physical device; retain the
  evidence needed to promote that same binary; keep backend health available through review.

## P1 — core experience polish

- [x] **APP-020 · Done · Review and correct imported items.** Receipt-derived entries land in a
  visible review state. Users can edit name, brand, category, color, size, purchase metadata,
  and image before accepting. Surface duplicates and extraction uncertainty instead of silently
  saving an incorrect catalog.
- [x] **APP-021 · Done · Make every item editable.** Reuse one validated item form for manual add,
  import review, and edit. Preserve the existing photo when editing and confirm destructive
  deletion. Show specific save/validation failures.
- [x] **APP-022 · Done · Improve catalog information architecture.** Add clear local/imported and
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
  permissions, include transparent privacy positioning, offer demo/local/Gmail paths, and replace
  the empty launch treatment while preserving fast startup.
- [ ] **APP-028 · Enhancement · Localize user-visible copy.** Start with a complete development
  language catalog and locale-aware dates/times, then choose additional App Store localizations
  based on target markets.

## P2 — feature enhancements after the public-release foundation

- [ ] **APP-029 · In progress · Wire structured receipt extraction end to end.** The repository
  already contains JSON-LD and OCR components; route suitable HTML/PDF/image receipts through
  them before cloud fallback, with confidence and review UI.
- [ ] **APP-030 · In progress · Scalable incremental Gmail sync.** Replace the 1,000-message
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
durable Fly auth-store/deployment evidence, and the external Apple Developer, Google, and App
Store submission gates. Simulator App Attest fakes never replace the physical-device gate.

## Current external references

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple required App Store Connect properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)
- [Apple App Privacy guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple submission flow](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Apple App Attest client integration](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Apple App Attest server validation](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Fly volume persistence and single-machine boundary](https://fly.io/docs/volumes/overview/)
