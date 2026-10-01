# Release plan

> **Public release — 23 September:** After the complete production preflight passed at
> `14:31:20Z`, the owner-authorized release of `1.0.0 (7)` was confirmed at approximately
> `14:33Z` (22:33 SGT). App Store Connect shows **Ready for Distribution**. Free,
> Singapore-only distribution is retained. By `14:44Z` (22:44 SGT), the anonymous public
> listing was live and Apple showed Singapore **Available**, with 174 territories unavailable.
> At the 23 September release checkpoint, Fly v15 was healthy with the repaired dependency and intact storage/limits. See the
> [launch evidence](app-store/launch-check-20260923.md). Earlier rejection and hold records are historical.
> No new TestFlight build was needed; approved build 7 was released.

Updated 1 October 2026; retains the owner-requested 10 September simplification.
This is the current work order. The backlog inventories work and the TestFlight runbook retains
procedures and dated evidence; neither is a list to replay from the beginning.

The next product step is to review the [1 October pricing and allowance proposal](freemium-model.md#pricing-and-allowance-proposal--1-october-2026)
for APP-037: assess S$4.98/month for 30 paid generations, with 5 Free generations per UTC month.
The owner requested profitability validation; actual costs remain unavailable in this workspace.
The illustrative planning case breaks even at 21 paid subscribers with 20 Free users, or 23 with
full use of the initial one-delivery-credit-per-period design; the stress
case loses money per subscriber after assumed support. These are not approved paid-launch terms.
Verify current commerce terms, production economics
and capacity under the existing private budget before selecting the offer and implementing
commerce/metering. The [commerce contract draft](freemium-contract.md) defines the next implementation
slices and the owner's selected bounded automatic-credit policy. The initial design cap is one
delivery credit per owner per allowance period; ownership/retention/cutover work remains open.
Cost verification remains deferred at the owner's request. The inactive quota policy, usage schema,
Swift/Pydantic mirrors and shared fixtures are implemented locally; verification and the remaining
Apple/store/API/UI integration are incomplete. The public app remains Free; daily operating review
continues below.

## Completed: verify the delivered local-first TestFlight beta

Build **1.0.0 (7)** has completed validation/upload and Apple processing. App Store Connect shows
it **Complete / Ready to Submit**, assigned only to `Family` Internal Testing with one group
tester and no individual testers. The initial AI-disabled notes were saved and reload-verified;
the saved notes now describe the separately approved enabled pilot.
The existing **Automatic for Xcode Builds** setting was preserved; no manual assignment was needed.
See the [10 September distribution record](app-store/internal-testflight-runbook.md#build-7-distribution--2026-09-10).

The owner-controlled handoff, clean installation and scoped local-beta QA passed on 11 September.
The bounded AI pilot was separately approved and enabled as Fly v13 on 12 September. Cataloging
clothing, photos, editing, wear history, reminders and Demo Mode remain local. The first protected
TestFlight styling request passed on 12 September; the saved notes now explain the enabled pilot.
This is a testing milestone, not a change to the approved Free, Singapore-only public launch.

11 September partial physical evidence: the owner reports an in-place TestFlight update to build 7.
The normal-state consent button passes visual inspection in the supplied Dark Mode screenshot,
and the owner confirms existing wardrobe items and wear history remain visible. Offline Demo
opening and sample-wardrobe browsing also pass with Airplane Mode on and Wi-Fi off.
Those initial observations were from the in-place update. Pressed/disabled device captures were
not collected; their deterministic contrast checks are automated. The later clean installation
and full regression complete this local-beta milestone without repeating the unchanged screen.
The approved in-app server deletion has since passed: the owner saw success, fresh live aggregates
are zero and one bounded deletion-success marker was observed. The owner subsequently confirmed
**Local Data Deleted**, removal of the app and clean installation of TestFlight `1.0.0 (7)`.
After **Start with my wardrobe**, Wardrobe and History are empty, AI permission remains off and
the confirmed version is `1.0.0 (7)`. Fresh live installation/session/challenge counts remain zero.
The owner-controlled handoff and clean-install first-launch checks are complete.
See the [physical checkpoint](app-store/internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial).

Builds **4–7 are consumed and must never be reused**. Build 6 is non-promotable because of the
consent-button presentation defect; the replacement control is implemented in build 7. The
purpose-specific preflight passed for the AI-disabled beta before the separately approved upload.
PR #46 merged the release refactor. Documentation corrections do not change the iOS bundle,
API contract, production resources or stored data and do not require build 8.

1. **Handoff complete.** Owner-approved server deletion was verified before local deletion and
   app removal. Do not repeat deletion or uninstall for the remaining QA.
2. **Clean installation complete.** The owner confirmed processed `1.0.0 (7)`, empty local state
   and AI permission off; the subsequent live check remained at zero security aggregates.
3. **Automated verification complete.** Retain the normal-state Dark Mode screenshot, completed
   handoff and brief smoke observations. The 11 September owner correction withdraws the extra
   manual photo/edit/relaunch request: routine catalog, persistence, Demo and button-state contrast
   checks belong in the suite. The added disk-persistence test and full regression passed:
   237 iOS tests, 840 backend tests with all locked checks, and 44 release-script tests. Ask for
   another device action only for a concrete uncovered physical boundary; see
   [QA ownership](app-store/internal-testflight-runbook.md#qa-automation-ownership--2026-09-11).
   AI stayed disabled through local QA. The separately approved 12 September activation is
   complete; its protected-device styling proof passed on 12 September.

If this QA requires an iOS fix, determine the next unused build number and repeat the applicable
review/distribution checks for that new candidate. Do not rebuild or re-upload because operator
documentation changed. **Ready to Submit** is Apple's build status, not public-submission approval.
Internal testers must meet
Apple's App Store Connect tester requirements; a wider external beta is a separate distribution
choice, not a reason to grant account roles casually.
[Apple internal testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/).

## Current: operate the verified small AI pilot

The [29 September provider-key rotation](app-store/key-rotation-20260929.md) is complete on
Fly v16, with the unchanged runtime image/source and preserved storage, other secrets and budget
accounting. The old key is disabled; rotate the replacement before **30 November 2026**.

Keep the existing backend, anonymous App Attest access, server-held provider key and durable global
AI budget. Do not redesign authentication, migrate storage, reset the ledger or evaluate another
model to finish this release.

- The [12 September privacy review](app-store/ai-pilot-privacy-review-20260912.md) confirms
  standard provider retention. The approved policy and Apple privacy answers are published and
  verified. Retain build 7 and notice version 3 for the unchanged flow; no new iOS build is needed
  for this disclosure/documentation update.
- The disabled review and separate bounded activation approval completed on 12 September. Fly v13
  enabled styling on the same image, Machine and volume, with the exact approved policy and intact
  ledger. Retain the provider cap, credits and auto-reload-off setting. Rotate the key before its
  recorded 8 October expiry; the 29 September rotation completed that action, as recorded above.
- The v13 enabled `ai-launch` checks passed at `2026-09-12T04:28:57Z`, with the approved Cowork-only
  status exception and fresh API/Console operational evidence. The owner's one protected-device
  styling request passed on 12 September. Use the simple cost routine below; residual Fly invoice
  exposure is accepted, not capped. A failed protected call or enabled-state check closes AI again
  under the already-approved response procedure.

The disabled pre-enable review and enabled post-change confirmation are distinct checkpoints.
Neither an internal beta nor a passing simulator suite proves that remote AI is ready.

## Public Singapore release

**Historical state — 19 September (superseded by the release above):** Apple shows **Rejected / Unresolved Issues** for `1.0.0 (7)`.
Apple's newest message, dated **19 September, 07:18 SGT**, cites **Guideline 4.3(a) —
Design — Spam**: similarity of the binary, metadata or concept to apps from other developers,
with only minor differences. Apple requests distinct content and functionality, but identifies
no particular matching app, code path or feature. Its extended-review warning concerns repeated
problematic submissions; it is not evidence of a current account removal.
See the [rejection and response plan](app-store/spam-rejection-20260919.md).

The [business-model response](app-store/business-model-response-20260916.md) was sent unchanged
with owner approval at **16:14 SGT on 16 September**. After the owner approved the visible
clarification draft and asked to reply, the exact **1,399-character** response was sent through
the desktop app on **19 September at 15:46 SGT**. Apple shows **Messages (6)** and the sent
owner message; **Rejected / Unresolved Issues** remains unchanged. No appeal, resubmission,
build upload, Notes/listing/attachment change or production change was performed.
This correspondence requires no new TestFlight build; any later app change needs its own
release-impact assessment.

The [12 September package](app-store/submission-preparation-20260912.md) is approved for source
publication, Apple draft completion and the bounded App Store compatibility deployment. Apple
has saved the listing, Lifestyle category, age rating 9+, owner-confirmed content rights,
reviewer instructions, no-sign-in/manual-release settings and existing build 7. Five fictional
screenshots are uploaded, ordered and reload-verified. Free pricing and disabled Mac/Vision
availability are also saved and reload-verified. Agreements and bank/tax/DSA status are active; only Singapore is
selected. Fly v16 retains categories `2,4`; the historical v14 independent configuration verification passed at
`2026-09-12T06:36:24Z` with the exact original image/resources, secrets, policy and intact ledger.
No paid call was made. The full post-change review at `2026-09-12T07:09:37Z` completed with the
approved Cowork-only status exception; all other operational checks passed, including the recovery-image scan.
After separate owner approval, version `1.0.0` with build 7 was submitted to Apple on 12 September
at 15:32 SGT (07:32 UTC). On 13 September Apple marked the item **Rejected / Unresolved Issues**
under **Guideline 2.1 — Information Needed — New App Submission**, citing limited developer
review history. The message asked for a physical-device walkthrough on the latest operating
system and six-part supporting information; it identified no specific app defect.
See the [review checkpoint](app-store/internal-testflight-runbook.md#apple-information-request--13-september-2026).
After separate owner approval, the reviewed video and six-part reply were sent at 11:55 SGT on
13 September. Matching final App Review Notes were saved and reload-verified. The existing
`1.0.0 (7)` was resubmitted at 11:56 SGT; Apple then showed the submission and its sole item as
**Waiting for Review**. Manual release was reverified; Apple approval and public release had
not occurred at that 13 September checkpoint. See the [response and resubmission checkpoint](app-store/internal-testflight-runbook.md#apple-information-response-and-resubmission--13-september-2026).
This information response requires no new TestFlight build.

Retain the completed candidate QA, published privacy/support/Terms pages and App Privacy answers,
verified listing/media/availability, account agreements and scoped accepted recovery risk.
Apple approval and owner-authorized manual release completed on 23 September after the full
production preflight passed. Storefront propagation completed by 14:44Z: the anonymous public
listing is live, and App Store Connect shows Ready for Distribution with Singapore Available. No clarification reply, appeal,
new build or further release approval is currently needed. The 19 September questions about
provenance remain unverified historical context; this release makes no new authorship claims.
By 15:02Z on 23 September, the owner confirmed successful App Store download and launch.
The public support link and existing operating routine were handed off in the same task.
This closes the physical delivery follow-up with owner-reported evidence, not an agent-observed
installation or additional AI call. Preserve identity/data and do not replay completed QA.
Continue the approved daily cost review and rotate the replacement production key before 30 November 2026.
The owner-requested Google shutdowns were accepted on 19 September; final provider deletion
remains pending and is separate from the released Gmail-free app. APP-036 retains only the
explicitly open residual lifecycle/provider evidence; completed release and delivery steps must not be replayed.

The completed 89-second physical-device walkthrough shows launch, photo-item creation,
successful styling, Wear/History, privacy controls and build 7. The reviewed recording and
supporting evidence remain private. See the [completed walkthrough record](app-store/review-walkthrough-20260913.md).

On 11 September the owner explicitly waived the remaining snapshot-list-expiry and deletion-
specific recovery/non-return evidence sub-gate for the Free Singapore v1. A read-only check first
confirmed that the monitored 25/28 August snapshots were no longer customer-visible; a later same-
day check confirmed that the 10 September Build-7 pre-deletion snapshot was still listed with
status `created` and 14-day retention. This is accepted residual risk, not evidence that this later
snapshot disappeared, all copies were purged, or the deleted identity cannot return through
recovery; Fly's replica, backup and all-copy purge timing remains undisclosed. The
waiver removes only this evidence item as a Singapore-v1 submission blocker. Pre-deletion snapshots
remain ineligible for normal service recovery; emergency recovery uses fresh auth state and re-
enrollment, preserves the separate budget ledger, and keeps AI disabled if accounting consistency
cannot be proved. The scheduled snapshot wait was stopped without changing Fly resources, app or
production/local data, the installed app, or TestFlight state.

Historical Google cleanup stays separate from the Gmail-free candidate and does not expand into new
Gmail product work. APP-009/APP-036, privacy and submission items not covered by this specific waiver
retain their own status.

Paid plans, subscriptions, country expansion, widgets, new infrastructure and broader polish stay
out of this release. The [freemium model](freemium-model.md) documents the future offering without
making it another launch prerequisite. Free distribution does not by itself require a new paid-app/IAP agreement;
check actual account requirements instead of completing every generic commerce checklist.
[Apple agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/).

## Small-pilot cost routine

Keep the approved one-Machine/one-volume Fly resource envelope and existing private warning/hold
amounts. During the pilot, the owner reviews the AI ledger/provider spend and Fly invoice,
Cost Explorer and resource list daily, and after configuration changes or reported problems.
Record aggregate outcomes and discrepancies. Investigate warnings promptly; use the reviewed
manual hold procedure when its trigger is met. No new account or monitoring service is required.

The AI ledger bounds the app's approved provider usage. Fly's bill remains variable: manual
review has detection delay, traffic is not limited by the expected tester count, and storage
continues after stopping compute. A hosting target is not an enforced invoice cap. Unknown
billing coverage stays unknown; it is not zero usage or a promise of a maximum bill.
[Detailed hosting policy and response](fly-spend-controls.md),
[Fly cost-management limits](https://fly.io/docs/about/cost-management/).

Hourly GitHub/Healthchecks automation, complete edge-counter coverage and a custom billing
collector are deferred. They are operational improvements, not automatic prerequisites for
this internal beta. Do not add a new launch gate without identifying its concrete risk, why the
existing controls cannot address it and which release milestone it actually affects.

## Work and evidence discipline

Keep changes small. Run focused checks while editing and the repository-required full regression
on the final source before declaring the change complete. Reuse unchanged physical and signed
artifact evidence, refreshing facts that genuinely expire or depend on live configuration.
Keep the README current and record detailed outcomes in the existing runbook. Preserve approval
for the actual upload, paid call, production change or deletion; complete the reviewable package
first and do not ask again for an unchanged policy already approved.

The unshipped monitoring prototype and its evidence were preserved in an ignored private archive
before removal from the active checkout. Production app/auth/budget code, data and credentials
were not reset. The refactor's code change is the purpose-specific read-only operations review;
it does not relax the default AI-launch checks.
