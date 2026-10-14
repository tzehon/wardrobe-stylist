# Apple ownership binding: protocol and inactive evidence collection

3 October 2026 foundation; 14 October inactive signing update below. The initial slice implemented
local evidence collection and request inspection only.
It does **not** establish a commerce owner, consume a challenge, update an assertion counter,
create a binding, grant usage, expose a route, or change production behavior.

**14 October design follow-up:** the [collection trust and cutover design](commerce-binding-cutover.md)
audits the retained legacy signing paths, specifies the dedicated collect-and-sign operation,
and defines provisional durable admission/recovery and legacy-route closure. It authorizes only
inactive evidence preparation: an instrumented app can still sign borrowed evidence. Binding
remains blocked pending an independent server-verifiable ownership mechanism; no policy flag
may promote this composition alone into ownership authorization.

## Inactive collect-and-sign operation — 14 October

`AppAttestAuthorization.collectCommerceProof(challenge:)` now collects evidence itself and signs
the resulting transcript. It accepts only a typed server challenge, requires an existing live
session for that installation and a matching registered key, and does not enroll or renew a
session as a side effect. Its constructor's collector injection is an in-process test seam;
the production default calls the system StoreKit collector. No product flow invokes the method.

The actor excludes concurrent commerce proofs, delays session renewal while local signing is
in progress, and lets deletion cancel/drain that work before producing a deletion assertion.
It checks expiry, clock regression, the identity generation and deletion fences after suspended
work and again before returning. Cancellation discards the result; upstream StoreKit/signing
errors become fixed errors. Returned evidence is volatile and redacted, with bounded assertion
size; there is no commerce network request, persistence, challenge consumption or server grant.

This serializes **local** signing only. Once the proof is returned, a later session assertion
can advance the server counter before a future commerce submission. The eventual transport and
coordinator must handle that conflict with server compare-and-swap and fresh collection; this
slice does not claim an end-to-end admission lock or durable replay protection. Dependency
cancellation is cooperative: deletion drains a started signing operation instead of assuming
that cancelling a task proves DeviceCheck has stopped. Physical compatibility remains unproved.

Tests cover local transcript inputs, legacy JSON escaping, challenge/key/installation mismatches,
expiry and clock rollback during collection/signing, concurrent renewal/proofs, deletion at both
boundaries, cancellation, error redaction and assertion size. Structural guards prohibit product
callers while retaining the backend borrowed-evidence counterexample. New TestFlight distribution
uses the next unused build 8, selected from the owner-provided 14 October App Store Connect
Build Uploads screenshot showing build 7 latest. The source allowlist includes 8; production
configuration deployment and physical-device proof remain open. This source slice performs no
upload or production activation.

## What the evidence actually proves

