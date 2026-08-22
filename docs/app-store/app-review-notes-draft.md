# App Review notes — draft

> Reconcile these notes with the exact submitted Gmail-free build. Remove every TODO and
> placeholder before submission.

## Product summary

Wardrobe Stylist is a local-first wardrobe catalog and optional AI styling app. Users add items
manually or from photos, browse and edit the catalog, record worn looks, and can ask Aria for an
outfit suggestion. Public v1 does not connect to Google, read email, import receipts, or require a
Wardrobe account or login.

When a user explicitly requests remote AI styling, Apple App Attest verifies that installation and
the backend issues a short-lived anonymous session. Local catalog, history, reminders, and Demo
Mode do not require the backend.

## Reviewer path without personal data

1. Launch the app.
2. Choose **Try the offline demo**. Its banner says **Demo Mode · Fictional Data** and
   **Offline · Changes are discarded**.
3. Open **Wardrobe** to browse, search, edit, and delete fictional manual/photo items.
4. Open **Today** to view the bundled recommendation. This path does not construct an AI network
   client.
5. Open **History** to inspect a fictional previously worn look and its pieces.
6. Open **Settings** to reset the disposable data or exit the tour.

No credentials or review account are required. Demo data uses a dedicated in-memory store and is
discarded on reset or exit; entering the tour does not open or modify the production wardrobe. The
same deterministic path is covered by `--wardrobe-demo`, but reviewers should use the visible
first-run button.

App Attest is not required for this offline reviewer path. If secure installation verification,
the network, or the backend is unavailable, local wardrobe and Demo Mode remain usable and only
remote AI fails closed with a recovery message. The app does not mint an unauthenticated fallback
session.

## Optional AI styling path

1. Add at least [MINIMUM ITEM COUNT] fictional items manually or from photos, or use the provided
   App Review fixture [VERIFY EXACT SUBMITTED PATH].
2. Open **Today** and request a suggestion.
3. Read and accept the styling disclosure immediately before the first transmission.
4. Optionally enter a short occasion and request the look.
5. Confirm the suggestion resolves only to items already in the local catalog; use **Wear this**
   to add it to local History.

No login is required. If App Review needs a deterministic connected path, describe the exact
submitted fixture here; never provide personal data or a shared backend credential.

## Third-party AI disclosure

Before styling data is transmitted, the app identifies the developer backend and Anthropic and
describes the compact text fields and purpose. With styling consent absent or withdrawn,
request-capture tests verify `/recommend` is not called. Wardrobe photos, purchase metadata, wear
dates, and feedback free text are not included in v1 styling requests.

The developer application does not persist wardrobe, prompt, or model-response payloads. The
backend retains only minimum anonymous App Attest authentication and abuse-prevention metadata.
Retention, logging, deletion, snapshots, and manual production operations follow the
[APP-009 lifecycle policy](app-attest-data-lifecycle-policy.md). [VERIFY THE SUBMITTED COMMIT AND
EVERY UNCHECKED POLICY-COMPLIANCE ITEM BEFORE SUBMISSION.]

The submitted build exposes **Settings → Privacy & Data → Delete Server Security Data**. It uses a
fresh App Attest assertion to delete the current installation's live anonymous server record and
sessions. This is separate from deleting the local wardrobe.

## Reminders and background behavior

Daily reminders are local notifications, off by default, and requested only after the user enables
them. The notification does not claim that an outfit was generated in the background; opening it
routes to Today. Public v1 has no Gmail or receipt background task. Do not submit build 5 with this
claim: delivery passed, but tapping the notification crashed. Reconfirm routing on the exact
replacement build before these notes are pasted into App Store Connect.

## Backend availability

- Production API: [HTTPS HOST]
- Health URL: [HEALTH URL]
- Review-window minimum instances: [VALUE]
- Support: `https://blog.tth.dev/wardrobe/`
- App Attest environment and tester OS/runtime fields:
  [PRODUCTION / OS VERSION / EXTENSIONS PRESENT OR EXPECTED ABSENT]
- iOS 27+ App Attest category/build allowlist:
  [TESTFLIGHT 2 OR APP STORE 4 / EXACT BUILD]
- Durable auth-store/restore evidence: [REFERENCE]

## Non-obvious implementation assurances

- The signed public-v1 archive contains no Google Sign-In SDK/client configuration, Gmail scope or
  route, receipt-import client path, or receipt background task. [MUST BE TRUE.]
