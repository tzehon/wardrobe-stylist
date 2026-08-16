# Recommended production sequence — Google Cloud OAuth and Gmail

This is intentionally deferred until the app-side readiness branch is complete. The current
single-user TestFlight configuration is not suitable for a generally available App Store app:
`gmail.readonly` is a **restricted** scope, receipt data crosses a developer-controlled backend,
and a public iOS client cannot safely hold the backend's shared bearer token.

Do these steps in order. Do not flip the existing project to production first and try to make the
code match afterward.

The next internal TestFlight build also follows the public-candidate standard in
[`app-store/internal-testflight-runbook.md`](app-store/internal-testflight-runbook.md). Internal
describes the tester group only; it does not authorize a shared bearer, placeholder release
configuration, or Apple's non-promotable **TestFlight Internal Only** artifact type.

## 1. Decide the permitted data-processing architecture

- [ ] Ask Google's verification team to classify the truthful use case: read-only receipt
  discovery that builds a user-visible wardrobe, analogous to user-benefiting email reporting or
  package/itinerary extraction. Approval is not guaranteed.
- [ ] Obtain a written position on whether ephemeral inference through the chosen Anthropic API
  configuration satisfies Workspace Limited Use. Confirm retention, training/model-improvement,
  human access, subprocessors, region, deletion, and contract terms. A CASA assessment does not
  cure a separate Limited Use problem.
- [ ] Choose one architecture:
  1. **Recommended privacy path:** on-device extraction/styling where feasible. Restricted-scope
     verification remains, but transmitting restricted Gmail data through a third-party server
     is removed.
  2. **Cloud-AI path:** user-directed, explicitly consented processing via the developer backend
     and Anthropic, only if Google accepts it. Plan restricted-scope verification plus an annual
     Google-approved security assessment/CASA.
- [ ] Freeze the precise data inventory and minimization rules that the code, consent text,
  privacy policy, verification justification, and demo will all describe.

**Exit:** written architecture decision, provider terms, data-flow diagram, and accepted wording.

## 2. Create a separate production Google Cloud project

- [ ] Keep development/testing credentials isolated; create a production project owned by a
  durable organization/account rather than repurposing the personal test project.
- [ ] Add at least two appropriate owners/admin recovery paths, current developer/security
  contacts, billing/budget alerts where needed, and least-privilege IAM.
- [ ] Enable the Gmail API only; review all other enabled APIs and service accounts.
- [ ] Set the OAuth audience to **External**. Use Testing only during configuration, then publish
  **In production** for the public rollout. Test-user or “personal use” exemptions are not a
  distribution strategy.

**Exit:** production project inventory and ownership/security review recorded.

## 3. Establish the public identity and verified domain

- [ ] Finalize app name, bundle ID, organization/developer name, icon/logo, and support contact.
  Keep them identical across the binary, OAuth screen, website, privacy policy, and App Store.
- [ ] Publish a real homepage, privacy policy, and support page on a stable HTTPS domain the
  developer controls. The homepage must explain the product; the policy must cover Google data,
  Limited Use, backend/Anthropic processing, retention, withdrawal, revocation, and deletion.
- [ ] Verify the owned domain in Google Search Console using an eligible account, then add only
  the required authorized domains to the OAuth brand configuration.

**Exit:** every public URL is live, crawlable, same-domain, accurate, and domain-verified.

## 4. Configure the production OAuth consent screen

- [ ] Add the final app name/logo, homepage, privacy-policy URL, terms URL if used, user-support
  email, and current developer contacts.
- [ ] Declare exactly one Google Workspace scope:
  `https://www.googleapis.com/auth/gmail.readonly`.
- [ ] Keep all consent-screen copy in English for the verification recording, with accurate
  product terminology and no claims broader/narrower than runtime behavior.
- [ ] Explain why narrower Gmail scopes cannot find and read arbitrary historical receipt bodies,
  and why each data element is necessary for the visible feature.

**Exit:** consent configuration matches the production binary and published policy verbatim.

## 5. Create production OAuth clients and backend identity audiences

- [ ] Create the production iOS client for the final bundle ID. Add the Apple Team ID and App
  Store ID when available; configure the exact reversed-client-ID URL scheme.
- [ ] Create the appropriate server/web OAuth audience only if the chosen per-user backend
  authorization flow needs it. Do not place a client secret in the iOS app.
- [ ] Implement the deferred `APP-009` cutover: obtain a refreshed per-user identity assertion,
  verify signature/issuer/expiry/audience and stable `sub` at the backend, issue a short-lived app
  session if useful, rate-limit by identity, and monitor abuse. App Attest can add defense in
  depth; it does not turn a shared client token into a secret.
