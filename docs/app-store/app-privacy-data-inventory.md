# App Privacy data inventory

This inventory drives the in-app disclosure, public privacy policy, Google verification, Apple
App Privacy answers, deletion implementation, request-capture tests, and processor contracts.
“Collected” below uses Apple's App Privacy concept and cannot be finalized until production
retention/logging is confirmed.

| Data / source | On-device use | Leaves device? | Recipient / purpose | Intended retention | Consent / control | Apple answer status |
|---|---|---:|---|---|---|---|
| Gmail OAuth credentials | Authenticate read-only Gmail calls | Google SDK/API only | Google authentication/API | Managed by Google/platform | Sign out; Disconnect/revoke | Not developer-collected unless backend receives tokens; verify final auth flow |
| Gmail sender/domain + subject | Candidate/retailer detection | Validated sender domain and sanitized subject for cloud fallback | Backend → Anthropic receipt extraction | Request only; verify logs/provider | Receipt-analysis consent | Likely “Other User Content” if retained; pending |
| Structured product fields or selected receipt product text | Item extraction | Yes; bounded JSON-LD product fields are preferred, otherwise minimized/redacted product lines | Backend → Anthropic receipt extraction | Request only; verify logs/provider | Receipt-analysis consent | Likely “Other User Content” if retained; pending |
| Gmail message ID/history cursor | Local dedup/incremental sync and current API response correlation | Message ID currently reaches the backend compatibility envelope but is stripped before Anthropic; history cursor stays local | Developer backend for request correlation; local app for history cursor | Backend request only plus local state until disconnect/delete or cursor expiry; verify logs | Disconnect/delete | Pending final API-contract and logging review |
| Receipt attachment/image/PDF | Deterministic OCR | Raw bytes must remain device-only; OCR fallback text may leave | Backend → Anthropic only if disclosed/consented | Request only; verify | Receipt-analysis consent | Pending final implementation |
| Wardrobe item attributes | Catalog + styling | Yes for AI styling | Backend → Anthropic outfit recommendation | Request only; verify logs/provider | Styling consent | Likely “Other User Content” if retained; pending |
| Wardrobe photos | Catalog display | No in v1 styling path | Local app | Until item/local-data deletion | Photo picker/camera; delete | Not collected if device-only |
| Purchase date/price/currency | Catalog/review/insights | No in v1 styling | Local app | Until item/local-data deletion | Review/edit/delete | Not collected if device-only |
| Outfit and wear history | Anti-repeat/history and explicit 1–5 feedback | Recent item IDs and bounded per-item rating summaries (item ID, average, count) leave for styling; no feedback free text or wear dates | Backend → Anthropic recommendation | Request only; local history until delete | Styling consent; delete | Pending retention interpretation |
| Occasion/context text | User-directed recommendation | Yes | Backend → Anthropic recommendation | Request only; verify | Styling consent; user submits | “Other User Content” if retained; pending |
| App Attest key ID, verified public key, opaque Apple receipt, anonymous installation ID and assertion counter | Prove a genuine installation and renew backend access without a Wardrobe or Google account | Key ID/attestation/assertions leave; private key never leaves Secure Enclave | Apple App Attest certification → developer backend authentication/security store | Define exact active, revoked, backup/snapshot and deletion periods; normal update retains identity, reinstall/migration/restore creates a new one; independent receipt validation/risk-metric policy remains pending | Session expiry; reinstall/reset/support deletion process must be defined | Likely Device ID because it is an installation-level identifier retained by the developer; linkage and final answer pending |
| One-time App Attest challenges, hashed short-lived sessions and coarse rate windows | Replay prevention, authorization, quotas and abuse prevention | Yes | Developer backend security store | Define challenge/session TTLs, rate-window cleanup, logs and backup/snapshot periods from production truth | Automatic expiry; support/deletion process must be defined | Device ID and/or Diagnostics may apply depending linkage/logging; pending |
| IP address/request timing | Network delivery/security | Inherent | Host/backend abuse prevention | Define exact log period | Policy/support request | Diagnostics/Identifiers depending retention/linkage; pending |
| Consent and automation preferences | Enforce user choices | No | Local UserDefaults | Until withdrawal/delete | Privacy Center | Not collected if device-only |
| Camera/photo-library selection | Add item photo | Selected asset only, device-local | Local app | Until item/delete | System permission/selection | Not collected if device-only |
| Notification schedule | Daily local reminder | Apple notification system | Local notification delivery | Until disabled | Reminder toggle/system settings | Usually not developer-collected; verify no push service |
| Crash/analytics diagnostics | None currently planned | No current SDK | N/A | N/A | N/A | Reassess before adding any SDK |

## Release-blocking confirmations

- [ ] Capture and inspect every production `/extract` and `/recommend` request body.
- [ ] Confirm the backend logs, metrics, traces, exception capture, IP handling and retention.
- [ ] Confirm Fly.io region, storage/logging and deletion behavior.
- [ ] Confirm the production App Attest App ID prefix, entitlement/profile, environment, tester OS,
  signed runtime-field presence, iOS 27+ validation categories and exact allowed bundle builds,
  physical-device evidence, and which Apple receipt fields are retained.
- [ ] Confirm the durable auth-store schema contains only public keys/receipts, anonymous
  installation IDs, counters, challenges, session hashes and rate windows—never Gmail receipt or
  wardrobe payloads. Record volume/database topology, encryption, access, snapshot/backup,
  restore, retention, revocation and deletion behavior.
- [ ] Confirm unsupported App Attest, offline verification and backend failure preserve local
  wardrobe/Demo Mode while remote AI fails closed without creating an unauthenticated identifier
  or request.
- [ ] Confirm any migration bridge has expired, `DEVICE_TOKEN` is unset/rotated, obsolete builds
  are rejected, and the retained rollback image remains App-Attest-only.
- [ ] Confirm Anthropic API retention, training/model-improvement, human access, subprocessors and
  contract configuration in writing.
- [ ] Confirm Google accepts the final AI/processor architecture under Limited Use.
- [ ] Match every item above to the exact in-app notice and public policy wording.
- [ ] Complete Apple App Privacy answers based on actual retention, linkage and tracking—not on
  whether content merely passes through a content-stateless endpoint. Assess the anonymous App
  Attest installation identifier as Device ID rather than assuming it is uncollected or a User ID.
- [ ] Verify Delete Local Data and Disconnect remove all state promised by their copy.
