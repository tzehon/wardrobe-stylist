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
- [ ] Complete the separate production Google OAuth sequence and its security/verification gates.

## 2. Public pages and truthful data declarations

- [ ] Publish the homepage, support page, privacy policy, and deletion/help instructions on the
  same stable owned HTTPS domain; remove every bracketed placeholder from the drafts.
- [ ] Verify each public URL on a signed-out browser and configure the exact values in Release.
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
- [ ] Enter the review contact, optional connected-feature test account, and exact instructions from
  [`app-review-notes-draft.md`](app-review-notes-draft.md). Apple requires complete contact details
  and a working demo account where sign-in is needed.

Apple's current field matrix is the source of truth for which properties are required, localizable,
or editable: [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties).

## 4. Release candidate and evidence

- [ ] Confirm the latest build already uploaded to App Store Connect, then select the next unused
  `CURRENT_PROJECT_VERSION`. If this exact internal build may be promoted, set the intended public
  `MARKETING_VERSION` before archiving; do not rely on Xcode to invent either value during upload.
- [ ] Regenerate the project and run the complete backend, Swift unit, UI, public-config,
  request-capture, artifact/privacy-manifest, and Release-build checks from the repository runbook.
- [ ] Confirm Gmail remains GET-only with only `gmail.readonly`, no Anthropic/shared backend secret
  exists in the app, and every production endpoint/link is HTTPS and non-placeholder.
- [ ] Build with an accepted production Xcode/SDK. As of 28 April 2026, Apple requires uploads to
  use the iOS 26 SDK or later: [current SDK minimum](https://developer.apple.com/news/?id=ueeok6yw).
- [ ] Confirm the launch-screen key remains present. Uploads built with the iOS 27 SDK or later are
  validated for a launch-screen configuration: [TN3208](https://developer.apple.com/documentation/technotes/tn3208-preparing-your-apps-launch-screen-to-meet-app-store-requirements).
- [ ] Create, validate, and export the signed archive; record archive hash, commit, version/build,
  Xcode/SDK, dependency resolution, entitlements, privacy manifests, symbols, and validation output.
- [ ] Distribute from Organizer using **TestFlight & App Store**. Do not use **TestFlight Internal
  Only**, and do not bypass the device-Release public configuration guard.
- [ ] Install the candidate on a clean physical device and test first launch, offline/local use,
  Demo Mode, photo/camera, Gmail consent/import/review, styling, reminders, background expiry,
  sign out, disconnect, deletion, account switching, and relaunch.

## 5. Upload, review, and release

- [ ] Upload exactly the verified archive; wait for processing and resolve any compliance prompts.
- [ ] Select the processed build and re-check its device requirements and displayed metadata.
- [ ] For the internal QA phase, add the processed build only to the intended Internal Testing
  group, enter truthful What to Test notes, and retain upgrade plus clean-device evidence.
- [ ] Add the version to a draft review submission, inspect all items, then submit. Apple's current
  flow requires choosing the build and completing required metadata before **Add for Review** and
  **Submit for Review**: [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
- [ ] Keep the production backend healthy and the review contact reachable during review; respond
  to App Review in the App Review section.
- [ ] After approval, execute the chosen release method, verify the live product page/install, and
  retain the final evidence and support handoff.
