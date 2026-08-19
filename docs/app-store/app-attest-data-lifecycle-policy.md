# APP-009 App Attest data lifecycle and logging policy

- **Decision approved:** 2026-08-18
- **Provider-risk revision approved:** 2026-08-19
- **Manual-operations revision approved:** 2026-08-20
- **Release compliance:** Repository enforcement and final-image deployment complete; Fly
  provider and manual-operations boundaries explicitly accepted; first manual review,
  snapshot-list, deletion-specific recovery, and publication evidence incomplete

This is the approved production policy for Wardrobe Stylist's developer-controlled backend
authentication store, application logs, manual operations, and Fly volume snapshots. It is the
source of truth for the APP-009 retention, deletion, logging, and operations gate.

The limits below are requirements, not claims that every control is already enforced. The
[compliance checklist](#compliance-and-release-evidence) distinguishes verified behavior from
remaining work. APP-009 stays open until every unchecked release requirement is implemented and
evidenced.

## Owner-approved Fly provider boundary

The owner approved continued use of Fly.io on 2026-08-19 after Fly Security confirmed that the
original hard 24-hour provider raw-IP maximum is not customer-enforceable. The former limit was
not met and must not be recorded as passed. It is superseded for Fly-controlled logging only by
the disclosed boundary below:

- the customer-visible log stream is retained for a fixed seven days and can include
  provider-generated paths, request IDs, and client IP;
- separate operational and abuse-prevention logs can contain connection metadata including
  source IP, while their in-service fields, retention, and purge timing are undisclosed and not
  customer-configurable; and
- encrypted snapshots stop appearing from the customer snapshot listing after the configured 14
  days, while separate all-copy purge, replica, and backup timing is undisclosed. Fly Security
  summarized an optional DPA as providing deletion within 30 days after service provision ends and
  residual encrypted-backup removal within 90 days; those are termination terms, not active
  per-snapshot guarantees. A read-only account check on 2026-08-19 found no active DPA: the Fly
  Compliance dashboard says the pre-signed agreement becomes active only when the customer signs
  it and currently offers `Request now`. Do not treat the 30/90-day summary as binding for this
  account unless the exact agreement/version is reviewed and executed.

The rationale is to retain the already-deployed, single-user architecture while preserving strict
application-owned minimization and making the provider-controlled unknowns explicit to users and
App Store review. This is a conscious privacy tradeoff, not a technical enforcement claim.

This risk acceptance preserves the strict developer-controlled limits below: application access
logs remain disabled, developer-emitted events remain payload/identifier-free, verified live
server-data deletion remains within 24 hours, and an isolated restore volume must still be
destroyed within 24 hours. Revisit the provider boundary before any provider, logging, region,
subprocessor, or DPA change and during the annual release/privacy review.

## Owner-approved manual operations boundary

On 2026-08-20 the owner chose not to add Better Stack, Grafana/Alertmanager, GitHub Actions
polling, or another automated alert/incident service for the initial personal, single-user
release. This supersedes automated alert routing as a pre-release APP-009 requirement; it does not
claim that alert delivery was technically implemented or passed.

The rationale is to avoid a new processor, monitoring credential, incident store, backend metrics
surface, and another image/deployment cycle solely for a self-imposed gate. Apple's published App
Review, App Privacy, and Support URL requirements do not state an automated infrastructure-alerting
requirement. This is not a guarantee of App Review approval.

The accepted operational tradeoff is slower detection: a backend, snapshot, abuse, Anthropic, or
budget problem may remain unnoticed until the owner performs a check or receives a support report.
For the initial release, the owner must perform and record a payload-free manual review:

- before every archive/upload;
- after every backend deploy or production configuration change; and
- at least once every 30 days while production remains deployed or enabled.

Each review checks the public health response, running Machine and immutable image digest, recent
5xx state where available, auth-volume usage, newest snapshot age/status, aggregate bounded App
Attest/rate-limit and Anthropic failure signals where available, Anthropic usage/budget state, and
the monitored support route. Retain only the review timestamp, fixed check names,
pass/warning/open result,
coarse aggregate bands where available, remediation outcome, and next due date. Never backdate a
missed review; record it as missed when discovered. Do not retain log samples, request content,
identifiers, credentials, exact billing data, screenshots, or provider response bodies. Reconsider
automated monitoring before multi-user distribution, paid operation, or any availability
commitment.

For this review, volume usage below 70% is `PASS`, 70–84% is `WARNING`, and 85% or more is `OPEN`
until remediated. Snapshot state is `PASS` only when automatic snapshots remain enabled with the
14-day listing setting, a completed snapshot is no older than 36 hours, and no failed or unknown
snapshot state is present. Operational-event state is `PASS` only when the available aggregate
surface shows no cluster of three 5xx/Anthropic failures or five auth rejection/rate-limit events
within ten minutes. A current log-buffer marker scan alone cannot prove aggregate 5xx state and
must be recorded as `OPEN` when no stronger surface is reviewed.

The owner also accepts that a 30-day manual cadence is not continuous monitoring: an incident that
begins and resolves outside Fly's available log/metric windows may permanently escape review. The
pre-archive and post-change checks reduce that risk but do not eliminate it.

This policy does not settle:

- local iPhone data, which is covered by the app's Privacy & Data controls;
- Google/Gmail retention, which is controlled by Google and the user's Google account; or
- Anthropic request retention, training, human-access, and deletion terms, which remain APP-016
  provider-contract gates.

## Scope and data minimization

The backend may persist only the minimum metadata needed to establish and defend an anonymous
App Attest installation session:

- one-time challenge IDs and 32-byte challenge secrets;
- App Attest key IDs, verified public keys, anonymous installation IDs, counters, App ID and
  environment, and optional signed validation-category/build values;
- the opaque Apple attestation receipt associated with the installation;
- session IDs and one-way bearer-token hashes; and
- bounded rate-window scopes, counts, timestamps, and keyed HMAC subject hashes.

The opaque Apple receipt is App Attest security metadata, not a Gmail purchase receipt. It follows
the installation record's lifecycle and remains untrusted for fraud decisions unless its separate
Apple receipt checks are implemented and evidenced.

The auth database must never contain Gmail message or purchase-receipt content, wardrobe data,
photos, model prompts or responses, OAuth credentials, raw bearer tokens, App Attest private keys,
or raw IP addresses. Receipt and wardrobe request payloads may exist in process memory only for the
request being served and must not be written to application logs or durable application storage.
Provider processing remains subject to the separate processor-contract gate.

## Required retention schedule

“Purge” means the record is absent from the active logical database and no longer usable. A
completed active-database deletion must also checkpoint/truncate relevant SQLite WAL state using a
tested maintenance procedure. It does not claim that bytes have disappeared from an encrypted
snapshot when that snapshot leaves the customer-visible listing.

| Data | Approved limit / accepted provider boundary | Current repository/production truth |
|---|---|---|
| Receipt and wardrobe request payloads | Request lifetime only; no application persistence | Current routes do not persist payloads. Review guardrails pin the exact auth schema, block common file/database persistence patterns and direct auth-store use from payload modules, and allowlist current application log calls. Anthropic/provider terms remain separate evidence |
| App Attest challenges | Valid for 5 minutes; purge no later than 70 minutes after issue | Fly v5 runs one-minute deadline maintenance on the minimum-one-Machine topology, with cold-start lookahead and repeat-until-drained bounded transactions |
| Session-token hashes | Valid for 15 minutes; purge no later than 20 minutes after issue | Fly v5 runs one-minute deadline maintenance on the minimum-one-Machine topology, with cold-start lookahead and repeat-until-drained bounded transactions |
| Rate-limit subject hashes | Challenge window plus 5 minutes; hourly windows no later than 65 minutes after window start | Only keyed HMAC subjects persist; expired windows are purged by request admission and Fly v5's one-minute maintenance loop |
| Active installation metadata, verified public key, counter, and opaque Apple receipt | 90 days after the last successful authenticated request | `last_seen_at` advances after successful enrollment, assertion renewal, or bearer authentication; Fly v5 purges inactive installations at the deadline and cascades their sessions |
| Revoked installation metadata | 30 days after revocation | Fly v5 purges revoked installations at the deadline and cascades their sessions. Anonymous identities are not linked, so this applies only to individually revoked records |
| Verified server-data deletion request | Remove live installation, sessions, and associated auth rows within 24 hours | `POST /auth/app-attest/delete` requires a fresh one-time deletion assertion and synchronously deletes the proven installation, key-bound challenges, sessions, and rate rows derived with the current HMAC secret. Once the signed proof is dispatched, iOS immediately fences memory-only sessions and retains the local key only for an idempotent retry until deletion is confirmed. Any unlinkable pre-rotation rate hash expires under the 65-minute outer limit. Fly v5 is deployed; processed-TestFlight proof remains pending |
| Automatic or manual auth-volume snapshots | Customer-visible listing for 14 days; no developer-created or customer-configured monthly/indefinite archive. Separate provider all-copy purge timing is accepted as undisclosed | Fly v5 is configured for 14 days. Fly says a snapshot stops appearing in the snapshot list at the configured deadline, but does not publish separate purge-completion, replica, or backup semantics; actual listing disappearance remains to be observed. Fly Security summarized optional DPA termination periods of 30 days for personal-data deletion and 90 days for residual encrypted backups, but the account has no active DPA and those periods are not active per-snapshot guarantees |
| Temporary restore volume | Delete within 24 hours after the rehearsal or incident closes | On 2026-08-19 a production snapshot was restored cross-app into a secret-free temporary app with no public IP or service. A one-shot Machine remounted the source read-only and reported schema v4, SQLite integrity `ok`, zero foreign-key errors, and zero rows in each of the four auth tables. The Machine auto-destroyed; the encrypted temporary volume and empty app were then deleted, and control-plane absence was verified within 391 seconds of volume creation. This proves attended list removal, not physical-media purge |
| Wardrobe application access logs | None | Fly v5's running Uvicorn process was verified with `--no-access-log`, and a regression pins that production command |
| Developer-emitted application security events | 7 days maximum | Application-owned event fields are minimized and tested. Fly retains the customer-visible stream for seven days, which is not configurable per app |
| Provider-generated proxy/platform records in the customer-visible stream | Fixed seven days, including when a provider record contains client IP | Fly says these records can include paths, request IDs, and sometimes client IP; retention cannot be shortened, disabled, or configured per app |
| Separate Fly operational/abuse-prevention logs | Fly-defined in-service retention with no disclosed or customer-enforceable numeric maximum; explicitly accepted 2026-08-19 | Fly says these records can include connection metadata such as source IP but does not publish the requested per-system fields, retention, or purge timing |
| Fixed-field manual-review attestations | Project/release evidence lifetime | Long-lived evidence contains only timestamp, fixed check/result fields, coarse aggregate bands, remediation outcome, and next due date; it contains no log samples or identifiers |
| Temporary incident working notes, if needed | 30 days maximum, or 7 days after incident closure when earlier | No dedicated alert/incident service is created for the initial release; working notes follow the same payload and identifier prohibitions as logs |

The 70-minute challenge limit allows the five-minute usable lifetime, the existing one-hour
post-expiry cleanup grace, and five minutes for deadline-based cleanup. Rate hashes use one-minute
or one-hour fixed windows; the five-minute allowance is maintenance time, not added authorization.

## Logging and telemetry

Application security events may contain only:

- a bounded event name, error code, quota scope, fixed API path, and authentication mechanism;
- severity and timestamp supplied by the logging platform; and
- a bounded upstream SDK error class/status or provider-issued request ID when needed to diagnose a
  failed request.

Application access logs must be disabled. Developer-controlled application logs, metrics, traces,
alerts, and exception reports must not contain raw or hashed IP addresses, installation IDs, key
IDs, challenge IDs or challenge values/secrets, raw tokens or token hashes, rate-window subject
HMACs, headers, attestation/assertion objects, Apple receipts, Gmail IDs or content,
wardrobe/catalog content, photos, prompts, or model output. This prohibition does not describe
unavoidable provider edge network logs, which are governed separately below. Do not add a log
drain, analytics SDK, tracing service, error-capture service, or external monitoring/alert provider
without updating the data inventory, processor list, this policy, public disclosures, and the
retention evidence first.

Provider edge logging is a separate boundary. Fly Security confirmed on 2026-08-19 that internal
operational and abuse-prevention logs outside the customer-visible stream can include source IP,
and that customers cannot configure or enforce a hard 24-hour provider-side maximum. Fly also
confirmed that proxy/platform error records in the seven-day customer-visible stream can contain
paths, request IDs, and in some cases client IP. That seven-day beta retention cannot be shortened,
disabled, or configured per app. A customer log shipper controls only an additional destination
and does not alter these provider-controlled copies. The owner explicitly accepted this boundary
on 2026-08-19. Public disclosures and App Store Connect answers must state the retained-IP
collection truth and must not describe all Fly logs as identifier-free or as having a seven-day
maximum.

## Deletion, reinstall, backup, and restore

Deleting local data and deleting server authentication metadata are separate operations. The
implemented server deletion path verifies possession of the anonymous App Attest installation
with a fresh, one-time assertion-backed request. Email address, Google
identity, device model, or knowledge of wardrobe contents is not sufficient verification. Support
must never request a token, private key, attestation object, Apple receipt, Gmail content, or
wardrobe payload.

A successful server deletion removes the installation and cascades its sessions and related auth
state from the live database within 24 hours. The implemented fresh assertion flow performs this
synchronously and checkpoints/truncates WAL. After dispatching the signed deletion proof, iOS
immediately retires every memory-only session so an ambiguous timeout or maintenance response
cannot recreate the identity through a late retry. It retains the App Attest credential solely for
an idempotent deletion retry and removes that reference only after the server confirms deletion or
absence. Reinstalling or restoring the app creates a new installation identity; it does not prove
deletion of the old record. The 90-day inactivity limit is the fallback for an installation that is
lost before it can authenticate a deletion.

Deletion quotas use capacity reserved from ordinary authentication traffic. The current SQLite
admission guard still has a bounded 32-row deletion namespace: a distributed attacker using enough
distinct source IPs can temporarily exhaust it for at most the hourly rate-window lifetime. This is
an accepted availability risk for the single-user release, not an authorization bypass or data
disclosure. Under the owner-approved manual-operations boundary, sustained exhaustion may be
detected only during a manual aggregate review or from a support report; that slower detection is
an accepted availability risk.

Rate subjects are keyed HMACs. Rotating `APP_ATTEST_SESSION_SECRET` intentionally breaks the link
to rate rows written with the previous secret. A verified deletion still removes the live
installation, sessions, and key-bound challenges synchronously; any unlinkable pre-rotation rate
hash remains unusable as identity data and must expire no later than its fixed window plus the
five-minute maintenance allowance (65 minutes maximum). Record secret rotations and do not claim
that every pre-rotation rate row was synchronously selected for deletion.

Encrypted rolling snapshots remain in the customer-visible listing for 14 days. Fly does not
disclose all-copy purge timing, so provider-controlled copies may retain a deleted record beyond
listing disappearance. A snapshot created before a completed deletion must not silently restore
that record into service. Until a
durable deletion journal exists, such a snapshot is ineligible for normal restoration; emergency
recovery must use a fresh auth store and require re-enrollment. Any future deletion journal must be
minimal, keyed, expire after the last eligible snapshot, and be added to this inventory.

Restore work must use an isolated, non-serving volume/Machine without application secrets. Record
only aggregate table counts and integrity results, then destroy the temporary restore volume within
24 hours. Never retain raw database copies in release evidence.

## Manual operations and support

The owner performs the manual review defined above instead of operating an automated alerting
stack for the initial single-user release. A failed check is a release blocker until remediated and
rechecked. Future automated alerting must follow the same payload and identifier prohibitions as
logs and requires the inventory, processor, retention, and public-disclosure review described in
[Logging and telemetry](#logging-and-telemetry) before activation.

The published support and privacy pages must name a monitored contact and response target. The
support process must distinguish device-local deletion from server auth-metadata deletion and must
meet the 24-hour live-deletion deadline after installation control is verified.

### Manual review register

This fixed-field table is the long-lived compliance attestation. It must never contain raw metric
values, logs, screenshots, identifiers, exact billing data, or provider response bodies.

| Checked at UTC | Health / Fly | Snapshot | Volume | Auth / 5xx | Anthropic | Support | Overall | Remediation / next action | Next due |
|---|---|---|---|---|---|---|---|---|---|
| 2026-08-19T23:34:44Z | PASS · expected Machine/image | PASS · 14d · latest <36h | below-warning | OPEN · current-buffer markers only; aggregate 5xx unavailable | OPEN · public status page operational; console usage/spend-limit sign-in required | PASS · routing rehearsal confirmed | OPEN | Finish Fly aggregate 5xx and Anthropic console checks; no remediation applied | 2026-08-20 |

## Compliance and release evidence

Verified as of 2026-08-20:

- [x] The auth-store schema excludes receipt/wardrobe payloads and raw IP addresses.
- [x] Session bearers are stored only as hashes; rate subjects are stored only as keyed HMACs.
- [x] Challenges and sessions become unusable after five and fifteen minutes respectively.
- [x] Application security-event fields are bounded and payload/identifier-free, with regression
  coverage.
- [x] The production auth volume is encrypted and Fly reports a configured 14-day snapshot-listing
  period; actual listing disappearance remains an external evidence item below.
- [x] Structural review guardrails pin the exact auth schema, block common durable-write patterns
  and direct auth-store use from payload modules, allowlist current application log calls, and
  exercise payload-free error behavior. These guardrails supplement review; they are not a proof
  against every possible future persistence mechanism.
- [x] A one-minute lifecycle task starts and stops with FastAPI, uses cold-start lookahead, and
  repeats bounded cleanup transactions until every eligible challenge, session, and rate row is
  drained. Fly v5 runs the committed minimum-one-Machine production topology.
- [x] Repository cleanup enforces 90-day inactive-installation and 30-day revoked-installation
  limits, cascades sessions, uses SQLite secure deletion, and checkpoints/truncates WAL.
- [x] A fresh one-time App Attest deletion assertion synchronously deletes the proven installation;
  the separate in-app Privacy & Data control fences memory sessions after proof dispatch, retains
  its local credential for ambiguous-response retries, clears that reference only after confirmed
  server deletion/absence, and then allows a future remote-AI request to enroll a new anonymous
  identity.
- [x] The production container command disables Uvicorn access logs and is pinned by a regression.
- [x] A redacted production-operations inventory on 2026-08-19 reconfirmed Fly v5 healthy on
  the immutable policy image, one encrypted 1 GB auth volume, automatic daily snapshots, and a
  configured 14-day listing period. Two completed snapshots dated 2026-08-17 and 2026-08-18 each
  reported `retention_days = 14`; neither is old enough to prove actual list disappearance.
- [x] Fly documents approximately seven-day searchable application-log retention and no built-in
  metrics alerting. No custom log drain, Fly Log Shipper/monitoring companion app, or configured
  alert route was found in the read-only account inventory.
- [x] A written Fly Security response received at `2026-08-19T13:19:43Z` confirms that
  provider-controlled operational/abuse logs can include source IP, the customer-visible stream
  can include platform/proxy paths, request IDs, and client IP, and no customer-enforceable hard
  24-hour provider-log limit exists. This proves the former limit was not met.
- [x] On 2026-08-19 the owner explicitly approved continued Fly use with the provider boundary
  above. This supersedes the former 24-hour provider-log limit without weakening the separate
  24-hour live-deletion or temporary-restore-volume requirements.
- [x] On 2026-08-20 the owner explicitly chose manual operations for the initial single-user
  release instead of an automated alert/incident service. This records the accepted slower-detection
  risk and supersedes the old alert-delivery gate without claiming it passed.

Required before APP-009 can close:

- [x] Fly v5 deploys final policy-enforced `linux/amd64` digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  from source `7b6acb83960e2cd69458489ab5f5fe0e04cd9f85`. Local and immutable-registry
  scans found no critical/high vulnerability across 90 packages. App-Attest-only rollback digest
  `sha256:f4758e08046e187161b992ad34530c3c41c89375c9277522015628ec9306eef1`
  was restored to the registry, re-scanned, and passed an isolated v3/v4 database round-trip with
  SQLite integrity `ok`.
- [x] Rehearse the isolated snapshot-restore control path. At `2026-08-19T14:31:01Z`, a
  secret-free, non-serving temporary app restored the newest completed snapshot to an encrypted
  volume. The verifier remounted it read-only and reported schema v4, SQLite integrity `ok`, zero
  foreign-key errors, and aggregate counts of zero for challenges, installations, rate windows,
  and sessions. The one-shot Machine auto-destroyed; the volume and app were explicitly removed,
  and absence was verified by `2026-08-19T14:33:06Z`, 391 seconds after volume creation. The
  production volume, source snapshot, pinned image, and passing health check remained intact.
  No secret value, row value, database copy, or request/log sample is retained as evidence.
- [x] Record Fly's provider-controlled fields/retention limits and the owner-approved risk
  revision; update the inventory and draft disclosures without claiming the former requirement
  passed.
- [ ] Publish the final App Store Connect App Privacy answers from the accepted production facts:
  Device ID, Other Diagnostic Data, and Product Interaction; App Functionality; linked; not
  tracking. Reassess before submission if any processor, purpose, or data flow changes.
- [ ] Complete the first manual operations review against the final deployed image. The
  2026-08-19T23:34:44Z partial review verified public health, Fly checks, the single running
  Machine, expected immutable image, encrypted-volume policy and usage band, a fresh 14-day
  snapshot, absence of the selected auth/Anthropic-failure markers in the current log buffer, the
  public status page's operational API state, and the rehearsed support route. The review remains
  open because the buffer scan does not prove aggregate 5xx behavior and signed-in Anthropic
  usage/spend-limit state has not yet been inspected.
- [ ] Publish monitored privacy/support contacts and the server-deletion procedure. The public
  contact is selected as `contact@tth.dev`. Unpublished support/privacy pages are prepared in
  [`tzehon.github.io` draft PR #2](https://github.com/tzehon/tzehon.github.io/pull/2). A
  payload-free inbound-routing rehearsal sent at `2026-08-19T13:20:04Z` was confirmed delivered
  by the owner on 2026-08-19; no message body, mailbox contents, or identifiers are retained as
  release evidence. Removal of the pages' `published: false` guards remains pending. The approved
  public response target is within two business days.
- [ ] From the processed TestFlight client, rehearse deletion followed by eligible snapshot-list
  disappearance or safe fresh-store recovery. The generic isolated restore-path rehearsal above
  does not prove that a deleted production identity cannot return.

The provider questions and redacted written outcome are recorded in
[`fly-data-retention-inquiry-draft.md`](fly-data-retention-inquiry-draft.md). The response proves
that Fly could not meet the former hard 24-hour provider raw-IP maximum; the owner explicitly
superseded that requirement on 2026-08-19. Retain the later timestamped snapshot-list-expiry
observation separately.

Retain only redacted evidence: source SHA, immutable image digest, policy/config names, aggregate
counts, timestamps, snapshot retention, manual check/remediation result, and deletion/restore outcome.
Never retain secret values, raw identifiers, request bodies, database files, or log samples that
contain prohibited fields.

## Provider and publication references

- [Fly Volume snapshots](https://fly.io/docs/volumes/snapshots/)
- [Fly app logging overview](https://fly.io/docs/monitoring/logging-overview/)
- [Fly log search](https://fly.io/docs/monitoring/search-logs/)
- [Fly built-in metrics and external alerting](https://fly.io/docs/monitoring/metrics/)
- [Fly subprocessors](https://fly.io/legal/sub-processors/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Privacy requirements](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple Support URL requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- Fly Compliance dashboard (authenticated account evidence, checked 2026-08-19): the optional
  pre-signed DPA becomes active only when the customer signs it; no active agreement or exact
  version is currently evidenced.
