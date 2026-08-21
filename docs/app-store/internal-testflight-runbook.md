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

## Current candidate status — 2026-08-21

- Version metadata baseline: PR #12 commit `b000fdfb19ae496a42c6c38565d961a929801c17`
  contains `1.0.0 (4)`. Final Gmail-free product/backend source merged through PR #14 as
  `9a48caebdec67ac26673c3ba51546a5e7edcf0cc`; local and remote `main` were synchronized before
  the release image was built. The archive source is later `dd3d99061321cf91bdce166e7da579b84edb07e8`,
  which adds the signed-profile verifier fix without changing that shipped app bundle. PR #19 then
  rebase-merged the reviewed Swift/backend/contract/verifier fixes as
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`. Documentation-only PR #20 then produced clean
  synchronized archive context `24c17cb9fe643035f9206ee61e2935e086902146`; `ios/`, `backend/`,
  and `shared/` are unchanged from the reviewed code merge. The reviewed backend is deployed and
  the clean replacement regression/archive are verified.
- Target version/build: `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 4`. Live App Store
  Connect showed builds 1–3 only at `2026-08-21T06:34:50Z`, immediately before the replacement
  archive, so build 4 remained unused. The historical `dd3d990` signed archive remains superseded
  and is not eligible for validation or upload.
- Current production backend baseline: Fly release v7 serves the exact reviewed `linux/amd64`
  image from source `d4637f4b2adf14cd533594aec6060c385f8a5e2b` at immutable digest
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`,
  with validation category `2`, bundle-build allowlist `4`, durable encrypted auth storage, and
  `min_machines_running = 1`. Local and immutable-registry scans each covered 90 packages and found
  no critical/high vulnerability. Gmail-free v6 digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  remains the required recovery baseline and passed a fresh registry scan. Both exact v7 and v6
  digests resolved after fresh registry authentication at `2026-08-21T06:06:01Z`. Emergency
  pre-build-4 rollback digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  is App-Attest-only and scan-clean, but it re-exposes `/extract`; using it must halt the release.
  Production `/extract` returns `404`, unauthenticated `/recommend` returns `401`, and the v7
  post-deploy review passed at `2026-08-21T06:00:21Z`.
- Pre-APP-036 development proof: App Attest enrollment, assertion renewal, and `/recommend`
  succeeded on an iPhone 16 Pro running iOS 26.6 with build 4. The iOS 27+ runtime category/build
  fields were absent as expected. Repeat the relevant proof against the final Gmail-free build;
  the earlier run is a baseline, not candidate evidence.
- Superseded Gmail-free repository proof: 202 locked backend tests and all dependency/security/type
  gates passed; 209 unique iOS tests passed (200 Swift tests plus all 9 UI flows); 31/31 release-
  script tests passed; and a clean Release simulator artifact for `1.0.0 (4)` passed public-config,
  plist, dependency, and removed-capability verification. No Google/Gmail/OAuth, `/extract`, or
  receipt-background capability was found in shipped source/configuration, generated project,
  executable, or app bundle. Clean source `dd3d99061321cf91bdce166e7da579b84edb07e8` then produced
  the signed `1.0.0 (4)` App Store archive. Its strict verifier passed the production App Attest
  entitlement, matching distribution profile, public configuration, app privacy manifest, and
  removed-capability checks. Preserve these facts as history only: the shipped Swift/backend and
  merged contract/verifier changes invalidate the old regression and archive as current
  candidate evidence.
- Current replacement proof: clean synchronized source context
  `24c17cb9fe643035f9206ee61e2935e086902146` passed 219 backend tests, 215 Swift tests, all 9 UI
  flows, 43 release-script tests, the locked dependency/security/type gates, and clean Release
  simulator/public-config/privacy/removed-capability verification. Xcode 26.6 with the iOS 26.5
  SDK created the arm64 Apple Distribution archive for `1.0.0 (4)` at
  `2026-08-21T06:36:33Z`. Its strict verifier passed the matching App Store profile/certificate,
  scalar production App Attest, HTTPS public configuration, app privacy manifest, and Gmail-free
  artifact guards. A separate targeted scan found no Anthropic/API-key, shared-bearer, or private-
  key credential marker; separate `dwarfdump --uuid` output matched the arm64 app and dSYM at
  `5BA1F06E-7458-32A4-890F-36C8F22D9C13`. The upload target is
  `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`.
