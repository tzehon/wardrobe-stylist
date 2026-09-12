# AI pilot privacy review — 12 September 2026

Status: prepared for owner review; no policy publication, Apple declaration change, paid call or
AI activation. Reviewed repository source: `3c58dce`, with the delivered build `1.0.0 (7)` notice.
The last verified Fly v12 runtime remains the disabled baseline; this review is not a fresh live
operations check. Private limits, provider identifiers and credentials are excluded.

## Decision

Retain build 7 and consent notice version 3 for the existing styling flow. Publish the updated
[privacy proposal](privacy-policy-proposed-20260909.md) before enabling AI and reconcile the
[Apple inventory](app-privacy-data-inventory.md). No new TestFlight build is required for these
documentation changes. This is the implementation assessment, not an assertion of Apple approval.

The bundled notice already names Anthropic, the requested styling purpose and all transmitted
fields, and requires explicit permission before sending them. It makes no zero-retention promise.
Settings exposes the public privacy-policy link. The proposed update explains existing provider
handling and service accounting without adding a recipient, device field or processing purpose.
The separate budget ledger receives no installation ID, wardrobe, prompt or response payload.
Its random reservation references and aggregate liability survive individual identity deletion;
they are not a new personal profile. The in-app deletion control already limits its promise to
the live anonymous security record.

Retain the existing explicit opt-in. If the final proposal instead changes the payload, provider,
purpose or bundled promises, reassess consent/versioning before enabling that changed flow.
[Apple 5.1.1–5.1.2](https://developer.apple.com/app-store/review/guidelines/#privacy)
requires accessible privacy disclosures and permission before sharing personal data with third-party AI.

## Verified provider and publication evidence

On 12 September, signed-in Claude Console Privacy controls showed organization retention **on,
30 days**, **Allow user feedback off**, and a **Join** action for the Development Partner Program.
The Wardrobe Production workspace exists; its single listed key expires 8 October. No settings
were changed and no key value was copied. No bespoke retention contract or ZDR grant was presented.
Do not describe this account as ZDR or assume private contract exceptions.

The current [Commercial Terms](https://www.anthropic.com/legal/commercial-terms) permit powering
customer-facing products, prohibit training on customer content, and incorporate the
[DPA](https://www.anthropic.com/legal/data-processing-addendum). The DPA describes processor duties,
authorized-person confidentiality, subprocessor protections and assistance with data requests.
These are the published standard terms; no new agreement was accepted in this review.

The [commercial retention policy](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
sets the ordinary 30-day period with legal/enforcement exceptions, including two-year flagged
content and seven-year safety scores. The proposal now distinguishes provider retention from
request-only processing in the developer application. The
[training explanation](https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training)
separately identifies feedback/opt-in exceptions. Source inspection confirms synchronous Messages,
no Files/Batch/feedback endpoint and no end-user identity metadata in the provider request.

Both pages of the current [subprocessor list](https://trust.anthropic.com/subprocessors) were
reviewed. It covers infrastructure, routing, support, billing and security vendors as well as
product-specific vendors. Listing a vendor does not prove every styling request reaches it;
Wardrobe does not invoke provider web-search or voice tools. The
[region disclosure](https://privacy.claude.com/en/articles/7996890-where-are-your-servers-located-do-you-host-your-models-on-eu-servers)
describes US storage and international processing, including internal safety/support work.
No Singapore-only processing or no-human-access claim is supported.

An anonymous fetch of the [live privacy page](https://blog.tth.dev/wardrobe/privacy/) succeeded.
It still has the 21 August effective date and describes only security/authentication records,
omitting the newer budget ledger and explicit API retention. The proposed replacement has no
effective date until publication. Historical publication evidence is preserved.

## Proposed Apple answers

Apple counts off-device information accessible beyond the immediate request, including partner
retention. Optional styling is a primary feature, so its consent button alone does not exempt it.
See [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/).

| Information | Proposed declaration | Reason |
|---|---|---|
| Compact wardrobe attributes, recent item IDs, average ratings/counts and occasion text | Other User Content; App Functionality and Product Personalization; linked; not tracking | Provider retention is confirmed; suggestions adapt to personal wardrobe/preferences. Anonymous access does not establish de-identification. |
| App Attest/security identifiers and retained hosting metadata | Existing Device ID, Other Diagnostic Data and Product Interaction declarations; App Functionality; linked; not tracking | Preserve the existing security/hosting classification; do not infer advertising or analytics use. |
| Local photos, purchase details, full history and local preferences | Not collected in the current v1 flow | These remain on device; only the specified summaries leave. |
| Separate global budget/reservation ledger | No additional device-collected category solely for this store | Backend-generated aggregate accounting has no installation or user identifier; still disclose its purpose and retention publicly. |

The personalization purpose applies to styling content, not automatically to security metadata.
These are prepared answers, not saved or published App Store Connect state. Apple allows updating
privacy answers without shipping a new app binary.

## Remaining actions

1. Approve and publish the proposed privacy wording, assign its actual effective date, and verify
   the rendered page and existing in-app link. Review/save the corresponding Apple answers.
2. Run the existing disabled pre-enable review against the approved private budget, current
   provider/workspace and fixed Fly resource envelope. Preserve residual Fly invoice exposure.
3. Present the exact bounded activation and verification-call package, then enable only on its
   approval. Keep real production styling proof separate from the automated local QA already passed.

Snapshot/recovery waiver work is tracked separately. No additional monitoring service, model
migration, storage reset, routine phone QA or replacement archive is introduced by this review.
