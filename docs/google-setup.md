# Google / Gmail read-only OAuth setup

This app reads your Gmail **read-only** to find purchase receipts. This guide configures the
Google Cloud side. Because it's a **personal, single-user** app, you avoid Google's costly
restricted-scope security assessment (CASA) entirely.

> Google reorganized this flow in late 2024 — the old "OAuth consent screen" page is now
> split across **Branding / Audience / Data access / Clients** under the new
> [Google Auth Platform](https://console.cloud.google.com/auth/overview). This guide follows
> the new UI.

## 1. Create a project + enable the Gmail API

1. Go to the [Google Cloud Console](https://console.cloud.google.com) and create a project
   (e.g. `wardrobe-stylist`). Make sure it's selected in the top-left project picker.
2. **APIs & Services → Library**, search for **Gmail API**, click it, then **Enable**.

## 2. Configure the OAuth consent flow (Google Auth Platform)

Open the [Google Auth Platform](https://console.cloud.google.com/auth/overview) (sidebar:
**APIs & Services → OAuth consent screen** redirects here). On the **Overview** page click
**Get started** if this is a fresh project — it walks you through the first four sections
below in one wizard. Otherwise edit each section directly:

### 2a. Branding
- **App name:** e.g. `Wardrobe Stylist`.
- **User support email:** your own email (it's just you).
- **Developer contact email:** same.
- Logo / homepage / privacy policy / TOS: leave blank — not required while unverified.

### 2b. Audience
- **User type:** **External** (Internal is Workspace-only).
- **Test users:** add your own Google account here so you can sign in while the app is in
  Testing.
- **Publishing status:** this is the critical setting — see §3 below.

### 2c. Data access (scopes)
- Click **Add or remove scopes**.
- In the filter box paste `https://www.googleapis.com/auth/gmail.readonly` and tick **only**
  that one row. It will appear under **Restricted scopes** — that's expected.
- **Do not add** any other Gmail scope. Anything with `modify`, `send`, `compose`,
  `insert`, `labels`, `settings.basic`, etc. is a write scope and violates this repo's
  read-only invariant (see [`CLAUDE.md`](../CLAUDE.md) and
  [`GmailScope.swift`](../ios/Wardrobe/Gmail/GmailScope.swift)).
- Save. The scope list on **Data access** should show exactly one entry: `gmail.readonly`.

### 2d. (Skip) Verification centre
Only relevant if you submit for verification. **You don't need to** — see §3.

## 3. (Optional) Publish to Production to avoid the 7-day refresh-token expiry

While **Audience → Publishing status** is **Testing**, Google issues refresh tokens that
**expire after ~7 days** — meaning you'll re-authenticate roughly weekly. Everything else
works fine in Testing; skip this section if weekly re-login is acceptable.

To get long-lived refresh tokens, on the **Audience** page click **Publish app** to move the
status to **In production**, and **leave it unverified**. Because it's a personal/single-user
app you'll:

- Click through a one-time **"Google hasn't verified this app"** warning at sign-in
  (Advanced → Go to Wardrobe Stylist (unsafe)).
- Get long-lived refresh tokens after that.
- Still **not** need to go through Google's CASA security assessment, which only applies if
  you make the app available to other users.

> If you already created an OAuth client while the app was in Testing, **delete it and
> create a new one** after switching to In production — refresh tokens minted under the
> old client keep the 7-day behavior.

## 4. Create the iOS OAuth client

1. **Google Auth Platform → Clients → Create client** (or **APIs & Services → Credentials →
   Create credentials → OAuth client ID** — same dialog).
2. **Application type:** **iOS**.
3. **Name:** anything, e.g. `Wardrobe iOS`.
4. **Bundle ID:** **`com.tth.Wardrobe`** — must match `PRODUCT_BUNDLE_IDENTIFIER` in
   [`ios/project.yml`](../ios/project.yml) exactly.
5. **App Store ID / Team ID:** leave blank (not required for sign-in to work).
6. Click **Create**. Copy the **Client ID** that's shown — it looks like
   `123456789012-abcdefg....apps.googleusercontent.com`.
7. The **reversed client ID** (`com.googleusercontent.apps.123456789012-abcdefg...`) is what
   gets added to the app's Info.plist as a URL scheme when Gmail sign-in is wired up in
   **Phase 1** (via the GoogleSignIn-iOS SDK).

## 5. What the app does with this

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
