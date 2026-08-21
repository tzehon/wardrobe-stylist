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
routes to Today. Public v1 has no Gmail or receipt background task.

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
Today offline-cache Restyle defect. App Store Connect shows build 4 as the highest upload; build 5
is reserved locally but has no signed archive, upload, processing, internal assignment, or physical
proof. Reviewed PR #23 merged at `2026-08-21T10:29:56Z`; frozen shipped-code/backend source was
`4a75b99dcd49e818ad1d5b198e8c49abba702e18`, and later docs-only evidence does not change the
deployed image or iOS bundle. Current local pre-archive gates are green (221
backend tests plus audit/Bandit/Ruff/mypy, 218 Swift unit tests, 9 UI flows, 43 release-script tests,
and Release simulator/artifact checks). Fly v8 deploys that source with production category `2`,
builds `4,5`, and targeted auth-service INFO logging; its post-change review passed at
`2026-08-21T11:09:20Z`. No lifecycle success event has yet been exercised against v8.

- [ ] Replace every backend, health, fixture, and contact placeholder.
- [ ] Confirm Demo Mode labels, item count, and reviewer steps against the exact uploaded build.
- [ ] Confirm the archive has no Google/Gmail/receipt-import capability and no login screen.
- [x] Record the pre-upload transition. The installed development build disconnected Google,
  deleted local data, and was uninstalled after production showed zero installations, zero sessions,
  and zero pending challenges. It predated the server-deletion UI, so do not claim that unavailable
  action succeeded or claim in-place migration support.
- [x] Confirm processed build 4 is distributed only to the `Family` Internal Testing group with the
  saved truthful What to Test wording reproduced in the internal runbook.
- [x] Retain the historical clean build-4 TestFlight install on iPhone 16 Pro/iOS 26.6 as partial
  evidence only; it was never installed over the older app and is not migration evidence.
- [ ] Only after the runbook's build-4 identity-safe handoff passes, install processed build 5
  cleanly and repeat the full physical matrix. Close successful Camera/Photo Library selection,
  notification delivery, styling-consent withdrawal, local/server deletion, Today failed-Restyle
  cache preservation/recovery, and reinstall evidence.
- [ ] Confirm the production API is healthy throughout the review window.
- [ ] Confirm App Attest is enabled for the exact App ID and prefix; the build-5 archive/profile
  contain the entitlement; and the uploaded build completes production attestation. On iOS 27+, confirm
  the intended signed category/build. On iOS 18–26, record the expected field absence without
  claiming category/build enforcement.
- [ ] Confirm durable auth storage, snapshot/restore evidence, logging/retention claims, rate
  limits, and a retained Gmail-free App-Attest-only recovery image against the deployed backend.
  Fly v8 deploys the targeted logger and `4,5` allowlist, and its payload-free review passed. The
  first bounded query returned zero registration, assertion, and deletion success events because
  none was exercised; retain real registration/assertion observation from processed build 5 and
  `installation_deleted` from the later identity-safe handoff. Protected `/recommend` success
  remains aggregate/client-evidenced. The latest listed snapshot at `2026-08-21T07:32:23Z`
  predates enrollment, so deletion/reinstall is paused. The former v5 image is only a pre-build-4
  abort because it re-exposes `/extract` and halts release.
- [ ] Confirm server-security-data deletion against the final backend and retain only redacted
  success/restore evidence.
- [ ] Confirm the obsolete shared-bearer build is rejected without breaking the submitted build.
- [ ] Attach a short screen recording only if the optional styling path needs clarification.
- [ ] Re-run public Release configuration, request-capture, privacy-manifest, and artifact-absence
  guards against the archive.

## Contact

Review contact: [NAME, EMAIL, PHONE, TIME ZONE]  
Escalation contact during review: [NAME, EMAIL, PHONE]
