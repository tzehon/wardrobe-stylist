# Internal TestFlight, always App-Store-ready

Use this runbook for every internal beta. The audience is internal, but the binary is treated as
an App Store release candidate from the moment it is archived. This prevents a separate, weaker
"beta build" configuration from drifting away from what will eventually be reviewed.

## Distribution policy

- Upload with Xcode's **TestFlight & App Store** distribution option, then add the processed build
  only to an App Store Connect **Internal Testing** group.
- Do **not** choose **TestFlight Internal Only**. Apple marks that artifact as internal-only, so it
  cannot later be submitted to external testers or customers.
- Do not bypass the device-Release configuration guard. Internal testers must exercise the same
  production identifiers, HTTPS endpoints, privacy manifests, disclosures, and authentication
  architecture intended for App Review.
- Keep Debug/LAN credentials in `Secrets.xcconfig`. Keep non-secret distribution identifiers and
  endpoints in the gitignored `Distribution.xcconfig`. Never place a shared backend bearer or an
  Anthropic key in either public client configuration.
- Adding a build to an internal group is not an App Store submission. Promotion happens later by
  selecting the same processed build on the App Store version and submitting it for review.

## Current candidate status — 2026-08-20

- Version metadata baseline: PR #12 commit `b000fdfb19ae496a42c6c38565d961a929801c17`
  contains `1.0.0 (4)`. The final Gmail-free source is not frozen; record its merged SHA before
  archiving or uploading.
- Target version/build: `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 4`. The candidate
  has not been archived or uploaded. Live App Store Connect inspection confirms build 3 is the
  highest upload, so build 4 remains unused and selected unless that external fact changes.
- Current production backend: Fly release v5 serves the pre-APP-036 policy-enforced `linux/amd64`
  image from source
  `7b6acb83960e2cd69458489ab5f5fe0e04cd9f85` at immutable digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`,
  with validation category `2`, bundle-build allowlist `4`, durable encrypted auth storage, and
  `min_machines_running = 1`. Retained rollback digest
  `sha256:f4758e08046e187161b992ad34530c3c41c89375c9277522015628ec9306eef1`
  is App-Attest-only and registry-addressable. This image still exposes `/extract`; the tested
  Gmail-free replacement has not been built, scanned, pushed, or deployed from a merged source.
- Pre-APP-036 development proof: App Attest enrollment, assertion renewal, and `/recommend`
  succeeded on an iPhone 16 Pro running iOS 26.6 with build 4. The iOS 27+ runtime category/build
  fields were absent as expected. Repeat the relevant proof against the final Gmail-free build;
  the earlier run is a baseline, not candidate evidence.
- Current Gmail-free repository proof: 202 locked backend tests and all dependency/security/type
  gates passed; 209 unique iOS tests passed (200 Swift tests plus all 9 UI flows); 24/24 release-
  script tests passed; and a clean Release simulator artifact for `1.0.0 (4)` passed public-config,
  plist, dependency, and removed-capability verification. No Google/Gmail/OAuth, `/extract`, or
  receipt-background capability was found in shipped source/configuration, generated project,
  executable, or app bundle. This is unmerged simulator evidence, not a signed archive or
  production cutover.
- APP-009's lifecycle/logging policy is approved in
  [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md), and Fly v5 deploys
  its repository-owned enforcement. On 2026-08-19 the owner accepted Fly's fixed seven-day
  customer-visible logs, undisclosed provider-internal in-service retention, and 14-day
  snapshot-listing boundary with undisclosed all-copy purge timing. An isolated, secret-free,
  read-only restore of the 2026-08-19 snapshot passed aggregate-only schema/integrity checks and
  its temporary resources were removed within 391 seconds of volume creation. Snapshot-list
  expiry, deletion-specific recovery, the signed distribution archive/profile, and
  production TestFlight enrollment, assertion renewal, protected API call, and server-deletion UI
  proof are still required. The first payload-free manual operations review passed at
  `2026-08-20T00:15:07Z` and must be repeated before archive/upload.
- Fly Security summarized optional DPA termination periods of 30/90 days, but the account's
  Compliance page says the DPA is inactive until the customer signs it. Exact agreement review and
  any execution remain an APP-016 processor-contract gate, not proof of active log/snapshot purge.

## One-time gates before the next internal build

- [x] Push the readiness branch, review it, and merge the intended release scope so the uploaded
  commit is recoverable from the remote repository. PR #7 merged it to `main` at
  `f2a02825fd4178478bfc130525463165f12d648c`.
- [x] Implement the repository portion of `APP-009`: enroll one anonymous App Attest key per installation, validate fresh
  challenges/attestations/assertions at the backend, issue short-lived sessions, persist only
  durable auth/security metadata, enforce build/category allowlists when iOS 27+ supplies those
  signed fields, enforce rate limits, remove `BackendDeviceToken`, and retire/rotate the legacy
  backend token in the client contract. iOS 18–26 still requires core App Attest. Local wardrobe
  and Demo Mode remain available when secure verification is unsupported; remote AI fails closed.
- [x] Enable App Attest for `com.tth.Wardrobe`, confirm App ID prefix `29NT767Y9P`, exercise
  regenerated development signing, and retain physical-device sandbox enrollment and assertion
  renewal evidence.
- [x] Provision one encrypted Fly volume for the single production Machine; verify private
  ownership/modes, SQLite integrity, restart persistence, automatic daily snapshots, a retained
  snapshot, and an isolated restore rehearsal. These snapshots are not a separate backup system.
- [x] Adopt the APP-009
  [data-lifecycle and logging policy](app-attest-data-lifecycle-policy.md), including exact target
  periods, prohibited log fields, deletion/restore rules, manual operations requirements, and an
  explicit current-compliance checklist.
- [x] Enforce the repository-owned policy: a one-minute deadline-maintenance loop on a pinned
  minimum-one-Machine topology, repeat-until-drained cleanup, 90-day inactive and 30-day revoked
  installation purge, assertion-verified in-app deletion, SQLite secure-delete/WAL maintenance,
  structural persistence/logging guards, and a pinned no-access-log production command are all
  implemented and covered by focused tests.
- [x] After policy enforcement, build and scan the exact final `linux/amd64` container image,
  including OS packages, for high/critical known vulnerabilities; push and re-scan its immutable
  registry digest, then deploy only that digest. Fly v5 serves
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  from source `7b6acb83960e2cd69458489ab5f5fe0e04cd9f85`; both scans covered 90
  packages and found no critical/high vulnerability. The retained App-Attest-only rollback digest
  `sha256:f4758e08046e187161b992ad34530c3c41c89375c9277522015628ec9306eef1`
  was restored to the registry, re-scanned, and passed an isolated schema round-trip. The locked
  Python audit is already enforced in CI; the local Docker Scout command is
  `docker scout cves --only-severity critical,high --exit-code local://wardrobe-backend-local-verify`
  and requires an authenticated Docker Desktop/Docker ID session.
