# Wardrobe Stylist

> **Public release — 23 September:** After the complete production preflight passed at
> `14:31:20Z`, the owner-authorized release of `1.0.0 (7)` was confirmed at approximately
> `14:33Z` (22:33 SGT). App Store Connect shows **Ready for Distribution**. Free,
> Singapore-only distribution is retained. By `14:44Z` (22:44 SGT), the anonymous public
> listing was live and Apple showed Singapore **Available**, with 174 territories unavailable.
> At the 23 September release checkpoint, Fly v15 was healthy with the repaired dependency and intact storage/limits. See the
> [launch evidence](docs/app-store/launch-check-20260923.md). Earlier rejection and hold records are historical.
> No new TestFlight build was needed; approved build 7 was released.

A **personal, privacy-first** iOS app for cataloging clothing manually or from photos, browsing a
local wardrobe, and optionally asking **Aria** for a non-repeating daily outfit. Public v1 does not
connect to Google, read Gmail, import receipts, or require an account.

The approved launch is **Free, Singapore only, version 1.0.0 / Build 7**, with no in-app
purchases or subscriptions. Transparent freemium in Singapore comes next; country expansion
follows only after its pricing, budget controls, and operations are proven.

## How freemium will work

The local wardrobe, photos, history, reminders and Demo Mode remain free. The planned paid
monthly subscription adds a larger fixed allowance of fresh AI outfit generations. The app
will show the current plan, remaining allowance, reset date, localized price and restore/manage
controls. Existing looks and local features do not consume a new AI generation.

**This is planned, not active:** the current v1 has no subscription, purchase flow or
customer-level monthly quota. The owner-selected validation candidate is **S$4.98/month for
30 Plus generations per subscription period, with 5 Free generations per UTC month**.
Actual-cost validation is deferred; pricing and paid launch are not approved. Per-customer allowances will
sit behind the owner's separate global AI spending limit; paying users do not automatically
raise that limit. See the [freemium model](docs/freemium-model.md) for inclusions, metering and
the decisions required before the paid release.

## Current release

