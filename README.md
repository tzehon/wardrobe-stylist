# Wardrobe Stylist

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

The next milestone is **a usable internal TestFlight build**, using the existing `1.0.0 (7)`
candidate after fresh archive, operations and App Store Connect checks. The local wardrobe,
photos, history, reminders and Demo Mode are available without remote AI. The last verified
Fly v12 configuration has AI styling disabled; the app shows temporary unavailability for
remote styling requests.

Follow **[the release plan](docs/release-plan.md)** for the current work order:

1. Distribute and physically verify the existing beta candidate.
2. Complete privacy/consent and existing budget checks, then separately approve AI activation.
3. Finish the applicable privacy/recovery and store-submission work for the Free Singapore launch.

The signed build-7 archive was verified on 29 August; upload and candidate-specific physical QA
remain open. Build 6 is already used and non-promotable after the consent-button visual defect;
the fix is implemented in build 7. Recheck live build availability before any upload.

The 10 September reset defers the unshipped hourly monitoring system. Its prototype is preserved
privately, and the active path uses the existing fixed Fly resources, provider budget controls
and owner-run daily cost review. Full edge-counter coverage is not a beta distribution gate.
Fly still has variable charges; see [hosting controls](docs/fly-spend-controls.md).

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

The 10 September reset passed **840 backend tests**, locked dependency audit, Bandit, Ruff and
application mypy, plus **236 iOS tests** (226 Swift and 10 UI) and **44 release-script tests**.
Independent review found no actionable defect in the scoped beta check. The archived monitor's
tests remain historical evidence, not production features.
Source publication and the correction of older monitoring instructions are tracked in
[PR #46](https://github.com/tzehon/wardrobe-stylist/pull/46).

The current operations checker distinguishes an intentionally AI-disabled internal beta from
AI-launch readiness. The default AI-launch purpose remains strict; a beta-only result does not
authorize AI, App Store submission or an upload. No iOS bundle/API-contract change is part of
this refactor, so it does not itself require a new TestFlight build.

Provider-key rotation before the recorded 8 October expiry, truthful AI disclosures/consent,
snapshot-expiry/deletion-recovery proof and App Store metadata remain tracked in the
[release plan](docs/release-plan.md) and [TestFlight runbook](docs/app-store/internal-testflight-runbook.md).
Detailed historical model evaluations, releases and test counts remain in those linked records
and Git history; they are not additional tasks to repeat.
