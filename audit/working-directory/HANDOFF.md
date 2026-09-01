# Handoff — orchestrate_app

Last updated: 2026-08-31 UTC

Read this first, then `CURRENT_STATE.md`, then `AGENTS.md` (operating law: workspace separation, category guardrail).

Orientation:

- Hard surface separation (Public / Client / Operator) lives in `lib/app/routing/app_router.dart`; never leak operator surfaces into client or public routes.
- The backend is `../orchestrate_backend` (own repo and continuity set — read its HANDOFF too; it contains founder-owned uncommitted work and its pushes trigger Railway deploys).
- Verification bar: `flutter analyze` clean, `flutter build web --release` compiles, then live cache-busted verification on `orchestrateops.com` with the real reviewer account — a passing build alone has been insufficient here before.
- Current public flagship state: `PublicOverviewWidget` renders before Home's
  hero. Its lifecycle records come only from the public lifecycle projection.
  Desktop uses the approved broad curve; mobile uses a width-adaptive
  serpentine topology. Travelers are sampled from their actual Flutter paths.
- Latest pushed public-web change: `aa46ec4` (`Preserve approved desktop
  flagship curve`). The unrelated generated macOS registrant remains
  uncommitted and must not be staged accidentally.
- Live evidence is stored outside the app source under the workspace evidence
  captures, including `desktop-flagship-restored.png`,
  `topology-fix-390.png`, and `topology-fix-320.png`.

Pending and founder gates: `NEXT_WORK.md`.
