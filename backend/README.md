# Wardrobe backend (FastAPI)

Thin proxy that holds the Anthropic API key and calls Claude. It never persists wardrobe
payloads. It persists separate aggregate AI-budget/reservation metadata and narrowly scoped App Attest authentication
metadata (public keys, opaque Apple receipts, assertion counters, session hashes, challenges,
and rate windows). See [`../docs/architecture.md`](../docs/architecture.md).

Fly v11 selects pinned Sonnet 5 with SDK 1.4.0, strict forced tool output,
thinking/cache/retries off, and a pinned 1,024-token response cap. Admission and preflight reject
configuration or source drift from that evaluated cap. A separate durable v2
ledger reserves worst-case cost before each provider call and fails closed on missing storage,
policy mismatch, or uncertain accounting. Styling defaults to disabled. The owner approved
the private launch limits and daily monitoring policy on 2026-09-06; exact values are ignored
private release records, remain unapplied, and must not be committed. See
[`../docs/ai-spend-controls.md`](../docs/ai-spend-controls.md) for provisioning and recovery.
[PR #41](https://github.com/tzehon/wardrobe-stylist/pull/41) merged the model/budget source.
Budget provisioning and AI enablement remain open. A subsequent
security fix adds `libuuid>=2.42.3-r1` to the final runtime stage, preserving the pinned
base images and crypto updates. Its image passes the zero-High/Critical scan and isolated
runtime/storage checks. [PR #42](https://github.com/tzehon/wardrobe-stylist/pull/42) records its
owner-approved source publication, required checks, Codex review, and merge state. Its exact
merged image, source `d2866a2`, deployed on 2026-09-07 with **AI disabled**. The disabled-only
review completed at `2026-09-07T10:39:08Z`: original Machine/volume, registry identity/security,
health, auth-store protections and closed AI admission passed. No budget storage was created
and no paid call was made. The later
[preparation review](../docs/app-store/internal-testflight-runbook.md#budget-and-provider-preparation--2026-09-07)
supports zero prior liability within the approved selected-model production scope; excluded
evaluation uncertainty remains separate. The prepared provisioning/provider/capacity proposal is
unapproved. Capacity, credit and alert readiness remain open;
this is not a full pre-upload operational pass. See the
[disabled rollout](../docs/app-store/internal-testflight-runbook.md#disabled-runtime-rollout--2026-09-07).
The request/response contract and iOS bundle are unchanged; Build 8 is not required.
The revised 8 September setup proposal also includes separate
[Fly hosting cost controls](../docs/fly-spend-controls.md). Their resource restrictions, monitoring
and service-hold procedure are proposed only; the AI budget and disabled switch do not cap Fly
charges. The signed-in 8 September review reconciled the current September invoice preview with
Cost Explorer across the five expected resource categories; the reviewed organization has no linked
organizations, active support package, Managed Postgres clusters or Upstash Redis databases. This
is a current billing snapshot, not proof of final charges or the absence of every possible add-on.
The feed's coverage cutoff/refresh lag and monitoring readiness remain open; month-end amounts
remain planning scenarios.

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
The current v11 immutable image is verified for disabled redeployment and retained privately.
After budget provisioning, verify compatibility with that same ledger and approved limits before
enablement; pre-budget v10 is not a normal rollback target after this cutover. Cleanup repeats bounded transactions until drained,
removes inactive installations after 90 days and revoked installations after 30 days, and securely
checkpoints/truncates SQLite WAL state. A fresh App Attest deletion assertion
synchronously removes the proven installation and its sessions, and the iOS Privacy & Data screen
exposes that server-only control. The exact live and retained-recovery digests and scan evidence are
kept in ignored private release records; the internal-TestFlight runbook records fixed outcomes.
The owner-approved payload-free manual operations
review replaces automated alert delivery for this personal single-user release. The first manual
review passed on 2026-08-20, and the v10 post-change review passed at `2026-08-29T02:21:41Z`. A
fresh full operations/recovery review against exact v10 completed at `2026-08-29T11:02:18Z`,
including a fresh private-registry match and zero-High/Critical Docker Scout scan, immediately
before the distinct final build-7 archive. Repeat the full review immediately before upload. The
Gmail-free public pages are live; snapshot-list expiry and deletion-specific recovery remain release
gates.

The auth service defines bounded security events containing only an event/code/scope/path/
mechanism tuple. Live Fly v11 enables application `INFO` only for `app.auth.service`, routes it
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
review passed its scoped checks, while budget readiness, provider credit/alert readiness and the
full pre-upload repeat remain open. Snapshot-list expiry, final App
Privacy publication, and deletion-specific recovery remain release gates; the manual review must
remain current under the approved cadence.

Run the repeatable read-only part of the fresh pre-upload review from clean synchronized `main`:

```bash
python3 backend/verify_production_operations.py --refresh-registry-auth
```

The lock identifies the verified v11 deployment and its exact merged source. Because the
private policy remains unapplied and no budget ledger exists, the required budget check
correctly reports OPEN `styling-budget-evidence-open`; do not provision storage to make it green.
The command defaults to the locked final build-7 archive. It captures Fly/Docker/HTTP/SQLite output
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
No public profile is approved or selected yet. See the
[capacity-policy schema and review procedure](../docs/ai-spend-controls.md#public-launch-observed-capacity-preflight).

The Apple receipt is stored as an opaque blob only after core attestation succeeds. Its
PKCS#7 payload validation and fraud-metric exchange are a separate deferred operations
gate, so the backend does not claim that the receipt blob itself is verified.
