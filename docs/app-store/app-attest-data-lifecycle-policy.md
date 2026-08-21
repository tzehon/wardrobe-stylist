# APP-009 App Attest data lifecycle and logging policy

- **Decision approved:** 2026-08-18
- **Provider-risk revision approved:** 2026-08-19
- **Manual-operations revision approved:** 2026-08-20
- **Release compliance:** Repository enforcement and the exact reviewed Gmail-free v8 deployment
  are verified; Fly provider and manual-operations boundaries are explicitly accepted; the v8
  post-change review, historical v7/build-4 reviews and signed archive, Apple upload/processing,
  internal assignment, and Gmail-free public support/privacy/Terms routes are retained. Build-4
  processed-client proof is partial and exposed a release defect. Real registration/assertion
  success-marker observation, complete build-5 physical proof, snapshot-list expiry, and deletion-
  specific recovery remain incomplete.

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

Anthropic state is `PASS` only when its public status is operational, a configured monthly limit
exists, signed-in month-to-date spend is below 80% of that limit, visible cost is attributed only
to the expected Wardrobe model/key series, and no rate-limit saturation warning is visible. Spend
from 80% to below 100% is `WARNING`. Spend at or above 100%, no configured limit, an unexpected
model/key series, a visible saturation warning, or a non-operational public status is `OPEN` until
reviewed or remediated.

The owner also accepts that a 30-day manual cadence is not continuous monitoring: an incident that
begins and resolves outside Fly's available log/metric windows may permanently escape review. The
pre-archive and post-change checks reduce that risk but do not eliminate it.

This policy does not settle:

- local iPhone data, which is covered by the app's Privacy & Data controls;
- any separately approved future Google/Gmail access or retention; public v1 contains no such
  capability; or
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
or raw IP addresses. Wardrobe request payloads may exist in process memory only for the request
being served and must not be written to application logs or durable application storage.
Provider processing remains subject to the separate processor-contract gate.

## Required retention schedule

“Purge” means the record is absent from the active logical database and no longer usable. A
completed active-database deletion must also checkpoint/truncate relevant SQLite WAL state using a
tested maintenance procedure. It does not claim that bytes have disappeared from an encrypted
snapshot when that snapshot leaves the customer-visible listing.

