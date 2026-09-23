# Singapore submission preparation — 12 September 2026

> **23 September:** Apple approval and owner-authorized manual release of build 7 completed
> after the full preflight passed. Singapore storefront propagation remains pending. See the
> [current launch record](launch-check-20260923.md). Do not repeat the completed transmission,
> submission or release actions below.

## Historical preparation and correspondence — through 19 September

Status: **19 September Guideline 4.3(a) rejection; Rejected / Unresolved Issues; clarification reply sent at 15:46 SGT; awaiting Apple; manual public release remains unapproved**. Build
`1.0.0 (7)` remains the existing processed candidate. The owner approved source publication,
saving the prepared Apple draft and the minimal App Store compatibility deployment. The later
contact correction retains that scope; private approval/amendment records bind the corrected
package. Documentation, store assets, backward-compatible backend configuration and the local
preflight correction need **no new TestFlight build**. The later owner-approved information
response and video submission likewise retain the existing build.

Apple's newest message, dated **19 September, 07:18 SGT**, cites **Guideline 4.3(a) — Design —
Spam**. The signed-in desktop app initially showed **Messages (5)** and **Rejected / Unresolved Issues**.
Apple alleges similarity to other developers' apps and requests distinct content and functionality,
but does not identify a matching app, code path or feature. See the
[rejection and response plan](spam-rejection-20260919.md).
The [business-model response](business-model-response-20260916.md) was sent unchanged with owner
approval at **16:14 SGT on 16 September**. On **19 September at 15:46 SGT**, the exact
**1,399-character** clarification reply was sent after the owner approved the visible draft and
asked to reply. The desktop app then confirmed **Messages (6)** and the sent owner message;
**Rejected / Unresolved Issues** remains unchanged. No appeal, resubmission, new build,
Notes/listing/attachment change or production change was performed. This correspondence
requires no new TestFlight build.

## Confirmed account and draft state

App Store Connect inspection and approved draft saves confirmed:

