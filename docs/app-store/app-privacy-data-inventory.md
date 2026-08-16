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
| Stable backend subject/session | Authenticate/rate-limit public API | Yes | Developer backend security | Define exact expiry/security-log period | Disconnect/session expiry | Likely User ID if retained; pending |
| IP address/request timing | Network delivery/security | Inherent | Host/backend abuse prevention | Define exact log period | Policy/support request | Diagnostics/Identifiers depending retention/linkage; pending |
| Consent and automation preferences | Enforce user choices | No | Local UserDefaults | Until withdrawal/delete | Privacy Center | Not collected if device-only |
| Camera/photo-library selection | Add item photo | Selected asset only, device-local | Local app | Until item/delete | System permission/selection | Not collected if device-only |
| Notification schedule | Daily local reminder | Apple notification system | Local notification delivery | Until disabled | Reminder toggle/system settings | Usually not developer-collected; verify no push service |
| Crash/analytics diagnostics | None currently planned | No current SDK | N/A | N/A | N/A | Reassess before adding any SDK |

## Release-blocking confirmations

- [ ] Capture and inspect every production `/extract` and `/recommend` request body.
- [ ] Confirm the backend logs, metrics, traces, exception capture, IP handling and retention.
- [ ] Confirm Fly.io region, storage/logging and deletion behavior.
- [ ] Confirm Anthropic API retention, training/model-improvement, human access, subprocessors and
  contract configuration in writing.
- [ ] Confirm Google accepts the final AI/processor architecture under Limited Use.
- [ ] Match every item above to the exact in-app notice and public policy wording.
- [ ] Complete Apple App Privacy answers based on actual retention, linkage and tracking—not on
  whether data merely passes through a stateless endpoint.
- [ ] Verify Delete Local Data and Disconnect remove all state promised by their copy.
