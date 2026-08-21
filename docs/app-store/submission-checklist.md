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

## 4. Release candidate and evidence

- [x] Merge and freeze the reviewed Swift/backend/contract/verifier fixes on clean synchronized
  `main`. PR #19 rebase-merged source `d4637f4b2adf14cd533594aec6060c385f8a5e2b`.
- [x] Build and scan the exact frozen `linux/amd64` backend image, deploy only its recorded digest,
  verify production health/configuration/Gmail-free behavior, and complete the required payload-
  free post-deploy manual review. Fly v7 serves
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`;
  the review passed at `2026-08-21T06:00:21Z`.
- [ ] Confirm the latest build already uploaded to App Store Connect, then select the next unused
  `CURRENT_PROJECT_VERSION`. If this exact internal build may be promoted, set the intended public
  `MARKETING_VERSION` before archiving; do not rely on Xcode to invent either value during upload.
  The check before the superseded archive found build 3 highest; retain build 4 only if a fresh
  check immediately before the replacement archive still confirms it is unused.
- [ ] Regenerate the project and run the complete backend, Swift unit, UI, public-config,
  request-capture, artifact/privacy-manifest, and Release-build checks from the repository runbook.
- [ ] Confirm the replacement archive contains no Google Sign-In SDK/client configuration, Gmail
  permission or route, `/extract` client path, receipt-import UI/background task, Anthropic/shared
  backend secret, non-HTTPS production endpoint, or placeholder public link.
- [ ] Build the replacement archive with an accepted production Xcode/SDK. As of 28 April 2026,
  Apple requires uploads to use the iOS 26 SDK or later:
  [current SDK minimum](https://developer.apple.com/news/?id=ueeok6yw).
- [ ] Confirm the launch-screen key remains present in the replacement archive. Uploads built with
  the iOS 27 SDK or later are validated for a launch-screen configuration:
  [TN3208](https://developer.apple.com/documentation/technotes/tn3208-preparing-your-apps-launch-screen-to-meet-app-store-requirements).
- [ ] Create and verify the replacement production-signed archive; record commit, version/build,
  Xcode/SDK, dependency resolution, entitlements, privacy manifests, and signed-artifact output.
- [ ] Repeat the payload-free manual operations review against the exact deployed backend
  immediately before validation/upload.
- [ ] Validate and export/upload exactly the newly recorded replacement archive; record validation
  output, exported artifact hash, and symbols. The formerly verified
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-dd3d990-appstore.xcarchive` was superseded by
  shipped Swift/backend changes and is not an upload target. The development-signed
  `Wardrobe-1.0.0-4-dd3d990.xcarchive` is also ineligible.
- [ ] Distribute from Organizer using **TestFlight & App Store**. Do not use **TestFlight Internal
  Only**, and do not bypass the device-Release public configuration guard.
- [ ] Install the candidate on a clean physical device and test first launch, offline/local use,
  Demo Mode, manual add, photo library/camera, catalog edit/delete, styling consent and withdrawal,
  Today/History, reminders, local deletion, separate server-security deletion, backend failure,
  reinstall identity reset, and relaunch. Confirm no Google/Gmail UI or network path exists.
- [x] Complete the pre-upload clean-uninstall transition. The installed development build
  disconnected Google and deleted local data, but predated the server-deletion UI; production had
  zero installations, zero sessions, and zero pending challenges before uninstall, so no live
  identity existed to delete. Install build 4 only from processed TestFlight, never over an older
  app, and do not claim migration.

## 5. Upload, review, and release

- [ ] Upload exactly the verified archive; wait for processing and resolve any compliance prompts.
- [ ] Select the processed build and re-check its device requirements and displayed metadata.
- [ ] For the internal QA phase, add the processed build only to the intended Internal Testing
  group, enter truthful What to Test notes, and retain the pre-uninstall cleanup plus fresh-install
  evidence.
- [ ] Add the version to a draft review submission, inspect all items, then submit. Apple's current
  flow requires choosing the build and completing required metadata before **Add for Review** and
  **Submit for Review**: [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
- [ ] Keep the production backend healthy and the review contact reachable during review; respond
  to App Review in the App Review section.
- [ ] After approval, execute the chosen release method, verify the live product page/install, and
  retain the final evidence and support handoff.
