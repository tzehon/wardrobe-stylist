# App distribution, polish, and feature backlog

This is the implementation source of truth for turning the current personal TestFlight build
into a public App Store product. It deliberately separates work we can complete in this
repository from Google Cloud and App Store Connect work that needs an external account or a
policy decision. The Google-specific order lives in
[`gcp-oauth-production-sequence.md`](gcp-oauth-production-sequence.md).

Statuses:

- **Now** — part of the current `codex/app-store-readiness` implementation branch.
- **GCP gate** — coordinated code is specified here, but the production identity/policy choice
  must be completed in the Google sequence before it can be finished safely.
- **Submission** — repository assets/checks can be prepared now; the final action happens in
  App Store Connect.
- **Enhancement** — product improvement that is valuable but does not by itself unblock review.

## P0 — privacy, security, and trustworthy data handling

- [ ] **APP-001 · Now · Make the core app local-first.** Gmail connection must be optional.
  A user—and App Review—can add photos, browse the catalog, and understand the product without
  granting mailbox access. Replace the current sign-in gate with a clear tab shell, onboarding,
  and an optional “Connect Gmail” path.
- [ ] **APP-002 · Now · Add versioned, affirmative AI/data-use consent.** Immediately before any
  receipt or wardrobe data is sent, explain the on-device selection, developer backend,
  Anthropic processing, exact data categories and purposes. Gate manual sync, styling, and
  background work; restored sessions do not inherit a notice they never accepted. Consent is
  revocable and scoped to the connected account where possible.
- [ ] **APP-003 · Now · Add a Privacy & Data center.** Keep Sign out, Disconnect Gmail/revoke,
  Withdraw AI consent, and Delete Local Data distinct. Show the connected account, sync and
  reminder controls, data flow, policy/support links, and destructive confirmations. A delete
  operation must cancel work and verify completion before reporting success.
- [ ] **APP-004 · Now · Stop automatic background and notification enrollment.** Both are off by
  default and user-controlled. Disabling, disconnecting, withdrawing consent, or deleting data
  cancels pending work. Background execution re-checks sign-in, consent, and opt-in before a
  Gmail or backend call. Notification copy must not claim an outfit already exists; allow a
  reminder time and route the tap to Today.
- [ ] **APP-005 · Now · Revalidate restored Gmail authorization.** A restored Google session is
  usable only if `gmail.readonly` remains granted. Map SDK/network failures to friendly recovery
  states and keep the one-scope, GET-only guard intact. Use the official Google sign-in control
  and label the action as an optional Gmail connection.
- [ ] **APP-006 · Now · Make persistence failures visible and recoverable.** Replace user-facing
  `try?` save/delete paths with throwing operations, rollback, alerts, and no false success or
  dismissal. Replace launch-time `fatalError` with a recoverable store error screen. Define a
  versioned SwiftData migration plan before evolving persisted models.
- [ ] **APP-007 · Now · Prevent cross-account catalog mixing.** Gmail-derived records, sync
  history, preferences, and consent must have an explicit stable owner. Account A must never see
  account B's data. Existing unscoped data requires an explicit migrate-or-delete choice; it is
  never silently assigned. Local photo items may remain in a clearly identified device-local
  wardrobe if that is the chosen product model.
- [ ] **APP-008 · Now · Minimize and deduplicate receipt transmission.** Use structured JSON-LD
  before raw text; select only product-relevant lines; redact obvious email, phone, card,
  shipping, address, and order identifiers; send a sender domain instead of a full address; and
  never expose a Gmail message ID to the model. Exclude Spam and Trash by default. Persist
  per-account processed IDs/history state so background runs do not retransmit the same mail.
- [ ] **APP-009 · GCP gate · Remove the shared backend bearer from the public client.** A token in
  `Info.plist` is extractable, even if moved to Keychain. Replace it with short-lived per-user
  authorization verified by the backend, rate limits, quotas, monitoring, and an old-build
  retirement plan. The concrete issuer/audience configuration depends on the production OAuth
  architecture in the Google sequence. No public build is releasable with the shared bearer.
- [ ] **APP-010 · Now · Restrict remote images.** Do not load arbitrary model-derived URLs. Apply
  HTTPS-only validation, a conservative host policy, bounded image decoding/caching, and a safe
  placeholder.

## P0 — release and App Review readiness

- [ ] **APP-011 · Now · Align product identity and release configuration.** Use “Wardrobe
  Stylist” consistently in the app, OAuth screen, help text, and store copy. Split development
  and production configuration. A Release archive must fail if required non-secret identifiers,
  HTTPS endpoints, policy/support URLs, or URL schemes are absent; it must also prove no shared
  backend credential is embedded.
