# Fly hosting spend controls

Status: proposed on 8 September 2026 at the owner's request. No Fly spending monitor,
configuration change, shutdown, purchase or deployment was performed for this preparation.
The private setup proposal now includes an independent hosting budget. The Anthropic ledger
does not account for Fly charges, and neither proposal is approved for execution yet.

## Resource baseline and cost exposure

The read-only inventory at `2026-09-07T23:30:46Z` found one started Singapore Machine with
one shared CPU and 512 MB RAM, one 1 GB volume with 14-day snapshot retention, and shared IPv4
plus IPv6. The same billing organization's app list contains only this app and no builder app.
This inventory does not prove the absence of paid support, extensions, linked-organization
charges, historical build usage or other invoice adjustments; signed-in billing reconciliation
remains required before accepting the total hosting forecast.

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

## Proposed controls before AI enablement

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
  crossed private service-hold threshold requires the owner-controlled hold below. The proposed
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

The README, setup proposal and release backlog must report actual activation and unresolved gates.
This documentation-only addition requires no new TestFlight build.