- APP-009's lifecycle/logging policy is approved in
  [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md), and Fly v7 deploys
  its repository-owned enforcement. On 2026-08-19 the owner accepted Fly's fixed seven-day
  customer-visible logs, undisclosed provider-internal in-service retention, and 14-day
  snapshot-listing boundary with undisclosed all-copy purge timing. An isolated, secret-free,
  read-only restore of the 2026-08-19 snapshot passed aggregate-only schema/integrity checks and
  its temporary resources were removed within 391 seconds of volume creation. Snapshot-list
  expiry, deletion-specific recovery, and production TestFlight enrollment, assertion renewal,
  protected API call, and server-deletion UI proof are still required. The first payload-free
  manual operations review passed at `2026-08-20T00:15:07Z`; the required post-v6 review passed at
  `2026-08-21T01:11:43Z`; and the historical pre-archive repeat passed at
  `2026-08-21T03:30:33Z`. The reviewed v7 post-deploy review passed at
  `2026-08-21T06:00:21Z`; repeat it against that exact deployment immediately before upload and no
  later than 2026-09-20.
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
- [x] After policy enforcement, build and scan the exact reviewed `linux/amd64` container image,
  including OS packages, for high/critical known vulnerabilities; push and re-scan its immutable
  registry digest, then deploy only that digest. Fly v7 serves
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`
  from source `d4637f4b2adf14cd533594aec6060c385f8a5e2b`; both scans covered 90
  packages and found no critical/high vulnerability. Gmail-free v6 digest
  `sha256:0550dc9004a49711bd7346f750e62d1946fc13249b3ef0a5b11dc1480a40b5c5`
  remains the recovery baseline and passed a fresh registry scan. The emergency v5 rollback digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  was restored to the registry, re-scanned, and passed an isolated old/new/old schema-v4
  round-trip. The locked Python audit is already enforced in CI; the local Docker Scout command is
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
  Release settings and the simulator artifact passed the public configuration guard. The later
  per-build archive/profile proof also passed for historical `1.0.0 (4)` source `dd3d990`; that
  archive is now superseded and cannot satisfy the current gate. The completed replacement
  per-build archive/profile proof is recorded below.
- [x] Freeze and publish the Gmail-free source. PR #14 merged as
  `9a48caebdec67ac26673c3ba51546a5e7edcf0cc`; its remote branch was deleted, and local `main` was
  fast-forwarded to the same `origin/main` SHA before the release image was built.
- [x] Complete the pre-upload `APP-036` cutover. The installed intermediate development build
  `0.1.0 (4)` completed Google disconnection and local deletion, but it predated the
  server-deletion UI. Production had zero installations, zero sessions, and zero pending challenges
  before it was uninstalled, so no live production identity existed to delete. Exact-source
  `linux/amd64` digest
  `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0` passed local and registry
  critical/high scans across 90 packages and is healthy as Fly release v7 from source
  `d4637f4b2adf14cd533594aec6060c385f8a5e2b`. The registry-resolved
  v5 emergency rollback digest `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`
  resolved after fresh private-registry authentication at `2026-08-21T01:20:25Z`, re-scanned clean,
  and passed an isolated old/new/old schema-v4 rehearsal. Production `/extract`
  returns `404`, `/recommend` fails closed without authorization, and the payload-free
  reviewed v7 post-deploy manual review passed at `2026-08-21T06:00:21Z`. Install build 4 only after
  TestFlight processing, never over an older app.
- [x] Republish accurate Gmail-free privacy-policy, support, and Terms pages on the final owned
  HTTPS domain and verify all three while signed out. `tzehon.github.io` PR #5 merged as
  `c5da090a0417bcda99fc6d328a0cdff808ea597d` at `2026-08-21T01:42:01Z`; the matching Pages run
  completed successfully at `2026-08-21T01:42:39Z`. Anonymous HTTPS requests at
  `2026-08-21T01:45:27Z` returned `200` for `https://blog.tth.dev/wardrobe/`,
  `https://blog.tth.dev/wardrobe/privacy/`, and `https://blog.tth.dev/wardrobe/terms/`. The rendered
  pages showed the 21 August 2026 effective date where applicable, linked to each other, and
  contained no Gmail/Google/OAuth/import capability claim. This closes the publication sub-gate;
  provider terms, App Privacy, and final store answers remain separate APP-016 work.