- The server rejects recommendation item IDs not present in the submitted catalog.
- Styling requests and responses are schema-validated.
- The public client contains no Anthropic key or shared backend bearer. [MUST BE TRUE.]
- Backend authorization uses an Apple-certified key unique to this installation and a short-lived
  session. Reinstalling creates a new anonymous installation identity; it does not create or link
  a human account.
- Server authentication-data deletion is distinct from local wardrobe deletion. It requires a
  fresh App Attest assertion, removes the current live identity and sessions, and then clears the
  app's local server-identity reference.
- Sign in with Apple is not presented because the app has no human account or login. App Attest is
  installation security, not an account system.

## Build-specific checks before pasting these notes

Build 4 is historical internal-QA evidence and must not be submitted: physical testing found the
Today offline-cache Restyle defect. Build 5 also must not be submitted: its strictly verified
production-signed archive completed Organizer validation, upload, processing, and `Family`
Internal Testing assignment by `2026-08-22T03:24:21Z`, but clean physical QA later found a local-
notification tap crash. At the `2026-08-22T01:09:39Z` archive-time refresh, App Store Connect
showed build 4 as the highest upload and build 5 unused; the final pre-validation refresh at
`2026-08-22T03:16:16Z` again showed builds 1–4 only and build 5 absent. Build 5 is now consumed and
non-promotable. A signed-in TestFlight Build Uploads refresh at `2026-08-22T10:02:31Z` showed
builds 1–5 only, build 5 **Complete**, and no build 6. Build 6 is confirmed unused and selected;
`MARKETING_VERSION` stays `1.0.0`. Reviewed PR
#23 merged at `2026-08-21T10:29:56Z`; frozen
shipped-code/backend source was
`4a75b99dcd49e818ad1d5b198e8c49abba702e18`, and later docs-only evidence does not change the
deployed image or iOS bundle. Historical build-5 pre-archive gates were green (221
backend tests plus audit/Bandit/Ruff/mypy, 218 Swift unit tests, 9 UI flows, 43 release-script tests,
and Release simulator/artifact checks). Fly v8 deploys that source with production category `2`,
builds `4,5`, and targeted auth-service INFO logging; its post-change review passed at
`2026-08-21T11:09:20Z`, the pre-archive repeat passed at `2026-08-22T01:07:45Z`, the pre-validation
review passed at `2026-08-22T02:37:08Z`, and the separate post-distribution review passed at
`2026-08-22T03:30:33Z`. Later physical flows observed bounded registration, assertion, and deletion
success markers against v8.

- [ ] Replace every backend, health, fixture, and contact placeholder.
- [ ] Confirm Demo Mode labels, item count, and reviewer steps against the exact uploaded build.
- [x] Confirm the exact build-5 signed archive has no Google/Gmail/receipt-import capability. The
  strict verifier and separate non-emitting credential/removed-capability scan passed for
  `Wardrobe-1.0.0-5-695c562-appstore.xcarchive`.
- [x] Confirm processed build 5 presents no human-login screen. Its clean first launch showed
  **Your wardrobe, your way** and an empty wardrobe; this semantic evidence is retained even though
  the later notification crash makes build 5 non-promotable and must be repeated on the replacement.
- [x] Record the pre-upload transition. The installed development build disconnected Google,
  deleted local data, and was uninstalled after production showed zero installations, zero sessions,
  and zero pending challenges. It predated the server-deletion UI, so do not claim that unavailable
  action succeeded or claim in-place migration support.
- [x] Confirm processed build 4 is distributed only to the `Family` Internal Testing group with the
  saved truthful What to Test wording reproduced in the internal runbook.
- [x] Confirm processed build 5 is distributed only to the `Family` Internal Testing group with the
  saved truthful build-specific What to Test wording reproduced in the internal runbook. The build
  lists one tester through that group and no individual testers. This assignment was not physical
  proof and did not authorize installation or update before build 4's identity-safe handoff, which
  later completed as recorded below.
- [x] Retain the historical clean build-4 TestFlight install on iPhone 16 Pro/iOS 26.6 as partial
  evidence only; it was never installed over the older app and is not migration evidence.
