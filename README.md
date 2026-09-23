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

**Build `1.0.0 (7)` is processed and assigned to the `Family` internal TestFlight group.** The
initial AI-disabled tester notes were saved and reload-verified; they now describe the enabled
bounded pilot and have again been saved and reload-verified. The owner-controlled identity-safe
handoff, clean installation and scoped local-beta QA passed on 11 September. The current stage is
the owner-approved bounded AI pilot. The local wardrobe,
photos, history, reminders and Demo Mode are available without remote AI. The last verified
Fly v15 configuration has AI styling enabled within the existing approved global limits.
The historical v13 activation review passed on 12 September with the approved exception for an
unrelated Cowork-on-Windows incident; Claude API and Console were operational. The full v14
operations review completed at `2026-09-12T07:09:37Z` with the same approved Cowork-only exception.
The owner's first protected
TestFlight styling request displayed an outfit at 13:34 SGT. A read-only server check confirmed
one settled admission, no pending or uncertain reservations, and spend below warning. See the
[physical call checkpoint](docs/app-store/internal-testflight-runbook.md#first-protected-testflight-call--12-september-2026).
No new build or installation is required.

The [Singapore submission package](docs/app-store/submission-preparation-20260912.md) is approved
for source publication, saving the Apple draft and the bounded compatibility deployment. Apple
has saved the listing, Lifestyle category, age rating 9+, owner-confirmed content rights,
reviewer instructions, no-sign-in setting, manual release and existing build 7. Five fictional
screenshots are uploaded, ordered and reload-verified. Free pricing and disabled Mac/Vision
availability are saved and reload-verified. Agreements, bank/tax and DSA status are active;
Singapore is the sole available territory.
Current Fly v15 retains App Store App Attest category
`4` alongside TestFlight `2`, preserving the Machine, volume, keys, policy and intact ledger.
Its repaired image is recorded in the [23 September launch check](docs/app-store/launch-check-20260923.md).
Historically, the v14 independent configuration postcheck passed at `2026-09-12T06:36:24Z`; no paid call was
made. The full post-change review completed at `2026-09-12T07:09:37Z` with the approved
Cowork-only status exception; every other operational check passed, including the recovery scan.
See the [final review record](docs/app-store/internal-testflight-runbook.md#final-v14-operations-review--12-september-2026).
After separate owner approval, version **1.0.0 (7)** was submitted to Apple on 12 September at
15:32 SGT (07:32 UTC). On 13 September Apple marked it **Rejected / Unresolved Issues** under
Guideline 2.1, requesting additional information for an account with limited review history.
The request asked for a physical-device walkthrough video and written app details; it identified
no specific app defect. The owner-approved reply and redacted 89-second video were sent on
13 September, and the same build was resubmitted at **11:56 SGT (03:56 UTC)**. Apple showed
**Waiting for Review** at that checkpoint. On 16 September Apple returned it to
**Rejected / Unresolved Issues**, asking under Guideline 2.1(b) how paid features work. The
current build has none: optional AI is free to users and funded by the developer. A
[four-part business-model reply](docs/app-store/business-model-response-20260916.md) was sent
as reviewed, with owner approval, at **16:14 SGT**.
On **19 September at 07:18 SGT**, Apple issued a **Guideline 4.3(a) — Design — Spam** rejection,
alleging similarity to other developers' binaries, metadata and/or concepts. The desktop App
Store Connect app showed **Messages (5)** and **Rejected / Unresolved Issues**. The message
includes an extended-review warning but identifies no particular matching app, code element or
security defect. The owner-approved clarification was sent unchanged at **15:46 SGT** on
19 September; Apple shows **Messages (6)** with the sent reply. It asks which elements caused
the finding and describes the implemented workflow without unverified originality claims.
Await Apple's clarification; no appeal or resubmission was performed, and the status remains
**Rejected / Unresolved Issues**.
See the [19 September assessment and sent reply](docs/app-store/spam-rejection-20260919.md).
Do not resubmit unchanged or rebuild solely to change the binary. A clarification needs no new
TestFlight build; substantive iOS changes would require a new unused build number.
Manual release remains the selected release plan; the app is not Apple-approved or publicly released.
The owner-requested [Google Cloud retirement](docs/gcp-retirement-20260919.md) was performed on
19 September: both Wardrobe project shutdowns were accepted, with final provider deletion pending
after the recovery period. This legacy cleanup does not change the verified Gmail-free candidate.
Manual public release still requires separate owner approval after Apple's review.
The corrected reviewer notes have separate support/privacy links and were saved
and reload-verified. These changes need no new TestFlight build.

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
protected-device styling proof passed on 12 September.

Follow **[the release plan](docs/release-plan.md)** for the current work order:

1. Local-beta QA and the installation handoff are complete; retain that evidence without replaying it.
2. Privacy publication, consent assessment, bounded AI activation and the first protected
   TestFlight styling call are complete; continue the daily cost review.
3. Await Apple's answer to the [clarification sent on 19 September at 15:46 SGT](docs/app-store/spam-rejection-20260919.md)
   concerning the Guideline 4.3(a) similarity rejection.
   The earlier physical-device video and reviewer notes remain available to Apple.
   Clarification needs no new build; any product changes require a separate release assessment. Public
   release stays manual and requires separate owner approval.
   The snapshot/recovery evidence sub-gate remains owner-waived, not proven.

The [reviewer answers](docs/app-store/review-notes-1.0.0.txt) and
[short recording guide](docs/app-store/review-walkthrough-20260913.md) cover Apple's information
request. The inspected 89-second physical-device video, with unrelated photo-picker thumbnails
obscured, is attached to the sent response. The matching final 3,943-character App Review Notes
were saved and reload-verified on 13 September. The README and release records track the
resubmission; no new TestFlight build is required.

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
