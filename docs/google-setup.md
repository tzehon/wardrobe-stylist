# Google / Gmail read-only OAuth setup

This app reads your Gmail **read-only** to find purchase receipts. This guide configures the
Google Cloud side. Because it's a **personal, single-user** app, you avoid Google's costly
restricted-scope security assessment (CASA) entirely.

## 1. Create a project + enable the Gmail API

1. Go to the [Google Cloud Console](https://console.cloud.google.com) and create a project
   (e.g. `wardrobe-stylist`).
2. **APIs & Services → Library →** enable the **Gmail API**.

## 2. OAuth consent screen

1. **APIs & Services → OAuth consent screen.**
2. User type: **External**. Fill in the app name and your email.
3. **Scopes:** add **only** `https://www.googleapis.com/auth/gmail.readonly`.
   - This is a *restricted* scope, but personal/single-user use does **not** require CASA
     verification. Do not add any broader or write-capable scope.
4. Add yourself under **Test users**.

### ⚠️ Avoid the 7-day refresh-token expiry

If the consent screen stays in **"Testing"** status, Google issues refresh tokens that
**expire after ~7 days**, forcing weekly re-login.

**Fix:** set the publishing status to **"In production"** and leave it **unverified**. For a
single user this is fine — you'll click through a "Google hasn't verified this app" screen
(Advanced → Go to app) once, and refresh tokens become long-lived. CASA is still not required
for personal use.

> If you already created credentials while in Testing, **generate new credentials** after
> switching to In production — the old ones keep the 7-day behavior.

## 3. Create an iOS OAuth client

1. **APIs & Services → Credentials → Create credentials → OAuth client ID.**
2. Application type: **iOS**.
3. Bundle ID: **`com.tth.Wardrobe`** (must match `PRODUCT_BUNDLE_IDENTIFIER` in
   [`ios/project.yml`](../ios/project.yml)).
4. Note the **client ID**. Its reversed form
   (`com.googleusercontent.apps.<client-id>`) becomes a URL scheme added to the app's
   Info.plist when Gmail sign-in is wired up in **Phase 1** (via the GoogleSignIn-iOS SDK).

## 4. What the app does with this

- Requests exactly `gmail.readonly` at sign-in
  ([`GmailScope`](../ios/Wardrobe/Gmail/GmailScope.swift)).
- Calls only read endpoints — `messages.list` (with `includeSpamTrash=true` to cover Spam &
  Trash; archived mail is included by default), `messages.get`, `attachments.get`,
  `history.list`, etc. — all via [`GmailReadEndpoint`](../ios/Wardrobe/Gmail/GmailReadEndpoint.swift).
- Stores OAuth tokens in the iOS **Keychain**, device-only.
- See [`privacy.md`](privacy.md) for how read-only is guaranteed and tested.

## Notes & limits

- **Permanently deleted** mail (purged from Trash) cannot be read — it's gone from Gmail.
- Quotas are generous for one user; the app uses `history.list` for cheap incremental syncs.
- Revoke access anytime at <https://myaccount.google.com/permissions>.
