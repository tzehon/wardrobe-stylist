# Wardrobe Google Cloud project retirement — 19 September 2026

## Authorization and scope

The owner explicitly requested deletion of the GCP projects and the corresponding documentation
updates on 19 September. The signed-in Google Cloud console inventory identified these two
Wardrobe projects:

| Project name | Exact project ID | Action |
| --- | --- | --- |
| wardrobe-stylist | `wardrobe-stylist-497709` | Project shutdown requested and accepted |
| Wardrobe Stylist Production | `wardrobe-stylist-production` | Project shutdown requested and accepted |

Only those projects were selected. The unrelated `kaggle-gen-ai-google-course` project was left
untouched. No Google account, Search Console property or unrelated cloud resource was deleted.

The current Gmail-free build 7 and Fly/App Attest backend do not depend on these legacy projects.
Retained clean-install, local QA and protected-styling evidence remains valid. This action uses
the owner's new deletion instruction; it is not authorization inferred from the earlier snapshot
waiver or App Store submission approval.

## Provider outcome

Both exact project IDs were entered separately in Google Cloud's **Shut down project** dialogs,
and **Shut down anyway** was submitted for each. Google acknowledged both shutdown requests.
At the **19 September 2026, 15:50 SGT (07:50 UTC)** verification checkpoint, the refreshed
**Resources pending deletion** table listed both exact IDs above. The production project's
confirmation also stated that it was now shut down and scheduled for deletion **after
19 October 2026**. Both projects are shut down and pending final provider deletion.

This completes the requested project-shutdown action. It does **not** establish permanent deletion
or all-copy purge. Google's normal project-deletion flow retains a 30-day recovery window; some
resources can be deleted sooner and may not be recoverable. Do not restore either project or
recreate Google/OAuth credentials without a new owner instruction. Final provider deletion remains
pending and must not be marked verified merely because the date has elapsed.
See [Google's deletion and restoration documentation](https://docs.cloud.google.com/resource-manager/docs/delete-restore-projects).

The local Google Cloud CLI login had expired, so the action and verification used the existing
signed-in console session. No credentials were added or copied into the repository.

## Documentation and release impact

The README, agent guidance, release plan, APP-036 backlog, TestFlight runbook, submission records
and historical Google setup guides now point to this outcome. Dated pre-retirement evidence is
preserved as history. APP-036 remains in progress for its remaining public-release work; project
shutdown does not change Apple's review state or grant manual public-release approval.

No iOS source, bundled resource, API contract, backend runtime, Fly configuration or stored app
data changed. **No new TestFlight build is required.** The completed regression remains applicable
under the documentation-only rule in `AGENTS.md`; validation for this update is documentation
consistency, relative-link checks and diff review.
