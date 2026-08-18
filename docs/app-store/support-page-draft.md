# Wardrobe Stylist support page — publication draft

> Replace bracketed values and publish on the same stable HTTPS domain as the product homepage and
> privacy policy. The in-app Help screen should expose the same information.

## Get help

Contact: [SUPPORT EMAIL OR FORM]  
Expected response time: [BUSINESS-DAY TARGET]  
App version/build: available at the bottom of Wardrobe Stylist → Settings

When reporting a problem, include the app version, iOS version, device model, what you expected,
and what happened. Do not email receipt contents, OAuth tokens, backend credentials, or private
wardrobe photos.

## Common questions

### Do I need Gmail?

No. Manual/photo wardrobe features work locally without Google. Gmail is an optional read-only
receipt importer.

### Can Wardrobe Stylist modify my email?

No. It requests only Gmail's `gmail.readonly` scope and contains no Gmail write endpoint.

### Why does the app ask about AI processing?

Receipt extraction and outfit recommendations can send minimized data to the developer backend
and Anthropic. The app asks separately before each type of AI processing and keeps those features
off until you consent.

### What is the difference between Sign out and Disconnect Gmail?

Sign out ends the local session. Disconnect revokes Wardrobe Stylist's Google authorization so it
cannot access Gmail again unless you reconnect. Neither action changes or deletes Gmail messages.

### How do I stop background receipt import or reminders?

Open **Settings → Connected Features** and turn the corresponding control off. Background import
is opportunistic—iOS does not guarantee an exact schedule. Reminders are local notifications and
can also be controlled in iOS Settings.

### How do I delete my wardrobe?

Open **Settings → Privacy & Data → Delete Local Data**. This removes local items, photos, outfits,
wear history, receipt sync history, cached images, recommendations, and related choices from this
device. It does not delete email or revoke Google access. Use **Settings → Connected Features →
Disconnect Google** separately when you also want to revoke the grant.

### How do I delete server authentication data?

Wardrobe Stylist has no developer account and does not use your Google identity for backend access.
Its server authentication record belongs to one anonymous App Attest installation and is separate
from the wardrobe stored on your iPhone.

Before uninstalling, open **Settings → Privacy & Data → Delete Server Security Data**. The
app obtains a fresh App Attest proof, deletes that installation's live server identity and active
AI sessions, then removes its local server-identity reference. It does not delete the wardrobe on
your iPhone or disconnect Google. Remote AI creates a new anonymous identity the next time you use
it. Verified live authentication records are removed synchronously. The approved policy requires
encrypted rolling snapshots to expire within 14 days; verify actual expiry before publication.

Reinstalling creates a new identity but does not itself prove that the old server record was
deleted. If the original installation is no longer available, contact [PRIVACY/SUPPORT CONTACT]
only for general guidance: support cannot safely identify an unlinked anonymous record. The
90-day inactivity purge is the fallback for a lost installation. Never send a token, key,
attestation object, Gmail content, or wardrobe photo to support.

### How do I revoke Google access outside the app?

Use [Google Account third-party connections](https://myaccount.google.com/connections), select
Wardrobe Stylist, and remove access.

### Why did a receipt import miss or mislabel an item?

Automated extraction can be wrong. Open the pending-import review queue to correct or accept an
item, or delete it instead. [RECONCILE WITH THE FINAL IMPORT-REVIEW LABELS BEFORE PUBLICATION.]

## Privacy and safety

- [Privacy policy]
- [Google data-use disclosure / Limited Use statement]
- [Delete-data instructions]
- [Security contact]
- [Service status page, if provided]
