# App Review notes — draft

> Reconcile these notes with the exact submitted build. Remove every TODO before submission.

## Product summary

Wardrobe Stylist is a local-first wardrobe catalog and optional AI styling app. A reviewer can
explore the local/demo wardrobe without Google. Gmail connection is optional and strictly
read-only; it imports clothing purchase information from likely receipts.

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
Gmail/backend calls. [VERIFY IN SUBMITTED COMMIT.]

## Background and notifications

Both are off by default. Permission is requested only after the reviewer explicitly enables a
reminder. Background receipt import also requires an active Gmail connection, current receipt
consent and a separate toggle. iOS schedules it opportunistically, not at an exact time.

## Backend availability

Production API: [HTTPS HOST]  
Health URL: [HEALTH URL]  
Review-window minimum instances: [VALUE]  
Status/support: [URL]

## Non-obvious implementation assurances

- Gmail operations are structurally limited to allowlisted HTTP GET endpoints and guarded by an
  automated source scan/scope test.
- The server rejects recommendation item IDs not present in the submitted catalog.
- Receipt and wardrobe payloads are schema-validated.
- The public client contains no Anthropic key or shared backend bearer. [MUST BE TRUE.]
- Sign in with Apple is not presented because the Google connection is solely for the specific
  Gmail receipt-import service; the core app does not require a Wardrobe account.

## Build-specific checks before pasting these notes

- [ ] Replace the backend, health, contact, and Gmail-test-account placeholders below.
- [ ] Confirm Demo Mode labels and reviewer steps against the exact uploaded build.
- [ ] Confirm the selected review account can complete Google authorization without unavailable
  employee-only steps and that any verification warning has been resolved.
- [ ] Confirm the production API is healthy throughout the review window.
- [ ] Attach a short screen recording only if the connected flow needs additional explanation.
- [ ] Re-run the public Release configuration and request-capture guards against the archive.

## Contact

Review contact: [NAME, EMAIL, PHONE, TIME ZONE]  
Escalation contact during review: [NAME, EMAIL, PHONE]
