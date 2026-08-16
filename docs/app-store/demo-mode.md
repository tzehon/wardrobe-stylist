# Offline Demo Mode

Demo Mode gives App Review and first-time users a deterministic tour without a Google account or
personal wardrobe. Enter it from first-run onboarding (`Try the offline demo`) or Settings
(`Open Offline Demo`). Automated review flows may launch the app with `--wardrobe-demo`.

While active:

- the indigo banner labels every tab as `Demo Mode · Fictional Data`;
- seven fixed fictional items (including one pending synthetic import) and one fictional worn look live in a dedicated in-memory SwiftData
  container;
- Today renders a fixed bundled look without constructing `BackendConfig` or a recommendation
  client;
- the production Settings screen is replaced, so Google sign-in, Gmail sync, AI styling,
  background controls, and notification controls cannot be invoked;
- scene-background reconciliation is skipped; an in-app Demo entered from the production shell
  leaves that shell's OAuth callback routing available for an already-running Google flow, while
  reviewer launch never constructs connected-feature UI and never starts sign-in;
- catalog browsing, editing, deletion, and outfit-history navigation operate only on the
  in-memory demo container;
- Demo Settings can destructively reset that disposable container to the bundled seven-item state,
  giving reviewers a safe data-control path without touching the production store.

Exiting releases that container and discards every demo edit. An in-app tour resumes the same
production container and selected tab it had before the demo. A `--wardrobe-demo` launch opens or
migrates the production store only after the reviewer exits, so a broken real store cannot block
the tour or be touched merely by launching it. Demo definitions must remain obviously fictional
and must never include Gmail identifiers, account ownership, remote image URLs, or personal data.
