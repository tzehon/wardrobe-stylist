# App Privacy data inventory

This inventory drives the in-app disclosure, public privacy policy, Apple App Privacy answers,
deletion implementation, request-capture tests, and processor contracts for the approved
Gmail-free public v1. “Collected” below uses Apple's App Privacy concept. Final App Store Connect
publication and any later provider, purpose, or data-flow change still require review. Historical
Gmail/receipt-import data categories are intentionally excluded because the signed v1 must not
contain or invoke that capability.

| Data / source | On-device use | Leaves device? | Recipient / purpose | Intended retention | Consent / control | Apple answer status |
|---|---|---:|---|---|---|---|
| Wardrobe item attributes | Catalog + styling | Yes for AI styling | Backend → Anthropic outfit recommendation | Developer application: request lifetime only, no persistence; verify Anthropic/provider terms | Styling consent | Likely “Other User Content” if retained; pending |
| Wardrobe photos | Catalog display | No in v1 styling path | Local app | Until item/local-data deletion | Photo picker/camera; delete | Not collected if device-only |
| Purchase date/price/currency | Catalog/review/insights | No in v1 styling | Local app | Until item/local-data deletion | Review/edit/delete | Not collected if device-only |
| Outfit and wear history | Anti-repeat/history and explicit 1–5 feedback | Recent item IDs and bounded per-item rating summaries (item ID, average, count) leave for styling; no feedback free text or wear dates | Backend → Anthropic recommendation | Developer application: request lifetime only, no persistence; local history until delete; verify Anthropic/provider terms | Styling consent; delete | Pending retention interpretation |
| Occasion/context text | User-directed recommendation | Yes | Backend → Anthropic recommendation | Developer application: request lifetime only, no persistence; verify Anthropic/provider terms | Styling consent; user submits | “Other User Content” if retained; pending |
| App Attest key ID, verified public key, opaque Apple attestation receipt, anonymous installation ID and assertion counter | Prove a genuine installation and renew backend access without a Wardrobe account | Key ID/attestation/assertions leave; private key never leaves Secure Enclave | Apple App Attest certification → developer backend authentication/security store | Repository limits: 90 days after last successful use; revoked records 30 days; verified live deletion is synchronous. Encrypted snapshots stop appearing from Fly's customer listing after 14 days; all-copy purge timing is undisclosed and owner-accepted. The final policy image is deployed; listing-expiry observation and restore-after-deletion evidence remain APP-009 work. Independent Apple-receipt validation/risk-metric policy remains pending. | **Settings → Privacy & Data → Delete Server Security Data** uses a fresh App Attest assertion; reinstall creates a new identity but does not delete the old row | Device ID, App Functionality, linked, not tracking; publish only after final App Store Connect review |
| One-time App Attest challenges, hashed short-lived sessions and coarse rate windows | Replay prevention, authorization, quotas and abuse prevention | Yes | Developer backend security store | Repository maxima: challenge 70 minutes from issue; session hash 20 minutes from issue; rate-window hash five minutes after its one-minute/hourly window, enforced by the deployed one-minute maintenance loop and request-time expiry cleanup | Automatic expiry; a verified server deletion removes current-secret-derived key/installation rows, while unlinkable pre-rotation HMAC rows expire within 65 minutes | Device ID and Other Diagnostic Data; App Functionality; linked; not tracking. Final App Store Connect publication pending |
| IP address, request path/ID and timing | Network delivery/security | Inherent | Host/backend abuse prevention | Raw IP is not stored in SQLite and application access logs are disabled. Fly's customer-visible platform/proxy stream can contain path, request ID and client IP for a fixed seven days. Separate operational/abuse logs can contain source IP with undisclosed, non-configurable in-service retention. The owner accepted this provider boundary on 2026-08-19. | Public policy; remote features are optional | Conservatively: Device ID, Other Diagnostic Data and Product Interaction; App Functionality; linked; not tracking. Final App Store Connect publication pending |
| Consent and automation preferences | Enforce user choices | No | Local UserDefaults | Until withdrawal/delete | Privacy Center | Not collected if device-only |
| Camera/photo-library selection | Add item photo | Selected asset only, device-local | Local app | Until item/delete | System permission/selection | Not collected if device-only |
| Notification schedule | Daily local reminder | Apple notification system | Local notification delivery | Until disabled | Reminder toggle/system settings | Usually not developer-collected; verify no push service |
| Crash/analytics diagnostics | None currently planned | No current SDK | N/A | N/A | N/A | Reassess before adding any SDK |

## Release-blocking confirmations

