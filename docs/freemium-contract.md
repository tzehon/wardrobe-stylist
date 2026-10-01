# APP-037 commerce and usage contract

Draft, 1 October 2026. This is the next design step for the owner-selected validation candidate
**S$4.98/month, 30 Plus generations per verified subscription period, 5 Free generations per UTC
calendar month**. See [the product and cost proposal](freemium-model.md). Actual-cost verification
was deferred at the owner's request; profitability, Apple price availability and paid launch remain
unverified. The inactive policy and usage-snapshot foundation below is implemented locally; Apple
verification, persistence, commerce routes and purchase UI remain planned. Existing build 7 and
production remain unchanged.

## Foundation implementation — 1 October

- [`backend/app/commerce/usage.py`](../backend/app/commerce/usage.py) implements pure immutable
  period/usage transitions: 5 Free / 30 Plus, one outstanding operation per bucket, ordinary failure
  release, idempotent outcomes, one delivery credit, late settlement to the original period and
  rejection of cross-owner transitions, expired credits and clock regression.
- [`commerce-usage.schema.json`](../shared/schemas/commerce-usage.schema.json), its
  [Pydantic mirror](../backend/app/schemas/commerce.py), [Swift decoder](../ios/Wardrobe/Backend/CommerceUsage.swift)
  and [shared fixtures](../shared/fixtures/commerce-usage.json) distinguish gross successes,
  delivery credits, net usage, reservations and remaining balance. They reject inconsistent
  snapshots. No purchase price or wardrobe/owner payload appears in the snapshot.
- This is not a transactional store. The caller must supply verified ownership and Apple periods;
  a future store must preserve unique owner/period grants, serialize changes or compare revisions,
  enforce outstanding-operation exclusion across periods, and validate issued operation handles.
  Bucket revisions in the pure policy are local transition counters; the storage/API layer must
  supply a monotonically increasing owner-level snapshot revision across period/plan changes.
  Pure transition tests do not prove concurrent persistence, Apple entitlement restoration,
  dispatch-once behavior or cross-store recovery. No route imports this policy.
- Regression checks also required a lockfile-only update of the existing development dependency
  `urllib3` from 2.7.0 to 2.8.0 after pip-audit reported three advisories. No production deployment
  or budget mutation occurred. Validation results and remaining toolchain limits are in the README.

Backend validation passed 930 tests plus locked audit/Bandit/Ruff/mypy. The Swift decoder/tests
remain uncompiled because this environment has no Apple toolchain. Release-script validation is
39 passed / 5 environment errors (missing Clang). The foundation is not fully verified or releasable.

The next implementation work is verified Apple ownership and durable commerce storage, including
the remaining privacy/retention decisions. Purchase UI and live activation are later steps.

## Scope and invariants

Local wardrobe, photos, history, reminders, cached looks and Demo remain free. A successful fresh
generation, including Restyle and its returned alternates, consumes one unit. No rollover, extra
paid tiers or Family Sharing are proposed for the first release. Show StoreKit's localized price
and period, exact inclusions, usage/reset date, restore and manage controls before purchase.

Installation authorization, customer commerce and provider spending remain separate:

| Record | Authority | Required invariant |
| --- | --- | --- |
| Installation/session | Existing App Attest proof | Reinstall changes installation identity; it cannot reset customer usage |
| Commerce owner and entitlement | Server-verified Apple evidence | Restore/device changes recover existing entitlement and usage, never a fresh allowance |
| Customer usage | Durable server transaction | Concurrent requests cannot exceed allowance; one operation finalizes at most once |
| Provider liability | Existing global AI ledger | Customer refunds, cancellation or subscription revenue never reduce retained provider liability or raise limits |

Backend persistence excludes catalog content, item IDs, prompts, recommendations and response
payloads. Keep commerce metadata out of the App Attest database and the provider ledger. No
Wardrobe login, client-trusted subscriber flag, client-owned balance or anonymous remote-AI fallback.

## Verified ownership and Apple lifecycle

The proposed owner key is a namespaced, server-derived pseudonym of verified Apple
`appTransactionID`, with environment and app identity included. This is a design dependency,
not a claim that the current deployment supports it. Verify official signed-field availability,
device-proof binding and OS requirements before implementing the verifier. The app targets iOS 18;
do not silently raise that target or invent an installation-based fallback on unsupported systems.
Keep local features usable and disable remote commerce/AI with an actionable message if proof
cannot be obtained. Explain this limitation before offering a purchase.