- [ ] During backend rollout the service may accept both mechanisms briefly. Before the next
  always-ready internal TestFlight candidate, remove `BackendDeviceToken` from the app/archive,
  disable and rotate the legacy backend token, and retire incompatible old builds with an
  explicit minimum-version plan. Do not upload a deliberately weaker beta binary.
- [ ] Upgrade and pin Google Sign In, validate App Check/App Attest decisions, and test fresh,
  restored, expired, revoked, account-switch, offline, and denied-scope states.

**Exit:** a Release archive contains no shared secret and backend authorization is per-user,
short-lived, validated, rate-limited, and covered by negative tests.

## 6. Finish in-app disclosure, controls, and evidence

- [ ] Ensure the versioned disclosure appears immediately before affirmative authorization and
  explains: Gmail is read-only; selection occurs on device; exact fields transmitted; developer
  backend and Anthropic; styling catalog fields; retention; background behavior; and how to
  withdraw/revoke/delete. A privacy-policy link alone is insufficient.
- [ ] Provide distinct Sign out, Disconnect/revoke, Withdraw consent, background opt-out, and
  Delete Local Data actions. Explain Google account permission management in Help.
- [ ] Demonstrate that no Gmail/backend request occurs without current consent, background opt-in,
  and active account scope. Capture automated request-body minimization tests as review evidence.
- [ ] Add a Limited Use adherence statement and ensure every processor/contractor is bound to the
  same permitted-use and human-access constraints.

**Exit:** policy, UI, code, automated tests, and reviewer script tell the same story.

## 7. Submit restricted-scope verification

- [ ] Publish the OAuth app **In production**, then submit brand/domain and restricted-scope
  verification from the production project.
- [ ] Provide a detailed `gmail.readonly` justification, architecture/data-flow explanation,
  exact retention/deletion controls, processor list, and answers about Limited Use.
- [ ] Record an unlisted demo video showing the English OAuth consent screen and the complete
  feature enabled by the scope: disclosure → grant → on-device filtering → minimized extraction →
  review/correction → disconnect/delete. Ensure project/client IDs visible in evidence match.
- [ ] Respond to verification questions without changing scopes, project identity, or runtime
  behavior mid-review. If Google rejects the app category or cloud-AI interpretation, return to
  Step 1; do not workaround the review.

**Exit:** brand and restricted-scope verification approved for the production project.

## 8. Complete the security assessment/CASA if assigned

- [ ] Because restricted Gmail data is transmitted through the backend, expect Google to require
  a Google-approved annual security assessment. Google assigns the assurance level/tier; do not
  assume AL1/AL2 or cost from the repository.
- [ ] Supply architecture, asset inventory, IAM, SDLC/dependency evidence, encryption, logs,
  incident response, deletion, vendor controls, vulnerability results, and remediation evidence.
- [ ] Remediate findings, receive the Letter of Validation, submit it to Google, and calendar
  annual reassessment/reverification deadlines.

**Exit:** Google accepts the assessment and all findings are closed.

## 9. Production rollout and continuing compliance

- [ ] Deploy the verified backend/config first, then upload a production-client build through
  Xcode's **TestFlight & App Store** route and add it only to the internal tester group.
  Exercise real-device sign-in, scope restoration, consent upgrade, account switch, revocation,
  deletion, rate limits, background opt-in/expiry, and minimized request capture.
- [ ] Roll out gradually with error/auth/abuse monitoring and cost alerts. Keep privacy/support
  pages and contacts live.
- [ ] Submit the same verified binary/data flow to App Review with a demo path and precise review
  notes. Re-open Google and Apple disclosures before any new Gmail scope, data category,
  processor, AI use, retention change, or account-linking feature.
- [ ] Track annual OAuth reverification/CASA, dependency updates, incident exercises, and domain/
  contact ownership.

## Current console observations to correct later

The inspected development project was External but still in Testing, with two test users and a
100-user cap. It had no logo/homepage/privacy/terms URLs or authorized domain; the iOS client had
the correct `com.tth.Wardrobe` bundle ID but no Team ID/App Store ID, and App Check was off. The
project also showed no billing account, a stale contact warning, and weak ownership redundancy.
These are observations from the development console, not instructions to mutate it in place.

## Official Google references

- [Gmail API scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
- [Restricted-scope production readiness](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)
- [OAuth production policy compliance](https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance)
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)
- [Google Workspace API User Data and Developer Policy](https://developers.google.com/workspace/workspace-api-user-data-developer-policy)
- [Restricted-scope verification FAQ](https://support.google.com/cloud/answer/13463817)
- [Security assessment requirements](https://support.google.com/cloud/answer/13465431)
- [Verification submission guide](https://support.google.com/cloud/answer/13461325)
