# Singapore launch check — 23 September 2026

**Current outcome: publicly available in Singapore.** Backend remediation and complete final
verification passed. The authorized manual release of `1.0.0 (7)` was accepted at approximately
**14:33 UTC / 22:33 SGT**. By **14:44 UTC / 22:44 SGT**, the anonymous public listing was live,
App Store Connect showed **Ready for Distribution**, and Singapore was **Available**, with
174 other territories unavailable. The app remains Free, iPhone-only, without IAP/subscriptions.
[Live App Store listing](https://apps.apple.com/sg/app/wardrobe-stylist/id6789053566).
The earlier hold, diagnostic gap and initial propagation observations below are historical.

Historical initial outcome: **HOLD public release** (superseded by the verified remediation and release below). Apple has approved `1.0.0 (7)`; the version is
**Pending Developer Release**. The initial owner request was refreshed launch checks only. The owner subsequently instructed
remediation and public release after verification; this authorizes the necessary compatible backend
deployment and manual release of approved build 7, without another approval request.
The existing backend image fails the zero-High/Critical recovery-image requirement,
and fresh auth-store/capacity/volume diagnostics remain unverified after SSH timeouts.

## Apple and public-facing checks

Read directly from signed-in App Store Connect on 23 September:

- Submission **Review Completed**, item **Approved**, version **Pending Developer Release**.
  Messages (7) includes Apple's 22 September, 21:42 SGT acknowledgement that review would continue.
  Approval was observed on 23 September; its exact transition time was not established.
- Singapore is the sole available country; the other 174 countries/regions are unavailable.
  Current Singapore price is SGD 0.00. Mac and Vision Pro availability are disabled.
- No in-app purchases, auto-renewable subscription groups or non-renewing subscriptions exist.
- TestFlight Build Uploads shows `1.0.0 (7)` **Complete**. Build 7 remains assigned to Family.
- Manual release remains selected. No release button, reply, appeal or resubmission was submitted.
- The strict archived-candidate check and anonymous backend route, support, privacy and Terms
  checks passed against the retained build-7 archive.

## Production and spend checks

The tracked verifier ran from clean synchronized `main` at `0e9fa07`; its completed report is
retained privately as `.fly/launch-preflight-20260923.log` (13:19:12 UTC).
An expired Fly CLI login was refreshed through the existing account's normal browser flow.
No new provider scope, resource or service configuration was requested.

- **PASS:** exact healthy Fly v14 runtime/image/source, App-Attest-only configuration,
  existing App Store/TestFlight compatibility policy, and unchanged single-Machine deployment.
- **PASS:** enabled AI budget, ready bounded ledger, below-warning spend and clear concurrency.
  This is a read-only status check, not a new paid/protected styling call.
- **PASS:** automatic encrypted-volume snapshot policy; newest snapshot
  `2026-09-23T07:59:10Z`, created, 14-day retention. This does not establish all-copy purge.
- **PASS:** bounded application event review; public backend routes and all three public pages.
- **PASS:** Claude public status; signed-in production workspace spend below its existing
  warning threshold, approved workspace monthly limit and email thresholds retained,
  sufficient available credits, auto-reload off, production cost attributed to Sonnet 5,
  and no observed Sonnet 5 rate-limit saturation in the last 24 hours.
  The existing production key expires on 8 October; rotate before expiry.
- **PASS, limited window:** Fly's populated official one-hour HTTP view shows 200/404 only,
  with no 5xx series. The two-day view returned no data, including after reload; do not infer
  zero failures over that longer period. The visible Fly incident concerns Upstash in Frankfurt,
  which this Singapore app does not use.
- **Hosting observation:** one Singapore shared-CPU/512 MB Machine, one 1 GB volume and shared
  IPv4/IPv6 remain observed. Account is in good standing. Invoice service subtotal and Cost
  Explorer agree and remain below the private warning threshold. Net amount due differs from
  service subtotal; no precise usage cutoff or complete adjustment/tax reconciliation was shown.
  Two additional zero-rounded cross-region network line items are present. Retain the accepted
  variable Fly exposure and daily owner review; this is not an enforceable monetary cap.

Fresh signed-in fixed-field observations are retained in `.fly/launch-manual-20260923.toml`.
They do not convert the overall automated OPEN report into a PASS.

## Release blockers

1. **Critical image finding.** Fresh registry authentication and exact Linux/AMD64 image
   resolution succeeded. Docker Scout returned one Critical and zero High findings:
   `anyio 4.13.0`, **CVE-2026-63374**, improper certificate validation, CVSS 9.3.
   Scout reports affected versions `<4.14.2` and fixed version `4.14.2`.
   The exact serving image is also the recovery image, so the required clean scan fails.
   This is a scanner finding; application-specific exploitability was not tested.
   Private full scan: `.fly/launch-recovery-scan-20260923.txt`.
2. **Diagnostic evidence incomplete.** Auth-store schema/integrity, installation/session
   capacity and volume-use checks timed out through SSH. The standard 45-second check and a
   120-second retry did not complete; service-user and shorter-command retries also timed out. These are OPEN,
   not proven data corruption or an observed capacity breach. The shorter AI-budget probe passed.

Prepare a backward-compatible backend dependency remediation, run the repository's full required
regression and image scan, then deploy under the subsequent owner authorization. After any
deployment, verify the exact live configuration, restore successful auth/capacity/volume evidence,
and repeat the complete operations review. Preserve the existing auth store, budget ledger,
limits and resource envelope. No library update, deployment or service hold was performed here.

## Release impact and evidence boundaries

No shipped code, runtime configuration, tests, archive or version number changed. This read-only
review and documentation update require **no new TestFlight build**. A compatible backend-only
repair can retain approved build 7; assess the actual repair before deployment. Existing physical
QA and the scoped snapshot evidence waiver remain retained; do not repeat completed deletion or
routine device QA. No full regression was rerun for this documentation-only evidence update.

Manual public release is now owner-authorized once the backend blockers and all verification
gates are resolved. The 19 September rejection/wait-for-clarification work order is superseded by this
observed Apple approval and launch hold. No appeal or product redesign is currently needed to
answer that earlier rejection.

Review recorded at 2026-09-23T13:30:08Z UTC.

## Historical remediation checkpoint

- Added an explicit AnyIO security floor and narrowly updated the lock from 4.13.0 to 4.14.2.
  The [upstream advisory](https://github.com/agronholm/anyio/security/advisories/GHSA-82r6-8w77-94w6)
  describes inconsistent IDNA normalization during TLS certificate matching. The current app uses
  a synchronous client and fixed ASCII Anthropic hostname; application exploitability is unproven.
- Added network-free real TLS certificate regressions: two wrong-domain certificates are rejected,
  and Unicode IDNA2008, preencoded IDNA and ASCII controls succeed. Against the old dependency,
  three cases fail; all five pass with 4.14.2.
- Smaller live read-only probes passed schema, integrity and volume access. The full remote command
  stalled before its first marker, including a compressed attempt. The diagnostic now lives in
  `production_auth_diagnostic`, invoked using a short command under the existing service UID, with
  bytecode writes disabled. It retains all original schema/runtime/aggregate/disk checks and adds
  tests for valid state, runtime/schema drift, missing-database noncreation and service identity.
- Initial local iOS regression was blocked by Xcode 27 versus an older installed CoreSimulator.
  `xcodebuild -runFirstLaunch` successfully installed the matching components; regression is rerunning.
- Historical model-evaluation acceptance remains source-bound historical evidence. This dependency
  repair changes neither model, prompt, generation parameters nor the API contract; no new paid
  evaluation was initiated. No new TestFlight build is required.

Deployment, complete post-deployment review and public release were pending at this checkpoint;
the completed actions are recorded below.

## Verified backend remediation

PR [#59](https://github.com/tzehon/wardrobe-stylist/pull/59) received a clean Codex review on
`7b2314b` and rebase-merged at 13:54:35 UTC to `cb81d7c0e35fd36917bde0a4ab78c8bd456c257b`.
The tested and merged runtime/iOS/shared trees are identical. Full verification passed:

- 879 backend tests; locked pip-audit, Bandit (including the standalone diagnostic), Ruff and mypy.
- Xcode 27 full iOS regression: 227 Swift tests and 10 UI tests; 44 release-script tests.
- Exact merged Linux/AMD64 image: zero High/Critical findings locally and in the private registry;
  non-root/no-new-privileges, bounded logging, separate storage and restart-liability smokes passed.

The owner-authorized in-place deployment completed as Fly v15. The immediate follow-up caught
the Machine in `replacing` state; a subsequent independent read confirmed the exact healthy
image/source and preserved Machine, volume and all policy configuration. No deployment retry,
restore, ledger initialization, reset, limit change or new resource occurred. New diagnostics pass
for schema/integrity/runtime guards, configured public-capacity bands and disk usage below 70%;
AI remains enabled with a ready ledger, below-warning spend and no pending concurrency.

Private records: `.fly/runtime-publication-msh54stt`, `.fly/runtime-deployment-7f1dtiiy`,
`.fly/launch-live-runtime-20260923.json`, and the dated backend/iOS regression logs.
The v15 exact image replaces v14 as the eligible recovery image after its successful identity/scan
checks; v14 is historical and must not be restored while its Critical finding remains.

At this deployment checkpoint, the tracked baseline update, final operations review and manual
release were pending; the completed actions are recorded below. No new TestFlight build is required.

## Final preflight and manual release

PR [#60](https://github.com/tzehon/wardrobe-stylist/pull/60) received a clean current-head Codex
review on `9f78e5b`, with both prior documentation findings resolved and both CI checks green.
It rebase-merged to clean synchronized main `faea0c664569b3bba1e063083214f1fa5c2d69e9`.
The full preflight at **2026-09-23T14:31:20Z** passed every category: source/archive,
exact healthy Fly v15 runtime and App-Attest-only configuration, auth integrity/capacity,
enabled below-warning budget, volume below 70%, fresh automatic 14-day snapshot policy,
bounded events, public health/routes/pages, Claude public status, fresh signed-in console
inputs and exact Linux/AMD64 recovery-image scan with zero High/Critical findings.
Private report: `.fly/launch-final-preflight-20260923.log`.

During the console refresh the HTTP dashboard briefly showed no data and Grafana showed zero
responses in its one-hour window. After the preflight’s public checks, the official one-hour
chart populated with 200 and 404 only, with no 5xx series. This confirms that displayed window,
not an unobserved two-day history. The approved provider controls remained below warning,
credits available, auto-reload off, production key unexpired, and Sonnet 5 without saturation.

At approximately **14:33Z / 22:33 SGT**, selected **Release This Version** and confirmed the
Apple dialog explicitly listing **Singapore** as its sole download/purchase territory.
Apple then changed `1.0.0 (7)` to **Ready for Distribution**. The availability page shows
**1 Processing** and **174 Not Available**, matching the sole Singapore release destination.
No additional build, upload,
resubmission, app metadata edit or country/price expansion occurred.
The first anonymous check of `https://apps.apple.com/sg/app/id6789053566` returned Apple’s
page-not-found screen; this is a propagation boundary, not proof of download availability.
[Apple’s release guidance](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option)
allows up to 24 hours for the version to appear publicly after manual release.

Full validated regression remains 879 backend tests with locked audit/Bandit/Ruff/mypy,
227 Swift tests plus 10 UI tests, and 44 release-script tests. This final record changes
only documentation and needs no new TestFlight build or repeat regression.
Retain daily owner cost review, existing budgets/resources, the scoped snapshot-risk waiver,
and production provider-key rotation before 8 October. Public release does not convert the
waived snapshot/all-copy purge and recovery/non-return evidence into passed proof.

## Public storefront confirmed

By **2026-09-23 14:44 UTC (22:44 SGT)**, the anonymous Singapore App Store page resolved to
**Wardrobe Stylist**, subtitle **Catalog. Style. Wear more.**, **Free**, **Only for iPhone**,
developer **Tan Tze Hon**, Lifestyle category, age rating 9+, the five intended screenshots and
the approved local-first/optional-AI description. Canonical URL:
[Wardrobe Stylist](https://apps.apple.com/sg/app/wardrobe-stylist/id6789053566).
A separate signed-in App Store Connect refresh showed **Ready for Distribution**, **1 Available**
and **174 Not Available**; Singapore is the sole selected territory. This completes public-listing
and territory verification after the initial Processing/page-not-found checkpoint. No on-device
App Store installation was performed; the retained build-7 TestFlight/device evidence is distinct.

The public App Store installation/launch and support-handoff follow-up remains unchecked in the
submission checklist. Live listing/territory verification completes the publication action but
cannot prove the public-store delivery path on an iPhone. Preserve existing identity/data;
no repeat functional matrix, deletion or uninstall is requested. The owner-controlled physical
check is distinct from the completed automated and TestFlight evidence.
