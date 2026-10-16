# Build 8 release preparation — 16 October 2026

The owner requested continuation after PR #69 through backend verification and internal
TestFlight distribution, keeping commerce binding and paid features disabled. Public
`1.0.0 (7)` remains the Free Singapore release. This checkpoint does not submit a new public version.

## Backend deployment and recovery

PR #70 rebase-merged the minimum zlib repair to
`bd40450286d8703e4805cc554bf8e0100b6ba04a`. Fresh scans had found High-severity
CVE-2026-85091 in `zlib 1.3.2-r0` in both the v16 recovery image and the PR #69 candidate.
The Dockerfile now requires `zlib>=1.3.2-r1`, with a regression guard.

The exact merged Linux/AMD64 image passed local and immutable-registry scans with zero
High/Critical findings. Non-root, no-new-privileges, bounded logging, SQLite, separate mounted
storage and restart/uncertain-reservation smoke checks passed using isolated synthetic data.
Docker published an OCI index with an AMD64 image and provenance entry; the initial verifier
stopped on that shape. Read-only reconciliation verified the exact AMD64 child, matching source,
configuration and layers before scanning and deploying it. No duplicate publication was needed.

Fly v17 completed the in-place deployment. The immediate Machine snapshot still showed
`replacing`; the settled exact-image runtime was independently verified at `02:16:02Z`.
Production accepts builds `4,5,6,7,8` in categories `2,4`. The original Machine and encrypted
volume, all secret digests, approved limits and existing budget accounting were preserved.
No ledger initialization, reset, refund, provider-key change or resource expansion occurred.

Independent post-change verification passed at `02:16:48Z`: exact healthy runtime, App-Attest-only
configuration, auth-store integrity and approved public-capacity bounds, disk below policy,
fresh automatic 14-day snapshot, bounded events, ready enabled budget below warning with no
active/uncertain reservations, exact public routes and anonymous support/privacy/Terms pages.
Commerce routes are absent; no production commerce storage or paid feature was activated.
No paid AI call was made.

The v17 immutable image is the current recovery candidate, subject to fresh identity, security
and ledger-compatibility checks. The v15/v16 image is now ineligible because of the zlib finding;
its earlier clean scans remain historical evidence only.

## Fresh console evidence

The signed-in Claude production workspace retained the approved monthly limit and notification
thresholds, below-warning spend, sufficient credits and auto-reload off. The replacement key
expires on 30 November; the superseded key is now shown as expired. The pinned Sonnet 5 quotas
are present with zero reported peak utilization over the displayed 24 hours. No provider setting
was changed. Notification delivery remains unproven and is not relied on.

Fly's dashboard displayed no HTTP data; that was not counted as zero errors. The documented,
authenticated Fly Prometheus API returned two-day edge and application aggregates with `200`
and `404` responses and no reported `5xx`, including the post-deployment refresh. The separate
bounded-log review also passed. No monitoring job was introduced.

Fresh signed-in App Store Connect **Build Uploads / All Statuses**, sorted newest first, showed
`1.0.0 (7)` Complete as the latest upload and no build 8. Build 8 remains unused at this checkpoint.
Exact provider identifiers, costs, image digests and raw operational output remain private.

## Validation and remaining distribution gates

The security repair passed 1,095 backend tests and locked audit/Bandit/Ruff/mypy, 247 Swift unit
and 10 UI tests, 44 release-script tests, and the Release simulator/artifact checks. PR #70's
current-head Codex review had no findings and both CI suites passed before rebase merge.
The first local iOS 26.5 run stalled before executing tests and was interrupted; the complete
sequential iOS 26.4 rerun passed. The interrupted attempt is not passing evidence.

The operations lock now records observed v17/source/build allowlists. Its archive identity still
references preserved build 7 for the pre-archive operational baseline. Build 8 still needs a fresh
full clean-main pre-archive review, a distinct production-signed archive and exact artifact checks,
Apple validation/upload, processing, internal Family assignment and truthful tester notes.
Physical App Attest and candidate compatibility evidence remain separate from upload completion.
Do not repeat unchanged catalog or deletion QA merely because this is a new build.

