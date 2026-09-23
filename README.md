# Wardrobe Stylist

> **Public release — 23 September:** After the complete production preflight passed at
> `14:31:20Z`, the owner-authorized release of `1.0.0 (7)` was confirmed at approximately
> `14:33Z` (22:33 SGT). App Store Connect shows **Ready for Distribution**. Free,
> Singapore-only distribution is retained. The first anonymous storefront check had not yet
> resolved; public download availability is propagating, not yet independently confirmed.
> Fly v15 is healthy with the repaired dependency and intact storage/limits. See the
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

**This is planned, not implemented:** the current v1 has no subscription, purchase flow or
customer-level monthly quota. The earlier **5 Free / 60 Plus** allowances are draft options;
the actual numbers, reset rules, paid name and price are undecided. Per-customer allowances will
sit behind the owner's separate global AI spending limit; paying users do not automatically
raise that limit. See the [freemium model](docs/freemium-model.md) for inclusions, metering and
the decisions required before the paid release.

## Current release

Version **1.0.0 (7)** was manually released on **23 September at approximately 22:33 SGT**,
after Apple approval, explicit owner authorization and a complete passing production preflight.
App Store Connect shows **Ready for Distribution**; Singapore is **Processing**, with the other
174 territories unavailable. The first anonymous storefront checks had not yet resolved, so
public download availability remains unconfirmed until propagation completes.
The release is Free, with no in-app purchases or subscriptions and no Mac/Vision distribution.
[App Store destination](https://apps.apple.com/sg/app/id6789053566).

Fly **v15**, runtime source `cb81d7c0e35fd36917bde0a4ab78c8bd456c257b`, contains the AnyIO
security fix and repaired read-only diagnostic. Exact image scans have zero High/Critical
findings. Auth integrity/capacity, disk, enabled AI budget, snapshot policy, bounded logs,
public routes/pages and fresh console checks pass. Original resources, keys, private limits,
auth storage and aggregate budget liability were preserved. The old v11–v14 image is not an
eligible recovery target. No new iOS build or upload was needed; approved build 7 was released.

The current work order is to verify storefront propagation, continue the daily owner cost
review, and rotate the production provider key before its **8 October** expiry. Retain completed
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

## Documentation

| Doc | What |
|---|---|
| [`docs/release-plan.md`](docs/release-plan.md) | Current short path to TestFlight, AI activation and public release |
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

The September 23 remediation passed **879 backend tests** plus locked pip-audit, Bandit, Ruff
and mypy, **237 iOS tests** (227 Swift and 10 UI), and **44 release-script tests**.
The complete clean-main production preflight passed at **14:31:20 UTC** before the manual release.
The final release record changes documentation only; it requires no new TestFlight build.
Earlier regression counts and checkpoints remain in the dated runbook.

The current operations checker distinguishes an intentionally AI-disabled internal beta from
AI-launch readiness. The default AI-launch purpose remains strict; a beta-only result does not
authorize AI, App Store submission or an upload. No iOS bundle/API-contract change is part of
this refactor, so it does not itself require a new TestFlight build.

Provider-key rotation before the recorded 8 October expiry, truthful AI disclosures/consent,
the accepted snapshot/recovery residual risk and App Store metadata remain tracked in the
[release plan](docs/release-plan.md) and [TestFlight runbook](docs/app-store/internal-testflight-runbook.md).
Detailed historical model evaluations, releases and test counts remain in those linked records
and Git history; they are not additional tasks to repeat.
