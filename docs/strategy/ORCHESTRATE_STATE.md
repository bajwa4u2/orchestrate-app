# ORCHESTRATE_STATE.md — Canonical Reality

> Canonical reference for Orchestrate. Future work on the company website,
> investor materials, commercialization, decks, outreach, and positioning
> must reference this document first. It captures **observed implementation
> and validated audit findings** — facts, not aspirations. Do not drift from
> it without re-verifying against the implementation.
>
> Note on location: `orchestrate/` is not a git repository; the Orchestrate
> repository is `orchestrate_app` (origin: `bajwa4u2/orchestrate-app`). This
> canonical doc therefore lives at `orchestrate_app/docs/strategy/`.

## Product Reality

**What Orchestrate is.** Managed governed-outbound execution infrastructure. It detects commercial opportunity from market signals, qualifies it, verifies readiness, runs governed dispatch through the client's own mailbox under a versioned representation authorization, handles follow-up, reply classification, meeting handoff, and recovery — fully audited end to end.

**What it is not.** Not a CRM. Not an AI SDR. Not sequence / cold-email software. Not a generic lead tool. Not a dashboard the client operates manually.

**Multi-platform status (verified by release builds).** Live on the web at `orchestrateops.com`. Release artifacts build successfully for **Web** (`build/web`), **Windows** (`aura_app`-equivalent `orchestrate_app.exe`), and **Android** (`app-release.aab`, ~45 MB). **iOS** is built and signed via Codemagic workflow `ios-testflight` ("Orchestrate iOS — TestFlight") — not buildable on Windows by design. An **App-Store-safe billing gate** (iOS §3.1.1: `externalPurchaseAllowed`, `kIosPlanManagementNotice`) is implemented.

**Runtime status.** Deployed production runtime: a custom Postgres-backed dispatch loop (10s cadence), 15 job types, 12 concrete workers, 6 discovery connectors (Apollo, Overpass, Yelp, Search, open-dataset, website enrichment), an AI decision gateway + enforcement service (9 typed statuses, two call sites for defense in depth), and deterministic governors (reputation, discovery-refill, dispatch).

## Commercial Reality

- **Category:** Governed Revenue Automation.
- **What it is commercially:** managed commercial execution infrastructure.
- **Buyer-facing outcome:** qualified B2B opportunities and governed outreach without hiring or operating a revenue-operations team.
- **Commercial mechanics that exist:** subscription model, **2-lane × 3-tier** catalog (Opportunity / Revenue × Focused / Multi / Precision), live Stripe billing, **15-day trial** (`trial=15d`), public pricing page, signup-free diagnostics.
- **Existing customers / usage (honest):** **No externally-verified paying customers or references exist today.** A prior "institutional customers in active use" claim was unverified and has been removed from the investor deck. The live product, trial, and pricing are real; the first paying cohort is the next milestone. The realistic first-usage paths are founder-operated founding pilots and dogfooding the company's own outbound.

## Existing Assets

- **Runtime:** dispatch loop, workers, connectors, governors.
- **Diagnostics:** live, signup-free SPF/DKIM/DMARC checker using the *real production verifier* — a public proof + distribution asset.
- **Billing:** Stripe, 2-lane × 3-tier, App-Store-safe gate.
- **Trials:** 15-day, query-preserved (`plan`/`tier`/`trial`).
- **Governance:** refusal-first — 7 dispatch decisions (5 do not send), 8 rationale questions per send.
- **Readiness:** 9 ordered blocker layers; versioned representation authorization.
- **Audit systems:** decision → enforcement → outcome lineage; metadata-only audit (never credentials, never bodies).
- **Operational proof:** seven-faculty operator workspace (Cognition, Trust & Readiness, Continuity, Runtime Truth, Adaptation, Governance, Platform Supervision) + queryable audit timeline.
- **Public metrics:** **not yet instrumented/public** (a known gap, not a claim).

## Proven False Assumptions

- ❌ "It's just an idea." → It is a deployed, multi-platform product (builds verified Web/Windows/Android; iOS CI-ready).
- ❌ "It's an MVP." → Deep runtime + governance + a seven-faculty operator workspace.
- ❌ "It lacks proof." → It lacks *market* proof (customers/outcomes); it has abundant *capability and trust* proof (live product, diagnostics, audit trail). These are different things and must not be conflated.
- ❌ "It lacks operational reality." → Production runtime, governors, enforcement, audited execution exist.

## Current Bottlenecks (reality-backed)

1. **No externally-verified customers or outcomes** (market-assigned value) — the binding constraint.
2. **Distribution / opportunity generation** — the diagnostics tool is an unexploited growth wedge; the self-serve trial + transparent pricing are an unused PLG channel.
3. **First-customer acquisition is relationship-driven** — no inbound at zero references; the first sale is warm-sourced.
4. (Resolved) Commercial legibility — the acquisition flow was hardened (primary CTA "Start 15-Day Trial", trial language, query-context preserved).

## Representation Doctrine (how to represent Orchestrate)

- **Lead with the live product as proof** — "observe this," not "trust us." Foreground the diagnostics and the decision→enforcement→outcome audit lineage (the unfakeable artifact).
- **Hold the category:** Governed Revenue Automation / managed commercial execution infrastructure. Never reduce to CRM, AI SDR, sequence software, or lead tool.
- **Differentiator:** refusal as a first-class, audited outcome; AI under typed custody.
- **Be honest about traction:** no fabricated customers, logos, or metrics. The truthful line: *"the product is live; the first paying cohort is the next milestone."*
- **Primary CTA:** "Start 15-Day Trial" (carry `trial=15d`). Contact/Pitch remain reachable; founder-led for the first cohort.