The exact approved developer-controlled schedule and its current compliance status live in
[`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md).

- [ ] Use synthetic/local request-capture fixtures to verify the exact allowlisted `/recommend`
  fields. In production, inspect only schema/field names and aggregate sizes—never capture or
  retain real wardrobe, prompt, or model-response bodies as evidence.
- [ ] Verify the signed candidate and its generated configuration contain no Google Sign-In SDK,
  Google client identifier/callback scheme, Gmail permission/host/client path, `/extract` client
  path, receipt-import UI, or receipt-background-task identifier. Source-level removal is not by
  itself evidence that the signed archive is Gmail-free; retain both guard outputs.
- [x] Confirm the application security-event schema is bounded and excludes payloads, credentials,
  IPs, and installation identifiers; confirm raw IP is absent from SQLite.
- [x] Disable application access logs in the production container command and pin that command with
  a regression.
- [x] Record Fly's provider-controlled logging facts and the explicit 2026-08-19 owner decision
  accepting a fixed seven-day customer-visible stream plus undisclosed provider-internal
  in-service retention. Preserve the old 24-hour requirement as unmet and superseded, not passed.
- [x] Record the 2026-08-20 owner decision to use payload-free manual operations for the initial
  personal single-user release. No monitoring processor, credential, or new backend data flow is
  introduced by that decision.
- [ ] Decide whether to request, review, and sign Fly's optional DPA. The account currently has no
  active DPA; do not treat Fly Security's 30-day post-service deletion and 90-day residual
  encrypted-backup summary as binding unless the exact agreement/version is executed.
- [ ] Reconfirm Fly.io region and encrypted storage; observe the configured 14-day snapshot-list
  disappearance and complete deletion-specific recovery against the final deployment. The
  secret-free, non-serving restore path and immediate temporary-resource cleanup passed on
  2026-08-19, but no processed-TestFlight deletion identity existed in that empty snapshot.
  All-copy purge timing is explicitly accepted as undisclosed.
- [ ] Confirm the production App Attest App ID prefix, entitlement/profile, environment, tester OS,
  signed runtime-field presence, iOS 27+ validation categories and exact allowed bundle builds,
  physical-device evidence, and which Apple receipt fields are retained.
- [x] Confirm the durable auth-store schema contains only public keys/opaque Apple attestation
  receipts, anonymous installation IDs, counters, challenges, session hashes and rate windows—
  never wardrobe, prompt, or model-response payloads.
- [x] Enforce deadline cleanup, 90-day inactivity purge, 30-day revoked-record purge, synchronous
  assertion-verified live deletion, safe SQLite/WAL maintenance, and the separate in-app server
  deletion control in the repository.
- [x] Against the deployed final image, complete the first owner-approved payload-free manual
  operations review.
- [x] Publish and rehearse the monitored support route at `contact@tth.dev`; keep the
  two-business-day response target.
- [ ] Rehearse deletion-specific restore/recovery behavior against the final deployment.
- [ ] Confirm unsupported App Attest, offline verification and backend failure preserve local
  wardrobe/Demo Mode while remote AI fails closed without creating an unauthenticated identifier
  or request.
- [x] Confirm the migration bridge is retired, `DEVICE_TOKEN` is unset/rotated, and the obsolete
  shared-token build is rejected. The initial rollback boundary was App-Attest-only; APP-036 now
  additionally requires a Gmail-free recovery image after build 4 distribution.
- [x] After the Gmail-free image change, exact candidate digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5` and retained v5
  emergency rollback digest `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  both resolved from the registry after fresh authentication at `2026-08-21T01:20:25Z` and passed
  critical/high scans across 90 packages. An isolated old/new/old schema-v4 rehearsal retained
  integrity and zero foreign-key errors; live `/extract` now returns `404`, `/recommend` rejects
  missing authorization, and the obsolete shared bearer remains rejected. The v5 digest is an
  emergency pre-build-4 abort only; v6 is the retained Gmail-free recovery baseline.
- [ ] Confirm Anthropic API retention, training/model-improvement, human access, subprocessors and
  contract configuration in writing.
- [ ] Match every item above to the exact in-app notice and public policy wording.
- [ ] Complete Apple App Privacy answers based on actual retention, linkage and tracking—not on
  whether content merely passes through a content-stateless endpoint. Assess the anonymous App
  Attest installation identifier and retained IP as Device ID, retained provider operational/error
  records as Other Diagnostic Data, and retained request paths as Product Interaction. Use App
  Functionality, linked, and not tracking on the current evidence; do not select location,
  analytics, advertising, marketing, personalization, or other purposes without new evidence.
- [ ] Verify Delete Local Data and Delete Server Security Data remove only the state promised by
  their separate copy on the exact processed TestFlight build and deployed backend.
- [x] For the fresh-install-only build-4 transition, the installed intermediate development build
  completed Disconnect Google and local deletion. It predated Delete Server Security Data, but a
  read-only aggregate production query found zero installations, sessions, and pending challenges,
  so no live production identity existed to delete. The owner then uninstalled it and accepted
  re-entry of local items. Never install build 4 over an older app or claim migration.
