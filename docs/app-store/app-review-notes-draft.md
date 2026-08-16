# App Review notes — draft

> Reconcile these notes with the exact submitted build. Remove every TODO before submission.

## Product summary

Wardrobe Stylist is a local-first wardrobe catalog and optional AI styling app. A reviewer can
explore the local/demo wardrobe without Google. Gmail connection is optional and strictly
read-only; it imports clothing purchase information from likely receipts. The app has no
Wardrobe account or login. When a reviewer explicitly uses remote AI, Apple App Attest verifies
that installation and the backend issues a short-lived anonymous session; Google is not used to
authorize styling or the developer backend.

## Reviewer path without personal data

1. Launch the app.
2. Choose **Try the offline demo**. Its indigo banner says **Demo Mode · Fictional Data** and
   **Offline · Changes are discarded**.
3. Open **Wardrobe** to browse, search, review the pending fictional import, edit, and delete
   fictional items.
4. Open **Today** to view the bundled recommendation. This path does not construct a Gmail or AI
   network client.
5. Open **History** to inspect a fictional previously worn look and its pieces.
6. Open **Settings** to confirm connected features are unavailable in Demo Mode, reset the
   disposable data, or exit the tour.

No Google credentials are required for this path. Demo data is held in a dedicated in-memory
store and discarded on reset or exit; it does not open the production wardrobe merely by
launching the tour. The same deterministic path is covered by the app's UI-test launch argument
`--wardrobe-demo`, but reviewers should use the visible first-run button above.

App Attest is not required for this offline reviewer path. If secure installation verification,
the network, or the backend is unavailable, the app keeps local wardrobe and Demo Mode usable and
fails closed only for remote AI with a recovery message; it does not mint an unauthenticated
fallback session.

## Gmail test path

1. Open **Settings → Connected Features → Receipt Import → Connect Gmail**.
2. Read and affirm the disclosure immediately before the Google authorization screen.
3. The app requests only `https://www.googleapis.com/auth/gmail.readonly`.
4. Tap **Sync Receipts**, then review and correct pending imported items before accepting them.
5. Disconnect Gmail in **Settings → Connected Features**; the grant is revoked and background
   work is cancelled.

Test account: [APP STORE CONNECT REVIEW CREDENTIAL FIELD ONLY]  
Representative receipt subject: [FICTIONAL TEST SUBJECT]  
Expected item/result: [EXPECTED RESULT]

## Third-party AI disclosure

The app names the developer backend and Anthropic before receipt or styling data is transmitted.
Receipt analysis and wardrobe styling have separate, versioned consent records. With consent
absent or withdrawn, automated request-capture tests verify the protected network paths make zero
Gmail/backend calls. The backend retains only the minimum anonymous App Attest authentication and
abuse-prevention metadata; it is intended not to persist receipt or wardrobe payloads. [VERIFY
THE SUBMITTED COMMIT, PRODUCTION LOGGING, AUTH-STORE RETENTION, AND BACKUPS.]

## Background and notifications

Both are off by default. Permission is requested only after the reviewer explicitly enables a
reminder. Background receipt import also requires an active Gmail connection, current receipt
consent and a separate toggle. iOS schedules it opportunistically, not at an exact time.

## Backend availability

- Production API: [HTTPS HOST]
- Health URL: [HEALTH URL]
- Review-window minimum instances: [VALUE]
- Status/support: [URL]
- App Attest environment and tester OS/runtime fields:
  [PRODUCTION / OS VERSION / EXTENSIONS PRESENT OR EXPECTED ABSENT]
- iOS 27+ App Attest category/build allowlist:
  [TESTFLIGHT 2 OR APP STORE 4 / EXACT BUILD]
- Durable auth-store/restore evidence: [REFERENCE]

## Non-obvious implementation assurances

- Gmail operations are structurally limited to allowlisted HTTP GET endpoints and guarded by an
  automated source scan/scope test.
- The server rejects recommendation item IDs not present in the submitted catalog.
- Receipt and wardrobe payloads are schema-validated.
- The public client contains no Anthropic key or shared backend bearer. [MUST BE TRUE.]
- Backend authorization uses an Apple-certified key unique to this installation and a short-lived
  session. Reinstalling creates a new anonymous installation identity; it does not create or link
  a human account.
- Sign in with Apple is not presented because the Google connection is solely for the specific
  Gmail receipt-import service; the core app and backend do not require a Google or Wardrobe
  account.

## Build-specific checks before pasting these notes

- [ ] Replace the backend, health, contact, and Gmail-test-account placeholders below.
- [ ] Confirm Demo Mode labels and reviewer steps against the exact uploaded build.
- [ ] Confirm the selected review account can complete Google authorization without unavailable
  employee-only steps and that any verification warning has been resolved.
- [ ] Confirm the production API is healthy throughout the review window.
- [ ] Confirm App Attest is enabled for the exact App ID and prefix; the archive/profile contain
  the entitlement; and the uploaded TestFlight build completes production attestation. On iOS
  27+, confirm signed category `2` and the exact submitted bundle build; on iOS 18–26, record the
  expected absence of those runtime fields without claiming build/category enforcement.
- [ ] Confirm durable auth storage, snapshot/backup and restore evidence, logging/retention claims,
  rate limits, and an App-Attest-only rollback image against the deployed backend.
- [ ] Confirm the migration bridge is disabled, `DEVICE_TOKEN` is unset/rotated, and an obsolete
  shared-bearer build is rejected without breaking the submitted build.
- [ ] Attach a short screen recording only if the connected flow needs additional explanation.
- [ ] Re-run the public Release configuration and request-capture guards against the archive.

## Contact

Review contact: [NAME, EMAIL, PHONE, TIME ZONE]  
Escalation contact during review: [NAME, EMAIL, PHONE]
