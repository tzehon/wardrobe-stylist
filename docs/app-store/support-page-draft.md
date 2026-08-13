# Wardrobe Stylist support page — publication draft

> Replace bracketed values and publish on the same stable HTTPS domain as the product homepage and
> privacy policy. The in-app Help screen should expose the same information.

## Get help

Contact: [SUPPORT EMAIL OR FORM]  
Expected response time: [BUSINESS-DAY TARGET]  
App version/build: available in Wardrobe Stylist → Settings → About

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

Open Settings and turn the corresponding control off. Background import is opportunistic—iOS does
not guarantee an exact schedule. Reminders are local notifications and can also be controlled in
iOS Settings.

### How do I delete my wardrobe?

Open Settings → Privacy & Data → Delete Local Wardrobe. This removes local items, photos, outfits,
wear history, sync state and cached recommendations. It does not delete email. [VERIFY FINAL UI
LABELS AND SERVER-SIDE SESSION DELETION BEFORE PUBLICATION.]

### How do I revoke Google access outside the app?

Use [Google Account third-party connections](https://myaccount.google.com/connections), select
Wardrobe Stylist, and remove access.

### Why did a receipt import miss or mislabel an item?

Automated extraction can be wrong. Open the import review queue to correct, merge, accept or delete
an item. [PUBLISH ONLY AFTER REVIEW UI SHIPS.]

## Privacy and safety

- [Privacy policy]
- [Google data-use disclosure / Limited Use statement]
- [Delete-data instructions]
- [Security contact]
- [Service status page, if provided]

