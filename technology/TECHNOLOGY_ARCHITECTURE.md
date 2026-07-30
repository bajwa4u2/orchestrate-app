# Technology Architecture — Orchestrate Operations App

**Status: Canonical authority.**

```
orchestrate_app (this repo — Flutter client, 6 platforms)
        │  full HTTP API consumption
        ▼
orchestrate_backend (owns all OR-01..OR-16 technology)
```

No independent backend logic exists here. See `orchestrate_backend/technology/TECHNOLOGY_ARCHITECTURE.md` for the real technology graph this client exercises.
