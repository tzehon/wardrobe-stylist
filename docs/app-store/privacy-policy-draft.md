# Wardrobe Stylist privacy policy — publication draft

> **Do not publish yet.** Replace every bracketed value, confirm the production Anthropic/backend
> terms and Google verification outcome, and reconcile this text with the final request-capture
> tests and App Privacy answers before setting an effective date.

**Effective date:** [DATE]  
**Developer:** [LEGAL NAME OR ENTITY]  
**Privacy contact:** [PRIVACY EMAIL]  
**Product website:** [HTTPS HOMEPAGE]

Wardrobe Stylist helps you build a wardrobe catalog and get outfit suggestions. You can add items
manually or from photos without connecting Google. If you choose to connect Gmail, the app uses
read-only access to look for purchase receipts. Gmail connection, AI processing, background
receipt import, and reminders are optional.

## Information the app handles

### Information stored on your device

The app stores wardrobe item details, photos you choose or capture, purchase details you approve,
outfit recommendations cached for use, wear history, feature preferences, consent records, and
sync state on your device. [CONFIRM WHETHER ICLOUD/BACKUP EXCLUSION OR INCLUSION APPLIES.]

### Google and Gmail information

If you connect Gmail, the app requests only the
`https://www.googleapis.com/auth/gmail.readonly` scope. This allows the app to read Gmail but not
send, modify, label, trash, or delete messages. On-device code searches for likely purchase
receipts and extracts deterministic structured fields where possible.

For a receipt that needs cloud analysis, the app sends our backend a validated sender domain, a
sanitized subject, and either bounded structured product fields or selected, redacted product
lines. The current compatibility envelope also sends a Gmail message identifier to our backend
for response correlation; the backend removes that identifier before sending the minimized
product context to Anthropic. Full sender addresses and raw message bodies are not sent to
Anthropic. [VERIFY FINAL REQUEST CAPTURE, BACKEND LOGGING, AND PROVIDER FIELDS BEFORE PUBLICATION.]

### Wardrobe information used for AI styling

If you consent to AI styling, the app may send compact wardrobe attributes—such as internal item
ID, name, category, brand, colors and material—plus recent-wear identifiers, bounded per-item
rating summaries (item ID, average 1–5 rating and rating count), and an occasion you provide to
our backend and Anthropic. Rating free text, wear dates, wardrobe photos, and purchase metadata
are not included in styling requests unless this policy and the in-app disclosure are updated and
you consent.

### Technical information

The backend necessarily receives network information such as IP address and request timing while
servicing a request. The developer auth database stores only keyed HMAC rate-limit subjects, not
raw IP addresses. Application security events are designed to omit IP addresses, installation and
key identifiers, credentials, request content, and model content.

[BEFORE PUBLICATION: VERIFY THE FINAL DEPLOYED IMAGE HAS APPLICATION ACCESS LOGS DISABLED; VERIFY
FLY EDGE FIELDS AND THE APPROVED 24-HOUR RAW-IP LIMIT; VERIFY SEVEN-DAY SANITIZED-LOG RETENTION,
ALERT ROUTING, HOSTING REGION, CRASH/ANALYTICS TOOLS, AND LINKAGE. SEE
`app-attest-data-lifecycle-policy.md`.]

## How information is used

We use information only to provide user-facing features you request: importing wardrobe items
from receipts, generating outfit suggestions, preventing excessive repeats, securing and
operating the service, diagnosing failures, and complying with law. We do not use Gmail data for
advertising, data brokerage, credit or lending decisions, or building advertising profiles.

We adhere to the Google API Services User Data Policy, including its Limited Use requirements.
[KEEP THIS STATEMENT ONLY AFTER THE FINAL PROCESSOR/AI ARCHITECTURE IS ACCEPTED BY GOOGLE.]

## Processing providers and disclosures

- **Google:** authentication and read-only Gmail API access when you connect Gmail.
- **[BACKEND HOST, CURRENTLY FLY.IO]:** runs the developer-controlled API that authenticates the
  app, minimizes/validates requests, and coordinates AI processing.
