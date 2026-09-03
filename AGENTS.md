# AGENTS.md — Orchestrate Flutter Frontend

<!-- foundational-product-direction-pointer -->
## Foundational product direction (added 2026-09-03) — read once, before planning

`docs/governance/FOUNDATIONAL_PRODUCT_DIRECTION.md` states what this product is for and what it may never be reduced to.
Read it **before** planning, architecture, naming, route design or client
reconstruction — so the product's purpose is in view before its code is.
It is a mirror; the canonical source is
`representation/inventory/FOUNDATIONAL_PRODUCT_DIRECTION.md`. Never edit the
mirror in place — edit the source, advance its stamp, resync.

**It is a directional authority, not a replacement authority.** It does not
supersede, dilute or reinterpret this repository's established governance. Where
a more specific established authority controls a matter, **that authority
continues to govern** — here, `orchestrate_backend/docs/ORCHESTRATE_AUTHORITY_INDEX.md` and the K1–K17 capability authorities.

**Do not cite it during routine implementation.** A governance layer invoked for
ordinary work stops being read. Its §5 states the precedence rule and the four
conflict classes; any narrowing of a specific authority must be classified and
recorded in `representation/inventory/FOUNDATIONAL_DIRECTION_SUPERSESSION.md`,
with the original wording preserved. Never supersede silently.


Operating law for agents working in `orchestrate_app/`. The umbrella scope file is `../AGENTS.md`; this file overrides for frontend work.

## Repo identity

Flutter (single codebase: iOS + Android + Web). Three workspaces: Public showroom, Client workspace, Operator command center. Hard surface separation in `lib/app/routing/app_router.dart`. Out-of-scope: anything under `../../aura/`.

## Category guardrail

Orchestrate is **governed managed-outbound execution infrastructure**. The public hero explicitly refuses: **"Not a CRM. Not an AI SDR. Not sequence software. Not a dashboard you operate manually."** This frontend is **not**:

- a CRM (no contact records as primary; Records are read-only operational artifacts)
- an AI SDR product (we have the substrate underneath — custodial dispatch + AI authority + enforcement + operator supervision)
- sequence software (we run the operation; the Client doesn't operate the runtime)
- a sales engagement productivity tool (the user is not the operator; the platform is)
- an autonomous AI agent (every governed action passes through a typed decision + enforcement record)

If a change would flatten Orchestrate into any of those, refuse it.

## Architecture boundaries

```
lib/
  app/
    routing/app_router.dart         ← surface guard, separate ShellRoutes per workspace
    shell/
      public_shell.dart             ← light theme
      client_shell.dart             ← light theme
      operator_shell.dart           ← dark theme
  core/
    theme/app_theme.dart            ← dark / light tokens
    network/                        ← Dio client + repositories
  features/
    public/                         ← /, /product, /pricing, /diagnostics, /trust-architecture, /legal/*, /intake, /contact, /for-evaluators
    client/                         ← Home, Operations, Opportunities, Replies, Meetings, Infrastructure, Representation, Records, Billing, Notifications, Support, Settings
    operator_workspace/             ← seven faculties (cognition, trust_readiness, continuity, runtime_truth, adaptation, governance, platform_supervision)
    operator/                       ← legacy operator surfaces (deprecate gradually)
    guidance/                       ← WhyAffordance + guidance drawer
```

## Canonical abstractions (preserve)

- **Surface-keyed routing** (`lib/app/routing/app_router.dart`): session carries `surface: operator | client`. Operator visiting `/client/*` or `/app/*` → forcibly redirected to `/ops/overview`. Client visiting `/ops/*` → forcibly redirected to `/app/home`. **Never bypass.**
- **Separate ShellRoutes** with separate `GlobalKey<NavigatorState>` per workspace. **Do not merge.**
- **Dark Operator theme** (`#090D14` abyss, teal `#6FD3C3` accent) vs **light Public/Client theme** (`#F7F8FA` cream, forest `#176B5D` accent). Theme is selected inside each shell.
- **Subscription-degradation reachability**: `/app/home` remains reachable on `past_due` / `paused` / `canceled` so the workspace can explain degradation. Do not lock the user out.
- **Client sidebar IA** (renamed away from CRM-shaped names; preserve):
  - Home, Operations (was "Outreach"), Opportunities (was "Leads"), Replies, Meetings, Infrastructure (was "Mailbox" — consolidates mailbox + sending identity + provider trust), Representation (consolidates business identity + ICP + voice + constraints + authorization), Records (read-only), Billing, Notifications, Support, Settings.
- **Operator sidebar IA** (seven faculties): Cognition, Trust & Readiness, Continuity, Runtime Truth, Adaptation, Governance, Platform Supervision + Developer drawer.
- **Outcome-confidence framing** on Client surfaces. Replace lifecycle buttons with `ClientMomentumCard`, `ClientConfidencePanel` reads from `ClientPortalRepository.fetchClientExperience`. Never fake metrics.
- **WhyAffordance** (`lib/features/guidance/widgets/why_affordance.dart`) — labeled button, opens a single drawer with one of ten explicit explain targets. No floating bubble, no popup, no auto-open.
- **MessageGovernancePanel** — provenance disclosure on activity. Client-altitude language only.

## Forbidden drift

- **Operator-altitude language in Client UI.** Forbidden phrases in Client routes: "governance posture", "governed template", "legacy custom body", "bounded AI (preview)", "inbound pipeline polling", "backend documents", "BackendSurface". See `../marketing/terminology-system.md` leak inventory.
- **CRM / AI-SDR / sequence terminology** in user-visible Client copy: "Leads", "Pipeline", "Campaign" (as primary surface), "Sequence" (as primary surface), "Cadence", "Drip", "Engagement rate", "Funnel". Internal model layer may carry these; user-facing strings must not.
- **Chatbot bubbles or floating AI assistants.** AI is surfaced as governance / decision support / readiness, not personality.
- **Fabricated metrics.** No fake counts, fake job states, fake AI status, fake client progress, fake provider data, fake billing data, fake campaign outcomes. Every displayed operational state maps to backend data, endpoint responses, or a clearly marked empty/loading/error state. (AGENTS.md ../ §4 Frontend Truth Rule.)
- **Bypassing surface guards** in `app_router.dart`. The redirect logic is structural authority.
- **Introducing a fourth workspace shell.** Public / Client / Operator is the architecture.
- **Manual operator tools in Client UI.** The Client authorizes; the platform operates. The Client sees outcome confidence, not lifecycle controls.
- **Mounting `ClientBackendSurfaceScreen` (or any generic backend-surface wrapper) on a Client route** with operator-altitude vocabulary.
- **New legacy `/app/*` routes.** The legacy fallback set (`/app/activity`, `/app/branding`, `/app/newsletter`, `/app/contacts`, `/app/campaigns`) should be deprecated, not extended.
- **Importing test packages in `lib/`** (test code belongs in `test/`).
- **Hardcoded API URLs or tokens** in source.

## Secret handling

- `.env` (if any) is gitignored.
- No hardcoded OAuth client secrets, API keys, sending-domain credentials in source.
- Tokens come from `aura-equivalent` (Orchestrate backend) at runtime.
- Build-time configuration via `dart-define`.
- If a real credential is discovered in any file, flag for rotation and remove the value.

## Token discipline

Default load for agents:

- this file (`AGENTS.md`)
- `../AGENTS.md` (umbrella scope, only if cross-repo context needed)

Opt-in (load only when the task requires):

- `docs/OUTREACH_LEAD_CAMPAIGN_FLOW_AUDIT.md` — current outbound flow audit
- `../docs/CLIENT_WORKSPACE_END_TO_END_AUDIT.md` (31K — heavy; load only for client-workspace work)
- `../docs/CLIENT_WORKSPACE_END_TO_END_IMPLEMENTATION.md`
- `../docs/MAILBOX_ACTIVATION_AND_RESPONSE_SENDING.md`
- `../orchestrate_docs/00_governance/OPERATOR_WORKSPACE_SPECIFICATION.md` (22K) — load for operator faculty work
- `../orchestrate_docs/01_foundation/ORCHESTRATE_FOUNDATION_AND_EXECUTION_RECORD.md`

Do not load by default:

- `../orchestrate_docs/00_governance/SYSTEM_GUIDANCE_SPECIFICATION.md` (42K)
- `../docs/CLIENT_REVENUE_ENGINE_WORKFLOW.md` (23K)
- `../marketing/**` — load only for positioning, copy, or external-facing work
- `docs/business_deck/` — marketing-adjacent
- `store_assets/` — marketing-adjacent
- `.dart_tool/`, `build/`, `ios/Pods/`, `android/.gradle/`, `web/canvaskit/` — generated

## Required validation

For Dart code changes:

```
flutter analyze
flutter test
```

For routing / runtime changes:

```
flutter build apk --debug
# or appropriate target
```

For integration test changes:

```
flutter test integration_test/
```

Do not claim `flutter analyze` is clean unless it actually exited 0 with zero issues.

## Git discipline

- Branch per task.
- Commit messages: short imperative summary + body that explains the "why."
- Never force-push to `main`.
- Do not bypass hooks (`--no-verify`) without explicit user authorization.
- If a pre-commit hook fails, fix the issue and create a new commit. Do not `--amend` a published commit.

## Documentation discipline

- Frontend architecture decisions → `docs/` with a dated filename.
- Marketing / positioning / external narrative → `../marketing/` (canon lives there; do not duplicate).
- Do not write a new audit / handoff doc unless the task explicitly requests it.
- The frontend operating canon is here; deeper rationale lives in `../orchestrate_docs/`.

## Completion standard

A change is complete when:

1. `flutter analyze` exits 0 with zero issues.
2. `flutter test` passes affected tests.
3. New screens carry useful empty / loading / error states.
4. No fabricated metrics or fake operational state.
5. Vocabulary conforms to `../marketing/terminology-system.md`.
6. No operator-altitude language leaks into Client routes.
7. Surface-keyed routing remains structural; no merged ShellRoutes.
8. No new legacy `/app/*` routes added.
9. A PR / commit message explains the change and the validation run.

## Known live findings (verify before assuming fixed)

- `ClientSequenceAuthorScreen` (`lib/features/client/screens/client_sequence_author_screen.dart`) — exposes operator-altitude vocabulary to clients. Documented leak; needs paraphrase.
- `MessageGovernancePanel` (`lib/features/client/widgets/message_governance_panel.dart`) — operator-altitude provenance language. Documented leak; needs paraphrase.
- `ClientBackendSurfaceScreen(trust)` mounted at `/client/trust` (`lib/app/routing/app_router.dart:1163`) — generic backend-surface wrapper on a Client route. Replace with purpose-built client trust surface.
- Legacy `/app/*` routes still mounted (`/app/activity`, `/app/branding`, `/app/newsletter`, `/app/contacts`, `/app/campaigns`) — deprecate-redirect to canonical successors.
- `AiApprovalsScreen` and `PlatformSupervisionScreen` are intentional honest stubs per `OPERATIONAL_FULFILLMENT_DIRECTIVE §5.1` — do not "fill in" with fabricated state.

These are tracked. Do not "fix" them in passing without scope.

## Repository Continuity Doctrine (workspace-wide, 2026-07-21)

Repository documentation is authoritative. Conversation history is temporary.

This repository maintains its canonical continuity records in `audit/working-directory/` (`CURRENT_STATE.md`, `NEXT_WORK.md`, `HANDOFF.md`, `DECISIONS.md`, `OPERATIONAL_BASELINE.md`). Read `HANDOFF.md` first when taking over work.

- No implementation milestone is complete until the continuity documents are synchronized.
- Every milestone must record: completed implementation; founder-approved architectural decisions; production baseline; current implementation status; the next implementation starting point; and outstanding founder approvals.
- Future agents resume from repository continuity documentation, never from assumptions or prior conversations.

Engineering lifecycle -- no step may be bypassed:

```text
Implement -> Founder Approval -> Commit -> Continuity Synchronization -> Next Milestone
```