| Data | Approved limit / accepted provider boundary | Current repository/production truth |
|---|---|---|
| Wardrobe request payloads | Request lifetime only; no application persistence | Current routes do not persist payloads. Review guardrails pin the exact auth schema, block common file/database persistence patterns and direct auth-store use from payload modules, and allowlist current application log calls. Anthropic/provider terms remain separate evidence |
| App Attest challenges | Valid for 5 minutes; purge no later than 70 minutes after issue | Fly v8 runs one-minute deadline maintenance on the minimum-one-Machine topology, with cold-start lookahead and repeat-until-drained bounded transactions |
| Session-token hashes | Valid for 15 minutes; purge no later than 20 minutes after issue | Fly v8 runs one-minute deadline maintenance on the minimum-one-Machine topology, with cold-start lookahead and repeat-until-drained bounded transactions |
| Rate-limit subject hashes | Challenge window plus 5 minutes; hourly windows no later than 65 minutes after window start | Only keyed HMAC subjects persist; expired windows are purged by request admission and Fly v8's one-minute maintenance loop |
| Active installation metadata, verified public key, counter, and opaque Apple receipt | 90 days after the last successful authenticated request | `last_seen_at` advances after successful enrollment, assertion renewal, or bearer authentication; Fly v8 purges inactive installations at the deadline and cascades their sessions |
| Revoked installation metadata | 30 days after revocation | Fly v8 purges revoked installations at the deadline and cascades their sessions. Anonymous identities are not linked, so this applies only to individually revoked records |
| Verified server-data deletion request | Remove live installation, sessions, and associated auth rows within 24 hours | `POST /auth/app-attest/delete` requires a fresh one-time deletion assertion and synchronously deletes the proven installation, key-bound challenges, sessions, and rate rows derived with the current HMAC secret. Merged replacement source persists the post-dispatch deletion fence across termination/relaunch and retains its local key only for an idempotent retry until deletion is confirmed; historical `dd3d990` fenced only the running actor. Any unlinkable pre-rotation rate hash expires under the 65-minute outer limit. Fly v8 and historical build-4 archive/upload evidence are verified; processed-client deletion proof remains pending |
| Automatic or manual auth-volume snapshots | Customer-visible listing for 14 days; no developer-created or customer-configured monthly/indefinite archive. Separate provider all-copy purge timing is accepted as undisclosed | Fly v8 is configured for 14 days. All snapshots listed after deployment were created; the newest is `2026-08-21T07:32:23Z`. Fly says a snapshot stops appearing in the snapshot list at the configured deadline, but does not publish separate purge-completion, replica, or backup semantics; actual listing disappearance remains to be observed. The newest snapshot predates build-4 production enrollment, so deletion/reinstall QA is paused pending eligible recovery evidence. Fly Security summarized optional DPA termination periods of 30 days for personal-data deletion and 90 days for residual encrypted backups, but the account has no active DPA and those periods are not active per-snapshot guarantees |
| Temporary restore volume | Delete within 24 hours after the rehearsal or incident closes | On 2026-08-19 a production snapshot was restored cross-app into a secret-free temporary app with no public IP or service. A one-shot Machine remounted the source read-only and reported schema v4, SQLite integrity `ok`, zero foreign-key errors, and zero rows in each of the four auth tables. The Machine auto-destroyed; the encrypted temporary volume and empty app were then deleted, and control-plane absence was verified within 391 seconds of volume creation. This proves attended list removal, not physical-media purge |
| Wardrobe application access logs | None | Fly v8's single UID-10001 Uvicorn process uses `--no-access-log`, and a regression pins that production command |
| Developer-emitted application security events | 7 days maximum | Application-owned event fields are minimized and tested. Fly v8 enables application `INFO` only for the non-propagating `app.auth.service` logger while other application INFO and access logs remain off. The first post-deploy bounded query found zero `registration_succeeded`, `assertion_succeeded`, and `installation_deleted` events because none had been exercised; real connected-client observation remains open. Protected `/recommend` intentionally has no developer success event and uses aggregate admission plus client-result evidence. Fly retains the customer-visible stream for seven days, which is not configurable per app |
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
state from the live database within 24 hours. The fresh assertion flow performs this synchronously
and checkpoints/truncates WAL. After dispatching the signed deletion proof, iOS must retire every
memory-only session and persist a pending-deletion fence across app termination and relaunch so an
ambiguous timeout or maintenance response cannot reuse or recreate the identity. It may retain the
App Attest credential solely for an idempotent deletion retry and must remove that reference only
after the server confirms deletion or absence. The historical `dd3d990` archive fenced only the
running authorization actor and therefore does not satisfy this requirement; replacement proof is
open. Reinstalling or restoring the app creates a new installation identity; it does not prove
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

