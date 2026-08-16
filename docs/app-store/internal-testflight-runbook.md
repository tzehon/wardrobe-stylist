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

## Current candidate status — 2026-08-16

- Candidate source: PR #7 is merged to `main` at
  `f2a02825fd4178478bfc130525463165f12d648c`. APP-009 follow-up work is isolated on
  `codex/app-009-backend-identity`.
- Local version/build: `MARKETING_VERSION = 0.1.0`, `CURRENT_PROJECT_VERSION = 3`.
- The merged candidate scope and APP-009 follow-up have not changed version metadata or uploaded
  a new TestFlight build.
- The next build number is unknown until the highest uploaded build is checked in App Store
  Connect. Never infer it from the repository alone.
- APP-009's repository implementation is complete and regression-tested on the follow-up branch,
  but the item remains open. Apple capability/profile setup, the exact App ID prefix, durable Fly
  auth storage, compatible backend deployment, production App Attest physical-device proof, and
  legacy-token retirement must still be evidenced. A Release-simulator build cannot clear any of
  those external gates.

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
- [ ] In Certificates, Identifiers & Profiles, confirm the exact App ID prefix for
  `com.tth.Wardrobe`, enable App Attest, regenerate provisioning profiles, and verify the signed
  archive and embedded profile. Complete a development/sandbox run on a physical iPhone, then a
  production TestFlight run whose attestation reports category `2` and the exact uploaded build.
- [ ] Provision private durable auth storage for the Fly deployment. Record its mount/database,
  single- versus multi-machine topology, atomic counter/challenge behavior, snapshot/backup and
  restore procedure, and retention/deletion criteria. Do not enable production App Attest with an
  ephemeral or in-memory store, and never persist receipt text or wardrobe payloads there.
- [ ] Before deployment, rotate the Anthropic API key and legacy `DEVICE_TOKEN`; store only the
  replacement values in their external secret managers, never in the repository or release
  evidence. Verify the old values are unusable after the cutover.
- [ ] Treat the opaque Apple receipt stored from an otherwise valid attestation as separate fraud
  evidence, not as part of session authorization. Before trusting or redeeming it, implement and
  evidence Apple's receipt signature/chain, App ID, freshness, and attested-public-key checks; until
  then, do not describe the receipt itself or any risk metric as verified.
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
   and durable auth-store version.
2. **Choose version/build from App Store Connect.** In **Apps → Wardrobe Stylist → TestFlight →
   iOS**, inspect all uploads and choose the next unused `CURRENT_PROJECT_VERSION`. If this exact
   build may be promoted as the first public release, decide and set the intended public
   `MARKETING_VERSION` (recommended `1.0.0`) before archiving.
3. **Regenerate and verify.** Run the backend pytest/Ruff/mypy suite, full Swift and UI suite,
   public Release configuration tests, request-capture/privacy guards, Release build, and simulator
   artifact preflight. Xcode strips App Attest from simulator signatures, so the signed entitlement
   is checked after archiving. Any config, auth allowlist, or build-number change happens before
   this final run.
4. **Create a signed device archive.** In Xcode select the `Wardrobe` scheme and a generic physical
   iOS device, then choose **Product → Archive**. The archive must pass the strict public Release
   post-build check without bypasses. Before validation or upload, run
   `ios/scripts/verify-release-artifact.sh DerivedData/ReleaseValidation
   "/path/to/Wardrobe.xcarchive/Products/Applications/Wardrobe.app"`; this pass must confirm the
   signed production App Attest entitlement and absence of the shared bearer.
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
   reminders/background work, Settings/privacy, sign out, disconnect, deletion, account switching,
   offline/relaunch, backend failure, and reinstall creating a new anonymous installation. Verify
   local/demo behavior remains available when secure remote AI is unavailable.
9. **Retire the bridge.** If a legacy compatibility bridge was used, switch the validated backend
   to App-Attest-only mode, unset/rotate `DEVICE_TOKEN`, and prove an old build is rejected while
   the candidate still succeeds. A rollback must use a retained App-Attest-only image and preserve
   the auth store; rolling back to the shared bearer is not an acceptable recovery plan.
10. **Record evidence.** Retain the commit, archive, build/version, Xcode and SDK, test results,
   validation/upload logs, processed-build metadata, backend image/config, exact App ID prefix,
   entitlement/profile, tester OS/runtime-field presence, category/build values when supplied,
   auth-store volume and backup/restore evidence, Apple-receipt validation/risk-metric policy,
   bridge retirement, old-build rejection, and physical-device QA. Do not claim build/category
   rejection on iOS 18–26, where Apple omits those fields; the pre-App-Attest shared-token build
   must still be rejected.

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
