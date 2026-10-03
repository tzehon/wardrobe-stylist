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
owner key, allowance grant or API response. No runtime imports this module. Tests generate ephemeral
synthetic certificate chains and exercise actual ES256/chain verification, stubbing only OCSP;
these are not official Apple fixtures or live purchase/device proof.

## Remaining gates and environment access

Requests to Apple's official StoreKit documentation host returned HTTP 403 in this cloud
environment. The precise iOS availability and documented device-proof computation/binding
therefore remain unverified. Before implementing `/commerce/bind`, read the official
[AppTransaction ID](https://developer.apple.com/documentation/storekit/apptransaction/apptransactionid),
[device verification](https://developer.apple.com/documentation/storekit/apptransaction/deviceverification)
and nonce documentation from an authorized environment. Establish what evidence binds the
App Store owner to the requesting installation, including freshness, replay and account changes.
Never substitute a client-supplied device ID, signed JWS possession alone, `appAccountToken`, or
App Attest installation identity for that proof. Keep the iOS 18 target and local features;
unsupported ownership verification must close remote commerce rather than invent a fallback.

The cloud session exposes runtime status but no configuration-editing tool. The owner can keep
restricted networking and the existing package-manager preset, add `developer.apple.com` for
documentation and `www.apple.com` for certificate downloads, then publish the environment change.
No credential is needed for those public reads. Confirm the new policy is enforced before retrying;
do not edit the local policy snapshot or bypass the proxy. Additional live verification endpoints
must be derived from reviewed Apple material before activation, not guessed or blanket-allowed.

The new commerce store accepts trusted internal owner/grant inputs solely to test durable
accounting independently of this unresolved verifier. It has no public route or runtime caller.
Its `verified_until` value is a caller-provided boundary, not independently verified Apple evidence.
Privacy/retention approval, purchase notification deduplication, reconciliation (including grace
and shortened/overlapping periods), binding/deletion policy, and global-ledger coordination remain
separate prerequisites. Test fixtures are synthetic and local only.