- [x] Complete the build-4 identity-safe handoff. An eligible automatic snapshot created at
  `2026-08-22T07:33:23Z` reported `created` with 14-day retention. Build 4 proof remained available
  after build 5 appeared installed in place unexpectedly; assertion-verified server deletion emitted
  exactly one success marker and live installations/sessions/challenges reached `0/0/0`. Local
  data and then the app were deleted, and build 5 was installed cleanly. Do not claim migration.
- [x] Retain clean build-5 physical evidence through notification delivery. Offline Demo Mode,
  Camera and Photo Library saves, the full local catalog flow, online Style at `16:30`, cached
  relaunch, Restyle at `17:04`, failed-offline-Restyle cached-look preservation, and offline Wear
  this/History passed. The local reminder delivered.
- [ ] Replace and retest notification response routing. Tapping the delivered notification at
  `2026-08-22T17:15:14+08:00` crashed build 5. Its exact dSYM matched; safe symbolication showed
  `SIGABRT`, a UIKit state-restoration assertion, and an app frame in the
  `DailyReminderNotificationRouter` `didReceive` async bridge. Do not repeat the tap. Keep installed
  build 5 and its live clean-install identity intact with automatic TestFlight updates off until
  the identity-safe handoff. The local source fix has passed 17 focused tests, the 221-test backend
  gate plus security/audit/type checks, 222 Swift unit tests, all 9 UI flows, and all 43 release-
  script tests; it is not merged, signed, uploaded, or released.
- [ ] Confirm the production API is healthy throughout the review window.
- [x] Confirm App Attest is enabled for the exact App ID/prefix and the build-5 archive/profile
  contain matching production authorization. The strict verifier matched the prefix, team, bundle,
  Apple Distribution certificate, App Store profile, and scalar production entitlement.
- [x] Confirm processed build 5 completes production registration and assertion renewal on iPhone
  16 Pro/iOS 26.6, with expected signed runtime-field absence. Do not claim iOS 27+ category/build
  enforcement; repeat the production path on the final replacement.
- [ ] Confirm durable auth storage, snapshot/restore evidence, logging/retention claims, rate
  limits, and a retained Gmail-free App-Attest-only recovery image against the deployed backend.
  Fly v8 deploys the targeted logger and `4,5` allowlist, and its payload-free review passed. The
  first post-deploy bounded query was zero because no lifecycle flow had yet been exercised. Later
  clean build-5 Style/Restyle observed `registration_succeeded`/`assertion_succeeded`, and the
  preceding identity-safe handoff observed exactly one `installation_deleted` plus `0/0/0` live
  aggregates. Protected `/recommend` remains aggregate/client-evidenced. The eligible
  `2026-08-22T07:33:23Z` created/14-day snapshot enabled the build-4 handoff, but listing expiry and
  deletion-specific restore/non-return remain open. The former v5 image is only a pre-build-4 abort
  because it re-exposes `/extract` and halts release.
- [x] Confirm live server-security-data deletion against Fly v8 with only redacted evidence: one
  success marker and aggregate `0/0/0` during the build-4 handoff.
- [ ] Confirm snapshot-list expiry, deletion-specific restore/non-return, and the same safe deletion
  ordering on the final replacement client.
- [x] Refresh App Store Connect and confirm the replacement build number before archive/upload.
  The signed-in TestFlight Build Uploads view at `2026-08-22T10:02:31Z` showed builds 1–5 only,
  build 5 **Complete**, and no build 6. Build 6 is confirmed unused and selected;
  `MARKETING_VERSION` remains `1.0.0`.
- [ ] Confirm the obsolete shared-bearer build is rejected without breaking the submitted build.
- [ ] Attach a short screen recording only if the optional styling path needs clarification.
- [x] Retain explicit synthetic request-capture evidence for the exact allowlisted `/recommend`
  fields. The tests-only guard inventories all stored properties, including nil optionals, and
  separately pins the encoded top-level, catalog-item, and preference keys; the shared schema/
  backend reject extras. Strengthened focused `RecommendClientTests` passed 12/12 at
  `2026-08-22T01:59:08Z`. The post-guard tree then passed the mandatory 221-test backend gate and
  one uninterrupted historical pre-archive 218-unit/9-UI iOS regression whose result bundle finalized at
  `2026-08-22T02:04:17Z`. The exact signed build-5 archive separately passed the public Release,
  privacy-manifest, and artifact-absence verifier. No production payload was inspected or retained.

## Contact

Review contact: [NAME, EMAIL, PHONE, TIME ZONE]  
Escalation contact during review: [NAME, EMAIL, PHONE]
