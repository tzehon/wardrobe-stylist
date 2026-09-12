# Fictional Wardrobe model acceptance

The selected runtime is deployed as the enabled bounded Fly v13 pilot. It pins `claude-sonnet-5`, synchronous
Messages, thinking disabled, explicit standard service tier, forced strict `propose_outfit`, and
1,024 output tokens.
The evaluation
imports the production request builder and response extractor and checks both the
authoritative shared schema and local Pydantic/sanitizer guards. It never reads a
production catalog or replays a real request. The package is outside the production
application and is not a runtime shadow evaluator.

**Status: the revised Sonnet 5 run passed every automatic gate on 2026-09-06. The owner
subsequently approved all proposals qualitatively and directed the migration to proceed.**
All 28 calls cost US$0.360167 before tax. Both complete Haiku failures and the first Sonnet
failure remain recorded. The numeric rubric remains incomplete and is not reported as passed;
the owner's qualitative acceptance is recorded separately. No scores were fabricated and no
automatic threshold changed. The selected Sonnet model, accounting, and preflight are aligned
and fully tested locally. Warm cache savings do not prove production reuse, so caching stays off.
The existing `/recommend` contract and preserved Build 7 client remain unchanged;
this backend/evaluation work does not require Build 8.

The [approved disabled setup](app-store/internal-testflight-runbook.md#approved-disabled-budget-setup--2026-09-08)
has provisioned the existing-volume ledger, applied the private policy and workspace-scoped key,
verified provider controls and usable prepaid credit, and activated the private capacity review
profile. The v12 restart verified that the same immutable image read the then-zero current-month ledger. This adds no
evaluation or numeric-score evidence. The ordinary budget diagnostic's service-identity correction
passed live read-only verification on 9 September; that historical budget check reported OPEN
`styling-disabled`. Provider alert delivery remains unproven and billing-feed uncertainty remains
unresolved. The [10 September release plan](release-plan.md) uses daily owner cost review for the
small pilot and defers external monitoring. The
[10 September beta-only review and internal distribution](app-store/internal-testflight-runbook.md#build-7-distribution--2026-09-10)
are complete. The separately approved [v13 activation and enabled operations review](app-store/internal-testflight-runbook.md#bounded-ai-pilot-activation--2026-09-12)
passed on 12 September with the scoped Cowork-only exception. Protected-device styling proof passed on 12 September; activation adds no new model-evaluation or numeric-score evidence.
The explicit internal-beta review purpose accepts only
the verified disabled state with an intact, below-warning, idle ledger and every other check
passing. That beta-only result does not establish AI readiness. See the
[launch-readiness follow-up](app-store/internal-testflight-runbook.md#launch-readiness-follow-up--2026-09-09).

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

## Completed run — 2026-09-06

The owner approved a fresh 28-call evaluation with an **additional US$6 before-tax
ceiling**. It ran on documentation-only successor `aa314ca`, using the unchanged
manifest `276fe51f6b79b12c3046c84d9210f9774a3457b4a68e7c35ec20996976cca8dc`.
All 28 calls returned one completed `tool_use` response, with complete usage and
no provider error or retry. This completes the experiment, not model acceptance.

| Fixed criterion | Result | Required |
|---|---|---|
| Shared schema / known catalog IDs | 24 / 24 each | 24 / 24 |
| Complete primary and every alternate | **23 / 24** | 24 / 24 |
| Distinct item sets across primary and alternates | **22 / 24** | 24 / 24 |
| Sufficient alternates / occasion exclusions | 24 / 24 each | 24 / 24 |
| Targeted avoidance / preferred-item checks | 4 / 4 each | At least 3 / 4 each |
| Nearest-rank p95 quality latency | 15.872 seconds | At most 20 seconds |
| Highest quality output usage | 709 tokens | At most 1,024 tokens |
| Human review | Not performed | All 24 scorecards pass |

The failures are confirmed against the fictional output, not evaluator errors:

- Quality calls 7 and 8 (`black_palette`) each include an alternate with exactly
  the primary outfit's unordered item set. The fixture is feasible: the complete
  black top/trousers/loafers combination can be worn with or without the optional
  tote. A different rationale cannot make identical item IDs a distinct outfit.
- Quality call 18 (`all_recent`, second repeat) chooses trousers, a blazer,
  sandals, and a tote for the primary look, with no top or dress. The supplied
  blazer is categorized as outerwear; the unchanged completeness rule fails it.

Twenty-one of 24 quality responses pass every applicable automated check. The
candidate therefore **fails** the acceptance floor. Human scores cannot override
these failures, so no human-review form was generated for this run. The saved
blinded packet remains available as evidence, without fabricated human ratings.

Measured usage across all 28 calls is **64,572 input and 14,406 output tokens**,
costing **US$0.136602 before tax**. The 24 quality calls cost US$0.117154, averaging
about US$0.004881 per attempted quality call. Quality inputs range from 1,614 to
4,559 tokens and outputs from 202 to 709; median latency is 10.7575 seconds and
maximum latency 15.950 seconds. These are descriptive pilot measurements, not
accepted-recommendation economics. The report's 23-case `usable` denominator
checks only schema, known IDs, and completeness; it includes the duplicate-look
failures and must not be presented as 23 fully accepted recommendations.

All four cache probes completed. Both marked requests report **zero cache writes
and zero cache reads**. Their combined input cost is US$0.004244, identical to
the uncached counterfactual. There is no measured caching benefit; keep caching
off and do not pad the prompt to manufacture a hit.

Across the original timeout, separate diagnostic, and this complete run, known
token cost is **US$0.140824 before tax**. Adding the original timeout's unresolved
US$0.205120 reservation gives a conservative cumulative upper bound of
**US$0.345944 before tax**. All charges from this complete run are usage-accounted;
the earlier timeout's charge and cause remain unresolved.

Private artifacts remain in
`/private/tmp/wardrobe-fictional-evaluation-20260906-aa314ca/`: manifest/report,
accounting journal, bounded stop-reason observations, fictional review packet,
and unfilled scores. No paid run is continuing in the background.

The next prompt iteration below clarifies general complete-outfit and distinct-set
requirements, without fixture-specific instructions, post-filtered apparent
passes, or changes to the floor. Fresh approval is required for its full evaluation.
This failed Haiku run also makes a separately pinned/priced Sonnet 5 evaluation
eligible; there is no automatic production fallback. Do not select or provision
the private launch budget before full model acceptance.

## Prompt iteration 2 — completed and failed

The general prompt now requires shoe + top + bottom or shoe + dress in every look,
rejects outerwear as a substitute for required clothing, and explicitly compares
unordered item sets across the primary and all alternates. It omits duplicates
rather than padding the list. Recent item IDs no longer imply knowledge of past
outfit pairings, and the per-request label states that those combinations are
unknown. No fixture-specific IDs, colors, or occasions were added to the prompt.

Regression tests replay the three observed failures, verify that changing item
order or rationale cannot hide duplicates, and confirm feasible corrected
selections pass the unchanged evaluator. These are offline checks of the contract
and evaluation; they do not demonstrate improved live model quality. The original
run remains failed, with no rewritten results or fabricated human scores.

The owner approved an additional US$6 pre-tax ceiling for the full run on source
`43f3e0e`, with manifest
`92eabf7e62796a4686ebeb4c29eac14b0acc31b054c8988fdd5d25185f0cd961`.
Only prompt/request and implementation identity change: the fictional cases,
schema, quality floor, 30-second SDK timeout, zero retries, one call in flight,
24 quality plus four cache calls, model, prices, and 1,024-token output cap are
unchanged. The conservative maximum remains **US$5.843360**, with a proposed
**additional US$6 pre-tax ceiling** requiring fresh owner approval. Its heuristic
estimate at full output is US$0.441638, not a guaranteed token bound. Adding its
conservative maximum to previous usage/uncertainty would give a cumulative upper
bound of US$6.189304 before tax across all attempts.

The approved run completed with the unchanged criteria above. Pre-run verification passed **441 backend tests**, locked
pip-audit with no known vulnerabilities, Bandit, Ruff, mypy, **236 iOS tests**
(226 Swift + 10 UI), all **44 release-script tests**, and a fresh Release simulator
build/artifact check. The iOS result bundle is
`ios/DerivedData/HaikuPromptRegression-20260906.xcresult`; bounded local logs are
`/private/tmp/wardrobe-haiku-prompt-*.log`. No shared schema or iOS source changed,
so Build 8 is not required. This does not substitute for live quality acceptance.
No additional run or retry is authorized beyond this approved plan.

The run attempted exactly 28 calls, all with completed `tool_use` responses,
complete usage, and no provider error or retry. Its result is **failed**, because
two hard requirements missed their fixed 24/24 threshold:

| Fixed criterion | Revised prompt result | Required |
|---|---|---|
| Shared schema / known IDs / complete outfits / occasion exclusions | 24 / 24 each | 24 / 24 |
| Distinct item sets | **23 / 24** | 24 / 24 |
| Sufficient alternates | **23 / 24** | 24 / 24 |
| Targeted avoidance | 4 / 4 | At least 3 / 4 |
| Targeted preferred items | 3 / 4 | At least 3 / 4 |
| Nearest-rank p95 latency | 12.369 seconds | At most 20 seconds |
| Highest output usage | 664 tokens | At most 1,024 tokens |
| Human review | Not performed | All 24 scorecards pass |

Quality call 5 (`humid_walk`) repeats its primary item set in an alternate; its
rationale also contains tool-like markup and an embedded item-ID array, and
describes sandals while selecting sneakers. That prose defect is retained as an
observation, not a fabricated human rating or a changed automatic criterion.
Quality call 8 (`black_palette`) omits the required alternate even though removing
its optional tote yields a distinct complete look. The preferred-item result of 3/4
passes its deliberately softer threshold; it is not an additional gate failure.
Do not waive the duplicate or alternate requirement, count this run as accepted,
or replace human review with model-generated scores.

All 28 calls used **67,148 input and 13,219 output tokens**, costing
**US$0.133243 before tax**. The 24 quality calls cost US$0.114567, averaging
US$0.004773625 per attempted quality call. Quality inputs ranged from 1,706 to
4,651 tokens and outputs from 204 to 664; median latency was 10.055 seconds and
maximum latency 13.273 seconds. The report's 24 mechanically `usable` results
still include both hard failures and are not 24 accepted recommendations.

The four cache probes all completed. Marked requests again reported zero writes
and reads; their combined US$0.004428 input cost equals the uncached
counterfactual. Keep caching off for this Haiku candidate.

Known cost across all attempts is now **US$0.274067 before tax**. The original
timeout still carries up to US$0.205120 of unconfirmed exposure, so the cumulative
conservative upper bound is **US$0.479187 before tax**. This completed run does
not resolve the original timeout's cause or charge.

Private artifacts are in
`/private/tmp/wardrobe-fictional-evaluation-20260906-43f3e0e/`. The 24 scorecards
remain unfilled and no human-review form was generated. No paid call is still
running. After two failed Haiku pilots, proceed to the separately approved
Sonnet 5 comparison below, without automatic production fallback or a private
launch-budget decision.

## Sonnet 5 comparison — completed and failed

The comparison used pinned `claude-sonnet-5`; its dateless ID is a fixed
model snapshot, not a moving alias. It kept the then-current revised production prompt,
fictional cases, shared schema, quality floor, 1,024 output cap, synchronous
Messages, forced strict tool, explicit `thinking={"type":"disabled"}`,
`service_tier="standard_only"`, zero retries, one call in flight, and 30-second
SDK timeout. Only the evaluation profile changes; the production stylist,
Haiku budget constants, and preflight remain unchanged.
[Model versioning](https://platform.claude.com/docs/en/about-claude/models/model-ids-and-versions),
[Sonnet 5 behavior](https://platform.claude.com/docs/en/models/sonnet-5/whats-new-sonnet-5).

Official pricing rechecked on 2026-09-06 is **US$2 input / US$10 output per
million tokens**, with five-minute cache writes at US$2.50 and reads at US$0.20.
The earlier scheduled increase to US$3/15 was cancelled; US$2/10 is the standard
price. Sonnet's context is **1,000,000 tokens by default and maximum**, with no
smaller variant. Its cache minimum is 1,024 tokens, so Haiku's zero-read result
does not settle Sonnet caching.
[Current prices](https://platform.claude.com/docs/en/about-claude/pricing),
[Context](https://platform.claude.com/docs/en/models/sonnet-5/whats-new-sonnet-5),
[Cache minimums](https://platform.claude.com/docs/en/build-with-claude/prompt-caching).

For the same 26 uncached and two marked requests, the conservative bound is
`26 × (1000000 × 2 + 1024 × 10)/1000000 + 2 × (1000000 × 2.50 + 1024 × 10)/1000000`
= **US$57.286720**, rounded up to the approved **additional US$58 pre-tax ceiling**.
This intentionally uses the full model context; it is not the expected cost of
these small fictional requests. The source-bound manifest reports a smaller,
explicitly unproven byte-based planning estimate of **US$0.882705** at full output.
Including previous
usage and uncertainty, this plan's conservative cumulative maximum would be
US$57.765907 before tax. The owner approved this exact plan on 2026-09-06.
The one approved run completed from source `b36307b`, with private artifacts at
`/private/tmp/wardrobe-fictional-sonnet-evaluation-20260906-b36307b/`.
That approval permits no automatic retry, repeat run, or production switch.

A read-only Models API lookup with the existing configured key on 2026-09-06
returned the requested `claude-sonnet-5` ID and 1,000,000-token input limit in
0.511 seconds. This metadata lookup made no generation call and does not prove
Messages compatibility or model quality.

The completed run used the evaluation-only profile manifest
`e1972ee4f9162b5f50a6ff3f9bd558143dc5f5feda410a3844f95a41aca05678`.
It independently validates the selected model, priced context/rates, exact
manifest, and numeric ceiling before constructing an API client; a Haiku
approval cannot authorize Sonnet, or vice versa. A token-boundary violation
stops before cost settlement or review-card creation and leaves usage uncertain.

At that historical checkpoint the default was Haiku; it now follows the selected Sonnet candidate.
Preview the current Sonnet
plan without making any API call; it reflects the current source and does not
recreate an earlier historical manifest:

```bash
uv run --locked python -m evaluation.run dry-run --model claude-sonnet-5
```

The exact approved command is recorded below; it is not an instruction to repeat the run:

```bash
uv run --locked python -m evaluation.run live --model claude-sonnet-5 \
  --approved-manifest-sha256 e1972ee4f9162b5f50a6ff3f9bd558143dc5f5feda410a3844f95a41aca05678 \
  --approved-max-usd 58.00 \
  --output-dir /tmp/wardrobe-fictional-sonnet-evaluation-UNIQUE_RUN
```

Full local verification passed on 2026-09-06: **469 backend tests** (including
all 80 evaluation tests), locked dependency audit with no known vulnerabilities,
Bandit including evaluation tooling, Ruff, mypy, **236/236 iOS tests** (226 Swift
and 10 UI), **44 release-script tests**, and the Release simulator build/artifact
checks. The approved Sonnet run completed and failed as recorded below. If a future
Sonnet run passes automatic and human review, the production model/accounting/preflight
must be aligned and validated together before private budget approval and
deployment. A comparison result never authorizes a production switch by itself.

All **28 calls completed** without a provider error or retry. Every response completed
the forced tool call, usage is complete, and all 24 quality scorecards remain blank.
No human-review form was generated because the fixed automatic floor failed.

| Check | Result |
|---|---:|
| Shared schema and known catalog IDs | 24/24 |
| Complete primary and alternate looks | 24/24 |
| Distinct unordered item sets | 24/24 |
| Required alternate count | **23/24 — fail** |
| Primary occasion exclusions | 24/24 |
| Targeted avoidance / preferred items | 4/4 / 3/4 — pass |
| Nearest-rank p95 latency | 13.266 seconds — pass |
| Median / maximum latency | 6.9275 / 14.709 seconds |
| Quality input / output token ranges | 2,003–5,562 / 235–847 |

Call 8, the second black-palette case, returned the black tee, black trousers,
black loafers, and optional black tote with no alternate. Removing the tote leaves
a complete, occasion-compatible, distinct set, so the recorded minimum still applies.
The second humid-walk primary used sandals rather than the preferred sneakers;
that is a soft miss and the aggregate preferred-item threshold still passed at 3/4.
The report's 24 mechanically `usable` results include the missing-alternate failure
and are not 24 accepted recommendations. No threshold was relaxed or response repaired.

Total usage was 75,934 ordinary input, 17,710 output, 1,606 cache-write, and 1,606
cache-read tokens, for **US$0.333305 before tax**. The 24 quality attempts cost
US$0.287822, averaging US$0.0119925833 per attempt. The marked cache pair's input
cost was US$0.008353 versus US$0.010440 uncached, saving US$0.002087 (about 20%).
This passes the warm-pair input-cost test only; it does not establish reuse within
five minutes under real traffic or authorize production caching.

Cumulative known evaluation spend is **US$0.607372 before tax**. Retaining the
original timeout's US$0.205120 uncertainty gives a cumulative conservative bound
of **US$0.812492**. There is no unresolved charge from this completed Sonnet run.
All paid calls are finished. Any revised or repeated run needs new explicit approval.

## Optional-item clarification — automatic pass and owner qualitative acceptance

This prompt revision explicitly checks suitable substitutions and optional
bag/jewelry/accessory additions or removals before returning no alternates. A valid
optional-item change counts as a distinct set while completeness, occasion, and
2–8-item bounds still apply. The tool description also requires at least one alternate
whenever a valid distinct set exists. No case name, color, item ID, fixture expectation,
acceptance threshold, runtime post-processing, model, or request count changed.
The two-item dress-and-shoe capsule still permits zero alternates. The three prior
full-run failures remain recorded failures, and no scores are synthesized.

The revised Sonnet manifest is
`ae2479794e5aa40dc79ed4c555c9f89c9b8bfb4d451bce29120563357931fa06`.
It retains 24 quality calls plus four cache probes, one call in flight, no retries,
the 30-second SDK timeout, no thinking, and 1,024 output tokens. The full-context
bound remains **US$57.286720**, within the approved **additional US$58 pre-tax
ceiling**. The unproven byte-based planning estimate at full output is now
**US$0.917418**. Including prior recorded usage and the original timeout's uncertainty,
the planned cumulative conservative maximum would be **US$58.099212** before tax.
The owner explicitly approved this revised manifest and ceiling on 2026-09-06.
The one approved run completed from source `10e837b`, with private artifacts at
`/private/tmp/wardrobe-fictional-sonnet-evaluation-20260906-10e837b/`.
This approval permits no automatic retry, repeated run, or production switch.

The exact approved command is recorded below; do not repeat the run:

```bash
uv run --locked python -m evaluation.run live --model claude-sonnet-5 \
  --approved-manifest-sha256 ae2479794e5aa40dc79ed4c555c9f89c9b8bfb4d451bce29120563357931fa06 \
  --approved-max-usd 58.00 \
  --output-dir /tmp/wardrobe-fictional-sonnet-optional-alternate-UNIQUE_RUN
```

Full verification passed on 2026-09-06: **472 backend tests**, the locked dependency
audit with no known vulnerabilities, Bandit including evaluation tooling, Ruff, mypy,
**236/236 iOS tests** (226 Swift and 10 UI; zero failures or skips), **44 release-script
tests**, and the Release simulator build/artifact checks. Independent review confirmed
the unchanged evaluation floor and exact revised manifest. The approved run completed as below.
The shared contract and iOS source are unchanged; Build 8 is not required.

All **28 calls completed**, with complete usage, no provider errors or retries, and
one completed forced tool call per response. Independent calculation confirmed the report.

| Check | Result |
|---|---:|
| Shared schema and known catalog IDs | 24/24 |
| Complete primary and alternate looks | 24/24 |
| Distinct unordered item sets | 24/24 |
| Required alternate count | 24/24 |
| Primary occasion exclusions | 24/24 |
| Targeted avoidance / preferred items | 4/4 / 3/4 |
| Nearest-rank p95 latency | 12.665 seconds |
| Median / maximum latency | 7.277 / 14.637 seconds |
| Quality input / output token ranges | 2,195–5,754 / 237–830 |

Total usage was 80,926 ordinary input, 19,346 output, 1,798 cache-write, and 1,798
cache-read tokens. The calculated total was **US$0.360167 before tax**; the 24 quality
attempts cost US$0.308128, or US$0.012839 per mechanically usable recommendation
rounded up to six decimal places. Human acceptance was pending at this calculation checkpoint;
the later qualitative decision is recorded below. These fictional-run costs do not establish a
production unit-cost estimate.

| Cache probe | Ordinary input | Cache write | Cache read | Output | Latency (s) |
|---|---:|---:|---:|---:|---:|
| Off 1 | 2,802 | 0 | 0 | 786 | 7.386 |
| Off 2 | 2,802 | 0 | 0 | 785 | 7.489 |
| Marked 1 | 1,004 | 1,798 | 0 | 798 | 7.681 |
| Marked 2 | 1,004 | 0 | 1,798 | 827 | 7.824 |

The marked pair's reported input cost was US$0.008871 versus US$0.011208 uncached,
saving about **20.9%**. That passes the warm-pair test only; production caching remains
off until a plausible request cadence demonstrates reuse within five minutes.

Cumulative known evaluation cost is now **US$0.967539 before tax**. The original
timeout still contributes up to US$0.205120 of unresolved exposure, giving a cumulative
conservative upper bound of **US$1.172659**. This revised run has no missing usage or
unresolved charge. All paid calls are finished; its approval is consumed.

The original human-review procedure requested all 24 randomized proposals across the
five existing dimensions. The offline form is
`/private/tmp/wardrobe-fictional-quality-review-20260906.html`, generated only from
this run's `blinded-review.json` and blank `scores.json`. It preserves the randomized
order and contains no model, cost, latency, token-count, or automatic-score metadata.
The original score template remains blank. The form runs offline, supports downloading/importing
partial progress, and exports the runner's exact completed-score format. The owner
must supply the ratings; an agent must not substitute its own scores.

On 2026-09-06 the owner supplied `/Users/tth/Downloads/scores-progress.json`.
Its exact flat schema and all 24 unique IDs match this passing run. It contains
**one complete proposal (5 ratings), with 23 proposals and 115 ratings still blank**.
All entered values are valid integers from 1 through 5. The acceptance scorer
correctly rejects the incomplete file; no human-pass decision or model acceptance
was made, and no missing ratings were inferred.

The owner's exact progress is preserved privately at
`/private/tmp/wardrobe-human-review-progress-20260906/scores.json`. A resumed form at
`/private/tmp/wardrobe-fictional-quality-review-resume-20260906.html` preloads those
five ratings while preserving the original blinded order and all 23 remaining blank
cards. The original run report, blank score template, review packet, and first form
are unchanged. This partial-file checkpoint is retained as historical evidence.

The owner then said **"all are ok, proceed"** and accepted all 24 proposals qualitatively.
That instruction selects Sonnet for the local migration without requiring completion of
the numeric scorecards. It is an explicit owner acceptance exception to the numeric-only
review workflow, not proof that all 120 ratings were entered or that the numeric thresholds
passed. The one completed card and 115 blank ratings remain unchanged; the scorer still
rejects the partial file. The automatic floor and all previous failures remain unchanged.
The separate decision record is
`/private/tmp/wardrobe-fictional-sonnet-evaluation-20260906-10e837b/owner-qualitative-acceptance.json`.
The owner also supplied the first-month planning assumption of **up to 10 AI users**.
Budget policy, public-capacity/operations acceptance, source publication, deployment and
distribution required separate decisions; subsequent approvals and completed setup are recorded
at the top of this document. No additional paid evaluation is needed merely to
align the production request with the already evaluated Sonnet request.

If numeric review is resumed later, the completed ratings may be retained against this original
historical report. They do not establish acceptance of a different candidate. The hardened
scorer now verifies the complete saved manifest and its hash against the selected current
source/profile before calculating acceptance; this historical manifest is stale after the
implementation advanced. Do not rewrite it or bypass the check to obtain a current pass.
The existing qualitative owner acceptance and unchanged 28 request hashes remain separately
documented evidence. For a future evaluated run whose manifest matches the current source,
validate the owner's actual exported file with the same explicitly selected model:

```bash
uv run --locked python -m evaluation.run score \
  --model claude-sonnet-5 \
  --report /path/to/current-source/report.json \
  --scores /path/to/owner-exported-scores.json
```

Inspect the returned `accepted` value and retain that decision separately: a successful
command exit only confirms valid scoring input, and the command does not rewrite the
original report. Missing, altered, extra-field, stale-source, or wrong-profile manifests are
rejected before score computation; legacy Haiku scoring must explicitly select its profile.
The unchanged numeric rubric requires every rating at least 3/5 and every
dimension mean at least 4/5; it remains unproven for this run. The qualitative owner exception
above authorizes local model selection and implementation. Align Sonnet runtime/pricing/
full-context accounting/preflight together, repeat validation, and propose the private
launch budget. The owner's quality acceptance does not approve a spend amount or deployment.

## Local Sonnet runtime alignment — verified

Historical local checkpoint, before the production rollout and the approved September 8 setup.

The runtime now selects `claude-sonnet-5`; its exact prompt, tools, service tier,
thinking setting, and 1,024-output limit are unchanged from the accepted request.
Independent reconstruction matched **all 28 request hashes** to the saved passing run.
The current evaluation default follows Sonnet, while legacy Haiku remains an explicit
comparison profile. The implementation-bound manifest changed, so no previous paid
approval can authorize another run. No paid call was needed for this local alignment.

The separate v2 ledger stores the model, micro-USD unit, pricing policy, 2-input/10-output
rates, and full 1M context bound. Default admission reserves 2,010,240 units. Old Haiku,
relabeled schemas, mismatched pricing/context, and underpriced pending reservations fail
closed without upgrade, recreation, reset, or refund. Runtime admission and redacted
production preflight both require matching Sonnet policy; the prior live Fly release/source
lock and historical single-user auth-aggregate policy remain unchanged.

Final verification passed **505 backend tests**, locked dependency audit with no known
vulnerabilities, Bandit including evaluation tooling, Ruff, mypy, **236/236 iOS tests**
(226 Swift + 10 UI; zero failures or skips), **44 release-script tests**, and a fresh
Release simulator build/artifact check. The iOS result is
`ios/DerivedData/SonnetMigrationRegression-20260906.xcresult`; local logs use
`/private/tmp/wardrobe-sonnet-migration-*`. No shared-contract or iOS source changed,
and Build 8 is not required. No public source push, provisioning, provider-console change,
deployment, upload, or physical-device action occurred.

The private launch policy uses the measured cost and the owner's expectation of up to 10
first-month AI users. On 2026-09-06 the owner replied **"approve and proceed"** to the concrete
spend/admission-limit and daily-monitoring proposal. The approved record and disabled
configuration were retained in ignored private release files; no exact private limit is published
here, and no setting had been applied at that checkpoint. This closed the budget/operating-policy
decision. Capacity activation, credit readiness and provisioning were then open and were completed
under the separate September 8 setup approval. That initial policy approval did not itself authorize
paid evaluation, provider-console changes or deployment; current remaining gates are listed above.

## PR #41 review safeguards — verified

[PR #41](https://github.com/tzehon/wardrobe-stylist/pull/41) records source publication, required
checks, Codex review, and merge state.

PR #41 review added two acceptance safeguards. Runtime admission/preflight now pin the configured
output cap and stylist default to integer 1,024 before ledger/provider access. Numeric scoring
independently recomputes the saved manifest hash and compares its complete canonical content
against the current source and explicitly selected model before calculating any acceptance.
Missing, tampered, extra-field, stale-source, and cross-model artifacts fail closed. All 28
accepted request hashes and their order remain unchanged; no prompt, fixture, numeric threshold,
historical artifact, rating, or provider request was changed or added.

Final review-fix verification passed 583 backend tests, locked dependency audit, Bandit, Ruff,
mypy, 236 iOS tests, 44 release-script tests, and fresh Release simulator/artifact checks.
The result bundle is `ios/DerivedData/ReviewFixRegression-20260906.xcresult`, with local logs at
`/private/tmp/wardrobe-review-fix-*`. The approved private cap and v2 ledger format are unchanged;
no new paid call, provisioning, deployment, or TestFlight build is required by these fixes.

## Disabled production rollout — 2026-09-07

Historical checkpoint; the approved September 8 setup supersedes the unprovisioned state below.

After separate owner approval, the merged model/budget and patched runtime source
`d2866a2375dd4795f40a3ab13d273ed138cedd7e` deployed as Fly v11 with AI disabled. The original
Machine and volume were healthy at `2026-09-07T10:36:34Z`; the disabled-only review completed at
`2026-09-07T10:39:08Z`. Exact registry/runtime source and Linux/AMD64 identity matched, and fresh
scans found zero High/Critical vulnerabilities. See the
[deployment and remaining gates](app-store/internal-testflight-runbook.md#disabled-runtime-rollout--2026-09-07).

At this checkpoint the approved private budget policy was unapplied, no budget storage was created,
and no paid model call ran. The broader budget/pre-upload gates remained OPEN. This deployment added no
model-quality or numeric-score evidence, did not reconcile the earlier uncertain charge, and
did not alter the saved reports, missing ratings, or qualitative owner acceptance. Provisioning,
capacity, alerts, prepaid-credit readiness, AI enablement and distribution were then open; the
current setup and remaining gates are recorded at the top of this document.
The preserved Build 7 archive is unchanged; no new TestFlight build is required.

## Fixed paid-call plan and approval

The default profile now follows the selected **Sonnet 5 candidate**, with a US$58
ceiling for a newly approved 28-call evaluation. The legacy Haiku profile remains available
only through explicit `--model claude-haiku-4-5-20251001` and its separate US$6 ceiling.
The following commands default to Sonnet. A hash or approval for one profile cannot
authorize the other, and all previous paid approvals are consumed.

Twelve hand-authored cases each run twice: office, wedding, humid walking, black
palette, recent rotation, positive ratings, negative ratings, a two-item dress
capsule, all items recently worn, custom categories, instruction-like catalog text,
and a 60-item catalog. Four additional calls use the same office catalog: two with
caching off followed by two with a five-minute breakpoint on the static prefix.
There are **at most 28 calls, no SDK retries, one call in flight, and a 30-second
SDK timeout per operation** (not an absolute wall-clock deadline). A provider error stops
the run; an uncertain charge is never
retried automatically. Cache probes are excluded from the 24 quality scores.

Prices verified on 2026-09-06 are USD per million tokens: Sonnet input $2, output
$10, five-minute cache write $2.50, cache read $0.20. This is the first-party global
API, with no batch, priority, regional, or server-tool surcharge. The approval
estimate uses the full 1,000,000-token context ceiling as a conservative input cap
for every call, plus the 1,024 output cap. It assumes every input token of both
cached probes incurs the write premium:
`26 × (1000000 × 2 + 1024 × 10)/1000000 + 2 × (1000000 × 2.50 + 1024 × 10)/1000000`
= **$57.286720 maximum estimated API usage**, rounded up to a proposed **$58.00
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
  --approved-max-usd 58.00 \
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

Haiku's cache minimum is 4,096 tokens; Sonnet 5's is 1,024. Haiku's measured zero
reads do not predict Sonnet's behavior; do not pad the prefix merely to manufacture
a cache hit. Read the selected model's four probe rows'
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
