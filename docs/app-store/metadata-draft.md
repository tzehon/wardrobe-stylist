# App Store metadata source — draft

## Identity

- Product name: **Wardrobe Stylist**
- Subtitle (30 characters max): **Catalog. Style. Wear more.** (candidate)
- Bundle ID: `com.tth.Wardrobe` — confirm before first public version
- SKU: `wardrobe-stylist-ios` (candidate; immutable after record creation)
- Primary category: **Lifestyle** (candidate)
- Secondary category: **Productivity** (candidate)
- Copyright: [YEAR LEGAL OWNER]
- Public version: **1.0.0**

## Description draft

Build a wardrobe you can actually use. Add pieces manually or from photos, browse and edit your
catalog, then ask Aria for a coordinated look that considers what you recently wore.

Wardrobe Stylist is local-first and requires no account. Cataloging, photos, outfit history, and
local reminders stay available without connected AI. Styling is optional and runs only when you
request it and consent to sending minimized text attributes.

Features planned for the public v1 cut:

- Manual and photo wardrobe catalog
- Search, categories, sorting and item details
- Daily outfit suggestions with occasion context and anti-repeat history
- Outfit history and local reminders
- Clear privacy, styling-consent and deletion controls
- Offline sample/demo path for product review

## Promotional text candidate

Build your wardrobe locally from manual entries and photos, then ask Aria for a thoughtful look
when you need one.

## Keywords candidate

`closet,outfit,clothes,fashion,catalog,organizer,lookbook,wear,styling,daily`

Recount the UTF-8 byte total after any localization or market-research changes. Do not add the
app name, category names, competitors, or other companies.

## URLs

- Marketing: `https://blog.tth.dev/wardrobe/`
- Support: `https://blog.tth.dev/wardrobe/`
- Privacy policy: `https://blog.tth.dev/wardrobe/privacy/`

## Required questionnaires and declarations

- [ ] App Privacy answers reconciled with `app-privacy-data-inventory.md`
- [ ] Updated age-rating questionnaire
- [ ] DSA trader/non-trader status; public trader contact if applicable in EU
- [ ] Content rights
- [ ] Export compliance (`ITSAppUsesNonExemptEncryption=false` only while system HTTPS/TLS is the
  sole cryptography)
- [ ] Advertising identifier/tracking declarations: expected no; verify archive and SDKs
- [ ] Accessibility Nutrition Labels only for capabilities manually verified in the final build
- [ ] Pricing, tax category, availability and agreements

## Screenshot narrative

Use fictional/demo data and current device specifications. Each frame should communicate one idea:

1. **Your wardrobe, without an account** — polished populated catalog.
2. **Make every piece yours** — full edit form with useful local details.
3. **Keep useful details close** — fictional item details and local organization.
4. **A thoughtful look for today** — coordinated item strip and rationale.
5. **Remember what worked** — fictional worn-look history and wardrobe snapshot.
6. **AI styling stays optional** — concise privacy/settings view.

The detailed capture matrix, current Apple dimensions, safety checks, and evidence naming live in
[`screenshot-plan.md`](screenshot-plan.md).

Never show a real person's wardrobe photos, email address, tokens, test credentials, backend
details, debug banners, or raw error messages.