The latest listed 14-day snapshot at `2026-08-21T07:32:23Z` predates the build-4 TestFlight
enrollment. Server deletion and reinstall QA are therefore paused: that pre-enrollment snapshot
cannot prove deletion-specific recovery or the non-return of the newly enrolled identity.

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
| 2026-08-20T00:15:07Z | PASS · expected Machine/image | PASS · 14d · latest <36h | below-warning | PASS · 7d HTTP view: 200/401/405 only, no 5xx series; selected-event bursts below threshold | PASS · public status operational · <80% of configured limit · expected models/keys | PASS · routing rehearsal confirmed | PASS | None; repeat before archive/upload | 2026-09-19 |
| 2026-08-21T01:11:43Z | PASS · exact Gmail-free Machine/image | PASS · 14d · latest <36h | below-warning | PASS · post-v6 2d HTTP view: 401/404 only, no 5xx series; bounded marker buffer empty | PASS · public status operational · <80% of configured limit · production key on expected model · no saturation warning | PASS · routing rehearsal confirmed | PASS | None; repeat before archive/upload | 2026-09-20 |
| 2026-08-21T03:30:33Z | PASS · exact Gmail-free Machine/image | PASS · 14d · latest <36h | below-warning | PASS · 2d HTTP view: 200/401/404 only, no 5xx series; bounded markers empty | PASS · public status operational · <80% of configured limit · production key on expected model · no saturation warning | PASS · routing rehearsal confirmed | PASS | Historical archive completed; later superseded by review fixes; repeat after replacement deploy and before upload | 2026-09-20 |
| 2026-08-21T06:00:21Z | PASS · exact reviewed v7 Machine/image | PASS · 14d · latest <36h | below-warning | PASS · 2d HTTP view: 200/401/404 only, no 5xx series; bounded marker queries empty | PASS · public status operational · <80% of configured limit · production key on Opus 4.8 · no saturation warning | PASS · routing rehearsal confirmed | PASS | None; repeat immediately before replacement-archive upload | 2026-09-20 |
| 2026-08-21T08:12:46Z | PASS · exact reviewed v7 Machine/image | PASS · 14d · latest <36h | below-warning | PASS · 2d HTTP view: 401/404 only, no 5xx series; bounded marker queries empty | PASS · public status operational · <80% of configured limit · production key on Opus 4.8 · no saturation warning | PASS · routing rehearsal confirmed | PASS | None; build-4 replacement archive validated/uploaded; resume monthly cadence | 2026-09-20 |
| 2026-08-21T11:09:20Z | PASS · exact reviewed v8 Machine/image | PASS · 14d · all listed created · latest <36h | below-warning | PASS · 2d HTTP view: 401/404 only, no 5xx series; bounded failure-event classes zero; lifecycle success not exercised | PASS · public status operational · <80% of configured limit · deployed Wardrobe key on Opus 4.8 · no saturation warning | PASS · pages/contact/target and retained rehearsal confirmed | PASS | None; repeat before archive/upload | 2026-09-20 |

### Processed build-4 aggregate evidence — 2026-08-21 (PARTIAL)

The clean TestFlight install on iPhone 16 Pro/iOS 26.6 took the production installation aggregate
from 0 to 1. First assertion/protected calls and a cold assertion/session renewal succeeded. Online
recovery showed `Styled 17:24`; the assertion aggregate advanced 1→2 and the current recommendation-
installation rate window 0→1. Signed runtime category/build fields were absent as expected on iOS
26.6 and are not enforcement evidence. Offline remote styling failed closed while local features
remained usable.

The bounded Fly marker stream had no `registration_succeeded` or `assertion_succeeded` matches
because live v7 suppressed INFO lifecycle events during this build-4 run; `installation_deleted`
was not expected because deletion was paused. Protected `/recommend` intentionally has no developer
success event; the aggregate admission counter and visible non-cached client result supplied its
separate evidence. Fly v8 now deploys the logging fix and source TestFlight allowlist for builds
`4,5`, but its initial lifecycle-event counts remain zero because no corresponding operation was
exercised after deployment. This historical result does not close lifecycle-marker observation. It
also does not close deletion: the latest listed 14-day snapshot at
`2026-08-21T07:32:23Z` predates enrollment, so server deletion/reinstall remains paused. Repeat the
complete aggregate proof on build 5 after deployment. Retain no raw identifiers, tokens, request
bodies, database rows, wardrobe payloads, or log samples.

## Compliance and release evidence

Verified as of 2026-08-21:

- [x] The auth-store schema excludes receipt/wardrobe payloads and raw IP addresses.
- [x] Session bearers are stored only as hashes; rate subjects are stored only as keyed HMACs.
- [x] Challenges and sessions become unusable after five and fifteen minutes respectively.
- [x] Application security-event fields are bounded and payload/identifier-free, with regression
  coverage.
- [x] Deploy and verify the payload-free App Attest INFO lifecycle-marker logging configuration and
  TestFlight build `4,5` allowlist. Fly v8 serves exact reviewed PR #23 source
  `4a75b99dcd49e818ad1d5b198e8c49abba702e18` at immutable digest
  `sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`;
  its build, scan, runtime, configuration, and post-change review gates passed.
