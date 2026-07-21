# Operational Baseline — orchestrate_app

Last updated: 2026-07-21 UTC

## Production resources

- Web: `orchestrateops.com`, behind Cloudflare edge cache. API: `api.orchestrateops.com` (from `../orchestrate_backend`).
- Mobile: iOS via founder's manual Codemagic flow. Last recorded release `0.2.2+11`.

## Commands

- `flutter analyze` (must be clean)
- `flutter build web --release` (must compile)
- `flutter test`

## Release order

Implement -> Founder Approval -> Commit -> analyze + build -> Push/deploy -> Cache-freshness check (`Cf-Cache-Status`; founder purge if stale) -> Live verification with the real reviewer account -> Continuity synchronization

No secrets are stored in this working directory.
