# Commerce ownership: collection trust and cutover design

14 October 2026. Design for the next inactive implementation slice, based on repository
`2bb5968cd56654aab8399aa6c376a57b4b003d10`. GitHub's `main` matched that source at this
checkpoint. This is source analysis and an implementation specification, not a deployed
ownership verifier, new Apple guarantee, retention approval or paid-launch approval.

## Decision and security boundary

Implement a dedicated, inactive **collect-and-sign** evidence operation in the authentic app. It must obtain its own
verified `AppTransaction.shared` result and `AppStore.deviceVerificationID`, check the local
device digest, construct the existing commerce transcript and sign it with the installation's
registered App Attest key. Its production entry point accepts a validated server challenge;
it must not accept a JWS, device UUID, precomputed digest, transcript or collected-evidence
object from its caller. Test-source injection remains an in-process seam only.

This composition authenticates the bytes presented by an installation but does **not**
independently certify the StoreKit device UUID or commerce ownership to the server. An
instrumented authentic process can choose arbitrary bytes for its valid App Attest key even
when ordinary UI/network paths cannot. That attack is not solved by a private Swift method,
constructor-only injection or an allowlisted build. Keep
`test_signature_is_not_a_certificate_of_device_uuid_origin`: a borrowed matching JWS/UUID
pair signed by another synthetic key still passes the low-level inspector.

The implementation must therefore keep both the signer and `inspect_app_request` as evidence
helpers. **Binding must stay disabled:** no server policy flag or acceptance of an app-integrity
assumption may promote this composition alone into an ownership authorizer. Before implementing
an authorizing coordinator, establish an Apple-verifiable ownership/device proof or a separately
designed abuse-resistant ownership mechanism whose access cannot be transferred by copying the
JWS/device UUID pair. Specify its reinstall, restore, multi-device and account-change behavior
without resetting quota, and test denial of the existing borrowed-evidence attack. The current
API evidence has not established such a mechanism; do not invent one from `appAccountToken`,
receipt possession, build numbers or a client verified flag. Privacy and physical compatibility
review are additional prerequisites, not substitutes for this missing ownership authority.

## Historical signing-path audit

The archive/source mappings below come from the existing
[TestFlight runbook](app-store/internal-testflight-runbook.md). The uploaded build-4 replacement
source is used, rather than the earlier superseded archive. This review inspected Git source,
not the private signed archives again.

| Candidate | Recorded archive source | Assertion construction |
| --- | --- | --- |
| Build 4 | `24c17cb9fe643035f9206ee61e2935e086902146` | Fixed `AssertionClientData` JSON |
| Build 5 | `695c562b7b18e4a0b7f8a72b814af59efdd0cf3a` | Same |
| Build 6 | `de7c540275fb16e61aabf1884538b18cf6edf76f` | Same |
| Public build 7 | `0cc0fa7eadac998d32022e3e6a9dba2a62db64c4` | Same |
| Current source | `2bb5968cd56654aab8399aa6c376a57b4b003d10` | Same; commerce collector is not called |

In each of these trees, `AppAttestAuthorization.swift` contains the sole production call to
`service.generateAssertion`. Its private `makeAssertion` encodes the fixed fields `challenge`,
`challenge_id`, `key_id`, `purpose` and `version` using `JSONEncoder`; the only callers choose
the fixed session or deletion purpose. Server response strings remain JSON strings, including
escaped control characters. Even a hostile challenge response cannot turn that JSON object
into the ASCII transcript beginning `wardrobe-commerce-app-proof-v1\n`.

The exact `makeAssertion` source slice, from its declaration up to `makeAccessSession`, has
SHA-256 `b088155b39fb851d2442523e24d52b7ee7fdaa574543d82fd9999b94ae9e917c` in all five
trees. The lower-level `SystemAppAttestService` wrapper accepts a digest but has no separate
production caller that supplies externally chosen bytes. This is a call-path conclusion,
not a claim that Swift access control is a cryptographic boundary.

History searches for `generateAssertion`, `attestKey`, `DCAppAttestService` and `clientDataHash`
under `ios/Wardrobe` found the initial App Attest addition (`f869081`) and deletion refactor
(`ba3aa0a`) as the signing-call changes. The initial session signer already encoded fixed JSON;
the refactor added the fixed deletion purpose. Subsequent transport, Gmail-removal and deletion-
fence changes did not add a raw-input signer. This covers the retained source lineage before
build 4 as well; it is not a new inventory of every binary ever distributed from this App ID.

Enrollment hashes a decoded server challenge for `attestKey`, but returns an **attestation**,
not an assertion. `AppAttestVerifier.verify_assertion` requires exactly `signature` and
`authenticatorData`, verifies a positive increasing counter and the assertion signature over
the reconstructed commerce transcript. It must never accept an enrollment object as a substitute.