- [ ] Observe real `registration_succeeded` and `assertion_succeeded` events during connected
  build-5 QA and `installation_deleted` during the later identity-safe handoff. The first v8
  post-deploy query returned zero for all three because none was exercised. Protected `/recommend`
  intentionally remains aggregate/client-evidenced; deployment/configuration evidence alone does
  not close this observation gate.
- [x] The production auth volume is encrypted and Fly reports a configured 14-day snapshot-listing
  period; actual listing disappearance remains an external evidence item below.
- [x] Structural review guardrails pin the exact auth schema, block common durable-write patterns
  and direct auth-store use from payload modules, allowlist current application log calls, and
  exercise payload-free error behavior. These guardrails supplement review; they are not a proof
  against every possible future persistence mechanism.
- [x] A one-minute lifecycle task starts and stops with FastAPI, uses cold-start lookahead, and
  repeats bounded cleanup transactions until every eligible challenge, session, and rate row is
  drained. Fly v8 runs the committed minimum-one-Machine production topology.
- [x] Repository cleanup enforces 90-day inactive-installation and 30-day revoked-installation
  limits, cascades sessions, uses SQLite secure deletion, and checkpoints/truncates WAL.
- [x] A fresh one-time App Attest deletion assertion synchronously deletes the proven installation;
  the separate in-app Privacy & Data control must persist its pending-deletion fence across app
  termination/relaunch after proof dispatch, retain the existing credential only for ambiguous-
  response retries, clear that reference only after confirmed server deletion/absence, and only
  then allow a future remote-AI request to enroll a new anonymous identity. PR #19 merged the
  persisted fence and relaunch/retry coverage in source
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`; historical build-4 signed-archive and Apple upload/
  processing evidence are retained. Build-4 physical proof is partial; build-5 deletion proof
  remains a separate gate.
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

- [x] On 2026-08-19, Fly release v5 deployed policy-enforced `linux/amd64` digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  from source `7b6acb83960e2cd69458489ab5f5fe0e04cd9f85`. Local and immutable-registry
  scans found no critical/high vulnerability across 90 packages. App-Attest-only rollback digest
  `sha256:f4758e08046e187161b992ad34530c3c41c89375c9277522015628ec9306eef1`
  was restored to the registry, re-scanned, and passed an isolated v3/v4 database round-trip with
  SQLite integrity `ok`.
- [x] The Gmail-free source merged as `9a48caebdec67ac26673c3ba51546a5e7edcf0cc` and exact
  `linux/amd64` digest `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  passed local and immutable-registry critical/high scans across 90 packages before digest-only
  deployment as Fly release v6. The running label matches the merged source, the Machine and
  service check are healthy, the encrypted volume remains attached with the configured 14-day
  snapshot listing, schema v4 integrity is `ok` with zero foreign-key errors, `/extract` returns
  `404`, and unauthenticated `/recommend` returns `401`. Former v5 digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  was restored to the registry, re-scanned clean, and passed an isolated old/new/old schema-v4
  rehearsal as an emergency pre-build-4 rollback only; using it would re-expose `/extract` and halt
  release. Both exact digests resolved after fresh private-registry authentication at
  `2026-08-21T01:20:25Z`. The v6 digest is the required Gmail-free recovery baseline and resolved
  again after fresh authentication during the `2026-08-21T03:14:10Z`–`03:30:06Z` pre-archive
  window. The payload-free post-deploy manual review passed at `2026-08-21T01:11:43Z`.
- [x] PR #19 rebase-merged the reviewed fixes as
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`. Its exact local `linux/amd64` image ID
  `sha256:ac409ec2e687b96f718aeffd27dd244814919483f86e4af2dea3d97e9a80c643`
  and immutable registry digest
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
  each passed a Docker Scout critical/high scan across 90 packages. Fly release v7 deployed only
  that digest. At that historical gate, the running label matched the reviewed source; one Singapore
  Machine and its health check passed; `min_machines_running = 1`; the encrypted 1 GB auth volume
  remained attached with automatic 14-day snapshots; schema v4 integrity was `ok` with zero foreign-
  key errors; production App Attest category/build configuration was `2`/`4`; `/extract` returned
  `404`; and unauthenticated `/recommend` returned `401`. Locked backend tests covered the reviewed
  quota order. Source configuration for builds `4,5` and registration/assertion INFO success-marker
  logging was locally validated but not live at that time; the following v8 entry supersedes that
  production state.
  Gmail-free v6 digest `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  remains the freshly scan-clean recovery baseline; both exact v7 and v6 digests resolved after
  fresh registry authentication at `2026-08-21T06:06:01Z`.
