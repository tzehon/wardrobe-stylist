# Internal TestFlight, always App-Store-ready

> **Public release — 23 September:** After the complete production preflight passed at
> `14:31:20Z`, the owner-authorized release of `1.0.0 (7)` was confirmed at approximately
> `14:33Z` (22:33 SGT). App Store Connect shows **Ready for Distribution**. Free,
> Singapore-only distribution is retained. By `14:44Z` (22:44 SGT), the anonymous public
> listing was live and Apple showed Singapore **Available**, with 174 territories unavailable.
> At the 23 September release checkpoint, Fly v15 was healthy with the repaired dependency and intact storage/limits. See the
> [launch evidence](launch-check-20260923.md). Earlier rejection and hold records are historical.
> No new TestFlight build was needed; approved build 7 was released.

Use this runbook for every internal beta. The audience is internal, but the binary is treated as
an App Store release candidate from the moment it is archived. This prevents a separate, weaker
"beta build" configuration from drifting away from what will eventually be reviewed.

## Provider-key rotation — 29 September 2026

The owner-authorized replacement is deployed on Fly v16 using the unchanged v15 image/source,
Machine and durable storage. Other secrets and budget accounting were preserved. The old key
is disabled, and backend authentication with the replacement passed again after that action.
The replacement expires on **30 November 2026**. No paid generation or new TestFlight build was
needed. See the [rotation record](key-rotation-20260929.md) for ordered evidence, validation and
the initial postcheck/aggregate-metrics limitations. This does not reopen completed release QA.

## Historical work order — 19 September 2026

Start with [the short release plan](../release-plan.md). This runbook retains operator procedures
and historical evidence; it is not a request to repeat every completed row. Internal beta
availability, optional AI activation and public App Store submission have separate requirements.
The owner requested a reset of the overgrown monitoring/release workflow on 10 September.