- [x] Explicitly defer the remaining App Store Connect record/media work in `APP-016` through
  `APP-018` for the internal TestFlight build only. Those items remain open and must be completed
  before App Store submission; this sequencing decision permits no binary, signing,
  configuration, privacy, or review-evidence shortcut.

The following restart gates are ordered. They replace the superseded `dd3d990` archive as the
active path and must be completed without skipping ahead:

- [x] **Merge and freeze the review fixes.** PR #19 rebase-merged the reviewed Swift, backend,
  shared-contract, release-verifier, and focused-test changes. The remote branch was deleted and
  clean synchronized `main` is `d4637f4b2adf14cd533594aec6060c385f8a5e2b`.
- [x] **Build, scan, and deploy the exact reviewed backend.** The exact frozen `linux/amd64` image
  passed local and immutable-registry critical/high scans across 90 packages and was deployed only
  as digest `sha256:360e1351e36e782dcb375f6bffd25f1e633014f347734694759e61cea59d62a0`.
  Production health, auth-store/configuration, encrypted storage, snapshot policy, and Gmail-free
  route behavior passed, followed by the payload-free review at `2026-08-21T06:00:21Z`.
- [x] **Run a clean Release regression and create the replacement signed archive.** App Store
  Connect showed builds 1–3 only at `2026-08-21T06:34:50Z`. Clean source context `24c17cb` passed
  219 backend tests, 215 Swift tests, all 9 UI flows, 43 release-script tests, and every Release,
  request-capture, dependency, privacy-manifest, and removed-capability gate. Xcode 26.6/iOS SDK
  26.5 created `Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive` at
  `2026-08-21T06:36:33Z`; strict certificate/profile, production App Attest, public-config,
  privacy-manifest, and Gmail-free artifact verification passed. Separate targeted credential-
  pattern and app/dSYM UUID checks also passed.
- [ ] **Repeat the pre-upload review, then validate and upload.** Repeat the payload-free manual
  review against the exact deployed backend and refresh App Store Connect's build-upload list
  immediately before validation/upload. Stop if build 4 is no longer unused. Only after both
  checks pass may the replacement archive be validated and uploaded through **TestFlight & App
  Store**. Neither `dd3d990` archive is an upload target.

## Mandatory clean-uninstall transition for build 4

Build `1.0.0 (4)` is fresh-install-only and must never be installed over an earlier app. The owner
explicitly accepted losing the earlier local wardrobe and adding items again.

The pre-upload portion completed on 2026-08-21. The installed intermediate development build was
`0.1.0 (4)`, not an uploaded TestFlight candidate. It completed **Disconnect Google** and
**Delete Local Data**, but predated **Delete Server Security Data**. A read-only aggregate query
reported zero production installations, sessions, and pending challenges, so there was no live
production identity to delete. The app was then uninstalled. This exception is evidence about that
one retired build, not permission to skip verified server deletion when a future installed build
has a live identity or exposes the control.

Install `1.0.0 (4)` only after it has processed in TestFlight. The clean install must enroll a new
anonymous production App Attest identity; do not claim upgrade or migration support.

## Per-build release-candidate loop

1. **Freeze the candidate.** Use a clean, reviewed commit. Record its hash, the backend image that
   will serve it, App Attest environment/category/build allowlist, iOS-version compatibility policy,
   durable auth-store version, and the policy-compliance evidence linked from
   [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md). Re-resolve the v6
   Gmail-free recovery digest after fresh private-registry authentication immediately before
   archive/upload.