Release impact: the backend repair and operations evidence alone need no new iOS build; the
already-prepared Swift candidate and explicit distribution request require `1.0.0 (8)`.

## Signed archive and Apple version rejection — 03:05Z

PR #71 rebase-merged the verified operations lock and deployment evidence to clean main
`a5e5cd4b087abc71f343bfe763c623c318e11f09`. Its full local regression passed 1,095 backend tests,
locked audit/Bandit/Ruff/mypy, 247 Swift unit tests, 10 UI tests and 44 release-script tests.
The first final-head CI attempt timed out in the unchanged system Photos-picker UI test;
the other 256 tests passed. Three focused local iOS 26.5 repetitions passed, then the full
same-head CI rerun passed all 257 tests, the Release build and artifact checks. The failed
attempt remains retained evidence; no test or product source was changed to obtain the rerun.

The full clean-main pre-archive operations/recovery review passed at `03:02:44Z`, including
fresh signed-in provider/Build Uploads evidence, official Fly metrics and a zero-High/Critical
scan of the exact v17 recovery image. A distinct `1.0.0 (8)` archive started at `03:03:03Z`:
`Wardrobe-1.0.0-8-a5e5cd4-appstore-20261016T030303Z.xcarchive`.
Xcode 27.0 / iOS 27 SDK, the existing Apple Distribution certificate and App Store profile
produced scalar production App Attest. Strict artifact, public configuration, Gmail-free,
non-emitting credential guards and matching arm64 app/dSYM checks passed at `03:03:42Z`.
Minimum deployment OS remains iOS 18.0.

Apple validation completed unsuccessfully at `03:05:51Z`: **Invalid Pre-Release Train** —
version `1.0.0` is closed for new submissions, and `CFBundleShortVersionString` must be higher
than the previously approved `1.0.0`. This archive is not uploadable and must not be reused.
A fresh post-rejection signed-in Build Uploads / All Statuses refresh still showed build 7
Complete latest and build 8 absent. No upload, processing or new internal distribution completed. The public build-7 release,
commerce-disabled scope and backend v17 remain unchanged. A higher marketing version requires
the owner's decision under AGENTS.md; the proposed next candidate is `1.0.1 (8)`.

## Approved replacement candidate

After the concrete Apple rejection, the owner explicitly authorized **Use 1.0.1 (8) and continue**.
`MARKETING_VERSION` is now `1.0.1`; `CURRENT_PROJECT_VERSION` remains unused build `8`.
This authorizes the replacement tests, signed archive, Apple validation and internal TestFlight
upload. It does not submit a public version or enable commerce/paid features. The rejected
`1.0.0 (8)` archive remains historical and unusable. Full regression and the replacement
archive/distribution checks must pass before this candidate is delivered.

## Validated replacement archive

The owner-approved `1.0.1 (8)` archive was built from clean synchronized main
`031911aa7a2da76d10fc33ea47dbe914b186eed1` after the repeated full regression and fresh pre-archive review.
Exact archive: `Wardrobe-1.0.1-8-031911a-appstore-20261016T032606Z.xcarchive`.
Strict archive verification passed at `2026-10-16T03:26:54.559883+00:00`; Apple validation passed
at `2026-10-16T03:29:38.122393+00:00`. The archive uses Apple Distribution signing, production
App Attest, minimum iOS 18, matching arm64 app/dSYM, and the unchanged public configuration.
App CDHash: `b63f9b2904beb8f4a2e0211015797dad59b34f54`; dSYM UUID: `081b03eb-3e91-3001-8bc5-83dd29a0c5b2`.
The operations lock now binds that exact candidate for the fresh clean-main pre-upload review.
Upload, Apple processing, internal Family assignment and saved tester notes remain open.
The rejected `1.0.0 (8)` archive remains unusable. Commerce binding and paid features remain off.
