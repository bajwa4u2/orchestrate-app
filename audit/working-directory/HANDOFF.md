# Handoff — orchestrate_app

Last updated: 4 Oct 2026

Read this first, then `CURRENT_STATE.md` (current product and the RETIRED list), then `AGENTS.md` (operating law, design authority, category guardrail).

Orientation:

- The client workspace is Direction B (DD-26): Today, Customers, Market, Money, Setup, plus Search and Support; account menu for People & authority, Plan & billing, Account & security. The legacy workspace and every `/app/*` address are gone (DD-36). If a task, an old document or a backend field names a retired page, map it to today's place; never re-create the page or route.
- Anything a user sees needs the founder's design approval first (charter `PDF-2026-09-27.1`, see `AGENTS.md`). Approved decisions are recorded in `company/docs/design/DESIGN_DECISIONS.md`.
- Use the release toolchain, Flutter 3.47.2 at `C:\flutter-release-3.47.2`. The global `C:\flutter` produces false test failures ("Unsupported runtime stages format").
- Forward tolerance: an unknown server value must degrade to something generic and usable, never force a release (`test/a_newer_server_needs_no_release_test.dart`).
- Surface separation (Public / Client / Operator) lives in `lib/app/routing/app_router.dart`; never leak operator surfaces into client or public routes.
- The backend is `../orchestrate_backend` (own repo and continuity set). Pushing its `main` deploys the API on Railway. This app's web build also deploys from `main` on Railway (`orchestrate-app`).
- Verification bar: analyze clean and tests passing on the release toolchain, then the change seen in the running product, signed in as the right person, at real widths. A passing build alone has been wrong before.
- Untracked store screenshots under `store_assets/` and the generated macOS registrant are not part of any commit unless the founder says so; stage files explicitly.

Pending and founder gates: `NEXT_WORK.md`.