2. **Confirm version/build from App Store Connect.** The refreshed inspection at
   `2026-08-21T06:34:50Z` showed builds 1–3 only, so the replacement archive correctly preserved
   `1.0.0 (4)`. Refresh the build-upload list again immediately before validation/upload and stop
   if build 4 is no longer unused. Never reuse build 4 after upload.
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
   Historical evidence: for build `1.0.0 (4)`, clean source
   `dd3d99061321cf91bdce166e7da579b84edb07e8`
   produced the Apple Distribution archive at `2026-08-21T03:34:13Z` using Xcode 26.6 and the iOS
   26.5 SDK. The signed app carried scalar production App Attest, and the embedded App Store profile
   matched its team, App ID, certificate, and production grant. The strict artifact verifier passed
   public configuration, app privacy manifest, and Gmail-free artifact checks. Subsequent
   shipped Swift/backend changes supersede
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-dd3d990-appstore.xcarchive`; retain it only
   as history and never validate or upload it. A separate earlier automatic-signing archive,
   `Wardrobe-1.0.0-4-dd3d990.xcarchive`, used a development profile and failed verification; it
   also must never be validated or uploaded. Current replacement evidence: clean synchronized
   source context `24c17cb9fe643035f9206ee61e2935e086902146` (a documentation-only successor to
   shipped-code merge `d4637f4b2adf14cd533594aec6060c385f8a5e2b`) produced
   `ios/DerivedData/ReleaseValidation/Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive` at
   `2026-08-21T06:36:33Z`. It is arm64, minimum iOS 18.0, Xcode 26.6/iOS SDK 26.5, and signed by
   `Apple Distribution: Tan Tze Hon (29NT767Y9P)` with profile
   `Wardrobe App Store App Attest 2026-08-21` (`2b11bc90-0194-4fe6-8dcc-413c6dc5ccd2`). The signed
   app carries scalar production App Attest; the profile is App Store distribution, grants
   production, and contains the matching certificate. The strict verifier passed HTTPS public
   configuration, app privacy manifest, and Gmail-free artifact guards. A separate targeted scan
   found no Anthropic/API-key, shared-bearer, or private-key credential marker. Separate
   `dwarfdump --uuid` output matched the arm64 app and dSYM at
   `5BA1F06E-7458-32A4-890F-36C8F22D9C13`.
5. **Validate and upload.** In Organizer choose **Validate App**, then **Distribute App →
   TestFlight & App Store → Upload**. Upload symbols and use the intended distribution signing.
6. **Wait for processing.** In App Store Connect review Build Upload status, warnings, privacy
   manifests, entitlements, supported devices, version/build, and export-compliance state. Resolve
   every error before testing.
7. **Distribute internally.** Add the processed build only to the chosen Internal Testing group,
   enter truthful **What to Test** notes, and keep automatic distribution off when a deliberate QA
   gate is desired.
8. **Run fresh-install QA.** The mandatory pre-uninstall sequence is already recorded complete;
   never install build 4 over an older app. Test a clean build-4 install on a physical
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
   the candidate still succeeds. After build 4 is distributed, recovery must use the retained v6
   Gmail-free digest or a later validated Gmail-free App-Attest-only image while preserving the auth
   store. The former v5 image is a pre-build-4 abort only: it re-exposes `/extract` and must halt the
   release. Rolling back to the shared bearer is never acceptable.
10. **Record evidence.** Retain the commit, archive, build/version, Xcode and SDK, test results,
   validation/upload logs, processed-build metadata, backend image/config, exact App ID prefix,
   entitlement/profile, tester OS/runtime-field presence, category/build values when supplied,
   auth-store volume and snapshot/restore evidence, Apple-receipt validation/risk-metric policy,
   APP-036 artifact-absence output, pre-uninstall Google disconnection and local deletion, the exact
   zero-installation/zero-session/zero-pending-challenge production check, clean-install proof,
   bridge retirement, old-build rejection,
   and physical-device QA. Do not claim build/category
   rejection on iOS 18–26, where Apple omits those fields; the pre-App-Attest shared-token build
   must still be rejected.

## Post-upload APP-009 closure

Production App Attest proof is necessarily post-upload; it is not a pre-build gate.

- [x] Retain the current candidate's signed production App Attest entitlement, matching embedded
  App Store profile and certificate, and strict artifact-verifier result. The verified current
  archive is `Wardrobe-1.0.0-4-24c17cb-appstore.xcarchive`; historical `dd3d990` archives are
  superseded and cannot satisfy any later upload or processed-build gate.
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
> Install build 4 only as a clean processed-TestFlight install; the earlier development app was
> already disconnected, locally cleared, and uninstalled after production was verified to contain
> zero installations, zero sessions, and zero pending challenges. Exercise manual/photo cataloging,
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
