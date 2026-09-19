# Business model response — 16 September 2026

Historical correspondence checkpoint. Apple subsequently issued a new **Guideline 4.3(a)**
rejection on 19 September; see the [current assessment](spam-rejection-20260919.md).

Status: **sent as reviewed on 16 September at 16:14 SGT**, after explicit owner approval.
At that checkpoint, Apple showed **Messages (4)** with the sent reply and the submission remained
**Rejected / Unresolved Issues** for **1.0.0 (7)**; no resubmission was performed in this step.
The message addressed by this response cited **Guideline 2.1(b) — Information Needed** and asked
four questions about paid digital features. Its review date was 15 September, and it appeared at
00:41 SGT on 16 September. It identified no crash or other functional defect.

## Sent reply

Thank you for reviewing Wardrobe Stylist. Version 1.0.0 (7) is completely free for users, including optional AI styling. Its Singapore App Store price is SGD 0.00. It has no paid features, subscriptions, in-app purchases or external feature purchases.

1. Who are the users that will use the paid features in the app?

There are no paid features or paying-user groups in this version. Individuals use it to catalogue their own clothing, request optional outfit suggestions and record wear history. All available functionality is provided without payment.

2. Where can users purchase the features that can be accessed in the app?

Nowhere. There is no purchase flow, checkout, external payment link or redemption code for app features. Users do not need a paid account, a Claude/Anthropic subscription or their own API key. The developer pays the backend hosting and Anthropic API costs; those are operating expenses, not purchases by app users.

3. What specific types of previously purchased features can a user access in the app?

None. The app does not import or recognise purchases, paid memberships or subscription entitlements from another app or website. The item editor's optional Purchase, Price, Currency and purchase-date fields simply let users record what they previously paid for physical clothing they already own. These fields do not process a transaction or unlock app functionality.

4. What paid content, subscriptions, or features are unlocked within the app that do not use In-App Purchase?

None. There is no paid content, subscription or paid feature unlocked by any method. “Allow AI styling” is permission to send the disclosed text data for a styling request, not a purchase or subscription. AI service limits are capacity and abuse controls for the free service; users cannot pay to bypass them.

Any freemium/subscription discussion in our project documentation describes a future, unimplemented release. It is not an offer or feature in version 1.0.0 (7). A future paid subscription would use Apple In-App Purchase and be submitted in a new version for review.

The physical-device walkthrough attached to our 13 September response demonstrates this same free build. Please let us know if there is a particular screen or behaviour that suggests a payment requirement so we can clarify it directly.

## Evidence and execution scope

- Live App Store Connect inspection on 16 September confirmed Singapore **SGD 0.00**, the saved
  description's Free/no-subscription/no-IAP statement, selected build 7 and manual release.
- [Current product model](../freemium-model.md) separates the Free v1 from planned freemium.
- `ios/Wardrobe/Capture/ItemDetailsForm.swift` and `ios/Wardrobe/Views/ItemDetailView.swift`
  implement optional clothing purchase metadata, not commerce or digital entitlements.
- Source inspection found no StoreKit, feature checkout or paid-entitlement implementation.
  Backend provider credentials remain server-held, and anonymous App Attest access is not a
  paid account. AI limits cannot be removed by user payment.

The owner requested an independent simulated App Store reviewer assessment, which found no
blocking issues. The owner then approved sending the existing wording as-is; the optional minor
wording suggestion was not applied. **Reply to App Review** sent the exact 2,327-character text
at 16:14 SGT, and the sent-message entry and increased message count verified delivery.

The next step at the 16 September checkpoint was to await Apple's assessment. The subsequent
[19 September rejection and sent clarification](spam-rejection-20260919.md) now govern follow-up.
Retain the existing 13 September walkthrough and saved reviewer instructions; this business-model
response required no replacement video or new binary. Public release remains manual and needs
separate owner approval.
The earlier expired session was restored before this send. No App Review Notes, listing,
build, pricing or release-setting change was made, and no new attachment was uploaded.

This checkpoint changed documentation and review correspondence only. **No new TestFlight
build was required.** No code, configuration or test input changed; the response was checked
against source and Apple settings without repeating the completed physical QA.
