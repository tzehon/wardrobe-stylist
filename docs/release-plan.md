# Release plan

Updated 12 September 2026; retains the owner-requested 10 September simplification.
This is the current work order. The backlog inventories work and the TestFlight runbook retains
procedures and dated evidence; neither is a list to replay from the beginning.

## Completed: verify the delivered local-first TestFlight beta

Build **1.0.0 (7)** has completed validation/upload and Apple processing. App Store Connect shows
it **Complete / Ready to Submit**, assigned only to `Family` Internal Testing with one group
tester and no individual testers. The approved AI-disabled notes are saved and reload-verified.
The existing **Automatic for Xcode Builds** setting was preserved; no manual assignment was needed.
See the [10 September distribution record](app-store/internal-testflight-runbook.md#build-7-distribution--2026-09-10).

The owner-controlled handoff, clean installation and scoped local-beta QA passed on 11 September.
Preparing the separately approved AI pilot is the next work. Cataloging clothing,
photos, editing, wear history, reminders and Demo Mode are the core of this beta. Remote AI is
explicitly unavailable while its separate activation work remains open, as the saved notes explain.
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
   Keep AI disabled; protected production styling proof belongs to separately approved activation.

If this QA requires an iOS fix, determine the next unused build number and repeat the applicable
review/distribution checks for that new candidate. Do not rebuild or re-upload because operator
documentation changed. **Ready to Submit** is Apple's build status, not public-submission approval.
Internal testers must meet
Apple's App Store Connect tester requirements; a wider external beta is a separate distribution
choice, not a reason to grant account roles casually.
[Apple internal testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/).

## Next: prepare and separately approve the small AI pilot

Keep the existing backend, anonymous App Attest access, server-held provider key and durable global
AI budget. Do not redesign authentication, migrate storage, reset the ledger or evaluate another
model to finish this release.

- The [12 September privacy review](app-store/ai-pilot-privacy-review-20260912.md) confirms
  standard provider retention and prepares the public policy and Apple classifications. Retain
  build 7 and notice version 3 for the unchanged flow; publish the approved policy and verify the
  Apple answers. No new iOS build is needed solely for this disclosure/documentation update.
- Verify the existing approved limits, model/key/workspace, capacity and intact ledger while AI
  is still disabled. The pre-enable review expects disabled AI; it must not demand the enabled
  state that it is meant to precede. Retain the existing provider cap, credits and auto-reload-off
  setting. Rotate the provider key before its recorded 8 October expiry.
- Use the simple cost routine below and disclose residual Fly exposure in the enablement package.
  Present one bounded approval covering the exact enablement and verification call. Enable only
  after approval, then run the normal `ai-launch` review and protected-device styling proof.
  An enabled-state failure closes AI again through the reviewed response procedure.

The disabled pre-enable review and enabled post-change confirmation are distinct checkpoints.
Neither an internal beta nor a passing simulator suite proves that remote AI is ready.

## Public Singapore release

Finish the candidate-specific physical QA, applicable privacy/deletion/recovery evidence,
truthful privacy/support/Terms pages and App Privacy answers, screenshots/description, availability
and actual account agreements. Submit the reviewed build when those items are complete.
Apple processing/review time is outside this project's control.

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
