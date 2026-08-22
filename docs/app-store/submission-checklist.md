# App Store submission checklist

This is the final operational checklist, not proof that an item is already complete. Attach the
release evidence beside each checked item and use the exact uploaded build throughout.

For internal beta distribution, follow
[`internal-testflight-runbook.md`](internal-testflight-runbook.md). Internal describes the tester
audience, not a weaker binary: use Xcode's **TestFlight & App Store** route and add the processed
build only to an Internal Testing group. Do not use **TestFlight Internal Only** when the build may
later be promoted to customers.

## 1. External decisions and account readiness

- [ ] Confirm legal seller name/entity, copyright owner, postal address, support/privacy/security
  contacts, and review phone number.
- [ ] Decide public version, price/tax category, countries/regions, automatic/manual/phased release,
  and EU Digital Services Act trader status.
- [ ] Confirm all Apple agreements, tax, banking, and any account compliance review are current.
- [ ] Decide the final bundle ID and immutable SKU before creating the App Store Connect record.
- [ ] Confirm the approved public-v1 scope is Gmail-free and no Google OAuth verification,
  restricted-scope, or review-account dependency remains in the candidate.

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
- [ ] Reconcile the policy, in-app disclosures, request captures, backend/host logs, provider
  contract, and [`app-privacy-data-inventory.md`](app-privacy-data-inventory.md).
- [ ] Complete and publish App Privacy answers for the app and all integrated third parties. Apple
  requires an iOS privacy-policy URL and accurate app-level collection answers, including partner
  practices: [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).
- [ ] Complete the age-rating questionnaire from observed final behavior; do not select Kids unless
  that permanent program commitment is intended.

## 3. Product-page record

- [ ] Enter the final name, subtitle, primary language, categories, description, keywords,
  promotional text, copyright, support URL, and optional marketing URL from
  [`metadata-draft.md`](metadata-draft.md).
- [ ] Complete content rights, export compliance, DSA, availability, pricing, tax category, and any
  region-specific declarations shown by App Store Connect.
- [ ] Upload one to ten current screenshots per required device class and localization using
  [`screenshot-plan.md`](screenshot-plan.md). Preview scaling and ordering.
- [ ] Enter the review contact and exact no-login reviewer instructions from
  [`app-review-notes-draft.md`](app-review-notes-draft.md). Confirm App Review needs no Google,
  Wardrobe, or shared test account.

Apple's current field matrix is the source of truth for which properties are required, localizable,
or editable: [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties).

## 4. Historical build-4 and current replacement evidence

Checked historical items in this section preserve the uploaded build-4 record. The current
`1.0.0 (5)` production-signed archive is now strictly verified, but Organizer validation, upload,
processing, assignment, and physical testing have not happened.

- [x] Review and freeze the Today offline-cache fix, its focused tests, the backend registration/
  assertion success-marker logging fix, and source `4,5` TestFlight allowlist. Reviewed PR #23
  merged at `2026-08-21T10:29:56Z`; frozen shipped-code/backend source was
  `4a75b99dcd49e818ad1d5b198e8c49abba702e18`. Later docs-only evidence does not change the
  deployed image or iOS bundle.
- [x] Retain the current local build-5 pre-archive regression: 221 backend tests plus locked audit/
  Bandit/Ruff/mypy, 218 Swift unit tests, all 9 UI flows, all 43 release-script tests, and Release
  simulator/artifact checks passed after project regeneration. Rerun affected gates if source or
  configuration changes; this local regression is distinct from the retained signed archive and
  is not distribution evidence.
