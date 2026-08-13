# App Store screenshot plan

Use only fictional Demo Mode content. Never capture a real Gmail account, receipt, email address,
order identifier, personal wardrobe photo, OAuth token, backend host credential, or debug overlay.

Apple currently accepts one to ten screenshots per supported device size and localization in PNG
or JPEG format, without transparency. For iPhone, capture an accepted 6.9-inch portrait size for
the primary English set—for example `1320 × 2868`, `1290 × 2796`, or `1260 × 2736`—so App Store
Connect can scale it for smaller displays. Re-check the dimensions immediately before upload:
[Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

## Primary six-frame narrative

| Order | Store message | Screen and required state | Safety / QA check |
|---:|---|---|---|
| 1 | **Your wardrobe, without an account** | Demo Wardrobe, populated grid, fictional banner visible | No search keyboard, alert, or clipped cards |
| 2 | **Make every piece yours** | Fictional item edit/review form with useful details | No private photo; Save enabled only for valid data |
| 3 | **Review imports before they join** | Pending imported-item review using a synthetic receipt item | No real retailer order data or mailbox identity |
| 4 | **A thoughtful look for today** | Demo Today recommendation and rationale | Offline label visible; no loading/error state |
| 5 | **Remember what worked** | Demo History with a fictional worn look | Date/time locale is intentional and consistent |
| 6 | **Connected features stay optional** | Privacy & Data or Demo Settings controls | Clearly show local use and optional Google/AI choices |

The first three frames should communicate the core value even when seen alone. Prefer native app
UI with minimal, truthful framing text; do not imply weather, calendar, cloud backup, or other
features that are not in the submitted build.

## Capture procedure

1. Use the exact Release candidate and primary App Store language.
2. Reset Demo Mode before each sequence so names and ordering are deterministic.
3. Set a stable status bar, light/dark appearance choice, locale, text size, and 24-hour/12-hour
   convention; record those choices in the evidence manifest.
4. Capture on an accepted 6.9-inch simulator/device size, then inspect every image at 100%.
5. Verify no alpha channel, unintended rotation, modal residue, insertion cursor, or transient
   spinner appears.
6. Retain the unedited capture, final upload asset, source build number, commit, device, OS, and
   SHA-256 in the release evidence directory.
7. Upload in narrative order and preview the scaled product page before submission.

App previews are optional; Apple currently allows up to three per supported device size and
language. Do not create one until the six still frames are final, because an uploaded preview is
displayed before screenshots. See [Apple's media upload guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots).
