# Wardrobe backend (FastAPI)

Thin proxy that holds the Anthropic API key and calls Claude. It never persists email
content or wardrobe payloads. It does persist narrowly scoped App Attest authentication
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
| `POST /extract` | 2 | receipt snippet → structured fashion purchase(s) (Claude Haiku, forced tool use) |
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
Exact operational retention periods for authentication metadata remain TBD pending the
final policy decision; expired rows are removed opportunistically in bounded batches, not
retained as content history.

The auth service emits bounded security events containing only an event/code/scope/path/
mechanism tuple; log retention and alert routing remain deployment-policy evidence gates.
The Apple receipt is stored as an opaque blob only after core attestation succeeds. Its
PKCS#7 payload validation and fraud-metric exchange are a separate deferred operations
gate, so the backend does not claim that the receipt blob itself is verified.