- [x] Reviewed PR #23 merged at `2026-08-21T10:29:56Z`; frozen shipped-code/backend source was
  `4a75b99dcd49e818ad1d5b198e8c49abba702e18`. Later docs-only evidence does not change the
  deployed image or iOS bundle. A fresh no-cache
  `linux/amd64` build produced local image ID
  `sha256:3eb95304cb6e97976d2aa8b18dce302a3a908cf1d565b13d511c3fc2ed9d7c84`;
  its local scan covered 90 packages with zero critical/high vulnerabilities, and UID 10001,
  no-new-privileges, mounted-volume, and targeted-logging smoke checks passed. The immutable
  registry digest
  `sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`
  re-resolved with the exact source label, digest, `linux/amd64` architecture, and a 90-package
  zero-critical/high scan. Fly release v8 completed at `2026-08-21T10:45:06Z` and runs only that
  image. One healthy Singapore Machine runs with `min_machines_running = 1`; production App Attest
  configuration is category `2` and builds `4,5`; required secrets are deployed without retaining
  values; and the encrypted 1 GB volume is in the below-warning usage band. All listed snapshots are
  created; the newest is `2026-08-21T07:32:23Z`, and retention remains 14 days. Schema v4 integrity
  is `ok` with zero foreign-key errors, one installation, zero sessions, and zero challenges. The
  single UID-10001 Uvicorn process uses the targeted non-propagating auth-service logger with access
  logging disabled. Health returns `200`, `/extract` returns `404`, unauthenticated `/recommend`
  returns `401`,
  and the OpenAPI route set matches the reviewed source. Former v7 digest
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
  and Gmail-free v6 recovery digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  freshly re-resolved and scanned across 90 packages with zero critical/high vulnerabilities. Both
  are operational recovery only: using either reopens the exact-candidate deployment,
  configuration, and manual-review gates and blocks build-5 archive/QA until v8 is restored and
  reverified.
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
- [x] Complete the first manual operations review against the pre-APP-036 policy-v5 image. The
  `2026-08-20T00:15:07Z` review reconfirmed the public production health response, passing Fly
  check, single running Machine, expected immutable image, encrypted-volume policy and
  below-warning usage band, and a completed 14-day snapshot newer than 36 hours. Fly's
  last-seven-days aggregate HTTP view showed only 200, 401, and 405 series and no 5xx series, and
  the available bounded auth/Anthropic-failure event view remained below the policy burst
  thresholds. The signed-in Anthropic console showed month-to-date usage below 80% of the
  configured limit, only the expected Wardrobe model/key series, and no visible rate-limit
  saturation warning; the refreshed public status was operational. The monitored support route
  had already passed its payload-free delivery rehearsal. No raw metric value, log sample,
  screenshot, identifier, exact billing amount, credential, or provider response body is retained
  as evidence. Its original next-due date was 2026-09-19 and was superseded by the post-v6 review.
- [x] Complete the required post-deploy manual review against the exact Gmail-free v6 image. The
  `2026-08-21T01:11:43Z` review reconfirmed health, Machine/image identity, 14-day snapshot-listing
  configuration and newest-snapshot age, below-warning volume use, the post-v6 two-day HTTP status
  series without a 5xx series, and an empty bounded marker buffer. Anthropic public status was
  operational; signed-in spend was below 80% of its configured limit; only the production Wardrobe
  key on the expected model was visible; and no saturation warning was present. Support routing
  remained rehearsed. The required pre-archive repeat at `2026-08-21T03:30:33Z` again passed exact
  image/Machine health, snapshot and volume bands, the two-day 200/401/404-only HTTP view with no
  5xx series, empty bounded markers, Anthropic status/spend/model/key/saturation checks, and support
  routing. These remain historical v6/`dd3d990` attestations.
