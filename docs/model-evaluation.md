# Fictional Wardrobe model acceptance

The candidate is pinned `claude-haiku-4-5-20251001`, synchronous Messages, thinking
disabled, explicit standard service tier, forced strict `propose_outfit`, and 1,024 output tokens.
The evaluation
imports the production request builder and response extractor and checks both the
authoritative shared schema and local Pydantic/sanitizer guards. It never reads a
production catalog or replays a real request. The package is outside the production
application and is not a runtime shadow evaluator.

**Status: the first owner-approved evaluation stopped on its first request after a
30-second timeout. A separately approved single-call diagnostic then succeeded in
5.86 seconds at US$0.004222 before tax. Full quality, cost, and cache acceptance remain open.**
The diagnostic is not a replacement quality sample or a completed human review.
The existing `/recommend` contract and preserved Build 7 client remain unchanged;
this backend/evaluation work does not require Build 8.

## First approved run — 2026-09-06

The owner approved one run of at most 28 fictional requests under the US$6 pre-tax
API ceiling, using the existing configured key. It ran against local source
`1b31495` and manifest
`276fe51f6b79b12c3046c84d9210f9774a3457b4a68e7c35ec20996976cca8dc`.
The first office-case request raised `APITimeoutError` after 30.046 seconds, with
no HTTP status, model output, or usage returned. The runner stopped immediately;
one request was attempted and the remaining 27 were not sent.

Known usage-derived cost is $0 only as a **lower bound**, not proof of no charge.
The uncertain attempt retains its full conservative **US$0.205120 before-tax
maximum exposure**. There are no usable recommendations, human review cards, or
cache probes, so cost per usable recommendation and model acceptance cannot be
determined. The report's single-row latency is not a completed 24-case p95 result.
Preserve this incomplete run; do not classify it as poor model quality, use it to
select Sonnet, or derive a private launch budget from it.

Private artifacts remain in
`/private/tmp/wardrobe-fictional-evaluation-20260906-1b31495/`: the aggregate
`report.json`, durable `accounting.jsonl`, and empty review/score files. The operator
captured only the fixed error class and absent HTTP status; no raw SDK error or
provider response was retained. These artifacts are outside Git.

