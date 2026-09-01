# Current State — orchestrate_app

Last updated: 2026-08-31 UTC

Repository documentation is authoritative. Conversation history is temporary. This continuity set was established 2026-07-21 (workspace-wide continuity doctrine); prior history is reconstructed from git history and the ROS Phase II record (in `../orchestrate_backend/representation/inventory/`).

## Identity

Orchestrate Flutter frontend (single codebase: iOS + Android + Web). Three workspaces with hard surface separation in `lib/app/routing/app_router.dart`: Public showroom, Client workspace, Operator command center. Orchestrate is governed managed-outbound execution infrastructure; the public hero explicitly refuses "Not a CRM. Not an AI SDR. Not sequence software. Not a dashboard you operate manually." See `AGENTS.md`.

## Production baseline

- Production web at `orchestrateops.com`, behind Cloudflare edge cache (a deploy was once invisible for ~90 minutes behind a stale cached `main.dart.js` — always verify freshness with `Cf-Cache-Status`, purge if needed).
- Last recorded release version: `0.2.2+11` (`4a3a8cd`). iOS/Codemagic upload is the founder's manual step.
- Public web flagship verification was performed against the deployed site with
  cache-busted browser renders at 1440, 1024, 768, 390, 360, and 320px.

## Implementation status

- `main` HEAD `aa46ec4` is pushed to `origin/main` (`bajwa4u2/orchestrate-app`).
- The public Home lifecycle flagship is restored before the hero and consumes
  the existing `/v1/public/lifecycle` projection without backend changes.
- Flagship presentation uses a live broadcast rail, curve-native travelers,
  an Opportunities → Dispatch packet branch, a Leads → Suppressed governed
  branch, and a mobile width-adaptive serpentine topology. Desktop retains the
  approved broad editorial curve.
- Backend ordering, values, surfaced/hidden records, and zero behavior remain
  authoritative. No operational values or events are fabricated in the
  frontend.
- Recent public-web commits: `c65f797`, `de6b282`, `309651f`, `3c05d40`,
  `fd679c4`, `a8ff6e9`, `10c7d4d`, `9ce7d86`, `f8a155f`, `b9d08fc`,
  `aa46ec4`.
- `a71b39e` = ROS Phase II fidelity restoration (CLOSED, VERIFIED 2026-07-13): removed false "outreach active"/"no action needed" claims (frontend side of the CD-2 fix), 9-layer chain copy corrections. Live-verified on production with the real reviewer account after a founder cache purge.
- `3a2a23b` = operator work queue + six-ring subsystem screens (post-closeout feature, committed and pushed).

## Next implementation starting point

No founder-defined next milestone is recorded. See `NEXT_WORK.md`.

## Outstanding founder approvals

Prioritization of any next milestone; iOS store upload remains a founder manual step.