Require an App Attest session plus cryptographically verified Apple ownership evidence to bind a
commerce owner to an installation. A valid signed transaction alone is not proof that its bearer
owns it: validate Apple's documented device/ownership proof and replay/freshness rules. A new
installation may restore the same owner; a client-supplied ID or `appAccountToken` alone must not
create or transfer ownership. Support account changes explicitly: revoke the prior commerce binding,
settle or reconcile its pending operation, then independently verify the new owner. Do not switch
owners merely because an unverified client field changed.

Use a maintained Apple verification library with pinned dependencies and official trust roots.
Verify signature/chain, app/bundle identity, environment, configured product, subscription group,
ownership type, transaction/period IDs and time bounds. Production must reject sandbox and Xcode
test evidence; test routes/storage stay isolated. Never accept a trial, shared-family entitlement
or unknown product as paid entitlement for this initial offer.

Process StoreKit transaction updates, verified server notifications and server reconciliation.
Deduplicate transaction/notification IDs and reject stale events that would resurrect revoked
access. Do not grant a new period based solely on notification type or arrival order. On purchase,
send verified evidence to the backend and refresh entitlement; show pending verification if that
fails instead of promising paid usage. Finish a StoreKit transaction after durable entitlement
processing; replay after a crash must be harmless. Restore is explicit and never buys again.

| Verified state | Entitlement and usage behavior |
| --- | --- |
| Initial purchase | One 30-unit bucket for that verified paid period; no unused Free units stacked on top |
| Renewal | One new bucket for the new verified period; duplicate evidence grants nothing extra |
| Auto-renew disabled/cancelled | Existing paid period remains usable until verified expiry |
| Expired | Return to the existing current-UTC-month Free bucket; do not reset prior Free usage |
| Billing retry without valid entitlement | No new paid period or quota; local features stay available |
| Apple-verified grace | Honor the verified entitlement through its verified grace boundary; reuse its bucket without inventing a new allocation; reconcile later renewal evidence |
| Refunded/revoked | Deny new paid admissions when verified; keep usage/revocation records and local saved looks |
| Verification unavailable | Do not create or extend a grant; existing verified access lasts only to its verified boundary and freshness deadline |

Proposed configuration disables optional billing grace initially, but reconciliation must handle
real verified grace if encountered. Free buckets use UTC calendar months; Plus buckets use Apple's
verified periods. Store UTC instants and display the device-local boundary (Free is 08:00 on the
first in Singapore). Server time, not the device clock, selects the period. Clock regression fails
closed. A request admitted before a boundary settles against its original bucket; it cannot debit
the next bucket. No new operation for that owner starts until the old operation is resolved.

Re-purchase/restore must not duplicate a previously granted paid period. Free re-entry uses that
month's existing bucket. Overlapping, conflicting or shortened paid periods require reconciliation
before granting another bucket; do not add allowances by summing overlapping transactions.

## Proposed API boundary

Names below are draft endpoints, not deployed routes. All except the Apple notification receiver
require the existing backend session. Scope every operation lookup/mutation to the verified commerce
owner; return a generic missing-resource response across owners. Bound payload sizes, rate limits
and stored operation counts. The notification receiver authenticates signed Apple evidence and
must not rely on a caller-supplied secret query parameter.

| Endpoint | Purpose and response contract |
| --- | --- |
| `POST /commerce/bind` | Verify Apple ownership and bind it to this authorized installation; return usage snapshot |
| `POST /commerce/reconcile` | Verify purchase/restore updates; return current entitlement and usage, with no new purchase side effect |
| `GET /commerce/usage` | Return plan, allowance, consumed, reserved, remaining, period start/end, entitlement status and AI availability |
| `POST /commerce/operations` | Create one opaque operation handle for this owner and period; no provider call or quota debit yet |
| `POST /v2/recommend` | Submit that operation handle and the existing recommendation input; reserve usage and global admission, then call the provider at most once |
| `GET /commerce/operations/{id}` | Return only durable operation state and usage outcome; never replay an outfit payload |
| `POST /commerce/operations/{id}/delivery-credit` | Apply the bounded missing-delivery credit once, or return its existing result and current usage |
| `POST /commerce/apple-notifications` | Verify/deduplicate lifecycle event, reconcile affected entitlement and acknowledge durable processing |

`remaining = allowance − consumed − reserved`, never negative. Report `quota_exhausted` separately
from `service_paused`, `verification_required`, `operation_pending`, `entitlement_expired` and
`rate_limited`. Include a server timestamp and snapshot revision so an older response cannot
increase the displayed balance after a newer mutation. Availability never promises that a later
admission will succeed. Offline display is labeled last-known; local remaining counts authorize
nothing. Price comes from StoreKit, never a hardcoded S$4.98 label in the purchase flow.

