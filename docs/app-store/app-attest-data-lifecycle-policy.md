# APP-009 App Attest data lifecycle and logging policy

- **Decision approved:** 2026-08-18
- **Provider-risk revision approved:** 2026-08-19
- **Manual-operations revision approved:** 2026-08-20
- **Snapshot/recovery evidence exception approved:** 2026-09-11
- **Current deployment:** Fly v13 has the bounded AI pilot enabled under the owner's separate
  12 September approval. The enabled review at `04:28:57Z` passed with the approved Cowork-only
  status exception and operational API/Console evidence. The same image, original resources,
  exact private policy and ready/idle ledger are preserved. Physical protected-call proof remains
  pending. See the [activation checkpoint](internal-testflight-runbook.md#bounded-ai-pilot-activation--2026-09-12).
- **Historical disabled setup:** Fly v12 retained source
  `d2866a2375dd4795f40a3ab13d273ed138cedd7e`, the same scanned Linux/AMD64 immutable image and the
  original Machine and durable volume. The owner-approved September 8 setup provisioned the
  separate budget ledger, applied the private policy and workspace-scoped key with AI false, and
  activated the private public-capacity review profile. Independent review at
  `2026-09-08T09:32:49Z` verified exact policy and zero current-month ledger state after restart,
  closed admission, App Attest-only configuration, auth schema v4/integrity, non-root/NoNewPrivs,
  bounded logs, fresh automatic 14-day snapshots, below-warning volume use and public pages.
  Provider limits and notification settings persisted, prepaid-credit readiness passed, and
  auto-reload stayed off. No paid model call ran. Actual provider alert delivery remains unproven;
  billing discrepancies and unknown coverage remain unresolved until reviewed. The 10 September
  [release plan](../release-plan.md) uses daily owner cost review for the small pilot and defers
  new monitoring infrastructure. The later combined review passed `PASS_INTERNAL_BETA_ONLY` at
  `2026-09-10T11:25:45Z`, as recorded in the [manual review register](#manual-review-register).
  AI remained disabled at that beta checkpoint; the separately approved v13 activation followed.
  Physical protected-call proof and public-release requirements remain open, and
  operations evidence must be refreshed before upload or after a change. The ordinary diagnostic's
  service-identity correction passed
  live read-only verification at `2026-09-09T00:05:29Z`; the unchanged v12 runtime then returned
  OPEN `styling-disabled`.
  It connects as `wardrobe`, requires real/effective UID and GID 10001 and suppresses bytecode
  writes with `-B`. The earlier `styling-budget-evidence-open` result remains historical evidence.
  Preserve the existing ledger, limits, charges and uncertainty for every recovery. The same
  immutable image has now demonstrated reading that ledger after restart; pre-budget v10 remains
  ineligible for normal rollback. See the
  [approved setup](internal-testflight-runbook.md#approved-disabled-budget-setup--2026-09-08) and
  [launch-readiness follow-up](internal-testflight-runbook.md#launch-readiness-follow-up--2026-09-09).
- **Retained release compliance:** Repository enforcement and the historical Gmail-free Fly v10
  deployment were verified; Fly provider and manual-operations boundaries are explicitly accepted; the v10
  post-change review, late historical v9 review, historical v8/v7 reviews, build-4 signed archive
  and Apple distribution, historical build-5 distribution, historical build-6 production-signed archive
  and Apple distribution, and Gmail-free public support/privacy/Terms routes are retained. The required v9 post-deploy/pre-
  upload review was missed and is not backdated; the late review records that process miss while
  restoring current operational evidence. The build-4 and build-5 identity-safe handoffs are
  complete. Clean build-5 QA exposed a notification-tap crash, so build 5 is consumed and non-
  promotable. Build 6 is strictly verified, processed, assigned only to the intended internal group,
  and clean-tested through the fixed reminder tap. Its final identity-safe deletion/reinstall and
  new anonymous enrollment are complete. A 2026-08-28 owner-supplied Dark Mode screenshot separately
  confirmed that the **Allow AI styling** title is approximately 21 points right of center and its
  sampled `#C2DFFC` fill against white is approximately `1.38:1`, making build 6 non-promotable.
  PR #31 has since merged and verified the replacement control implementation. At the earlier
  build-selection checkpoint on 2026-08-29, a signed-in TestFlight **Build Uploads** view showed
  build 6 as the highest upload and
  **Complete**, with build 7 absent. Build `1.0.0 (7)` is selected with `MARKETING_VERSION = 1.0.0`,
  and source configuration is prepared for accepted builds `4,5,6,7`. PR #34 merged the runtime
  remediation; the exact merged Linux/AMD64 image deployed as completed Fly v10 at
  `2026-08-29T01:52:47Z`, and its health/configuration/storage/snapshot plus payload-free review
  passed at `2026-08-29T02:21:41Z`. The build-7 exact-source regression has also passed. The
  `04:21:50Z` review and `07:15:57Z` archive are retained as timing-stale/non-uploadable evidence;
  the earlier development-signed archive is separately invalid/non-uploadable. A fresh full review
  completed at `11:02:18Z`, followed by the distinct final Apple Distribution archive at
  `11:03:10Z` and strict verification at `11:04:02Z`. The signed-in `11:05:38Z` Build Uploads
  refresh showed build 6 highest and **Ready to Submit**, with build 7 absent. Snapshot-list expiry,
  deletion-specific restore/non-return and clean physical Dark Mode visual retest were incomplete
  at that archive-era checkpoint.
  The 10 September beta-only review and separately approved validation/upload completed; Apple
  processing, `Family` internal assignment and saved/reloaded AI-disabled notes are verified.
  The [11 September checkpoint](internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial)
  subsequently records approved server/local deletion, clean installation and scoped local-beta
  QA. Post-deletion and post-clean-first-launch aggregates were zero; the bounded log check
  observed one deletion-success marker. No intermediate post-uninstall sample was taken.
  The monitored 25/28 August snapshots were later observed absent from the customer-visible list.
  The 10 September Build-7 pre-deletion snapshot's later disappearance and deletion-specific
  recovery/non-return were not proven. On 11 September the owner explicitly waived only that
  evidence sub-gate for the Free Singapore v1 and accepted the residual risk described below.
  Neither this evidence nor delivery authorizes AI activation or public submission.

This is the approved production policy for Wardrobe Stylist's developer-controlled backend
authentication store, separate aggregate AI budget/reservation store, application logs, manual
operations, and Fly volume snapshots. It is the source of truth for the APP-009 retention,
deletion, logging, and operations gate. The [12 September review](ai-pilot-privacy-review-20260912.md)
records completed APP-016 provider/consent reconciliation and publication of the policy and Apple
answers, including the aggregate store.

The limits below are requirements, not claims that every control is already enforced. The
[compliance checklist](#compliance-and-release-evidence) distinguishes verified behavior from
remaining work. APP-009 stays open until every other unchecked release requirement is implemented
and evidenced. The snapshot/recovery item is a named owner-waived exception for the Free Singapore
v1, not a passing check or closure of APP-009. The [release plan](../release-plan.md) assigns that work to the internal beta, AI
activation and public-release milestones; waiting privacy/recovery evidence does not stop
unrelated beta preparation or visual QA and must not be marked complete prematurely.

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
server-security-data deletion remains within 24 hours, and an isolated restore volume must still be
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
identifiers, credentials, exact billing data, screenshots, or provider response bodies. Reassess
operational adequacy before expanding the pilot, paid operation, or any availability commitment.
The 10 September reset retains daily owner cost review for the initial small pilot; reassessment
does not automatically require the deferred monitoring runner or a new alert service.

An owner-triggered local helper may automate repeatable read-only collection without reversing the
decision against continuous alerting. `backend/verify_production_operations.py` can pass only from
clean synchronized `main`; a different or dirty source remains `OPEN` while the other read-only
checks continue. It compares the locked archive and deployment source, captures supported Fly,
Docker, SQLite, and public HTTPS responses in memory, and emits only fixed check/result codes plus
the newest safe snapshot UTC/status/retention. Missing, malformed, stale, timed-out, or weaker
evidence is `OPEN`; raw provider output is never copied into the report. The helper does not probe
unauthenticated `/recommend`, because that path consumes durable abuse-rate state, and it never
deploys, scales, restores, deletes, uploads, or changes App Store assignment.

For the internal beta, the explicit `internal-beta-ai-disabled` purpose requires AI to remain
disabled with an intact, below-warning, idle budget store. Every other required check must pass.
That beta-only result neither clears AI activation nor authorizes public submission or upload.
The default `ai-launch` purpose remains strict and requires the enabled-state checks; use it
after separately approved activation, not as a prerequisite that demands AI already be enabled.

The helper cannot convert the whole review into an offline test. Fly's official response-class
metric remains a signed-in live check when no supported aggregate API is available, and a current
log-buffer scan alone remains insufficient. Anthropic's configured limit, spend band, expected
model/key series, and saturation state and App Store Connect's current Build Uploads state likewise
remain signed-in live checks. A same-session fixed-field TOML may combine those observations with
the automated report; its maximum age is 30 minutes, it is gitignored, and it contains exactly:

```toml
checked_at_utc = "REPLACE_WITH_CURRENT_UTC"
marketing_version = "COPY_EXACT_LOCKED_VALUE"
build_number = "COPY_EXACT_LOCKED_VALUE"
archive_cdhash = "COPY_EXACT_LOCKED_VALUE"
deployed_revision = "COPY_EXACT_LOCKED_VALUE"
official_fly_metrics = "pass"
anthropic_console = "pass" # or "warning", which blocks upload
app_store_connect = "pass"
```

Copy the four candidate fields exactly from `backend/production-operations.toml`; the helper rejects
evidence for any other archive or deployed revision. The file is an operator attestation, not proof
that the consoles were inspected. Never create it before the checks, add raw values or screenshots,
or add an owner-approval field. Explicit upload
approval remains a separate action after the combined preflight passes. After a pass, retain one
identifier-free row in the [Manual review register](#manual-review-register), including the fixed
results, remediation outcome, and next due. The gitignored TOML is only same-session input and does
not replace that long-lived compliance record.

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

On 2026-09-06 the owner approved a private launch spend/admission policy and owner-operated daily
monitoring. The separate September 8 approval applied the policy and activated private public-capacity
review bounds on disabled v12; its aggregate checks passed within that profile. Under the
10 September reset, the small pilot uses daily review of the AI ledger/provider spend, Fly invoice,
Cost Explorer and resource list, also repeated after configuration changes or reported problems.
This daily cost routine supplements the full operations-review cadence above. The owner must be
available for it or arrange a reviewed alternative. Retain the approved private resource envelope,
warning/hold triggers, discrepancies and unknown billing coverage. Manual review has detection
delay; traffic is not bounded by tester count, storage charges continue after compute stops, and
the hosting target is not an enforced invoice cap. See the
[hosting policy and response](../fly-spend-controls.md).

Provider notifications remain useful supplements with delivery unproven. Hourly GitHub/Healthchecks
automation and complete edge-counter coverage are deferred improvements, not automatic beta or AI
activation gates. Provider-terms/consent review and privacy publication passed on 12 September.
The disabled limits/key/ledger checks, bounded activation approval and enabled-state verification
completed on 12 September. The protected-device styling call remains pending; preserve the
approved disable-on-failure response and daily review.
The AI-disabled beta and separate AI pilot do not close the public release's applicable privacy,
deletion/recovery and App Store requirements. Historical single-user reviews do not replace fresh
evidence for the declared milestone.

This policy does not settle:

- local iPhone data, which is covered by the app's Privacy & Data controls;
- any separately approved future Google/Gmail access or retention; public v1 contains no such
  capability; or
- Anthropic request retention, training, human-access and deletion terms, which are documented
  separately in the completed [12 September review](ai-pilot-privacy-review-20260912.md), not
  governed by this developer-store policy.

## Scope and data minimization

Backend persistence is limited to minimum App Attest authentication/security metadata and separate
aggregate AI budget/reservation metadata. The authentication store may contain only:

- one-time challenge IDs and 32-byte challenge secrets;
- App Attest key IDs, verified public keys, anonymous installation IDs, counters, App ID and
  environment, and optional signed validation-category/build values;
- the opaque Apple attestation receipt associated with the installation;
- session IDs and one-way bearer-token hashes; and
- bounded rate-window scopes, counts, timestamps, and keyed HMAC subject hashes.

The opaque Apple receipt is App Attest security metadata, not a Gmail purchase receipt. It follows
the installation record's lifecycle and remains untrusted for fraud decisions unless its separate
Apple receipt checks are implemented and evidenced.

The separate budget store may contain only a month identifier, aggregate charged-unit/admission
totals, approved limits, model/pricing/token-bound policy, halt state, and random pending-reservation
IDs with month, bounded token amounts, charged units and uncertainty flags. It contains no
installation or human-account identifier. Completed reservations are removed; unresolved exposure
stays conservatively charged until separately reconciled. Individual server-security deletion does
not reset this global accounting or restore an allowance. See the
[spend-control rules](../ai-spend-controls.md) and
[data inventory](app-privacy-data-inventory.md); the reconciled public declarations were published
on 12 September.

Neither database may contain Gmail message or purchase-receipt content, wardrobe data,
photos, model prompts or responses, OAuth credentials, raw bearer tokens, App Attest private keys,
or raw IP addresses. Wardrobe request payloads may exist in process memory only for the request
being served and must not be written to application logs or durable application storage.
Provider processing follows the separately reviewed standard terms recorded in the
[12 September privacy review](ai-pilot-privacy-review-20260912.md).

## Required retention schedule

“Purge” means the record is absent from the active logical database and no longer usable. A
completed active-database deletion must also checkpoint/truncate relevant SQLite WAL state using a
tested maintenance procedure. It does not claim that bytes have disappeared from an encrypted
snapshot when that snapshot leaves the customer-visible listing.

| Data | Approved limit / accepted provider boundary | Current repository/production truth |
|---|---|---|
| Wardrobe request payloads | Request lifetime only; no application persistence | Current routes do not persist payloads. Review guardrails pin the exact auth schema, block common file/database persistence patterns and direct auth-store use from payload modules, and allowlist current application log calls. Anthropic/provider terms remain separate evidence |
| Aggregate AI budget and unresolved reservations | Preserve the global accounting state and uncertain liability; individual security-data deletion does not reset it | Fly v13 uses a separate v2 ledger on the existing encrypted volume. Its singleton month/accounting row and random pending reservations contain no installation, wardrobe, prompt or response data. Rollover carries unresolved exposure conservatively; completed reservations are removed and uncertain work requires separate reconciliation. The store is subject to the volume’s unchanged 14-day snapshot policy; the policy check is not budget-specific snapshot or restore proof. Public disclosure and Apple classification were reconciled and published on 12 September |
| App Attest challenges | Valid for 5 minutes; purge no later than 70 minutes after issue | Fly v13 retains one-minute deadline maintenance on the original minimum-one-Machine topology, with cold-start lookahead and repeat-until-drained bounded transactions |
| Session-token hashes | Valid for 15 minutes; purge no later than 20 minutes after issue | Fly v13 retains one-minute deadline maintenance on the original minimum-one-Machine topology, with cold-start lookahead and repeat-until-drained bounded transactions |
| Rate-limit subject hashes | Challenge window plus 5 minutes; hourly windows no later than 65 minutes after window start | Only keyed HMAC subjects persist; expired windows are purged by request admission and Fly v13's retained one-minute maintenance loop |
| Active installation metadata, verified public key, counter, and opaque Apple receipt | 90 days after the last successful authenticated request | `last_seen_at` advances after successful enrollment, assertion renewal, or bearer authentication; Fly v13 retains deadline purging of inactive installations and cascading deletion of their sessions |
| Revoked installation metadata | 30 days after revocation | Fly v13 retains deadline purging of revoked installations and cascading deletion of their sessions. Anonymous identities are not linked, so this applies only to individually revoked records |
| Verified server-data deletion request | Remove live installation, sessions, and associated auth rows within 24 hours | `POST /auth/app-attest/delete` requires a fresh one-time deletion assertion and synchronously deletes the proven installation, key-bound challenges, sessions, and rate rows derived with the current HMAC secret. Merged replacement source persists the post-dispatch deletion fence across termination/relaunch and retains its local key only for an idempotent retry until deletion is confirmed; historical `dd3d990` fenced only the running actor. Any unlinkable pre-rotation rate hash expires under the 65-minute outer limit. Fly v10 enforcement and historical build-4 archive/upload evidence are verified. The build-4, build-5, and final build-6 identity-safe handoffs each preserved proof of possession through server deletion, returned live aggregates to zero, then deleted local data and the app before the next clean install. Build 6's final handoff observed `1/0/0` before deletion, exactly one bounded deletion marker, and `0/0/0` after deletion and uninstall; explicit Style after reinstall enrolled a new anonymous identity |
| Automatic or manual auth-volume snapshots | Customer-visible listing for 14 days; no developer-created or customer-configured monthly/indefinite archive. Separate provider all-copy purge timing is accepted as undisclosed | Fly v13 retains automatic 14-day snapshots on the original volume; the 2026-09-08 configured-but-disabled review passed the fresh-snapshot policy check. The `2026-08-23T07:34:23Z` successful snapshot, status `created`, retention 14 days, enabled the build-5 handoff. The eligible `2026-08-25T07:35:53Z` snapshot with the same status and retention enabled the completed build-6 handoff. The archive-era reviewed snapshot was `2026-08-28T07:37:13Z`, status `created`, retention 14 days. A read-only check at `2026-09-11T08:11:59Z` found the monitored 25/28 August snapshots absent from the customer-visible list. The Build-7 pre-deletion snapshot from `2026-09-10T07:48:53Z` was still customer-visible with status `created` and 14-day retention in a later same-day check, when the owner waived further listing/recovery evidence. Fly says a snapshot stops appearing in the snapshot list at the configured deadline, but does not publish separate purge-completion, replica, or backup semantics; that snapshot's later listing disappearance and deletion-specific restore/non-return were not observed and are accepted residual risk for Free Singapore v1. Fly Security summarized optional DPA termination periods of 30 days for personal-data deletion and 90 days for residual encrypted backups, but the account has no active DPA and those periods are not active per-snapshot guarantees |
| Temporary restore volume | Delete within 24 hours after the rehearsal or incident closes | On 2026-08-19 a production snapshot was restored cross-app into a secret-free temporary app with no public IP or service. A one-shot Machine remounted the source read-only and reported schema v4, SQLite integrity `ok`, zero foreign-key errors, and zero rows in each of the four auth tables. The Machine auto-destroyed; the encrypted temporary volume and empty app were then deleted, and control-plane absence was verified within 391 seconds of volume creation. This proves attended list removal, not physical-media purge |
| Wardrobe application access logs | None | Fly v13's single UID-10001 Uvicorn process retains `--no-access-log`, and a regression pins that production command |
| Developer-emitted application security events | 7 days maximum | Application-owned event fields are minimized and tested. Fly v13 retains application `INFO` only for the non-propagating `app.auth.service` logger while other application INFO and access logs remain off. Historical bounded observation captured clean build-5 registration/assertion events, the build-4 deletion event, and exactly one final build-6 deletion marker plus one post-reinstall registration marker. Protected `/recommend` intentionally has no developer success event and uses aggregate admission plus client-result evidence. Fly retains the customer-visible stream for seven days, which is not configurable per app |
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

This installation-specific deletion leaves the separate aggregate budget/reservation ledger
intact. That ledger has no installation identifier and preserves global charges and unresolved
exposure independently of local deletion, server-security deletion, reinstall or re-enrollment.

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
Recreating auth state must not recreate or clear the separate budget ledger; preserve its approved
limits, charges and unresolved exposure. Keep AI disabled if budget recovery cannot establish
consistent accounting.

An eligible automatic snapshot created at `2026-08-22T07:33:23Z` reported `created` with 14-day
retention after the build-4 TestFlight enrollment. Build 4's proof of possession remained available
after build 5 appeared installed in place unexpectedly. The owner used the assertion-verified
server deletion control; exactly one bounded `installation_deleted` marker appeared and live
installations, sessions, and challenges reached `0/0/0`. Local data and the app were then deleted,
and build 5 was installed cleanly.

Build 6 likewise appeared installed in place before the planned build-5 handoff, but inherited
proof remained available. A successful post-enrollment snapshot at `2026-08-23T07:34:23Z`, status
`created`, retention 14 days, cleared that gate. Server deletion returned the live aggregates to
`0/0/0`; local data and the app were deleted; and build 6 was installed cleanly.

The later `2026-08-25T07:35:53Z` snapshot, also `created` with 14-day retention, enabled the final
Build 6 handoff. The owner-controlled sequence observed `1/0/0` before server deletion, exactly one
bounded deletion marker, and `0/0/0` after deletion and uninstall. Reinstall and local-only actions
remained at zero; explicit Style at `2026-08-28 17:17 SGT` created a new anonymous installation and
session. These sequences close the live build-4, build-5, and build-6 handoffs, not snapshot-list
expiry or deletion-specific restore/non-return evidence. Those evidence items were later owner-
waived only for the Free Singapore v1.

Restore work must use an isolated, non-serving volume/Machine without application secrets. Record
only aggregate table counts and integrity results, then destroy the temporary restore volume within
24 hours. Never retain raw database copies in release evidence.

On 2026-09-11, after the monitored 25/28 August snapshots were observed absent, the owner explicitly
waived waiting for the still-listed 10 September Build-7 pre-deletion snapshot and performing the
deletion-specific recovery/non-return rehearsal for the Free Singapore v1. This exception does not
establish that snapshot's later customer-list disappearance, physical or all-copy purge, or that an
operator could not reintroduce a deleted identity by restoring an ineligible pre-deletion snapshot.
Fly's replica, backup and all-copy purge timing remains undisclosed. The existing safety rule remains binding: never restore a
pre-deletion snapshot into service; use fresh auth state and re-enrollment, preserve the separate
budget ledger, and keep AI disabled if its consistency cannot be established. The decision changed
no Fly resource, app or production/local data, installed app, or TestFlight state. It removes only
this evidence item as a Free Singapore v1 submission blocker.

## Manual operations and support

The owner performs the manual review defined above for the initial small pilot. A failed check
required for the declared milestone blocks that step until remediated and rechecked; only the
explicit internal-beta purpose accepts the verified intentionally disabled AI state described above.
Future automated alerting must follow the same payload and identifier prohibitions as
logs and requires the inventory, processor, retention, and public-disclosure review described in
[Logging and telemetry](#logging-and-telemetry) before activation.

The published support and privacy pages must name a monitored contact and response target. The
support process must distinguish device-local deletion from server auth-metadata deletion and must
meet the 24-hour live-deletion deadline after installation control is verified.

### Manual review register

This fixed-field table is the long-lived compliance attestation. It must never contain raw metric
values, logs, screenshots, identifiers, exact billing data, or provider response bodies.
Each row preserves its dated outcome and next actions as recorded then; use the
[release plan](../release-plan.md) for the current work order and deferred monitoring decision.

| Checked at UTC | Health / Fly | Snapshot | Volume | Auth / 5xx | Anthropic | Support | Overall | Remediation / next action | Next due |
|---|---|---|---|---|---|---|---|---|---|
| 2026-08-19T23:34:44Z | PASS · expected Machine/image | PASS · 14d · latest <36h | below-warning | OPEN · current-buffer markers only; aggregate 5xx unavailable | OPEN · public status page operational; console usage/spend-limit sign-in required | PASS · routing rehearsal confirmed | OPEN | Finish Fly aggregate 5xx and Anthropic console checks; no remediation applied | 2026-08-20 |
| 2026-08-20T00:15:07Z | PASS · expected Machine/image | PASS · 14d · latest <36h | below-warning | PASS · 7d HTTP view: 200/401/405 only, no 5xx series; selected-event bursts below threshold | PASS · public status operational · <80% of configured limit · expected models/keys | PASS · routing rehearsal confirmed | PASS | None; repeat before archive/upload | 2026-09-19 |
| 2026-08-21T01:11:43Z | PASS · exact Gmail-free Machine/image | PASS · 14d · latest <36h | below-warning | PASS · post-v6 2d HTTP view: 401/404 only, no 5xx series; bounded marker buffer empty | PASS · public status operational · <80% of configured limit · production key on expected model · no saturation warning | PASS · routing rehearsal confirmed | PASS | None; repeat before archive/upload | 2026-09-20 |
| 2026-08-21T03:30:33Z | PASS · exact Gmail-free Machine/image | PASS · 14d · latest <36h | below-warning | PASS · 2d HTTP view: 200/401/404 only, no 5xx series; bounded markers empty | PASS · public status operational · <80% of configured limit · production key on expected model · no saturation warning | PASS · routing rehearsal confirmed | PASS | Historical archive completed; later superseded by review fixes; repeat after replacement deploy and before upload | 2026-09-20 |
| 2026-08-21T06:00:21Z | PASS · exact reviewed v7 Machine/image | PASS · 14d · latest <36h | below-warning | PASS · 2d HTTP view: 200/401/404 only, no 5xx series; bounded marker queries empty | PASS · public status operational · <80% of configured limit · production key on Opus 4.8 · no saturation warning | PASS · routing rehearsal confirmed | PASS | None; repeat immediately before replacement-archive upload | 2026-09-20 |
| 2026-08-21T08:12:46Z | PASS · exact reviewed v7 Machine/image | PASS · 14d · latest <36h | below-warning | PASS · 2d HTTP view: 401/404 only, no 5xx series; bounded marker queries empty | PASS · public status operational · <80% of configured limit · production key on Opus 4.8 · no saturation warning | PASS · routing rehearsal confirmed | PASS | None; build-4 replacement archive validated/uploaded; resume monthly cadence | 2026-09-20 |
| 2026-08-21T11:09:20Z | PASS · exact reviewed v8 Machine/image | PASS · 14d · all listed created · latest <36h | below-warning | PASS · 2d HTTP view: 401/404 only, no 5xx series; bounded failure-event classes zero; lifecycle success not exercised | PASS · public status operational · <80% of configured limit · deployed Wardrobe key on Opus 4.8 · no saturation warning | PASS · pages/contact/target and retained rehearsal confirmed | PASS | None; repeat before archive/upload | 2026-09-20 |
| 2026-08-22T01:07:45Z | PASS · exact reviewed v8 Machine/image | PASS · 14d · all listed created · latest <36h | below-warning | PASS · 2d HTTP view: 401/404 only, no 5xx series; bounded failure-event classes zero; lifecycle success not exercised | PASS · public status operational · <80% of configured limit · deployed Wardrobe key on Opus 4.8 · no saturation warning | PASS · pages/contact/target and retained rehearsal confirmed | PASS | Build-5 archive completed; repeat immediately before validation/upload | 2026-09-21 |
| 2026-08-22T02:37:08Z | PASS · exact reviewed v8 Machine/image | PASS · 14d · all listed created · latest <36h | below-warning | PASS · no 5xx series · bounded failure-event classes zero · lifecycle success not exercised | PASS · public status operational · <80% of configured limit · current-month usage/cost only on expected Wardrobe model/key series · no saturation warning | PASS · pages/contact/target and retained rehearsal confirmed | PASS | Manual-review gate passed; final App Store Connect refresh still required; repeat after distribution | 2026-08-22 |
| 2026-08-22T03:30:33Z | PASS · exact reviewed v8 Machine/image | PASS · 14d · all listed created · latest <36h | below-warning | PASS · no 5xx series · bounded failure-event classes zero · lifecycle success not exercised | PASS · public status operational · <80% of configured limit · current-month usage/cost only on expected Wardrobe model/key series · no saturation warning | PASS · pages/contact/target and retained rehearsal confirmed | PASS | None; resume monthly cadence | 2026-09-21 |
| 2026-08-23T02:13:12Z | PASS · exact v9 Machine/image | PASS · automatic · 14d · latest <36h · no failed/unknown | below-warning | PASS · current 1h HTTP view: 200/401/404 only, no 5xx series; bounded failure classes zero | PASS · public status operational · <80% of configured limit · production key on Opus 4.8 · no saturation warning | PASS · pages/contact/target and retained rehearsal confirmed | PASS | Required v9 post-deploy/pre-upload review was missed; late review not backdated; repeat before any future archive/upload | 2026-09-22 |
| 2026-08-29T02:21:41Z | PASS · exact v10 Machine/image | PASS · automatic · 14d · latest <36h · no failed/unknown | below-warning | PASS · official 2d metric: 2xx/4xx only, no 5xx; bounded application failure classes zero; deployment-transition transport non-response reviewed | PASS · public status operational · <80% of configured limit · active Wardrobe use on Opus 4.8 · historical series inactive in 7d · no saturation warning | PASS · pages/contact/target/reciprocal links and retained rehearsal confirmed | PASS | None; repeat immediately before build-7 upload | 2026-09-28 |
| 2026-08-29T04:21:50Z | PASS · exact v10 Machine/image | PASS · automatic · 14d · latest <36h · no failed/unknown | below-warning | PASS · official 2d metric: 2xx/4xx only, no 5xx; bounded application failure classes zero | PASS · public status operational · <80% of configured limit · expected Wardrobe key/model · no saturation warning | PASS · pages/contact/target/reciprocal links confirmed | PASS | Review passed but did not immediately precede archive; resulting intermediate archive is timing-stale/non-uploadable | 2026-08-29 |
| 2026-08-29T11:02:18Z | PASS · exact v10 release/Machine/image · fresh registry match · zero High/Critical | PASS · automatic · 14d · latest <36h · no failed/unknown | below-warning | PASS · official 2d metric: 2xx/4xx only, no 5xx; bounded application failure classes zero | PASS · public status operational · <80% of configured limit · expected Wardrobe key/model · no saturation warning | PASS · pages/contact/target/reciprocal links confirmed | PASS | Final build-7 archive completed; repeat immediately before upload | before upload; otherwise 2026-09-28 |
| 2026-09-07T10:39:08Z | PASS · exact v11 source/image/platform · original healthy Machine/volume · zero High/Critical · AI disabled | PASS · automatic · 14d · fresh | below-warning | PASS · schema v4/integrity · single-user band only · official last-2-days metric: 200/404, no 5xx · bounded logs | OPEN · partial console check: active key, spend below warning, no last-24h saturation; low prepaid credit, no alert rows visible; delivery unverified | PASS · public pages verified | OPEN · disabled scope only | Historical checkpoint: budget unprovisioned and policy unapplied; later September 8 setup supersedes those states; no paid calls | historical checkpoint; superseded below |
| 2026-09-08T09:32:49Z | PASS · v12 · same scanned image and original healthy Machine/volume · AI disabled | PASS · automatic · 14d · fresh | below-warning | PASS · schema v4/integrity · approved public-capacity band · bounded logs; fresh full manual metrics still required | OPEN · configured limits/notification settings and usable credit verified · auto-reload off · real delivery unverified | PASS · public pages verified | OPEN · configured-but-disabled setup passed; full pre-upload remains open | Preserve applied policy and existing zero ledger; correct ordinary diagnostic ownership context, prove monitoring/delivery and reconcile Fly billing feeds before enablement | before enablement or upload; full review remains open |
| 2026-09-10T11:25:45Z | PASS · unchanged v12 runtime/source/configuration · recovery image/scan verified · AI disabled | PASS · automatic · 14d · latest created 2026-09-10T07:48:53Z | below-warning | PASS · auth/store and bounded logs · official 2d metric 200/404, no 5xx | PASS for disabled beta · public status operational · configured spend below warning · expected workspace/key unexpired · no observed production usage or saturation | PASS · public pages | PASS_INTERNAL_BETA_ONLY · intact, below-warning, idle ledger · styling-disabled expected | Same-session App Store Connect check passed with build 7 absent; refresh before upload/after change. Exact upload approval, processing/assignment, physical QA, AI activation and public release remain open; no deployment, paid call or upload | daily cost review 2026-09-11; full review before upload/after change |
| 2026-09-12T04:28:57Z | PASS · v13 · same image and original resources · bounded AI enabled | PASS · automatic · 14d · fresh | below-warning | PASS · auth/store · approved capacity band · bounded events · official 2d HTTP has no visible 5xx | PASS with approved Cowork-only exception · API/Console operational · aggregate status remains OPEN · limits/credits/key/auto-reload verified · no saturation | PASS · public pages | PASS with scoped owner exception · enabled intact idle ledger | One owner-triggered protected TestFlight call pending; disable on failure, preserve liability; no paid agent call or public submission | daily review 2026-09-13; sooner after problem/change |

Following the 10 September pre-upload review, the owner approved the exact package. Xcode
validation passed and Content Delivery recorded normal-route build-7 upload success at
`2026-09-10T11:47:49.338Z`; Xcode's terminal success was observed at `11:48:11Z`.
Apple processing and `Family` internal assignment were verified at `11:50:45Z`, with one group
tester and no individual testers; approved notes persisted after reload at `11:51:22Z`. The
group's existing **Automatic for Xcode Builds** setting was preserved. This later
upload is recorded in the [runbook](internal-testflight-runbook.md#build-7-distribution--2026-09-10)
and is not a new operations review, AI activation or public submission.

The 2026-09-07 row retains the observed disabled-deployment checks and partial signed-in views.
At that checkpoint, the complete helper's manual-review inputs remained open, including App Store
Connect; that historical row does not claim a combined pre-upload pass or verify alert delivery.

### Processed build-4 aggregate evidence and identity-safe handoff — 2026-08-21/22

The clean TestFlight install on iPhone 16 Pro/iOS 26.6 took the production installation aggregate
from 0 to 1. First assertion/protected calls and a cold assertion/session renewal succeeded. Online
recovery showed `Styled 17:24`; the assertion aggregate advanced 1→2 and the current recommendation-
installation rate window 0→1. Signed runtime category/build fields were absent as expected on iOS
26.6 and are not enforcement evidence. Offline remote styling failed closed while local features
remained usable.

The bounded Fly marker stream had no `registration_succeeded` or `assertion_succeeded` matches
because live v7 suppressed INFO lifecycle events during the original build-4 run. Fly v8 then
deployed the logging fix and source TestFlight allowlist for builds `4,5`. An eligible automatic
snapshot created at `2026-08-22T07:33:23Z` reported `created` and 14-day retention. Build 4's proof
of possession remained available after build 5 appeared installed in place unexpectedly, and the inherited
identity's assertion-verified server deletion produced exactly one `installation_deleted` marker
and `0/0/0` installations/sessions/challenges. Local data and the app were then deleted, and build
5 was clean-installed. This is the completed build-4 live handoff; it is not migration evidence and
does not close snapshot listing expiry or deletion-specific restore/non-return evidence. Those
evidence items were later owner-waived only for the Free Singapore v1.

### Processed build-5 clean physical evidence and release blocker — 2026-08-22 (PARTIAL)

On iPhone 16 Pro/iOS 26.6, first launch showed no account/login and an empty wardrobe. Offline Demo
Mode passed; Camera and Photo Library items saved; and the complete disposable catalog flow covered
manual add, edit, favorite/filter, archive/restore, search, and delete. Online Style at `16:30`
created the clean installation and produced a bounded `registration_succeeded` observation. Cached
relaunch passed. Restyle at `17:04` renewed via assertion and produced `assertion_succeeded`; a
failed offline Restyle kept the cached look visible; offline Wear this/History passed; and the local
reminder was delivered. Protected `/recommend` remained separately aggregate/client-evidenced.

Tapping that delivered notification crashed at `2026-08-22T17:15:14+08:00`. The exact build-5
dSYM matched. Safe symbolication identified `SIGABRT`, a UIKit state-restoration assertion, and an
app frame in the `DailyReminderNotificationRouter` `didReceive` async bridge. Build 5 is consumed
and non-promotable; do not repeat the tap. Its app and live identity were retained until the later
eligible handoff completed. The fix merged
through PR #27; merged-source gates, Fly v9, strict build-6 archive verification, normal-route
Xcode validation/upload, Apple processing, `Family` assignment, and tester-note checks passed.
Build 6 is consumed. Retain no raw identifiers, tokens, request
bodies, database rows, wardrobe payloads, crash-report bodies, or log samples.

### Processed build-6 clean physical evidence and final handoff — 2026-08-24 and 2026-08-28 (PARTIAL)

Clean build 6 passed Gmail-free first launch, empty local state, offline Demo, Camera and Photo
Library saves, the catalog matrix, production registration, cold assertion renewal, online styling,
explicit cached-look restoration after offline relaunch, failed-Restyle preservation, offline Wear/
History, reminder delivery, and delivered-reminder tap without a crash or local-state loss. The
initial **Style a look** state before an explicit cached restore is the no-call-on-tab-appearance
design, not cache loss.

The later automatic snapshot at `2026-08-25T07:35:53Z` reported `created` with 14-day retention and
was eligible for the final owner-controlled handoff. Before deletion, the live installation/session/
challenge aggregate was `1/0/0`. **Delete Server Security Data** produced exactly one bounded
`installation_deleted` marker; post-deletion and post-uninstall aggregates were `0/0/0`. Clean
reinstall, first launch, local item additions, and styling consent alone kept that zero baseline.
The explicit **Style a look** action at `2026-08-28 17:17 SGT` then created one new anonymous
installation and one active session, with zero pending or failed challenges, one completed
challenge, and one bounded registration marker. Signed runtime category/build fields were absent
as expected on iOS 26.6; this is not iOS 27+ enforcement evidence. This closes deletion/reinstall
and new enrollment only. Snapshot-list expiry and deletion-specific restore/non-return were not
proven and were later owner-waived only for the Free Singapore v1.
Retain no raw identifiers, tokens, request bodies, database rows, wardrobe payloads, or log samples.

## Compliance and release evidence

Verified as of 2026-08-29:

- [x] The auth-store schema excludes receipt/wardrobe payloads and raw IP addresses.
- [x] Session bearers are stored only as hashes; rate subjects are stored only as keyed HMACs.
- [x] Challenges and sessions become unusable after five and fifteen minutes respectively.
- [x] Application security-event fields are bounded and payload/identifier-free, with regression
  coverage.
- [x] Deploy and verify the payload-free App Attest INFO lifecycle-marker logging configuration and
  TestFlight build `4,5,6` allowlist. Historical Fly v9 served exact clean merged source
  `de7c540275fb16e61aabf1884538b18cf6edf76f`; its build, local-only official Alpine secdb
  comparison, locked `pip-audit`, runtime, configuration, health, and route gates passed. The secdb
  comparison found zero unfixed advisories; no external private-image/SBOM scan was run. Fly v10's
  current `4,5,6,7` deployment and post-change review are recorded below.
- [x] Observe real `registration_succeeded` and `assertion_succeeded` events during clean build-5
  QA and `installation_deleted` during the preceding build-4 identity-safe handoff. Style at
  `16:30`, Restyle at `17:04`, and exactly one deletion marker supplied the bounded observations;
  the deletion aggregate reached `0/0/0`. Protected `/recommend` intentionally remains aggregate/
  client-evidenced; this marker evidence does not close snapshot-list expiry or restore proof. Those
  evidence items were later owner-waived only for the Free Singapore v1.
- [x] The production auth volume is encrypted and Fly reports a configured 14-day snapshot-listing
  period. The monitored 25/28 August snapshots were observed absent; the 10 September Build-7 pre-
  deletion snapshot's later disappearance is unproved and owner-waived only for Free Singapore v1.
- [x] Structural review guardrails pin the exact auth schema, block common durable-write patterns
  and direct auth-store use from payload modules, allowlist current application log calls, and
  exercise payload-free error behavior. These guardrails supplement review; they are not a proof
  against every possible future persistence mechanism.
- [x] A one-minute lifecycle task starts and stops with FastAPI, uses cold-start lookahead, and
  repeats bounded cleanup transactions until every eligible challenge, session, and rate row is
  drained. Fly v10 runs the committed minimum-one-Machine production topology.
- [x] Repository cleanup enforces 90-day inactive-installation and 30-day revoked-installation
  limits, cascades sessions, uses SQLite secure deletion, and checkpoints/truncates WAL.
- [x] A fresh one-time App Attest deletion assertion synchronously deletes the proven installation;
  the separate in-app Privacy & Data control must persist its pending-deletion fence across app
  termination/relaunch after proof dispatch, retain the existing credential only for ambiguous-
  response retries, clear that reference only after confirmed server deletion/absence, and only
  then allow a future remote-AI request to enroll a new anonymous identity. PR #19 merged the
  persisted fence and relaunch/retry coverage in source
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`; historical build-4 signed-archive and Apple upload/
  processing evidence are retained. The build-4 handoff then passed against exact Fly v8 after an
  eligible snapshot: deletion emitted exactly one success marker and live aggregate counts reached
  `0/0/0`. Build 5 later completed the same ordered handoff. Build 6 completed its final ordered
  handoff after the eligible `2026-08-25T07:35:53Z` snapshot: the pre-deletion aggregate was
  `1/0/0`, exactly one bounded deletion marker was observed, and post-deletion/post-uninstall
  aggregates were `0/0/0`. Reinstall and local-only actions preserved zero; explicit Style at
  `2026-08-28 17:17 SGT` enrolled a new anonymous installation and active session. No iOS 27+
  category/build enforcement is claimed from the iOS 26.6 runtime-field absence.
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

Required before APP-009 can close, except for the explicitly owner-waived snapshot/recovery evidence
item recorded below:

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
  `2026-08-21T01:20:25Z`. At that recorded 2026-08-21 checkpoint, the v6 digest was the required
  Gmail-free recovery baseline and resolved again after fresh authentication during the
  `2026-08-21T03:14:10Z`–`03:30:06Z` pre-archive window. The payload-free post-deploy manual review
  passed at `2026-08-21T01:11:43Z`.
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
  At that historical v7 gate, Gmail-free v6 digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  was treated as the freshly scan-clean recovery baseline; both exact v7 and v6 digests resolved
  after fresh registry authentication at `2026-08-21T06:06:01Z`.
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
  image. At this `2026-08-21` v8 checkpoint, one healthy Singapore Machine ran with
  `min_machines_running = 1`; production App Attest
  configuration is category `2` and builds `4,5`; required secrets are deployed without retaining
  values; and the encrypted 1 GB volume was in the below-warning usage band. At that Aug-21
  checkpoint, all listed snapshots were created, the newest was `2026-08-21T07:32:23Z`, retention
  was 14 days, schema v4 integrity was `ok` with zero foreign-key errors, and the aggregate state was
  one installation, zero sessions, and zero challenges. Later Aug-22 snapshot and handoff evidence
  is recorded above. The
  single UID-10001 Uvicorn process uses the targeted non-propagating auth-service logger with access
  logging disabled. Health returns `200`, `/extract` returns `404`, unauthenticated `/recommend`
  returns `401`, and the OpenAPI route set matches the reviewed source. Former v9 and v8 references
  remain historical operational evidence. Separately, the former v7 digest
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
  and Gmail-free v6 recovery digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  were freshly re-resolved and scanned across 90 packages with zero critical/high vulnerabilities
  at their recorded historical checkpoint. Those former references are timestamped historical
  evidence only.
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
- [x] Publish and reload-verify App Store Connect privacy answers on 12 September: Device ID,
  Other Diagnostic Data and Product Interaction use App Functionality; Other User Content uses
  App Functionality and Product Personalization. All four are linked and not tracking. The public
  policy also discloses the separate aggregate ledger and its retention/deletion behavior.
  See the [publication evidence](ai-pilot-privacy-review-20260912.md). Reassess if any processor,
  purpose or data flow changes.
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
- [x] Repeat the payload-free review against exact Fly v8 immediately before the build-5 archive.
  The pass completed at `2026-08-22T01:07:45Z` after reconfirming the exact image/source,
  healthy Singapore Machine, encrypted volume, 14-day snapshot and below-warning usage bands,
  two-day HTTP surface without a 5xx series, zero bounded failure-event classes, operational
  Anthropic status, spend below 80% of a configured limit, the deployed Wardrobe key on Opus 4.8,
  no saturation warning, and monitored support routing. Lifecycle successes were not exercised in
  that review, so marker observation was open at that checkpoint and was closed later by the
  physical flows recorded above. No raw sample, identifier, exact billing amount, credential,
  screenshot, secret value, or provider body is retained. Repeat again immediately before
  validation/upload; otherwise resume the monthly cadence no later than 2026-09-21.
- [x] Complete the same-session payload-free review against exact Fly v8 before build-5 validation
  and upload. The review ran from `2026-08-22T02:27:21Z` through `2026-08-22T02:37:08Z`; the fixed health,
  snapshot, volume, auth/5xx, Anthropic, and support checks all passed. No lifecycle success was
  exercised during the review; the later physical flows closed marker observation. No raw sample,
  identifier, exact billing amount, credential, screenshot, secret value, or provider body is
  retained.
- [x] Complete and record the separate payload-free post-distribution review against exact Fly v8.
  The review ran from `2026-08-22T03:19:20Z` through `2026-08-22T03:30:33Z`; upload occurred during
  that interval, so this is retained as post-distribution evidence rather than backdated pre-upload
  evidence. The same fixed fields passed, while lifecycle success remained unexercised at that
  checkpoint; later physical flows closed marker observation. Resume the monthly cadence no later
  than 2026-09-21.
- [x] Record the late payload-free review against exact Fly v9. The required post-deploy and pre-
  archive/upload review was missed, discovered after build-6 distribution, and is not backdated.
  The `2026-08-23T02:13:12Z` review passed exact release/running-image and source equality, one
  healthy Singapore Machine, public health, automatic 14-day snapshots with the newest successful
  snapshot younger than 36 hours and no failed/unknown state, below-warning volume use, the current
  one-hour 200/401/404-only HTTP view with no 5xx series, zero bounded failure classes, operational
  Anthropic public status, spend below 80% of a configured limit, the active production Wardrobe
  key only on Opus 4.8, no saturation warning, and the published support/contact/response target
  plus retained routing rehearsal. A separate older Wardrobe-labelled key had no activity in the
  seven-day view; its earlier-month Haiku cost was reviewed as historical non-production usage, not
  current backend behavior. No raw metric, identifier, exact billing amount, key name/value, log
  sample, screenshot, or provider response is retained. Repeat the review before every future
  archive/upload and after every backend/configuration change. The historical v10 review's next
  due date was 2026-09-28; the current enabled v13 review and pending protected-call/public-release gates are recorded above.
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
- [x] Retain historical pre-archive build-5 regression evidence: 221 backend tests plus audit/Bandit/Ruff/
  mypy, 218 Swift unit tests, all 9 UI flows, 43 release-script tests, and Release simulator/
  artifact checks passed. After the tests-only request guard was strengthened to inventory stored
  properties including nil optionals and separately pin encoded keys, the full backend and iOS
  gates reran on the resulting tree with the same 221 and 218+9 counts; the uninterrupted iOS
  result bundle finalized at `2026-08-22T02:04:17Z` with no failure, skip, or retry. This local
  evidence is distinct from the signed archive retained below and does not prove upload or physical
  production App Attest behavior.
- [x] Retain exact build-5 signed-archive evidence. Fresh private-registry authentication
  re-resolved Gmail-free v6 recovery digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`, whose
  zero-critical/high scan completed at `2026-08-22T01:00:09Z`; the exact-v8 pre-archive review
  passed at `2026-08-22T01:07:45Z`; and App Store Connect showed builds 1–4 only at
  `2026-08-22T01:09:39Z`. Clean source context
  `695c562b7b18e4a0b7f8a72b814af59efdd0cf3a`, a documentation-only successor to frozen shipped
  source `4a75b99dcd49e818ad1d5b198e8c49abba702e18`, produced
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-5-695c562-appstore.xcarchive` at
  `2026-08-22T01:10:32Z` with Xcode 26.6 (`17F113`) and the iOS 26.5 SDK. The exact app is
  `1.0.0 (5)`, `com.tth.Wardrobe`, `iphoneos`, arm64, minimum iOS 18.0. The Apple Distribution
  signer and App Store profile `Wardrobe App Store App Attest 2026-08-21`
  (`2b11bc90-0194-4fe6-8dcc-413c6dc5ccd2`, expires `2027-08-21T02:07:47Z`) match the App ID
  prefix, team, bundle, and profile certificate; `get-task-allow` is false, beta reporting is
  active, no devices/all-devices are provisioned, the profile grants production App Attest, and
  the signed entitlement is scalar `production`. The strict verifier completed at
  `2026-08-22T01:11:17Z` with public HTTPS configuration, app privacy manifest, shared-bearer, and
  Gmail-free artifact guards passing. The separate non-emitting credential/removed-capability scan
  passed at `2026-08-22T01:12:01Z`, followed by deep signature verification at
  `2026-08-22T01:12:19Z`. App/dSYM UUID
  `DA20FD8D-64C3-3B7A-9990-19EAF050AF04` matches for arm64; executable SHA-256 is
  `a9f01231025874d331e76be40ebe6f493b3f36051902b66b0ad03c35206bb3b9`. At that stage this was not
  Organizer validation, upload, processing, assignment, or physical-device evidence; the later
  Apple distribution evidence is retained separately below.
- [x] Retain Apple validation/upload/processing and internal-assignment evidence for the exact
  build-5 archive. The same-session exact-v8 pre-validation review passed at
  `2026-08-22T02:37:08Z`, and the final App Store Connect refresh at
  `2026-08-22T03:16:16Z` still showed builds 1–4 only and build 5 absent. Xcode validation succeeded
  at `03:18:30Z` and the normal App Store Connect upload succeeded at `03:20:59Z`, each with zero
  warnings, errors, or information messages. Symbols were included; **Manage version and build
  number** and **TestFlight Internal Testing Only** were off. Processing reached **Ready to Submit**
  by `03:24:21Z`; the processed record shows `1.0.0 (5)`, bundle `com.tth.Wardrobe`, SDK `23F81a`,
  arm64 iPhone support, iOS 18.0 minimum, included symbols, no non-exempt encryption, production App
  Attest, `get-task-allow = false`, and beta reporting active. The build lists exactly the `Family`
  Internal Testing group with one tester and no individual testers, and its truthful What to Test
  wording is reproduced in the runbook. The post-distribution exact-v8 review passed at
  `03:30:33Z`. Build 5 is consumed. Later physical testing completed enrollment, assertion, and
  marker observation, but the notification tap crashed; build 5 is non-promotable.
- [x] From clean-installed processed build 5, repeat production enrollment and cold assertion/
  session renewal with bounded registration/assertion marker observation. Style at `16:30` and
  Restyle at `17:04` passed; protected `/recommend` was proved separately by aggregate admission-
  counter delta plus the visible non-cached client result. This does not make build 5 promotable.
- [x] Record the owner-approved snapshot/recovery evidence waiver for Free Singapore v1. On
  2026-09-11 the monitored 25/28 August snapshots were observed absent, while the 10 September
  Build-7 pre-deletion snapshot remained customer-visible with status `created` and 14-day
  retention. The owner accepted that snapshot's unproved later listing disappearance, all-copy
  purge and deleted-identity non-return through recovery. This check marks the waiver decision, not the missing evidence as passed;
  the fresh-auth-store recovery rule remains binding and every other APP-009 requirement retains
  its own status.
- [x] Confirm the build-6 **Allow AI styling** presentation failure. The 2026-08-28 owner-supplied
  Dark Mode screenshot places the title approximately 21 points right of center and measures the
  sampled `#C2DFFC` fill against white at approximately `1.38:1`. Build 6 is non-promotable; its
  completed identity and notification evidence remains valid.
- [x] Complete and verify the replacement control implementation. PR #31 rebase-merged app commit
  `b7e46e4` to clean `main` `e4a0ae2`. The title-only control is centered, full-width, and opaque;
  focused coverage pins enabled, pressed, and disabled contrast plus the screenshot UI assertion.
  Merged verification passed 221 backend tests plus audit/Bandit/Ruff/mypy, 226 Swift unit tests,
  all 9 UI tests, and 43 release-script tests; both GitHub iOS checks are green.
- [x] Select and source-prepare build 7 without claiming deployment. The signed-in TestFlight
  **Build Uploads** view on 2026-08-29 showed build 6 as the highest upload and **Complete**, with
  build 7 absent. Select `1.0.0 (7)`, retain `MARKETING_VERSION = 1.0.0`, and prepare source
  configuration for accepted builds `4,5,6,7`. At selection time, Fly v9 still accepted `4,5,6`.
- [x] Retain the archive-era deployment and review of the selected build-7 backend. Fly v10 accepted
  `4,5,6,7`; exact image, health/configuration/storage/snapshot, and payload-free review passed on
  2026-08-29.
- [x] Complete the build-7 exact-source regression. On clean synchronized main
  `f183f074d1a63a4ec46d6d34fa13979a2c8b1fdd`, 222 backend tests plus audit/Bandit/Ruff/mypy,
  226 Swift unit tests, all 9 UI tests, 43 release-script tests, and the Release simulator/artifact
  gates passed. The later documentation-only recovery correction does not change the verified iOS,
  backend, or shared source.
- [x] Retain the archive-era build-7 recovery reference. At
  `2026-08-29T03:31:57Z`, fresh private-registry authentication re-resolved the exact v10 immutable
  reference with the expected source identity and Linux/AMD64 architecture, and its zero-High/
  Critical scan passed. The former v6 reference's current platform/source identity was not
  independently proven, so it was ineligible for rollback or recovery. Exact v10 was the sole
  verified recovery reference at that checkpoint. Current disabled recovery uses the verified
  private immutable image retained by v12. The September 8 review verified that it reads the existing
  initialized ledger after restart; every later recovery must preserve and reverify the ledger,
  policy and uncertainty. Pre-budget v10 must not become a normal rollback target after cutover.
- [x] Complete the build-7 pre-archive review and signed-archive gate. The `04:21:50Z` review and
  `07:15:57Z` technically verified archive are retained as timing-stale/non-uploadable evidence;
  the earlier automatic-signing archive is development-signed and separately invalid/non-uploadable.
  A fresh full operations/recovery review against exact Fly v10 completed at
  `2026-08-29T11:02:18Z`, including a fresh private-registry match and zero-High/Critical Docker
  Scout scan. Clean synchronized main `0cc0fa7` then created the distinct final archive
  `Wardrobe-1.0.0-7-0cc0fa7-appstore-final-20260829T110218Z.xcarchive` at `11:03:10Z`; strict
  production App Attest/profile/identity, public-configuration, privacy, Gmail-free, non-emitting
  credential, deep-signature, and matching arm64 app/dSYM verification passed at `11:04:02Z`. The
  signed-in `11:05:38Z` post-archive Build Uploads refresh showed build 6 highest and **Ready to
  Submit**, with build 7 absent.
- [x] Validate and distribute only the exact verified build-7 archive. The 10 September beta-only
  review preceded separate owner approval and normal-route validation/upload. Apple processing,
  `Family` internal assignment and saved/reloaded AI-disabled notes are verified in the
  [distribution record](internal-testflight-runbook.md#build-7-distribution--2026-09-10).
- [x] Complete build-7 handoff, clean installation and scoped local-beta QA. The
  [11 September checkpoint](internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial)
  records the completed owner-controlled sequence and normal-state Dark Mode screenshot.
  Automated tests cover enabled/pressed/disabled contrast; retain unchanged device evidence.
  Do not repeat deletion, uninstall or routine QA. AI activation and public submission remain separate.
- [x] Retain the historical build-6 App Store Connect number check. Before changing version metadata
  or archiving that replacement, the `2026-08-22T10:02:31Z` signed-in TestFlight Build Uploads view
  showed builds 1–5 only, build 5 **Complete**, and no build 6. Build 6 is confirmed unused and
  selected; `MARKETING_VERSION` remains `1.0.0`. The subsequent completed normal-route upload
  consumes build 6; never reuse it.

The provider questions and redacted written outcome are recorded in
[`fly-data-retention-inquiry-draft.md`](fly-data-retention-inquiry-draft.md). The response proves
that Fly could not meet the former hard 24-hour provider raw-IP maximum; the owner explicitly
superseded that requirement on 2026-08-19. Retain the 11 September observation that the monitored
25/28 August snapshots were absent and the separate owner waiver for the still-listed 10 September
Build-7 pre-deletion snapshot and deletion-specific non-return evidence.

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
