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

- Versioned candidate source: PR #12 commit `b000fdfb19ae496a42c6c38565d961a929801c17`,
  which contains `1.0.0 (4)`. The final `main` archive source is not frozen; record its merged SHA
  before archiving or uploading.
- Target version/build: `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 4`. The candidate
  has not yet been archived or uploaded.
- Production backend: Fly release v5 serves the policy-enforced `linux/amd64` image from source
  `7b6acb83960e2cd69458489ab5f5fe0e04cd9f85` at immutable digest
  `sha256:ff1befcbeede04e426f0da57d811f5d94366d4d7b83809bcb7a666325236ad17`,
  with validation category `2`, bundle-build allowlist `4`, durable encrypted auth storage, and
  `min_machines_running = 1`. Retained rollback digest
  `sha256:f4758e08046e187161b992ad34530c3c41c89375c9277522015628ec9306eef1`
  is App-Attest-only and registry-addressable.
- Development proof: App Attest enrollment, assertion renewal, and `/recommend` succeeded on an
  iPhone 16 Pro running iOS 26.6 with build 4. The iOS 27+ runtime category/build fields were
  absent as expected and are not claimed as development evidence.
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
- [ ] Verify production operations against that final image: retain the redacted Fly response and
  owner decisions, keep the payload-free manual review current, then prove 14-day snapshot-list
  disappearance, restore-after-deletion handling, and monitored support routing. The first review
  passed at `2026-08-20T00:15:07Z`. The generic
  isolated restore path passed on
  2026-08-19 with read-only, aggregate-only evidence and immediate temporary-resource cleanup; it
  does not close deletion-specific recovery. The customer-visible log stream is accepted as seven
  days; provider-internal in-service retention and all-copy snapshot purge timing are accepted as
  undisclosed. Do not claim the former 24-hour provider-log requirement passed.
- [x] Rotate and verify the Anthropic API key, retire `DEVICE_TOKEN`, deploy App-Attest-only auth,
  and prove the retired credential returns `401`. No credential value is retained in evidence.
- [x] Treat the opaque Apple receipt as untrusted fraud evidence, not session authorization. The
  current release neither redeems nor trusts it; before any future use, implement and evidence
  Apple's receipt signature/chain, App ID, freshness, and attested-public-key checks.
- [ ] Complete the production-client portion of the
  [Google OAuth sequence](../gcp-oauth-production-sequence.md): production Gmail project/iOS
  client and reversed callback scheme. Google remains solely the optional read-only Gmail
  connection; no Google server audience or stable Google subject authorizes Wardrobe's backend.
  Full restricted-scope approval/CASA may still be in progress for internal testing, but it must
  be approved before public App Store availability.
- [ ] Publish accurate privacy-policy and support pages on the final owned HTTPS domain and verify
  both while signed out.
- [ ] Create gitignored `ios/Distribution.xcconfig` from
  `ios/Distribution.xcconfig.example` with the production Google IDs, HTTPS backend host, public
  privacy/support URLs, and Apple Developer Team ID.
- [ ] Complete or explicitly defer the remaining App Store Connect record/media work in
  `APP-016` through `APP-018`. Deferral does not permit binary/configuration shortcuts.

## Per-build release-candidate loop

1. **Freeze the candidate.** Use a clean, reviewed commit. Record its hash, the backend image that
   will serve it, App Attest environment/category/build allowlist, iOS-version compatibility policy,
   durable auth-store version, and the policy-compliance evidence linked from
   [`app-attest-data-lifecycle-policy.md`](app-attest-data-lifecycle-policy.md).
2. **Choose version/build from App Store Connect.** In **Apps → Wardrobe Stylist → TestFlight →
   iOS**, inspect all uploads and choose the next unused `CURRENT_PROJECT_VERSION`. If this exact
   build may be promoted as the first public release, decide and set the intended public
   `MARKETING_VERSION` (recommended `1.0.0`) before archiving.
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
   signed production App Attest entitlement and absence of the shared bearer. Retain the archive
   entitlement and embedded-profile inspection as the distribution half of APP-009 evidence.
5. **Validate and upload.** In Organizer choose **Validate App**, then **Distribute App →
   TestFlight & App Store → Upload**. Upload symbols and use the intended distribution signing.
6. **Wait for processing.** In App Store Connect review Build Upload status, warnings, privacy
   manifests, entitlements, supported devices, version/build, and export-compliance state. Resolve
   every error before testing.
7. **Distribute internally.** Add the processed build only to the chosen Internal Testing group,
   enter truthful **What to Test** notes, and keep automatic distribution off when a deliberate QA
   gate is desired.
8. **Run clean-device QA.** Test both upgrade and clean install on a physical iPhone: launch/icon,
   local onboarding, offline Demo Mode, camera and photo library, migrations, App Attest enrollment
   and session renewal, import review, Gmail disclosure/sign-in/import, styling/history,
   reminders/background work, Settings/privacy, sign out, disconnect, local deletion, separate
   server-security deletion, account switching, offline/relaunch, backend failure, and reinstall
   creating a new anonymous installation. Verify
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
   bridge retirement, old-build rejection, and physical-device QA. Do not claim build/category
   rejection on iOS 18–26, where Apple omits those fields; the pre-App-Attest shared-token build
   must still be rejected.

## Post-upload APP-009 closure

Production App Attest proof is necessarily post-upload; it is not a pre-build gate.

- [ ] Retain the signed archive's production App Attest entitlement and matching embedded profile.
- [ ] From the processed internal TestFlight build, retain production enrollment, assertion
  renewal, and a protected API call. Record the tester OS and signed runtime-field presence; do not
  claim category/build enforcement when iOS 18–26 omits those fields.
- [ ] Complete upgrade and clean-install QA and attach the redacted results to the final evidence
  record.

## Promoting an internally tested build

When the build is approved for public release, do not rebuild unless something changed:

- Finish `APP-016` through `APP-018`, Google restricted-scope verification/CASA, agreements,
  pricing/availability, privacy answers, screenshots, review contact, and review notes.
- Select the already-tested build on the matching App Store version.
- Re-check the binary, live backend and auth store, App Attest compatibility policy plus iOS 27+
  build/category allowlist, public URLs, Gmail OAuth project, disclosures, and metadata against the
  retained evidence.
- Choose **Add for Review**, inspect the complete submission, then **Submit for Review**.

If code, resources, configuration, backend contract, disclosures, or version metadata changes,
increment the build number and repeat the full loop. Never "patch" an uploaded candidate in place.

## Suggested What to Test for the next build

> Verify the new Wardrobe Stylist icon, add an item with both Camera and Photo Library, and confirm
> each picker remains open until completion or cancellation. Review the simplified Settings hub
> and its Connected Features, Wardrobe & Demo, Privacy & Data, and Help & Support destinations.
> Confirm existing wardrobe data survives the upgrade, then exercise Gmail import review,
> styling/history, reminders, sign out, disconnect, and verified local deletion. On a clean
> physical install, confirm secure installation verification completes without a Wardrobe or
> Google sign-in, and that local/demo features remain usable during an offline backend failure.

## Official Apple references

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
- [View builds and upload status](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata)
- [Establishing your app's integrity with App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Validating App Attest at your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Preparing App Attest environments and rollout](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