- [x] Rotate and verify the Anthropic API key, retire `DEVICE_TOKEN`, deploy App-Attest-only auth,
  and prove the retired credential returns `401`. No credential value is retained in evidence.
- [x] Treat the opaque Apple receipt as untrusted fraud evidence, not session authorization. The
  current release neither redeems nor trusts it; before any future use, implement and evidence
  Apple's receipt signature/chain, App ID, freshness, and attested-public-key checks.
- [x] Complete the repository and simulator-artifact portion of `APP-036`: Google Sign-In, Google
  client/callback configuration, Gmail/receipt-import UI and network paths, active `/extract`
  route/client capability, and receipt background scheduling are absent; build 4 uses the approved
  fresh local-only schema; Demo Mode and in-app disclosures are Gmail-free; and Release/artifact
  checks fail if a removed capability returns. Intentional negative guards and legacy-rate cleanup
  remain. The historical Google OAuth sequence is deferred and is not a public-v1 gate.
- [x] Create gitignored `ios/Distribution.xcconfig` from
  `ios/Distribution.xcconfig.example` with the HTTPS backend host, public privacy/support URLs, and
  Apple Developer Team ID. It contains no Google client identifiers or callback scheme; resolved
  Release settings and the simulator artifact passed the public configuration guard. The signed
  archive/profile proof remains a separate per-build step.
- [ ] Freeze and publish the Gmail-free source: review the combined diff, rebase onto current
  `origin/main`, publish a reviewable PR, merge it, fast-forward local `main`, and record the exact
  merged SHA. Do not build or deploy the replacement image from an unmerged working tree.
- [ ] Complete the pre-upload `APP-036` cutover: on the old build, complete **Disconnect Google**
  and **Delete Server Security Data**, wait for both successes, and uninstall. Build, scan, push,
  and deploy the exact merged-source immutable `linux/amd64` backend image; prove `/extract` is
  retired and repeat the payload-free manual review. Install build 4 only after TestFlight
  processing, never over builds 1–3.