The operation handle is server-issued, owner-bound, cryptographically unpredictable and tied to a
bounded validity interval. A unique database constraint makes its first accepted submission win.
A repeated handle returns its existing state without executing the supplied body again, even if
that body changed. It does not need a persistent digest of private wardrobe content. An expired,
unknown or pruned handle must never start a new call. Retain terminal deduplication metadata through
the full validity/reconciliation interval; unresolved operations must not be evicted to make room.

The usage snapshot's schema and fixtures now have Pydantic and Swift mirrors. Define the remaining
endpoint schemas with their implementation slices. The current [outfit response](../shared/schemas/outfit.schema.json) remains
unchanged for the existing route. The versioned response adds operation/usage metadata around that
validated outfit rather than changing the current client's required fields in place.

## Atomic metering and cross-store recovery

Use a separate durable commerce SQLite store on the existing storage topology, with restrictive
permissions and explicit provisioning. Persist owner/binding metadata, verified entitlement
periods/revocations, bucket counters, operation state and replay identifiers only. Choose retention
periods and disclose them before provisioning; do not auto-create a replacement if storage is lost.

Within one commerce transaction, validate entitlement/period, ensure sufficient balance, enforce
one outstanding generation per owner across devices, and reserve exactly one unit. Then obtain
global admission from the existing AI ledger before contacting the provider. Rejecting a request
before global admission releases only the customer reservation. Neither store may bypass the other.

There is no atomic transaction across the commerce and existing provider databases. Use durable
intent/outcome states and explicit recovery instead of claiming cross-store exactly-once behavior:

1. Commit the customer reservation and operation intent before global admission.
2. Persist a dispatch fence before provider invocation. Only its winning worker may dispatch;
   a restart, duplicate request or expired worker lease must never re-dispatch it.
3. Reserve global liability. Correlate the opaque global reservation to the commerce operation
   through a reviewed metadata-only design; no catalog or model output enters either store.
   A crash between the two commits leaves reconciliation work, not permission to reserve/call again.
4. Invoke the provider once, apply the existing schema/known-item checks and settle checked global
   usage. Commit the customer outcome before returning a successful response. If either outcome is
   uncertain, retain the conservative global liability and prevent another call for that operation.
5. A verified model/provider failure releases customer usage once. An interrupted worker enters
   reconciliation; a timeout alone cannot prove provider quiescence or authorize slot recovery.
   Once quiescence and durable outcomes are reconciled, release a customer reservation with no
   committed success. Never refund or clear global liability to repair customer quota.

Invariants to test include `consumed + reserved <= allowance`, one customer outcome per operation,
at most one provider dispatch per operation, and no automatic provider retry. A commerce-store
failure, unresolved reconciliation or lost ownership evidence closes new remote AI. Keep ordinary
catalog browsing and cached looks available. Do not weaken the existing budget store to implement
idempotency; any added correlation requires a versioned, tested migration with preserved liability.

## Interrupted delivery: bounded automatic credit

The current route validates and settles the provider result before returning it. A network failure
after a successful generation can lose that response. With no backend result persistence, the
server cannot replay it after a restart; neither HTTP write completion nor a client acknowledgment
proves that the user received and saved it. Client-controlled acknowledgments also cannot safely
be the sole condition for charging: withholding them could bypass customer quota.

The owner selected automatic credits within a defined limit on 1 October. The initial design cap
is **one automatic delivery credit per verified owner per allowance period**, for both Free and
Plus. This cap is a design default; the owner's selection was the bounded automatic-credit policy.
Ordinary recorded provider/model failures remain uncharged and do not use this recovery credit.

Charge once when a valid generation is durably committed. On connection loss, the app first checks
its durable local result and the operation's server status. Save a received result locally with
the operation ID before changing the UI; relaunch restores that result without another call. If
the server recorded success but the device has no result, automatically request one delivery
credit. Keep the previous cached look visible throughout. A pending/uncertain generation must be
reconciled first; it is not eligible for a success-delivery credit.

The credit endpoint requires the existing authenticated session and verified owner binding. In
one commerce transaction, verify that the operation belongs to this owner, succeeded and consumed
one unit, belongs to the owner's currently usable original allowance period, and has no previous
adjustment. Enforce unique credit records for both `(owner, period)` and `operation_id`; decrement
net consumed usage by exactly one and increment a separate recovery-credit counter atomically.
Retain the original success outcome and gross successful-generation count for reconciliation.
Concurrent requests on two devices cannot award two credits. An already credited operation returns
the same adjustment result without another mutation, even if a later period is now current.