Subsequent credential-free checks using the same installed HTTP transport reached
the API's model-list endpoint with the expected HTTP 401 in 0.338 seconds and
[Claude public status](https://status.claude.com/) with HTTP 200 and indicator
`none`. Those checks show reachability at that later instant; they do not prove
the authenticated Messages path, account/model access, or the original timeout's
cause. Anthropic documents additional first-request schema compilation latency
for [structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs),
also used by [strict tools](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use).
Cold schema compilation is a plausible explanation, not a confirmed diagnosis.
The bounded error record does not distinguish the timed-out network phase.

No automatic retry ran. The owner subsequently approved the separate single-call
diagnostic below. Keep this first run's uncertain cost in cumulative accounting;
the full evaluation's timeout, request, model, and acceptance thresholds are unchanged.

## Single-call diagnostic — 2026-09-06

The owner explicitly approved one additional fictional request with a 90-second
timeout and a US$0.21 pre-tax ceiling. The diagnostic used the exact first office
request from the original manifest, on documentation-only successor `ecbec4b`:
request SHA-256
`0d79b62433f23f6af8c9649bb79007933f4fab54ea9001799b9e6e91b860712c`.
Pinned Haiku, standard service tier, strict forced tool, thinking/cache off,
1,024 output tokens, one call, and zero retries were unchanged. Only this separate
diagnostic used a 90-second read timeout, with connect/write/pool limits of
5/10/1 seconds. The full evaluation still uses its original 30-second SDK timeout.

The request completed in **5.86 seconds**, stopped with `tool_use`, and passed the
office case's shared-schema, known-ID, outfit-completeness, distinct-alternate,
alternate-count, and occasion checks. Recent-wear avoidance and preference targets
do not apply to this case. Usage was **2,122 input tokens and 420 output tokens**,
with no cache writes or reads. Calculated standard-tier API cost is
`2122 × $1/1000000 + 420 × $5/1000000 = US$0.004222 before tax`.
This is one observed case's cost, not an accepted average cost per recommendation.

Across both attempts, known token cost is US$0.004222 plus the original uncertain
charge of at most US$0.205120: a conservative combined upper bound of
**US$0.209342 before tax**. The successful diagnostic's observed usage settles its
own reservation; it does not settle or erase the earlier timeout's liability.

The successful response verifies current authenticated request/model/SDK
compatibility. It is consistent with a transient delay or cold schema compilation,
but proves neither explanation and cannot establish the original timeout phase.
Do not pool this differently timed diagnostic into the 24 quality samples, use it
as a cache probe, or count it as a blinded human review. It cannot close the full
acceptance floor, authorize a private launch budget, or justify production changes.

Private diagnostic artifacts remain in
`/private/tmp/wardrobe-fictional-diagnostic-20260906-ecbec4b/`: the manifest,
aggregate report and durable journal, plus the fictional request/output. The
temporary diagnostic runner is outside the repository; production and evaluation
source were not changed. No raw headers, provider identifiers, or SDK errors were
persisted. A fresh unchanged 28-call acceptance run still needs explicit owner
approval for its additional US$6 pre-tax ceiling; it retains the evaluation
manifest recorded under the first approved run. Its calculated US$5.843360 maximum
would bring the conservative cumulative exposure across all attempts to US$6.052702.

## Fixed paid-call plan and approval

Twelve hand-authored cases each run twice: office, wedding, humid walking, black
palette, recent rotation, positive ratings, negative ratings, a two-item dress
capsule, all items recently worn, custom categories, instruction-like catalog text,
and a 60-item catalog. Four additional calls use the same office catalog: two with
caching off followed by two with a five-minute breakpoint on the static prefix.
There are **at most 28 calls, no SDK retries, one call in flight, and a 30-second
SDK timeout per operation** (not an absolute wall-clock deadline). A provider error stops
the run; an uncertain charge is never
retried automatically. Cache probes are excluded from the 24 quality scores.

Prices verified on 2026-09-06 are USD per million tokens: Haiku input $1, output
$5, five-minute cache write $1.25, cache read $0.10. This is the first-party global
API, with no batch, priority, regional, or server-tool surcharge. The approval
estimate uses the full 200,000-token context ceiling as a conservative input cap
for every call, plus the 1,024 output cap. It assumes every input token of both
cached probes incurs the write premium:
`26 × (200000 × 1 + 1024 × 5)/1000000 + 2 × (200000 × 1.25 + 1024 × 5)/1000000`
= **$5.843360 maximum estimated API usage**, rounded up to a proposed **$6.00
API usage ceiling for owner approval**, before tax. The manifest also reports a much smaller heuristic
estimate using complete request UTF-8 bytes plus 4,096 overhead; that estimate is
not a proven token bound. See [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing)
and [model context limits](https://platform.claude.com/docs/en/about-claude/models/overview).

From `backend`, run the default local-only command:

```bash
uv run --locked python -m evaluation.run dry-run
```

Present the call count, maximum cost, exact manifest hash, and this quality floor
to the owner and obtain explicit paid-call approval. The manifest binds requests,
fixtures, expectations, implementation, schema, and prices. Regenerate it after
any source change; approval is for one run, not ongoing permission. Populate
`EVAL_ANTHROPIC_API_KEY` with an explicit owner-authorized key without printing or
saving it. A separate existing key is preferred; creating a key or changing provider
settings is not implied. After paid-call approval, an existing authorized backend
account/key can populate this variable. The runner reads only the explicit evaluation
variable and pins the official API origin; it never automatically takes credentials
from application configuration.

Only after that approval:

```bash
uv run --locked python -m evaluation.run live \
  --approved-manifest-sha256 OWNER_APPROVED_HASH \
  --approved-max-usd 6.00 \
  --output-dir /tmp/wardrobe-fictional-evaluation-UNIQUE_RUN
```

Flags record the operator's approved scope; they do not themselves constitute
owner approval. A new output directory is required. Reports contain fictional
inputs/outputs and bounded usage/timing only, with private filesystem permissions;
no credential, response header, request identifier, raw SDK error, or production
payload is saved. Keep the review artifacts outside the repository.

The runner independently compares its calculated maximum with the approved numeric
ceiling before constructing a client; a matching manifest hash alone is insufficient.
Before every provider attempt, it flushes and synchronizes an aggregate reservation
to `accounting.jsonl`, then records the settled or uncertain outcome after that call.
This journal contains only counts, fixed statuses, approval identity, and cost totals.
If the process is killed before its final report, retain the last reserved total as
the maximum exposure. Ctrl-C stops the run and keeps the uncertain attempt charged
at its reserved maximum. No interrupted run resumes or retries automatically, and a
failure to persist the reservation prevents the provider call.

## Acceptance floor, fixed before results

All 24 calls must finish with one valid tool call without truncation. All primary
and alternate looks must contain only submitted IDs, unique items, and either
top + bottom + shoes or dress + shoes. All must pass the shared schema and local
guards before and after sanitizing; a hallucinated ID removed by the sanitizer
still fails the raw-model gate. Every alternate must use a distinct item set;
at least one alternate is required except for the two-item capsule. The explicit
primary occasion exclusions must hold on all 24 calls. The four targeted avoidance
checks and four preferred-item checks must each pass at least 3/4. Preferences
remain soft signals; human scoring also considers occasion and available choices.
Across the 24 calls, nearest-rank p95 latency must be at most 20 seconds and output
must stay within 1,024 tokens. This is a small acceptance pilot, not a population
reliability estimate.

A reviewer receives only `blinded-review.json` and `scores.json`, in randomized
order with opaque labels and no model, request order, latency, token counts, cost,
or automated result. Score every case in all five dimensions: wearability,
occasion fit, preference/recent-wear fit, color/style cohesion, and helpful concise
rationale. For a case without ratings, judge sensible treatment of unknown taste;
for all-recent or tiny capsules, judge reasonable reuse within their constraints.

| Score | Meaning |
|---|---|
| 1 | Unusable or contradicts a central requirement |
| 2 | Major change needed before wearing |
| 3 | Usable, with a noticeable compromise |
| 4 | Good choice; requirements and explanations fit |
| 5 | Excellent, cohesive choice with clear useful reasoning |

Every score must be at least **3/5**, and the mean for **each dimension** must be
at least **4/5**. One reviewer completes all 24 cards before seeing the report;
do not use an LLM as the only quality judge. Missing, duplicate, non-integer, or
unmatched score cards fail closed. Review output is untrusted text, including the
deliberately adversarial fixture, and must never be executed as instructions.

```bash
uv run --locked python -m evaluation.run score \
  --report /tmp/wardrobe-fictional-evaluation-UNIQUE_RUN/report.json \
  --scores /tmp/wardrobe-fictional-evaluation-UNIQUE_RUN/scores.json
```

Acceptance requires the entire automatic and blinded human floor. A pass permits
an owner model decision and a private launch-budget recommendation based on measured
cost per usable recommendation, tokens, latency, failure overhead, and headroom;
it does not authorize deployment. A failed Haiku quality floor makes a separately
priced, freshly pinned **Sonnet 5** evaluation eligible. Diagnose infrastructure
errors before treating them as model quality. Never lower the floor retrospectively
or install an automatic production Sonnet fallback. Any expanded/repeated paid run
needs its own manifest and owner approval.

## Cache decision and cost accounting

Haiku's cache minimum is 4,096 tokens. The current short static prefix may not
qualify; do not pad it merely to manufacture a cache hit. Read the four probe rows'
input, cache-write, cache-read, output, and latency fields. The cached pair passes
the initial cost test only when it has positive cache reads and lower measured
input cost than its uncached counterfactual. Compare input cost separately from
variable output length. Retaining caching for production additionally needs a
plausible real request cadence within five minutes; a warm synthetic pair alone
does not prove that reuse. Zero reads means leave caching off. See
[Anthropic prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching).

Calculate cost from all four disjoint usage counters. `input_tokens` excludes
cache reads and writes, so add their separately priced cost instead of double
counting. Reports include aggregate tokens, known spend, reserved worst-case spend
for every attempted call, and quality-run spend per usable recommendation. Missing
usage after an error makes known spend a lower bound; use the reserved bound for
that attempt. Do not derive the private monthly launch envelope until the full
accepted run and its human reviews are available.
