# App Privacy data inventory

This inventory drives the in-app disclosure, public privacy policy, Google verification, Apple
App Privacy answers, deletion implementation, request-capture tests, and processor contracts.
“Collected” below uses Apple's App Privacy concept and cannot be finalized until production
retention/logging is confirmed.

| Data / source | On-device use | Leaves device? | Recipient / purpose | Intended retention | Consent / control | Apple answer status |
|---|---|---:|---|---|---|---|
| Gmail OAuth credentials | Authenticate read-only Gmail calls | Google SDK/API only | Google authentication/API | Managed by Google/platform | Sign out; Disconnect/revoke | Not developer-collected unless backend receives tokens; verify final auth flow |
| Gmail sender/domain + subject | Candidate/retailer detection | Validated sender domain and sanitized subject for cloud fallback | Backend → Anthropic receipt extraction | Developer application: request lifetime only, no persistence; verify Anthropic/provider terms | Receipt-analysis consent | Likely “Other User Content” if retained; pending |
| Structured product fields or selected receipt product text | Item extraction | Yes; bounded JSON-LD product fields are preferred, otherwise minimized/redacted product lines | Backend → Anthropic receipt extraction | Developer application: request lifetime only, no persistence; verify Anthropic/provider terms | Receipt-analysis consent | Likely “Other User Content” if retained; pending |
| Gmail message ID/history cursor | Local dedup/incremental sync and current API response correlation | Message ID currently reaches the backend compatibility envelope but is stripped before Anthropic; history cursor stays local | Developer backend for request correlation; local app for history cursor | Developer application: request lifetime only, no persistence; local state until disconnect/delete or cursor expiry | Disconnect/delete | Pending final API-contract and provider review |
| Receipt attachment/image/PDF | Deterministic OCR | Raw bytes must remain device-only; OCR fallback text may leave | Backend → Anthropic only if disclosed/consented | Developer application: request lifetime only, no persistence; verify Anthropic/provider terms | Receipt-analysis consent | Pending final implementation |
| Wardrobe item attributes | Catalog + styling | Yes for AI styling | Backend → Anthropic outfit recommendation | Developer application: request lifetime only, no persistence; verify Anthropic/provider terms | Styling consent | Likely “Other User Content” if retained; pending |
| Wardrobe photos | Catalog display | No in v1 styling path | Local app | Until item/local-data deletion | Photo picker/camera; delete | Not collected if device-only |
| Purchase date/price/currency | Catalog/review/insights | No in v1 styling | Local app | Until item/local-data deletion | Review/edit/delete | Not collected if device-only |
| Outfit and wear history | Anti-repeat/history and explicit 1–5 feedback | Recent item IDs and bounded per-item rating summaries (item ID, average, count) leave for styling; no feedback free text or wear dates | Backend → Anthropic recommendation | Developer application: request lifetime only, no persistence; local history until delete; verify Anthropic/provider terms | Styling consent; delete | Pending retention interpretation |
| Occasion/context text | User-directed recommendation | Yes | Backend → Anthropic recommendation | Developer application: request lifetime only, no persistence; verify Anthropic/provider terms | Styling consent; user submits | “Other User Content” if retained; pending |
| App Attest key ID, verified public key, opaque Apple receipt, anonymous installation ID and assertion counter | Prove a genuine installation and renew backend access without a Wardrobe or Google account | Key ID/attestation/assertions leave; private key never leaves Secure Enclave | Apple App Attest certification → developer backend authentication/security store | Repository limits: 90 days after last successful use; revoked records 30 days; verified live deletion is synchronous; encrypted snapshots 14 days. Final-image deployment/restore evidence remains APP-009 work. Independent receipt validation/risk-metric policy remains pending. | **Settings → Privacy & Data → Delete Server Security Data** uses a fresh App Attest assertion; reinstall creates a new identity but does not delete the old row | Likely Device ID because it is an installation-level identifier retained by the developer; linkage and final answer pending |
| One-time App Attest challenges, hashed short-lived sessions and coarse rate windows | Replay prevention, authorization, quotas and abuse prevention | Yes | Developer backend security store | Repository maxima: challenge 70 minutes from issue; session hash 20 minutes from issue; rate-window hash five minutes after its one-minute/hourly window, enforced by a one-minute desired-production maintenance loop and request-time expiry cleanup | Automatic expiry; a verified server deletion removes current-secret-derived key/installation rows, while unlinkable pre-rotation HMAC rows expire within 65 minutes | Device ID and/or Diagnostics may apply depending linkage/logging; pending |
| IP address/request timing | Network delivery/security | Inherent | Host/backend abuse prevention | Raw IP is not stored in SQLite. Approved target: no application access log; unavoidable provider edge-IP logs 24 hours maximum. Fly enforcement remains unverified. | Policy/support request | Diagnostics/Identifiers depending retention/linkage; pending |
| Consent and automation preferences | Enforce user choices | No | Local UserDefaults | Until withdrawal/delete | Privacy Center | Not collected if device-only |
| Camera/photo-library selection | Add item photo | Selected asset only, device-local | Local app | Until item/delete | System permission/selection | Not collected if device-only |
| Notification schedule | Daily local reminder | Apple notification system | Local notification delivery | Until disabled | Reminder toggle/system settings | Usually not developer-collected; verify no push service |
| Crash/analytics diagnostics | None currently planned | No current SDK | N/A | N/A | N/A | Reassess before adding any SDK |

