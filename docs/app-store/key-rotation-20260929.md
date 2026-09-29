# Production provider-key rotation — 29 September 2026

The owner authorized rotation in the post-launch work order and created the replacement
workspace-scoped key. Fly **v16** now serves that key using the unchanged v15 image and runtime
source `cb81d7c0e35fd36917bde0a4ab78c8bd456c257b`. Public `1.0.0 (7)` remains Free and
Singapore-only. No app build, model change, paid generation, resource expansion or ledger reset
was performed.

## Credential handoff and deployment

- The owner created the replacement in the existing production workspace, retaining workspace-only
  scope and no Admin API access. The owner selected an expiry shown in Console as **30 November
  2026**, superseding the prepared form's 30-day default. Rotate again before that date.
- Hidden terminal input passed the key only in process memory and subprocess stdin to the existing
  Fly application's secret vault. The agent did not persist or print the key. The private record
  retains only metadata and a verification hash; names, provider identifiers and private amounts
  remain outside this document.
- The replacement authenticated against the pinned model's read-only metadata endpoint before
  staging. This was not a Messages request or a paid outfit generation.
- Staging completed at `02:02:02Z`; only `ANTHROPIC_API_KEY` changed. All seven other secrets,
  including App Attest signing and the private AI policy, were preserved.
- `fly secrets deploy` completed at `02:03:31Z`. Fly independently reported v16 complete with
  the same immutable image, Machine, region, CPU/RAM, volume mounts and product configuration.
- The immediate postcheck stopped with OPEN evidence. Its precise transient failure was not
  retained. No deployment retry occurred. Independent read-only verification passed at
  `02:05:23Z`; do not describe the initial check as a pass.
- After the replacement passed, the old key was **disabled** in Console. It was not deleted.
  At `02:06:57Z`, another backend-side check confirmed the deployed replacement still
  authenticated and public health remained good after the old key was disabled.

## Verification

The runtime's replacement-key hash matched the privately staged value. Its authenticated
model-metadata request succeeded without exposing the credential. Public health, App Attest-only
configuration, auth-store schema/integrity/runtime guards, the approved public-capacity band,
volume utilization, fresh automatic 14-day snapshots and bounded event review passed.

AI remained enabled, below its warning band and idle. The separate ledger retained its month,
limits and concurrency policy; accounting counters did not decrease, and no active or uncertain
reservation was introduced by the rotation. Existing application and storage identities were
preserved. These checks do not prove an all-copy purge, provider-alert delivery or another
physical-device styling journey.

The operations lock now expects v16 with the unchanged runtime source and archive. This is a
backend credential/configuration change; **no new TestFlight build is required**. The existing
v15 image is also v16's image; older v11–v14 images remain ineligible for recovery.

Additional read-only review passed the preserved build-7 archive identity, public routes,
support/privacy/Terms pages, public Anthropic status and a fresh exact-image Linux/AMD64 recovery
scan with zero High/Critical findings. Signed-in Console retained the approved workspace spend
limit and notification settings, below-warning spend, sufficient existing credits and auto-reload
off. No credit purchase or billing-setting change was made. Actual notification delivery remains
unproven.

Fly's official HTTP response-class dashboard reported **No data available** in both the one-hour
and two-day windows. That evidence is OPEN, not zero traffic or proof of zero 5xx. Direct public
health, authenticated provider access and bounded event checks passed separately. This rotation
record does not claim a new complete clean-main pre-upload review, and no upload was attempted.
The existing daily Fly invoice/Cost Explorer review remains the owner's operating routine.

Final regression after the v16 lock update passed **879 backend tests**, locked pip-audit
with no known vulnerabilities, Bandit, Ruff and mypy; **237 iOS tests** (227 Swift and 10 UI);
and **44 release-script tests**. XcodeGen regenerated the existing project. Documentation link,
conflict-marker and credential checks passed. No production app-source or iOS bundle change
was introduced.

## Next work

Continue the existing daily owner cost review and rotate the new key before **30 November 2026**.
The [freemium decision packet](../freemium-model.md#next-decision-packet--29-september) is the next
product-planning step; it does not approve prices, quotas or paid distribution.