- [ ] Republish accurate Gmail-free privacy-policy, support, and Terms pages on the final owned
  HTTPS domain and verify all three while signed out. The earlier Gmail-capable publication is
  retained as history: `tzehon.github.io` PR #3 merged as
  `7e919ef373782c22cc1500a31ed475ebfd75373c`; its Pages deployment succeeded, and anonymous HTTPS
  requests returned `200` for `https://blog.tth.dev/wardrobe/` and
  `https://blog.tth.dev/wardrobe/privacy/` at `2026-08-20T13:22:35Z`. PR #4 merged as
  `ff27bbe3ed2d2c4e7d3041313c0745df7f09fe44`; its Pages deployment also succeeded, and an anonymous
  HTTPS request returned `200` for `https://blog.tth.dev/wardrobe/terms/` at
  `2026-08-20T13:52:35Z`. The three rendered pages linked to each other as intended. Local
  Gmail-free revisions are prepared but must not be treated as published until a later Pages
  deployment and signed-out verification succeed.
- [ ] Complete or explicitly defer the remaining App Store Connect record/media work in
  `APP-016` through `APP-018`. Deferral does not permit binary/configuration shortcuts.

## Mandatory clean-uninstall transition for build 4

Build `1.0.0 (4)` is fresh-install-only and must never be installed over TestFlight builds 1–3.
The owner explicitly accepted losing the earlier local wardrobe and adding items again.

On the older build, in this order:

1. Complete **Settings → Connected Features → Disconnect Google** and wait for success.
2. Complete **Settings → Privacy & Data → Delete Server Security Data** and wait for success.
3. Uninstall Wardrobe Stylist. This deletes the old device-local wardrobe.
4. Install build 4 as a clean app and enroll its new anonymous App Attest installation.

Complete steps 1–3 before the backend cutover. Complete step 4 only after build 4 has processed in
TestFlight; the numbered list defines one transition, not a requirement to install an unprocessed
build.

Do not uninstall first. The Gmail-free app cannot revoke the old Google grant, and a reinstall
creates a different App Attest identity that cannot delete the prior live server record. Retain
redacted success evidence for steps 1–2; do not claim upgrade or migration support.

## Per-build release-candidate loop

1. **Freeze the candidate.** Use a clean, reviewed commit. Record its hash, the backend image that
   will serve it, App Attest environment/category/build allowlist, iOS-version compatibility policy,
   durable auth-store version, and the policy-compliance evidence linked from
   [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md).
2. **Confirm version/build from App Store Connect.** Live inspection currently shows build 3 as
   the highest upload, so the selected candidate remains `1.0.0 (4)`. Recheck immediately before
   archiving. If build 4 has appeared, stop and select the next unused integer; otherwise preserve
   build 4 and do not increment it merely because APP-036 changed unuploaded local source.
3. **Regenerate and verify.** Run the locked backend pytest/pip-audit/Bandit/Ruff/mypy suite, full Swift and UI suite,
   public Release configuration tests, request-capture/privacy guards, Release build, and simulator
   artifact preflight. Xcode strips App Attest from simulator signatures, so the signed entitlement
   is checked after archiving. Any config, auth allowlist, or build-number change happens before
   this final run.
4. **Create a signed device archive.** In Xcode select the `Wardrobe` scheme and a generic physical
   iOS device, then choose **Product → Archive**. The archive must pass the strict public Release
   post-build check without bypasses. Before validation or upload, run
   `ios/scripts/verify-release-artifact.sh DerivedData/ReleaseValidation
   "/path/to/Wardrobe.xcarchive/Products/Applications/Wardrobe.app"`; this pass must confirm the
   signed production App Attest entitlement; absence of the shared bearer, Google/GoogleSignIn/
   AppAuth/GTM bundles, Google client identifiers/callback scheme, Gmail permission/host/client
   paths, `/extract` client path, and receipt background-task identifier; and correct public URLs.
   Retain the archive entitlement and embedded-profile inspection as APP-009/APP-036 evidence.
5. **Validate and upload.** In Organizer choose **Validate App**, then **Distribute App →
   TestFlight & App Store → Upload**. Upload symbols and use the intended distribution signing.
6. **Wait for processing.** In App Store Connect review Build Upload status, warnings, privacy
   manifests, entitlements, supported devices, version/build, and export-compliance state. Resolve
   every error before testing.
7. **Distribute internally.** Add the processed build only to the chosen Internal Testing group,
   enter truthful **What to Test** notes, and keep automatic distribution off when a deliberate QA
   gate is desired.