Consequently, the audited unmodified legacy paths are not commerce signing oracles under the
existing cryptographic assumptions. This closes only the ordinary legacy-path question, not
instrumentation or ownership authorization. A client-reported build number, new key enrollment date or forced
re-enrollment would add no proof of collection. Signed runtime fields, when present, must still
pass the existing strict allowlist; their absence on supported older OS versions must not be
reinterpreted as a verified new build. Review every future signing call site and any previously
unknown distributed source before any future integration; that audit alone cannot enable binding.

## Collect-and-sign implementation contract

1. Enter the same installation actor that coordinates session renewal and deletion. Capture a
   current credential/installation generation and refuse pending deletion. Serialize assertion
   generation; actor isolation alone is insufficient across `await` suspension points.
2. Validate challenge bounds, its registered key and installation, and its time window. Obtain
   StoreKit evidence through the system source, with the existing before/after device-ID check.
   No automatic `AppTransaction.refresh()` and no purchase side effect.
3. Construct the transcript internally from that newly collected evidence. Recheck the credential
   generation, deletion fence and challenge expiry after suspended work and before signing. Recheck
   again before returning/sending; discard a result retired during signing. Do not cache a proof
   for another challenge or accept a caller-supplied replacement payload after collection.
4. Keep raw evidence and proof bytes volatile and redacted. Do not expose them through debug logs,
   analytics, durable retry storage, URL handlers or a general-purpose signing endpoint. A lost
   response uses server status/idempotency and, if necessary, fresh local collection.
5. The server reconstructs the transcript from its own challenge/installation state and checks
   the App Attest assertion locally. Before any online Apple work, it atomically claims the
   purpose-bound challenge as described below; only that winner validates the exact JWS and
   digest online. It then rechecks policy, time, installation and binding revision at durable
   admission. Inspection alone never changes ownership or creates an allowance. The existing
   monolithic inspector must be split at this boundary before runtime integration.

## Durable binding and recovery contract

Use the existing auth database as the sole App Attest counter authority and the separate commerce
database for owner/binding metadata. Do not change the provider budget database. Introduce an
opaque admission ID shared across the two stores; auth stores only security disposition and
installation/challenge/counter information, never the commerce owner, JWS or device UUID.
New schema/provisioning and retention remain a later reviewed implementation. The sequence below
is a recovery specification for a **future independent ownership authority**, not permission to
derive an authorized owner from the current inspector. It cannot be connected to routes or
grants until the ownership requirement above is resolved and the complete protocol is reviewed.

Before the binding commits below, acquire a **durable verification claim** in auth storage after
local assertion validation. Atomically transition an issued challenge to `verifying`, recording
an opaque attempt ID and a lease deadline no later than challenge expiry. Recheck the installation,
counter snapshot, purpose, policy and binding revision; apply bounded issuance/attempt rate limits
per installation and globally. Only the transition winner starts online Apple verification, with
no database lock held. Duplicate submissions return scoped pending/terminal status and do no
online work. This excludes concurrent replays across processes, not just within one request actor.

Each challenge permits at most one online attempt. A failure, cancellation or expired lease
retires that challenge; it is never reset to issued and cannot acquire a replacement lease.
After a crash before durable admission, recovery marks an abandoned claim failed and requires a
fresh challenge/proof. An old worker may still finish its bounded network request, but its attempt
ID/deadline must match at every later commit or it cannot bind. This deliberate lost-attempt
recovery consumes no customer allowance, advances no counter by itself and stores no raw proof.

The proposed coordinator then follows this order:

1. Finish the claimed verification and the independent ownership authorization outside write
   locks against server snapshots. Signed AppTransaction identity alone cannot supply that
   authorization. With a consistent lock order of **auth
   first, commerce second**, revalidate those snapshots and prepare a bounded, inactive commerce
   intent containing only the server-derived owner pseudonym, expected binding revision, policy
   revision, verification deadline and opaque admission ID. Recheck the winning verification
   attempt and unexpired lease. Preparation grants no access.
2. Under the same lock order, require that exact unchanged intent and compare-and-swap the live
   auth counter and the still-valid verification claim. In one auth transaction, consume the
   purpose-bound challenge, advance the shared
   counter and persist its accepted admission ID. A session renewal/deletion that won the race
   causes this step to fail; never keep a second commerce counter.
3. Under the same lock order, require the durable auth acceptance, the still-live installation,
   current policy/revision and unexpired evidence; then finalize the commerce binding exactly
   once. A later ordinary session assertion may advance the counter without invalidating the
   recorded acceptance, but deletion or a changed binding generation must prevent finalization.
   No network call occurs while either database write lock is held.

These are separate durable commits, not a cross-database atomic transaction. All binding changes
and commerce admissions must use the coordinator; a commerce row by itself is never sufficient
authorization. Hold the auth lock through the commerce authorization/reservation commit so
deletion cannot race a check performed outside the transaction. Account changes and revocations
must fence the binding revision through the same protocol. Preserve admitted provider liability.