- [ ] **APP-012 · Now · Pin/audit dependencies and archive privacy metadata.** Pin the Google Sign
  In SDK to a reviewed version, commit a reproducible resolution where practical, and validate
  the exact archive's SDK signatures/privacy manifests. Add an app privacy manifest only for
  required-reason APIs the app actually uses.
- [ ] **APP-013 · Now · Give App Review a deterministic product tour.** Add a seeded, offline demo
  mode or equivalent UI-test fixture that exercises Today, wardrobe browsing, item editing, and
  data controls without a reviewer sharing a personal mailbox. It must be visually and
  functionally distinct from real user data and never call Gmail or the backend.
- [ ] **APP-014 · Now · Add end-to-end UI coverage.** Cover first launch, skipped Gmail,
  disclosure/consent, demo entry, add/edit/delete item, catalog search/filter, Today states,
  reminder controls, disconnect, and local data deletion. Keep request-capture tests proving no
  network path runs without consent and no prohibited Gmail operation is representable.
- [ ] **APP-015 · Now · Strengthen CI/release gates.** Run backend contract tests when `shared/**`
  changes; build/test a Release configuration; run an archive/privacy report guard; and retain
  full pytest/Ruff/mypy plus Swift test regressions.
- [ ] **APP-016 · Now · Prepare accurate public-facing documents.** Replace the stale internal
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
  version is `1.0.0`; archive with the currently required Xcode/iOS SDK; validate/upload; wait for
  processing; test on a clean physical device; keep backend health available through review.

## P1 — core experience polish

- [ ] **APP-020 · Now · Review and correct imported items.** Receipt-derived entries land in a
  visible review state. Users can edit name, brand, category, color, size, purchase metadata,
  and image before accepting. Surface duplicates and extraction uncertainty instead of silently
  saving an incorrect catalog.
- [ ] **APP-021 · Now · Make every item editable.** Reuse one validated item form for manual add,
  import review, and edit. Preserve the existing photo when editing and confirm destructive
  deletion. Show specific save/validation failures.
- [ ] **APP-022 · Now · Improve catalog information architecture.** Add clear local/imported and
  pending-review cues, useful empty/search-zero states, stable sorting, favorites, archive, and
  bulk review where it materially reduces effort.
- [ ] **APP-023 · Now · Polish Today.** Cache a recommendation for the day, let users refresh
  intentionally, accept occasion/context input, explain empty/error/offline states, and never
  make a backend call merely because a tab appeared. Saving “Wear this” must be transactional
  and acknowledged only after persistence succeeds.
- [ ] **APP-024 · Enhancement · Add outfit history and feedback.** Show worn looks, dates, and
  item details. Let users rate/save/skip a recommendation and feed those preferences into future
  prompts without weakening the catalog-ID hallucination guard.
- [ ] **APP-025 · Now · Finish accessibility and adaptive layout.** VoiceOver names/hints and
  traversal, Dynamic Type through accessibility sizes, minimum tap targets, sufficient contrast,
  non-color-only status, Reduce Motion, keyboard/focus behavior, and meaningful image labels.
  Test the smallest supported phone and large text.
- [ ] **APP-026 · Now · Standardize loading, empty, failure, offline, and retry states.** Avoid raw
  SDK/backend errors and indefinite spinners. Preserve user input on failure and make destructive
  or privacy-impacting actions explicit.
- [ ] **APP-027 · Now · Add a branded first-run and launch experience.** Explain the value before
  permissions, include transparent privacy positioning, offer demo/local/Gmail paths, and replace
  the empty launch treatment while preserving fast startup.
- [ ] **APP-028 · Enhancement · Localize user-visible copy.** Start with a complete development
  language catalog and locale-aware dates/times, then choose additional App Store localizations
  based on target markets.

## P2 — feature enhancements after the public-release foundation

- [ ] **APP-029 · Enhancement · Wire structured receipt extraction end to end.** The repository
  already contains JSON-LD and OCR components; route suitable HTML/PDF/image receipts through
  them before cloud fallback, with confidence and review UI.
- [ ] **APP-030 · Enhancement · Scalable incremental Gmail sync.** Replace the 1,000-message
  ceiling/full rescans with an initial resumable backfill and Gmail History API cursor while
  retaining strict read-only endpoints and cancellation.
- [ ] **APP-031 · Enhancement · Rich styling preferences.** Add dress code, weather/context (only
  with separate permission), color/fit preferences, avoid/prefer items, laundry/unavailable
  state, packing/travel capsules, and calendar-aware occasions only as explicit opt-ins.
- [ ] **APP-032 · Enhancement · Wardrobe insights.** Cost-per-wear, least/most worn, neglected
  items, category gaps, repeat rate, and purchase trends computed locally where possible.
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