Apple's [AppTransaction JWS documentation](https://developer.apple.com/documentation/storekit/verificationresult/jwsrepresentation-6ma59)
explicitly places the `deviceVerification`/nonce comparison **on the device**. Its
[deviceVerificationID algorithm](https://developer.apple.com/documentation/storekit/appstore/deviceverificationid)
is SHA-384 of the lowercased nonce UUID string followed by the lowercased device UUID string.
The signed JWS authenticates the digest and nonce, not the origin of a UUID supplied to a server.

[App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
certifies an installation key and signs a hash of client data containing a server challenge.
The [server validation procedure](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
checks that signature, app identity, counter and challenge. It does not expose a StoreKit device
UUID or certify arbitrary client-data fields as Apple observations.

Consequently, a stolen JWS **and** its matching device UUID can pass a server-side hash comparison.
A second key signing that same pair proves who signed the request, not that its Apple Account
owns the app transaction. The regression suite retains this counterexample. Neither receipt
possession, a client `verified` flag, `appAccountToken`, nor an installation ID closes that gap.

The candidate composition relies on an authentic app collecting only its own StoreKit result
and device UUID, then asserting those exact bytes. Its security depends on that collection path
and the App Attest integrity assumptions; it is not an independent same-device certificate.
The current shipping build has no such collection/signing path. On iOS 18–26 App Attest's signed
build/category fields may be absent, so a server cannot simply require the new build number to
prove this path ran. An old/general-purpose signing path must not become an assertion oracle.
The [follow-up source audit](commerce-binding-cutover.md#historical-signing-path-audit) finds that
the retained legacy paths sign fixed JSON and cannot emit the commerce transcript. The next
implementation must preserve that separation and collect its own evidence inside the signer.
There is still no ownership authorization implementation. The historical audit does not stop
an instrumented app from signing borrowed evidence; an independent ownership authority remains
a prerequisite for implementing an authorizing coordinator.
Physical evidence is necessary for compatibility but cannot prove away this cryptographic limit.

## Implemented, inactive components

- `AppleEvidenceVerifier.verify_app` verifies a fresh signed AppTransaction without requiring
  a purchase. This supports eventual Free ownership without inventing an installation allowance.
  It retains the same signature/chain/online-check, app/environment, raw-type and freshness checks.
- `CommerceOwnershipCollector` obtains `.verified` `AppTransaction.shared` and reads
  `AppStore.deviceVerificationID` locally before and after collection. Missing/changed IDs,
  unverified results, unsupported environments and mismatching device hashes fail closed.
  Its injectable source is an in-process test seam; no file, URL or server payload feeds it.
  It never buys, stores or transmits anything. The inactive actor operation above signs its result;
  no product flow calls that operation.
- Swift and Python produce an identical, domain-separated transcript. The shared golden vector
  is synthetic. It proves byte agreement, not an Apple signature or device relationship.
- `inspect_app_request` accepts trusted server challenge/installation snapshots, verifies the
  App Attest signature first, verifies the exact AppTransaction JWS, compares its device digest,
  and rechecks challenge expiry/clock regression after online verification. It returns volatile
  **inspected evidence**, never an owner or entitlement. Inspector errors and the inspected/collected
  result representations exclude evidence. Passing the same unchanged state twice can pass inspection twice; it is not a durable
  replay gate. A monotonic counter from the server rejects replay only once the caller commits it.
- Structural guards prevent runtime code from importing the inspector or product flows from
  calling the inactive iOS signing entry point. The auth database, commerce database and live
  routes are unchanged.

## Proposed request protocol

The request transcript is ASCII with these lines, in this order, ending in one LF:

1. Literal `wardrobe-commerce-app-proof-v1`.
2. Server challenge UUID, lowercase canonical form.
3. Server random 32-byte nonce, lowercase hexadecimal.
4. Server-authorized installation UUID, lowercase canonical form.
5. Registered App Attest key identifier's 32 decoded bytes, lowercase hexadecimal.
6. Server binding revision, unsigned decimal integer, maximum 2^53 − 1.
7. Server challenge issuance time, Unix milliseconds, unsigned decimal.
8. Server challenge expiry time, Unix milliseconds, unsigned decimal.
9. SHA-256 of the exact ASCII AppTransaction compact JWS, lowercase hexadecimal.
10. Locally collected StoreKit device UUID, lowercase canonical form.

UUIDs must be canonical hyphenated UUIDs and nonzero. The draft challenge lifetime is positive
and at most five minutes; this is an inactive protocol bound, not an approved production rate
or freshness policy. JWS is bounded to 32 KiB and assertion CBOR to 8 KiB. The client passes
SHA-256 of these transcript bytes to `generateAssertion`; the server verifies those same bytes
using its registered key. AppTransaction `receiptCreationDate` is the signed JSON timestamp;
StoreKit exposes its date as `AppTransaction.signedDate`. These names must not be conflated.

The challenge, identity, key, revision, issuance/expiry and previous counter come from server
state, never from a proof body's claim to those values. A session identifies an installation;
it does not authorize an arbitrary signing key or commerce owner. The server reconstructs the
transcript from stored state plus the received JWS and device UUID. No client-supplied transcript,
purpose, verification verdict or owner key is accepted as authoritative.

`AppTransaction.shared` may require connectivity and StoreKit keeps it updated. Apple's
[refresh documentation](https://developer.apple.com/documentation/storekit/apptransaction/refresh())
says `refresh()` prompts for App Store credentials and must follow an explicit user action.
Do not call it automatically on expiry, launch, tab appearance or retry. Cached/stale evidence
must fail closed with a future explicit recovery flow. No refresh call is installed in this slice.

## Durable binding and lifecycle requirements (not implemented)

Before adding `/commerce/bind`, the service must implement and validate the
[collection/coordinator design](commerce-binding-cutover.md), including these requirements:

- Serialize proof admission with existing session/deletion assertions against the **same**
  installation counter. Atomically claim a purpose-bound, expiring challenge; confirm the active
  installation, expected binding revision and policy again at commit; consume each counter once.
  Online verification must run outside the database write lock, with compare-and-swap on return.
- Define recovery across auth/commerce storage. A crash between counter acceptance and binding
  commit must leave a durable recoverable intent, never a half-binding or another allowance.
  An uncertain/replayed request cannot silently reassign an owner. Do not create an independent
  counter in the commerce database or pretend two SQLite transactions are one atomic commit.
- Derive the owner pseudonym on the server from verified app transaction identity, namespace and
  environment. Store minimal binding metadata only after retention/privacy approval. Raw device
  UUIDs, JWS, transcripts, signatures and receipts from this flow must not enter logs or storage.
  The proposed device UUID transmission is a new data flow needing privacy review before activation.
- Reinstall/restore: a new attested installation independently proves access and reconnects to
  the existing commerce owner/usage. No fresh allowance follows from a new installation key.
- Account change: suspend old commerce admissions, settle or reconcile outstanding work, then
  explicitly detach the old binding and independently verify the new owner at a higher revision.
  A stale in-flight proof must not restore the old binding. Owner replacement is not implicit.
- Deletion/revocation: serialize with in-flight proofs, invalidate binding/challenges and revoke
  admissions, while preserving required usage/liability records. Local features remain available.
- Unavailable or unsupported proof, lost state, conflicting evidence, clock regression and unknown
  policy fail closed. There is no fallback to installation-only ownership or an unsigned flag.

## Evidence and remaining gates

The official Apple Inc., G2 and G3 roots were read over HTTPS from Apple's PKI links and are kept
as **test fixtures only**, with pinned fingerprints and self-signature checks. See the
[fixture provenance](../backend/tests/fixtures/apple_commerce/README.md). The pinned SDK's mock
transaction uses a test CA and is correctly rejected under those roots. Its model AppTransaction
fixture is LocalTesting with placeholder device data; neither is a valid production device proof.
No positive official/live signed AppTransaction fixture was established from these public samples.
Production roots and online revocation endpoints remain unconfigured.

Required next evidence is narrowly scoped: compile/simulator tests for these helpers; then actual
StoreKit JWS field presence, device matching and freshness on the supported iOS boundary, plus
account switch and reinstall/restore behavior of the eventual attested collection flow. A simulator
or synthetic certificate cannot establish those physical boundaries. Preserve the existing v1
physical QA; do not repeat unrelated catalog, photo, notification or deletion tests.

This adds unshipped Swift source, so a **new TestFlight build is required before distribution**.
Build 7 remains consumed. The owner-provided 14 October App Store Connect Build Uploads
screenshot confirmed it as the latest upload, so this slice selects `1.0.0 (8)` in source and
adds build 8 to the source App Attest allowlist. Backend deployment and verification, signing,
upload and physical-device validation remain separate distribution work. Production remains
Free and Singapore-only; paid activation is separate.
