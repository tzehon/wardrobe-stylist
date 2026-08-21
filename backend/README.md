# Wardrobe backend (FastAPI)

Thin proxy that holds the Anthropic API key and calls Claude. It never persists wardrobe
payloads. It does persist narrowly scoped App Attest authentication
metadata (public keys, opaque Apple receipts, assertion counters, session hashes, challenges,
and rate windows). See [`../docs/architecture.md`](../docs/architecture.md).

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
| `POST /recommend` | 5 | "Aria" stylist → one daily outfit from a compact catalog + recent-worn ids (Claude Opus 4.8, forced tool use) |

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
Fly release v8 runs reviewed PR #23 source
`4a75b99dcd49e818ad1d5b198e8c49abba702e18` at immutable `linux/amd64` digest
`sha256:0b2dc350e88522a07f999ae5676ad680c0ab3a6538e44066db52baec8003e7eb`
with a one-minute maintenance loop on the minimum-one-Machine production topology. Former v7 digest
`sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
is the immediate rollback, while retained v6 Gmail-free digest
`sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
remains the eligible post-build-4 recovery path; both freshly re-resolved and scanned with zero
critical/high vulnerabilities. Both are operational recovery only: using either reopens the exact-
candidate deployment, configuration, and manual-review gates and blocks build-5 archive/QA until
v8 is restored and reverified. Cleanup repeats bounded transactions until drained,
removes inactive installations after 90 days and revoked installations after 30 days, and securely
checkpoints/truncates SQLite WAL state. A fresh App Attest deletion assertion
synchronously removes the proven installation and its sessions, and the iOS Privacy & Data screen
exposes that server-only control. The exact live and retained-recovery digests and scan evidence are
recorded in the internal-TestFlight runbook. The owner-approved payload-free manual operations
review replaces automated alert delivery for this personal single-user release. The first manual
review passed on 2026-08-20, and the reviewed v8 post-change review passed at
`2026-08-21T11:09:20Z`. The Gmail-free public pages are live; snapshot-list expiry and deletion-
specific recovery remain
release gates.

The auth service defines bounded security events containing only an event/code/scope/path/
mechanism tuple. Live Fly v8 enables application `INFO` only for `app.auth.service`, routes it
through one non-propagating handler, leaves other application `INFO` logs disabled, and keeps
Uvicorn access logging off. The first post-deploy bounded query returned zero
`registration_succeeded`, `assertion_succeeded`, and `installation_deleted` events because none was
exercised; real production lifecycle-marker observation remains a release gate.
Structural and production-equivalent tests pin the reviewed auth schema, persistence sinks,
application log calls, and container command.
Fly Security confirmed that provider-controlled logs can include source IP and that customers
cannot enforce a hard 24-hour provider raw-IP maximum. On 2026-08-19 the owner explicitly accepted
Fly's fixed seven-day customer-visible stream and undisclosed provider-internal in-service
retention. The 2026-08-20 manual-operations decision adds no monitoring processor or backend data
flow. Required manual reviews through the live v8 deployment have passed. Snapshot-list expiry,
final App Privacy publication, and deletion-specific recovery remain release gates; the manual
review must remain current under the approved cadence.
The Apple receipt is stored as an opaque blob only after core attestation succeeds. Its
PKCS#7 payload validation and fraud-metric exchange are a separate deferred operations
gate, so the backend does not claim that the receipt blob itself is verified.
