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

Build a wardrobe you can actually use. Add pieces from photos or import clothing purchases from
Gmail with optional, read-only access. Browse and correct your catalog, then ask Aria for a
coordinated look that considers what you recently wore.

Wardrobe Stylist is local-first: manual and photo cataloging work without an account. Gmail import,
AI receipt processing, AI styling, background import and reminders are separate choices you can
control at any time.

Features planned for the public v1 cut:

- Manual and photo wardrobe catalog
- Optional read-only Gmail receipt import
- Review and correction of imported items
- Search, categories, sorting and item details
- Daily outfit suggestions with occasion context and anti-repeat history
- Clear privacy, consent, disconnect and deletion controls
- Offline sample/demo path for product review

## Promotional text candidate

Build your wardrobe locally, import purchases with optional read-only Gmail access, and ask Aria
for a thoughtful look when you need one.

## Keywords candidate

`closet,outfit,clothes,fashion,catalog,organizer,lookbook,wear,receipt,styling`

Recount the UTF-8 byte total after any localization or market-research changes. Do not add the
app name, category names, competitors, or other companies.

## URLs

- Marketing: [HTTPS HOMEPAGE]
- Support: [HTTPS SUPPORT PAGE]
- Privacy policy: [HTTPS PRIVACY POLICY]

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
3. **Review before it joins your wardrobe** — pending synthetic import and correction flow.
4. **A thoughtful look for today** — coordinated item strip and rationale.
5. **Remember what worked** — fictional worn-look history and wardrobe snapshot.
6. **Connected features stay optional** — concise privacy/settings view.

The detailed capture matrix, current Apple dimensions, safety checks, and evidence naming live in
[`screenshot-plan.md`](screenshot-plan.md).

Never show real Gmail content, email addresses, order numbers, receipts, wardrobe photos, tokens,
test credentials, debug banners or raw error messages.