- [x] Build, scan, deploy, configure, and review the exact frozen backend. Fly v8 completed at
  `2026-08-21T10:45:06Z` with exact source and immutable registry digest
  `sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
  Local/registry zero-critical/high scans, runtime/storage/route checks, production App Attest
  category `2` and builds `4,5`, targeted INFO logging, rollback/recovery checks, and the payload-
  free post-change review at `2026-08-21T11:09:20Z` passed. This is not lifecycle-event, upload,
  or physical-device proof.
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
  pins every top-level, catalog-item, and preference key and rejects extras; the focused
  `RecommendClientTests` suite passed 12/12 at `2026-08-22T01:27:39Z`. No production payload,
  credential, token, or identifier was inspected or retained, and the test does not alter the
  signed bundle.

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
- [ ] Refresh App Store Connect again immediately before build-5 validation/upload and stop if
  build 5 is no longer unused.
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
- [ ] Only after the runbook's build-4 identity-safe handoff passes, install processed build 5 on a
  clean physical device and test first launch, offline/local use,
  Demo Mode, manual add, photo library/camera, catalog edit/delete, styling consent and withdrawal,
  Today/History, reminders, local deletion, separate server-security deletion, backend failure,
  reinstall identity reset, and relaunch. Confirm no Google/Gmail UI or network path exists. Build 4
  supplied only historical **PARTIAL** evidence: clean TestFlight install on iPhone 16 Pro/iOS 26.6;
  0→1 production installations; first assertion/protected calls; cold renewal; expected runtime-
  field absence; offline friendly failure with Wardrobe/History/Demo usable; online recovery at
  `Styled 17:24` with assertions 1→2 and the current recommendation-installation window 0→1; manual
  add/edit; Camera and Photo Library open/cancel; Demo; reminder permission/scheduling; and Wear/
  History. A failed offline Restyle hid the cached look until relaunch/tap, so build 4 is not
  promotable. Successful media selection, notification delivery, consent withdrawal, local/server
  deletion, and the full build-5 repeat remain open.
- [x] Complete the pre-upload clean-uninstall transition. The installed development build
  disconnected Google and deleted local data, but predated the server-deletion UI; production had
  zero installations, zero sessions, and zero pending challenges before uninstall, so no live
  identity existed to delete. Build 4 was installed only from processed TestFlight and never over
  the older app; do not claim migration.
- [ ] From processed build 5, exercise and observe real payload-free `registration_succeeded` and
  `assertion_succeeded` INFO events. Fly v8 deploys the targeted logger and production build `4,5`
  allowlist, but its post-deploy counts for registration, assertion, and deletion success remained
  zero because none was exercised. Observe `installation_deleted` only during the later identity-
  safe handoff. Protected `/recommend` remains aggregate/client-evidenced. The latest listed 14-day
  snapshot at `2026-08-21T07:32:23Z` predates build-4 enrollment, so server deletion/reinstall and
  deletion-specific recovery remain paused and open.

## 5. Upload, review, and release

Checked upload/processing/internal-assignment items below are historical build-4 facts.

- [ ] Validate, upload, process, and internally assign only the verified build-5 archive using the
  normal **TestFlight & App Store** route, then save truthful build-5 What to Test wording.

- [x] Upload exactly the verified archive; wait for processing and resolve any compliance prompts.
  Build `1.0.0 (4)` completed processing by `2026-08-21T08:20:20Z` with no unresolved prompt.
- [x] Select the processed build and re-check its device requirements and displayed metadata. The
  processed record shows the expected version/build and bundle, arm64 iPhone support, minimum iOS
  18.0, included symbols, no non-exempt encryption, and production App Attest entitlement.
- [x] For the internal QA phase, add the processed build only to the intended Internal Testing
  group and enter truthful What to Test notes. Build 4 is in the `Family` group and the saved
  truthful wording reproduced in the runbook was saved on 2026-08-21. The separate build-5 upload
  and clean physical-device evidence items above remain open.
- [ ] Add the version to a draft review submission, inspect all items, then submit. Apple's current
  flow requires choosing the build and completing required metadata before **Add for Review** and
  **Submit for Review**: [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
- [ ] Keep the production backend healthy and the review contact reachable during review; respond
  to App Review in the App Review section.
- [ ] After approval, execute the chosen release method, verify the live product page/install, and
  retain the final evidence and support handoff.
