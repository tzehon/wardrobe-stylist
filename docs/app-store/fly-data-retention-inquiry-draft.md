# Fly.io data-retention inquiry

> **Status:** Sent to `security@fly.io` from the monitored owner mailbox at
> `2026-08-19T12:50:40Z`; written response received at `2026-08-19T13:19:43Z`. Gmail message
> identifiers, mailbox contents, the private sender address, and the response body are
> intentionally omitted from release evidence. The redacted outcome below follows the rules in
> [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md).

## Redacted response outcome

- Fly's provider-controlled operational and abuse-prevention logs, outside the
  customer-visible application-log stream, can include connection metadata such as source IP.
- Fly does not publish the requested per-system field, storage, region, or retention inventory.
  A customer cannot configure or enforce a hard 24-hour maximum for those provider-side logs.
- Customer-visible proxy and platform error records can contain request paths, request
  identifiers, and in some cases client IP addresses. The searchable customer-visible stream is
  retained for seven days; that beta retention cannot be shortened, disabled, or configured per
  app.
- A log shipper lets the customer control an additional destination's retention but does not
  establish a shorter provider-side limit. It therefore did not satisfy the former 24-hour
  edge-IP requirement that the owner later superseded.
- A Fly Volume snapshot is removed from `fly volumes snapshots list` at the end of its configured
  retention period. Fly does not publish a separate purge-completion time, purge granularity,
  replica/backup behavior, or another evidence surface. The DPA's general end-of-service terms do
  not prove per-snapshot physical deletion at day 14.
- Fly Security summarized the optional DPA as providing personal-data deletion within 30 days
  after service provision ends and residual encrypted-backup purge within 90 days. Those
  termination terms do not establish an active-service provider-log maximum or an active
  per-snapshot purge deadline. A read-only account check on 2026-08-19 found no active DPA: the
  Compliance page says it becomes active only when the customer signs and currently offers
  `Request now`. No exact agreement/version has been reviewed or executed, so the 30/90-day
  summary is not recorded as binding for this account.

**Decision outcome:** the response proves that the former hard 24-hour provider raw-IP maximum
was not met. On 2026-08-19 the owner explicitly approved continued Fly use with the disclosed
seven-day customer-visible stream, undisclosed/non-configurable provider-internal in-service
retention, and 14-day snapshot-listing boundary with undisclosed all-copy purge timing. This
supersedes the former provider-log requirement; it does not retroactively make that requirement a
pass or weaken the separate live-deletion and temporary-restore-volume deadlines.

**Subject:** Written data-retention confirmation for an App Attest release gate

Hello Fly Security team,

We operate a personal, single-user iOS application's backend on Fly.io. The application disables
Uvicorn access logs and emits only bounded, payload-free security events. Before distributing an
App Attest-enabled build, we need written evidence for the provider-controlled boundaries below.
No account credentials, end-user identifiers, log samples, or database contents are needed for
this inquiry.

Could you please confirm:

1. Whether Fly Proxy, edge, worker, security, abuse-prevention, or other provider-controlled
   systems persist an end user's source IP address, `Fly-Client-IP`, complete
   `X-Forwarded-For`, or equivalent forwarded-IP data outside the customer-visible application-log
   stream.
2. For every system that does, the retained fields, purposes, storage system, subprocessors and
   regions, default and maximum retention, deletion/purge timing, any backup or replica lifetime,
   and whether a customer can enforce a hard maximum of 24 hours.
3. Whether proxy or platform error records exposed in the customer log stream can contain source
   IP addresses, forwarded-IP headers, request paths, request identifiers, or other end-user
   identifiers, and whether every such record is subject to the documented approximately
   seven-day searchable application-log window.
4. Whether searchable application-log data or any copy of that stream persists beyond seven days,
   and whether retention can be shortened or disabled for one app without adding another
   processor.
5. For an encrypted Fly Volume configured with 14-day snapshot retention, when a snapshot becomes
   unavailable and when all provider-controlled copies are deleted. Please include purge
   granularity, backup/replica behavior, and any evidence surface beyond disappearance from
   `fly volumes snapshots list`.

If a public document contractually answers a question, a direct link and the relevant scope would
be helpful. For anything not publicly specified, please state the current operational guarantee
in writing and identify any plan or account configuration required to obtain it.

Thank you.
