# Wardrobe backend (FastAPI)

Thin proxy that holds the Anthropic API key and calls Claude. It never persists wardrobe
payloads. It persists separate aggregate AI-budget/reservation metadata and narrowly scoped App Attest authentication
metadata (public keys, opaque Apple receipts, assertion counters, session hashes, challenges,
and rate windows). See [`../docs/architecture.md`](../docs/architecture.md).

Fly v12 selects pinned Sonnet 5 with SDK 1.4.0, strict forced tool output,
thinking/cache/retries off, and a pinned 1,024-token response cap. Admission and preflight reject
configuration or source drift from that evaluated cap. A separate durable v2
ledger reserves worst-case cost before each provider call and fails closed on missing storage,
policy mismatch, or uncertain accounting. Styling defaults to disabled. The owner approved
the private launch limits and daily monitoring policy on 2026-09-06; exact values are ignored
private release records and must not be committed. They are recorded in the existing ledger and
applied to the serving runtime with AI explicitly disabled. See
[`../docs/ai-spend-controls.md`](../docs/ai-spend-controls.md) for provisioning and recovery.
[PR #41](https://github.com/tzehon/wardrobe-stylist/pull/41) merged the model/budget source.
AI enablement remains open. A subsequent
security fix adds `libuuid>=2.42.3-r1` to the final runtime stage, preserving the pinned
base images and crypto updates. Its image passes the zero-High/Critical scan and isolated
runtime/storage checks. [PR #42](https://github.com/tzehon/wardrobe-stylist/pull/42) records its
owner-approved source publication, required checks, Codex review, and merge state. Its exact
merged image, source `d2866a2`, deployed on 2026-09-07 with **AI disabled**. The disabled-only
review completed at `2026-09-07T10:39:08Z`: original Machine/volume, registry identity/security,
health, auth-store protections and closed AI admission passed. That rollout created no budget storage
and made no paid call. The later
[preparation review](../docs/app-store/internal-testflight-runbook.md#budget-and-provider-preparation--2026-09-07)
supports zero prior liability within the approved selected-model production scope; excluded
evaluation uncertainty remains separate. On 8 September the owner approved the finite billing-reviewed
setup phase. Fresh automated operational checks, including recovery-image verification, passed at
`2026-09-08T08:54:09Z`; budget/manual gates remained OPEN. First-ever ledger provisioning succeeded
at `2026-09-08T08:56:32Z` with the approved policy, zero current-month state, no reservations and
required ownership/permissions. Independent read-only verification passed at
`2026-09-08T09:00:32Z`; the initializer was not repeated. The approved public-capacity review file is installed locally.
The original source/image/Machine/volume are unchanged. Fly v12 applies all six private policy
settings with AI false and the new provider key; all eight expected secrets are deployed. The
dedicated production workspace was created in the approved US
geography; its monthly limit and two email-notification settings were verified after reload. One
approved credit purchase is paid, usable balance is sufficient, and auto-reload remains off. Actual
alert delivery is still unverified, with no native test control observed. The workspace-scoped key
was created with no Admin API access and transferred through hidden owner input without local
secret persistence. Rotate it before its 8 October 2026 expiry. Independent post-deployment review
passed at `2026-09-08T09:32:49Z`: the serving UID reads the intact zero-state ledger, the disabled
guard returns 503, and runtime/auth/public-capacity/storage/snapshot/log/archive/public-page checks
pass. The 9 September diagnostic correction uses SSH account `wardrobe` and checks real/effective
UID/GID 10001 before ledger access. Its targeted live check passed on unchanged v12 at
`2026-09-09T00:05:29Z`; the ordinary budget gate remains OPEN `styling-disabled`. Storage guards
are unchanged. The finite disabled setup and 10 September beta-only pre-upload review are verified.
Build `1.0.0 (7)` completed validation/upload, Apple processing and `Family` internal distribution
with saved/reloaded AI-disabled notes; it is consumed and must never be uploaded again. See the
[distribution record](../docs/app-store/internal-testflight-runbook.md#build-7-distribution--2026-09-10).
The [11 September checkpoint](../docs/app-store/internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial)
records completed owner-controlled deletion, clean installation and scoped local-beta QA. AI
activation, broader public-release checks and public submission remain open.
Earlier setup evidence remains in the
[diagnostic follow-up](../docs/app-store/internal-testflight-runbook.md#launch-readiness-follow-up--2026-09-09),
[approved setup checkpoint](../docs/app-store/internal-testflight-runbook.md#approved-disabled-budget-setup--2026-09-08)
and the historical
[disabled rollout](../docs/app-store/internal-testflight-runbook.md#disabled-runtime-rollout--2026-09-07).
The request/response contract and iOS bundle are unchanged; Build 8 is not required.
The revised 8 September setup proposal also includes separate
[Fly hosting cost controls](../docs/fly-spend-controls.md). The policy is approved; the
[10 September release plan](../docs/release-plan.md) uses daily owner cost review and defers the
external monitor. A service hold requires its own execution approval. The AI budget and disabled
switch do not cap Fly charges. The latest signed-in 9 September refresh shows an increased September invoice preview
while same-period Cost Explorer is unchanged across the same five expected categories; private planning uses the higher
preview and retains feed reconciliation OPEN. The reviewed organization has no linked
organizations, active support package, Managed Postgres clusters or Upstash Redis databases. This
is a current billing snapshot, not proof of final charges or the absence of every possible add-on.
The feed's coverage cutoff/refresh lag remains unknown; month-end amounts remain planning
scenarios. The daily review does not rely on unproven provider alert delivery or remove residual
hosting exposure. The standalone
[`verify_fly_spend.py`](verify_fly_spend.py) validates explicitly supplied private policy/resource/
billing JSON and emits fixed local-evidence labels. It has no live collection, scheduler,
notification or shutdown path; see the
[input and output contract](../docs/fly-spend-controls.md#local-evidence-checker).

## Setup

```bash
cd backend
uv sync --locked             # create .venv exactly from uv.lock
cp .env.example .env         # then fill in local-development values
```

## Run

```bash
uv run uvicorn app.main:app --reload
# health check:
curl localhost:8000/health
```

## Test & lint (run after every change)

```bash
uv run --locked pytest
uv run --locked pip-audit
uv run --locked bandit -r app container_entrypoint.py -q
uv run --locked ruff check .
uv run --locked mypy app
```

## Endpoints

| Route | Phase | Purpose |
|---|---|---|
| `GET /health` | 0 | liveness |
| `POST /auth/app-attest/challenge` | APP-009 | one-time enrollment/assertion challenge |
| `POST /auth/app-attest/register` | APP-009 | verify one installation and issue a short-lived session |
| `POST /auth/app-attest/session` | APP-009 | verify a fresh assertion and rotate the session |
| `POST /auth/app-attest/delete` | APP-009 | verify a fresh deletion assertion and remove that installation's server identity |
| `POST /recommend` | 5 | "Aria" stylist → one daily outfit from a compact catalog + recent-worn ids (Sonnet 5, strict forced tool use; production AI currently disabled) |

Phase 3 (dynamic categories) is done **on-device** — there is no `/categorize`
endpoint. `/recommend` is a single non-streaming call.

Production startup rejects `AUTH_MODE=legacy`. A temporary `bridge` deployment must
carry a UTC `LEGACY_BRIDGE_EXPIRES_AT` no more than seven days in the future; the legacy
bearer stops being accepted at that instant. An expired bridge can cold-start in
App-Attest-only behavior, but operators must still switch final production to
`AUTH_MODE=app_attest`, with a private
`APP_ATTEST_SESSION_SECRET`, and `/data/app-attest/auth.sqlite3` on the mounted Fly volume.
Because Apple's April 2026 published validation vector contradicts its normative
challenge-hashing prose, successful physical-device attestation in development and
production/TestFlight environments remains a mandatory release gate.

The verifier requires the supplied key ID to match both `credentialId` and the SHA-256
hash of the certified P-256 public key's uncompressed X9.62 representation, and requires
the nonce-bound COSE key to equal that certified key. Runtime validation-category and
bundle-version extensions arrive on iOS 27 and later: their signed absence is accepted for
iOS 18-26, while any present extension requires the complete pair and exact allowlists.
The approved operational limits are defined in
[`docs/app-store/app-attest-data-lifecycle-policy.md`](../docs/app-store/app-attest-data-lifecycle-policy.md).
Historical production evidence describes Fly v10 and the earlier Opus 4.8 backend.
That release used an immutable Linux/AMD64 image with a one-minute
maintenance loop on the minimum-one-Machine production topology. At the
`2026-08-29T03:31:57Z` recovery-baseline checkpoint, fresh authentication re-resolved its expected
source identity and architecture, and its zero-High/Critical scan passed. Former v9, v8, v7, and v6
references are timestamped historical evidence only. The former v6 reference's current platform/
source identity was not independently proven, so it is ineligible for rollback or recovery. Any
identity or scan mismatch blocks archive, upload, distribution, and physical QA.
The unchanged image used by v11 and v12 is verified for disabled redeployment and retained privately.
The v12 restart and configured probe verified compatibility with the existing ledger and approved
limits; preserve that storage and liability in future recovery. Pre-budget v10 is not a normal
rollback target after this cutover. Cleanup repeats bounded transactions until drained,
removes inactive installations after 90 days and revoked installations after 30 days, and securely
checkpoints/truncates SQLite WAL state. A fresh App Attest deletion assertion
synchronously removes the proven installation and its sessions, and the iOS Privacy & Data screen
exposes that server-only control. The exact live and retained-recovery digests and scan evidence are
kept in ignored private release records; the internal-TestFlight runbook records fixed outcomes.
The owner-approved payload-free manual operations review remains part of the operating policy.
The [current release plan](../docs/release-plan.md) supplements it with daily owner cost review
for the small pilot and defers the new monitoring stack. Unproven provider alert delivery is not
relied on; residual Fly cost exposure and the manual response remain explicit. The first manual
review passed on 2026-08-20, and the v10 post-change review passed at `2026-08-29T02:21:41Z`. A
fresh full operations/recovery review against exact v10 completed at `2026-08-29T11:02:18Z`,
including a fresh private-registry match and zero-High/Critical Docker Scout scan, immediately
before the distinct final build-7 archive. The later beta-only review and internal distribution
completed on 10 September. Refresh the applicable review before a future candidate upload and
after every backend/configuration change; do not repeat build 7's upload. The
Gmail-free public pages are live; snapshot-list expiry and deletion-specific recovery remain release
gates.

The auth service defines bounded security events containing only an event/code/scope/path/
mechanism tuple. Live Fly v12 enables application `INFO` only for `app.auth.service`, routes it
through one non-propagating handler, leaves other application `INFO` logs disabled, and keeps
Uvicorn access logging off. Required production registration, assertion, and deletion success
markers have been observed; the runbook retains only their bounded, payload-free evidence.
Structural and production-equivalent tests pin the reviewed auth schema, persistence sinks,
application log calls, and container command.
Fly Security confirmed that provider-controlled logs can include source IP and that customers
cannot enforce a hard 24-hour provider raw-IP maximum. On 2026-08-19 the owner explicitly accepted
Fly's fixed seven-day customer-visible stream and undisclosed provider-internal in-service
retention. The 2026-08-20 manual-operations decision adds no monitoring processor or backend data
flow. Historical v10 manual reviews and the build-7 pre-archive repeat passed. The v11 disabled-only
review passed its scoped checks. The later v12 review verified the applied private budget policy,
existing ledger and usable provider credit with AI disabled. Provider alert delivery remains
unproven and billing reconciliation remains unresolved; the daily owner-review path does not rely
on delivery or require the deferred external monitor. The completed beta review does not substitute
for fresh checks on later changes or AI activation. Snapshot-list expiry, final App Privacy publication and
deletion-specific recovery remain open in the public-release track; the manual review must remain
current under the approved cadence.

For later backend/configuration changes or a future internal-beta candidate, use the applicable
review procedure in the runbook. The read-only disabled-beta command below is a reference for those
future checks, not an outstanding build-7 upload step. Run it from the repository root on clean
synchronized `main`, keeping AI disabled:

```bash
python3 backend/verify_production_operations.py \
  --purpose internal-beta-ai-disabled --refresh-registry-auth
```

This purpose accepts only verified disabled styling with an intact, below-warning, idle ledger;
every other required check must pass. Its `PASS_INTERNAL_BETA_ONLY` result does not authorize
AI activation, public submission or upload. Verify the existing limits/key/ledger and current
privacy/consent and daily cost-response checks before requesting separate AI activation approval.
After approved activation, use the enabled-state review:

```bash
python3 backend/verify_production_operations.py --purpose ai-launch --refresh-registry-auth
```

`ai-launch` is the default purpose and requires enabled styling. It is not a prerequisite that
demands AI already be enabled before activation is approved.

The lock identifies the verified v12 configuration deployment with unchanged merged source.
The ledger and private policy are applied with AI disabled. The ordinary budget check remains
OPEN `styling-disabled`. The repaired diagnostic runs as `wardrobe`, verifies real/effective
UID/GID 10001, suppresses bytecode writes and calls the existing read-only inspector.
Never reinitialize storage or bypass ownership guards to make the checker green.
Both purposes currently use the locked final build-7 archive as a verification baseline; this is
not permission to upload that consumed build again. Before a future iOS candidate, confirm the next
unused build number and review its archive/deployment lock. The command captures Fly/Docker/HTTP/SQLite output
only in memory, emits a fixed redacted report, uses a temporary Docker credential directory for the
fresh private-registry resolution, and never probes the write-affecting unauthenticated
`/recommend` path. It deliberately returns nonzero until the official Fly response-class metric,
signed-in Anthropic usage/limit/model/key/saturation state, and signed-in App Store Connect Build
Uploads state are reviewed in the same session. Those fixed manual results may be supplied through
the gitignored `backend/production-operations-evidence.toml`; explicit owner upload approval is
always separate and is neither stored nor accepted by the command. See the TestFlight runbook for
the exact fields and sequence, including the four lock-copied fields that bind the observation to
the selected archive and deployment. Supply `--refresh-registry-auth` again on the combined rerun because
each registry credential directory is intentionally ephemeral. After a pass, retain the approved
fixed fields, remediation outcome, and next due in the lifecycle policy's manual-review register;
the temporary TOML is not the long-lived review record.

The historical single-user aggregate profile remains the default. The deployed backend also
supports `--auth-capacity-profile public-launch --auth-capacity-policy PRIVATE_TOML` with
independently approved private installation/session bounds and active-session ownership checks.
The owner-approved public-capacity policy is installed locally; select it explicitly for applicable
future live reviews. It changes review bounds only, not runtime auth or customer quotas. See the
[capacity-policy schema and review procedure](../docs/ai-spend-controls.md#public-launch-observed-capacity-preflight).

The Apple receipt is stored as an opaque blob only after core attestation succeeds. Its
PKCS#7 payload validation and fraud-metric exchange are a separate deferred operations
gate, so the backend does not claim that the receipt blob itself is verified.
