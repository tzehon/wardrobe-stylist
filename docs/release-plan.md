# Release plan

Updated 10 September 2026 after the owner requested a reset and simplification.
This is the current work order. The backlog inventories work and the TestFlight runbook retains
procedures and dated evidence; neither is a list to replay from the beginning.

## Next outcome: verify the delivered TestFlight build

Build **1.0.0 (7)** has completed validation/upload and Apple processing. App Store Connect shows
it **Complete / Ready to Submit**, assigned only to `Family` Internal Testing with one group
tester and no individual testers. The approved AI-disabled notes are saved and reload-verified.
The existing **Automatic for Xcode Builds** setting was preserved; no manual assignment was needed.
See the [10 September distribution record](app-store/internal-testflight-runbook.md#build-7-distribution--2026-09-10).

The next work is the owner-controlled handoff, clean installation and physical QA. Cataloging clothing,
photos, editing, wear history, reminders and Demo Mode are the core of this beta. Remote AI is
explicitly unavailable while its separate activation work remains open, as the saved notes explain.
This is a testing milestone, not a change to the approved Free, Singapore-only public launch.

Builds **4–7 are consumed and must never be reused**. Build 6 is non-promotable because of the
consent-button presentation defect; the replacement control is implemented in build 7. The
purpose-specific preflight passed for the AI-disabled beta before the separately approved upload.
PR #46 merged the release refactor. Documentation corrections do not change the iOS bundle,
API contract, production resources or stored data and do not require build 8.

1. **Complete the owner-controlled identity-safe handoff.** Keep the existing installation until
   the owner clears the applicable runbook stage. Delivery does not authorize local/server
   deletion, uninstall or replacement.
2. **Install the processed build cleanly after the handoff.** Use the delivered `1.0.0 (7)` beta;
   do not re-upload it or install it over the predecessor before the handoff is complete.
3. **Verify the physical delta.** Check the fixed consent control in Dark Mode and perform the
   brief local/catalog/Demo smoke in the saved tester notes. Keep AI disabled; a production
   styling call belongs to separately approved AI activation. Repeat other physical rows only
   when behavior changed or retained evidence is missing, rather than replaying the full matrix.

If this QA requires an iOS fix, determine the next unused build number and repeat the applicable
review/distribution checks for that new candidate. Do not rebuild or re-upload because operator
documentation changed. **Ready to Submit** is Apple's build status, not public-submission approval.
Internal testers must meet
Apple's App Store Connect tester requirements; a wider external beta is a separate distribution
choice, not a reason to grant account roles casually.
[Apple internal testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/).

## Then: activate AI for the small pilot

Keep the existing backend, anonymous App Attest access, server-held provider key and durable global
AI budget. Do not redesign authentication, migrate storage, reset the ledger or evaluate another
model to finish this release.

- Resolve the actual privacy/provider-terms and consent questions for the AI flow. Update public
  disclosures and Apple answers accurately. Make a new iOS build only if the bundled notice or
  behavior needs to change; decide that before another archive/upload cycle.
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

The existing snapshot-expiry and deletion-specific recovery evidence remain open until verified.
They are a separate privacy/recovery track; their waiting period does not stop unrelated beta
preparation or visual QA. Do not mark them complete from elapsed time, erase the evidence, or make
an unsupported deletion promise. Historical Google cleanup stays separate from the Gmail-free
candidate and does not expand into new Gmail product work.

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
