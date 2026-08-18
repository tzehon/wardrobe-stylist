# APP-009 App Attest data lifecycle and logging policy

- **Decision approved:** 2026-08-18
- **Release compliance:** Repository enforcement complete; deployment/external evidence incomplete

This is the approved production policy for Wardrobe Stylist's developer-controlled backend
authentication store, application logs, alerts, and Fly volume snapshots. It is the source of
truth for the APP-009 retention, deletion, logging, and operations gate.

The limits below are requirements, not claims that every control is already enforced. The
[compliance checklist](#compliance-and-release-evidence) distinguishes verified behavior from
remaining work. APP-009 stays open until every unchecked release requirement is implemented and
evidenced.

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
snapshot before that snapshot expires.

| Data | Approved maximum | Current repository/production truth |
|---|---|---|
| Receipt and wardrobe request payloads | Request lifetime only; no application persistence | Current routes do not persist payloads. Review guardrails pin the exact auth schema, block common file/database persistence patterns and direct auth-store use from payload modules, and allowlist current application log calls. Anthropic/provider terms remain separate evidence |
| App Attest challenges | Valid for 5 minutes; purge no later than 70 minutes after issue | Repository enforcement runs one-minute deadline maintenance, with cold-start lookahead and repeat-until-drained bounded transactions; final-image deployment remains pending |
| Session-token hashes | Valid for 15 minutes; purge no later than 20 minutes after issue | Repository enforcement runs one-minute deadline maintenance, with cold-start lookahead and repeat-until-drained bounded transactions; final-image deployment remains pending |
| Rate-limit subject hashes | Challenge window plus 5 minutes; hourly windows no later than 65 minutes after window start | Only keyed HMAC subjects persist; expired windows are purged by request admission and the one-minute maintenance loop; final-image deployment remains pending |
| Active installation metadata, verified public key, counter, and opaque Apple receipt | 90 days after the last successful authenticated request | `last_seen_at` advances after successful enrollment, assertion renewal, or bearer authentication; repository cleanup purges inactive installations at the deadline and cascades their sessions; final-image deployment remains pending |
| Revoked installation metadata | 30 days after revocation | Repository cleanup purges revoked installations at the deadline and cascades their sessions; final-image deployment remains pending. Anonymous identities are not linked, so this applies only to individually revoked records |
| Verified server-data deletion request | Remove live installation, sessions, and associated auth rows within 24 hours | `POST /auth/app-attest/delete` requires a fresh one-time deletion assertion and synchronously deletes the proven installation, key-bound challenges, sessions, and rate rows derived with the current HMAC secret. Once the signed proof is dispatched, iOS immediately fences memory-only sessions and retains the local key only for an idempotent retry until deletion is confirmed. Any unlinkable pre-rotation rate hash expires under the 65-minute outer limit. Final-image and TestFlight proof remain pending |
| Automatic or manual auth-volume snapshots | Encrypted, rolling, 14 days maximum; no monthly or indefinite archive | Fly configuration/status reported a 14-day setting on 2026-08-18; actual expiry and final-deployment reconfirmation remain external evidence |
| Temporary restore volume | Delete within 24 hours after the rehearsal or incident closes | Restore isolation has been rehearsed; deadline evidence remains required for each restore |
| Wardrobe application access logs | None | The production container command disables Uvicorn access logs and a regression pins it; the final image has not yet been built/deployed |
| Unavoidable provider edge logs containing raw IP | 24 hours maximum | Fly fields and configurable retention are not yet verified; release is blocked if this limit cannot be met or the policy is not explicitly revised |
| Payload-free application security/error logs | 7 days maximum | Event fields are minimized and tested; production retention is not configured/evidenced |
| Payload-free alert/incident records | 30 days maximum, or 7 days after incident closure when earlier | Alert routing and retention are not configured/evidenced |

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

Provider edge logging is a separate boundary. Before release, inspect the actual Fly edge fields
and prove that any raw IP is either not retained or expires within 24 hours. Fly's current Search
Logs documentation describes seven-day searchable application-log retention, but this beta
platform behavior is not repository-enforceable and does not establish the edge-IP fields or their
retention. Absence of a custom log drain is not sufficient evidence.

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
disclosure; rate-limit alerts must make sustained exhaustion visible.

Rate subjects are keyed HMACs. Rotating `APP_ATTEST_SESSION_SECRET` intentionally breaks the link
to rate rows written with the previous secret. A verified deletion still removes the live
installation, sessions, and key-bound challenges synchronously; any unlinkable pre-rotation rate
hash remains unusable as identity data and must expire no later than its fixed window plus the
five-minute maintenance allowance (65 minutes maximum). Record secret rotations and do not claim
that every pre-rotation rate row was synchronously selected for deletion.

Encrypted rolling snapshots may retain a deleted record until their 14-day expiry. A snapshot
created before a completed deletion must not silently restore that record into service. Until a
durable deletion journal exists, such a snapshot is ineligible for normal restoration; emergency
recovery must use a fresh auth store and require re-enrollment. Any future deletion journal must be
minimal, keyed, expire after the last eligible snapshot, and be added to this inventory.

Restore work must use an isolated, non-serving volume/Machine without application secrets. Record
only aggregate table counts and integrity results, then destroy the temporary restore volume within
24 hours. Never retain raw database copies in release evidence.

## Alert routing and support operations

Production alerts must route to a monitored owner/security channel configured outside the
repository. At minimum, alert on:

- health-check or sustained 5xx failures;
- missing/stale snapshots or a failed snapshot-restore rehearsal;
- auth-volume usage at warning and critical thresholds;
- bursts of App Attest rejection or rate limiting; and
- Anthropic availability errors and budget/cost thresholds.

Alert messages must follow the same payload and identifier prohibitions as logs. Test delivery
before the signed archive, after routing changes, and at least every 30 days while the production
service operates. Retain only the delivery result, rule name, timestamp, and remediation outcome
for at most 30 days.

The published support and privacy pages must name a monitored contact and response target. The
support process must distinguish device-local deletion from server auth-metadata deletion and must
meet the 24-hour live-deletion deadline after installation control is verified.

## Compliance and release evidence

Verified as of 2026-08-18:

- [x] The auth-store schema excludes receipt/wardrobe payloads and raw IP addresses.
- [x] Session bearers are stored only as hashes; rate subjects are stored only as keyed HMACs.
- [x] Challenges and sessions become unusable after five and fifteen minutes respectively.
- [x] Application security-event fields are bounded and payload/identifier-free, with regression
  coverage.
- [x] The production auth volume is encrypted and Fly reports a configured 14-day snapshot
  retention period; actual expiry remains an external evidence item below.
- [x] Structural review guardrails pin the exact auth schema, block common durable-write patterns
  and direct auth-store use from payload modules, allowlist current application log calls, and
  exercise payload-free error behavior. These guardrails supplement review; they are not a proof
  against every possible future persistence mechanism.
- [x] A one-minute lifecycle task starts and stops with FastAPI, uses cold-start lookahead, and
  repeats bounded cleanup transactions until every eligible challenge, session, and rate row is
  drained. `fly.toml` and its regression define the desired minimum-one-Machine production
  topology; deploying that configuration remains an item below.
- [x] Repository cleanup enforces 90-day inactive-installation and 30-day revoked-installation
  limits, cascades sessions, uses SQLite secure deletion, and checkpoints/truncates WAL.
- [x] A fresh one-time App Attest deletion assertion synchronously deletes the proven installation;
  the separate in-app Privacy & Data control fences memory sessions after proof dispatch, retains
  its local credential for ambiguous-response retries, clears that reference only after confirmed
  server deletion/absence, and then allows a future remote-AI request to enroll a new anonymous
  identity.
- [x] The production container command disables Uvicorn access logs and is pinned by a regression.

Required before APP-009 can close:

- [ ] Build, scan, deploy, and retain the immutable digest for the final policy-enforced backend;
  revalidate an App-Attest-only rollback image after any auth schema/image change.
- [ ] Verify Fly edge-log fields and the 24-hour raw-IP limit; configure/evidence seven-day
  application-log and 30-day alert-record retention.
- [ ] Configure the alert routes above and retain a redacted successful delivery rehearsal.
- [ ] Publish monitored privacy/support contacts and the server-deletion procedure.
- [ ] Rehearse deletion followed by eligible-snapshot expiry or safe fresh-store recovery, and
  destroy the isolated restore volume within 24 hours.

Retain only redacted evidence: source SHA, immutable image digest, policy/config names, aggregate
counts, timestamps, snapshot retention, alert rule/delivery result, and deletion/restore outcome.
Never retain secret values, raw identifiers, request bodies, database files, or log samples that
contain prohibited fields.

## Provider references

- [Fly Volume snapshots](https://fly.io/docs/volumes/snapshots/)
- [Fly app logging overview](https://fly.io/docs/monitoring/logging-overview/)
- [Fly log search](https://fly.io/docs/monitoring/search-logs/)
- [Fly built-in metrics and external alerting](https://fly.io/docs/monitoring/metrics/)
