# Guideline 4.3(a) assessment — 19 September 2026

> **Public release — 23 September:** After the complete production preflight passed at
> `14:31:20Z`, the owner-authorized release of `1.0.0 (7)` was confirmed at approximately
> `14:33Z` (22:33 SGT). App Store Connect shows **Ready for Distribution**. Free,
> Singapore-only distribution is retained. By `14:44Z` (22:44 SGT), the anonymous public
> listing was live and Apple showed Singapore **Available**, with 174 territories unavailable.
> Fly v15 is healthy with the repaired dependency and intact storage/limits. See the
> [launch evidence](launch-check-20260923.md). Earlier rejection and hold records are historical.
> No new TestFlight build was needed; approved build 7 was released.

## Historical rejection and correspondence

Status at 19 September: **Rejected / Unresolved Issues**, version **1.0.0 (7)**. Read directly from the owner's
open App Store Connect desktop app on 19 September. Apple's rejection arrived at **07:18 SGT**.
The owner-approved clarification was sent unchanged at **15:46 SGT** and verified in
**Messages (6)**. Await Apple's reply; no appeal or resubmission was performed.
This supersedes the earlier instruction to await
assessment of the [16 September business-model response](business-model-response-20260916.md).
The prior reply remains sent; this checkpoint does not establish that all earlier issues are closed.

## What Apple said

Apple cites **Guideline 4.3(a) — Design — Spam**, alleging similarity in the binary, metadata
and/or concept to apps submitted by other developers, with only minor differences. It asks for
distinct content and functionality and lists reused source/assets, repackaged templates and
similar submissions across accounts as possible factors. It identifies no particular matching
app, source fragment, screen or behavior.

The message also contains an **Extended Review** warning about significant safety, security or
quality concerns, longer review times for repeated submissions with these issues, and potential
Developer Program removal for repeated noncompliance. This is a material release blocker. It
does not identify a concrete security defect or say this account has been terminated.

## Recommended next step

1. Confirm the project's starting point, any template/third-party app source used, asset origins,
   and whether substantially the same app was submitted through another developer account.
   Repository history alone cannot establish those facts; an owner question is pending.
2. **Completed:** the owner-reviewed clarification below was sent at 15:46 SGT, describing the
   actual build-7 workflow and asking which elements caused the finding. It references the
   already attached physical-device video; no new recording or upload was needed. Await Apple's
   clarification before deciding whether further evidence or product changes are required.
3. If the finding appears mistaken after clarification, prepare one evidence-backed App Review
   Board appeal. If it identifies a real product similarity problem, define a focused substantive
   change before building. Do not repeatedly resubmit unchanged, make cosmetic changes solely to
   alter the binary, or switch bundle IDs/accounts to evade the finding.

Apple permits correspondence before resubmission and an appeal with specific reasons, after
answering information requests; it asks for only one appeal per rejected submission.
[Apple review process](https://developer.apple.com/distribute/app-review/#contacting-us).
Its [spam guideline](https://developer.apple.com/app-store/review/guidelines/#spam) addresses
duplicate submissions and apps indistinguishable from existing offerings. Those policies do not
reveal which comparison caused this specific rejection.

## Evidence and limits

- `ios/project.yml` declares a native iOS application and its test targets; it declares no
  third-party iOS package dependencies. This is not proof that every source file is original.
- Git history records incremental iOS work from May 2026 onward. Source history helps explain
  development; it cannot independently establish ownership or rule out copied/template code.
- `ios/Wardrobe/Stylist/WearHistory.swift` implements a 14-day recent-wear window and aggregates
  per-item ratings. `OutfitRecommender.swift` uses those signals with the user's catalog.
  The audited workflow source files are unchanged from archive source `0cc0fa7`, so these points
  apply to build 7 rather than an unshipped implementation.
- The existing build supports local wardrobe/photos and wear history, optional text-only AI
  requests, and offline fictional Demo Mode. These are demonstrable behaviors, not proof that no
  competing app offers them. Free pricing, Singapore availability and security engineering alone
  do not establish a distinct product experience.
- The [13 September walkthrough](review-walkthrough-20260913.md) already demonstrates photo
  entry, styling, Wear/History and privacy controls on the physical device. Preserve that evidence.
- The generic listing and fictional Demo screenshots may undersell the product. That is an
  assessment to investigate, not a reason Apple stated or evidence that a cosmetic refresh fixes
  the rejection. Demo entries omit photos and use standard SF Symbol fallbacks. The current icon
  has a PNG and replacement commit, but no creation/license record was found in this audit.
  Asset authorship and licensing need substantiation before making stronger claims.

## Sent clarification — 19 September, 15:46 SGT

Hello App Review,

Thank you for the feedback regarding Guideline 4.3(a). We take the similarity concern seriously and would appreciate clarification so we can address it appropriately before resubmitting.

Could you identify a specific screen, asset, metadata passage, binary component or aspect of the user experience that led to this finding? We understand you may not be able to disclose another developer’s submission; an actionable example from our app would help.

Wardrobe Stylist 1.0.0 (7) supports the following workflow:

- Users catalogue their own clothing manually or with photos, stored locally on their device.
- Optional AI styling proposes outfits from those items, using recent wear history and recorded ratings to inform suggestions.
- “Wear this” records the selected outfit in local History.
- Local catalog and history features remain usable without AI. AI requests require consent and an explicit user action, and exclude wardrobe photos.

The physical-device walkthrough attached to our 13 September response demonstrates photo-item creation, styling and Wear/History in this same build.

Could you clarify whether the concern primarily relates to implementation or asset reuse, similarities in the listing, or insufficiently distinct functionality? This will help us address the underlying issue with a focused response or appropriate changes.

Thank you for your guidance.

## Execution and release impact

An independent simulated App Store reviewer found no blocking issue in the initial clarification
draft. The owner then requested a reply draft in the conversation and explicitly instructed
“reply for me”. The exact final wording shown above was entered into the desktop app's composer;
the visible text and remaining-character count matched **1,399 characters**. The sent-message
entry dated **19 September, 15:46 SGT** and **Messages (6)** verified delivery. The reply makes
no originality or cross-account assurances while owner facts remain pending.

The native send click left the composer unchanged; after observing that state, keyboard focus
and Return submitted it. Delivery was verified before recording success; no duplicate reply
appeared. No appeal, attachment, metadata change, resubmission or public release was performed.
No production configuration, paid AI call, code or test input changed. The README and release
records were updated locally; no Git publication occurred. Manual public release remains subject
to separate owner approval after Apple approval.

**No new TestFlight build is needed for this assessment or clarification.** Whether the eventual
resolution requires a new binary remains undecided. If shipped iOS behavior or resources change,
verify the latest uploaded number and use the next unused build; build 7 is already consumed.