Version **1.0.0 (7)** was manually released on **23 September at approximately 22:33 SGT**,
after Apple approval, explicit owner authorization and a complete passing production preflight.
App Store Connect shows **Ready for Distribution**; Singapore is **Available**, with the other
174 territories unavailable. By **22:44 SGT**, the anonymous public App Store listing was live
with the correct app name, developer, Free price and iPhone-only availability.
The release is Free, with no in-app purchases or subscriptions and no Mac/Vision distribution.
[App Store destination](https://apps.apple.com/sg/app/wardrobe-stylist/id6789053566).

Fly **v17**, runtime source `bd40450286d8703e4805cc554bf8e0100b6ba04a`, includes the zlib
security repair and accepts builds 4–8. Exact local/registry scans found zero High/Critical
issues, and independent runtime, auth/storage, budget, snapshot, logging and public-route checks
passed on 16 October. Original resources, secrets, private limits and accounting were preserved.
The v15/v16 image is now ineligible after a High zlib finding; v11–v14 remain ineligible after
Critical AnyIO findings. Build 8 is still unuploaded; the public release remains build 7.
See the [build-8 release evidence](docs/app-store/build8-release-20261016.md).


The owner confirmed successful App Store download and launch by **23:02 SGT**. The public
support link and existing operating routine were handed off in the same task. This is owner-
reported delivery proof; it does not claim another functional matrix or production AI call.
Retain completed QA and preserve existing data/identity. Continue the daily owner cost
review and rotate the replacement provider key before its **30 November 2026** expiry. The
[29 September rotation](docs/app-store/key-rotation-20260929.md) preserved the runtime and
accounting; the superseded key is disabled. Retain completed
physical QA without replaying it. The snapshot/deletion recovery evidence waiver remains accepted
residual risk, not proof of all-copy purge or deleted-identity non-return. The two legacy Google
project shutdowns were accepted on 19 September; final provider deletion remains pending.

See the [launch evidence](docs/app-store/launch-check-20260923.md),
[release plan](docs/release-plan.md), and [dated TestFlight/App Review history](docs/app-store/internal-testflight-runbook.md).
The earlier 19 September rejection and clarification correspondence are historical; no further
reply, appeal or resubmission is currently required.

## Automated QA

Routine catalog edits, Demo, Today/History relaunch, consent and reminder controls are covered by
the iOS test suite. Enabled, pressed and disabled consent-button contrast has automated coverage.
A disk-backed regression now checks that a photo, thumbnail and edited item name survive separate
store reopens. These are automation-owned checks, not another manual checklist for the owner.
Physical-device evidence remains separate for real App Attest, system permissions/notification
delivery and a changed visual presentation. Reuse unchanged physical evidence; see the
[QA ownership record](docs/app-store/internal-testflight-runbook.md#qa-automation-ownership--2026-09-11).

## Core safeguards

- Wardrobe data and photos stay on device; optional AI sends only disclosed compact text.
- The Anthropic key stays on the server. App Attest provides anonymous per-installation access.
- The backend stores minimum security metadata and separate aggregate budget metadata, never
  wardrobe, prompt or model-response payloads.
- The existing durable AI ledger, conservative reservations and disable switch bound the
  approved AI path. Keep their state across restarts and recovery.
- Public v1 contains no Google sign-in, Gmail access or receipt import.

## Repository layout

```
wardrobe-stylist/
├─ ios/         SwiftUI + SwiftData app (photos, local catalog, stylist UI)
├─ backend/     Python FastAPI proxy that holds the Anthropic key and calls Claude
├─ shared/      JSON Schemas shared by iOS + backend (the data contract)
├─ docs/        Setup + architecture docs (start here)
└─ .github/     CI workflows
```

## Quick start

See **[`docs/setup.md`](docs/setup.md)** for the full setup. Run each platform's commands from
the repository root:

```bash
# Backend
cd backend && uv sync --locked && uv run --locked pytest && uv run --locked pip-audit && uv run --locked bandit -r app container_entrypoint.py -q && uv run --locked ruff check . && uv run --locked mypy app
```

```bash
# iOS (generates Wardrobe.xcodeproj from project.yml, then runs tests)
cd ios && xcodegen generate
xcodebuild test -project Wardrobe.xcodeproj -scheme Wardrobe \
  -destination 'platform=iOS Simulator,name=iPhone 17'   # or any installed iPhone sim
```

## AI authorship in Git

Git AI records Codex edits in `refs/notes/ai`. The [Git AI workflow](.github/workflows/git-ai.yaml)
preserves those notes when same-repository pull requests are rebased or merged on GitHub.
It uses checksum-pinned Git AI 1.7.5 and the repository's temporary `GITHUB_TOKEN`, without
a Git AI account or telemetry key. Fork pull requests are outside this workflow's scope.
Local Git AI must capture edits and push their notes before merging. After a merge, wait for
the **Git AI** workflow, then run `git ai fetch-notes origin` to refresh local attribution.
Use `git ai stats` for the latest commit or `git ai blame <file>` for line attribution.
Existing history without recorded attribution remains untracked.

## Documentation

| Doc | What |
|---|---|
| [`docs/release-plan.md`](docs/release-plan.md) | Completed public release/delivery and current operating routine |
| [`docs/freemium-model.md`](docs/freemium-model.md) | Free launch, planned paid offering, usage/reset behavior and undecided prices/limits |
| [`docs/setup.md`](docs/setup.md) | End-to-end dev setup (Xcode, uv, App Attest, Anthropic key, Fly.io) |
| [`docs/architecture.md`](docs/architecture.md) | System architecture with diagrams (components, data flow, sequences) |
| [`docs/model-evaluation.md`](docs/model-evaluation.md) | Fictional model quality, latency, cost, and cache evaluation; paid-call approval procedure |
| [`docs/ai-spend-controls.md`](docs/ai-spend-controls.md) | Durable monthly AI ceiling, private provisioning, alerts, and disable/recovery procedure |
| [`docs/fly-spend-controls.md`](docs/fly-spend-controls.md) | Hosting limits, daily cost review, variable-charge risks and service-hold procedure |
| [`docs/google-setup.md`](docs/google-setup.md) | Historical/deferred read-only Gmail OAuth setup; not used by public v1 |
| [`docs/privacy.md`](docs/privacy.md) | Current local-first and App Attest privacy architecture |
| [`docs/app-release-backlog.md`](docs/app-release-backlog.md) | Work inventory and retained completion status; not a sequence to replay |
| [`docs/gcp-oauth-production-sequence.md`](docs/gcp-oauth-production-sequence.md) | Historical/deferred Google OAuth production sequence; not a v1 release gate |
| [`docs/app-store/`](docs/app-store/) | Draft privacy/support copy, data inventory, review notes, metadata, and screenshot narrative |
| [`AGENTS.md`](AGENTS.md) | Durable guidance for Codex and other coding agents in this repo |

## Verification and open work

The [29 September key rotation](docs/app-store/key-rotation-20260929.md) passed 879 backend
tests plus the locked security/type/lint gates, 237 iOS tests and 44 release-script tests.
At that rotation checkpoint, the replacement was verified on Fly v16 and the old key disabled.
Fly aggregate HTTP metrics returned no data then; the 16 October official API refresh now supplies
aggregate status evidence. Direct health/authentication and bounded-event checks passed separately.

The September 23 remediation passed **879 backend tests** plus locked pip-audit, Bandit, Ruff
and mypy, **237 iOS tests** (227 Swift and 10 UI), and **44 release-script tests**.
The complete clean-main production preflight passed at **14:31:20 UTC** before the manual release.
The final release record changes documentation only; it requires no new TestFlight build.
Earlier regression counts and checkpoints remain in the dated runbook.

The current operations checker distinguishes an intentionally AI-disabled internal beta from
AI-launch readiness. The default AI-launch purpose remains strict; a beta-only result does not
authorize AI, App Store submission or an upload. No iOS bundle/API-contract change is part of
this refactor, so it does not itself require a new TestFlight build.

The completed provider-key rotation and next expiry on 30 November 2026, truthful AI disclosures/consent,
the accepted snapshot/recovery residual risk and App Store metadata remain tracked in the
[release plan](docs/release-plan.md) and [TestFlight runbook](docs/app-store/internal-testflight-runbook.md).
The [1 October pricing proposal](docs/freemium-model.md#pricing-and-allowance-proposal--1-october-2026)
now assesses S$4.98/month for 30 paid generations and 5 Free generations per UTC month, following
the owner's request to validate profitability. Paid launch remains unapproved. The planning example
breaks even at 21 paid subscribers with 20 Free users, or 23 if everyone uses the proposed single
delivery credit; the stress case loses money per subscriber
after assumed support. Actual billing/success-count evidence and Apple account terms are unavailable
here, so profitability and capacity under the existing budget remain unverified.
The [commerce contract draft](docs/freemium-contract.md) specifies ownership, quota periods,
operation recovery and implementation slices. The owner selected bounded automatic delivery credits;
the initial design cap is one per allowance period. Legacy-route cutover remains open; no purchase
flow or live customer metering is enabled yet.
Detailed historical model evaluations, releases and test counts remain in those linked records
and Git history; they are not additional tasks to repeat.

### Freemium foundation — 1 October, inactive and cloud-verified

The first source slice adds a pure backend quota policy, a shared usage-snapshot schema/corpus,
Pydantic and Swift mirrors, and regression coverage. It implements 5/30 allowances, UTC Free
periods, supplied paid periods, idempotent outcomes, one delivery credit and late-settlement rules.
It does not verify Apple purchases, persist commerce records, expose commerce routes or activate
paid plans. Transactional concurrency, actual restore/renewal integration and cross-store recovery
remain future work; the pure policy's caller must provide verified ownership and period evidence.

Local verification passed **930 backend tests** (including 51 new policy/contract tests), locked
pip-audit, Bandit, Ruff and mypy. The existing development dependency `urllib3` was updated from
2.7.0 to 2.8.0 to clear three advisories found by the required audit; the new audit is clean.
The full backend suite needed socket access for its in-process test-client communication.

**Cloud validation passed** on source `9ad9b0b` in [PR #64](https://github.com/tzehon/wardrobe-stylist/pull/64):
[backend CI](https://github.com/tzehon/wardrobe-stylist/actions/runs/36841367340) passed all 930 tests,
locked checks and the unprivileged container check. [macOS CI](https://github.com/tzehon/wardrobe-stylist/actions/runs/36841367193)
passed **239 iOS tests** (229 Swift unit, including both shared-corpus tests, plus 10 UI), all
**44 release-script tests**, and the Release simulator build/artifact/privacy-manifest checks.
This closes the earlier Linux toolchain gap (39 script passes / five missing-Clang errors and no
Apple toolchain). It does not prove signed-device behavior or the future commerce integration.
The added Swift source requires a new TestFlight build before distribution; no build number,
upload, production runtime, credentials or spending limits were changed.

### Durable commerce storage — 3 October, inactive

The [commerce store](backend/app/commerce/store.py) adds atomic, metadata-only SQLite accounting,
opaque expiring operation handles, owner-wide revisions, one pending operation across periods,
durable dispatch fencing, sticky revocations and idempotent settlement/delivery credits. Restore
and restart retain balances and history. Explicit fixture provisioning, private file/schema
checks and allocation caps fail closed; no runtime imports the store or creates a commerce database.

[Apple ownership verification](docs/apple-commerce-verification.md) remains a prerequisite:
the official library verifies signed data but does not bind it to the submitting installation.
Apple's documented device computation and iOS API availability are now verified; supported-OS
JWS compatibility and authenticated installation binding still need implementation and evidence.
Retention/privacy approval, Apple lifecycle reconciliation, installation binding and global ledger
integration remain open. See the [contract](docs/freemium-contract.md) for scope and bounds.
Backend PRs now trigger the required macOS iOS regression as well as backend CI. This storage
slice adds no iOS bundle change; the earlier Swift foundation still needs TestFlight before release.
Local validation passed 968 backend tests (38 added), locked dependency audit, Bandit, Ruff and
mypy. The implementation PR records the separate cloud regression and review results.

### Signed commerce evidence — 3 October, inactive

The [evidence adapter](backend/app/commerce/apple_evidence.py) pins Apple's Python verification
library, requires online chain/revocation verification, and checks strict app, product, environment,
ownership-type, period and freshness claims. Synthetic certificates exercise actual signatures
and trust-chain rejection. No live route, production trust roots, owner binding or allowance grant
is installed. Signed evidence alone is not device ownership or current entitlement; those
[official Apple evidence and remaining gates](docs/apple-commerce-verification.md)
are explicit. No additional iOS build or production deployment is part of this backend slice.
Local validation passed 1,054 backend tests (86 added), locked dependency audit, Bandit,
Ruff and mypy. The implementation PR records cloud regression and review results.

### Ownership request evidence — 3 October, inactive

The [binding protocol and trust boundary](docs/apple-ownership-binding.md) now distinguish
StoreKit's local device comparison from App Attest's request integrity. An inactive Swift
collector reads verified StoreKit evidence locally; Python and Swift share an exact challenge-bound
transcript. The backend can inspect its App Attest signature, signed AppTransaction and device-hash
consistency without requiring an in-app purchase. Nothing consumes a challenge, updates a counter,
binds an owner or grants usage. A retained counterexample shows why a matching borrowed JWS/device
UUID signed by another key is not ownership proof. Durable binding and the collection/cutover
trust boundary remain open. Official Apple roots are test fixtures only; upstream mock evidence
is correctly rejected by them. No product flow calls these helpers.

This adds unshipped Swift source and requires a new TestFlight build **before distribution**.
No build number, upload, production deployment or paid activation is included. Physical StoreKit
compatibility and the eventual attested collection path remain separate evidence gates.

Local regression passed 1,093 backend tests, the locked dependency audit, Bandit, Ruff and mypy.
The implementation PR records macOS/iOS regression and review results.

### Ownership trust and cutover design — 14 October

The [next implementation design](docs/commerce-binding-cutover.md) audits the recorded build
4–7 signing sources and the earlier retained App Attest lineage. The legacy signers encode
fixed JSON and cannot emit the commerce transcript. The next slice is a dedicated operation
that collects StoreKit evidence and signs it internally, coordinated with session renewal and
deletion. This remains evidence-only: an instrumented app can sign borrowed evidence. Binding
stays disabled until an independent server-verifiable ownership mechanism is established.

The design also specifies durable counter/binding recovery across the separate stores and
closure of every legacy AI generation request at future freemium activation. Implementation,
privacy/retention review, physical compatibility and paid activation remain open. This design
checkpoint changes documentation only, adds no TestFlight requirement of its own, and claims
no new runtime test or device evidence.

### Inactive commerce collection and signing — 14 October

The App Attest actor now has a dedicated operation that collects its own StoreKit evidence and
signs the commerce transcript for an existing session and matching installation key. It
coordinates local signing with renewal/deletion, rejects stale or mismatched challenges, and
discards cancelled/retired results. Proofs remain volatile and redacted. Product callers and
commerce transport remain absent; ownership authorization, durable admission and physical
compatibility are still future work. See the [protocol update](docs/apple-ownership-binding.md#inactive-collect-and-sign-operation--14-october).

Backend regression passed 1,095 tests plus locked audit/Bandit/Ruff/mypy. Both macOS reruns
passed the full iOS suite, Release build/artifact checks and 44 release-script tests after the
initial runs failed different UI cases; final build-metadata regression is tracked on PR #69.

The owner's 14 October 22:22 SGT App Store Connect screenshot shows build 7 as the latest upload
under Build Uploads / All Statuses. Source now prepares `1.0.0 (8)` and adds build 8 to the backend
App Attest allowlist while retaining builds 4–7. At the PR #69 source checkpoint, live Fly v16 still used builds 4–7. The 16 October
deployment below closes that backend gate; signed distribution and physical compatibility remain open.

### Build-8 release preparation — 16 October

PR #70 repaired High-severity CVE-2026-85091 with Alpine `zlib>=1.3.2-r1`.
The exact merged image passed local and registry zero-High/Critical scans and runtime smoke
checks, then deployed as Fly v17 from `bd40450286d8703e4805cc554bf8e0100b6ba04a`.
Independent live verification passed at `02:16:48Z`, including builds 4–8, unchanged original
resources/secrets/budget accounting, auth integrity/capacity, snapshots, logs and public routes.
The old v15/v16 image is no longer eligible for recovery; use the verified v17 image subject to
fresh checks. See the [ordered build-8 evidence](docs/app-store/build8-release-20261016.md).

Build `1.0.1 (8)` now has a production-signed archive that passed strict artifact checks and
Apple validation. The earlier `1.0.0 (8)` archive was rejected because that version train is closed
and must never be uploaded. The operations lock binds the validated replacement; fresh clean-main
pre-upload review, upload/processing, Family assignment and candidate-specific physical evidence
remain. Commerce binding and paid features stay inactive.
This backend repair alone needs no iOS build; the prepared Swift changes and requested distribution
still require the owner-approved replacement `1.0.1 (8)`.