| Interruption point | Required recovery |
| --- | --- |
| Before prepared intent | Nothing accepted; a fresh request may start |
| Verification claim exists, no durable admission | No binding or quota; duplicates do no online work; crash/lease expiry retires the challenge and requires a fresh proof |
| Prepared intent, no auth acceptance | No binding or quota; bounded reconciliation abandons it or retries only while the original proof/state is still valid |
| Auth acceptance, binding not finalized | Recover the exact matching intent while all deadlines/revisions still pass; otherwise abandon and require a fresh proof with a higher counter |
| Binding finalized, response lost | Return the existing scoped outcome; no second binding, owner or allowance |
| Deletion/account change before finalization | Reject stale intent; never recreate a deleted installation or restore its old binding |
| One store missing, mismatched or restored alone | Stop commerce admissions; require recovery reconciliation, never initialize an empty ledger or infer acceptance from a prepared row |

Do not decrement counters or refund allowances to recover a failed bind. Binding itself allocates
no usage: reinstall and restore reconnect to the same server-derived owner and existing buckets.
Conflicting owner evidence cannot silently replace an active binding; require explicit detach,
fence pending admissions and reconcile outstanding work before binding a new owner. Missing auth
rows deny admission even if orphan commerce metadata remains. Current auth deletion removes its
row and challenges; the new coordinator must explicitly handle that absence and cleanup, rather
than assume a revocation tombstone already exists.

Recovery must validate the paired storage generation and pending admissions before enabling
commerce. Arbitrary rollback of both databases to an older mutually consistent snapshot can
still restore old counters/usage; this design does not solve that with an in-database flag.
Retain the existing recovery restrictions and require an independently reconciled recovery
checkpoint before resuming. Do not claim ordinary WAL durability proves snapshot rollback safety.

## Legacy AI route cutover

Keep the existing Free pilot during inactive development. At the future freemium activation,
choose a single server-controlled commerce mode: all generation uses verified ownership,
customer quota and the existing global budget, and **every** legacy `/recommend` request is
closed before provider dispatch. Do not exempt old installations, headers, versions or sessions.
Build 7 cannot supply the new proof, so silently metering its legacy requests is not an option.

Use a legacy-compatible **403** response for that route. At the recorded build-7 source,
`OutfitRecommender.message(for:)` already maps 403 to “Styling isn’t available in this build.
Please update the app and try again.” `RecommendClient.recommend` retries authorization only
for 401, so 403 also avoids a pointless session-renewal cycle. A 503 would show generic temporary
unavailability and hide the need to update. Use a machine-readable update-required code for the
new client without depending on build 7 parsing it. Publish the upgrade explanation in release
notes and the existing support page before cutover. Those external notices and the actual
cutover remain release work, not actions taken here.
Keep authentication and identity deletion available; local wardrobe, cached looks and Demo
remain available. Do not use repeated 401s to force re-enrollment.

Once commerce mode has admitted usage, rollback must pause remote generation or use a compatible
metered version. Re-enabling the unmetered route or restoring an older backend that ignores the
mode is not a valid rollback. Persist/verify the mode as part of the reviewed deployment and
recovery contract, with negative tests for old configuration and absent state.

## Next slice and acceptance evidence

Implement the inactive collect-and-sign operation and its actor coordination first. Add focused
tests for hostile challenge strings, legacy-JSON/commerce domain separation, exact locally
collected bytes, no external payload substitution, device change, deletion during collection
or signing, concurrent session renewal, expiry and redacted failures. Preserve the borrowed-
evidence counterexample and the production-route inactivity guards.

Next resolve the missing server-verifiable ownership authority, including the borrowed-evidence
attack. Keep coordinator implementation that could grant access blocked until that mechanism is
specified and reviewed. Its eventual tests must use real two-connection concurrency and process restarts
for every commit boundary above, cross-installation lookup denial, same-owner restore without
quota reset, explicit account change, retention cleanup and recovery mismatch. The schema must
make ownership/period grants unique and bound all pending metadata without deleting unresolved
liability. Race duplicate assertions before online verification and assert exactly one outbound
verification attempt; exercise crashes before/during/after that attempt and reject late workers
after lease expiry. Unit tests must not call the provider or create real StoreKit products.

Both code slices require the repository's full backend and iOS regression. Physical verification
remains limited to real StoreKit signed-field availability/freshness/device matching and the
eventual account-switch/reinstall/restore flow on supported OS versions. Synthetic signatures
and the source audit do not close those gates. Do not raise the iOS deployment target silently.

This checkpoint changes documentation only: source/path/hash consistency and Markdown links
were checked; no new runtime regression or device run is claimed. No additional TestFlight build
was required for these documents. The subsequent [16 October release](app-store/build8-release-20261016.md)
uploaded and processed `1.0.1 (8)`, satisfying the implemented inactive helpers/signer build
requirement. Build 8 is consumed; physical compatibility and promotion remain open. Future
implementation changes still require a new build with its unused number verified first.
