# Singapore submission preparation — 12 September 2026

Status: **approved Apple draft work in progress; not submitted or publicly released**. Build
`1.0.0 (7)` remains the existing processed candidate. The owner approved source publication,
saving the prepared Apple draft and the minimal App Store compatibility deployment. The later
contact correction retains that scope; private approval/amendment records bind the corrected
package. Documentation, store assets, backward-compatible backend configuration and the local
preflight correction need **no new TestFlight build**.

## Confirmed account and draft state

App Store Connect inspection and approved draft saves confirmed:

- Existing bundle ID and immutable SKU: `com.tth.Wardrobe`; Apple ID `6789053566`.
- Primary language English (U.K.); store draft is now `1.0.0`, Prepare for Submission.
- Free/Paid agreements active; bank and tax records active/complete; DSA trader status active.
- Singapore is the sole available territory; 174 territories are not available.
- Tax category is App Store software; Apple Standard License Agreement is selected.
- Listing text, subtitle, Lifestyle category, URLs, copyright and reviewer notes are saved.
- Existing build 7 is selected. No sign-in is required; manual release is saved.
- Age rating is 9+ from the lifestyle-content questionnaire, with medical content None. Content
  rights is Yes on the owner's explicit assurance. No accessibility capability was asserted.
- The corrected owner-confirmed review contact is saved and reload-verified privately.
- Five fictional screenshots are uploaded in Catalog/editor/detail/Today/History order and
  reload-verified. The smaller 6.5-inch slot automatically uses the 6.9-inch images.
- Free pricing and disabling the default Mac/Vision availability remain to be applied/verified.

Personal contact/account information remains in ignored private evidence. Existing agreements
were retained; no new agreement was accepted. Draft saves and asset uploads do not submit or
publish the app.

## Reviewable materials

- [Saved listing copy and remaining settings](metadata-draft.md).
- [Concise reviewer instructions](review-notes-1.0.0.txt), including the real two-item minimum
  and Settings → Connected Features consent path. There is no review-fixture import feature.
- Five screenshots: Catalog, item editor, item detail, Today and History. The optional sixth
  settings frame is omitted to avoid confusing Demo-only availability with the real app.
- Private package: `.fly/app-store-submission-20260912/`, including original screenshots,
  opaque upload JPEGs, SHA-256 manifest, contact proposal and a local HTML preview.

A Release simulator build from `cdb4b0a22f9c5ef4560be3123a3dcc46e3d3d895` passed compilation and
`verify-release-artifact.sh`. It retains version/build `1.0.0 (7)` and uses the same Release UI
paths as the delivered candidate; later Today/app-shell harness additions are DEBUG-only. This
simulator build is not the signed Apple archive. Capture used iPhone 17 Pro Max / iOS 26.5,
Light appearance, default English system formatting and a 9:41 status bar. All five 1320 × 2868
JPEGs were inspected; they retain native scroll-edge clipping/truncated item labels and have no
alpha, personal data, error state or added framing. Original PNGs remain available.

The screenshot-only preparation passed the Release compilation/artifact check and metadata
character/keyword-byte validation. The subsequent backend compatibility/preflight change passed
870 backend tests, locked pip-audit, Bandit, Ruff and mypy, 237 iOS tests and all 44 release-script
tests. No shipped iOS source or API contract changed.

## Backend source and configuration preparation

`backend/fly.toml` now proposes categories `2,4`, retaining builds `4,5,6,7`. The live runtime is
still Fly v13/category `2`; no compatibility deployment has occurred at this checkpoint.

`fly.toml` is deployment configuration and is not copied into the Docker image. The read-only
operations verifier therefore excludes it from immutable-image source equivalence while keeping
all image/runtime-contract inputs protected. Configuration is independently checked against exact
local, live-app and Machine values. A strict local section/app/region guard rejects unreviewed
deployment additions. Regressions prove protected source changes and category mismatches across
local/live/Machine/private review records still fail. Keep the actual deployed image source
revision unchanged when updating the post-deployment release/category review lock.

## Remaining execution

1. Finish the already approved draft work: apply and verify Free pricing and iPhone-only
   availability, then reload the final draft. Retain the verified screenshot order,
   saved build 7, declarations, corrected review contact and manual release.
2. Add App Store category `4` alongside TestFlight category `2` in the production App Attest
   allowlist. The proposed value is `2,4`; accepted builds remain `4,5,6,7`. Preserve the exact
   runtime image, Machine, volume, key, approved policy and intact budget ledger. This is a
   backward-compatible configuration change; no iOS rebuild or additional paid test is proposed.
   The live configuration still accepts only category `2`; do not claim App Store support live.
3. Before applying that configuration, follow the normal reviewed-source/configuration process.
   Afterwards verify the exact serving settings, health, storage, budget and payload-free
   operations review. Keep the existing cost envelope and daily review; Fly has no hard invoice
   cap. A failed check stops submission and uses the applicable approved recovery procedure.
4. Resolve Apple's actual validation errors, then obtain the final public-submission approval
   if not already explicitly granted for the reviewed final package. Submit to App Review with
   **manual release** selected. Apple approval does not itself publish the app under that setting.

The completed local QA, privacy publication, bounded AI activation and first protected call are
retained; do not repeat handoff/deletion or routine manual regression. The existing narrowly scoped
snapshot/recovery waiver remains accepted risk, not new deletion/purge proof.