Do not add to the advertised allowance or permit net consumed usage below zero. A credit returns
one spent unit to its original bucket. It cannot carry into a later bucket, extend expiry, restore
a revoked entitlement, stack unused Free and paid quotas, or reset on reinstall/restore/device
change. Claims first received after the original period is no longer usable are ineligible for
automatic credit; explain this and offer support rather than debiting the new period. Re-entering
the same Free bucket or restoring the same paid period preserves its already-used recovery credit.

After a credit, show “Your look didn't arrive. We returned 1 generation to your allowance.”
Let the user explicitly request a fresh look with a new operation ID; do not automatically incur
another provider call. If the recovery credit has already been used, show “This look was generated,
but delivery couldn't be confirmed. Your automatic delivery credit for this period has already
been used. Contact support for help.” Show current usage and the reset date; do not silently
present an uncharged failure. Disclose the one-credit limit and same-period eligibility in the
Plan & Usage details before purchase. An automatic allowance credit is not a monetary refund.

The server cannot prove a client's missing-delivery claim. The bounded policy therefore permits
at most one extra successfully generated response per bucket, including an abusive false claim:
**up to 31 Plus or 6 Free provider successes**, while net customer usage remains capped at 30/5.
The cap bounds this specific abuse; it does not establish delivery proof or bound ordinary failed
attempts. Existing rate/admission controls and the global spend/concurrency limits still apply.
Credits never refund provider charges/reservations, clear pending work or raise global limits.
The [cost model](freemium-model.md#price-and-allowance-comparison) includes full recovery-credit use.

Store only operation/owner/period identifiers, fixed adjustment reason, timestamp and counter
metadata. Do not add outfit persistence or delivery-content logs. Persistent encrypted outfits
would still be response persistence and are not authorized by this policy.

## Legacy compatibility, deletion and release

Additive development must leave build 7's `/recommend` behavior unchanged until the reviewed paid
cutover. That legacy route cannot stay as an unmetered bypass after quotas launch. Do not trust a
client version/header to select the free legacy path: App Attest does not enforce signed build
fields on all supported OS versions. Before paid activation, either route every remote entry point
through verified ownership/metering or close legacy remote generation with a compatible service-
unavailable response and clear upgrade/support notice. Choose the notice/cutover policy before
shipping. Local features and existing data remain available. Never enable paid mode while an
unmetered remote path remains reachable, including rollback configurations.

Deleting installation security data removes the installation binding, not Apple purchases or the
customer's durable allowance history. Otherwise re-enrollment would reset quota. Design and review
a separate commerce-data deletion/retention policy, including legal purchase records and replay
prevention, and update privacy disclosures before storing new customer metadata. The current
deletion screen must not imply that it deletes Apple billing records or cancels a subscription.
Restore after reinstall must verify ownership and recover authoritative usage without altering
local wardrobe data. Do not use physical uninstall/deletion as routine development QA.

## Implementation slices and acceptance

1. **Contracts and pure usage policy:** JSON Schemas, Swift/Pydantic mirrors and shared fixtures;
   exact UTC/Apple period allocation, nonnegative balances, cancellation/restore/revocation rules.
   Include gross successes versus net usage, ordinary failure release and the bounded delivery credit.
2. **Apple verification and commerce store:** official trust/ownership proof, lifecycle
   reconciliation, same-owner multi-device access, cross-owner denial, durable replay protection,
   privacy-reviewed provisioning/retention and recovery. Verify API/OS availability before coding
   against assumed signed fields. No real product creation or purchase is needed for fixture tests.
3. **Admission integration:** concurrent quota boundary tests, duplicate operation delivery, every
   crash boundary around the two stores, global rejection and failed/uncertain calls, period rollover,
   revocation during an admitted call and prevention of legacy-route bypass at paid activation.
   Test duplicate/cross-owner credit claims, concurrent credits from two devices, a second loss
   after the cap, crash before/after credit commit, replay after rollover, expired/revoked periods,
   restore/reinstall without resetting the credit, and unchanged provider liability after credit.
4. **iOS Plan & Usage and StoreKit:** localized price, verified purchase/restore/update flows,
   pending purchases, explicit service/quota states, durable local result recovery and offline views.
   Show upgrade only after availability/ownership prerequisites can be met on that device.
5. **Release validation:** full backend pytest/audit/Bandit/Ruff/mypy, iOS tests and release-script
   checks; targeted Apple sandbox/TestFlight lifecycle/device evidence. Verify the next unused build
   before changing version metadata. Review current Apple proceeds, capacity, privacy disclosures,
   legacy cutover and support policy before enabling paid distribution.

APP-037 implementation and release readiness remain incomplete. Source-bound Apple ownership/API
verification, retention and cutover decisions remain prerequisites for the remaining work.
The new Swift source requires a new TestFlight build before distribution under repository policy;
verify the next unused build number first. No version metadata, upload or deployment was changed.
