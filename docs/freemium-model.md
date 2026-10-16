# Free launch and future freemium model

> **23 September status:** Apple approved build 7 and the owner-authorized manual release
> completed after the full preflight passed. The public Singapore listing is live and availability was verified. Fly v15 was deployed at that checkpoint. See the [launch record](app-store/launch-check-20260923.md) for that dated evidence;
> earlier rejection, wait-for-reply and unapproved-release statements below are historical.

Status: **the approved public v1 is Free in Singapore, with no purchases or subscriptions.**
Freemium is the next product milestone after that launch, not a feature of the current build.
This document is the canonical product-model reference; the
[release plan](release-plan.md) sets the work order and
[APP-037 in the backlog](app-release-backlog.md#p2--feature-enhancements-after-the-public-release-foundation) tracks implementation.

## What exists now

The `1.0.0 (7)` candidate includes the local wardrobe, manual/photo entry, catalog browsing and
editing, wear history, local reminders and Demo Mode without payment or a Wardrobe account.
Optional AI styling is implemented and enabled as the owner-approved bounded Fly v17 pilot (zlib remediation and build-8 allowlist; unchanged budget).
The 12 September v13 activation review passed with the scoped Cowork-only exception. The v14
configuration postcheck passed, followed by its full operations review at `2026-09-12T07:09:37Z`
with the approved Cowork-only status exception. The first protected
TestFlight styling result passed on 12 September. Styling requires in-app consent
and remains subject to the global safety limits. Local features work independently of AI.
Build 7 has completed [internal TestFlight distribution](app-store/internal-testflight-runbook.md#build-7-distribution--2026-09-10).
The [11 September checkpoint](app-store/internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial)
records the completed handoff, clean installation and scoped local-beta QA. Bounded activation
is complete; protected-device styling proof passed on 12 September; manual release completed on 23 September; public Singapore storefront availability was confirmed by 14:44Z on 23 September. See the
[activation checkpoint](app-store/internal-testflight-runbook.md#bounded-ai-pilot-activation--2026-09-12).
The planned freemium offering is unchanged.

There is no StoreKit purchase flow, subscription entitlement service, customer-level monthly
allowance, Plan & Usage screen, Restore Purchases or Manage Subscription control in the current
source. The existing backend budget and hourly abuse limits do not constitute freemium metering.
Free v1 does not promise unlimited AI or a particular number of generations per person.

The developer pays the AI provider and hosting costs; users do not purchase credits, supply an
API key or need a Claude subscription. The item editor's optional Purchase/Price/Currency/date
fields record the cost of physical clothing already owned; they do not sell anything or unlock
app features. These distinctions are covered in the
[16 September App Review business-model response](app-store/business-model-response-20260916.md).

## Planned Free and paid offering

The intended model keeps the local wardrobe useful for free and sells a larger, fixed allowance
of fresh AI styling through a monthly Apple subscription. No additional paid feature bundle has
been approved. The paid name, price and numerical allowances still need decisions before selling
anything; “Plus” is a working name.

| Aspect | Public v1 — approved | Future Free — planned | Future paid plan — planned |
| --- | --- | --- | --- |
| Availability | Singapore only | Singapore initially | Singapore initially |
| Local wardrobe, photos, history, reminders and Demo Mode | Included without payment | Remain available without payment | Same local core |
| Fresh AI styling | Optional; bounded internal pilot enabled, subject to consent and global safety controls | Smaller fixed allowance | Larger fixed allowance |
| Customer allowance | No per-person monthly product quota implemented | Number and final reset rule undecided | Number undecided; subscription-period reset is the design direction |
| Price | Free; no IAP or subscription | Free | Localized monthly price undecided |
| Purchase and account model | No purchase or Wardrobe login | Preserve no Wardrobe login | Apple purchase, verified by the backend; no Wardrobe login |

The earlier **5 Free generations per UTC calendar month** and **60 Plus generations per verified
subscription period** are proposed starting points only. They are not approved launch allowances,
configured customer quotas or a published offer. No paid price has been approved. Country expansion
comes after the Singapore freemium model, restoration, accounting and operations are proven.

## What would consume an allowance

Planned metering counts a successful fresh styling generation, including a successful **Restyle**.
The primary look and alternates returned together form one generation. Viewing or restoring an
existing look, choosing one of its saved alternates, recording **Wear this**, and using local
features do not create another generation. Failed attempts must not silently consume a customer's
allowance. Exact handling of cancellation, lost responses and interrupted requests needs to be
specified and tested before charging.

The backend must reserve customer allowance atomically and finalize it idempotently, so duplicate
requests cannot spend the same allowance twice or bypass it. Customer exhaustion needs a clear
quota response and UI, distinct from temporary service unavailability or an hourly abuse limit.
Neither a reinstall nor a client-supplied remaining count may reset the server's usage record.
Live customer metering remains **planned, not enabled**. An inactive pure quota policy and usage
snapshot contract now exist; verified ownership, durable storage and API integration remain open.

## What customers must see before purchase

The paid release must show a plain comparison of Free and paid inclusions, the current plan,
the exact allowance and remaining usage, and when it resets. It must also show the StoreKit-localized
price and billing period, purchase confirmation, and visible **Restore Purchases** and
**Manage Subscription** controls. Quota exhaustion and a service-wide safety pause need different
messages. A paid plan cannot imply uninterrupted or unlimited AI when a global safety control can
temporarily stop generation.

Renewal, expiration, refund, revocation, grace and billing-retry states must be handled from
verified Apple information. The following product decisions remain open:

- Final plan name, monthly price, Free and paid numbers, and Free reset boundary.
- Rollover, upgrade timing, and allowance allocation when moving between Free and paid periods.
- Cancellation/downgrade timing and treatment of any remaining allowance.
- Grace-period and billing-retry behavior, refunds/revocations, and any Family Sharing offering.
- Customer communication and support response when the global safety budget pauses paid AI.

Do not turn these undecided behaviors into marketing promises or current-app instructions.

## Next decision packet — 29 September

The owner authorized proceeding with production-key rotation and preparation for the next
milestone. That instruction does not select a paid price or approve the proposed numeric
allowances. The [rotation and verification](app-store/key-rotation-20260929.md) are complete;
the public app remains Free. Product decisions below remain pending.

| Decision | Review starting point | Evidence or choice still needed |
| --- | --- | --- |
| Plan name and allowance | Working name Plus; earlier proposal of 5 Free generations per UTC month and 60 paid generations per verified subscription period | Owner selection of the name, numbers and Free reset boundary |
| Monthly price | No price selected | Current Apple commerce terms and Singapore price options, measured cost per successful generation, hosting/support allocation and margin under the existing global budget |
| Rollover and plan changes | Proposed: no rollover; cancellation retains paid access until the verified period ends | Owner decision; specify upgrade allocation so switching plans cannot grant duplicate allowances |
| Billing interruptions | Keep local features available; derive paid AI access from verified Apple subscription state | Decide grace/retry policy and refund/revocation treatment before implementation |
| Family Sharing | No offering selected | Explicit inclusion/exclusion and, if included, ownership and shared-allowance rules |
| Global safety pause | Preserve the independent owner-approved spend ceiling | Agree on customer wording and support response when paid AI is temporarily unavailable |

The [1 October commerce and usage contract](freemium-contract.md) guides the first implementation slice for
S$4.98/30, including ownership, atomic usage, recovery and the legacy-route transition. It explicitly
defines bounded automatic delivery credits; Apple proof verification, retention and cutover remain open.
The inactive quota policy and usage snapshot mirrors are implemented locally; full validation,
Apple verification, transactional persistence, endpoint integration and paid launch remain open.

### Inactive implementation authorization — 14 October

The owner instructed continuation of Wardrobe Stylist work on 14 October and then explicitly
said to proceed and open PRs where appropriate after reviewing the ownership/cutover design
checkpoint. This authorizes the next inactive collect-and-sign implementation, its tests and
reviewable binding/recovery preparation while the previously deferred cost validation remains
open. See the [scoped design](commerce-binding-cutover.md) and [current work order](release-plan.md).

This is not approval of final pricing, billing interruptions, Family Sharing, account-change
product behavior, retention/provisioning or paid activation. Keep those decisions open; any
inactive lifecycle/schema work is provisional and must be reconciled with the final approved
terms before integration. Do not expose purchase UI, persist new customer metadata in production,
or activate quotas from this implementation authorization. The existing Free pilot stays in place.

Once the product decisions are approved, integrate and deliver APP-037 in this order; the
scoped inactive preparation above may precede that approval:

1. Specify the commerce/usage contract, ownership, idempotency and interrupted-request behavior.
   Keep commerce records separate from installation security metadata and the global AI ledger;
   wardrobe, prompt and response payloads remain unpersisted on the backend.
2. Implement server-verified entitlements and atomic customer metering, with lifecycle and
   duplicate-request regressions, while preserving the current client's compatible API behavior.
3. Implement the iOS Plan & Usage, purchase, restore and manage controls with exact inclusions,
   localized price, remaining allowance/reset time and distinct exhaustion/safety-pause states.
4. Run the full repository regressions and targeted Apple sandbox/TestFlight commerce checks.
   Verify the latest uploaded build before assigning the next unused build number. A new
   TestFlight build is required for the shipped purchase/usage UI; build 7 must not be reused.
5. Review the complete Singapore offer and operating evidence before enabling paid distribution.
   Country expansion remains a later milestone.

This packet prepares decisions and delivery order only; it creates no StoreKit product,
subscription, entitlement, customer quota or new spending allowance.

## Pricing and allowance proposal — 1 October 2026

**Current candidate for cost validation: Wardrobe Plus at a target S$4.98/month, with 30 successful fresh
generations per verified subscription period; Free gets 5 per UTC calendar month.** Thirty
generations supports roughly one fresh look per day; cached looks and returned alternates remain
available without additional usage. Start with one paid tier, no rollover and no Family Sharing.
The owner asked to proceed with profitability validation of S$4.98/30 after discussing the
S$6.98/30 and S$4.98/15 alternatives. This replaces those alternatives as the current candidate
to assess. These are proposed terms, not an approved paid launch, a configured Apple price point
or implemented limits. The earlier 60-generation allowance remains an unselected alternative.
Willingness to pay has not been measured. Keep the public app Free while validating the proposal.

### Evidence and calculation assumptions

The accepted fictional Sonnet run recorded US$0.308128 for 24 mechanically usable quality
results: **US$0.0128387 each**, before tax. Input/output ranges were 2,195–5,754 / 237–830 tokens;
there were no provider errors or retries. This small fixture sample is not a production average,
percentile or upper bound. See the [evaluation record](model-evaluation.md) for source-bound
results and the separate qualitative acceptance. Do not repeat paid evaluations for this proposal.

The repository pins uncached input/output rates of US$2/US$10 per million tokens, last externally
verified on 6 September. Production caching remains off. The runtime reserves
`(1,000,000 × 2 + 1,024 × 10) / 1,000,000 = US$2.01024` for each admission, then settles a
successful response to checked usage. A known terminal failure retains that charge; an uncertain
failure retains both the charge and its concurrency slot. See
[`styling_runtime.py`](../backend/app/styling_runtime.py) and
[`styling_budget.py`](../backend/app/styling_budget.py). The reservation is safety-ledger exposure,
not evidence that the provider invoices US$2.01024 for every call.

| Input | Value used here | Status and limitation |
| --- | --- | --- |
| Cost per successful generation, `c` | US$0.03 planning; US$0.06 stress | Rounded scenarios, about 2.34× / 4.67× the fictional mean; allow for larger requests and cost drift, but are not measured production costs or maximums |
| SGD per USD, `x` | 1.40 | Planning conversion buffer, not a current FX quote; replace with effective settlement FX and provider tax/fees |
| Consumer-price tax deduction, `t` | 9% | Illustrative Singapore tax scenario; confirm actual Apple tax treatment and proceeds |
| Apple deduction, `a` | 30% base; 15% sensitivity | Scenario assumptions; no claim of Small Business Program enrollment or eligibility |
| Hosting/operations, `H` | Unknown; S$15/month in the example only | Includes allocated recurring non-AI costs; not the private Fly bill, a quote or an invoice cap |
| Support allocation, `s` | S$1 per paid subscriber/month in the example | Illustrative labor reserve, not measured support cost |
| Utilization | 100% of both allowances | Do not rely on unused paid or Free quota to make the offer viable |

Current Apple commerce terms, Singapore price-point availability, FX and provider pricing were
not refreshed on 1 October: the workspace network policy does not allow the relevant public
Apple/Anthropic sites, and no signed-in commerce or billing evidence is available here. Before
selecting an offer, verify [Apple subscription terms](https://developer.apple.com/app-store/subscriptions/),
[Small Business Program terms](https://developer.apple.com/app-store/small-business-program/),
[App Store Connect pricing](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-a-price-for-an-auto-renewable-subscription/)
and [provider pricing](https://platform.claude.com/docs/en/about-claude/pricing).
Use Apple's actual estimated proceeds once available; do not subtract the modeled fees/tax twice.

### Price and allowance comparison

For a tax-inclusive SGD price `P`, modeled proceeds are `R = P / (1 + t) × (1 − a)`.
Direct AI cost at allowance `q` is `q × c × x`. The following uses 30% Apple deduction,
9% tax and 1.40 SGD/USD. Values are SGD per paid subscription period, rounded to cents.
Contribution here excludes hosting, support, Free-user subsidy, refunds and retained failed-call
liability; it is not profit. Calculations use unrounded intermediate values.

| Target monthly price | Modeled proceeds | 30 generations, US$0.03 each: contribution | 30 generations, US$0.06 each: contribution | 60 generations, US$0.06 each: contribution |
| --- | ---: | ---: | ---: | ---: |
| **S$4.98** | **3.20** | **1.94** | **0.68** | **−1.84** |
| S$5.98 | 3.84 | 2.58 | 1.32 | −1.20 |
| S$6.98 | 4.48 | 3.22 | 1.96 | −0.56 |
| S$8.98 | 5.77 | 4.51 | 3.25 | 0.73 |

At S$4.98, a 15% deduction would instead leave S$3.88 proceeds and S$1.36 after 30 stress-cost
generations, before the other costs above. Do not base launch viability on that favorable rate
until the account qualifies. The selected candidate for validation is S$4.98/30: it can cover
costs in the planning scenario at sufficient demand, but has much less headroom in the stress case.
None of these target prices is verified as an available StoreKit price point.

Free usage must be funded too. Five fully used Free generations cost S$0.21 in the planning
scenario or S$0.42 in the stress scenario per Free user/month. For paid subscribers `N` and
Free users `F`, approximate monthly operating contribution before income tax is:

`N × (R − q × c × x − s) − H − F × 5 × c × x − D`

`D` is refund/chargeback and other proceeds loss not already included in `R`. Actual provider
charges for failed work must be included in measured `c` (all attributable charges divided by
successful generations), or added separately once, not omitted or double-counted. The scenario
values for `c` are assumptions and do not establish a measured failure-adjusted cost.

For illustration only, set `D = 0`, `H = S$15`, `s = S$1` and `F = 20`. At S$4.98/30, before
the additional delivery-credit sensitivity below:

| Full-allowance scenario | US$0.03 planning cost | US$0.06 stress cost |
| --- | ---: | ---: |
| Paid contribution after AI and assumed support, before hosting/Free usage | S$0.94 | −S$0.32 |
| Hosting plus 20 Free users | S$19.20 | S$23.40 |
| Monthly result with 10 paid subscribers | −S$9.82 | −S$26.62 |
| Monthly result with 25 paid subscribers | +S$4.25 | −S$31.45 |
| Break-even paying subscribers, keeping Free users fixed at 20 | **21** | **None: each additional subscriber loses money** |

These examples exclude unmeasured refunds and other omitted costs and do not prove profitability.
The Free population may grow alongside subscribers; recompute that mix instead of extrapolating
the fixed-20 example. Even if Apple's 15% rate applies, the stress example would need **65** paid
subscribers with those same assumptions. These counts do not authorize expansion of the pilot.

**Delivery-credit sensitivity:** the owner selected bounded automatic credit for a completed look
that does not reach the device. The contract sets an initial design cap of one credit per owner
per allowance period. If every paid and Free user uses that credit and requests a replacement,
model 31 paid and 6 Free successes rather than 30/5. At the same planning costs, paid contribution
after assumed support falls to **S$0.90**, hosting plus 20 Free users becomes **S$20.04**, and
break-even rises from 21 to **23 paying subscribers**. At 25 subscribers, monthly contribution
is **S$2.36**. The stress case still has no break-even: paid contribution after assumed support
is **−S$0.41** before hosting and Free usage. These are modeled costs, not verified profit.
Use `31 × N + 6 × F` in the cost denominator for full credit utilization; do not double-count
replacement costs if a later observed cost per net consumed unit already includes them.

Assess safety-budget capacity separately from operating contribution. Each retained failed
admission adds US$2.01024 (S$2.814336 at the assumed FX) to conservative ledger liability,
even when the provider's actual charge is smaller or zero. As an additional reserve sensitivity,
subtracting two full retained reservations from the planning example raises required paying
subscribers from 21 to **27**; that is reserve coverage, not an observed expense or accounting
profit calculation. Avoid counting any provider charge already in `c` a second time. Uncertain
work can also stop admission through the concurrency limit regardless of profitability.

### Operating-evidence check — 1 October 2026

**Result: actual profitability remains unverified.** The checkout has no private billing or
evaluation evidence files, and this managed environment has no configured provider credentials,
outbound identities or Fly CLI. The network policy does not permit the provider/Apple console
hosts, and no browser tool is available. No live billing, ledger or Apple-account check was run.
The owner chose to skip supplying the missing figures on 1 October. Retain the scenario analysis
and leave verification open; that choice is not evidence of profitability or paid-launch approval.

| Required input | Available evidence | Remaining gap |
| --- | --- | --- |
| Production AI cost per successful generation | Fictional evaluation mean only; 29 September rotation records below-warning/idle status | Same-period production charges and successful generations, including failed-attempt costs; amounts and denominator unavailable |
| Hosting allocation | Retained one-Machine/one-volume inventory and owner daily-review procedure | Actual Fly service charges before credits, period coverage, tax and FX; invoice/Cost Explorer discrepancies must remain explicit |
| Apple net proceeds | No verified subscription price or account commerce evidence | Available Singapore price point, actual estimated proceeds, agreements and confirmed commission eligibility |
| Demand, support and refunds | Up-to-ten-user historical pilot assumption | Paid/Free mix, conversion/retention, support effort and refund reserve; none measured here |
| Capacity under the global budget | Source proves reservation/admission rules; dated rotation reports intact limits | Current private limits, remaining liability and request capacity; cannot infer capacity from below-warning status |

The ledger stores admissions, charged units and outstanding reservations, not a durable completed-
generation counter or per-call token history. Successful settlement removes the reservation;
known failures keep their charge and remove their slot. Consequently, `charged_units / admissions`
is neither an observed provider cost nor a cost per successful generation. Use matching provider
billing and an independently evidenced successful-generation count; if the latter is unavailable,
keep unit cost unknown. Do not fabricate success counts from the current pending count or treat
October's counters as September usage after the UTC-month rollover.

For the candidate price, the maximum all-attempt USD cost per successful generation that just
breaks even under the example assumptions is:

`c_max = (N × (R − s) − H − D) / (x × (30 × N + 5 × F))`

With 30% Apple deduction, 20 Free users, S$15 hosting, S$1 support and zero modeled refunds:

| Paying subscribers | Maximum average USD cost per successful generation |
| --- | ---: |
| 10 | 0.012467 |
| 21 | 0.030491 |
| 25 | 0.033575 |

These thresholds exclude delivery-credit replacement use; use the 31/6 denominator above for its
full-use sensitivity. Thresholds are approximate break-even boundaries, not targets with profit headroom. Replace the
inputs with verified effective costs and retain precision before comparing. At ten paid users,
even the fictional mean of US$0.0128387 exceeds the modeled break-even threshold; that comparison
is illustrative, not a production result. The existing evidence supports validating S$4.98/30,
not advertising it as profitable. If commercial validation resumes, use the missing non-secret
billing aggregates and Apple rate confirmation to recalculate privately without committing
account-specific amounts or limits.

### Proposed customer rules

- Free resets at 00:00 UTC on the first of each month (08:00 Singapore time). Display the exact
  local reset date/time. Paid usage follows Apple's verified period boundaries; unused usage
  does not roll over. Local wardrobe, photos, history, reminders and Demo remain free.
- A first verified purchase starts one 30-generation paid allowance. Do not stack unused Free
  quota on top. Renewal allocates once per verified period; restore, duplicate transactions,
  reinstall and switching devices never allocate a second allowance. Specify the anti-reset
  rules for cancellation, re-purchase and Free re-entry in the commerce contract before coding.
- Cancellation retains paid access through the verified paid period. On expiry, use the Free
  allowance with its existing current-month usage, not a newly reset balance. Refund/revocation
  ends paid access when verified. Keep local data and saved looks available.
- Proposed initial policy: no optional billing grace period and no Family Sharing. Billing retry
  alone grants no fresh paid allowance after entitlement expiry. The implementation must still
  honor any grace entitlement Apple actually verifies and reconcile unexpected configuration.
- Count a successful fresh generation, including Restyle, once; returned alternates count in
  that same generation. Recorded failed attempts do not spend customer quota. For a completed
  generation whose result is missing on the phone, automatically restore one unit, capped at one
  delivery credit per verified owner per currently usable original allowance period. This is the
  initial design cap for the owner's selected bounded-credit policy. Duplicate claims never add
  credits; subsequent losses receive a clear usage/support message. See the
  [delivery-credit contract](freemium-contract.md#interrupted-delivery-bounded-automatic-credit).
  No automatic retry, cross-period rollover, result persistence or provider-liability refund occurs.
- Proposed safety-pause copy: “AI styling is temporarily paused. Your wardrobe and saved looks
  remain available. This attempt did not use your allowance.” Also show the verified reset date,
  support, Restore Purchases and Manage Subscription. Explain before purchase that unused usage
  expires and a service pause can prevent use. The bounded delivery credit is distinct from a
  service-pause credit or monetary refund; do not promise either of those automatically.
  Support should record affected periods, explain Apple's refund-request route and escalate
  prolonged disruption. Agree on a response target and remediation policy before selling.

### Evidence required to select the offer

1. Confirm the available Singapore price, actual Apple proceeds/agreements, billing settings and
   effective currency/tax costs. Refresh provider prices against the pinned runtime.
2. Use existing payload-free aggregates to estimate representative production cost, request sizes,
   failure/uncertain-call frequency and demand. Mark unavailable measures unknown; do not add
   wardrobe/prompt logging or make new paid calls to manufacture evidence. Recalculate with actual
   hosting allocation, support, refunds and Free-to-paid mix, including full allowance use.
3. Privately reconcile projected paid and Free demand with the unchanged global request/spend
   ceilings, existing liability, per-call reservation and concurrency limit. Aggregate quotas must
   fit supported service capacity; revenue and customer quota never override admission guards.
   A positive contribution calculation does not prove the global budget can serve the offer.
4. Select the final name, price, quotas and lifecycle/support policies before integrating and
   activating the prepared APP-037 components in the order above. Scoped inactive work may
   continue under the 14 October authorization. S$4.98/30 is conditional on these economics and service checks;
   it is not ready for paid distribution. Country expansion remains after proven Singapore operation.

The proposal is now accompanied by inactive policy/contract source. No live subscription, customer
quota, paid call, production change or new spend envelope was created. A new TestFlight build is
required before distributing the changed iOS source; select the next unused build only after
checking App Store Connect. The current build number remains unchanged.

## Ownership, verification and privacy

**Implemented:** App Attest proves access from an app installation and supports short-lived backend
sessions. Its installation identity is not a purchase account and changes after reinstall or
migration. It cannot own a subscription or durable customer quota.

**Planned:** use StoreKit 2 and server-verified Apple purchase information for paid entitlement and
customer usage ownership. The proposed identity is Apple's `appTransactionID`, with its signed
binding verified rather than trusting an arbitrary client identifier. Apple documents that this
identifier is available without IAP and remains stable for the same Apple Account and app across
redownloads and devices. This capability is not integrated into Wardrobe yet.
[Apple app transaction identity](https://developer.apple.com/documentation/storekit/apptransaction/apptransactionid).

Purchase restoration must recover verified access without inventing unused allowance. StoreKit
current entitlements, transaction updates and server-side signed transaction verification must
support the lifecycle; server notifications and reconciliation are part of the planned design.
A client `isSubscribed` flag is insufficient. Apple's current-entitlements API excludes refunded
or revoked products, illustrating why one cached purchase flag cannot represent current access.
[Apple current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements),
[Apple transaction verification](https://developer.apple.com/documentation/storekit/transaction).

Planned commerce records contain only the purchase/period/usage metadata needed for ownership and
accounting, separately reviewed from App Attest security storage and the global AI budget ledger.
They must not contain wardrobe, prompt or model-response payloads. Their retention, deletion and
public disclosures need review before the paid release. This is additional planned backend
metadata, not a claim that the current app already stores Apple purchase identity.

## The owner's budget remains independent

**Implemented and applied to the enabled bounded pilot:** a durable global monthly AI ceiling,
request ceiling, bounded concurrency, conservative pre-call reservations and a fail-closed switch.
The exact approved limits remain private. The provider workspace cap and credits with auto-reload
off provide additional controls. See [AI spend controls](ai-spend-controls.md).

The estimate of up to ten initial AI users is a planning assumption, not an enforced customer
limit or an allowance. Future customer allowances must sit behind the global controls. Adding
subscribers does not automatically raise the owner's budget. A customer may have allowance remaining while the service
cannot safely admit another call; the product must disclose and handle that state before charging.
Final prices and allowances need conservative cost modelling and sufficient operating headroom.

Customer usage and provider liability are different records: a failed or uncertain request may
retain a conservative charge in the global safety ledger even when it does not consume the
customer's successful-generation allowance. Never erase that liability to restore product quota.
Fly hosting is a separate variable expense; neither a subscription quota nor the AI ledger caps
the Fly invoice. See [hosting controls](fly-spend-controls.md).

## Delivery status

The approved sequence is Free Singapore v1, then freemium in Singapore, then carefully selected
country expansion. This documentation does not add a paywall, enable AI, configure an Apple product
or authorize purchases. A later freemium implementation requires the customer UI, verified commerce
and metering, lifecycle/restore tests, privacy review and a new iOS build through the full release
process. The inactive foundation has not been distributed; its new Swift source requires a new
TestFlight build before distribution.