At the 23 September release checkpoint, the separately approved bounded AI pilot was enabled on Fly v15. Its v13 activation review passed
with the approved Cowork-only status exception; the first owner-controlled protected styling
request passed on 12 September. See the [activation checkpoint](#bounded-ai-pilot-activation--2026-09-12).
The [v14 compatibility checkpoint](#app-store-compatibility-deployment--12-september-2026) records
the later approved categories `2,4` deployment and independent configuration postcheck. The full
v14 review at `2026-09-12T07:09:37Z` subsequently completed with the approved Cowork-only status
exception; every other operational check passed. See the [final review](#final-v14-operations-review--12-september-2026).
The owner separately approved submission; Apple's version `1.0.0`/build-7 item was submitted at
15:32 SGT (07:32 UTC) on 12 September. On 13 September Apple marked the item **Rejected /
Unresolved Issues**, requesting additional information and a physical-device walkthrough.
See the [review checkpoint](#apple-information-request--13-september-2026) and the subsequent
[13 September resubmission](#apple-information-response-and-resubmission--13-september-2026).
The owner-approved business-model reply was sent unchanged on 16 September at 16:14 SGT.
The newest Apple message, **19 September at 07:18 SGT**, now cites **Guideline 4.3(a) — Design —
Spam**. After the owner approved the visible draft and asked to reply, the exact **1,399-character**
clarification was sent at **15:46 SGT on 19 September**. The desktop app verified **Messages (6)**
and the sent owner message; **Rejected / Unresolved Issues** remains unchanged.
That historical checkpoint awaited Apple's clarification; see the [rejection and sent reply](spam-rejection-20260919.md).
No appeal, resubmission, new build, Notes/listing/attachment change or production change was
performed. Manual release remains selected;
Apple approval and manual public release were open at that checkpoint; both completed on
23 September, with public Singapore storefront availability confirmed by 14:44Z. The owner-requested
[Google project shutdowns](../gcp-retirement-20260919.md) were accepted on
19 September; final provider deletion remains pending after the recovery period. The legacy
shutdown action is complete and was not a public-v1 submission gate.

The unshipped hourly monitor was archived and removed from the active checkout. Use existing
budget/resource controls and daily owner pilot review; automated edge coverage and a new alerting
account are deferred. A local-first beta may intentionally have AI unavailable, with truthful
What to Test notes. Preserve privacy/deletion work and all applicable current security checks.

Use `--purpose internal-beta-ai-disabled` for that beta's read-only operations review, alongside
the normal archive/manual/recovery arguments. Its `PASS_INTERNAL_BETA_ONLY` result requires
verified disabled, below-warning, idle budget state and all other checks; it is not permission to
enable AI or submit publicly. The default purpose remains `ai-launch`. Do disabled pre-enable
checks before an approved activation and the enabled confirmation afterward.

The local reset regression passed 840 backend tests plus locked dependency audit, Bandit, Ruff
and application mypy; XcodeGen and the full iOS suite passed 236/236 tests (226 Swift and 10 UI),
and all 44 release-script tests passed. Independent review found no actionable defect in the
purpose-specific preflight. A separate read-only verification at `2026-09-10T00:42:09Z` passed the
preserved build-7 archive's strict signing/profile, production App Attest, public/Gmail-free content
and locked app/dSYM identity checks. The initial sandbox trust failure passed with macOS trust
access; neither the archive nor its signature was changed. At that archive-only checkpoint,
live operations and App Store Connect still needed fresh evidence; the later combined review is
recorded below. No iOS bundle or API-contract change was made, so the refactor requires
no new TestFlight build. [PR #46](https://github.com/tzehon/wardrobe-stylist/pull/46) merged at
`2026-09-10T01:04:48Z` after the documentation correction, a clear current-head Codex review and
both CI checks passed. Build 7 has completed Xcode validation/upload, Apple processing and
`Family` internal distribution with saved/reload-verified AI-disabled tester notes. Owner-controlled
physical handoff/QA remained open at distribution; the 11 September checkpoint records the
completed handoff and normal-state visual check. AI activation remains separate.

## AI-disabled beta pre-upload review — 2026-09-10

The combined read-only operations review completed at `2026-09-10T11:25:45Z` with exit 0 and
`PASS_INTERNAL_BETA_ONLY`. Every required check passed except the intentionally OPEN
`styling_budget: styling-disabled` result accepted only for this purpose. AI remained disabled;
the existing ledger is intact, below warning and idle. Archive, source/configuration, live
runtime, auth/store, recovery image/scan, storage, snapshots, bounded logs and public-page checks
passed. The newest automatic snapshot was `created` at `2026-09-10T07:48:53Z` with 14-day retention,
and volume use was below warning. No ledger initialization/reset, deployment or paid model call
was performed.

Same-session signed-in manual checks passed: App Store Connect showed `1.0.0 (6)` as the highest
upload, **Complete**, with no build 7; Fly's official two-day HTTP view showed 200/404 responses
and no 5xx; the expected production provider workspace/key was present and unexpired, configured
spend was below the warning band, and no production model-cost series, usage or saturation was
observed. The automated provider-status check passed. These observations support disabled beta
readiness; they do not prove a successful production styling call, alert delivery or final billing
reconciliation. The fixed outcome is also recorded in the
[manual review register](app-attest-data-lifecycle-policy.md#manual-review-register).

Refresh the full review immediately before upload, after a backend/configuration change, or when
same-session evidence expires. The next daily owner cost review is due **2026-09-11**. At this
pre-upload checkpoint, exact upload approval, Xcode validation/upload, Apple processing, `Family`
assignment, saved/reloaded tester notes and candidate-specific physical QA remained open; the
later approved upload is recorded below. Preserve the identity-safe handoff
before replacing an installation. This beta-only pass authorizes neither upload, AI activation
nor public submission; the read-only review performed no upload or distribution.

## Build-7 distribution — 2026-09-10

The owner separately approved the exact build-7 validation/upload, `Family` Internal Testing
assignment, truthful AI-disabled notes and three-document evidence publication package. Xcode
Validate App succeeded at approximately `2026-09-10T11:32Z` for the preserved `1.0.0 (7)` archive.
The first normal-route upload stalled during App Store Connect analysis with repeated
unauthorized status polls. It was cancelled at `11:44:54Z` without confirmed asset-upload
completion or terminal success. A fresh signed-in Build Uploads check at approximately `11:45Z`
still showed build 6 **Complete** as the highest upload, with build 7 absent.

A retry of the same archive began at `2026-09-10T11:46:34Z` using **Custom → App Store Connect →
Upload** within the original same-session manual-evidence window; the Apple build-list refresh
was not a new full operations review. The reviewed settings kept automatic build
number management off, symbols on and **TestFlight Internal Only** off. The selected Apple
Distribution profile and summary retained build 7 with production App Attest. This is the normal
App Store Connect-eligible route. Content Delivery recorded success at
`2026-09-10T11:47:49.338Z`; at `11:48:11Z`, Xcode's **App upload complete** result was observed for
Wardrobe `1.0.0 (7)`. The retry's exported app, profile, code, entitlements and matching dSYM
passed independent verification. Build 7 is now used and must never be reused.

At `2026-09-10T11:50:45Z`, the signed-in Build Uploads view showed `1.0.0 (7)` **Complete** and the
version's build record showed **Ready to Submit**. Build details confirmed exactly one group,
`Family` Internal Testing, with one tester, and zero individual testers. The existing group's
**Automatic for Xcode Builds** setting delivered the build; it was preserved, not changed or
verified off, and no manual assignment was needed.

The approved AI-disabled notes were saved and reload-verified at `2026-09-10T11:51:22Z` with Save
disabled. The processed metadata check at `11:51:27Z` confirmed **Binary State: Validated**,
`1.0.0 (7)`, expected bundle/application identity, included symbols, no non-exempt encryption,
minimum iOS 18.0, arm64 iPhone support, production App Attest, debugging disabled and beta reporting
enabled. This completes the approved validation/upload, processing, internal assignment and
tester-note loop. **Ready to Submit** is Apple's build status, not public-submission authorization.

The owner-controlled identity-safe handoff, clean installation and scoped local-beta QA later
completed as recorded below. Do not repeat deletion, uninstall or upload. No backend deployment,
AI activation or paid styling call occurred; this internal-beta upload does not authorize public
App Store submission.

## Build-7 physical checkpoint — 2026-09-11 (PARTIAL)

The owner reports `1.0.0 (7)` installed through a TestFlight update over the existing installation.
The supplied Dark Mode screenshot at 11:04 SGT shows saved AI styling permission allowed and the
daily reminder off. After the owner withdrew styling permission, the 11:05 screenshot shows the
replacement **Allow AI styling** control: centered, title-only white text, no leading icon slot,
solid blue fill and visually readable normal-state presentation. The normal-state visual check
passes by screenshot inspection; no measured contrast ratio is claimed. The owner then opened
Wardrobe and History and confirmed that existing items and wear history are still present. This
passes the retained-data presence smoke check; no full data comparison was performed.
The owner subsequently confirmed that Offline Demo opens and its sample wardrobe can be browsed
with Airplane Mode on and Wi-Fi off. The brief offline Demo smoke passes; no remote styling call
was part of this test.

A subsequent scoped live read-only handoff check passed the locked runtime, auth-store integrity,
approved aggregate band, volume and automatic snapshot checks. Safe aggregates were one active
installation, zero active sessions, zero pending challenges and zero failed challenges. The newest
snapshot was `created` at `2026-09-10T07:48:53Z` with 14-day retention. The budget guard remained
OPEN `styling-disabled`, confirming AI is still disabled. This is preparation for an owner-approved
handoff, not a full operations review or deletion authorization. In-app proof of possession and
successful server deletion must precede any local-data removal or uninstall.
The owner subsequently approved that ordered deletion and clean-install test. Approval covers
the current live server record and local wardrobe/photos/history, followed by uninstall and clean
installation of processed build 7. The owner then reported **Live server security record deleted**.
Fresh read-only verification returned zero active installations, active sessions, pending challenges
and failed challenges; the auth-store integrity, runtime, volume and snapshot checks still passed,
and AI remained disabled. At `2026-09-11T03:14:30Z`, the bounded log-buffer check observed exactly
one deletion-success marker and no deletion-rejection marker since approval. This verifies the
live server-deletion stage. The owner next confirmed that **Local Data Deleted** appeared after
the approved in-app local deletion. The owner then confirmed app removal, clean TestFlight
installation, **Start with my wardrobe**, empty Wardrobe and History, AI permission off and
version `1.0.0 (7)` in Settings. A fresh scoped read-only check after first launch again returned
zero active installations, active sessions, pending challenges and failed challenges. The runtime,
auth-store, aggregate-band, volume and snapshot checks passed; AI remained disabled. Its newest
automatic snapshot was `created` at `2026-09-11T07:49:53Z` with 14-day retention. This completes
the owner-controlled handoff and clean-install first-launch checks. No separate intermediate
post-uninstall server sample was taken; the zero-state observations bracket server deletion and
the subsequent clean-install first launch. This did not prove snapshot-list expiry or deletion-
specific recovery/non-return; the owner-waived evidence exception is recorded below.

This evidence does not establish pressed/disabled presentation or complete wardrobe/history
integrity. The server-deletion stage passed while the inherited installation was still available;
local deletion and clean installation are owner-confirmed. The completed regression and retained
physical evidence close the scoped local-beta QA below; broader AI/public-release evidence remains
open. Do not repeat deletion, uninstall or upload. No AI activation or styling call was requested.
No shipped app/backend behavior changed and no new TestFlight build is required.

## Snapshot/recovery evidence waiver — 2026-09-11

The owner explicitly waived the remaining snapshot-list-expiry and deletion-specific recovery/non-
return evidence sub-gate for the Free Singapore v1. A read-only check at
`2026-09-11T08:11:59Z` confirmed that the monitored `2026-08-25T07:35:53Z` and
`2026-08-28T07:37:13Z` snapshots were no longer customer-visible. A later same-day read-only check
at `2026-09-11T08:35:05Z` confirmed that the successful automatic snapshot created at
`2026-09-10T07:48:53Z`, before the verified Build-7 server deletion at
`2026-09-11T03:14:30Z`, remained customer-visible with status `created` and 14-day retention. The
scheduled wait was stopped and its automation deleted.

This is an accepted-risk exception, not passing evidence. It does not prove the 10 September
snapshot's later customer-list disappearance, replica/backup/all-copy purge, or that a deleted
identity cannot return if an ineligible pre-deletion snapshot is restored. Fly's all-copy purge
timing remains undisclosed.
Pre-deletion snapshots remain ineligible for normal service recovery; an emergency recovery must
use fresh auth state and re-enrollment while preserving the separate budget ledger, and AI stays
disabled if accounting consistency cannot be established. No Fly resource, production or app/local
data, installed app, or TestFlight state changed for this decision. The waiver removes only this
evidence sub-gate as a Free Singapore v1 submission blocker; every other APP-009/APP-036, privacy,
AI and App Store gate retains its own status, as does the separate deferred Google-retirement work.

## QA automation ownership — 2026-09-11

The owner challenged the repeated manual catalog/photo/edit/relaunch request. That request is
withdrawn. Reuse the automated and retained physical evidence before requesting another device
step; an uncovered deterministic scenario belongs in a regression test.

| Scenario | Automated evidence and limits |
| --- | --- |
| Local add/edit/delete, Demo catalog and Photo Library presentation | `WardrobeUITests.testManualItemCanBeAddedEditedAndDeletedLocally`, `testDemoCatalogCanFilterSearchEditDeleteAndRestoreOnRelaunch`, and `testPhotoLibraryStaysPresentedUntilTheUserCancels`. The picker test covers presentation/cancellation, not camera hardware or photo selection on the owner's device. |
| Photo and edited name after reopening persistent storage | New `WardrobeStoreDiskPersistenceTests.photoAndEditedNameSurviveSeparateStoreReopens` uses a generated image and isolated temporary disk store. It checks saved identity, photo/thumbnail bytes and image decoding after separate store opens. This is a persistence integration test, not a real-app process-termination or camera-permission claim. |
| Today/History across process termination and offline failure | `WardrobeUITests.testTodayCacheRestoresWithoutNetworkAfterProcessRelaunchAndSurvivesOfflineRestyle` uses the production views with an isolated fake transport and persistent test store. |
| Consent-button appearance and behavior | `StylingConsentButtonPresentationTests` checks enabled/pressed/disabled contrast; `testSettingsHubAndStylingConsentStayExplicitAndReversible` checks rendered title centering, width, contrast and grant/withdraw behavior in Dark Mode. The owner's build-7 screenshot provides the candidate-specific normal-state device observation. |

Do not request another manual pass over these deterministic scenarios. Preserve the already
completed owner-controlled production deletion and clean installation, the build-7 visual
screenshot, and applicable earlier media/notification physical evidence. Production App Attest
and a protected styling call remain in the separately approved AI pilot. No additional routine
phone checklist is assigned. Any newly required device step needs a specific uncovered physical
risk; missing pressed/disabled device captures must not be presented as missing automated contrast
coverage. No new TestFlight build is required for this test-only addition.

Local verification completed on 11 September: the new focused persistence test passed, followed
by all 237 iOS tests (227 Swift and 10 UI), 840 backend tests plus the locked dependency audit,
Bandit, Ruff and application mypy, and all 44 release-script tests. The remaining local-beta QA
is complete using those results and the retained device evidence; no extra routine phone test
is assigned. These are local test results; the PR's CI checks provide separate verification.
AI activation/protected-call proof, public submission, wider accessibility review and outstanding
privacy evidence remain separately scoped work. The 10 September snapshot-list/deletion-recovery
evidence is unproved but owner-waived only for the Free Singapore v1.

## Distribution policy

- Upload with Xcode's **TestFlight & App Store** distribution option, then add the processed build
  only to an App Store Connect **Internal Testing** group.
- Do **not** choose **TestFlight Internal Only**. Apple marks that artifact as internal-only, so it
  cannot later be submitted to external testers or customers.
- Do not bypass the device-Release configuration guard. Internal testers must exercise the same
  production identifiers, HTTPS endpoints, privacy manifests, disclosures, and authentication
  architecture intended for App Review.
- Keep Debug/LAN credentials in `Secrets.xcconfig`. Keep non-secret distribution identifiers and
  endpoints in the gitignored `Distribution.xcconfig`. Never place a shared backend bearer or an
  Anthropic key in either public client configuration.
- Adding a build to an internal group is not an App Store submission. Promotion happens later by
  selecting the same processed build on the App Store version and submitting it for review.
- Public `1.0.0`/build 7 is a Free, no-IAP/no-subscription candidate for the Singapore App Store
  only. Do not attach, advertise, or imply a future paid entitlement on this binary. The next
  product release is transparent, budget-bounded freemium in Singapore; country expansion follows
  only after that model and its operations are proven.

## Launch readiness follow-up — 2026-09-09

The ordinary budget diagnostic's ownership-context defect is corrected. It now connects as
`wardrobe`, verifies real/effective UID/GID 10001 before importing the status reader, and disables
Python bytecode writes. The existing read-only ledger, schema, ownership and accounting guards
are unchanged. Targeted live verification at `2026-09-09T00:05:29Z` confirmed the same healthy
Fly v12 image, original Machine and configuration before and after the check. The standard budget
gate now reports OPEN `styling-disabled`, as required while AI is off. This is diagnostic evidence,
not a complete pre-upload review or AI-enablement approval. No ledger/provider mutation or paid
model call occurred, and no backend deployment is required for this operator-tool correction.

Final regression including the local cost checker passed 780 backend tests, dependency audit,
Bandit, Ruff, application mypy and strict checker mypy. XcodeGen and the full iOS suite passed
236/236 tests (226 Swift and 10 UI) at `2026-09-09T00:57:21Z`; all 44 release-script tests also
passed. Independent review found no actionable defect. The iOS bundle and runtime inputs are
unchanged; no new TestFlight build is required. Private source/log bindings retain this evidence.
The PR review's policy-binding finding is corrected: the checker recomputes a canonical digest
of all policy contents except the digest field before evaluating evidence. Edited policies with
stale digests fail closed, and evidence must reference the corrected digest. This verifies local
content consistency without implying owner approval or authenticated source data.
The peer-feed review finding is also corrected: after shared billing metadata passes, each view
is validated independently. A valid warning/hold survives an invalid or missing peer, including
wrong JSON numeric types through the CLI. Invalid-view fields are never reused; shared metadata
or malformed whole-file failures remain closed. Reconciliation stays OPEN on a rejected peer.

At this 9 September checkpoint, the [privacy proposal](privacy-policy-proposed-20260909.md)
was unpublished and provider/Apple/consent review remained open. The subsequent
[12 September publication](#privacy-publication--2026-09-12) completed those checks and published
both the reconciled policy and Apple answers, retaining build 7 and consent notice version 3.

Fresh read-only Fly inventory confirmed the existing fixed resources. The September 9 invoice
preview increased while same-period Cost Explorer was unchanged; neither view establishes a
usage cutoff or refresh guarantee. The difference remains unreconciled. The next monitor requires
separate resource, traffic and billing inputs; traffic counters cannot stand in for billed egress.
The [local evidence checker](../fly-spend-controls.md#local-evidence-checker) prepares strict
assessment of explicitly supplied records; it does not collect live data, forecast bills or
activate monitoring. The private demonstration remains OPEN for incomplete service inventory,
unreconciled totals and unknown billing coverage. The private readiness proposal preserves the
already approved thresholds. The [external runner proposal](../fly-spend-controls.md#external-runner-proposal)
uses the verified public repository's standard GitHub runners with a free external heartbeat;
the exact collector, credential scope, actual alert receipt and independent missed-run detection
still need review and proof.
No monitor, notification test, service hold or new resource has been activated.

At this historical checkpoint, the proposed automation/delivery work was still open. The
10 September reset defers that automation: before AI activation, complete truthful privacy/consent,
key and budget checks plus the simple pilot cost/response review. Retain billing discrepancies
and residual exposure explicitly. Confirm enabled operation after the approved change; the
enabled check is not a prerequisite to the disabled pre-enable review.
AI enablement and distribution remain separate approvals. Never repeat first provisioning,
the consumed credit purchase or key staging to reproduce earlier setup evidence.

## Approved disabled budget setup — 2026-09-08

The owner's "proceed" approved the finite billing-reviewed setup proposal, its separate Fly
hosting policy and private capacity review bounds. The ignored approval record binds the exact
proposal/manifest; the earlier unapproved preparation records remain unchanged historical evidence.
This approval covers the specified first provisioning, provider setup and capped credit purchase,
disabled configuration deployment and sanitized evidence lifecycle. It does not authorize paid
model calls, AI enablement, distribution, snapshot/deletion/recovery operations, monitoring
activation or an automatic service hold.

Fresh automated operational checks at `2026-09-08T08:54:09Z`, including the exact recovery image
and zero-High/Critical scan, passed apart from the expected OPEN budget gate; manual rows remained
OPEN. Source `d2866a2375dd4795f40a3ab13d273ed138cedd7e`, Fly v11, the original Machine and encrypted
volume were unchanged. First-ever ledger provisioning succeeded at `2026-09-08T08:56:32Z`, before
staging any AI environment overrides. It recorded the exact approved private policy, zero
current-month charges/admissions and no reservations. Independent read-only verification under
service UID/GID 10001 passed at `2026-09-08T09:00:32Z`, including policy/state checks and parent
0700/database 0600 permissions. The initializer was not repeated. Keep the existing ledger;
never reset or recreate it to regain a first-provisioning state.

The approved public-capacity file is installed locally as private review bounds, not runtime
customer quotas. The dedicated production workspace now exists in the
approved US geography. Its monthly limit and two email-notification settings were saved and
verified after reload. One approved credit purchase is paid at the approved quote, sufficient
usable balance was verified, and auto-reload remains off. Exact workspace/key names, identifiers,
amounts and balances remain in private evidence. Actual alert delivery remains OPEN; no native
test control was observed. The workspace-scoped key was created for the existing owner without
Admin API access; the creation confirmation was verified. Hidden owner input transferred the key,
and staged-only verification passed at `2026-09-08T09:19:59Z` without local secret persistence or
an automatic retry. Its displayed expiry is `2026-10-08T09:13Z` (17:13 SGT); rotation before that
expiry is a required operations gate.

The approved configuration deployed as **Fly v12**, retaining the exact same scanned immutable
image/source, original Machine and encrypted volume. All six private AI policy values and the
new workspace key are applied, with AI false and the original session secret preserved; all eight
expected secrets are deployed. Independent post-deployment review at `2026-09-08T09:32:49Z`
verified the configured policy, existing ledger integrity/zero current-month state, and the
disabled 503 admission guard under serving UID/GID 10001. The same image reads the existing ledger
after restart without initialization or reset. Runtime/configuration, App Attest storage, approved
public-capacity band, volume, fresh 14-day snapshots, bounded logs, archive, public backend/pages
and public provider-status checks passed.

At this checkpoint the ordinary budget checker reported OPEN `styling-budget-evidence-open`: its
root-SSH diagnostic had an ownership-context gap, corrected by the September 9 follow-up above. The independent
configured probe passed under the required service identity. Do not force that ordinary checker
green or relax ownership guards. The full pre-upload gate remained OPEN at that setup checkpoint;
the later beta-only review and completed distribution are recorded above. AI-launch checks remain separate.

Fresh pre-deployment inventory confirmed no resource growth. The approximately 09:25–09:29 UTC
signed-in billing refresh showed divergent invoice-preview and Cost Explorer totals across the
same five expected products. Private planning uses the higher preview, without attributing the
difference to lag or claiming a proved forecast. Billing-feed freshness/reconciliation, final
adjustments, provider alert delivery and Fly monitoring implementation/delivery were OPEN at that
checkpoint. The 10 September plan supersedes the automation/delivery requirement with daily owner
review; it does not convert missing billing or delivery evidence into a pass.
Post-deployment resource inventory again passed with no additional billable resources. The
provider console recheck confirmed the saved cap/notification settings, usable credit and disabled
auto-reload; the Fly invoice preview was unchanged. These checks do not reconcile the divergent feeds.
No monitor or service hold was activated; the hold still requires its own execution approval.

The finite disabled setup and independent post-review are complete. This is not migration
acceptance or a full pre-upload pass.
No paid call, AI enablement or
TestFlight distribution occurred; the preserved Build 7 archive is unchanged and no new build is
required. The chronological checkpoints below retain their original scope and outcomes.

## Disabled runtime rollout — 2026-09-07

Historical checkpoint; the approved first provisioning above supersedes its unprovisioned state.

The owner approved private image publication and deployment with AI disabled after PR #42 merged.
Fly v11 ran source `d2866a2375dd4795f40a3ab13d273ed138cedd7e`; the original Machine and durable
volume were healthy at `2026-09-07T10:36:34Z`. The disabled-only review completed at
`2026-09-07T10:39:08Z`. The release, serving image, and privately retained immutable registry
reference matched the expected source and Linux/AMD64 architecture; fresh registry security scans
reported zero High/Critical findings. Production App Attest configuration, auth-store integrity,
non-root/no-new-privileges execution, bounded logging, snapshot policy, and public pages passed.

At that checkpoint the serving process had AI styling disabled, with no AI environment overrides
or `.env` file. The approved private launch policy was unapplied: the default budget path was blank,
monthly spend/admission limits were zero, and no budget directory or database was created. No paid
call ran. The checker retained `styling_budget = OPEN` with `styling-budget-evidence-open`; its
manual-input rows remained OPEN. This completed the disabled-deployment review, not the broader
pre-upload review.

The fresh official Fly two-day HTTP view showed successful and not-found responses, no 5xx series,
and no concurrent requests. The Claude key was active, spend was below the 80% warning band, and
the last-day view showed no rate saturation. Prepaid credit was low and no configured email-spend
notification rows were visible, so credit readiness and alert delivery were then open. Earlier
uncertain-call liability was unresolved. Provisioning, independent public-capacity approval,
AI enablement, the full fresh operational review, and distribution were then open.

The exact v11 immutable reference was retained privately for budget-aware redeployment. This
cutover excluded pre-budget v10 as a normal rollback target because it ignores the disabled switch
and budget controls. Compatibility with an initialized ledger was unproven at that checkpoint.
The September 8 setup above now records the existing ledger, applied limits and successful restart
on the same image; preserve and reverify them for any later recovery. The historical v10
archive/review evidence and preserved Build 7 archive are unchanged; no new TestFlight build is required.

## Budget and provider preparation — 2026-09-07

Historical preparation; the later approved setup checkpoint above records execution progress.

The retained release chronology contains no deployment between Opus v10 and the first Sonnet
runtime, v11. The prior source hardcodes Opus; the Sonnet deployment was handled with AI disabled,
and no production ledger was provisioned. Independent review found no contradictory in-scope
activity. Together with the original sole Machine/volume binding, this supports first-ever
storage and zero prior liability for the approved selected-model production envelope. The fresh
read-only check at `2026-09-07T11:51:58Z` passed exact healthy runtime/configuration, the serving
process's disabled defaults and absence of the whole budget directory. Recheck immediately before
any separately approved creation; these observations never authorize initialization themselves.

The approved policy explicitly excludes fictional evaluations and earlier Opus production. The
evaluation timeout remains unresolved as separate account-level exposure. Current-month provider
cost rows for the existing production key show billed activity only on the recorded evaluation
day, with model totals consistent with those runs and no billed activity displayed today. Rounded
costs are corroboration, not exact settlement or proof of provider completion. No nonzero opening
balance import is currently indicated; any contradictory in-scope charge or pending work requires
reconciliation before using the zero-only initializer.

A private proposal now specifies first provisioning with the existing approved limits, a dedicated
production workspace/key with a matching provider cap and spend notifications, a bounded one-time
credit purchase with auto-reload off, independent installation/session review thresholds, and a
same-image configuration update that keeps AI disabled. These new actions are unapproved. Console
forms were inspected and cancelled; no workspace, key, notification, purchase or production setting
was changed. The provider's workspace form currently offers immutable US workspace storage; it
does not establish Singapore residency or change the evaluated global inference pricing.

The README and operational guidance are updated locally. Public publication/review, provisioning,
provider changes, credit readiness, capacity activation, alert delivery and separate AI enablement
remain open. Configuration persistence does not prove email delivery. No runtime or iOS source
changed, no model call ran, and no new TestFlight build is required.

## Fly cost-protection preparation — 2026-09-08

Historical preparation; the later approved setup checkpoint above records the owner's acceptance
and first provisioning. Monitoring and service-hold execution remain separate open steps.

The owner requested hosting-cost protection in the pending setup plan. The revised private
8 September proposal supersedes the unapproved 7 September proposal while preserving its original
bytes and manifest. The previously approved AI limits are unchanged; Fly has its own proposed
operating target, warning/hold thresholds and early traffic triggers. No new financial or
production action was authorized by the request to revise the plan.

Read-only CLI inventory at `2026-09-07T23:30:46Z` found one started `sin` shared-CPU/512 MB Machine,
one 1 GB volume with 14-day snapshot retention, and shared IPv4/IPv6. The same organization's app
list contains only this app and no builder app. The signed-in billing review on 8 September,
started at `2026-09-07T23:44Z`, reconciled the current September invoice preview with Cost Explorer
across the five expected categories: CPU, additional RAM, volume storage, snapshots and egress.
The reviewed organization has no linked organizations, active support package, Managed Postgres
clusters or Upstash Redis databases. Exact amounts and provider identifiers remain private.
This current snapshot does not prove the absence of every possible add-on or final adjustment.
The billing feed supplies no coverage cutoff or refresh lag; those checks and verified monitoring
remain open, and final taxes/adjustments are not guaranteed. The baseline estimate is a planning
scenario that assumes continuous compute; the current minimum-one/autostart configuration does
not provide savings from idle shutdown. It is not a guaranteed month-end provider projection.

The [hosting control plan](../fly-spend-controls.md) freezes billable resource growth, requires
organization-wide cost/forecast and resource checks, and prepares a reversible hold that disables
autostart/minimum-one/restart behavior before verifying stopped state. It preserves volumes,
snapshots and uncertain provider liabilities. Native billing alerts and an enforceable total
monetary cap are not established; proposed monitoring/response is not a guaranteed bill ceiling.
Monitoring implementation, feed/delivery verification, acceptance of residual cost exposure and
any hold execution were separate open gates in this September 8 proposal. The 10 September plan
defers automated monitoring and retains current billing observations, explicit residual exposure
and the reviewed manual response. No monitor, shutdown, deployment or purchase ran at this checkpoint.
This is documentation-only preparation; the preserved Build 7 archive is unchanged.

## Local launch preparation — 2026-09-06

This section retains the implementation and evaluation checkpoints that preceded the disabled
v11 deployment above; statements about actions not yet taken describe those historical checkpoints.

The local backend candidate prepares pinned Sonnet 5, SDK 1.4.0, synchronous strict tool output,
no thinking/cache/retries, and a 1,024-token output cap, plus a separate durable global monthly
spend/admission ledger and default-disabled styling switch. The shared wire schemas and iOS
source are unchanged, so this work does not require Build 8 or replace the preserved Build 7
archive. Keep README current with these changes.

The [fictional model evaluation](../model-evaluation.md) and local implementation are accepted;
[PR #41](https://github.com/tzehon/wardrobe-stylist/pull/41) records source publication, required
checks, Codex review, and merge state. AI enablement and distribution were open at those preparation
checkpoints; the completed AI-disabled internal distribution is recorded above.
The following retains the evaluation history.
The first owner-approved Haiku run, with at most 28 paid calls and a $6 pre-tax ceiling,
stopped on 2026-09-06 on its first request after 30.046 seconds with `APITimeoutError`.
No response or usage returned; uncertain cost is bounded by $0.205120 before tax. A separately
approved single-call diagnostic with a 90-second read timeout succeeded in 5.86 seconds,
passed that office case's automated checks, and cost $0.004222 before tax. No automatic retry
ran. The full evaluation thresholds remain unchanged and further paid work needs fresh approval.
Full quality/cost/cache acceptance and human scores remain absent; the timeout's cause remains
unconfirmed. A separately approved fresh full run on `aa314ca` completed all 28 calls for
$0.136602 before tax but failed the automatic floor: completeness 23/24 and distinct item
sets 22/24; schema and known IDs passed 24/24, with p95 latency 15.872 seconds. Cache
reads/writes were zero, so caching stays off. The two duplicate-look failures and one missing
top/dress are genuine; no human scores or model acceptance follow from this run. General
prompt clarification and full local regressions completed. Its newly approved full 28-call run
on `43f3e0e` cost $0.133243 before tax but also failed: distinct looks and required alternates
each passed 23/24, while completeness reached 24/24 and p95 was 12.369 seconds. Caching again
had zero reads/writes. Sonnet 5 evaluation support is prepared and tested with the same prompt and
fixed quality floor. The owner approved one 28-call run within an additional $58 pre-tax ceiling
on 2026-09-06. It completed for $0.333305 before tax, with no provider errors or retries, but
failed required alternates 23/24; schema, known IDs, completeness, distinctness, and occasion
checks passed 24/24, and p95 latency was 13.266 seconds. The second all-black response omitted
the valid option of removing an optional tote. A general prompt clarification is implemented
and fully tested with the fixed floor intact. The warm cache pair saved about 20% of input cost,
but production reuse remains unproven and caching stays off. On 2026-09-06 the owner approved
one revised 28-call Sonnet run from `10e837b` under manifest
`ae2479794e5aa40dc79ed4c555c9f89c9b8bfb4d451bce29120563357931fa06`, within an additional
$58 pre-tax ceiling. The revised run completed all 28 calls without provider errors or retries
for $0.360167 before tax. It passed the unchanged automatic floor: all six hard checks passed
24/24, avoidance passed 4/4, preference passed 3/4, and p95 latency was 12.665 seconds.
The 24 quality calls cost $0.308128, or $0.012839 per mechanically usable recommendation;
human acceptance had not yet been established at that point. The cache pair wrote and read 1,798 tokens each,
with input cost $0.008871 versus $0.011208 uncached (about 20.85% savings). Production reuse
remains unproven, so production caching stays off. After supplying one completed numeric
scorecard, the owner said "all are ok, proceed" and accepted all proposals qualitatively.
The partial scorecard remains unchanged, and the numeric rubric is not claimed to have passed.
See [evaluation and owner acceptance](../model-evaluation.md). The local model, runtime, and
preflight now select Sonnet; the v2 budget binds its prices/context and reserves $2.010240 at
the default 1,024-output limit. Old or mismatched ledgers fail closed without upgrade or reset.
The 28 request hashes match the accepted run; full migration regression passed.
The owner expects up to 10 initial AI users and approved the private spend/admission limits
and owner-operated daily monitoring policy on 2026-09-06. Exact limits and disabled configuration
were retained in ignored private release records and had not yet been applied. Both failed Haiku runs and the failed Sonnet run
remain failed and retain unfilled human scores.
At that preparation checkpoint the remaining gates included public-capacity preflight, alert
delivery and credit readiness, approved [spend-controls provisioning](../ai-spend-controls.md),
AI enablement and the full operational review.
The [public-capacity preflight profile](../ai-spend-controls.md#public-launch-observed-capacity-preflight)
was prepared locally with independent private installation/session bounds and ownership checks;
those bounds were not yet approved. The later v11 disabled rollout still had an unprovisioned
budget and OPEN preflight. The [8 September setup](#approved-disabled-budget-setup--2026-09-08)
supersedes those provisioning, credit and capacity-decision states; it records the historical disabled v12
configuration; the 12 September v14 compatibility checkpoint records historical pilot state.
The [29 September rotation record](key-rotation-20260929.md) records current v16 state and evidence limitations. Snapshot expiry/deletion-specific recovery is separate.
Use the verified budget-aware recovery reference recorded above; pre-budget v10 is not a normal
rollback target after the disabled cutover.

Sonnet migration verification passed 505 backend tests plus locked audit/Bandit/Ruff/mypy, 226 Swift unit
tests plus all 10 UI tests, 44 release-script tests, and a new Release simulator build/artifact
check. The unchanged preserved Build 7 archive's earlier signature/profile/privacy verification
remains recorded. No public source push, production change,
upload, or phone/snapshot mutation occurred. Local signed-artifact validity is separate from
the fresh operational/upload gates.

After the owner approved the private budget/daily-monitoring policy, the local capacity-preflight
extension passed independent review and the complete regression: 551 backend tests, locked
dependency audit with no known vulnerabilities, Bandit, Ruff, mypy, 236 iOS tests (226 Swift plus
10 UI, no failures/skips), 44 release-script tests, and fresh Release simulator/artifact checks.
The result bundle is `ios/DerivedData/CapacityPreflightRegression-20260906.xcresult`; logs use
`/private/tmp/wardrobe-capacity-*`. The Release simulator artifact is `1.0.0 (7)` with minimum
iOS 18.0; the preserved distribution archive and production lock are unchanged. The approved
disabled configuration passed local settings validation; no ledger or paid call was created.
The private capacity bounds remain a separate open decision. Publication/review, provisioning,
deployment, and upload still require their respective gates and approvals.

The owner subsequently approved source publication and the complete review/merge cycle.
[PR #41](https://github.com/tzehon/wardrobe-stylist/pull/41) was created as a draft and immediately
marked ready. The PR records the checks, Codex review of its current commit, and merge state.
Passing checks and current-head approval are prerequisites for rebase-merge; this publication
checkpoint does not authorize production provisioning, capacity-policy activation, or distribution.

PR #41 review required two additional guards: runtime/preflight output must remain the evaluated
integer 1,024, and numeric scoring must match the complete current source/model manifest and hash.
Both fixes passed independent review, 583 backend tests plus locked audit/Bandit/Ruff/mypy,
236 iOS tests (226 Swift + 10 UI, zero failures/skips), 44 release-script tests, and fresh
Release simulator/artifact checks. The result bundle is
`ios/DerivedData/ReviewFixRegression-20260906.xcresult`; logs use
`/private/tmp/wardrobe-review-fix-*`. All 28 accepted request hashes remain unchanged. No paid
call or production change occurred; the v2 ledger and preserved Build 7 archive are unchanged.
The PR remains the record of the fixes' required Codex review and merge outcome.

## Runtime security follow-up — 2026-09-06

PR #41 received current-head Codex approval with no findings and green checks, then rebase-merged
at `2026-09-06T10:31:28Z` to `e3a837bf4d5c3c3afbee1431b4b69b36b213c431`.
The merged tree matched reviewed head `0c2f80c`; its code matched the full-regression head
`9edb9c3`. The remote/local feature branches were removed after tree-equivalence and worktree
checks, and main was synchronized cleanly.

The merged Linux/AMD64 image built successfully, but its fresh Docker Scout scan found four
High-severity findings in `util-linux 2.42.1-r0` (CVE-2026-76642, CVE-2026-78408,
CVE-2026-78410, CVE-2026-78409). The affected installed subpackage was `libuuid`; no image was
published or deployed. Local fix `970089d` requires `libuuid>=2.42.3-r1` in the final runtime
stage, preserving both digest-pinned bases and the existing crypto-library refresh. The rebuilt
image contains `libuuid 2.42.3-r1` and passes a fresh zero-High/Critical Scout scan, native UUID
loading, UID/GID 10001, no-new-privileges, SQLite, bounded logging, separate auth/budget storage,
and uncertain-reservation persistence across restart. Every smoke container had no network or
provider key; only the newly created synthetic Docker volume was removed after success.
Private image evidence is retained under `.fly/sonnet-image-validation-20260906T104140Z-2iAXp1/`.
The owner approved publication and the complete review/merge cycle on 7 September 2026 SGT.
[PR #42](https://github.com/tzehon/wardrobe-stylist/pull/42) was created as a draft and immediately
marked ready; it records the required checks, Codex review, and merge state. Production rollout
requires separate approval and a verified image of the merged source. This source approval
does not authorize registry publication, paid calls, provider changes, production provisioning,
deployment, AI enablement, or distribution. The fix changes no iOS/shared source, version,
signed archive, or live release lock.

The remediation passed 12 focused container tests, all 583 backend tests, locked dependency
audit with no known vulnerabilities, Bandit, Ruff, and mypy. Full iOS regression passed 236/236
unique tests (226 Swift across 34 suites plus 10 UI), with zero failures, skips, or expected
failures on iPhone 17 / iOS 26.5. All 44 release-script tests and a fresh `1.0.0 (7)` Release
simulator/artifact check passed. The result bundle is
`ios/DerivedData/RuntimeSecurityRegression-20260906.xcresult`; the Release build uses
`ios/DerivedData/RuntimeSecurityRelease-20260906`, and logs use
`/private/tmp/wardrobe-runtime-security-*`. These checks require no new TestFlight build and
do not replace source review or live deployment/recovery evidence.

A read-only production preflight at `2026-09-06T10:36:26Z` passed the retained archive, live
runtime/health/configuration, auth integrity and historical single-user bands, volume/snapshot
policy, bounded events, public backend/pages, and public Anthropic status. Source alignment,
budget evidence, recovery scan, and the three manual inputs remained OPEN. This was not a
completed operational review, public-capacity acceptance, zero-liability proof, or deployment
approval. Production provisioning, registry publication/deployment, AI enablement and Build 7
upload were separate pending gates at that checkpoint; no paid call, production change or phone/snapshot action occurred.

## Retained release evidence — 2026-09-01

- Version metadata baseline: PR #12 commit `b000fdfb19ae496a42c6c38565d961a929801c17`
  contains `1.0.0 (4)`. Final Gmail-free product/backend source merged through PR #14 as
  `9a48caebdec67ac26673c3ba51546a5e7edcf0cc`; local and remote `main` were synchronized before
  the release image was built. The archive source is later `dd3d99061321cf91bdce166e7da579b84edb07e8`,
  which adds the signed-profile verifier fix without changing that shipped app bundle. PR #19 then
  rebase-merged the reviewed Swift/backend/contract/verifier fixes as
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`. Documentation-only PR #20 then produced clean
  synchronized archive context `24c17cb9fe643035f9206ee61e2935e086902146`; `ios/`, `backend/`,
  and `shared/` are unchanged from the reviewed code merge. The reviewed backend is deployed and
  the historical build-4 replacement regression/archive are verified.
- Historical uploaded version/build: `1.0.0 (4)`. App Store Connect showed builds 1-3 only at
  `2026-08-21T06:34:50Z` before the replacement archive and again at `2026-08-21T08:12:46Z`
  immediately before validation/upload. Build 4 then uploaded, processed, and entered internal
  testing, so it is consumed and must never be reused. The historical `dd3d990` signed archive
  remains superseded and was not validated or uploaded.
- Historical build-5 distribution and completed build-6 distribution: the archive-time App Store Connect refresh at
  `2026-08-22T01:09:39Z` and final pre-validation refresh at `2026-08-22T03:16:16Z` showed builds
  1–4 only and build 5 absent. That archive used `MARKETING_VERSION = 1.0.0` and
  `CURRENT_PROJECT_VERSION = 5`. The exact production-signed build-5 archive is strictly verified,
  Organizer-validated, uploaded, processed, and assigned only to the `Family` Internal Testing
  group. Build 5 is consumed and must never be reused. Build-4 identity-safe recovery/handoff and
  broad clean build-5 physical QA later completed, but tapping a delivered reminder crashed build 5;
  it is non-promotable and a replacement iOS build was required. A read-only signed-in TestFlight
  **Build Uploads** inspection at `2026-08-22T10:02:31Z` (`18:02:31 SGT`) showed builds 1–5 only,
  build 5 **Complete**, and no build 6, confirming build 6 unused before replacement work.
  Reviewed PR #27 then merged the notification fix and build-6 metadata/allowlist to clean
  synchronized `main` `de7c540275fb16e61aabf1884538b18cf6edf76f`. Fly v9, the strict build-6
  archive, Xcode validation/upload through the normal App-Store-eligible route, Apple processing,
  `Family` assignment, and truthful tester-note save all passed. Build 6 is consumed and must never
  be reused. A later 2026-08-28 Dark Mode screenshot confirmed its styling-consent control
  presentation failure, so build 6 is non-promotable. PR #31 has since merged and verified the
  replacement control implementation. At the earlier build-selection checkpoint on 2026-08-29, the
  signed-in TestFlight **Build Uploads** view showed build 6 as the highest upload and **Complete**,
  with build 7 absent. Build `1.0.0 (7)` is
  selected while `MARKETING_VERSION` remains `1.0.0`; source configuration is prepared with
  `CURRENT_PROJECT_VERSION = 7` and accepted builds `4,5,6,7`. PR #34 rebase-merged the runtime
  remediation to clean main `162688ae72d07f06a7a8116249632aa0101e538f`; its exact Linux/AMD64
  image passed local and immutable-registry zero-High/Critical scans plus the runtime smoke gates,
  then deployed as completed Fly v10 at `2026-08-29T01:52:47Z`. The required post-change operational
  review passed at `2026-08-29T02:21:41Z`. The `04:21:50Z` review was too old to gate the archive
  created at `07:15:57Z`, so that technically verified Apple Distribution archive is preserved as
  timing-stale/non-uploadable; the earlier automatic-signing archive is development-signed and also
  invalid/non-uploadable. A fresh full review against exact Fly v10, including a fresh private-
  registry match and zero-High/Critical Docker Scout scan, completed at `2026-08-29T11:02:18Z`.
  Clean main `0cc0fa7` then produced the distinct Apple Distribution-signed `1.0.0 (7)` archive at
  `11:03:10Z`; strict verification passed at `11:04:02Z`, and the signed-in `11:05:38Z` post-archive
  Build Uploads refresh showed build 6 highest and **Ready to Submit**, with build 7 absent.
  Validation/upload, Apple processing, assignment, tester notes and physical retest were open at
  that archive-era checkpoint. The 10 September distribution record above closes the delivery
  pipeline; the 11 September checkpoint closes handoff and scoped local-beta QA. Keep the root
  `README.md` current with implementation and release status; this
  runbook and the release backlog retain the detailed ordered evidence.
- Notification-fix merged evidence: focused tests passed 17/17. Merged-source verification retained
  221 backend tests plus locked dependency audit/Bandit/Ruff/mypy, 231/231 iOS tests (222 Swift unit
  plus 9 UI), and all 43 release-script tests. Clean build-6 physical QA then closed the affected
  delivered-reminder-tap proof: the notification opened Today without a crash or local-state loss.
- APP-014/APP-023 automation evidence from 2026-08-29: 222 backend tests plus locked dependency
  audit/Bandit/Ruff/mypy, 236/236 iOS tests (226 Swift unit plus 10 UI), all 44 release-script tests,
  and a clean Release simulator/artifact check passed. The new deterministic process-relaunch
  harness and transport are DEBUG-only, and the Release-artifact guard proves their launch markers
  are absent. This test-only change does not alter Release code paths or the preserved build-7
  archive and does not require build 8.
- Historical pre-migration production backend baseline: Fly release v10 completed at
  `2026-08-29T01:52:47Z` and
  serves exact merged build-7 backend source `162688ae72d07f06a7a8116249632aa0101e538f` as
  `linux/amd64`. Release and running image references match privately; local and immutable-registry
  Docker Scout scans report zero High/Critical findings; and locked `pip-audit` passed. One healthy
  Singapore Machine runs with `min_machines_running = 1`; production App Attest uses category `2`
  and accepted builds `4,5,6,7`; and the encrypted auth store and bounded logging configuration
  remain healthy. `/health` returns `200`, `/extract` returns `404`, unauthenticated `/recommend`
  returns `401`, and the OpenAPI route set matches the reviewed source. Build 5 completed its
  identity-safe handoff, and build 6 then passed clean physical QA.
  A later automatic snapshot created at `2026-08-25T07:35:53Z` reported `created` with 14-day
  retention and was eligible for the final build-6 handoff. The pre-deletion aggregate was one
  installation, zero sessions, and zero challenges. Assertion-verified deletion emitted
  exactly one bounded deletion-success marker and returned the aggregate to `0/0/0`; it remained
  `0/0/0` after local deletion and uninstall. A clean reinstall, launch, two local wardrobe adds,
  and styling-consent grant also left the backend at `0/0/0`. Only the explicit **Style a look**
  action at `2026-08-28 17:17 SGT` enrolled the new anonymous identity: one active installation,
  one active session, zero pending and zero failed challenges, one completed challenge, and exactly
  one bounded registration-success marker. Signed runtime category/build fields remained absent as
  expected on iOS 26.6.
- The required v9 post-deploy/pre-upload payload-free review was missed and cannot be backdated. A
  late full review completed at `2026-08-23T02:13:12Z`: exact release/runtime/source, public health,
  automatic 14-day snapshot policy and freshness, below-warning volume use, a current Fly HTTP view
  without a 5xx series, zero bounded failure classes, Anthropic public status/configured-limit/
  below-80%-spend/production-Opus-4.8/no-saturation checks, and support/contact/response-target
  checks passed. A separate older Wardrobe-labelled key had no seven-day activity; its earlier-
  month Haiku cost was reviewed as historical non-production usage. No raw metric, provider
  identifier, exact billing amount, key name/value, log sample, screenshot, or provider body is
  retained. Repeat the review before any future archive/upload and after every backend/configuration
  change.
- Former v9, v8, v7, and Gmail-free v6 images remain historical operational recovery evidence. None
  is the exact current build-7 backend candidate: using one reopens deployment/configuration/manual-
  review gates. Before the Sonnet cutover, restoring and reverifying exact v10 was required.
  At the `2026-08-29T03:31:57Z` recovery-baseline checkpoint, fresh private-
  registry authentication re-resolved the exact v10 immutable recovery reference with the expected
  source identity and Linux/AMD64 architecture, and its zero-High/Critical scan passed. The former
  v6 reference's current platform/source identity was not independently proven, so it is ineligible
  for rollback or recovery. Exact v10 was the sole recovery reference at that historical checkpoint;
  the current budget-aware recovery rule is recorded in the approved disabled setup section above.
  The emergency pre-build-4 image that re-exposes `/extract` remains a release halt, never a
  public-v1 rollback.
- The historical payload-free v8 post-change review passed at `2026-08-21T11:09:20Z`. The two-day HTTP view
  showed only `401`/`404` and no 5xx series; the bounded ten-minute view had no auth-rejection/rate-
  limit, Anthropic/stylist, maintenance, unhandled, malformed-lifecycle, or access-log event.
  Anthropic status, configured-limit, below-80%-of-limit, expected deployed Wardrobe key/Opus 4.8,
  and no-saturation checks passed, as did the published support pages, contact/response target, and
  retained routing rehearsal. The live logging configuration is deployed, but the bounded query had
  zero `registration_succeeded`, `assertion_succeeded`, and `installation_deleted` events because
  no corresponding lifecycle operation was exercised after v8 deployment at that review point.
  Later physical QA safely observed predecessor deletion and one clean-build registration plus one
  cold assertion success without payloads or identifiers. Protected `/recommend` success
  intentionally emits no developer event; it was proven separately through the aggregate
  `recommend-installation` admission counter and a visible non-cached client result.
- Pre-APP-036 development proof: App Attest enrollment, assertion renewal, and `/recommend`
  succeeded on an iPhone 16 Pro running iOS 26.6 with build 4. The iOS 27+ runtime category/build
  fields were absent as expected. Clean builds 5 and 6 repeated production enrollment, cold
  assertion renewal, and protected styling, with the same expected runtime-field absence. Build 5's
  later notification crash prevents it from being final-candidate evidence; build 6 passed that
  route and has since completed its final deletion/reinstall/new-enrollment handoff. The monitored
  25/28 August snapshots were later observed absent from the customer-visible list. The 10 September
  Build-7 pre-deletion snapshot's later disappearance and deletion-specific recovery/non-return were
  not proven and were owner-waived only for the Free Singapore v1.
- Superseded Gmail-free repository proof: 202 locked backend tests and all dependency/security/type
  gates passed; 209 unique iOS tests passed (200 Swift tests plus all 9 UI flows); 31/31 release-
  script tests passed; and a clean Release simulator artifact for `1.0.0 (4)` passed public-config,
  plist, dependency, and removed-capability verification. No Google/Gmail/OAuth, `/extract`, or
  receipt-background capability was found in shipped source/configuration, generated project,
  executable, or app bundle. Clean source `dd3d99061321cf91bdce166e7da579b84edb07e8` then produced
  the signed `1.0.0 (4)` App Store archive. Its strict verifier passed the production App Attest
  entitlement, matching distribution profile, public configuration, app privacy manifest, and
  removed-capability checks. Preserve these facts as history only: the shipped Swift/backend and
  merged contract/verifier changes invalidate the old regression and archive as current
  candidate evidence.
- Historical uploaded build-4 proof: clean synchronized source context
  `24c17cb9fe643035f9206ee61e2935e086902146` passed 219 backend tests, 215 Swift tests, all 9 UI
  flows, 43 release-script tests, the locked dependency/security/type gates, and clean Release
  simulator/public-config/privacy/removed-capability verification. Xcode 26.6 with the iOS 26.5
  SDK created the arm64 Apple Distribution archive for `1.0.0 (4)` at
  `2026-08-21T06:36:33Z`. Its strict verifier passed the matching App Store profile/certificate,
  scalar production App Attest, HTTPS public configuration, app privacy manifest, and Gmail-free
  artifact guards. A separate targeted scan found no Anthropic/API-key, shared-bearer, or private-
  key credential marker; separate `dwarfdump --uuid` output matched the arm64 app and dSYM at
  `5BA1F06E-7458-32A4-890F-36C8F22D9C13`. The retained uploaded archive is
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`.
- Final distribution proof: the required payload-free exact-v7 review and final unused-build refresh
  passed at `2026-08-21T08:12:46Z`. The strict verifier passed again before Xcode validation.
  Organizer recorded the archive prepared/validated at 08:16Z and uploaded through the normal App
  Store Connect route at 08:18Z. Apple processing completed by `2026-08-21T08:20:20Z`. Processed
  metadata shows `1.0.0 (4)`, bundle `com.tth.Wardrobe`, arm64, iPhone, minimum iOS 18.0, included
  symbols, no non-exempt encryption, `get-task-allow = false`, and production App Attest. The build
  is assigned to the `Family` Internal Testing group with the saved truthful What to Test wording
  reproduced below. Direct
  Organizer upload produced no standalone exported IPA; retained binary evidence is the exact
  archive above, executable SHA-256
  `81ab249bbab122f549809bc094bdf8bbc450e84db34888b19a3272fe02cd22c6`, and matching app/dSYM UUID.
- Build-5 Apple distribution proof: the exact-v8 pre-validation review ran from
  `2026-08-22T02:27:21Z` through `2026-08-22T02:37:08Z` and passed. The final App Store Connect
  refresh at `2026-08-22T03:16:16Z` still showed builds 1–4 only and build 5 absent. Xcode validated
  the exact build-5 archive at `2026-08-22T03:18:30Z` and uploaded it through the normal App Store
  Connect route at `2026-08-22T03:20:59Z`, with zero warnings, errors, or information messages at
  both stages. Symbols were included; **Manage version and build number** and **TestFlight Internal
  Testing Only** were off. Processing reached **Ready to Submit** by
  `2026-08-22T03:24:21Z`. The processed record shows `1.0.0 (5)`, bundle `com.tth.Wardrobe`, SDK
  `23F81a`, arm64 iPhone support, minimum iOS 18.0, included symbols, no non-exempt encryption,
  `get-task-allow = false`, beta reporting active, and production App Attest. It lists exactly the
  `Family` Internal Testing group with one tester and no individual testers; the saved truthful
  build-5 What to Test wording is reproduced below. The separate exact-v8 post-distribution review
  ran from `2026-08-22T03:19:20Z` through `2026-08-22T03:30:33Z` and passed. This closes Apple
  distribution only, not physical, lifecycle-marker, deletion, or snapshot-recovery proof.
- Build-5 physical/crash proof: build 5 appeared installed in place before the planned handoff, but
  retained the predecessor identity's proof of possession. After the successful post-enrollment
  automatic snapshot at `2026-08-22T07:33:23Z` was confirmed with 14-day retention, the inherited
  identity successfully deleted server security data and production aggregates returned to zero.
  Local data was deleted, the app was removed, and build 5 was then installed cleanly. Clean QA
  passed Gmail-free launch/onboarding, empty wardrobe, offline Demo/local flows, Camera and Photo
  Library saves, the catalog matrix, production enrollment/cold renewal, styling/Restyle, Today
  offline-cache preservation, and Wear/History. Tapping a delivered reminder at
  `2026-08-22 17:15:14 SGT` then caused an ordinary `EXC_CRASH`/`SIGABRT`, not jetsam or watchdog.
  The executable exactly matches the retained build-5 dSYM. Safe symbolication reaches the
  generated async Objective-C bridge for
  `DailyReminderNotificationRouter.userNotificationCenter(_:didReceive:)`, which resumed UIKit's
  completion path on a cooperative queue while state restoration was updating. Build 5 is
  non-promotable; do not repeat the reminder tap. Its identity-safe handoff later completed as
  recorded below.
- Build-5 handoff, clean build-6 physical proof, and final build-6 handoff: build 6 appeared
  installed in place before the
  planned handoff, but inherited proof of possession remained available. After the successful
  post-enrollment automatic snapshot at `2026-08-23T07:34:23Z` was confirmed with 14-day retention,
  server security data was deleted, the aggregate returned to `0/0/0`, local data and the app were
  deleted, and build 6 was installed cleanly. On 2026-08-24, clean build 6 passed Gmail-free first
  launch, offline Demo, Camera/Photo Library saves, catalog operations, production registration and
  cold assertion renewal, online styling, explicit cached-look restoration after offline relaunch,
  failed-Restyle preservation, offline Wear/History, and delivered-reminder tap without a crash or
  state loss. Its reminder and styling permission were then turned off. The successful automatic
  snapshot at `2026-08-25T07:35:53Z`, status `created`, retention 14 days, cleared the final handoff
  gate. The owner completed ordered server deletion, aggregate-zero confirmation, local deletion,
  uninstall, and clean reinstall. Launch, local additions, and consent did not create server state;
  the explicit Style action at `2026-08-28 17:17 SGT` created the new anonymous installation and
  session with the expected completed-challenge and registration-success evidence recorded above.
- APP-009's lifecycle/logging policy is approved in
  [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md). The current enabled
  Fly v16 bounded pilot retains its verified repository-owned enforcement; v10 is historical evidence.
  On 2026-08-19 the owner accepted Fly's fixed seven-day
  customer-visible logs, undisclosed provider-internal in-service retention, and 14-day
  snapshot-listing boundary with undisclosed all-copy purge timing. An isolated, secret-free,
  read-only restore of the 2026-08-19 snapshot passed aggregate-only schema/integrity checks and
  its temporary resources were removed within 391 seconds of volume creation. Build 4 subsequently
  supplied partial production TestFlight enrollment, assertion-renewal, and protected-call evidence,
  then its inherited identity was safely deleted before a clean build-5 install. Build 5 repeated
  enrollment, assertion renewal, protected styling, server markers, media flows, and the Today
  regression before its reminder-tap crash. Build 5's handoff and clean build-6 replacement proof
  through the fixed reminder tap later passed, and build 6 subsequently completed its final ordered
  deletion/reinstall/new-enrollment handoff. The monitored 25/28 August snapshots were later
  observed absent from the customer-visible list. The 10 September Build-7 pre-deletion snapshot's
  later disappearance and deletion-specific recovery/non-return were not proven and were owner-
  waived only for the Free Singapore v1.
  Apple upload/processing and internal assignment alone do not satisfy those lifecycle
  checks. The first payload-free
  manual operations review passed at `2026-08-20T00:15:07Z`; the required post-v6 review passed at
  `2026-08-21T01:11:43Z`; and the historical pre-archive repeat passed at
  `2026-08-21T03:30:33Z`. The reviewed v7 post-deploy review passed at
  `2026-08-21T06:00:21Z`; the required final pre-upload repeat passed against that exact deployment
  at `2026-08-21T08:12:46Z`. The v8 post-change review passed at
  `2026-08-21T11:09:20Z`; the build-5 pre-validation and post-distribution reviews passed at
  `2026-08-22T02:37:08Z` and `2026-08-22T03:30:33Z`. The late v9 review passed at
  `2026-08-23T02:13:12Z`; the historical v10 post-change review passed at
  `2026-08-29T02:21:41Z`, and the fresh build-7 pre-archive repeat passed at
  `2026-08-29T11:02:18Z`. That historical review recorded a 2026-09-28 outer deadline. The current v16 bounded pilot is enabled; see the [rotation record](key-rotation-20260929.md).
  Historically, the v14 configuration postcheck passed and the full review at
  `2026-09-12T07:09:37Z` completed with the approved Cowork-only status exception. The [10 September beta-only review and distribution](#build-7-distribution--2026-09-10)
  completed the build-7 upload path. Refresh the applicable operations review before any later
  candidate upload, and after every backend/production-configuration change; do not re-upload build 7.
- Fly Security summarized optional DPA termination periods of 30/90 days, but the account's
  Compliance page says the DPA is inactive until the customer signs it. Any future execution needs
  exact agreement review and owner approval; no optional DPA was signed by the 12 September
  privacy publication. The public policy discloses the accepted existing provider boundary and
  does not claim these optional termination periods as active log/snapshot purge guarantees.

## One-time gates before the next internal build

- [x] Push the readiness branch, review it, and merge the intended release scope so the uploaded
  commit is recoverable from the remote repository. PR #7 merged it to `main` at
  `f2a02825fd4178478bfc130525463165f12d648c`.
- [x] Implement the repository portion of `APP-009`: enroll one anonymous App Attest key per installation, validate fresh
  challenges/attestations/assertions at the backend, issue short-lived sessions, persist only
  durable auth/security metadata in the App Attest store, enforce build/category allowlists when
  iOS 27+ supplies those signed fields, enforce rate limits, remove `BackendDeviceToken`, and retire/rotate the legacy
  backend token in the client contract. iOS 18–26 still requires core App Attest. Local wardrobe
  and Demo Mode remain available when secure verification is unsupported; remote AI fails closed.
- [x] Enable App Attest for `com.tth.Wardrobe`, confirm App ID prefix `29NT767Y9P`, exercise
  regenerated development signing, and retain physical-device sandbox enrollment and assertion
  renewal evidence.
- [x] Provision one encrypted Fly volume for the single production Machine; verify private
  ownership/modes, SQLite integrity, restart persistence, automatic daily snapshots, a retained
  snapshot, and an isolated restore rehearsal. These snapshots are not a separate backup system.
- [x] Adopt the APP-009
  [data-lifecycle and logging policy](app-attest-data-lifecycle-policy.md), including exact target
  periods, prohibited log fields, deletion/restore rules, manual operations requirements, and an
  explicit current-compliance checklist.
- [x] Enforce the repository-owned policy: a one-minute deadline-maintenance loop on a pinned
  minimum-one-Machine topology, repeat-until-drained cleanup, 90-day inactive and 30-day revoked
  installation purge, assertion-verified in-app deletion, SQLite secure-delete/WAL maintenance,
  structural persistence/logging guards, and a pinned no-access-log production command are all
  implemented and covered by focused tests.
- [x] After policy enforcement, build and scan the exact reviewed `linux/amd64` container image,
  including OS packages, for high/critical known vulnerabilities; push and re-scan its immutable
  registry digest, then deploy only that digest. At this historical build-4 gate, Fly v7 served
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
  from source `d4637f4b2adf14cd533594aec6060c385f8a5e2b`; both scans covered 90
  packages and found no critical/high vulnerability. At that historical build-4 gate, Gmail-free v6
  digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  was the recovery baseline and passed a fresh registry scan. The emergency v5 rollback digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  was restored to the registry, re-scanned, and passed an isolated old/new/old schema-v4
  round-trip. The locked Python audit is already enforced in CI; the local Docker Scout command is
  `docker scout cves --only-severity critical,high --exit-code local://wardrobe-backend-local-verify`
  and requires an authenticated Docker Desktop/Docker ID session.
- [x] Rotate and verify the Anthropic API key, retire `DEVICE_TOKEN`, deploy App-Attest-only auth,
  and prove the retired credential returns `401`. No credential value is retained in evidence.
- [x] Treat the opaque Apple receipt as untrusted fraud evidence, not session authorization. The
  current release neither redeems nor trusts it; before any future use, implement and evidence
  Apple's receipt signature/chain, App ID, freshness, and attested-public-key checks.
- [x] Complete the repository and simulator-artifact portion of `APP-036`: Google Sign-In, Google
  client/callback configuration, Gmail/receipt-import UI and network paths, active `/extract`
  route/client capability, and receipt background scheduling are absent; build 4 used the approved
  fresh local-only schema; Demo Mode and in-app disclosures are Gmail-free; and Release/artifact
  checks fail if a removed capability returns. Intentional negative guards and legacy-rate cleanup
  remain. The historical Google OAuth sequence is deferred and is not a public-v1 gate.
- [x] Create gitignored `ios/Distribution.xcconfig` from
  `ios/Distribution.xcconfig.example` with the HTTPS backend host, public privacy/support URLs, and
  Apple Developer Team ID. It contains no Google client identifiers or callback scheme; resolved
  Release settings and the simulator artifact passed the public configuration guard. The later
  per-build archive/profile proof also passed for historical `1.0.0 (4)` source `dd3d990`; that
  archive is now superseded and cannot satisfy any current gate. The later uploaded build-4 and
  build-5 archive/profile proofs are historical. The exact build-6 archive/profile proof is retained
  in the current evidence section below.
- [x] Freeze and publish the Gmail-free source. PR #14 merged as
  `9a48caebdec67ac26673c3ba51546a5e7edcf0cc`; its remote branch was deleted, and local `main` was
  fast-forwarded to the same `origin/main` SHA before the release image was built.
- [x] Complete the pre-upload `APP-036` cutover. The installed intermediate development build
  `0.1.0 (4)` completed Google disconnection and local deletion, but it predated the
  server-deletion UI. Production had zero installations, zero sessions, and zero pending challenges
  before it was uninstalled, so no live production identity existed to delete. Exact-source
  `linux/amd64` digest
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0` passed local and registry
  critical/high scans across 90 packages and was healthy as Fly release v7 from source
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`. The registry-resolved
  v5 emergency rollback digest `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  resolved after fresh private-registry authentication at `2026-08-21T01:20:25Z`, re-scanned clean,
  and passed an isolated old/new/old schema-v4 rehearsal. Production `/extract`
  returned `404`, `/recommend` failed closed without authorization, and the payload-free
  reviewed v7 post-deploy manual review passed at `2026-08-21T06:00:21Z`. Build 4 was later
  installed only after TestFlight processing and never over the older app.
- [x] Republish accurate Gmail-free privacy-policy, support, and Terms pages on the final owned
  HTTPS domain and verify all three while signed out. `tzehon.github.io` PR #5 merged as
  `c5da090a0417bcda99fc6d328a0cdff808ea597d` at `2026-08-21T01:42:01Z`; the matching Pages run
  completed successfully at `2026-08-21T01:42:39Z`. Anonymous HTTPS requests at
  `2026-08-21T01:45:27Z` returned `200` for `https://blog.tth.dev/wardrobe/`,
  `https://blog.tth.dev/wardrobe/privacy/`, and `https://blog.tth.dev/wardrobe/terms/`. The rendered
  pages showed the 21 August 2026 effective date where applicable, linked to each other, and
  contained no Gmail/Google/OAuth/import capability claim. This closes the publication sub-gate;
  provider terms and App Privacy were then open. They were reconciled and published on
  [12 September](#privacy-publication--2026-09-12); remaining store fields are APP-017.
- [x] Explicitly defer the remaining App Store Connect record/media work in `APP-016` through
  `APP-018` for the internal TestFlight build only. APP-016 subsequently completed on 12 September;
  APP-017/APP-018 still require completion before submission. This permits no binary, signing,
  configuration, privacy, or review-evidence shortcut.

The following ordered gates record the completed build-4 replacement/upload path. They replaced the
superseded `dd3d990` archive but are historical now that physical QA requires build 5:

- [x] **Merge and freeze the review fixes.** PR #19 rebase-merged the reviewed Swift, backend,
  shared-contract, release-verifier, and focused-test changes. The remote branch was deleted and
  clean synchronized `main` was `d4637f4b2adf14cd533594aec6060c385f8a5e2b` at that historical
  gate.
- [x] **Build, scan, and deploy the exact reviewed backend.** The exact frozen `linux/amd64` image
  passed local and immutable-registry critical/high scans across 90 packages and was deployed only
  as digest `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`.
  Production health, auth-store/configuration, encrypted storage, snapshot policy, and Gmail-free
  route behavior passed, followed by the payload-free review at `2026-08-21T06:00:21Z`.
- [x] **Run a clean Release regression and create the replacement signed archive.** App Store
  Connect showed builds 1–3 only at `2026-08-21T06:34:50Z`. Clean source context `24c17cb` passed
  219 backend tests, 215 Swift tests, all 9 UI flows, 43 release-script tests, and every Release,
  request-capture, dependency, privacy-manifest, and removed-capability gate. Xcode 26.6/iOS SDK
  26.5 created `Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive` at
  `2026-08-21T06:36:33Z`; strict certificate/profile, production App Attest, public-config,
  privacy-manifest, and Gmail-free artifact verification passed. Separate targeted credential-
  pattern and app/dSYM UUID checks also passed.
- [x] **Repeat the pre-upload review, then validate and upload.** The exact-v7 payload-free review
  and immediately refreshed App Store Connect list passed at `2026-08-21T08:12:46Z`, with builds
  1-3 still the only uploads. Xcode validated only the replacement `24c17cb` archive at 08:16Z and
  uploaded it through the normal **TestFlight & App Store**-eligible route at 08:18Z. Processing
  completed by `2026-08-21T08:20:20Z`; processed metadata, symbols, the `Family` internal group,
  and the saved truthful What to Test wording reproduced below were verified. Neither `dd3d990`
  archive was used.

The historical build-5 path and build-6 replacement path are ordered. Build-5 Apple distribution,
build-4 identity-safe recovery, partial clean build-5 physical QA, the build-6 availability check,
review/merge, Fly v9, strict archive, Apple internal distribution, clean build-6 physical QA, and
the final build-6 deletion/reinstall/new-enrollment handoff are complete. The monitored 25/28 August
snapshots were later observed absent from the customer-visible list. The 10 September Build-7 pre-
deletion snapshot's later disappearance and deletion-specific recovery/non-return were not proven
and were owner-waived only for the Free Singapore v1. The visual-control assessment is complete and
failed, and PR #31 has merged the replacement implementation. Build `1.0.0 (7)` is selected and its
source configuration is prepared; the archive-era Fly v10 deployment and post-change review passed.
The current Fly v16 runtime has the same private policy applied with the bounded pilot enabled;
see the 12 September activation checkpoint.
The build-7 exact-source regression, strict signed-archive verification and 10 September internal
distribution have passed. The 11 September handoff, clean first launch and scoped local-beta QA
are complete; use that checkpoint and its automation ownership record for current status.
The following entries retain the completed predecessor sequence:

- [x] **Freeze the fixes.** Reviewed PR #23 merged the Today offline-cache fix, its focused
  tests, the production registration/assertion success-marker logging fix, and the TestFlight build
  `4,5` backend allowlist at `2026-08-21T10:29:56Z`. The frozen shipped-code/backend source was
  `4a75b99dcd49e818ad1d5b198e8c49abba702e18`; later docs-only evidence does not change the
  deployed image or iOS bundle. Keep `MARKETING_VERSION = 1.0.0`; both the archive-time and final
  pre-validation unused-build checks passed.
- [x] **Retain historical build-5 pre-archive regression evidence.** The frozen build-5 worktree passed 221
  backend tests plus locked dependency audit/Bandit/Ruff/mypy; the regenerated project passed 218
  Swift unit tests and all 9 UI flows; and 43 release-script tests plus Release simulator/artifact
  checks passed. Rerun any affected gate if source or configuration changes before archive.
- [x] **Build, scan, deploy, configure, and review the backend candidate.** Fly v8 serves exact PR
  #23 source and immutable digest
  `sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`.
  Local/registry scans, runtime/storage/route/configuration checks, the `4,5` allowlist, targeted
  INFO logger, retained rollback/recovery checks, and the `2026-08-21T11:09:20Z` payload-free
  post-change review passed. This closed deployment/configuration review only at that stage; later
  physical QA observed the bounded lifecycle markers recorded below.
- [x] **Recheck App Store Connect, archive, and verify build 5.** Fresh registry recovery checks,
  the exact-v8 payload-free review, and the archive-time build-list refresh passed at
  `2026-08-22T01:00:09Z`, `2026-08-22T01:07:45Z`, and `2026-08-22T01:09:39Z` respectively.
  Build 4 remained highest and build 5 unused. The exact new production-signed archive passed the
  strict verifier, profile/entitlement/identity checks, separate non-emitting credential and
  removed-capability scans, and matching app/dSYM evidence recorded below.
- [x] **Retain exact synthetic `/recommend` request-capture evidence.** A tests-only assertion pins
  every stored property on the three Swift request types, including nil optionals, and separately
  pins the exact encoded top-level, catalog-item, and preference key sets. The shared schema/backend
  reject extras. The strengthened focused `RecommendClientTests` suite passed 12/12 at
  `2026-08-22T01:59:08Z` on an iPhone 17/iOS 26.5 simulator. After adding that guard, the mandatory
  backend gate passed 221 tests plus audit/Bandit/Ruff/mypy, and one uninterrupted full iOS run
  passed 218 Swift unit tests and all 9 UI tests (227/227 canonical cases); its result bundle
  finalized at `2026-08-22T02:04:17Z`, with no failures, skips, or retries. No production payload,
  token, or identifier was inspected or retained; the test-only change does not alter the signed
  archive or require a new build number.
- [x] **Validate, upload, process, and assign build 5.** The exact-v8 pre-validation review passed at
  `2026-08-22T02:37:08Z`, and the final `2026-08-22T03:16:16Z` App Store Connect refresh still showed
  builds 1–4 only with build 5 absent. Xcode validation succeeded at `03:18:30Z` and the normal App
  Store Connect upload succeeded at `03:20:59Z`, both with zero warnings, errors, or information
  messages. Symbols were included; **Manage version and build number** and **TestFlight Internal
  Testing Only** were off. Processing reached **Ready to Submit** by `03:24:21Z` with the expected
  version/build, bundle, SDK, architecture, minimum OS, symbols, encryption, production App Attest,
  `get-task-allow`, and beta-reporting metadata. The build lists only the `Family` Internal Testing
  group with one tester and no individual testers, and the truthful build-5 What to Test wording
  reproduced below is saved. The post-distribution exact-v8 review passed at `03:30:33Z`. Build 5
  is consumed and must never be reused.
- [x] **Complete build 4's identity-safe recovery/handoff.** Build 5 appeared installed in place,
  but the predecessor's live proof of possession remained available. A successful post-enrollment
  automatic snapshot created at `2026-08-22T07:33:23Z` was confirmed with 14-day retention;
  **Delete Server Security Data** succeeded; production installation/session/challenge aggregates
  returned to zero; and local deletion plus app removal preceded the clean build-5 install. This is
  safe recovery evidence, not upgrade/migration product proof.
- [x] **Run clean build-5 physical QA through the first blocker.** The launch/local/media/catalog,
  production auth/styling, Today offline-cache/failed-Restyle, and Wear/History boundaries passed,
  including one registration and one later assertion marker without payloads or identifiers. A
  delivered reminder tap at `2026-08-22 17:15:14 SGT` then caused `EXC_CRASH`/`SIGABRT`; build 5
  is non-promotable and must not receive another notification-tap attempt.
- [x] **Diagnose and implement the source fix on a branch.** The crash exactly matches the build-5
  dSYM and safely symbolicates to the generated async bridge for
  `DailyReminderNotificationRouter.userNotificationCenter(_:didReceive:)`. Branch
  `codex/fix-notification-tap-crash` replaces both imported async notification-delegate bridges
  with explicit completion-handler/main-queue routing. Focused tests passed 17/17 and the full
  branch regression passed 221 backend tests plus audit/Bandit/Ruff/mypy, 222 Swift unit tests,
  all 9 UI flows, and 43 release-script tests. This branch evidence was later superseded by the
  merged-source, Fly v9, archive, and Apple distribution evidence below.
- [x] **Confirm the replacement build number in live App Store Connect.** The read-only signed-in
  TestFlight **Build Uploads** view at `2026-08-22T10:02:31Z` showed builds 1–5 only, build 5
  **Complete**, and no build 6. Build 6 is confirmed unused and selected; the branch records
  `CURRENT_PROJECT_VERSION = 6`, source allowlist `4,5,6`, and `MARKETING_VERSION = 1.0.0`.
- [x] **Complete the replacement candidate pipeline.** PR #27 merged to clean synchronized `main`
  `de7c540275fb16e61aabf1884538b18cf6edf76f`. Merged-source regressions/release guards, exact Fly
  v9 compatibility and health, and strict verification of
  `Wardrobe-1.0.0-6-de7c540-appstore.xcarchive` passed. Xcode validation and normal-route upload
  succeeded; Apple processing reached **Ready to Submit**; only `Family` is assigned, with one group
  tester, no individual testers, and saved truthful What to Test notes.
- [x] **Record the missed v9 operational review honestly and restore current evidence.** The
  required post-deploy/pre-upload review was missed and is not backdated. The complete payload-free
  review passed late at `2026-08-23T02:13:12Z`; repeat before any future archive/upload and after
  every backend/configuration change.
- [x] **Identity-safely replace build 5 and repeat clean build-6 QA through the fixed route.** The
  eligible snapshot, ordered server/local deletion, aggregate-zero check, removal, clean build-6
  install, production auth, local/offline matrix, and delivered-reminder tap passed. The unexpected
  in-place build-6 installation was not counted as QA or migration evidence.
- [x] **Complete the final build-6 deletion/reinstall boundary.** A successful automatic snapshot
  created at `2026-08-25T07:35:53Z` reported `created` with 14-day retention. Before deletion, the
  installation/session/challenge aggregate was `1/0/0`. Assertion-verified server deletion
  emitted exactly one bounded success marker and returned the aggregate to `0/0/0`; it remained
  `0/0/0` after local deletion and uninstall. After a clean reinstall, launch, two local additions,
  and styling-consent grant also left it at `0/0/0`. Explicit Style at
  `2026-08-28 17:17 SGT` then created one active installation and one active session, with zero
  pending and zero failed challenges, one completed challenge, exactly one registration-success
  marker, and expected runtime-field absence on iOS 26.6. This closes the owner-controlled handoff,
  not snapshot-list expiry, deletion-specific recovery/non-return or final Google retirement.
  The snapshot/recovery evidence was later owner-waived only for the Free Singapore v1.
  Build-7 internal distribution completed on 10 September; its scoped local-beta QA completed on
  11 September as recorded above.

## Mandatory clean-uninstall transition for build 4

Build `1.0.0 (4)` is fresh-install-only and must never be installed over an earlier app. The owner
explicitly accepted losing the earlier local wardrobe and adding items again.

The pre-upload portion completed on 2026-08-21. The installed intermediate development build was
`0.1.0 (4)`, not an uploaded TestFlight candidate. It completed **Disconnect Google** and
**Delete Local Data**, but predated **Delete Server Security Data**. A read-only aggregate query
reported zero production installations, sessions, and pending challenges, so there was no live
production identity to delete. The app was then uninstalled. This exception is evidence about that
one retired build, not permission to skip verified server deletion when a future installed build
has a live identity or exposes the control.

Build `1.0.0 (4)` was installed only after it processed in TestFlight and only after the older app
was removed. That clean install enrolled a new anonymous production App Attest identity. This is
historical build-4 evidence, not upgrade or migration support.

The planned handoff was recovered after build 5 appeared installed in place: the predecessor's
proof of possession remained live, an eligible successful post-enrollment snapshot was confirmed,
server security data was deleted with zero aggregate confirmation, and local deletion plus app
removal followed. Build 5 was then installed cleanly. This completes the predecessor handoff but
does not validate the in-place installation as a supported upgrade. Build 5 later completed the
same identity-safe sequence before build 6 was installed cleanly. The original clean build-6
identity later completed the same ordered deletion after an eligible snapshot, followed by local
deletion, uninstall, clean reinstall, and a new anonymous enrollment only when the owner explicitly
styled a look. These are fresh-install and deletion proofs, not upgrade or migration support.

## AI pilot pre-enable review — 2026-09-12

The read-only review at `2026-09-12T03:39:31Z`, on clean synchronized main after PR #50,
passed the locked archive, exact healthy Fly v12 runtime, App Attest configuration, durable
auth-store integrity and approved capacity band, volume usage, fresh automatic 14-day snapshot,
bounded events, public backend and exact Linux/AMD64 recovery image with zero High/Critical
findings. The budget diagnostic confirmed disabled, below-warning and no pending work. A separate
service-UID read-only comparison confirmed the exact already-approved private policy and ready
ledger. The original one-Machine shared-CPU/512 MB resource envelope remains intact.

Signed-in review confirmed the existing production workspace cap and warning emails, zero displayed
workspace spend, prepaid credits, auto-reload off, the recorded 8 October key expiry and zero
reported Sonnet quota utilization over the last 24 hours. Fly's September invoice subtotal and
same-period Cost Explorer agreed, but displayed net due differed and no exact usage cutoff was
shown. Exact amounts remain private. Five expected billed product categories were visible; this
does not establish complete coverage of every possible account service or cap the final bill.
Retain the approved daily owner review and warning/hold procedure, without resurrecting the
deferred monitoring prototype.

The public-page check exposed a parser defect: HTML whitespace wrapping inside the snapshot
disclosure was treated as missing text. Normalizing whitespace fixes the live support/privacy/Terms
check without weakening required content, reciprocal links, contact or removed-capability guards.
Regression cases cover newlines, tabs, inline markup, nonbreaking spaces, missing disclosure and
forbidden wording split across lines.

The aggregate Anthropic status endpoint reported a minor outage. Its official summary identified
only Claude Cowork on Windows; both Claude API and Console were operational. Preserve the aggregate
checker as OPEN, with this component-level evidence separately recorded; do not silently label the
whole preflight green. Recheck the actual incident scope at activation. A targeted exception for
this unrelated incident must be part of the concrete enablement approval, not a general waiver for
provider API degradation. [Official status summary](https://status.claude.com/api/v2/summary.json).

Validation passed: 845 backend tests plus locked pip-audit, Bandit, Ruff and mypy; 227 Swift
unit tests and 10 UI tests; 44 release-script tests; 67 local documentation links, the new
runbook anchor and `git diff --check`.

No production setting, provider setting, ledger, app data or signed archive changed, and no paid
call was made. This checker/documentation change needs no new TestFlight build. Complete its
review/publication and the bounded activation approval before enabling AI; the first protected
styling call remains a physical-device boundary.

## Bounded AI pilot activation — 2026-09-12

The owner approved the exact five-file preflight PR, activation and single protected verification
call package, including residual Fly invoice exposure, unchanged private limits, disable-on-failure
response and the narrowly scoped Cowork-on-Windows status exception. PR #51 received a current-head
Codex thumbs-up with no findings and green backend CI, then rebase-merged to main
`a64a8332e33546f7cbfdf6d048cad8a2826ecfec`. The preceding regression passed 845 backend tests and
all locked security gates, 227 Swift tests, 10 UI tests and 44 release-script tests.

The fresh disabled review completed at `2026-09-12T04:25:10Z`. Exact policy, ready/idle ledger,
original resources, App Attest, archive, public backend/pages and zero-High/Critical recovery scan
passed. Same-session signed-in checks confirmed the production workspace cap/email thresholds,
credits and auto-reload off, key expiry, no Sonnet quota saturation, Build 7 Complete in Family,
and official two-day Fly HTTP series 200/204/404 with no visible 5xx series. Billing views retained
a small discrepancy and no proven usage cutoff; amounts stay private. The public API and Console
were operational, with only the specifically approved Cowork incident active.

The approved command changed only `AI_STYLING_ENABLED=true`. Fly completed release **v13** on the
original Machine and encrypted volume, retaining the same immutable image and source
`d2866a2375dd4795f40a3ab13d273ed138cedd7e`. An independent read-only probe as service UID/GID 10001
confirmed the exact approved policy, enabled state, pinned Sonnet, intact ready ledger, below-
warning spend and no pending work. No credentials, limits, model settings, resources or data were
replaced, and no paid call was made by the agent.

The enabled `ai-launch` operational review completed at `2026-09-12T04:28:57Z` using the observed
release number, unchanged source/archive identity and the repository's existing check functions.
All checks passed except the preserved aggregate Anthropic `OPEN public-status-open` result.
Fresh official summary evidence matched the owner's approved exception: API/Console operational,
only the identified Cowork-on-Windows incident, no API incident or maintenance. The outcome is
**PASS with the approved Cowork-only exception**, not an unqualified all-green preflight or public-
submission approval. The operations lock recorded observed v13 at that checkpoint. Private full results,
original nonzero reports, approval/proposal binding and resource identity comparisons are retained.

Build 7's What to Test text now describes the enabled bounded pilot, one initial styling request,
no retry after failure/timeout, local-feature availability and the existing consent disclosure.
Saving and reloading retained the text; Family remains the only group with one tester and there
are no individual testers. No build, tester invitation or distribution group changed.

### First protected TestFlight call — 12 September 2026

**Passed.** After the existing consent instruction, the owner supplied a screenshot showing an
outfit displayed in Today at **13:34 SGT** on the installed TestFlight build `1.0.0 (7)`.
The screenshot and wardrobe/output content are not copied into repository evidence.

At `2026-09-12T05:36:01Z`, the approved read-only follow-up verified the exact v13 runtime on the
same image and Machine, and the existing policy/ledger as service UID/GID 10001. The current-month
ledger records exactly **one admission**, settled below its conservative reservation, with zero
active or uncertain reservations, no halt and spend below warning. Anonymous security aggregates
show one active installation, one active session, zero pending challenges and zero failed
challenges. Exact cost and private values remain in the ignored evidence record.

The owner-visible result plus settled server admission closes the first protected styling-call
gate. This is physical TestFlight evidence, distinct from simulator coverage. No second request,
Restyle, synthetic authentication bypass, paid agent call, ledger reconciliation, reset or runtime
mutation occurred. It does not establish cold-session renewal, a new deletion/recovery test,
iOS 27+ signed runtime-field enforcement or public-submission approval.

Leave the bounded pilot enabled under the existing limits and daily owner review. The next daily
cost review is due 13 September, sooner after a problem or configuration change. Use the already
approved AI-disable response on failed verification, unexpected charge or uncertain work, preserving
charges and reservations. The global AI ceiling does not cap the Fly invoice. Public Singapore
submission remains separate. No new TestFlight build is required.

### App Store compatibility deployment — 12 September 2026

PR [#54](https://github.com/tzehon/wardrobe-stylist/pull/54) merged the approved App Store
compatibility/configuration-verifier work after review corrections, current-head Codex approval
and passing checks. The exact reviewed tree passed 870 backend tests, locked audit/Bandit/Ruff/mypy,
237 iOS tests and 44 release-script tests. No shipped iOS source or API contract changed.

The approved configuration-only deployment completed as **Fly v14**. Independent post-verification
at `2026-09-12T06:36:24Z` returned **PASS_CONFIGURATION_ONLY_POSTCHECK**. The live App Attest
categories are `2,4`, with accepted builds `4,5,6,7`; the exact immutable image/source, original
Machine and encrypted volume, keys, approved policy and intact ledger remain unchanged. AI stays
enabled, with ready/below-warning ledger and clear concurrency. No paid call was made. Provider
IDs, secret hashes and exact private policy/accounting values remain only in ignored evidence.

The operations lock records observed release 14/categories `2,4`, preserving every other binding,
including source `d2866a2375dd4795f40a3ab13d273ed138cedd7e` and the signed build-7 archive.
The complete regression was rerun after that lock update at source `2c0148c1dd451cf0a9e4ac63b4cb05fd690a714b`:
870 backend tests plus locked pip-audit/Bandit/Ruff/mypy passed; XcodeGen and all 237 iOS tests
(227 Swift and 10 UI) passed at `2026-09-12T06:51:51Z`, with all 44 release-script tests passing.
Subsequent edits in this evidence tranche change documentation only; the tested v14 lock, runtime
source, shipped iOS source and archive bindings are unchanged. Recording the later operations
result without changing those inputs does not introduce another code/configuration change.
**At this 06:36:24Z deployment checkpoint, the full operations review was still pending.**
The configuration postcheck was not a completed public/manual/recovery review. The later
[07:09:37Z final review](#final-v14-operations-review--12-september-2026) is recorded separately.

Apple draft evidence: Add for Review validation passed; version `1.0.0` with build 7 is **Ready
for Review** in a draft submission. Listing/declarations, the five fictional screenshots in the
verified order, Free price, Singapore-only availability and disabled Mac/Vision availability are
saved and reload-verified. The corrected owner contact remains private; the corrected 2,064-character
reviewer notes have separate support/privacy links and a complete fictional top/trousers/shoes
example. The exact text was saved and reload-verified after the review correction. Manual release
was retained. **Submit for Review had not been clicked at this checkpoint.** The later
[submission checkpoint](#apple-app-review-submission--12-september-2026) records that separately
approved action. No new TestFlight build was required.

## Final v14 operations review — 12 September 2026

PR [#55](https://github.com/tzehon/wardrobe-stylist/pull/55) merged the observed v14 lock and
corrected draft evidence after current-head Codex review and passing checks. The final strict
`ai-launch` review ran from clean synchronized main
`012e466369bfd0da59484076992fbcc8f376862a`. Its redacted baseline is timestamped
`2026-09-12T07:09:37Z`; the separate exception result finalized at `07:09:41Z` was
**PASS_WITH_APPROVED_COWORK_ONLY_EXCEPTION**.

Source/archive identity, exact healthy Fly runtime/configuration, auth-store integrity and
aggregate bands, enabled below-warning budget, volume/snapshot policy, bounded events, public
backend/pages, fresh official Fly metrics, signed-in Anthropic Console and App Store Connect
checks all passed. The exact Linux/AMD64 recovery image passed with zero High/Critical findings.
The same image/source, Machine, volume, keys, policy and intact ledger were retained. This review
made no paid test calls or provider/resource mutations.

The baseline deliberately retains `anthropic_status=OPEN public-status-open`. Fresh verification
matched the exact previously approved Cowork-only incident, with API, Console and every other
component operational and no maintenance. The scoped exception accepts that one status result;
it does not turn the baseline into an unconditional all-green report or waive another check.
The original redacted baseline and separate exception record remain privately retained.
`preupload_evidence=OPEN owner-upload-approval-not-requested` also remains truthful: this run
requests no new archive/upload and cannot grant upload or public-submission approval.

The tested v14 operations lock, backend runtime, iOS source and signed build-7 archive are
unchanged from the complete regression recorded above: 870 backend tests and all locked
security/lint/type checks, 237 iOS tests and 44 release-script tests passed. This final evidence
update changes documentation only; no repeated regression or new TestFlight build is needed.

At this 07:09:37Z review checkpoint, Apple's version `1.0.0`/build-7 draft was **Ready for Review**, with the verified
2,064-character reviewer notes, Free Singapore-only availability and manual release selected.
**Submit for Review had not been clicked; the owner's decision was still pending.** The later
[submission checkpoint](#apple-app-review-submission--12-september-2026) records the approved action. Retirement of the
inventoried Wardrobe Google Cloud/OAuth projects remained unperformed at that checkpoint and
required separate owner confirmation. The later [19 September retirement](../gcp-retirement-20260919.md)
records the owner-requested shutdowns and pending final deletion. Legacy cleanup did not block the
verified Gmail-free Free Singapore v1; APP-036 was still in progress for cleanup and submission.
Keep ordinary daily pilot review and the accepted Fly cost/snapshot residual risks; this checkpoint adds no restore,
all-copy-purge or deleted-identity recovery proof.

## Apple App Review submission — 12 September 2026

The owner explicitly approved submitting the existing reviewed **1.0.0 (7)** candidate to Apple
with **Manually release this version** selected. At 15:32 SGT (07:32 UTC), the exact version/build
and selected manual-release control were checked immediately before **Submit for Review** was
clicked once. Apple confirmed **1 Item Submitted** and showed the iOS submission as **Waiting for
Review**, with one submitted item: iOS App `1.0.0`, build `1.0.0 (7)`.

This is verified submission, not Apple approval or public release. The owner approved this
submission step only; manual public release requires separate owner approval after Apple's review.
The submitted candidate retains the reviewed listing, screenshots, 2,064-character reviewer
notes, Free Singapore-only availability and disabled Mac/Vision availability. No new archive,
upload, runtime/configuration change or paid AI call was needed.

Private confirmation evidence is retained separately from the frozen approval materials; the
submission identifier and contact details are not reproduced here. PR #56 had already recorded
the final v14 review with its approved Cowork-only exception. This update changes documentation
only and retains the exact tested/runtime/lock/iOS/archive inputs and completed regression.
No new TestFlight build is required. Continue ordinary pilot operations, respond to App Review
if needed, and await the review outcome. Google project retirement remained unperformed at that
submission checkpoint and required separate owner confirmation; it was not a public-v1 submission prerequisite. The later
[19 September retirement](../gcp-retirement-20260919.md) records the owner-requested shutdowns and
pending final deletion.

## Apple information request — 13 September 2026

A signed-in read of the existing App Store Connect submission confirmed build **1.0.0 (7)**
as **Rejected**, with one message dated **13 September, 09:15 SGT**. The cited issue is
**Guideline 2.1 — Information Needed — New App Submission**: Apple requests more information
because the developer account has limited App Review history. The message identifies no
specific crash, failed feature or other product defect. Its separate common-issues section
is general guidance, not additional findings against this build.

Apple requests the following in both an App Review reply and the App Review Information Notes:

1. A screen recording from a physical device running the latest operating system, beginning
   with app launch and showing the typical user flow and any applicable account, shared-content
   or paid-feature flows.
2. The app's purpose, target audience, problem solved and value.
3. Setup and access instructions for the main features, with credentials/sample files if needed.
4. External services, tools and platforms used for core functionality.
5. Regional feature/content differences, or confirmation of consistent behavior.
6. Relevant authorization for regulated services or protected third-party material, if applicable.

The existing v1 instructions provide much of the written information. The new substantive
evidence is the physical-device recording; existing simulator tests and screenshots do not
meet that explicit request. No code change or new TestFlight build is indicated by the message
alone. This checkpoint records read-only assessment and local documentation updates only;
no reply, upload, submission change or resubmission has occurred. Apple approval and separately
approved manual public release remain pending.

### Response preparation — 13 September 2026

After the owner asked to proceed, the six-part response was prepared and independently checked
against current app/backend behavior. App Store Connect saved it using **Save Draft**, and
**Continue Draft / Delete Draft** remained visible after navigating away and back. The same
**3,899-character** text was saved in App Review Notes and verified after reload; 101 characters
remained. Build 7 and the selected manual-release setting were retained. Section 1 explicitly
says the physical-device video is not yet attached. No reply or resubmission was sent.

The paired physical iPhone reported iPhone 16 Pro / iOS **26.6.2**, matching Apple's published
latest public release on this date. Mirroring required an owner unlock and was closed; Apple
also documents that device screen recording cannot run together with screen mirroring. No
device reset, deletion, installation, app launch or paid styling request was performed.

The [recording guide](review-walkthrough-20260913.md) preserves the current installation and
asks for one normal flow, not a repeat of completed QA. The pending-video response is retained
privately in `.fly/app-review-response-20260913/` and was mirrored in the tracked reviewer notes
at this preparation checkpoint. The remaining steps were to inspect the actual recording, replace
the pending-video paragraph with verified video/device/build details, attach it and synchronize Notes. This documentation/preparation work
changes no app/runtime/configuration/test input and requires no new TestFlight build.

### Recording received and upload copy prepared — 13 September 2026

The owner supplied an 89-second recording showing the physical app launch, a photo-based item
save, enabled AI disclosure, a successful styling request, Wear/History, privacy controls and
Settings **1.0.0 (7)**. The recording uses the owner's clothing photos, not bundled Demo data.
Review found no visible app failure; deletion controls were displayed without being activated.

A private H.264/30fps upload copy retains the full app sequence and masks unrelated photo-picker
thumbnails. The original stays unchanged. The original audio is digitally silent; the derivative
omits it and source metadata. Visual checks and a decoded-frame black-region check verified the
mask. Private hashes and the 3,943-character final reply are retained under
`.fly/app-review-response-20260913/`; no video/private thumbnail content is tracked in Git.

The video and final reply await owner approval for private Apple transmission and resubmission
of the same build with manual release retained. Apple still holds the earlier unsent draft and
pending-video Notes. No file upload, reply, resubmission, backend change or new TestFlight build
has occurred at this checkpoint.

## Apple information response and resubmission — 13 September 2026

The owner explicitly approved the reviewed redacted video, final reply, App Review Notes update
and resubmission of existing **1.0.0 (7)**, retaining manual public release. The approval record
binds the exact private video/reply hashes; the unredacted original was not uploaded.

- App Store Connect accepted **`wardrobe-app-review-build7.mp4`** as the reply attachment. It
  persisted with the saved draft and was visible on the sent message.
- The final **3,943-character** six-part response was saved in App Review Notes and verified
  after reload, with 57 characters remaining. The selected build stayed 7 and **Manually release
  this version** remained selected; sign-in remained unnecessary.
- **Reply** sent the response at **11:55 SGT**. Apple showed **Messages (2)** and the sent
  message with its video attachment, replacing the unsent-draft controls.
- **Update Review** changed the item to **Ready for Review**. **Resubmit to App Review** then
  returned both the submission and its sole item **1.0.0 (7)** to **Waiting for Review**.
  Apple displayed **Date Submitted: 13 September 2026, 11:56 SGT (03:56 UTC)**.

The [canonical reviewer notes](review-notes-1.0.0.txt), README, release plan and backlog reflect
this completion. Private execution evidence remains under `.fly/app-review-response-20260913/`;
the video and personal-content inspection artifacts remain excluded from Git. Apple approval
and manual public release have not occurred. Await Apple's response and continue the existing
bounded-pilot cost routine; no new manual QA cycle is assigned.

This work changes documentation and Apple review materials only. It changes no iOS bundle,
API contract, backend configuration or test input, and requires **no new TestFlight build**.
Documentation consistency and whitespace checks apply; the existing code-regression evidence
is retained without rerunning unchanged suites.

## Business model information request — 16 September 2026

A fresh signed-in App Store Connect inspection found **Rejected / Unresolved Issues** for
**1.0.0 (7)**. Apple's new **Guideline 2.1(b) — Information Needed** message appears at 00:41 SGT
on 16 September, with review date **15 September** and review device **iPhone 17 Pro Max**.
It asks who uses paid features, where they are purchased, which previous purchases can be
accessed, and which paid features unlock without In-App Purchase. No crash, broken flow or
new video request is identified in this message.

Source inspection confirms that this build has no paid-feature, StoreKit, checkout or paid-
entitlement implementation. The live listing still says Free/no-IAP/no-subscription, Singapore
current price is **SGD 0.00**, build 7 remains selected, and manual release remains selected.
Optional AI is developer-funded and provided without user payment. Clothing purchase metadata
is an optional local record of an owned garment's price/date, not digital-feature commerce.
Freemium remains an unimplemented future milestone.

The [prepared four-part response](business-model-response-20260916.md) explains each distinction.
It awaits owner approval to send and, if required by the Apple workflow, resubmit the same build.
The 13 September video and reply remain completed evidence; no new upload, paid call, app
change or production configuration change is proposed. Keep the existing saved App Review Notes
and walkthrough unless a later approved update is needed. Manual public release is separate.

This is a documentation/correspondence clarification requiring **no new TestFlight build**.
Source and documentation consistency checks apply; unchanged full regression and physical QA
are retained. No response or new resubmission has occurred at this preparation checkpoint.
The Apple session expired on returning to the reply page, so the new response remains local;
no Apple draft or Notes change was saved on 16 September.

### Business-model reply sent — 16 September 2026

After an independent simulated App Store reviewer found no blocking issue, the owner explicitly
asked to send the existing reply as-is. The optional wording refinement was not applied. The
restored signed-in session accepted the exact **2,327-character** response through **Reply**.
Apple then showed **Messages (4)** and the sent message dated **16 September, 16:14 SGT**.
The private source hash still matches the reviewed payload.

The submission remained **Rejected / Unresolved Issues** after delivery. No new resubmission,
App Review Notes change, replacement video, build upload, pricing change or production mutation
was performed. Await Apple's assessment of the supplied information; delivery is not approval.
The manual-public-release boundary and no-new-TestFlight-build assessment remain unchanged.

## Similarity rejection — 19 September 2026

A fresh signed-in inspection in the open App Store Connect desktop app verified **Messages (5)**.
The newest Apple message is dated **19 September, 07:18 SGT** and cites **Guideline 4.3(a) —
Design — Spam**. It alleges that the binary, metadata or concept is similar to other developers'
apps with minor differences and asks for distinct content and functionality. Apple names no
specific matching app, code path or feature, and identifies no particular crash or security defect.
The extended-review warning concerns repeated problematic submissions, possible delays and risk
to the developer account; it does not state that the account has been removed.

Build **1.0.0 (7)** remains **Rejected / Unresolved Issues**. The owner-approved 16 September
business-model reply is retained as sent at 16:14 SGT. The new message changes the current next
step from waiting for that reply's assessment to addressing the similarity concern. See the
[rejection and response plan](spam-rejection-20260919.md).

Prepare a focused clarification using verifiable source provenance and implemented workflows,
and confirm any template use or related submissions from other accounts with the owner before
making assurances. If clarification does not resolve the concern, consider an evidence-backed
appeal. Product changes depend on the evidence; this notice alone does not justify a broad refactor
or repeated unchanged resubmissions.

This initial checkpoint was read-only review and documentation preparation. No new message or appeal was
sent, no build was resubmitted or uploaded, and no production change was made. The saved Notes
and existing walkthrough remain retained evidence. Manual public release remains unapproved.
Documentation and correspondence preparation require **no new TestFlight build**; unchanged
regression and physical evidence are retained.

### Similarity clarification reply sent — 19 September 2026

After approving the visible draft, the owner asked to reply. The exact **1,399-character** message
was sent through the open App Store Connect desktop app. Delivery was verified as **Messages (6)**
and the owner's message dated **19 September, 15:46 SGT** (shown as **Today 3:46 PM**).
The exact sent text is retained in the [canonical response record](spam-rejection-20260919.md).

The submission remains **Rejected / Unresolved Issues** under Guideline 4.3(a). Await Apple's
clarification. Facts about template use and related submissions from other accounts are still
unconfirmed by the owner; the sent reply makes no assurances about them.

This action sent a review-thread reply only. No appeal, resubmission, new build, App Review Notes
or listing change, attachment upload, or production change was performed. The existing walkthrough
and Notes remain intact. Manual public release remains unapproved. This correspondence requires
**no new TestFlight build**; unchanged regression and physical evidence are retained.

## Per-build release-candidate loop

1. **Freeze the candidate.** Use a clean, reviewed commit. Record its hash, the backend image that
   will serve it, App Attest environment/category/build allowlist, iOS-version compatibility policy,
   durable auth-store version, and the policy-compliance evidence linked from
   [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md). Immediately before
   archive/upload, freshly authenticate, re-resolve the privately retained exact budget-aware
   recovery reference, verify its expected source identity and Linux/AMD64 architecture, and repeat
   the zero-High/Critical scan. Former references, including v6 whose current identity is not
   independently proven, are ineligible. Any mismatch or failure blocks archive/upload.

   From clean synchronized `main`, run the owner-triggered read-only helper immediately before
   upload:

   ```bash
   python3 backend/verify_production_operations.py --refresh-registry-auth
   ```

   This automates exact archive/source/runtime/configuration checks, the payload-free read-only
   auth-store and volume/snapshot review, public route/page and Claude-status checks, and a fresh
   exact recovery-image Linux/AMD64 plus zero-High/Critical scan. It emits only fixed results and
   safe snapshot UTC/status/retention; it does not call `/recommend`, mutate Fly, or authorize an
   upload. The official Fly response-class metric, signed-in Anthropic console state, and signed-in
   App Store Connect Build Uploads view remain live manual checks. Record only those same-session
   outcomes in the gitignored `backend/production-operations-evidence.toml`:

   ```toml
   checked_at_utc = "REPLACE_WITH_CURRENT_UTC"
   marketing_version = "COPY_EXACT_LOCKED_VALUE"
   build_number = "COPY_EXACT_LOCKED_VALUE"
   archive_cdhash = "COPY_EXACT_LOCKED_VALUE"
   deployed_revision = "COPY_EXACT_LOCKED_VALUE"
   official_fly_metrics = "pass"
   anthropic_console = "pass" # "warning" blocks upload
   app_store_connect = "pass"
   ```

   Copy those four candidate fields exactly from `backend/production-operations.toml`; they bind the
   signed-in observations to the locked archive and deployment. Rerun the helper with
   `--refresh-registry-auth --manual-evidence
   backend/production-operations-evidence.toml`. For an intentionally AI-disabled internal beta,
   include `--purpose internal-beta-ai-disabled`; otherwise retain the default `ai-launch`
   purpose. It must be eligible for the declared purpose within 30 minutes of those observations. Missing, malformed, stale, timed-out, or weaker evidence stays `OPEN`. After a
   pass, add one identifier-free fixed-field row—including remediation outcome and next due—to the
   policy's long-lived manual-review register; the gitignored TOML is only same-session input and is
   not the retained review record. Explicit owner upload approval is still a separate gate.
2. **Confirm version/build from App Store Connect.** The archive-time inspection at
   `2026-08-21T06:34:50Z` and final pre-validation refresh at `2026-08-21T08:12:46Z` showed builds
   1-3 only, so the replacement archive correctly preserved `1.0.0 (4)`. Its completed upload now
   consumes build 4. For build 5, the archive-time refresh at `2026-08-22T01:09:39Z` showed builds
   1–4 only and build 5 unused. The final pre-validation refresh at `2026-08-22T03:16:16Z` again
   showed builds 1–4 only and build 5 absent. Its completed upload now consumes build 5; never reuse
   a build number. The read-only live TestFlight **Build Uploads** inspection at
   `2026-08-22T10:02:31Z` showed builds 1–5 only, build 5 **Complete**, and no build 6; build 6 is
   confirmed unused and selected with `MARKETING_VERSION = 1.0.0`. The later completed normal-route
   upload consumes build 6; never reuse it. For build 7, the signed-in final post-archive Build
   Uploads refresh at `2026-08-29T11:05:38Z` showed build 6 as the highest upload and **Ready to
   Submit**, with build 7 absent. That established availability at the archive checkpoint; the
   completed 10 September upload consumed build 7. Never reuse it.
3. **Regenerate and verify.** Run the locked backend pytest/pip-audit/Bandit/Ruff/mypy suite, full Swift and UI suite,
   public Release configuration tests, request-capture/privacy guards, Release build, and simulator
   artifact preflight. Xcode strips App Attest from simulator signatures, so the signed entitlement
   is checked after archiving. Any config, auth allowlist, or build-number change happens before
   this final run.
4. **Create a signed device archive.** In Xcode select the `Wardrobe` scheme and a generic physical
   iOS device, then choose **Product → Archive**. The archive must pass the strict public Release
   post-build check without bypasses. Before validation or upload, run
   `ios/scripts/verify-release-artifact.sh DerivedData/ReleaseValidation
   "/path/to/Wardrobe.xcarchive/Products/Applications/Wardrobe.app"`; this pass must confirm the
   signed production App Attest entitlement; absence of the shared bearer, Google/GoogleSignIn/
   AppAuth/GTM bundles, Google client identifiers/callback scheme, Gmail permission/host/client
   paths, `/extract` client path, and receipt background-task identifier; and correct public URLs.
   Retain the archive entitlement and embedded-profile inspection as APP-009/APP-036 evidence.

   Current build-7 signed-archive evidence: the `2026-08-29T04:21:50Z` review did not immediately
   precede the archive created at `07:15:57Z`. That technically verified archive is retained as
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-7-0cc0fa7-prearchive-review-stale-nonuploadable.xcarchive`
   and must not be uploaded. The first automatic-signing archive used a development profile and is
   separately retained as invalid/non-uploadable. A fresh full operations/recovery review against
   exact Fly v10, including a fresh private-registry match and zero-High/Critical Docker Scout scan,
   completed at `2026-08-29T11:02:18Z`. Clean synchronized documentation-only successor main
   `0cc0fa7eadac998d32022e3e6a9dba2a62db64c4` then produced
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-7-0cc0fa7-appstore-final-20260829T110218Z.xcarchive`
   at `11:03:10Z`. The final archive uses manual Apple Distribution signing with the existing App
   Store profile. Xcode 26.6 and the iOS 26.5 SDK produced exact `1.0.0 (7)`, `iphoneos`, arm64, and
   minimum iOS 18.0 metadata. At `11:04:02Z`, the strict artifact verifier, production App Attest/
   profile/identity, public configuration, privacy manifest, Gmail-free removed-capability guards,
   separate non-emitting credential scan, deep signature, and matching app/dSYM checks passed. The
   `11:05:38Z` signed-in post-archive Build Uploads refresh showed build 6 highest and **Ready to
   Submit**, with build 7 absent. This paragraph retains archive evidence only. The later
   [10 September distribution](#build-7-distribution--2026-09-10) completed validation/upload,
   processing, internal group assignment and saved/reloaded notes for build 7.

   Historical build-6 archive and distribution evidence: clean synchronized source context
   `de7c540275fb16e61aabf1884538b18cf6edf76f` produced
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-6-de7c540-appstore.xcarchive` at
   `2026-08-22T11:42:24Z`. The strict verifier, deep signature check, matching app/dSYM check,
   production App Attest entitlement/profile, privacy manifest, public configuration, credential
   absence, and Gmail-free removed-capability guards passed. Xcode validated the exact archive and
   uploaded it through **TestFlight & App Store** at `2026-08-23 08:57 SGT`, with symbols enabled,
   automatic version/build management disabled, and **TestFlight Internal Testing Only** disabled.
   Apple processing reached **Ready to Submit**. The processed record shows `1.0.0 (6)`, arm64
   iPhone support, minimum iOS 18.0, included symbols, and no non-exempt encryption. Exactly the
   `Family` Internal Testing group is assigned with one group tester and no individual testers; the
   build-6 What to Test wording reproduced below is saved. Distribution remains distinct from the
   later clean physical proof. The final build-6 deletion/reinstall/new-enrollment handoff is now
   complete. The monitored 25/28 August snapshots were later observed absent from the customer-
   visible list. The 10 September Build-7 pre-deletion snapshot's later disappearance and deletion-
   specific recovery/non-return were not proven and were owner-waived only for the Free Singapore v1.

   Historical build-5 archive evidence: fresh private-registry authentication re-resolved exact
   Gmail-free v6 recovery digest
   `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`, whose
   zero-critical/high scan completed at `2026-08-22T01:00:09Z`. The exact-v8 payload-free review
   passed at `2026-08-22T01:07:45Z`; the final App Store Connect refresh at
   `2026-08-22T01:09:39Z` showed builds 1–4 only. Clean source context
   `695c562b7b18e4a0b7f8a72b814af59efdd0cf3a`, a documentation-only successor to frozen
   shipped-code/backend source `4a75b99dcd49e818ad1d5b198e8c49abba702e18`, produced
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-5-695c562-appstore.xcarchive` at
   `2026-08-22T01:10:32Z`. Xcode 26.6 (`17F113`) and the iOS 26.5 SDK produced exact
   `1.0.0 (5)`, `com.tth.Wardrobe`, `iphoneos`, arm64, minimum iOS 18.0 metadata. Apple
   Distribution profile `Wardrobe App Store App Attest 2026-08-21`
   (`2b11bc90-0194-4fe6-8dcc-413c6dc5ccd2`, expires `2027-08-21T02:07:47Z`) has no device or
   all-device grant, has `get-task-allow = false` and beta reporting active, and matches the App ID
   prefix, team, bundle, and signing certificate. The profile grants production App Attest and the
   signed app carries scalar `production`. The strict verifier completed at
   `2026-08-22T01:11:17Z` with public HTTPS configuration, app privacy manifest, shared-bearer, and
   Gmail-free artifact guards passing. A separate non-emitting scan found no Anthropic/API-key,
   shared-bearer, private-key, Google/Gmail/OAuth, `/extract`, or receipt-import/background marker
   at `2026-08-22T01:12:01Z`; post-scan deep signature verification passed at
   `2026-08-22T01:12:19Z`. The arm64 app/dSYM UUID is
   `DA20FD8D-64C3-3B7A-9990-19EAF050AF04`; executable SHA-256 is
   `a9f01231025874d331e76be40ebe6f493b3f36051902b66b0ad03c35206bb3b9`. At that stage this was
   signed-archive evidence only; the later Organizer validation, upload, processing, and assignment
   evidence is retained above. Physical proof remains open.

   Historical evidence: for build `1.0.0 (4)`, clean source
   `dd3d99061321cf91bdce166e7da579b84edb07e8`
   produced the Apple Distribution archive at `2026-08-21T03:34:13Z` using Xcode 26.6 and the iOS
   26.5 SDK. The signed app carried scalar production App Attest, and the embedded App Store profile
   matched its team, App ID, certificate, and production grant. The strict artifact verifier passed
   public configuration, app privacy manifest, and Gmail-free artifact checks. Subsequent
   shipped Swift/backend changes supersede
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-dd3d990-appstore.xcarchive`; retain it only
   as history and never validate or upload it. A separate earlier automatic-signing archive,
   `Wardrobe-1.0.0-4-dd3d990.xcarchive`, used a development profile and failed verification; it
   also must never be validated or uploaded. Historical uploaded build-4 replacement evidence:
   clean synchronized
   source context `24c17cb9fe643035f9206ee61e2935e086902146` (a documentation-only successor to
   shipped-code merge `d4637f4b2adf14cd533594aec6060c385f8a5e2b`) produced
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive` at
   `2026-08-21T06:36:33Z`. It is arm64, minimum iOS 18.0, Xcode 26.6/iOS SDK 26.5, and signed by
   `Apple Distribution: Tan Tze Hon (29NT767Y9P)` with profile
   `Wardrobe App Store App Attest 2026-08-21` (`2b11bc90-0194-4fe6-8dcc-413c6dc5ccd2`). The signed
   app carries scalar production App Attest; the profile is App Store distribution, grants
   production, and contains the matching certificate. The strict verifier passed HTTPS public
   configuration, app privacy manifest, and Gmail-free artifact guards. A separate targeted scan
   found no Anthropic/API-key, shared-bearer, or private-key credential marker. Separate
   `dwarfdump --uuid` output matched the arm64 app and dSYM at
   `5BA1F06E-7458-32A4-890F-36C8F22D9C13`.
5. **Validate and upload.** In Organizer choose **Validate App**, then **Distribute App →
   TestFlight & App Store → Upload**. Upload symbols and use the intended distribution signing.
6. **Wait for processing.** In App Store Connect review Build Upload status, warnings, privacy
   manifests, entitlements, supported devices, version/build, and export-compliance state. Resolve
   every error before testing.
7. **Distribute internally.** Confirm the processed build belongs only to the chosen Internal
   Testing group and enter truthful **What to Test** notes. Record the group's actual automatic
   distribution setting: the existing `Family` group had **Automatic for Xcode Builds** enabled
   during build-7 distribution. Do not describe that setting as off or assume distribution waits
   for a manual assignment. Physical installation remains subject to the identity-safe handoff.
8. **Run automated regression, then a targeted fresh-install physical delta.** Never install a
   fresh-reset candidate over an older app. The complete matrix remains the release inventory, not
   a manual script to replay in full. Simulator/UI automation owns deterministic first launch and
   Gmail-free UI, offline Demo, manual catalog operations, consent and Settings, Today/History,
   reminder controls, isolated local/server deletion, and offline/relaunch/backend-failure behavior.
   The deterministic process-relaunch journey styles against an isolated fake, terminates and
   relaunches offline, proves the idle **Style a look** state makes no request, restores the cached
   look only after an explicit tap without a request, preserves it through a failed Restyle, and
   reaches Wear/History.

   A processed TestFlight candidate still requires an owner-controlled identity-safe handoff and
   clean installation plus boundaries simulator fakes cannot establish: production App Attest
   enrollment/assertion and a protected API call; signed entitlements/runtime fields; any open live
   deletion, snapshot, or recovery step; real Camera/Photo Library permission surfaces; delivered OS
   notification routing; actual device connectivity behavior; and visual/assistive presentation.
   Always test the candidate-specific delta. Repeat unchanged media, notification, offline, catalog,
   cached-Today, or Wear/History rows only when their shipped source/configuration changed, retained
   physical proof is missing, or the targeted smoke reveals a regression. Confirm no Google/Gmail/
   receipt-import UI or request exists through automated artifact/network guards. On iOS 18–26,
   record signed runtime-field absence without claiming category/build enforcement.
9. **Retire the bridge.** If a legacy compatibility bridge was used, switch the validated backend
   to App-Attest-only mode, unset/rotate `DEVICE_TOKEN`, and prove an old build is rejected while
   the candidate still succeeds. Recovery must use the exact current
   validated Gmail-free App-Attest-only, budget-aware image while preserving the auth store and
   the initialized budget ledger, limits, and charges. The validated image shared by v15 and v16 is the current
   recovery baseline, subject to fresh identity/security and ledger-compatibility checks before use.
   The old v11–v14 image has a Critical AnyIO finding and is ineligible for recovery. No recovery
   or AI switch change is authorized by this record. Pre-budget v10 is
   not a normal rollback target. The former v6 reference's
   current identity is not independently proven and it is ineligible; the former v5 image is a pre-build-4 abort only,
   re-exposes `/extract`, and must halt the release. Rolling back to the shared bearer is never
   acceptable.
10. **Record evidence.** Retain the commit, archive, build/version, Xcode and SDK, test results,
   validation/upload logs, processed-build metadata, backend image/config, exact App ID prefix,
   entitlement/profile, tester OS/runtime-field presence, category/build values when supplied,
   auth-store volume and snapshot/restore evidence, Apple-receipt validation/risk-metric policy,
   APP-036 artifact-absence output, pre-uninstall Google disconnection and local deletion, the exact
   zero-installation/zero-session/zero-pending-challenge production check, clean-install proof,
   bridge retirement, old-build rejection,
   and physical-device QA. Do not claim build/category
   rejection on iOS 18–26, where Apple omits those fields; the pre-App-Attest shared-token build
   must still be rejected.

## Post-upload APP-009 closure

Production App Attest proof is necessarily post-upload; it is not a pre-build gate.

### Build 4 physical QA — 2026-08-21 (historical, PARTIAL)

This aggregate-only record describes processed TestFlight build `1.0.0 (4)`. It does not satisfy
the build-5 release gate and retains no device identifier, App Attest identifier, credential,
request body, database row, wardrobe payload, or raw log sample.

| Boundary | Redacted result |
|---|---|
| Installation | Clean TestFlight install on iPhone 16 Pro running iOS 26.6; production aggregate baseline was zero installations, then one installation after enrollment |
| App Attest / protected API | First production assertion and protected calls succeeded; a cold-app assertion/session renewal also succeeded |
| Offline behavior | Remote styling failed closed with a friendly offline message while Wardrobe, History, and Demo Mode remained usable |
| Today cache / release defect | The cached look survived an offline relaunch, but tapping **Restyle** while offline replaced the usable look with the error state. The look returned only after another relaunch and a tap. Build 4 is not promotable; clean build 5 later verified the fix |
| Online recovery | Styling recovered online and showed `Styled 17:24`; aggregate assertion total advanced from 1 to 2 and the current recommendation-installation rate window from 0 to 1 |
| Signed runtime fields | Validation category/build fields were absent, as expected on iOS 26.6; this is not category/build-enforcement evidence |
| Local flows | Manual add/edit, Demo Mode, **Wear this**, and History passed. Camera and Photo Library opened and cancelled only; successful media selection remains untested. Reminder permission and scheduling passed; delivery remains untested |
| Production marker stream | The build-4 bounded stream had no `registration_succeeded` or `assertion_succeeded` matches because live v7 suppressed INFO lifecycle events at the time. Fly v8 later emitted the bounded build-4 deletion and clean build-5 registration/assertion evidence without payloads or identifiers |
| Snapshot / deletion boundary | The initially listed snapshot predated enrollment. A later successful post-enrollment snapshot at `2026-08-22T07:33:23Z` cleared the recovery gate, after which server and local deletion completed safely |

### Build 5 physical QA — 2026-08-22 (historical, BLOCKED)

Clean build `1.0.0 (5)` passed Gmail-free launch/onboarding, empty wardrobe, offline Demo and local
tabs, successful Camera/Photo Library saves, the catalog matrix, production enrollment and cold
renewal, initial styling/Restyle, Today offline-cache and failed-Restyle preservation, and offline
Wear/History. Production markers and aggregates corroborated the connected operations without
retaining payloads or identifiers. Tapping a delivered reminder at `17:15:14 SGT` then caused
`EXC_CRASH`/`SIGABRT`. The executable exactly matches the retained build-5 dSYM; safe symbolication
reaches the generated async bridge for
`DailyReminderNotificationRouter.userNotificationCenter(_:didReceive:)` as UIKit updated state
restoration. Build 5 is consumed and non-promotable. Do not repeat the tap.

### Build 6 physical QA — 2026-08-24–28 (current, PARTIAL)

This aggregate-only record describes clean processed TestFlight build `1.0.0 (6)`. Build 6 first
appeared installed in place unexpectedly, so that installation was not counted as clean QA. After
an eligible post-build-5-enrollment snapshot was confirmed, the inherited server identity was
deleted with aggregate confirmation, local data and the app were deleted, and build 6 was installed
cleanly. This is not upgrade or migration evidence.

| Boundary | Redacted result |
|---|---|
| Launch / Gmail-free | **Your wardrobe, your way** led to an empty local wardrobe with no account, Google, Gmail, or receipt-import path |
| Offline local flows | Offline Demo, Camera and Photo Library saves, and the disposable catalog add/edit/search/filter/sort/delete matrix passed |
| Production App Attest | Style at `20:25 SGT` registered one anonymous installation; after session expiry, Style at `20:45 SGT` renewed with an assertion and a fresh challenge. Expected runtime build/category fields remained absent on iOS 26.6 |
| Today cache / failure | After an offline process relaunch, Today initially showed **Style a look**; one explicit tap restored the cached `20:25` look without a backend call. Failed offline Restyle showed **Couldn't refresh this look** while the cached look remained visible |
| Wear / History | Offline **Wear this** and History passed and persisted across the notification route |
| Reminder fix | The local reminder delivered at `20:53 SGT`; tapping it opened Today without crashing. The explicit **Style a look** action restored the cached `20:45` look, and Wardrobe/History state remained intact |
| Final deletion / uninstall | The `2026-08-25T07:35:53Z` automatic snapshot was `created` with 14-day retention and postdated enrollment. The pre-deletion aggregate was `1/0/0`; assertion-verified deletion emitted exactly one bounded success marker and returned it to `0/0/0`, which persisted after local deletion and uninstall |
| Clean reinstall / new identity | Clean reinstall, launch, two local wardrobe additions, and styling-consent grant left the backend at `0/0/0`. Explicit **Style a look** at `2026-08-28 17:17 SGT` created one active installation and one active session, zero pending and zero failed challenges, one completed challenge, and exactly one registration-success marker. Runtime category/build fields remained absent as expected on iOS 26.6 |
| Remaining lifecycle boundary | The monitored 25/28 August snapshots were observed absent. The 10 September Build-7 pre-deletion snapshot's later disappearance and deletion-specific recovery/non-return were not proven; the owner waived only this evidence sub-gate for Free Singapore v1 on 2026-09-11 and accepted the residual risk |

The intermediate idle state before explicit cache restoration matches the no-network-call-on-tab-
appearance design. A deterministic DEBUG-only process-relaunch XCUITest now pins that exact
explicit-action sequence and its request count with fictional data and an isolated fake network; it
does not substitute for production App Attest or other physical-device boundaries. Separately, the
2026-08-28 owner-supplied Dark Mode screenshot confirms
that build 6's **Allow AI styling** title is approximately 21 points right of the button center and
that the sampled `#C2DFFC` fill against the white title is approximately `1.38:1`. Build 6 therefore
fails the visual presentation gate and is non-promotable; this does not invalidate its completed
identity or notification evidence.

- [x] Retain historical build-4 signed production App Attest entitlement, matching embedded App
  Store profile and certificate, and strict artifact-verifier result. The verified uploaded archive
  is `Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`; historical `dd3d990` archives are superseded and
  cannot satisfy any later upload or processed-build gate.
- [x] Retain build-4 identity-safe recovery: eligible snapshot, assertion-verified server deletion,
  zero installation/session/challenge aggregates, local deletion, app removal, and subsequent clean
  build-5 install. This is not upgrade/migration proof.
- [x] Retain the clean build-5 production enrollment, cold assertion, protected styling, bounded
  markers, media/catalog, Today regression, and reminder-crash evidence above.
- [x] Confirm the replacement build number through fresh live App Store Connect inspection. At
  `2026-08-22T10:02:31Z`, builds 1–5 were the only uploads, build 5 was **Complete**, and build 6
  was absent. Build 6 is confirmed unused and selected; `MARKETING_VERSION` stays `1.0.0`.
- [x] Finish review/merge and the entire replacement build/archive/upload/processing/assignment
  loop. PR #27, merged-source verification, Fly v9, the strict build-6 archive, Xcode validation/
  upload, Apple processing, `Family` assignment, and saved tester notes are retained above.
- [x] Complete build 5's identity-safe handoff: after the eligible
  `2026-08-23T07:34:23Z` snapshot, disable its reminder, withdraw styling permission, delete its live
  server security record with aggregate confirmation, delete local data, remove the app, and install
  build 6 cleanly. Build 6 appearing in place before this sequence was not counted as QA.
- [x] Repeat the fresh-install matrix in clean build 6 through delivered-reminder tap. Launch,
  offline/local media and catalog flows, production enrollment/assertion renewal, Today cache and
  failure preservation, Wear/History, reminder delivery, tap routing, and local-state preservation
  passed as recorded above.
- [x] Complete the final build-6 handoff in owner-controlled order. The eligible
  `2026-08-25T07:35:53Z` snapshot reported `created` with 14-day retention; the `1/0/0` baseline,
  exactly one deletion-success marker, post-delete/uninstall `0/0/0`, clean-reinstall local-only
  `0/0/0`, and explicit `2026-08-28 17:17 SGT` Style enrollment evidence are retained above. The
  new identity has one active installation and one active session, zero pending/failed challenges, one
  completed challenge, one registration-success marker, and expected iOS 26.6 runtime-field
  absence. No identifier, payload, credential, or raw log sample is retained.
- [x] Record the owner-approved snapshot/recovery evidence waiver for Free Singapore v1. On
  2026-09-11 the monitored 25/28 August snapshots were observed absent, while the 10 September
  Build-7 pre-deletion snapshot remained listed. The owner accepted its unproved later listing
  disappearance, all-copy purge and deleted-identity recovery risk and stopped the scheduled wait.
  This marks the waiver decision,
  not the missing evidence as passed; other APP-009/APP-036 work remains open.
- [x] Confirm that build 6 fails the **Allow AI styling** presentation gate. The 2026-08-28 owner-
  supplied Dark Mode screenshot places the title approximately 21 points right of center and
  measures the sampled `#C2DFFC` fill against white at approximately `1.38:1`. Build 6 is consumed,
  non-promotable, and must never be reused.
- [x] Complete and verify the replacement control implementation. PR #31 rebase-merged app commit
  `b7e46e4` to clean `main` `e4a0ae2`. The title-only control is centered, full-width, and opaque;
  focused coverage pins enabled, pressed, and disabled contrast plus the screenshot UI assertion.
  Merged verification passed 221 backend tests plus audit/Bandit/Ruff/mypy, 226 Swift unit tests,
  all 9 UI tests, and 43 release-script tests; both GitHub iOS checks are green.
- [x] Select and source-prepare build 7 without claiming deployment. The signed-in TestFlight
  **Build Uploads** view on 2026-08-29 showed build 6 as the highest upload and **Complete**, with
  build 7 absent. Select `1.0.0 (7)`, keep `MARKETING_VERSION = 1.0.0`, and prepare source
  configuration with `CURRENT_PROJECT_VERSION = 7` and accepted builds `4,5,6,7`. At selection time,
  live Fly v9 still accepted `4,5,6`; the completed v10 deployment is recorded separately below.
- [x] Remediate the build-7 runtime scan before publication or deployment. The first local
  Linux/AMD64 candidate scan found seven High-severity OpenSSL findings in the prior pinned runtime,
  so no image was pushed or deployed. Commit `6186018` refreshes the digest-pinned official runtime
  and its two crypto libraries. The rebuilt image reports zero High/Critical Docker Scout findings
  and passes the non-root, no-new-privileges, logging, SQLite, and mounted-volume smoke gates. Full
  verification passed 222 backend tests plus audit/Bandit/Ruff/mypy, 226 Swift unit tests, all 9 UI
  tests, 43 release-script tests, and the clean `1.0.0 (7)` Release simulator artifact check. This is
  local source/image evidence only; deployment evidence is recorded separately below.
- [x] Deploy and review only the selected build-7 backend candidate. PR #34 rebase-merged the
  runtime remediation to clean main `162688ae72d07f06a7a8116249632aa0101e538f`. The exact merged
  Linux/AMD64 image passed local and immutable-registry zero-High/Critical scans plus non-root,
  no-new-privileges, logging, SQLite, and mounted-volume smoke gates. It deployed as completed Fly
  v10 at `2026-08-29T01:52:47Z`; release and Machine image references match privately. One healthy
  Singapore Machine runs the expected production App-Attest-only configuration with accepted builds
  `4,5,6,7`, validation category `2`, schema-v4 auth-store integrity, zero foreign-key failures,
  low-band encrypted-volume use, and safe aggregate `1/0/0`. `/health`, Gmail-free route absence,
  fail-closed unauthenticated styling, and the exact reviewed route set pass. The newest automatic
  snapshot remains `2026-08-28T07:37:13Z`, status `created`, retention 14 days. The payload-free
  review passed at `2026-08-29T02:21:41Z`: the official two-day Fly metric has only `2xx`/`4xx`
  classes and no `5xx`; the bounded log buffer has no application `5xx`, auth/App Attest,
  Anthropic, or rate-limit failure class; Anthropic public status, configured monthly limit,
  below-80%-spend band, expected active Wardrobe Opus 4.8 use, historical-key inactivity, and no
  saturation pass; and the public Gmail-free support/privacy/Terms pages, contact route, response
  target, and reciprocal links pass anonymously. No raw provider identifier, metric value, billing
  amount, key, log, response body, or screenshot is retained.
- [x] Complete the build-7 exact-source regression. Post-merge regression on clean
  synchronized main `f183f074d1a63a4ec46d6d34fa13979a2c8b1fdd` passed 222 backend tests plus
  audit/Bandit/Ruff/mypy, 226 Swift unit tests, all 9 UI tests, 43 release-script tests, and the
  Release simulator/artifact gates. This documentation-only recovery correction does not change the
  verified iOS, backend, or shared source.
- [x] Create and strictly verify the build-7 archive. The `04:21:50Z` review and `07:15:57Z`
  technically verified archive are retained as timing-stale/non-uploadable evidence; the earlier
  automatic-signing archive is development-signed and separately invalid/non-uploadable. The fresh
  full operations/recovery review against exact Fly v10 completed at `2026-08-29T11:02:18Z`,
  including a fresh private-registry match and zero-High/Critical Docker Scout scan. Clean
  synchronized main `0cc0fa7` then produced the distinct final archive at `11:03:10Z`; strict Apple
  Distribution, production App Attest/profile/identity, public-configuration, privacy, Gmail-free,
  non-emitting credential, deep-signature, and matching arm64 app/dSYM verification passed at
  `11:04:02Z`. The signed-in `11:05:38Z` post-archive Build Uploads refresh showed build 6 highest
  and **Ready to Submit**, with build 7 absent.
- [x] Automate the repeatable read-only portion of the fresh operational review. The locked
  production contract, redacted owner-triggered helper, and focused fail-closed tests
  cover exact source/archive/runtime/configuration, auth-store/volume/snapshot state, public
  endpoints, Claude public status, and exact recovery-image identity/security scanning. The helper
  fails closed on incomplete evidence and deliberately leaves the official Fly metric, signed-in
  Anthropic console, signed-in Build Uploads view, and separate owner upload approval as live gates.
  This release-operations tooling/test/documentation change does not alter the preserved build-7
  archive or shipped iOS/backend behavior and does not require build 8.
- [x] Validate and distribute only the exact verified build-7 archive. After the beta-only review
  and explicit owner approval, normal-route validation/upload completed on 10 September. Apple
  processing and the existing automatic `Family` assignment were verified, with one group tester
  and no individual testers; the approved AI-disabled notes persisted after reload. See the
  [distribution checkpoint](#build-7-distribution--2026-09-10). Build 7 is consumed.
- [x] Complete the build-7 local-beta verification using the
  [11 September physical evidence](#build-7-physical-checkpoint--2026-09-11-partial) and
  [automation ownership](#qa-automation-ownership--2026-09-11). Handoff and clean first launch
  passed; the device screenshot covers normal-state centering/legibility and automated tests own
  enabled/pressed/disabled contrast. The new disk-persistence regression and full suite passed.
  Reuse unchanged media/notification evidence and the brief local/Demo observations; no routine
  catalog or button-state phone checklist remains. The separately approved bounded v16 pilot
  is enabled; its one protected-device verification call passed on 12 September.
- [x] **Legacy Google project shutdowns:** the owner explicitly requested deletion on 19 September.
  Both inventoried Wardrobe projects were shut down; see the
  [retirement evidence](../gcp-retirement-20260919.md). Final provider deletion remains pending after
  the recovery period. This was not a public-v1 submission gate and does not change the verified
  Gmail-free candidate. Unrelated Google Cloud and Search Console resources were untouched.

## Promoting an internally tested build

Build 4 is not promotable because of the Today offline-cache defect, and build 5 is not promotable
because of the delivered-reminder tap crash. Build 6 passed the affected identity and notification
routes but is non-promotable because it failed the styling-consent control presentation gate. The
replacement `1.0.0 (7)` has completed distribution, owner-controlled handoff and clean first
launch with AI disabled. The normal-state device screenshot passed; automation owns the remaining
deterministic regression. Bounded activation is complete; protected-device styling proof passed on 12 September; public-release work remains open. When that candidate
is fully approved for public release, do not rebuild unless something changed:

- Retain completed `APP-016` privacy evidence. Finish `APP-017`/`APP-018`, agreements, screenshots, review
  contact, and review notes. Verify App Store Connect shows price **Free**, only **Singapore**
  enabled, and no in-app purchase/subscription offered with version 1.0. Google restricted-scope
  verification/CASA is not a public-v1 gate.
- Approve and verify the private Singapore-launch AI spend envelope, hard global capacity ceiling,
  bounded request/token/retry exposure, alert/disable response, and public multi-user operations
  cadence. Use the already accepted model/evaluation and approved budget policy; verify their current
  SDK/model/API configuration. Repeat model selection only if a concrete change invalidates
  that evidence, not as a new bakeoff on every submission. Never describe the
  current hourly abuse limit or a provider console warning as a proven monthly monetary circuit
  breaker.
- Select the already-tested build on the matching App Store version.
- Re-check the binary, live backend and auth store, App Attest compatibility policy plus iOS 27+
  build/category allowlist, public URLs, Gmail-free archive evidence, disclosures, and metadata
  against the retained evidence.
- Choose **Add for Review**, inspect the complete submission, then **Submit for Review**.

If the shipped iOS sources/resources/configuration, bundled disclosure, version metadata or
client-required API contract changes, use the next unused build and repeat the applicable
distribution checks. Never patch an uploaded binary in place. Backward-compatible backend-only
changes require their operations review, not an automatic new iOS build. Documentation and
App Store Connect-only price/territory choices do not require a new binary.
Future Plan & Usage UI, StoreKit, entitlement, metering, quota-response, or other user-visible
freemium behavior does require the next unused build and the full loop.

## Saved truthful What to Test wording for build 4

> Verify the new Wardrobe Stylist icon, add an item with both Camera and Photo Library, and confirm
> each picker remains open until completion or cancellation. Review the simplified Settings hub
> and its Connected Features, Wardrobe & Demo, Privacy & Data, and Help & Support destinations.
> Install build 4 only as a clean processed-TestFlight install; the earlier development app was
> already disconnected, locally cleared, and uninstalled after production was verified to contain
> zero installations, zero sessions, and zero pending challenges. Exercise manual/photo cataloging,
> styling/history, reminders, styling-consent withdrawal, verified local deletion, and separate
> server-security deletion. On a clean physical install, confirm there is no Google/Gmail or login
> path, secure installation verification completes anonymously, and local/demo features remain
> usable during an offline backend failure.

Saved on processed build `1.0.0 (4)` for its intended Internal Testing group on 2026-08-21.

## Saved truthful What to Test wording for build 5

> Build 5 is a clean-install replacement for build 4. Do not install it until the owner confirms build 4’s identity-safe handoff is complete, and never install it over build 4.
>
> After approval, test launch/icon, onboarding, manual catalog/photo/camera flows, editing/deletion, Demo Mode, styling consent/withdrawal, Today/Wear/History, and reminder delivery. Today regression: style online, relaunch offline, tap Restyle; the cached look must stay visible with a friendly failure, then recover after reconnecting. Wardrobe, History, and Demo Mode must remain usable while remote styling is unavailable. Confirm there is no Google, Gmail, login, receipt-import, or /extract path.
>
> Do not perform local/server deletion or reinstall until the runbook clears those stages.

Saved on processed build `1.0.0 (5)` for the `Family` Internal Testing group by
`2026-08-22T03:24:21Z`. This preserves the truthful pre-install instruction shown at assignment.
The later recovered handoff and clean build-5 QA are recorded above; the reminder-tap crash now
makes build 5 non-promotable.

## Saved truthful What to Test wording for build 6

> Build 6 is a clean-install replacement for build 5 and fixes the crash when tapping a delivered reminder. Keep build 5 installed until the owner confirms its identity-safe handoff is complete; do not install or update build 6 over build 5.
>
> After approval and a clean install, test launch/icon, onboarding, manual catalog/photo/camera flows, editing/deletion, Demo Mode, styling consent/withdrawal, Today/Wear/History, and reminder delivery. Tap the delivered reminder: it must open Wardrobe Stylist on Today without crashing, and existing local state must remain intact. Today regression: style online, relaunch offline, tap Restyle; the cached look must remain visible with a friendly failure, then recover after reconnecting. Wardrobe, History, and Demo Mode must remain usable while remote styling is unavailable. Confirm there is no Google, Gmail, login, receipt-import, or /extract path.
>
> Do not perform local/server deletion, uninstall, or reinstall until the runbook clears those stages.

Saved and reload-verified on processed build `1.0.0 (6)` for the `Family` Internal Testing group on
2026-08-23. The build has one group tester and no individual tester assignments. This preserves the
pre-install identity-safe handoff instruction; the later clean physical evidence is recorded above
and does not rewrite the historically saved note.

## Saved truthful What to Test wording for build 7

Historical 10 September notes, superseded by the saved/reloaded enabled-pilot notes in the
[12 September activation checkpoint](#bounded-ai-pilot-activation--2026-09-12). The handoff
instructions below applied before the completed 11 September clean installation.

> Wardrobe 1.0.0 (7) — internal beta
>
> AI styling is intentionally unavailable in this beta. Style a look and Restyle may show temporary
> unavailability; the local wardrobe and Demo Mode remain usable.
>
> Please check the updated Allow AI styling control in Dark Mode for centered, readable text. Also
> check manual/photo item entry, catalog editing and browsing, offline Demo Mode, wear history and
> local reminders. Report the steps and what you expected if a problem occurs.
>
> Follow the agreed installation handoff before replacing an existing Wardrobe installation. These
> notes do not authorize deleting local or server data.

Saved and reload-verified at `2026-09-10T11:51:22Z` for processed build `1.0.0 (7)`, assigned only
to `Family` Internal Testing with one group tester and no individual testers. The existing
**Automatic for Xcode Builds** setting was preserved; distribution was not held for manual assignment.
Keep the existing installation until the owner confirms its identity-safe handoff is complete.
Do not install/update build 7 over it or perform local/server deletion, uninstall or reinstall
without the owner's direction for the applicable runbook stage. Production styling/App Attest
success proof belongs to the separately approved AI activation; these beta notes request no paid
styling call.

## Official Apple references

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
- [View builds and upload status](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata)
- [Establishing your app's integrity with App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Validating App Attest at your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Preparing App Attest environments and rollout](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)


## Privacy publication — 2026-09-12

The owner approved publication of the reviewed policy update and Apple privacy answers. Website
[PR #6](https://github.com/tzehon/tzehon.github.io/pull/6) received a clear current-head Codex review,
merged and deployed successfully. Anonymous and rendered-page verification confirmed the
12 September effective date, provider retention/exceptions, separate aggregate ledger and limited
individual deletion scope. App Store Connect now has the policy URL and exactly four categories:
Other User Content, Device ID, Product Interaction and Other Diagnostic Data. All are linked and
not tracking; all use App Functionality, and Other User Content additionally uses Product
Personalization. Publication and reload retained these answers. The app version is still Prepare
for Submission; no app review submission, build upload, paid call or AI enablement occurred.

The [review and exact publication evidence](ai-pilot-privacy-review-20260912.md) retain source/PR/
deployment identifiers and the decision to keep build 7 and consent notice version 3. These are
documentation/store-metadata changes and require no new TestFlight build. Next: existing disabled
budget/operations review, then a bounded separately approved activation and protected-call check.
