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