8. **Run transition and fresh-install QA.** First complete the mandatory pre-uninstall sequence on
   the older build; never install build 4 over it. Then test a clean build-4 install on a physical
   iPhone: launch/icon, local onboarding, offline Demo Mode, manual add, camera/photo library,
   catalog edit/delete, App Attest enrollment/session renewal, styling consent/withdrawal,
   Today/History, local reminders, Settings/privacy, local deletion, separate server-security
   deletion, offline/relaunch, backend failure, and reinstall creating a new anonymous
   installation. Confirm no Google/Gmail/receipt-import UI or request exists. Verify
   local/demo behavior remains available when secure remote AI is unavailable. Through the
   processed internal TestFlight build, retain production enrollment, assertion renewal, and a
   protected API call. On iOS 18–26, record signed runtime-field absence without claiming
   category/build enforcement.
9. **Retire the bridge.** If a legacy compatibility bridge was used, switch the validated backend
   to App-Attest-only mode, unset/rotate `DEVICE_TOKEN`, and prove an old build is rejected while
   the candidate still succeeds. A rollback must use a retained App-Attest-only image and preserve
   the auth store; rolling back to the shared bearer is not an acceptable recovery plan.
10. **Record evidence.** Retain the commit, archive, build/version, Xcode and SDK, test results,
   validation/upload logs, processed-build metadata, backend image/config, exact App ID prefix,
   entitlement/profile, tester OS/runtime-field presence, category/build values when supplied,
   auth-store volume and snapshot/restore evidence, Apple-receipt validation/risk-metric policy,
   APP-036 artifact-absence output, pre-uninstall disconnect/server-deletion success, clean-install
   proof, bridge retirement, old-build rejection,
   and physical-device QA. Do not claim build/category
   rejection on iOS 18–26, where Apple omits those fields; the pre-App-Attest shared-token build
   must still be rejected.

## Post-upload APP-009 closure

Production App Attest proof is necessarily post-upload; it is not a pre-build gate.

- [ ] Retain the signed archive's production App Attest entitlement and matching embedded profile.
- [ ] From the processed internal TestFlight build, retain production enrollment, assertion
  renewal, and a protected API call. Record the tester OS and signed runtime-field presence; do not
  claim category/build enforcement when iOS 18–26 omits those fields.
- [ ] Retain the completed pre-uninstall cleanup evidence, install processed build 4 cleanly, and
  complete fresh-install QA. The cleanup itself occurs before backend cutover and upload; this
  post-upload step validates the replacement.
- [ ] Finish the remaining observable operations evidence: eligible 14-day snapshot-list
  disappearance and deletion-specific recovery. The generic isolated restore-path rehearsal does
  not prove that a deleted production identity cannot return.
- [ ] After processed build 4 and its replacement backend are proven, obtain a separate final
  owner confirmation and retire only the inventoried Wardrobe Google Cloud/OAuth projects. Do not
  touch unrelated Google Cloud or Search Console resources.

## Promoting an internally tested build

When the build is approved for public release, do not rebuild unless something changed:

- Finish `APP-016` through `APP-018`, agreements, pricing/availability, Gmail-free privacy answers,
  screenshots, review contact, and review notes. Google restricted-scope verification/CASA is not
  a public-v1 gate.
- Select the already-tested build on the matching App Store version.
- Re-check the binary, live backend and auth store, App Attest compatibility policy plus iOS 27+
  build/category allowlist, public URLs, Gmail-free archive evidence, disclosures, and metadata
  against the retained evidence.
- Choose **Add for Review**, inspect the complete submission, then **Submit for Review**.

If code, resources, configuration, backend contract, disclosures, or version metadata changes,
increment the build number and repeat the full loop. Never "patch" an uploaded candidate in place.

## Suggested What to Test for the next build

> Verify the new Wardrobe Stylist icon, add an item with both Camera and Photo Library, and confirm
> each picker remains open until completion or cancellation. Review the simplified Settings hub
> and its Connected Features, Wardrobe & Demo, Privacy & Data, and Help & Support destinations.
> On builds 1–3, complete Disconnect Google and Delete Server Security Data, then uninstall; never
> install build 4 over the older app. On the clean build-4 install, exercise manual/photo cataloging,
> styling/history, reminders, styling-consent withdrawal, verified local deletion, and separate
> server-security deletion. On a clean physical install, confirm there is no Google/Gmail or login
> path, secure installation verification completes anonymously, and local/demo features remain
> usable during an offline backend failure.

## Official Apple references

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
- [View builds and upload status](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata)
- [Establishing your app's integrity with App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Validating App Attest at your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Preparing App Attest environments and rollout](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
