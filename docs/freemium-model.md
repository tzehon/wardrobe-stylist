# Free launch and future freemium model

> **23 September status:** Apple approved build 7; public release is owner-authorized after final
> verification. Fly v15 is deployed. See the [launch record](app-store/launch-check-20260923.md) for current evidence;
> earlier rejection, wait-for-reply and unapproved-release statements below are historical.

Status: **the approved public v1 is Free in Singapore, with no purchases or subscriptions.**
Freemium is the next product milestone after that launch, not a feature of the current build.
This document is the canonical product-model reference; the
[release plan](release-plan.md) sets the work order and
[APP-037 in the backlog](app-release-backlog.md#p2--feature-enhancements-after-the-public-release-foundation) tracks implementation.

## What exists now

The `1.0.0 (7)` candidate includes the local wardrobe, manual/photo entry, catalog browsing and
editing, wear history, local reminders and Demo Mode without payment or a Wardrobe account.
Optional AI styling is implemented and enabled as the owner-approved bounded Fly v15 pilot.
The 12 September v13 activation review passed with the scoped Cowork-only exception. The v14
configuration postcheck passed, followed by its full operations review at `2026-09-12T07:09:37Z`
with the approved Cowork-only status exception. The first protected
TestFlight styling result passed on 12 September. Styling requires in-app consent
and remains subject to the global safety limits. Local features work independently of AI.
Build 7 has completed [internal TestFlight distribution](app-store/internal-testflight-runbook.md#build-7-distribution--2026-09-10).
The [11 September checkpoint](app-store/internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial)
records the completed handoff, clean installation and scoped local-beta QA. Bounded activation
is complete; protected-device styling proof passed on 12 September; public release remains open. See the
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
All of this customer metering is **planned, not implemented**.

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
process. This documentation-only change does not require another TestFlight build.
