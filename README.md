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

**Build `1.0.0 (7)` is processed and assigned to the `Family` internal TestFlight group.** The
initial AI-disabled tester notes were saved and reload-verified; they now describe the enabled
bounded pilot and have again been saved and reload-verified. The owner-controlled identity-safe
handoff, clean installation and scoped local-beta QA passed on 11 September. The current stage is
the owner-approved bounded AI pilot. The local wardrobe,
photos, history, reminders and Demo Mode are available without remote AI. The last verified
Fly v13 configuration has AI styling enabled within the existing approved global limits.
The enabled operational review passed on 12 September with the approved exception for an unrelated
Cowork-on-Windows incident; Claude API and Console were operational. The first protected styling
request from the owner's TestFlight app is pending. No new build or installation is required.

The 12 September disabled-pilot review verified the live runtime, exact approved budget settings,
intact idle ledger, fixed Machine size and recovery-image scan. The public-page checker now
normalizes HTML whitespace so a line-wrapped privacy paragraph does not falsely fail; missing
disclosures and forbidden capability wording still fail. The aggregate Anthropic status check
remains open for a Cowork-on-Windows incident, while the official API and Console components are
operational. The owner separately approved activation and this narrowly scoped exception. See the
[pre-enable checkpoint](docs/app-store/internal-testflight-runbook.md#ai-pilot-pre-enable-review--2026-09-12).

On 11 September the owner confirmed that TestFlight updated the existing installation to build 7.
A Dark Mode screenshot after withdrawing the saved styling permission shows the replacement
button with centered, title-only white text and a solid blue fill. The owner also confirms existing
wardrobe items and wear history remain visible, and that Offline Demo opens and its sample wardrobe
can be browsed with Airplane Mode on and Wi-Fi off. The normal-state visual, retained-data presence
and offline Demo smoke checks pass. Automated tests cover enabled/pressed/disabled contrast;
pressed/disabled device captures were not collected. See the
[physical checkpoint](docs/app-store/internal-testflight-runbook.md#build-7-physical-checkpoint--2026-09-11-partial).
The scoped live handoff precheck passed with one anonymous installation and a fresh automatic
snapshot. After owner-approved in-app server deletion, live installation/session/challenge counts
are zero and one bounded deletion-success marker was observed. The owner subsequently confirmed
the **Local Data Deleted** result, app removal and a clean TestFlight installation of `1.0.0 (7)`.
First launch with AI permission off shows an empty Wardrobe and History; a fresh server check
remains at zero installations, sessions and challenges. The handoff is complete. AI was still disabled at that checkpoint.

The owner waived the remaining snapshot-list-expiry and deletion-specific recovery/non-return
evidence sub-gate for the Free Singapore v1 on 11 September. The earlier monitored 25/28 August
snapshots were no longer customer-visible; the 10 September Build-7 pre-deletion snapshot remained
listed. This is an accepted-risk exception, not proof of that snapshot's later listing disappearance,
all-copy purge, or deleted-identity non-return through recovery. Fly's replica, backup and all-copy
purge timing remains undisclosed. Pre-deletion snapshots remain ineligible for service recovery;
emergency recovery uses fresh auth state and re-enrollment
while preserving the separate budget ledger. The waiver did not change Fly, the app, production or
local data, the installed build, or TestFlight state.

The [12 September AI privacy review](docs/app-store/ai-pilot-privacy-review-20260912.md)
records the approved [published policy](https://blog.tth.dev/wardrobe/privacy/) and reload-verified
Apple privacy answers. The existing build-7 consent covers the unchanged styling flow; this work
needs no new TestFlight build. The disabled checks and separately approved activation are complete;
protected-device styling proof remains open.

Follow **[the release plan](docs/release-plan.md)** for the current work order:

1. Local-beta QA and the installation handoff are complete; retain that evidence without replaying it.
2. Privacy publication, consent assessment and bounded AI activation are complete; verify one
   protected styling request from the existing TestFlight app, then continue the daily cost review.
3. Finish the remaining privacy and store-submission work for the Free Singapore launch; the
   snapshot/recovery evidence sub-gate is owner-waived, not proven.

The preserved signed build-7 archive passed strict verification on 10 September. The combined
operations review passed `PASS_INTERNAL_BETA_ONLY` at `2026-09-10T11:25:45Z`: AI remained disabled,
the intact budget was below warning and idle, and every other check passed. The same-session
App Store Connect view showed build 6 as the highest upload and no build 7. The owner then
approved the exact package; Xcode validation passed and Content Delivery recorded upload success
at `2026-09-10T11:47:49.338Z`, observed in Xcode at `11:48:11Z`. Apple processing and `Family`
assignment were verified at `11:50:45Z`,
and the approved notes persisted after reload at `11:51:22Z`. The existing group's **Automatic
for Xcode Builds** setting delivered the build without a manual assignment change; it was not
turned off. Clean installation and scoped local-beta QA have since passed. Build 7 is used and
must not be reused.
Build 6 is already used and non-promotable after the consent-button visual defect; the fix is
implemented in build 7. Preserve the owner-controlled identity-safe handoff before replacing an
installed build.

The 10 September reset defers the unshipped hourly monitoring system. Its prototype is preserved
privately, and the active path uses the existing fixed Fly resources, provider budget controls
and owner-run daily cost review. Full edge-counter coverage is not a beta distribution gate.
Fly still has variable charges; see [hosting controls](docs/fly-spend-controls.md).

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

The 11 September automation correction passed **237 iOS tests** (227 Swift and 10 UI), including
the new photo/edit/disk-reopen regression, **840 backend tests** plus the locked dependency audit,
Bandit, Ruff and application mypy, and **44 release-script tests**. These results were obtained
locally; CI runs provide separate verification. No shipped iOS/backend behavior changed and no new
TestFlight build is required. The completed local-beta QA does not authorize AI or public release.

The 10 September reset passed **840 backend tests**, locked dependency audit, Bandit, Ruff and
application mypy, plus **236 iOS tests** (226 Swift and 10 UI) and **44 release-script tests**.
Independent review found no actionable defect in the scoped beta check. The archived monitor's
tests remain historical evidence, not production features.
[PR #46](https://github.com/tzehon/wardrobe-stylist/pull/46) merged on 10 September after the
monitoring-instruction correction, a clear current-head Codex review and both CI checks passed.
The scoped review and approved build-7 upload are recorded in the
[runbook](docs/app-store/internal-testflight-runbook.md#build-7-distribution--2026-09-10), with
truthful AI-disabled tester notes at that checkpoint. AI activation subsequently completed on
12 September as Fly v13; no paid call had been made at the enabled-review checkpoint. The next
daily owner cost review is due 13 September, or sooner after a problem or configuration change.

The current operations checker distinguishes an intentionally AI-disabled internal beta from
AI-launch readiness. The default AI-launch purpose remains strict; a beta-only result does not
authorize AI, App Store submission or an upload. No iOS bundle/API-contract change is part of
this refactor, so it does not itself require a new TestFlight build.

Provider-key rotation before the recorded 8 October expiry, truthful AI disclosures/consent,
the accepted snapshot/recovery residual risk and App Store metadata remain tracked in the
[release plan](docs/release-plan.md) and [TestFlight runbook](docs/app-store/internal-testflight-runbook.md).
Detailed historical model evaluations, releases and test counts remain in those linked records
and Git history; they are not additional tasks to repeat.