- [x] Complete and record the payload-free post-deploy manual review against exact reviewed Fly v7.
  At `2026-08-21T06:00:21Z`, the exact Machine/image, health, encrypted-volume, snapshot, and
  below-warning usage bands passed. The two-day Fly Edge view showed only 200/401/404 series and no
  5xx series; aggregate bounded auth, Anthropic, stylist, and schema-failure marker queries were
  empty. Anthropic public status was operational, signed-in spend was below 80% of a configured
  limit, only the production Wardrobe key on Opus 4.8 was visible, and no saturation warning was
  present. Support routing remained rehearsed. No raw sample, identifier, exact billing amount,
  credential, screenshot, or provider body is retained as evidence.
- [x] Repeat the same payload-free review against exact Fly v7 immediately before replacement-
  archive upload. The `2026-08-21T08:12:46Z` pass reconfirmed exact Machine/image health,
  encrypted-volume/snapshot/usage bands, a two-day HTTP view without a 5xx series, empty bounded
  auth/Anthropic/stylist/schema-failure markers, operational Anthropic status, spend below 80% of a
  configured limit, the expected production key/model, no saturation warning, and monitored
  support routing. No raw sample, identifier, exact billing amount, credential, screenshot, or
  provider body is retained. Resume the monthly cadence no later than 2026-09-20.
- [x] Complete and record the payload-free post-change manual review against exact Fly v8. At
  `2026-08-21T11:09:20Z`, exact image/source/architecture, the healthy Singapore Machine, health,
  encrypted-volume, snapshot, and below-warning usage bands passed. The two-day HTTP view showed
  only `401`/`404` and no 5xx series. The bounded ten-minute view contained zero auth-rejection/
  rate-limit, Anthropic/stylist, maintenance, unhandled, malformed-lifecycle, or access-log events.
  It also contained zero registration, assertion, or deletion success events
  because no corresponding lifecycle operation was exercised; this is not marker-observation
  evidence. Anthropic public status was operational, signed-in spend was below 80% of a configured
  limit, only the deployed Wardrobe key on Opus 4.8 was visible, and no saturation warning was
  present. The published support pages, monitored contact/response target, and retained payload-
  free routing rehearsal passed. No raw sample, identifier, exact billing amount, credential,
  screenshot, secret value, or provider body is retained. Repeat before archive/upload and resume
  the monthly cadence no later than 2026-09-20.
