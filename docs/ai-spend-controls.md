# Singapore launch AI spend controls

Status: local candidate, not deployed or enabled. The private monthly launch budget is
**not chosen**. First pass the [fictional model evaluation](model-evaluation.md), including
human review, then recommend a private envelope from measured cost per usable recommendation,
expected demand, failed-call exposure, tax, and operating headroom. The 5 Free / 60 Plus figures
remain post-v1 proposals. This ledger is a global safety ceiling, not a customer's paid quota.

Both complete Haiku pilots and the first Sonnet 5 run failed the fixed quality floor.
The optional-item clarification's revised Sonnet run passed every automatic gate at
US$0.360167 for 28 calls (US$0.012839 per mechanically usable quality output). The 24-proposal
human quality review and owner model acceptance remain open. Warm-pair input savings of about
20.9% do not prove production reuse, so caching stays off. No private budget is selected yet.
Evaluation profile selection does not change this Haiku-priced production implementation.
If Sonnet is accepted, first align the runtime model, token rates, full-context reservation,
and redacted preflight, and repeat required validation before approving/provisioning a budget.
Never deploy Sonnet behind the current Haiku-specific accounting constants.

## Admission and maximum exposure

The pinned model is `claude-haiku-4-5-20251001`, using synchronous Messages, no thinking,
no cache breakpoint, explicit `service_tier=standard_only`, and zero SDK retries. The explicit
tier prevents an account's Priority capacity from changing the pricing assumption; see
[Anthropic service tiers](https://platform.claude.com/docs/en/api/service-tiers).
Official global API rates verified on 2026-09-06
are $1 per million uncached input tokens and $5 per million output tokens.
[Anthropic model limits and prices](https://platform.claude.com/docs/en/models/overview).

One internal accounting unit is $0.000001 of pre-tax API usage. Before contacting the
provider, SQLite atomically charges `200000 + 5 × max_output_tokens` units and one admission.
The full 200,000-token context is reserved even though actual input is much smaller; UTF-8
size estimates are not treated as a proof of provider token count. Default output is 1,024,
so one reservation is 205,120 units ($0.205120). A valid completed recommendation refunds
only the difference between this reservation and checked usage. Failures retain the full
reservation, including failures that may actually be unbilled. This is intentionally conservative.

The approved unit ceiling bounds this backend's selected-model API usage, before tax, as long
as every call uses this ledger and the pinned model/rates remain valid. It does not bound Fly
charges, other Anthropic keys/apps, evaluations, taxes, or charges after unreviewed price changes.
Keep evaluation on a separate key. A dedicated production workspace/key with a provider-side
workspace limit is recommended as an independent backstop, subject to separate owner approval.

The route admits at most 200 catalog items, 32,768 bytes of normalized request JSON, and
64 characters per color. The HTTP receive layer limits `/recommend` to 128 KiB even when
Content-Length is missing or misleading. Existing wire schemas and the Build 7 app remain
unchanged; oversized operational requests receive the existing safe 503/413 error behavior.
There is no extra token-counting call that transmits a real wardrobe twice. Client timeouts
are bounded (connect 5s, write 10s, read 45s, pool 1s); these are socket inactivity limits,
not a proof that remote execution has stopped. SDK clients are closed after each request.

All worker processes share one existing durable SQLite ledger on the single Fly volume.
Reservations commit before the call, with WAL and FULL synchronization. They enforce both
monthly units/admissions and durable concurrency. A timeout, cancellation, or process loss
keeps its full charge and slot; leases never expire into an automatic refund. Known terminal
failures release only their slot. Invalid usage halts the ledger when bounds are exceeded.
Unfinished prior-month calls carry their entire reservation into the next UTC month; late
completion cannot refund the carried amount. Clock regression, corruption, policy mismatch,
or a missing database closes admission. Successful settlement deletes its opaque reservation;
the ledger retains current aggregate counters and unresolved reservations only.

## Private configuration and first provisioning

`AI_STYLING_ENABLED` defaults to false. `AI_MONTHLY_UNIT_LIMIT` and
`AI_MONTHLY_REQUEST_LIMIT` default to zero, meaning no approved budget. These are private
runtime values, never committed actual launch amounts. General code safety upper bounds are
100,000,000 units, 100,000 admissions, four concurrent calls, and 2,048 output tokens; these
upper bounds are not an approved launch policy. The default concurrency is one. The selected
limits must match the immutable policy stored at first provisioning.

The existing root container entrypoint prepares only the App Attest directory. For the one-time
approved budget provisioning, prepare the separate directory with the existing
`container_entrypoint.prepare_database_parent(Path("/data/ai-budget/budget.sqlite3"))` helper
as root, then run the initializer as service UID/GID 10001. Normal app startup does not initialize
the ledger. Do not add budget files to the dedicated App Attest directory.

Before an owner-approved deploy/configuration change, prepare a private configuration with
`AI_BUDGET_DATABASE_PATH=/data/ai-budget/budget.sqlite3`, the approved unit/admission limits,
`AI_MAX_CONCURRENCY`, and `AI_MAX_OUTPUT_TOKENS`. Keep styling disabled. The dedicated directory
must be mode 0700 and owned by the non-root service user; the DB must be mode 0600, with no
symlink or hard-link substitution. Provision as that service user, on the existing mounted
volume, only for the first-ever ledger with independently confirmed zero prior liability:

```python
from pathlib import Path
from app.config import settings
from app.styling_budget import initialize_budget_database

assert settings.ai_styling_enabled is False
initialize_budget_database(
    Path(settings.ai_budget_database_path),
    monthly_unit_limit=settings.ai_monthly_unit_limit,
    monthly_request_limit=settings.ai_monthly_request_limit,
    max_concurrency=settings.ai_max_concurrency,
)
```

This is a procedure to review, not authorization to run it in production. Initialization refuses
an existing file, including a partially provisioned or corrupt file. Never delete an existing
ledger, silently replace it, restore an older snapshot, or reinitialize it to regain allowance.
An older restored ledger may omit charged requests. Recovery requires AI disabled, independent
reconciliation, and explicit owner approval; if the same-month liability cannot be established,
remain disabled through the month boundary and resolve pending provider work before a separately
approved new-period initialization. The App Attest store remains separate and unchanged.

Deploy only the reviewed/scanned immutable image after approval. Freshly verify model, rates,
SDK, exact source, all settings, single-volume topology, and the ledger's integrity and private
policy match. Update the production-operations lock's deployed revision/release and required
secret names from actual deployment evidence; do not fabricate a future release number or reuse
the v10 source lock as proof. `production_styling_status()` emits fixed bands only and is read-only.
The full operations helper now requires this check; v10 cannot pass it. Enable the server switch
only after the owner approves the bounded launch policy and the remaining gates pass.

Once this candidate is enabled, the recovery reference must be a freshly scanned, verified
**budget-aware image** using the same ledger and limits. Pre-budget v10 ignores the new switch
and accounting, so it is not a normal rollback target after cutover. If no compatible recovery
image is available, keep protected AI traffic stopped. The v10-only recovery reference in older
release records remains pre-migration historical evidence; re-lock the actual replacement after
approved deployment. Never regain availability by bypassing the budget.

## Alerts, disable, and recovery

The ledger exposes below-80%, 80% warning, 95% critical, and exhausted bands. Exhaustion includes
insufficient room for one full reservation even if some allowance remains. A bounded
`styling_budget_event` warning signals admission/storage/settlement problems or an 80% review
threshold; logs contain no amounts, catalog data, IDs, or credentials. Preflight fails closed on
warnings, exhaustion, disabled styling, pending requests, or absent/untrusted evidence.

Before public launch, obtain explicit acceptance of a named owner and operational cadence:
recommended daily provider/ledger review during launch, same-day review of warning events, and
immediate disabling on critical spend, anomalous traffic, uncertain accounting, or provider-price
drift. Configure or verify delivery of provider/workspace alerts without a new vendor where
possible. No notification delivery or monitoring automation has been installed by this change.
The current auth preflight still accepts only its historical single-user aggregate band;
multi-user capacity and that check must be deliberately reviewed before public launch.

For an incident, follow this order:

1. Obtain approval to set the deployed `AI_STYLING_ENABLED=false` and verify it on every worker.
   Existing in-flight reservations remain charged; the switch prevents new admissions. Local
   wardrobe and Demo Mode continue working through the existing unavailable-AI behavior.
2. Drain or stop every worker and independently confirm provider quiescence. Waiting for a
   socket timeout alone does not prove a request stopped remotely. Review only aggregate
   provider usage, ledger bands, and fixed failure classes.
3. If the ledger is healthy and only stranded slots need release, the explicitly approved
   owner operation below releases those slots while preserving every charge and any safety halt:

   ```python
   from pathlib import Path
   from app.config import settings
   from app.styling_budget import StylingBudget

   assert settings.ai_styling_enabled is False
   budget = StylingBudget(
       Path(settings.ai_budget_database_path),
       monthly_unit_limit=settings.ai_monthly_unit_limit,
       monthly_request_limit=settings.ai_monthly_request_limit,
       max_concurrency=settings.ai_max_concurrency,
   )
   budget.recover_pending(
       ai_styling_disabled=True,
       provider_quiescence_confirmed=True,  # independently evidenced, never inferred
   )
   ```

4. A bound violation halts admission across months; the recovery function does not clear it.
   Diagnose the model/pricing/accounting discrepancy before designing any separately approved
   reconciliation. Never erase counters or raise caps as routine recovery.
5. Repeat redacted integrity/configuration/recovery checks, obtain explicit re-enable approval,
   enable styling, and complete the fresh operational review. Record only timestamp, bands,
   outcome, and next review due. Any paid smoke call needs its own authorization.

Snapshot expiry and deletion-specific recovery remain independent APP-009 work. Do not mutate
Fly snapshots or perform a restore as part of this migration. Public provider/privacy declarations
and alert delivery remain external acceptance gates. A backward-compatible backend rollout
preserves Build 7 and does not require Build 8.
