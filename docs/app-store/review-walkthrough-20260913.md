# Apple review walkthrough — build 1.0.0 (7)

> **23 September:** Apple approval and owner-authorized manual release of build 7 completed
> after the full preflight passed. Singapore storefront propagation remains pending. See the
> [current launch record](launch-check-20260923.md). Do not repeat the completed transmission,
> submission or release actions below.

## Historical preparation and correspondence — through 19 September

**Current review state — 19 September:** Apple shows **Rejected / Unresolved Issues** under
Guideline 4.3(a). The owner-approved [clarification](spam-rejection-20260919.md) was sent at
15:46 SGT and verified in **Messages (6)**. Await Apple's clarification; no appeal or further
resubmission was performed. This does not reopen the completed walkthrough below.

The earlier [four-answer business-model response](business-model-response-20260916.md) was sent
unchanged at 16:14 SGT on 16 September and verified in Messages (4). It answered Apple's
Guideline 2.1(b) request dated 16 September at 00:41 SGT, with review date 15 September on
iPhone 17 Pro Max. Retain that [historical checkpoint](internal-testflight-runbook.md#business-model-information-request--16-september-2026).

**Completed:** after owner approval, the reviewed 89-second physical-device video and final
six-part reply were sent to Apple on 13 September at 11:55 SGT. Matching App Review Notes were
saved and reload-verified. The existing `1.0.0 (7)` was resubmitted at 11:56 SGT; Apple then showed the
submission and its sole item as **Waiting for Review**. Manual release was reverified and public
release remains separately unapproved. See the [response and resubmission checkpoint](internal-testflight-runbook.md#apple-information-response-and-resubmission--13-september-2026).

Apple's information request asked for app launch and the normal user flow on a physical device
running the latest OS. The supplied recording demonstrates those steps. No retake, reinstall,
reset, deletion or new TestFlight build is required. The reviewed recording and supporting
evidence remain private. The instructions below are retained for reference, not as open work.

## Recording guide — retained reference

Aim for about 3–5 minutes at a readable pace; Apple did not specify a duration or require
narration. Use the existing fictional test wardrobe and a clothing-only photo. Avoid personal
notifications, unrelated photos or private context text in the recording.

1. **Start at the Home Screen.** Use Control Center → Screen Recording, wait for the countdown,
   return Home, then tap Wardrobe. Keep the app launch in the final recording.
2. **Show the catalog.** Open Wardrobe, open an item and show its details. Add one clothing item
   using a clothing-only Camera/Photo Library image, enter a fictional name/category and save.
   The styling example should contain a top, trousers and shoes; existing fictional items are
   sufficient. Do not remove existing items merely to film.
3. **Show optional AI permission.** Open Settings → Connected Features and pause on the
   disclosure. If permission is already enabled, show that state; no need to withdraw it first.
   If off, read the disclosure and allow styling when ready to demonstrate it.
4. **Show one real styling result.** Open Today and tap Style a look, or use the refresh control
   if a look is already displayed. Let the request finish, then show the outfit and explanation.
   One successful request is sufficient; avoid repeated restyles just for filming. If a real
   error appears, stop and retain it for diagnosis rather than editing it into a success.
5. **Show wear history.** Tap Wear this, then History, and open the recorded look.
6. **Show controls and build.** Open Settings → Privacy & Data to show the separate local-data
   and server-security-data controls, without activating deletion. Show version/build in
   Settings. Stop the recording; it will be saved in Photos.

An additional short offline Demo tour is optional. Do not substitute Demo's bundled outfit
for evidence that the optional connected styling flow works.

No human registration/login, public posting/blocking/reporting, or paid-content flow exists in
v1. The written reviewer answers explain their absence. Private user-created wardrobe content
is still demonstrated by the add/edit flow above.

## Device and recording handoff

On 13 September the paired physical device reported iPhone 16 Pro with iOS **26.6.2**.
[Apple's security releases page](https://support.apple.com/en-us/100100) listed 26.6.2 as the
latest public iOS release at that check. Refresh the version check if filming after an update
is released. Do not identify a simulator capture as a physical-device recording.

[Apple's screen-recording instructions](https://support.apple.com/guide/iphone/take-a-screen-recording-iph52f6e1987/ios)
explain adding the control and saving to Photos. Apple states that screen recording and screen
mirroring cannot run together; end the Mac's iPhone Mirroring session before filming.

AirDrop the finished original video to this Mac, or otherwise save it locally, and provide its
path. Before sending it to Apple, inspect the complete recording for readability, app launch,
actual functionality, unintended private content and exact device/build claims. Keep the
video private to the review workflow; it is not an App Store marketing preview.

## Completed reply and Notes

The earlier pending-video draft was superseded by the final **3,943-character** response, within
the observed 4,000-character limit. Its six numbered answers identify the actual recording and
verified device, OS and app version/build. This final text was saved and reload-verified in App
Review Notes, then sent with the reviewed video before resubmission. The earlier unsent draft
is historical and must not replace the submitted response.

The approved reply and video remain bound to the private manifest. Keep the recording and its
content-review details out of public Git history. These canonical Notes remain the saved
13 September response; neither the separate 16 September business-model reply nor the
19 September similarity clarification replaced those Notes or the video. Await Apple's answer
to the 19 September clarification without replaying this completed recording procedure; no new
TestFlight build is indicated by that correspondence. Manual public release still requires
separate owner approval.
