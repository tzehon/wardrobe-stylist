# Fly hosting spend controls

Status: the owner approved the billing-reviewed hosting policy and finite setup phase on
8 September 2026. Fly v12 applies the private AI policy and provider key with AI disabled;
independent post-deployment review passed at `2026-09-08T09:32:49Z`. The unchanged image reads
the intact existing ledger after restart on the original Machine/volume, without resource growth.
No Fly spending monitor, service hold or Fly credit purchase has been performed. The private
hosting envelope is separate from the Anthropic ledger, which does not account for Fly charges.
The dedicated AI-provider workspace and its monthly cap/email settings are now saved and verified;
one approved provider-credit purchase is paid with sufficient usable balance and auto-reload off.
The workspace-scoped key was transferred through hidden owner input and deployed without local
secret persistence; rotation is required before its 8 October 2026 expiry. These are separate from
Fly billing. The finite disabled setup is verified.
Provider alert delivery, Fly monitoring implementation/delivery, billing-feed reconciliation and
AI enablement remain open. The ordinary budget diagnostic needs an ownership-context correction;
its independent configured probe passed. No hard invoice cap or automatic hold is active.
See the [approved disabled setup checkpoint](app-store/internal-testflight-runbook.md#approved-disabled-budget-setup--2026-09-08).

## Resource baseline and cost exposure

The read-only inventory at `2026-09-07T23:30:46Z` found one started Singapore Machine with
one shared CPU and 512 MB RAM, one 1 GB volume with 14-day snapshot retention, and shared IPv4
plus IPv6. The same billing organization's app list contains only this app and no builder app.
The signed-in billing review on 8 September, beginning at `2026-09-07T23:44Z`, reconciled the
September invoice preview with Cost Explorer across CPU, additional RAM, volumes, snapshots and
egress. The organization shows no linked organizations, active support package, Managed Postgres
clusters or Upstash Redis databases. Exact charges and account identifiers remain private.
Tigris inventory required accepting its terms, so that inventory was not read and no terms were
accepted. No Tigris or other add-on charge appeared in the reviewed current-period product list;
this does not rule out unreported usage or later adjustments.

The previous month's service charges were waived on the paid invoice. Do not assume future
waivers or use the net amount due as the consumption measure: compare pre-tax service charges
before discretionary waivers or prepaid/promotional credits with the approved private thresholds, and
show adjustments and payable amounts separately. Retain applicable published resource allowances
only while their actual availability is verified. Displayed line items are rounded; use the
provider's subtotal rather than summing rounded lines.

The current preview is not a full-month forecast. The reviewed billing views show no usage
coverage cutoff or refresh-lag guarantee. No tax line was shown; future tax treatment is unverified.
The later pre-deployment refresh at approximately 09:25–09:29 UTC showed a higher invoice-preview
total than Cost Explorer across the same five products. Private planning uses the higher preview;
the difference is not attributed to lag without evidence, and the feeds are not reconciled.
Fresh resource/service inventory found no expansion or new paid product. The unchanged-resource
planning scenario remained below the approved warning threshold; it is not a liability ceiling.
The post-deployment inventory again passed with no extra billable resources, and the refreshed
invoice preview was unchanged. The Cost Explorer divergence remains unresolved.
Billing-feed freshness, final adjustments and monitoring readiness remain open. The current
resource scenario below remains the planning estimate; do not extrapolate a rounded daily
average into a promised maximum bill.

The current configuration keeps at least one Machine running. Budget for continuous operation;
do not rely on autostop savings. Fly's Singapore price selected on 8 September is approximately
US$4.05 for 30 days of the current Machine. A 1 GB provisioned volume adds US$0.15; Asia-Pacific
internet egress is US$0.04/GB. One GB of egress and available snapshot allowance produce an
illustrative US$4.24 for 30 days, or about US$4.38 for 31 days, before tax. These are estimates,
not maximum bills. [Resource prices](https://fly.io/docs/about/pricing/).

Snapshots are incremental stored data. Their retained size and available organization allowance
must be checked; 14-day retention is not proof of fourteen full copies or a snapshot-cost cap.
Volumes and snapshots continue billing when a Machine stops, and stopped root filesystems also
incur storage charges. [Billing mechanics](https://fly.io/docs/about/billing/).

Fly's current cost-management documentation says billing alerts are unsupported and allowances
do not cap overages. No native enforceable monetary cap has been verified. Prepaid credit,
the AI switch, request throttles and the observed installation/session profile are not substitutes.
Public health, malformed and rejected requests can still create traffic. A strict total invoice
guarantee is therefore an unresolved requirement, not a property of this plan.
[Fly cost management](https://fly.io/docs/about/cost-management/).

## Approved policy and remaining controls before AI enablement

- Freeze the resource envelope at the existing one Machine, size, region and one 1 GB volume.
  Require a separately costed approval for additional resources, resizing, volume auto-extension,
  new regions, paid IPs, support plans, reservations, extensions or remote builders. Keep the
  approved automatic 14-day snapshot policy; do not delete or shorten recovery evidence to save cost.
- Deploy the already-built immutable image with the reviewed no-HA, update-only and no-new-IP
  procedure. Inventory the whole billing organization before and after changes, including stopped
  Machines, detached volumes, builders and managed services outside the app list.
- Retain the monthly hosting target, early warning, service-hold threshold and traffic triggers
  in an ignored private policy. Compare both accrued charges and a conservative month-end forecast,
  with headroom for delayed billing, taxes and retained storage. Show Fly and Anthropic separately.
- Prepare hourly resource/egress monitoring and daily invoice reconciliation using the existing
  tools; no monitor has been installed. Verify the data source, refresh lag, missed-run reporting
  and notification delivery before relying on it. Missing data is an open gate, never zero spend.
  If the monitoring host is unavailable, automated detection cannot be promised.
- Stop expansion at warnings and investigate unexpected resources or traffic immediately. A
  crossed private service-hold threshold requires the owner-controlled hold below. The planned
  monitor is read-only and cannot stop production by itself; hold execution needs explicit approval.
- Before enabling AI, obtain owner acceptance of the remaining variable-cost exposure. If an
  absolute invoice cap is required, keep enablement blocked until an enforceable provider/control
  option is separately reviewed. Do not describe this monitored budget as a hard cap.

## Reversible service hold

Prepare and review the exact current Machine configuration first. Freeze deployments and restart/
scaling automation. Preserve the same image, CPU/RAM, volume mounts, auth settings and private
ledger. Set every service's autostart to false and minimum running count to zero; set Machine
restart policy to no. Apply the change without starting the Machine, then stop it if still running
and independently verify the stopped state and disabled restart/autostart settings. A bare stop
or `AI_STYLING_ENABLED=false` is insufficient to contain hosting compute/traffic exposure.

This is a procedure for a separately approved interruption, not authority to stop production.
Preserve all volumes, snapshots, charges and pending reservations. Stopping the local process does
not settle uncertain provider work. Retained storage and unrelated organization charges continue;
the hold does not make the bill zero. Restoration requires explicit approval, the same compatible
budget-aware image and storage, initially disabled AI, fresh verification and a deliberate update
of the live configuration evidence. An ordinary deployment from the current `fly.toml` would
restore autostart/minimum-one settings, so it must not bypass the hold.

The README, bound setup proposal and release backlog must report actual activation and unresolved
gates. Policy approval does not activate a monitor or authorize an automatic hold. The backend-only
setup and documentation do not require a new TestFlight build.
