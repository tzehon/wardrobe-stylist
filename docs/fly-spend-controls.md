# Fly hosting spend controls

Current approach, refreshed 12 September 2026: use the existing fixed resources and owner-run daily review
for the small pilot. The unshipped hourly GitHub/Healthchecks prototype is deferred and preserved
privately. No new monitoring account, token, schedule, service hold or Fly credit purchase has been
performed. Follow [the release plan](release-plan.md) for which checks apply to beta, AI activation
and public submission.

## Existing safeguards

The 12 September activation inventory retained one Singapore shared-CPU Machine with 512 MB RAM,
one encrypted 1 GB volume with automatic 14-day snapshots, shared IPv4 and IPv6. The selected
organization contained the original app and no builder app. This is dated evidence, not a current
billing guarantee; refresh it for release/configuration decisions.

Keep that envelope. Review cost before adding/resizing resources, extending volumes, adding
regions, paid IPs, builders, support packages or managed services. Do not delete or shorten required
snapshots to make a cost estimate look smaller. Keep current recovery data and approved limits.

The separate AI ledger bounds the reviewed app's provider calls; it does not pay for or meter Fly.
Fly v16 retains AI enabled under the separately approved bounded pilot, with the exact existing
private policy and intact ledger; only the provider key changed on 29 September. The production workspace limit/email settings,
sufficient existing credits and auto-reload off were freshly verified. Do not repeat provisioning, key staging or credit purchases to
reproduce those earlier setup steps. The [29 September key rotation](app-store/key-rotation-20260929.md) is complete; rotate the
replacement before its 30 November 2026 expiry. See [AI spend controls](ai-spend-controls.md).

The owner accepted the residual Fly invoice exposure in the 12 September activation package.
The refreshed invoice and elapsed-period Cost Explorer differed slightly; no exact usage cutoff
or final adjustment coverage was established. All five visible billed categories were expected,
and observed amounts were below the private warning threshold. Keep that uncertainty and the
daily review; the operating target is still not a monetary cap. No hosting expansion or service
hold occurred. The next daily review is due 13 September, sooner after any problem or change.

## Daily pilot review

The owner reviews these once daily during the pilot and again after configuration changes,
unexpected failures or unusual traffic:

1. **AI ledger and provider account.** Check the existing budget bands, outstanding/uncertain
   work and workspace spend. Preserve the already approved private amounts. Investigate the
   warning band promptly and respond immediately to critical or uncertain accounting.
2. **Fly charges.** Read both invoice preview and Cost Explorer for the same billing period.
   Compare pre-tax service consumption, before discretionary waivers and credit offsets, with
   the existing private warning/hold thresholds. Show credits, taxes and net payable separately.
   Keep discrepancies and missing usage cutoffs explicit; do not assume a lower rounded total
   is more current. A previous waived invoice does not promise future free service.
3. **Resources and response.** Check the organization's apps/resources and native billing product
   list for growth or unfamiliar charges, including stopped Machines, detached volumes and
   services outside the app list. Freeze expansion at a warning. Investigate rapid growth and
   prepare the reviewed service hold when its threshold is reached.

Record the date, aggregate status, unresolved discrepancy, action and next review. Keep exact
amounts and account/resource identifiers in the existing ignored private records. Do not create
another reporting system merely to store those few fields. Native provider emails are useful
supplements; they do not replace the owner's review or require a new monitoring vendor.

If the owner cannot perform the checks, pause the enabled pilot under the approved disable
response or arrange a separately reviewed operating alternative. Even an automated alert cannot guarantee reaction before charges accrue.

## Limits of this protection

Fly's cost-management documentation does not offer an enforceable account spending cap or native
billing alerts. The resource envelope reduces predictable exposure; it does not bound traffic,
delayed adjustments, tax or all other account products. Ten expected users do not limit requests
to a public endpoint. Stopped Machines can retain storage charges, and volumes/snapshots continue
billing. A monthly operating target is not a maximum invoice.
[Cost management](https://fly.io/docs/about/cost-management/),
[billing mechanics](https://fly.io/docs/about/billing/),
[resource pricing](https://fly.io/docs/about/pricing/).

The September 9 billing views disagreed and did not provide a verified usage cutoff. The live
resource probe passed; VM counters were fresh, but edge counters were stale/intermittent. Those
unknowns remain recorded. The completed local-first beta distribution and bounded v15 pilot
do not require a custom collector. The 12 September activation approval accepted the residual
Fly exposure and manual response plan. If an absolute bill ceiling is essential, it requires a different
verified control; do not represent this plan as one.

## Local evidence checker

`backend/verify_fly_spend.py` remains available for assessing explicitly supplied private policy,
resource and billing records. It does not collect live bills, send alerts, forecast a maximum or
execute a hold. Its policy digest establishes content consistency, not approval/authenticity.

It validates each billing view independently after shared metadata passes, preserving a valid
warning or hold signal even if its peer is missing or malformed. Unknown coverage and inconsistent
amounts remain OPEN. `HOLD_REQUIRED` is an owner-action signal, not shutdown permission.
The tool is optional assistance to the manual review; do not fabricate inputs to obtain a PASS.

## External runner proposal

Deferred on 10 September at the owner's request to reset and simplify. The prepared hourly
resource/traffic collector, tests and inactive workflow were removed from the active checkout
only after their exact patch and evidence were preserved in ignored private storage. No account,
credential delegation, schedule or heartbeat was activated.

Reconsider automation after the small pilot has demonstrated a need. Any future design must state
its actual coverage, credential scope, cost, notification recipient, missed-run behavior and
proven delivery. Stale or absent edge samples must never be silently interpreted as zero. A new
vendor or complete metric-history requirement is not automatically a blocker for every release.

## Reversible service hold

This is a response procedure, not permission to interrupt production. Review the exact current
Machine configuration and obtain approval for the concrete hold when required.

Freeze deploy/restart/scaling automation. Preserve the same image, CPU/RAM, volume mounts, auth
settings and budget ledger. Disable service autostart, set minimum running count to zero and
Machine restart policy to no; apply without starting the Machine, then stop it if needed and
independently verify stopped state and disabled restart/autostart. A bare stop can be undone by
automatic starts. Disabling AI alone does not stop hosting charges.

Preserve all volumes, snapshots and pending/uncertain charges. A stopped process does not prove a
provider call was cancelled or its cost settled. Retained storage and unrelated organization
charges continue. Recovery keeps the same ledger and reviewed budget-aware image; never reset
storage or roll back to the pre-budget runtime to regain availability.