- Existing bundle ID and immutable SKU: `com.tth.Wardrobe`; Apple ID `6789053566`.
- Primary language English (U.K.); version `1.0.0` with build 7 passed Add for Review validation,
  then was submitted with separate owner approval on 12 September at 15:32 SGT (07:32 UTC).
  Apple initially confirmed **Waiting for Review**. The [13 September information request](internal-testflight-runbook.md#apple-information-request--13-september-2026)
  changed the status to **Rejected / Unresolved Issues**. After the approved reply/video at
  11:55 SGT and resubmission at 11:56 SGT, Apple then showed the submission and sole item as
  **Waiting for Review**. See the [completed response](internal-testflight-runbook.md#apple-information-response-and-resubmission--13-september-2026).
  Manual release was reverified; Apple approval and public release have not occurred.
- Free/Paid agreements active; bank and tax records active/complete; DSA trader status active.
- Singapore is the sole available territory; 174 territories are not available.
- Tax category is App Store software; Apple Standard License Agreement is selected.
- Listing text, subtitle, Lifestyle category, URLs and copyright are saved. The 12 September
  corrected reviewer notes were saved and reload-verified at 2,064 characters. They were replaced
  on 13 September by the final 3,943-character six-part response, again saved and reload-verified.
  Separate support/privacy links and the fictional top/trousers/shoes instructions remain.
- Existing build 7 is selected. No sign-in is required; manual release is saved.
- Age rating is 9+ from the lifestyle-content questionnaire, with medical content None. Content
  rights is Yes on the owner's explicit assurance. No accessibility capability was asserted.
- The corrected owner-confirmed review contact is saved and reload-verified privately.
- Five fictional screenshots are uploaded in Catalog/editor/detail/Today/History order and
  reload-verified. The smaller 6.5-inch slot automatically uses the 6.9-inch images.
- Free pricing (Singapore base price SGD 0.00) and disabled Mac/Vision availability are saved
  and reload-verified, with Singapore available and 174 other territories unavailable.

Personal contact/account information remains in ignored private evidence. Existing agreements
were retained; no new agreement was accepted. The later explicit Submit for Review action sent
the candidate to Apple. Draft saves and asset uploads alone did not submit it; none of these
actions publicly releases the app while manual release remains selected.

## Reviewable materials

- [Saved listing copy and remaining settings](metadata-draft.md).
- [Concise reviewer instructions](review-notes-1.0.0.txt), including a complete fictional outfit catalog
  and Settings → Connected Features consent path. There is no review-fixture import feature.
- Five screenshots: Catalog, item editor, item detail, Today and History. The optional sixth
  settings frame is omitted to avoid confusing Demo-only availability with the real app.
- Private package: `.fly/app-store-submission-20260912/`, including original screenshots,
  opaque upload JPEGs, SHA-256 manifest, contact proposal and a local HTML preview.

A Release simulator build from `cdb4b0a22f9c5ef4560be3123a3dcc46e3d3d895` passed compilation and
`verify-release-artifact.sh`. It retains version/build `1.0.0 (7)` and uses the same Release UI
paths as the delivered candidate; later Today/app-shell harness additions are DEBUG-only. This
simulator build is not the signed Apple archive. Capture used iPhone 17 Pro Max / iOS 26.5,
Light appearance, default English system formatting and a 9:41 status bar. All five 1320 × 2868
JPEGs were inspected; they retain native scroll-edge clipping/truncated item labels and have no
alpha, personal data, error state or added framing. Original PNGs remain available.

The screenshot-only preparation passed the Release compilation/artifact check and metadata
character/keyword-byte validation. The subsequent backend compatibility/preflight change passed
870 backend tests, locked pip-audit, Bandit, Ruff and mypy, 237 iOS tests and all 44 release-script
tests. No shipped iOS source or API contract changed.

## Backend configuration deployment

PR #54 merged the reviewed categories `2,4`, retaining builds `4,5,6,7`. The approved configuration
deployment completed as **Fly v14**. An independent postcheck passed at
`2026-09-12T06:36:24Z`: exact original image, Machine, volume, keys, policy and intact ledger were
preserved, with no paid call. The lock now records observed v14/categories `2,4` while retaining
all image/archive bindings. The full post-change review at `2026-09-12T07:09:37Z` completed with
the approved Cowork-only status exception; every other operational check passed, including the
exact recovery-image scan. No paid calls or provider/resource mutations were made.
Before that full review, the complete regression was rerun on the observed v14 lock: 870 backend tests and locked
security/lint/type checks, 237 iOS tests (227 Swift/10 UI; completed `06:51:51Z`) and 44 release-script
tests passed. Later operations-result documentation retains this exact tested lock/runtime/iOS
state; it does not require another code-change regression or a new TestFlight build.

`fly.toml` is deployment configuration and is not copied into the Docker image. The read-only
operations verifier therefore excludes it from immutable-image source equivalence while keeping
all image/runtime-contract inputs protected. Configuration is independently checked against exact
local, live-app and Machine values. A strict local section/app/region guard rejects unreviewed
deployment additions. Regressions prove protected source changes and category mismatches across
local/live/Machine/private review records still fail. Keep the actual deployed image source
revision unchanged when updating the post-deployment release/category review lock.

## Remaining execution

1. Retain the verified Free/Singapore/iPhone-only draft, screenshot order, saved build 7,
   declarations, corrected review contact/notes and manual release. Add for Review validation
   is complete; do not repeat the upload or draft-entry work.
2. Retain the [completed final v14 review](internal-testflight-runbook.md#final-v14-operations-review--12-september-2026)
   and its explicit Cowork-only exception. Keep the existing cost envelope and daily review;
   Fly has no hard invoice cap. A new failure or configuration change requires the applicable
   approved response. Preserve the exact image, resources, keys, policy and intact ledger;
   no iOS rebuild or additional paid test is proposed.
3. Await Apple's clarification in response to the [19 September reply](spam-rejection-20260919.md),
   sent and verified at **15:46 SGT**. Owner facts about template use and related submissions
   remain unconfirmed; the sent reply makes no assurances about them. Consider an appeal if the
   concern remains unresolved; change the product only when the evidence warrants it.
   No appeal or resubmission has been performed. The earlier
   [walkthrough and six-part response](review-walkthrough-20260913.md), saved 13 September Notes
   and video remain unchanged. Obtain owner approval for any further reply or appeal.
   **Manual release** remains selected and needs separate owner approval; Apple approval does
   not itself publish the app under that setting.

The owner separately requested [Google project retirement](../gcp-retirement-20260919.md) on
19 September. Both Wardrobe project shutdowns were accepted; final provider deletion remains
pending after the recovery period. The legacy shutdown action is complete and does not change
the verified Gmail-free Free Singapore v1. APP-036 remains in progress for final public release;
this cleanup does not grant release approval.

The completed local QA, privacy publication, bounded AI activation and first protected call are
retained; do not repeat handoff/deletion or routine manual regression. The existing narrowly scoped
snapshot/recovery waiver remains accepted risk, not new deletion/purge proof.