- **Anthropic:** processes receipt or wardrobe payloads to return structured items and outfit
  suggestions when you explicitly use an AI feature.
- **Apple:** provides the operating system, notifications, optional platform backup behavior, and
  App Store distribution.

[ADD EVERY PRODUCTION PROCESSOR AND LINK ITS POLICY. CONFIRM CONTRACTUAL RETENTION, TRAINING,
HUMAN ACCESS, REGION, SUBPROCESSORS, AND DELETION BEFORE CLAIMING SPECIFIC PRACTICES.]

## Retention

Wardrobe data remains on your device until you delete it or remove the app, subject to any device
backup you control. Our developer application does not persist receipt text or wardrobe payloads
after the request completes. We retain only the minimum server-side authentication, security, and
abuse-prevention records required to operate the public service.

[BEFORE PUBLICATION: DEPLOY AND EVIDENCE THE REPOSITORY-ENFORCED SCHEDULE. CHALLENGES: 70 MINUTES
MAXIMUM FROM ISSUE; SESSION HASHES: 20 MINUTES; RATE HASHES: WINDOW PLUS 5 MINUTES; ACTIVE
INSTALLATIONS AND OPAQUE APPLE RECEIPTS: 90 DAYS AFTER LAST SUCCESSFUL USE; REVOKED INSTALLATIONS:
30 DAYS; VERIFIED LIVE DELETION: 24 HOURS; ENCRYPTED SNAPSHOTS: 14 DAYS; SANITIZED SECURITY LOGS:
7 DAYS; ALERT RECORDS: 30 DAYS. VERIFY ANTHROPIC/PROCESSOR RETENTION SEPARATELY.]

## Your choices and controls

In the app you can use a local wardrobe without Gmail, decline or withdraw receipt-analysis and
styling consent, disable background import and reminders, sign out, disconnect/revoke Gmail, and
delete local wardrobe data. You can separately use **Settings → Privacy & Data → Delete
Server Security Data** to prove control with App Attest and remove this installation's live
anonymous authentication record and sessions. That server action does not delete the wardrobe or
disconnect Google; future remote-AI use enrolls a new anonymous identity. Disconnecting Gmail stops
future Gmail access but does not delete mail or modify your Google account. Deleting the local
wardrobe does not delete Gmail messages.

You can also review or revoke Google access at
[Google Account third-party connections](https://myaccount.google.com/connections).

For access, correction, deletion, or privacy questions about any server-side information, contact
[PRIVACY EMAIL]. [BEFORE PUBLICATION: VERIFY THE IN-APP ASSERTION-VERIFIED SERVER-DELETION FLOW ON
THE FINAL TESTFLIGHT BUILD, PUBLISH THE MONITORED CONTACT, AND ADD APPLICABLE
JURISDICTION-SPECIFIC RIGHTS AND RESPONSE PROCESS.]

## Security

We use HTTPS in transit, platform-provided credential storage, least-privilege read-only Gmail
scope, schema validation, anonymous per-installation App Attest backend authorization, rate
limits, dependency review, and automated tests intended to prevent Gmail write capability and
unauthorized data transmission.
[REMOVE ANY CONTROL NOT VERIFIED IN THE FINAL PRODUCTION DEPLOYMENT.]

No method of storage or transmission is completely secure. Contact [SECURITY EMAIL] if you
believe you found a security issue.

## Children

Wardrobe Stylist is not directed to children under [APPLICABLE AGE]. [RECONCILE WITH FINAL APP
STORE AGE RATING AND TARGET MARKETS.]

## International transfers

[DESCRIBE THE DEVELOPER, HOSTING AND ANTHROPIC LOCATIONS, TRANSFER MECHANISM, AND TARGET MARKETS.]

## Changes to this policy

We will update this policy when data practices or providers change and show the effective date.
When a material change affects an optional AI data flow, the app will require consent to the new
notice before that flow resumes.

## Contact

[LEGAL NAME OR ENTITY]  
[POSTAL ADDRESS IF REQUIRED]  
[PRIVACY EMAIL]  
[SUPPORT URL]