## Release-blocking confirmations

The exact approved developer-controlled schedule and its current compliance status live in
[`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md).

- [ ] Use synthetic/local request-capture fixtures to verify the exact allowlisted `/extract` and
  `/recommend` fields. In production, inspect only schema/field names and aggregate sizes—never
  capture or retain real receipt, wardrobe, prompt, or model-response bodies as evidence.
- [x] Confirm the application security-event schema is bounded and excludes payloads, credentials,
  IPs, and installation identifiers; confirm raw IP is absent from SQLite.
- [x] Disable application access logs in the production container command and pin that command with
  a regression.
- [ ] On the final deployed image, evidence seven-day sanitized-log retention and Fly edge fields
  plus the 24-hour provider raw-IP limit.
- [ ] Reconfirm Fly.io region, encrypted storage, 14-day snapshot expiry, and deletion/restore
  behavior against the final deployment.
- [ ] Confirm the production App Attest App ID prefix, entitlement/profile, environment, tester OS,
  signed runtime-field presence, iOS 27+ validation categories and exact allowed bundle builds,
  physical-device evidence, and which Apple receipt fields are retained.
- [x] Confirm the durable auth-store schema contains only public keys/receipts, anonymous
  installation IDs, counters, challenges, session hashes and rate windows—never Gmail receipt or
  wardrobe payloads.
- [x] Enforce deadline cleanup, 90-day inactivity purge, 30-day revoked-record purge, synchronous
  assertion-verified live deletion, safe SQLite/WAL maintenance, and the separate in-app server
  deletion control in the repository.
- [ ] Deploy and rehearse deletion/restore behavior; configure/evidence alert routing and publish a
  monitored support process.
- [ ] Confirm unsupported App Attest, offline verification and backend failure preserve local
  wardrobe/Demo Mode while remote AI fails closed without creating an unauthenticated identifier
  or request.
- [x] Confirm the migration bridge is retired, `DEVICE_TOKEN` is unset/rotated, the obsolete
  shared-token build is rejected, and the deployed rollback boundary is App-Attest-only.
- [ ] After any auth schema/image change, re-scan the immutable candidate image and revalidate the
  retained App-Attest-only rollback image plus obsolete-build rejection.
- [ ] Confirm Anthropic API retention, training/model-improvement, human access, subprocessors and
  contract configuration in writing.
- [ ] Confirm Google accepts the final AI/processor architecture under Limited Use.
- [ ] Match every item above to the exact in-app notice and public policy wording.
- [ ] Complete Apple App Privacy answers based on actual retention, linkage and tracking—not on
  whether content merely passes through a content-stateless endpoint. Assess the anonymous App
  Attest installation identifier as Device ID rather than assuming it is uncollected or a User ID.
- [ ] Verify Delete Local Data, Delete Server Security Data, and Disconnect remove only the state
  promised by their separate copy on the exact processed TestFlight build and deployed backend.