- [x] Publish monitored privacy/support contacts and the server-deletion procedure. Public Pages
  [`PR #3`](https://github.com/tzehon/tzehon.github.io/pull/3) merged as
  `7e919ef373782c22cc1500a31ed475ebfd75373c` at `2026-08-20T13:20:54Z`, and the matching GitHub
  Pages deployment completed successfully. Anonymous HTTPS requests at
  `2026-08-20T13:22:35Z` returned `200` for
  [`/wardrobe/`](https://blog.tth.dev/wardrobe/) and
  [`/wardrobe/privacy/`](https://blog.tth.dev/wardrobe/privacy/). The rendered pages identify
  `contact@tth.dev`, the two-business-day response target, the live server-deletion procedure,
  and the accepted separate hosting-log/snapshot boundaries, with no draft/publication markers.
  Public Terms [`PR #4`](https://github.com/tzehon/tzehon.github.io/pull/4) then merged as
  `ff27bbe3ed2d2c4e7d3041313c0745df7f09fe44` at `2026-08-20T13:50:53Z`; the matching Pages
  deployment succeeded, and an anonymous HTTPS request returned `200` for
  [`/wardrobe/terms/`](https://blog.tth.dev/wardrobe/terms/) at `2026-08-20T13:52:35Z`.
  Support and privacy link to Terms, and Terms links back to both pages.
  A payload-free inbound-routing rehearsal sent at `2026-08-19T13:20:04Z` was confirmed delivered
  by the owner on 2026-08-19; no message body, mailbox contents, or identifiers are retained as
  release evidence.
  This check remains valid for monitored routing and the server-deletion procedure. APP-036's
  Gmail-free revision then shipped through `tzehon.github.io` PR #5 as
  `c5da090a0417bcda99fc6d328a0cdff808ea597d` at `2026-08-21T01:42:01Z`; its Pages deployment
  completed successfully at `2026-08-21T01:42:39Z`. Anonymous HTTPS checks at
  `2026-08-21T01:45:27Z` returned `200` for support, privacy, and Terms, confirmed reciprocal links
  and the 21 August 2026 effective date, and found no Gmail/Google/OAuth/import capability wording.
- [x] Retain the superseded signed build-4 archive history. Clean source
  `dd3d99061321cf91bdce166e7da579b84edb07e8` produced an arm64 Apple Distribution archive for
  `1.0.0 (4)` at `2026-08-21T03:34:13Z` with Xcode 26.6 and the iOS 26.5 SDK. The strict verifier
  passed the signed scalar production App Attest entitlement, matching App Store distribution
  profile, public configuration, app privacy manifest, and absence of shared-bearer, Google/Gmail/
  OAuth, `/extract`, and receipt-background artifacts. Subsequent shipped Swift/backend changes
  supersede this archive, so it and the failed development-profile archive are not eligible for
  validation or upload.
- [x] Retain historical uploaded build-4 signed-archive evidence after the review fixes merge, the exact
  backend image is deployed and reviewed, App Store Connect freshly confirms the next unused build,
  and a clean complete regression passes. At `2026-08-21T06:34:50Z`, App Store Connect showed
  builds 1–3 only. Clean synchronized source context
  `24c17cb9fe643035f9206ee61e2935e086902146`, a documentation-only successor to shipped-code merge
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`, passed 219 backend tests, 215 Swift tests, all 9 UI
  flows, 43 release-script tests, and the clean Release/artifact gates. Xcode 26.6 with the iOS
  26.5 SDK created
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive` at
  `2026-08-21T06:36:33Z`. The strict verifier passed the matching Apple Distribution certificate
  and App Store profile, scalar production App Attest entitlement, HTTPS public configuration, app
  privacy manifest, and Gmail-free artifact guards. A separate targeted scan of the signed app
  found no Anthropic/API-key, shared-bearer, or private-key credential marker. Separate
  `dwarfdump --uuid` output matched the app binary and dSYM at
  `5BA1F06E-7458-32A4-890F-36C8F22D9C13` (arm64).
- [x] Retain Apple validation/upload/processing and internal-assignment evidence for the exact
  build-4 replacement archive. Xcode validated at 08:16Z and uploaded through the normal App Store
  Connect route at 08:18Z; Apple processing completed by `2026-08-21T08:20:20Z`. The processed record shows
  the expected version/build, bundle, arm64 iPhone support, iOS 18.0 minimum, included symbols, no
  non-exempt encryption, and production App Attest entitlement. The `Family` Internal Testing group
  and saved truthful What to Test wording reproduced in the runbook are present. Direct Organizer
  upload produced no standalone IPA;
  the retained executable SHA-256 is
  `81ab249bbab122f549809bc094bdf8bbc450e84db34888b19a3272fe02cd22c6` and its app/dSYM UUID matches
  the archive evidence above.
- [x] Retain current local build-5 pre-archive evidence: 221 backend tests plus audit/Bandit/Ruff/
  mypy, 218 Swift unit tests, all 9 UI flows, 43 release-script tests, and Release simulator/
  artifact checks passed. This does not prove deployment, a signed archive, upload, or physical
  production App Attest behavior.
- [ ] From processed build 5, repeat production enrollment and cold assertion/session renewal with
  bounded registration/assertion marker observation. Prove protected `/recommend` separately by an
  aggregate admission-counter delta plus the visible non-cached client result; build-4 partial
  physical evidence does not close this gate.
- [ ] From the processed TestFlight client, rehearse deletion followed by eligible snapshot-list
  disappearance or safe fresh-store recovery. The latest listed 14-day snapshot at
  `2026-08-21T07:32:23Z` predates build-4 enrollment, so deletion/reinstall is paused. The generic
  isolated restore-path rehearsal above does not prove that a deleted production identity cannot
  return.

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
