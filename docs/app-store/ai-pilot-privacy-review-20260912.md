# AI pilot privacy review — 12 September 2026

Status: owner-approved policy and Apple privacy answers published on 12 September. This privacy
publication itself made no paid call or AI activation. Reviewed repository source: `3c58dce`,
with the delivered build `1.0.0 (7)` notice. Fly v12 was the disabled baseline at that checkpoint.
The subsequent separately approved [v13 activation](internal-testflight-runbook.md#bounded-ai-pilot-activation--2026-09-12)
and enabled operations review are complete; protected-device styling proof passed on 12 September.
This document is the privacy assessment, not live operations evidence. Private limits, provider
identifiers and credentials are excluded.

## Decision

Retain build 7 and consent notice version 3 for the existing styling flow. The updated
[policy](privacy-policy-proposed-20260909.md) and the Apple answers recorded in the
[inventory](app-privacy-data-inventory.md) are now published. No new TestFlight build is required
for these documentation changes. This is the implementation assessment, not an assertion of Apple approval.

The bundled notice already names Anthropic, the requested styling purpose and all transmitted
fields, and requires explicit permission before sending them. It makes no zero-retention promise.
Settings exposes the public privacy-policy link. The published update explains existing provider
handling and service accounting without adding a recipient, device field or processing purpose.
The separate budget ledger receives no installation ID, wardrobe, prompt or response payload.
Its random reservation references and aggregate liability survive individual identity deletion;
they are not a new personal profile. The in-app deletion control already limits its promise to
the live anonymous security record.

Retain the existing explicit opt-in. If a later change alters the payload, provider,
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

Before publication, an anonymous fetch of the [live privacy page](https://blog.tth.dev/wardrobe/privacy/) succeeded.
It had the 21 August effective date and described only security/authentication records,
omitting the newer budget ledger and explicit API retention. The replacement was subsequently published with the actual 12 September effective date.
Historical publication evidence is preserved.

## Approved and published Apple answers

Apple counts off-device information accessible beyond the immediate request, including partner
retention. Optional styling is a primary feature, so its consent button alone does not exempt it.
See [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/).

| Information | Published declaration | Reason |
|---|---|---|
| Compact wardrobe attributes, recent item IDs, average ratings/counts and occasion text | Other User Content; App Functionality and Product Personalization; linked; not tracking | Provider retention is confirmed; suggestions adapt to personal wardrobe/preferences. Anonymous access does not establish de-identification. |
| App Attest/security identifiers and retained hosting metadata | Device ID, Other Diagnostic Data and Product Interaction declarations; App Functionality; linked; not tracking | Use the reviewed security/hosting classification; do not infer advertising or analytics use. |
| Local photos, purchase details, full history and local preferences | Not collected in the current v1 flow | These remain on device; only the specified summaries leave. |
| Separate global budget/reservation ledger | No additional device-collected category solely for this store | Backend-generated aggregate accounting has no installation or user identifier; still disclose its purpose and retention publicly. |

The personalization purpose applies to styling content, not automatically to security metadata.
These answers were entered, published and reload-verified in App Store Connect. Its initial form
was empty; the previously prepared classifications were not previously saved Apple declarations.
Apple allows updating privacy answers without shipping a new app binary.

## Publication evidence

The owner answered **Proceed** to the request to publish this policy update and apply these Apple
answers. Website [PR #6](https://github.com/tzehon/tzehon.github.io/pull/6) received a clear Codex
review on `66731f5` and rebase-merged at `2026-09-12T03:09:38Z` as `cdef8874e69706712163c1f8031e40eac3593811`.
[GitHub Pages run 34669611500](https://github.com/tzehon/tzehon.github.io/actions/runs/34669611500)
passed Jekyll build and deployment; deploy completed at `03:10:20Z`. Anonymous HTTPS retrieval,
rendered browser text and visual inspection confirmed the new effective date, aggregate ledger,
provider retention/exceptions and deletion limits. The public body exactly matches this approved
source; existing support links and response target are preserved. Local Jekyll was unavailable
because Bundler 2.5.11 was missing; the successful hosted Jekyll build supplies rendering validation.

App Store Connect initially had no Privacy Policy URL or data declarations. The existing public
URL was saved, and exactly four categories above were configured, each linked and not tracking.
Only Other User Content additionally uses Product Personalization. After confirmation Apple showed
**Published a few seconds ago by tan tze hon** at the `03:14–03:15Z` verification checkpoint;
reload retained the publication, URL and four configured categories. This publishes privacy
metadata; the app version remains **Prepare for Submission**, with no review submission or release.

## Remaining actions

The disabled pre-enable review and separately approved activation completed on 12 September.
Fly v13 is enabled within the existing policy and fixed resource envelope. The enabled review
passed with the approved Cowork-only status exception; see the
[activation checkpoint](internal-testflight-runbook.md#bounded-ai-pilot-activation--2026-09-12).
The first protected TestFlight styling request passed on 12 September. Preserve residual Fly invoice
exposure and keep physical proof separate from the automated local QA already passed.

The independently approved snapshot/recovery waiver merged through PR #49 and remains unchanged.
No additional monitoring service, model migration, storage reset, routine phone QA or replacement
archive is introduced by this review.
