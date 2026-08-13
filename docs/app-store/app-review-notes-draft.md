# App Review notes — draft

> Reconcile these notes with the exact submitted build. Remove every TODO before submission.

## Product summary

Wardrobe Stylist is a local-first wardrobe catalog and optional AI styling app. A reviewer can
explore the local/demo wardrobe without Google. Gmail connection is optional and strictly
read-only; it imports clothing purchase information from likely receipts.

## Reviewer path without personal data

1. Launch the app.
2. Choose **Explore Sample Wardrobe**. Sample entries are fictional and clearly labeled.
3. Open **Wardrobe** to browse/search, add or edit an item, and inspect data controls.
4. Open **Today** to view the deterministic demo/cached recommendation. [VERIFY DEMO MODE EXISTS
   AND MAKES NO NETWORK REQUEST.]
5. Open **Settings → Privacy & Data** to review consent, background/reminder controls, disconnect,
   and deletion behavior.

No Google credentials are required for this path. [IF DEMO MODE IS NOT SHIPPED, REPLACE WITH A
DURABLE REVIEW ACCOUNT AND PRECISE CREDENTIALS/2FA INSTRUCTIONS IN APP STORE CONNECT—NEVER HERE.]

## Gmail test path

1. Open Settings → Receipt Import → Connect Gmail.
2. Read and affirm the disclosure immediately before the Google authorization screen.
3. The app requests only `https://www.googleapis.com/auth/gmail.readonly`.
4. Tap Sync Receipts, then review/correct imported items.
5. Disconnect Gmail in Settings; the grant is revoked and background work is cancelled.

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

## Contact

Review contact: [NAME, EMAIL, PHONE, TIME ZONE]  
Escalation contact during review: [NAME, EMAIL, PHONE]

