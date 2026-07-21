# Handoff — orchestrate_app

Last updated: 2026-07-21 UTC

Read this first, then `CURRENT_STATE.md`, then `AGENTS.md` (operating law: workspace separation, category guardrail).

Orientation:

- Hard surface separation (Public / Client / Operator) lives in `lib/app/routing/app_router.dart`; never leak operator surfaces into client or public routes.
- The backend is `../orchestrate_backend` (own repo and continuity set — read its HANDOFF too; it contains founder-owned uncommitted work and its pushes trigger Railway deploys).
- Verification bar: `flutter analyze` clean, `flutter build web --release` compiles, then live cache-busted verification on `orchestrateops.com` with the real reviewer account — a passing build alone has been insufficient here before.

Pending and founder gates: `NEXT_WORK.md`.
