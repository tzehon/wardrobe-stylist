# Apple commerce verification: evidence and open gates

Checked 3 October 2026. APP-037 now includes an inactive signed-evidence adapter,
not a working ownership verifier or authorization to enable commerce.

Apple's official Python library at commit
[`1da04603e77b7da5b6a160d4ef8410ba2d2b70d4`](https://github.com/apple/app-store-server-library-python/tree/1da04603e77b7da5b6a160d4ef8410ba2d2b70d4)
provides these confirmed boundaries:

- [`SignedDataVerifier`](https://github.com/apple/app-store-server-library-python/blob/1da04603e77b7da5b6a160d4ef8410ba2d2b70d4/appstoreserverlibrary/signed_data_verifier.py)
  verifies ES256 signed data against supplied trust roots and the configured app/environment.
  Its AppTransaction method checks bundle ID, production app Apple ID and receipt environment.
  Its transaction method checks bundle ID and environment. Product, subscription-group,
  ownership type, period and freshness policy still need application checks.
- The [`AppTransaction` model](https://github.com/apple/app-store-server-library-python/blob/1da04603e77b7da5b6a160d4ef8410ba2d2b70d4/appstoreserverlibrary/models/AppTransaction.py)
  represents `appTransactionId`, `deviceVerification` and `deviceVerificationNonce` as optional
  fields. Their presence in a Python model does not prove availability on every supported iOS
  version. The verifier does not compare device proof or bind it to an App Attest installation.
- The library explicitly skips signature verification for Xcode/local-testing environments.
  An eventual production adapter must prohibit those modes, use official Apple roots, require
  relevant fields, and distinguish cryptographic validity from current ownership/entitlement.
- Apple's [library README](https://github.com/apple/app-store-server-library-python/blob/1da04603e77b7da5b6a160d4ef8410ba2d2b70d4/README.md)
  documents trust-root acquisition and online verification. The adapter pins
  `app-store-server-library==3.1.2`; no production roots, signing keys, real product,
  receipt or customer record are installed.

## Implemented evidence-only boundary

[`AppleEvidenceVerifier`](../backend/app/commerce/apple_evidence.py) accepts trusted, explicit
app/product/environment/freshness policy and externally supplied trust roots. It rejects
Xcode/local-testing signature bypass modes and always enables the SDK's online chain/revocation
checks. The SDK caches verified certificate chains for up to 15 minutes; this is not a fresh
App Store entitlement-status query on every verification. Reviewed official Apple roots and
network availability are required before any real integration.

The adapter bounds JWS input, rejects duplicate keys/non-JSON constants, and checks authenticated
raw claim types rather than relying on the SDK's permissive model conversion. It requires matching
AppTransaction IDs, exact app/product/group/environment, purchased ownership, fresh signed dates
at verification completion, and consistent subscription dates. Offers, refunds/revocations,
upgrades and nonstandard billing fail closed pending the lifecycle reconciler. Device evidence is
returned only as signed opaque bytes/nonce; no device-proof computation or binding is claimed.

Returned records are volatile evidence, with identifiers excluded from their representations.
An expired purchase can remain valid historical evidence. Nothing returns a current entitlement,
owner key, allowance grant or API response. Only the separately guarded inactive request inspector
imports this module; no live path reaches it. Tests generate ephemeral
synthetic certificate chains and exercise actual ES256/chain verification, stubbing only OCSP;
these are not official Apple fixtures or live purchase/device proof.

## Official documentation verified on continuation — 3 October

The newly published cloud environment reports enforced restricted networking with Apple hosts
allowed. HTTPS reads of `apple.com` (redirecting to `www.apple.com`), `www.apple.com` and
`developer.apple.com` returned HTTP 200. The earlier proxy 403 is resolved; no further publication
of that same environment change is needed. The following official documentation was read directly through its Apple-hosted
DocC JSON:

- [isUpgraded](https://developer.apple.com/documentation/appstoreserverapi/isupgraded):
  “This value appears in the transaction only when it’s true.” The adapter now accepts omission
  or explicit Boolean false, while rejecting true and all malformed present values, including
  null, numeric zero and strings. Synthetic signed fixtures normally omit the claim; regression
  coverage also accepts explicit false and rejects malformed values.
- [Transaction payload](https://developer.apple.com/documentation/appstoreserverapi/jwstransactiondecodedpayload)
  marks `quantity` as optional, consistent with the pinned SDK's `Optional[int]`. The current
  [quantity documentation](https://developer.apple.com/documentation/appstoreserverapi/quantity)
  describes products or seats, including multiseat subscriptions; the older SDK description
  mentions only consumables. Omitted quantity is accepted for this subscription evidence, while
  any present value must be the integer one. Null, Boolean/numeric coercions, zero, negatives,
  collections and quantities above one remain rejected. Tests cover both omission and explicit one
  in combination with omitted/false `isUpgraded`.
- [receiptCreationDate](https://developer.apple.com/documentation/appstoreserverapi/receiptcreationdate):
  “The date that the App Store signs a JSON Web Signature (JWS) app transaction.” This confirms
  the pinned SDK model: AppTransaction freshness uses `receiptCreationDate`; purchase-transaction
  freshness uses `signedDate`. Do not require an unsupported AppTransaction `signedDate` field.
- [AppTransaction ID](https://developer.apple.com/documentation/storekit/apptransaction/apptransactionid):
  the identifier is stable for the same Apple Account and app across redownloads, refunds,
  repurchases and storefront changes, and exists without an in-app purchase. Apple documents
  iOS 16 availability with `@backDeployed(before: iOS 18.4, ...)`. This establishes documented
  API availability for the iOS 18 target, not tested JWS field presence across every supported OS.
- [Device verification](https://developer.apple.com/documentation/storekit/apptransaction/deviceverification)
  and [nonce](https://developer.apple.com/documentation/storekit/apptransaction/deviceverificationnonce)
  are documented from iOS 16. [AppStore.deviceVerificationID](https://developer.apple.com/documentation/storekit/appstore/deviceverificationid)
  specifies the comparison: append the lowercased device UUID string after the lowercased nonce
  UUID string, compute SHA-384, and compare the digest with `deviceVerification`. The device ID
  API is optional. This is Apple's current-device check, not by itself a server-authenticated
  link between that device, the JWS and an App Attest installation.

## Remaining integration gates

The [ownership evidence slice](apple-ownership-binding.md) implements local StoreKit collection,
the device-hash comparison and challenge-bound request inspection, including app-only evidence for
Free users. It deliberately returns no ownership verdict: a matching borrowed JWS/device UUID
signed by another installation is still not independent device-origin proof. Before `/commerce/bind`,
resolve that trust/cutover boundary and implement durable binding to the requesting installation,
including freshness, replay protection, account changes and missing-device-ID behavior. Never
substitute a client-supplied device ID, signed JWS possession alone, `appAccountToken`, or App Attest
installation identity for that proof. Keep the iOS 18 target and local features; unsupported
ownership verification must close remote commerce rather than invent a fallback.

Official roots are now fingerprint-pinned test fixtures; the public SDK mock is correctly rejected
by them and is not positive live-Apple evidence. Actual supported-OS JWS compatibility and
physical-device proof remain open. No production roots were installed. Additional live verification endpoints
must be derived from reviewed Apple material before activation, not guessed or blanket-allowed.

The new commerce store accepts trusted internal owner/grant inputs solely to test durable
accounting independently of this unresolved verifier. It has no public route or runtime caller.
Its `verified_until` value is a caller-provided boundary, not independently verified Apple evidence.
Privacy/retention approval, purchase notification deduplication, reconciliation (including grace
and shortened/overlapping periods), binding/deletion policy, and global-ledger coordination remain
separate prerequisites. Test fixtures are synthetic and local only.
