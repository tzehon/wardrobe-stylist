# App distribution, polish, and feature backlog

This is the implementation source of truth for turning the current personal TestFlight build
into a public App Store product. It deliberately separates work we can complete in this
repository from Google Cloud and App Store Connect work that needs an external account or a
policy decision. The Google-specific order lives in
[`gcp-oauth-production-sequence.md`](gcp-oauth-production-sequence.md). Every beta now follows the
[`internal TestFlight, always App-Store-ready`](app-store/internal-testflight-runbook.md) runbook:
the tester group is internal, but the archive and upload remain eligible for later App Review.

Statuses:

- **Now** — part of the current `codex/app-store-readiness` implementation branch.
- **Done** — implemented, focused-tested, and included in a complete regression on this branch.
- **In progress** — a safe foundation is committed, but one or more acceptance details remain.
- **GCP gate** — coordinated code is specified here, but the production identity/policy choice
  must be completed in the Google sequence before it can be finished safely.
- **Submission** — repository assets/checks can be prepared now; the final action happens in
  App Store Connect.
- **Enhancement** — product improvement that is valuable but does not by itself unblock review.

## Progress snapshot

Last updated: **2026-08-16**. This table is authoritative when an item's original scope label
below still says “Now.” “Done” means the whole item is complete; partial work is deliberately
kept “In progress.”

| Items | Status | Verified branch outcome |
|---|---|---|
| APP-001–APP-008, APP-010, APP-012 | **Done** | Local-first shell; versioned consent; complete Privacy & Data controls; default-off reminder/background work; restored-scope validation; transactional persistence; V2 account isolation; minimized/deduplicated receipt import; bounded remote images; pinned SDK/privacy manifests |
| APP-009 | **GCP gate** | Public-client bearer removal is intentionally blocked on the production identity decision; the Release archive guard refuses the legacy key |
| APP-011 | **In progress** | Product display name, Debug/Release config split, HTTPS/public-link/OAuth guards are committed; final URLs/IDs and bearer removal remain external/GCP work |
| APP-013 | **Done** | Reviewer launch and in-app entry use a labeled, disposable, offline seven-item tour with a synthetic pending import and worn look; reviewer launch does not open or migrate the production store; reset/exit preserve real data |
| APP-014 | **Done** | Eleven deterministic UI flows cover local onboarding, offline demo/edit/delete/reset, pending-import review, History, the simplified Settings hub, disclosures, reminder time, sign-out, disconnect, and verified local deletion; connected tests use deny-network fakes |
| APP-015 | **Done** | Full backend/Swift/UI tests, shared-contract routing, Release build, public-config guard, and embedded privacy-manifest artifact checks are active |
| APP-016 | **In progress** | Accurate data inventory, privacy/support/review drafts exist; final owned-domain publication, contact details, retention verification, and store answers remain |
| APP-017–APP-019 | **Submission / next milestone** | Use the always-ready internal TestFlight lane: finish the binary/config gates, choose the next unused build in App Store Connect, upload through **TestFlight & App Store**, distribute only to an internal group, and retain clean-device evidence |
| APP-020–APP-022 | **Done** | V3 migration, pending-import confidence review, one validated add/edit/review form, favorites, archive, duplicate cues, useful filters, and individual/bulk acceptance are implemented and account-scoped |
| APP-023 | **Done** | Today is explicit-action-only, account-scoped daily looks survive offline/relaunch, occasion input is bounded, refreshes serialize/cancel safely, and wear recording is idempotent/transactional |
| APP-024–APP-028 | **Done / pending** | Outfit History, local insights, 1–5 feedback, preference-aware styling, accessibility-size layouts, friendly bounded states, and branded launch/first-run are done; broader localization remains APP-028 |
| APP-029–APP-035 | **Pending / in progress** | JSON-LD-first minimized import, resumable per-account ledgering, and the first local insights are live; OCR routing, Gmail History execution, richer preferences/insights, backup, imagery tools, and widgets remain |

Latest integrated verification: **400 iOS tests** total (**389 Swift tests plus 11 end-to-end UI
tests**), **71 backend tests**, Ruff, mypy, **10/10** public Release configuration tests, a
Release-simulator build, and artifact checks for GoogleSignIn 9.2.0, the app privacy manifest,
branded launch/icon assets, required plist values, and 10 SDK privacy manifests all passed. That
scope was merged by PR #7 to `main` at `f2a02825fd4178478bfc130525463165f12d648c`; the merge did
not change build/version metadata or upload/deploy a candidate.

## Immediate next milestone — internal TestFlight candidate

These items are ordered. Do not archive early and plan to repair the same binary later.

- [x] **Publish the candidate source.** PR #7 merged the reviewed `codex/app-store-readiness`
  scope to `main` at `f2a02825fd4178478bfc130525463165f12d648c`.
- [ ] **Close APP-009 and the production-client portion of APP-011.** Complete the per-user backend
  identity cutover, remove `BackendDeviceToken` from the bundle, deploy the compatible backend,
  and populate the production Google IDs, HTTPS endpoint, public links, and Team ID in the
  gitignored distribution configuration.
- [ ] **Close the publication portion of APP-016.** Publish and verify the final privacy/support
  pages and reconcile their claims with the code, Anthropic terms, Google Limited Use, and App
  Privacy inventory.
- [ ] **Choose candidate metadata from external truth.** Check the highest uploaded build in App
  Store Connect, select the next unused `CURRENT_PROJECT_VERSION`, and decide whether the next
  candidate should use public version `1.0.0` so the exact internal build can later be promoted.
- [ ] **Run and upload the candidate.** Follow
  [`internal-testflight-runbook.md`](app-store/internal-testflight-runbook.md): complete regression,
  signed archive, validation, normal **TestFlight & App Store** upload, processing review, internal
  group assignment, upgrade/clean-device QA, and retained release evidence.

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
- [ ] **APP-009 · GCP gate · Remove the shared backend bearer from the public client.** A token in
  `Info.plist` is extractable, even if moved to Keychain. Replace it with short-lived per-user
  authorization verified by the backend, rate limits, quotas, monitoring, and an old-build
  retirement plan. The concrete issuer/audience configuration depends on the production OAuth
  architecture in the Google sequence. No public build is releasable with the shared bearer.
- [x] **APP-010 · Done · Restrict remote images.** Do not load arbitrary model-derived URLs. Apply
  HTTPS-only validation, a conservative host policy, bounded image decoding/caching, and a safe
  placeholder.

## P0 — release and App Review readiness

- [ ] **APP-011 · In progress · Align product identity and release configuration.** Use “Wardrobe
  Stylist” consistently in the app, OAuth screen, help text, and store copy. Split development
  and production configuration. A Release archive must fail if required non-secret identifiers,
  HTTPS endpoints, policy/support URLs, or URL schemes are absent; it must also prove no shared
  backend credential is embedded.
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
  full pytest/Ruff/mypy plus Swift test regressions.
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
- [ ] **APP-019 · Submission · Final distribution verification.** Confirm the latest App Store
  Connect build before choosing the next build number; decide whether the public marketing
  version is `1.0.0`; archive with the currently required Xcode/iOS SDK; validate and upload using
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
cd backend && uv run pytest && uv run ruff check . && uv run mypy app

cd ios && xcodegen generate
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Before calling the branch public-release-ready, also complete a clean simulator UI run, physical
device permission/auth QA, a signed Release archive/validation, request-capture privacy tests,
and the external gates in the Google and App Store submission sequences.

## Current external references

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple required App Store Connect properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)
- [Apple App Privacy guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple submission flow](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
