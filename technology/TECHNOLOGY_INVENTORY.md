# Technology Inventory — Orchestrate Operations App

**Status: Canonical authority for this repository.** This repository does not independently own backend technology — see `orchestrate_backend/technology/TECHNOLOGY_INVENTORY.md` for the full OR-01–OR-16 catalog this client consumes.

## What this repository itself implements

| Item | What it is | Evidence |
|---|---|---|
| Multi-platform client (OR-15) | One Flutter codebase to Windows(MSIX/Microsoft Store)/macOS/Android/iOS/Linux/web | Real platform dirs; genuine, specific MSIX product identity |
| Operator/client-portal/public role surfaces | Three distinct UI role surfaces over one backend API | `lib/features/operator`, `client`, `public` |
| Dedicated governance UI | Operator-facing screens for dispatch governance, AI trust readiness, runtime truth | `lib/features/operator_workspace/{governance,trust_readiness,runtime_truth}` |
