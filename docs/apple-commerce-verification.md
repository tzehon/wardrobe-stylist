# Apple commerce verification: evidence and open gates

Checked 3 October 2026. This is a dependency assessment for APP-037, not a working
ownership verifier or authorization to enable commerce.

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
  documents trust-root acquisition and online verification. No dependency, roots, signing keys,
  real product, receipt or customer record were added in this slice.

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

The new commerce store accepts trusted internal owner/grant inputs solely to test durable
accounting independently of this unresolved verifier. It has no public route or runtime caller.
Its `verified_until` value is a caller-provided boundary, not independently verified Apple evidence.
Privacy/retention approval, purchase notification deduplication, reconciliation (including grace
and shortened/overlapping periods), binding/deletion policy, and global-ledger coordination remain
separate prerequisites. Test fixtures are synthetic and local only.
