# Wardrobe Stylist support page — publication source

> Source for the Gmail-free candidate's next public-page revision. Reconcile all Settings labels
> with the exact submitted build before republishing at `https://blog.tth.dev/wardrobe/`.

## Get help

- Contact: `contact@tth.dev`
- Expected response time: within two business days
- Initial App Store availability: Singapore
- App version/build: available at the bottom of Wardrobe Stylist → Settings

When reporting a problem, include the app version, iOS version, device model, what you expected,
and what happened. Do not email backend credentials, App Attest material, or private wardrobe
photos.

## Common questions

### Do I need an account?

No. Manual and photo cataloging, browse/edit/history, local reminders, and Demo Mode work without
an account.

### What information is sent for AI styling?

Only when you request a suggestion and consent, the app may send compact text attributes for
catalog items, recent-wear item IDs, bounded rating summaries, and an occasion you provide to the
developer backend and Anthropic. Public v1 does not send wardrobe photos, purchase metadata, wear
dates, or rating free text for styling. The developer application does not persist the wardrobe,
prompt, or model-response payload after request processing.

### Can I use the app if AI styling is unavailable?

Yes. Manual/photo cataloging, browse/edit/history, local reminders, and offline Demo Mode stay
available. Remote AI fails closed if App Attest, the network, or the backend is unavailable; the
app does not create an unauthenticated fallback session.

### How do I stop reminders?

Open **Settings → Connected Features** and turn reminders off. Reminders are local notifications
and can also be controlled in iOS Settings. No outfit is generated in the background.

### How do I delete my local wardrobe?

Open **Settings → Privacy & Data → Delete Local Data**. This removes local items, photos, outfits,
wear history, cached suggestions, and related choices from this device. It does not delete the
separate anonymous server-security record; use the control below for that record.

### How do I delete server security data?

Wardrobe Stylist does not create a human account. Its server-security record belongs to one
anonymous App Attest installation and is separate from the wardrobe stored on the iPhone.

Before uninstalling, open **Settings → Privacy & Data → Delete Server Security Data**. The app uses
a fresh App Attest proof to delete that installation's live server identity and active AI
sessions. This action does not delete the local wardrobe. Remote AI creates a new anonymous
identity the next time you use it.

Reinstalling creates a new identity but does not prove the old record was deleted. If the original
installation is unavailable, email `contact@tth.dev` for general guidance. Support cannot safely
identify an unlinked anonymous record and will never ask for a token, key, attestation object, or
wardrobe photo. The server's inactivity policy removes an unused live installation after 90 days.
Hosting logs and encrypted snapshots are separate from the live server identity, are not removed
immediately by the in-app action, and follow the retention described in the privacy policy.

## Privacy and terms

- Privacy policy: `https://blog.tth.dev/wardrobe/privacy/`
- Terms of Service: `https://blog.tth.dev/wardrobe/terms/`
- Security contact: `contact@tth.dev`
