# Singapore launch AI spend controls

Status: **Fly v12 configured with the approved budget and AI disabled**. First-ever provisioning
succeeded at `2026-09-08T08:56:32Z`; independent post-deployment review passed at
`2026-09-08T09:32:49Z`. The unchanged image reads the existing ledger as service UID/GID 10001,
with approved policy, zero current-month state and no reservations; the disabled guard returns 503.
The finite disabled setup is verified. See the
[approved setup checkpoint](app-store/internal-testflight-runbook.md#approved-disabled-budget-setup--2026-09-08).
On 2026-09-06 the owner **approved the private
launch spend/admission limits and operating policy** after reviewing measured cost, expected
demand, failed-call exposure, and headroom. The [fictional model evaluation](model-evaluation.md)
passed all automatic checks and received qualitative owner acceptance. The 5 Free / 60 Plus figures
remain post-v1 proposals. This ledger is a global safety ceiling, not a customer's paid quota.

Both complete Haiku pilots and the first Sonnet 5 run failed the fixed quality floor.
The optional-item clarification's revised Sonnet run passed every automatic gate at
US$0.360167 for 28 calls (US$0.012839 per mechanically usable quality output). The 24-proposal
human review was accepted through the owner's explicit qualitative approval of all proposals.
The partial numeric rubric remains unproven and no missing ratings were inferred. Warm-pair
input savings of about 20.9% do not prove production reuse, so caching stays off. The owner
expects up to 10 AI users in the first launch month. The approved private policy is retained in
ignored `.fly/launch-policy-20260906.md`, with a disabled configuration prepared separately.
The policy is recorded in the ledger and applied to the serving runtime through all six approved
AI settings, including the existing budget path and explicit `AI_STYLING_ENABLED=false`.
The existing first-provisioned directory/database must be preserved; no paid call ran.
The runtime model, token rates, full-context reservation,
and redacted preflight are aligned and have passed the full required regressions.
The exact approved monthly amount and admission limits remain outside tracked source.
Source publication and the disabled-only deployment received separate owner approval. On 8 September
the owner approved the finite billing-reviewed setup, including first provisioning, specified provider
changes, the capped credit purchase and disabled configuration deployment. First provisioning and
local installation of the approved capacity review file are complete. The dedicated production
workspace now exists in the approved US geography; its monthly limit and two email-notification
settings were verified after reload. One approved credit purchase is paid and sufficient usable
balance was verified, with auto-reload off. The workspace-scoped key is created without Admin API
access; hidden owner input transferred and staged it without local secret persistence. Fly v12
deploys the new key and private policy while preserving the session secret, with all eight expected
secrets deployed. Rotation before its 8 October 2026 expiry remains an operations gate.
Actual alert delivery remains OPEN; no native test control was seen.
AI enablement retains its separate approval gate. Build 7 completed its separately approved
AI-disabled internal distribution; see the [distribution record](app-store/internal-testflight-runbook.md#build-7-distribution--2026-09-10).
The ordinary checker's earlier `styling-budget-evidence-open` result recorded its root-SSH
ownership-context gap. The corrected local diagnostic connects as `wardrobe`, requires
real/effective UID and GID 10001, and uses `-B` to avoid bytecode writes. Live read-only verification
on 9 September passed against unchanged v12 and returned OPEN `styling-disabled`; it changed no
runtime settings or ledger state. See the
[launch-readiness follow-up](app-store/internal-testflight-runbook.md#launch-readiness-follow-up--2026-09-09).
The 10 September beta-only pre-upload review passed; this does not close AI-launch readiness.
The approved public-capacity profile passed the disabled post-review; alert-delivery
verification remains open. Prepaid-credit readiness now passes the approved setup check; refresh
it before later activation. The earlier
[preparation review](app-store/internal-testflight-runbook.md#budget-and-provider-preparation--2026-09-07)
supports zero prior liability within the approved selected-model production scope. The earlier
evaluation timeout remains unresolved outside that scope. The earlier 7 September provider review found spend below its warning band
and no recent rate saturation, but low prepaid credit and no configured email-spend notification
rows visible; no exact
provider balances or private limits are retained here.

## Admission and maximum exposure

The pinned model is `claude-sonnet-5`, using synchronous Messages, no thinking,
no cache breakpoint, explicit `service_tier=standard_only`, and zero SDK retries. The explicit
tier prevents an account's Priority capacity from changing the pricing assumption; see
[Anthropic service tiers](https://platform.claude.com/docs/en/api/service-tiers).
Official global API rates verified on 2026-09-06
are $2 per million uncached input tokens and $10 per million output tokens.
[Anthropic model limits and prices](https://platform.claude.com/docs/en/models/overview).

One internal accounting unit is $0.000001 of pre-tax API usage. Before contacting the
provider, SQLite atomically charges `1000000 × 2 + 10 × max_output_tokens` units and one admission.
The full 1,000,000-token context is reserved even though actual input is much smaller; UTF-8
size estimates are not treated as a proof of provider token count. Approved output is pinned to 1,024,
so one reservation is 2,010,240 units ($2.010240). A valid completed recommendation refunds
only the difference between this reservation and checked usage. Failures retain the full
reservation, including failures that may actually be unbilled. This is intentionally conservative.

The v2 ledger stores and validates the pinned model, micro-USD unit, global-standard uncached
pricing policy, input/output prices, and input/output token bounds alongside its private limits.
Old v1 Haiku storage, a relabeled old schema, changed pricing fields, or underpriced pending
reservations fail closed. No automatic upgrade or liability reinterpretation is allowed.
The first production budget ledger is provisioned, connected to the serving runtime and
independently verified after restart. If any other old ledger is
discovered, keep styling disabled and reconcile its liability through the owner recovery process;
do not delete or reinitialize it to make the Sonnet candidate start.

The approved unit ceiling bounds this backend's selected-model API usage, before tax, as long
as every call uses this ledger and the pinned model/rates remain valid. It does not bound Fly
charges, other Anthropic keys/apps, evaluations, taxes, or charges after unreviewed price changes.
Keep evaluation on a separate key. The dedicated production workspace and provider-side monthly
limit are created and verified. The workspace-scoped key was securely transferred, staged and
deployed. Saved email-notification settings are not delivery evidence.
The owner's 8 September request adds a separate [Fly hosting policy](fly-spend-controls.md).
Its private resource envelope and warning/hold thresholds are approved; monitoring is not installed,
and service-hold execution requires separate approval.
Neither the AI ledger nor the disabled AI switch caps hosting charges. The latest signed-in
8 September refresh shows divergent invoice-preview and Cost Explorer totals across five expected
resource categories, with no linked organizations, active support package, Managed Postgres
clusters or Upstash Redis databases in the reviewed organization. The snapshot does not establish
the billing feed's coverage cutoff/refresh lag, final taxes/adjustments or the absence of every
possible add-on. Private planning uses the higher preview; feed reconciliation remains OPEN.
Before AI enablement, refresh the billing observations and review the current owner-run daily
cost procedure, unresolved coverage and residual Fly exposure in the concrete activation package.
The [10 September release plan](release-plan.md) defers the external runner; installing it or
proving its alert delivery is not a prerequisite for this manual operating path. A month-end
estimate remains a planning scenario, and any disagreement between feeds remains explicit.

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
upper bounds are not an approved launch policy. Runtime admission and production preflight
separately require integer `AI_MAX_OUTPUT_TOKENS=1024` and the matching stylist default; even
an in-range setting such as 256 or 2,048 fails closed before ledger/provider access. This pins
the selected evaluated cap without reinterpreting the v2 ledger's broader storage bound.
The default concurrency is one. The selected limits must match the immutable policy stored at
first provisioning.

The first-ever provisioning below has now completed under the bound approval. It is retained as
the reviewed procedure, not permission to initialize the existing ledger again.

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
volume, only for the first-ever ledger with independently confirmed zero prior liability within
the approved budget scope:

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
The approved selected-model production envelope excludes fictional evaluations and earlier
Opus production. Preserve their unresolved account-level charges separately; do not import them
as launch-ledger debt or claim they were settled. Release/source history and the disabled Sonnet
cutover support the first-ever zero balance; directory absence or rounded provider costs alone
do not. Refresh the exact runtime, topology, disabled serving settings and storage checks before
creation. Any contradictory in-scope activity or lost/partial/restored ledger stops initialization.
The current initializer cannot import a nonzero opening balance; that case requires a separately
reviewed conservative reconciliation procedure. The allowance remains a UTC calendar month.
An older restored ledger may omit charged requests. Recovery requires AI disabled, independent
reconciliation, and explicit owner approval; if the same-month liability cannot be established,
remain disabled through the month boundary and resolve pending provider work before a separately
approved new-period initialization. The App Attest store remains separate and unchanged.

Deploy only the reviewed/scanned immutable image after approval. Freshly verify model, rates,
SDK, exact source, all settings, single-volume topology, and the ledger's integrity and private
policy match. Update the production-operations lock's deployed revision/release and required
secret names from actual deployment evidence; do not fabricate a future release number or reuse
the historical v10 source lock as proof. The v12 configuration-deployment evidence binds unchanged source
`d2866a2375dd4795f40a3ab13d273ed138cedd7e`. `production_styling_status()` emits fixed bands only
and is read-only. The default `ai-launch` purpose requires a ready, enabled budget; configured-but-disabled
v12 returns OPEN `styling-disabled`. For an intentionally AI-disabled internal beta, the explicit
`internal-beta-ai-disabled` purpose can accept that disabled evidence only after below-warning,
no-pending-work checks pass and every other review check passes. Its output is beta-only, not
AI-launch readiness. Complete disabled pre-enable checks first, then enable only under the
separate approved change and verify enabled operation afterward; there is no circular prerequisite.
The bounded launch policy is approved, but the
remaining operational gates and explicit AI-enable approval are still required.

The unchanged immutable reference used by v11 and v12 is privately retained for **budget-aware redeployment** after
verified source/architecture matching and zero-High/Critical scanning. Pre-budget v10 ignores the
new switch and accounting, so it is not a normal rollback target after this disabled cutover.
The v12 restart and independent configured probe verified that image reads the existing ledger
without initialization or reset. Recovery must continue to preserve its model, policy, limits and
charges. If no compatible recovery image is available, keep protected AI
traffic stopped. The v10-only recovery reference in older release records remains pre-migration
historical evidence. Never regain availability by bypassing the budget.

## Alerts, disable, and recovery

The ledger exposes below-80%, 80% warning, 95% critical, and exhausted bands. Exhaustion includes
insufficient room for one full reservation even if some allowance remains. A bounded
`styling_budget_event` warning signals admission/storage/settlement problems or an 80% review
threshold; logs contain no amounts, catalog data, IDs, or credentials. Preflight fails closed on
warnings, exhaustion, pending requests, or absent/untrusted evidence. Disabled styling remains
open under the default AI-launch purpose; the explicit internal-beta purpose requires that
disabled state and does not permit enabling AI.

The owner accepted responsibility for daily provider/ledger review during launch, same-day
review of warning events, and immediate response to critical spend, anomalous traffic, uncertain
accounting, or provider-price drift on 2026-09-06. The approved cadence supplements the existing
pre-archive/upload and post-change reviews. Configure or verify delivery of provider/workspace alerts without a new vendor where
possible. No notification delivery or monitoring automation has been installed by this change.
The auth preflight defaults to its historical single-user aggregate band. The local tooling also
supports an explicitly selected public-launch profile with a separate private policy file.
The owner approved those bounds with the 8 September setup, and the file is installed locally.
The configured public-band check passed after v12 deployed; future reviews must select it explicitly.
The estimate of ten people does not determine
installation/session limits: reinstalls create new identities, and session renewals can overlap.

### Public-launch observed-capacity preflight

Review independent maximum observed active-installation and active-session counts, then retain
the approved values in an ignored, owner-owned mode-0600 TOML file such as
`.fly/auth-capacity-policy.toml`. These are release-review bounds, not runtime account caps or
additional AI spending allowances. The schema is shown with deliberately invalid placeholders;
replace them only with separately approved integers before use:

```toml
schema_version = 1
profile = "public-launch"
max_active_installations = "OWNER_APPROVED_INTEGER"
max_active_sessions = "OWNER_APPROVED_INTEGER"
```

The parser requires exactly these fields, rejects non-integers, zero, values above its general
100,000 safety bound, symlinks, hard links, unsafe permissions, and oversized/malformed files.
The safety bound is not a recommended or approved launch capacity. Supplying a file without
explicitly selecting the public profile also fails closed. After policy approval, use the same
profile and file on every combined preflight rerun from clean synchronized `main`:

```bash
python3 backend/verify_production_operations.py --refresh-registry-auth \
  --auth-capacity-profile public-launch \
  --auth-capacity-policy .fly/auth-capacity-policy.toml
```

The public profile permits legitimate overlapping sessions while independently requiring every
active session to belong to a non-revoked installation. Both profiles retain the quiescent
release-review requirements of zero pending/failed challenges and at most 552 rate windows.
Output reports fixed profile/status labels only; private limits and observed counts are not
printed. An invalid policy stops before live checks. No public capacity policy is created or
selected automatically. The source/release lock follows verified deployment evidence independently
of public-capacity approval; a runtime deployment does not approve or activate a public-capacity
profile. The September 8 setup separately approved and installed the current private review bounds.

Runtime auth and abuse limits are unchanged. Existing registration limits allow five attempts
per IP and ten globally per hour, so several testers sharing a network may need staged
onboarding. Styling retains its independent 60-attempt global hourly abuse ceiling before the
approved monthly/concurrency controls. These limits do not enforce a ten-person population cap.

The completed local approval/capacity tranche passed 551 backend tests, locked dependency audit,
Bandit, Ruff, mypy, 236 iOS tests, 44 release-script tests, and fresh Release simulator/artifact
checks on 2026-09-06. Independent review found no actionable issue. The approved disabled
budget configuration passes local settings validation; no ledger or provider call was created.
No runtime auth, live release lock, iOS source, or shared schema changed in this tranche.

### Incident response

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
remain external acceptance gates for the applicable milestone. Provider alert delivery is still
unproven and is not relied on by the current daily owner-review path; the deferred monitoring
stack is not an activation prerequisite. A backward-compatible backend rollout
preserves Build 7 and does not require Build 8.
