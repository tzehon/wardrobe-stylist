# Singapore submission preparation — 12 September 2026

Status: **prepared locally; not submitted or published**. Build `1.0.0 (7)` remains the existing
processed candidate. This preparation changes documentation and screenshot assets only and needs
**no new TestFlight build**.

## Confirmed account and draft state

Read-only App Store Connect inspection confirmed:

- Existing bundle ID and immutable SKU: `com.tth.Wardrobe`; Apple ID `6789053566`.
- Primary language English (U.K.); store draft labelled `1.0`, Prepare for Submission.
- Free/Paid agreements active; bank and tax records active/complete; DSA trader status active.
- Singapore is the sole available territory; 174 territories are not available.
- Tax category is App Store software; Apple Standard License Agreement is selected.
- Price schedule, subtitle, categories, age rating, content rights, screenshots, description,
  review contact/notes and selected build remain incomplete.
- Sign-in required, automatic release and Mac/Vision availability are selected by default.
  The prepared proposal changes those settings to no sign-in, manual release and iPhone-only.

Personal contact/account information remains in ignored private evidence. No agreement was
accepted, account setting changed, store metadata saved, asset uploaded or app submitted during
this preparation.

## Reviewable materials

- [Listing copy and proposed settings](metadata-draft.md).
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

No application source changed. Full regression is not rerun for documentation/assets only;
previous code verification remains in the runbook. The Release compilation/artifact check and
metadata character/keyword-byte limits passed for this preparation.

## Remaining execution

1. Obtain owner approval of the concrete listing, screenshots, copyright/review contact and
   store settings, plus the configuration change below. Complete age/content-rights declarations
   accurately against the submitted app; save and reload the draft, attach existing build 7 and
   preview Apple's scaled media. Do not assert unsupported accessibility capabilities.
2. Add App Store category `4` alongside TestFlight category `2` in the production App Attest
   allowlist. The proposed value is `2,4`; accepted builds remain `4,5,6,7`. Preserve the exact
   runtime image, Machine, volume, key, approved policy and intact budget ledger. This is a
   backward-compatible configuration change; no iOS rebuild or additional paid test is proposed.
   Current configuration still accepts only category `2`; do not claim App Store support live.
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
