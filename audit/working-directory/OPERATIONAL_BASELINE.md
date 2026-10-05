# Operational Baseline — orchestrate_app

Last updated: 4 Oct 2026

## Production resources

- Web: `orchestrateops.com`, deployed from `main` on Railway (`orchestrate-app`). After a deploy, confirm the new build is served (check cache headers, purge if stale). API: `api.orchestrateops.com` (from `../orchestrate_backend`).
- Stores: Google Play `com.orchestrateops.app`, App Store (iOS via Codemagic `ios-testflight`), Microsoft Store `AuraPlatformLLC.Orchestrateoperations`. Current release 2.1.0 (19), submitted 4 Oct 2026 (`store_assets/release_notes/2.1.0.md`).

## Toolchain

- Flutter 3.47.2 at `C:\flutter-release-3.47.2` for analyze, tests and release builds (`docs/RELEASE_TOOLCHAIN.md`). Do not use the global `C:\flutter`: it is a different version and gives false test failures ("Unsupported runtime stages format").

## Commands (with the release toolchain)

- `flutter analyze` (must be clean)
- `flutter test` (all tracked tests; `test/zz_preview` captures are untracked and may fail)
- `flutter build web --release`

## Release order

Implement -> Founder approval -> Commit (stage files explicitly) -> analyze + test on 3.47.2 -> Push (web deploys) -> Confirm the served build -> Walk it in the running product, signed in -> Release record in `store_assets/release_notes/` -> Continuity synchronization

No secrets are stored in this working directory.
