# Wardrobe Stylist privacy policy — publication source

> Source for the Gmail-free candidate's next public-page revision. Reconcile it with the exact
> submitted build, final request-capture tests, current linked provider terms, and App Privacy
> answers before republishing. The current live page still describes the earlier Gmail-capable
> build until this revision is deliberately published.

- **Effective date:** 20 August 2026
- **Developer:** Tan Tze Hon
- **Initial App Store availability:** Singapore
- **Privacy contact:** `contact@tth.dev`
- **Product/support website:** `https://blog.tth.dev/wardrobe/`
- **Terms:** `https://blog.tth.dev/wardrobe/terms/`

Wardrobe Stylist helps you build a wardrobe catalog and get outfit suggestions. You can add items
manually or from photos without an account. Cataloging, history, local reminders, and Demo Mode
work without connected AI.

## Information stored on your device

The app stores wardrobe item details, photos you choose or capture, purchase details you enter,
cached outfit suggestions, wear history, feature preferences, styling-consent records, and local
notification settings on your device. The developer does not operate cloud sync for this data.
Apple-managed device backups may retain or restore some app data according to your device and
backup settings.

## Wardrobe information used for optional AI styling

If you consent and request an outfit suggestion, the app may send compact wardrobe attributes—
such as an internal item ID, name, category, brand, colors, and material—plus recent-wear item IDs,
bounded per-item rating summaries, and an occasion you provide to the developer backend and
Anthropic.

Wardrobe photos, purchase date/price/currency, wear dates, rating free text, and other local files
are not included in public-v1 styling requests. The app does not send a styling request merely
because you open a tab.

## Technical and security information

Remote AI is authorized by Apple App Attest rather than a human login. Anonymous App Attest
security metadata can include key and challenge IDs, one-time challenge secrets, a verified public
key, an anonymous installation ID, assertion counter, App ID and environment, optional Apple-
signed validation-category and app-build values, an opaque Apple attestation receipt, session IDs
and one-way bearer-token hashes, and bounded rate-window scopes, counts, timestamps, and keyed HMAC
subject hashes. App Attest identifies one app installation and is recreated after reinstall,
migration, or restore. The private key remains in the Secure Enclave and raw bearer tokens are not
stored by the backend.

The backend necessarily receives network information such as IP address and request timing while
servicing a request. The developer authentication database stores keyed HMAC rate-limit subjects
rather than raw IP addresses. Application security events are designed to omit IP addresses,
installation/key identifiers, credentials, request content, and model content.

Fly.io has confirmed that its customer-visible proxy/platform error records can include paths,
request IDs, and sometimes client IP, and that separate provider operational or abuse-prevention
logs can contain source IP. The customer-visible stream lasts seven days and cannot be shortened
per app; separate provider-internal in-service retention is undisclosed and not customer-
configurable. These retained technical records support app functionality, network delivery, abuse
prevention, security, reliability, and diagnostics. They may be associated with an installation or
request and are not used by the developer for advertising or cross-company tracking.

## How information is used

The developer uses information only to provide features you request: storing local wardrobe
details, generating outfit suggestions, preventing excessive repeats, securing and operating the
service, diagnosing failures, and complying with law. The developer does not use wardrobe or
technical/security data for advertising, data brokerage, credit or lending decisions, advertising
profiles, or tracking across other companies' apps and websites.

## Processing providers

- **[Fly.io](https://fly.io/legal/privacy-policy/):** hosts the developer-controlled backend and
  encrypted authentication volume.
- **[Anthropic](https://www.anthropic.com/legal/privacy):** processes minimized wardrobe inputs to return outfit suggestions when you
  explicitly use AI styling.
- **[Apple](https://www.apple.com/legal/privacy/):** provides iOS, local notifications, optional device-backup behavior, App Attest, and
  App Store distribution.
- **[GitHub Pages](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement):** hosts the public support, privacy, and Terms pages and necessarily processes
  website-request network data when someone visits them.

These providers may process information outside Singapore under their linked privacy policies and
service terms. Do not infer stronger retention, model-improvement, human-access, subprocessor,
regional, or deletion guarantees than those verified for the production configuration.

## Retention

Local wardrobe data remains on the device until you delete it or remove the app, subject to Apple-
managed backup settings. The developer application does not persist wardrobe, prompt, or model-
response payloads after request processing. It retains only minimum authentication, security, and
abuse-prevention records required to operate remote AI.

The implemented live-store limits are:

- one-time challenges are valid for 5 minutes and purged no later than 70 minutes after issue;
- session-token hashes are valid for 15 minutes and purged no later than 20 minutes after issue;
- keyed rate-limit subjects are purged no later than the applicable window plus 5 minutes;
- active installation metadata is removed after 90 days without successful authenticated use;
- revoked installation metadata is removed after 30 days; and
- an App-Attest-verified deletion request synchronously removes that installation's live security
  record and sessions, within the policy's 24-hour maximum.

The authentication volume is encrypted and configured for rolling 14-day snapshots. Fly.io says a
snapshot then disappears from the customer listing but does not disclose all-copy purge timing.
Fly.io's customer-visible log stream lasts seven days; its separate provider operational/abuse-log
in-service retention is undisclosed and has no customer-enforceable hard maximum. Hosting records
are separate from the live server record and are not removed immediately by the in-app deletion
action.

## Your choices and controls

You can use the local wardrobe without remote AI, decline or withdraw styling consent, disable
local reminders, and delete local wardrobe data. You can separately use **Settings → Privacy &
Data → Delete Server Security Data** to prove installation control with App Attest and delete that
installation's live anonymous server record and sessions. That action does not delete the local
wardrobe; future remote-AI use enrolls a new anonymous identity.

For privacy, access, correction, deletion, or security questions, email `contact@tth.dev`. Never
send credentials, App Attest material, or private wardrobe photos.

## Security

Security measures include HTTPS in transit, platform credential storage, anonymous App Attest
backend authorization, schema validation, rate limits, dependency review, minimized request
fields, and automated regression checks. No method of storage or transmission is completely
secure.

## Children

Wardrobe Stylist is not directed to children.

## International processing

The app is initially offered in Singapore. The providers listed above may process data in other
locations under their linked terms and privacy policies.

## Changes

Material changes will be reflected by updating the effective date. When a material change affects
optional AI data processing, the app will require consent to the updated notice before that flow
resumes.

## Contact

- Tan Tze Hon
- `contact@tth.dev`
- `https://blog.tth.dev/wardrobe/`
