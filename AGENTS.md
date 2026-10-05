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

<!-- product-design-function-pointer -->
## Product design authority (charter PDF-2026-09-27.1): read before changing anything a user sees

This applies before any change to what a user sees or does in Orchestrate: screens, layout, flows,
wording, visual assets. It does not apply to backend-only work.

- **The founder is Head of Product Design.** Agents carry out design work; they never hold design
  authority.
- **Orchestrate has its own design system.** Nothing visual (colour, type, spacing, density, icons,
  motion, tone) is shared with the company's other products without a founder decision. Only
  behaviour is shared: an honest interface, explicit decision and authority moments, truthful
  empty, loading and error states, accessibility floors, platform conventions.
- **Corrections (founder ruling, 2026-09-27):** "The agent may implement a narrow, reversible
  correction locally when it restores an already approved design. It must record what was broken
  and verify the rendered result. Founder approval is required before committing or releasing the
  correction. Any new design or change in flow requires approval before implementation."
- **Verify rendered.** Design work is verified only in the running product, in the right signed-in
  state, at real widths and text sizes. Name the layer observed.
- **Record** every approved design decision in `company/docs/design/DESIGN_DECISIONS.md`.

Full charter: `company/governance/product-design-function.md` (version `PDF-2026-09-27.1`).
If this pointer's version differs from the charter's, the pointer is stale: resync it from the
charter's Appendix A, never edit it here.

## Repo identity

Flutter (single codebase: iOS + Android + Web + Windows). Three workspaces: Public site, Client workspace, Operator console. Hard surface separation in `lib/app/routing/app_router.dart`. Out-of-scope: anything under `../../aura/`.

## Current product, and what is retired (updated 4 Oct 2026) — read before any client work

The client workspace is **Direction B** (DD-26, founder, 30 Sep 2026). The legacy workspace
was retired on 2 Oct 2026 (DD-34, DD-35, DD-36). If a task, an old document or a field name
points at a retired page, map it to today's place. **Never rebuild a retired page or route.**
Full state and the dated RETIRED list: `audit/working-directory/CURRENT_STATE.md`. Design
decisions: `company/docs/design/DESIGN_DECISIONS.md` (DD-26 to DD-39).

- **Places** (`lib/app/shell/client_shell.dart`): Today, Customers (`/client/relationships`),
  Market, Money, Setup, plus Search (`command_palette.dart`) and Support. The account menu holds
  People & authority, Plan & billing, Account & security (and Support); Search also offers Your
  record with Orchestrate. The only client addresses are `_clientCanonicalRoutes` in
  `app_router.dart`.
- **Setup** (`lib/features/client/setup/one_path_setup_screen.dart`): one path of 8 steps chosen
  by kind of business (33 kinds): Your business, Who you want, When they're ready, What you offer,
  How you get paid, Your email, Who acts for it, Your plan; then Where it stands. The plan is last;
  setup and readiness are free. Buyer roles, moments, proof kinds, payment choices and kind
  questions come from the server playbook.
- **Market**: only businesses that passed five checks, each put to the owner as a proposal: Yes,
  write to them / Not now / Not for us. "Write automatically" is the owner's standing yes within a
  daily limit. A yes writes from the client's own mailbox; follow-ups are automatic per the Setup
  choice; replies are drafted and every answer needs the owner's yes.
- **Mailbox privacy promise:** Orchestrate never reads or comments on unrelated mail in a client's
  inbox or sent folder.
- **Retired, removed from the app:** the client names Home, Operations, Opportunities, Leads,
  Replies, Meetings, Notifications, Infrastructure, Representation, Records, Billing, Settings,
  Business hub/identity, Mailbox, Credentials, Evidence, Artifacts, Branding, Subscribe, Contacts,
  Sequence author; every `/app/*` address and retired `/client/*` page (removed outright, not
  redirected, `293f81a`); `ClientSequenceAuthorScreen`, `MessageGovernancePanel`,
  `ClientBackendSurfaceScreen` on `/client/trust`, `WhyAffordance` and the guidance drawer,
  `ClientMomentumCard`, `ClientConfidencePanel`; the seven-faculty operator workspace; lanes,
  tiers and trials.
- **Dead files still on disk** (imported or present, never routed): `leads_screen.dart`,
  `meetings_screen.dart`, `client_replies_screen.dart`, `client_notifications_screen.dart` in
  `lib/features/client/screens/`, and `public_overview_widget.dart`,
  `commercial_execution_surface.dart` in `lib/features/public/widgets/`. Do not re-mount them.

## Release toolchain and forward tolerance

- **Toolchain:** analyze, test and build with Flutter 3.47.2 at `C:\flutter-release-3.47.2`
  (`docs/RELEASE_TOOLCHAIN.md`). The global `C:\flutter` is a different version and produces false
  test failures ("Unsupported runtime stages format"). Release records:
  `store_assets/release_notes/<version>.md` (current: 2.1.0 (19), submitted 4 Oct 2026).
- **A newer server needs no release** (`test/a_newer_server_needs_no_release_test.dart`): any
  server value this app does not know (a decision, a payment choice, a question, a draft) must
  degrade to something generic and usable. Never write client code that needs a store release
  because the server said something new.
- **Retired stays retired:** `test/navigation_promises_test.dart` and
  `test/router_redirect_integrity_test.dart` assert retired addresses are not routed and that every
  route the server names is a page the app shows.

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
      public_shell.dart             ← Direction B (paper)
      client_shell.dart             ← Direction B (paper); places + account menu
      operator_shell.dart           ← dark theme
  core/
    theme/ob.dart                   ← Direction B tokens (paper, ink, amber = yes, green = money)
    theme/app_theme.dart            ← operator dark tokens and shared theme
    network/                        ← Dio client + repositories
  features/
    public/                         ← /, /how-it-works, /pricing, /trust, /about, /contact (visitor assistant), /diagnostics, /legal/*
    client/                         ← Today, Customers, Market, Money, Inbound (in Today), Support, Account; setup/ = one-path Setup
    ops_console/                    ← operator console: work queue, dispatch, transport, inventory, jobs, authority, history, clients, campaigns
    operator/                       ← remaining operator screens (provenance, audit, system doctor, inquiries, debug)
    support/                        ← client Support
```

(Updated 4 Oct 2026. `operator_workspace/` and `guidance/` no longer exist.)

## Canonical abstractions (preserve)

- **Surface-keyed routing** (`lib/app/routing/app_router.dart`): session carries `surface: operator | client`. An operator visiting `/client/*`, `/app/*` or `/auth/*` is sent to `/ops/work`. A client visiting `/ops/*` is sent to `/client/today`. Retired operator addresses (`_retiredOperatorSurfaces`) land on `/ops/work`. **Never bypass.**
- **Separate ShellRoutes** with separate `GlobalKey<NavigatorState>` per workspace. **Do not merge.**
- **Themes:** dark Operator theme (`#090D14`, teal `#6FD3C3`, `app_theme.dart`) vs Direction B for Public and Client (paper `#F3EFE7`, ink `#17202B`, `ob.dart`; amber only for "waiting for your yes", green only for money, guarded by `test/design/colour_has_one_meaning_test.dart`). Theme is selected inside each shell.
- **A place is never refused for want of a plan:** signed-in, verified members reach their workspace whatever the subscription state; entitlement refuses an action, at the server, and explains itself. Do not add a subscription gate to a route.
- **Client IA (updated 4 Oct 2026; preserve):** Today, Customers, Market, Money, Setup, plus Search and Support; account menu: People & authority, Plan & billing, Account & security, Support. See "Current product, and what is retired" above. The earlier IA (Home, Operations, Opportunities, Replies, Meetings, Infrastructure, Representation, Records, Billing, Notifications, Settings) is retired; do not restore it.
- **Operator IA:** the console in `operator_shell.dart` (Work queue, Authority, Clients, Contacts & imports, Transport, Dispatch, Campaigns, Message provenance, Audit history, Jobs, Inquiries, Feedback, Debug checks). The seven-faculty IA was retired in Sep 2026.
- **Honest states on Client surfaces:** every number, status and card reads from the server; empty, loading and error states say what is true. Never fake metrics.

## Forbidden drift

- **Operator-altitude language in Client UI.** Forbidden phrases in Client routes: "governance posture", "governed template", "legacy custom body", "bounded AI (preview)", "inbound pipeline polling", "backend documents", "BackendSurface". See `../marketing/terminology-system.md` leak inventory.
- **CRM / AI-SDR / sequence terminology** in user-visible Client copy: "Leads", "Pipeline", "Campaign" (as primary surface), "Sequence" (as primary surface), "Cadence", "Drip", "Engagement rate", "Funnel". Internal model layer may carry these; user-facing strings must not.
- **Chatbot bubbles or floating AI assistants.** AI is surfaced as governance / decision support / readiness, not personality.
- **Fabricated metrics.** No fake counts, fake job states, fake AI status, fake client progress, fake provider data, fake billing data, fake campaign outcomes. Every displayed operational state maps to backend data, endpoint responses, or a clearly marked empty/loading/error state. (AGENTS.md ../ §4 Frontend Truth Rule.)
- **Bypassing surface guards** in `app_router.dart`. The redirect logic is structural authority.
- **Introducing a fourth workspace shell.** Public / Client / Operator is the architecture.
- **Manual operator tools in Client UI.** The Client authorizes; the platform operates. The Client sees outcome confidence, not lifecycle controls.
- **Mounting `ClientBackendSurfaceScreen` (or any generic backend-surface wrapper) on a Client route** with operator-altitude vocabulary.
- **Any `/app/*` route, or any retired `/client/*` page.** All were removed on 2 Oct 2026 (DD-36). Do not add them back, even as redirects.
- **Rebuilding a retired surface** (see the RETIRED list in `audit/working-directory/CURRENT_STATE.md`), or re-mounting the dead files listed above.
- **Client code that needs a store release because the server said something new** (forward tolerance, above).
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

- `audit/working-directory/CURRENT_STATE.md` — current product and the RETIRED list (read first for client work)
- `company/docs/design/DESIGN_DECISIONS.md` (DD-26 onward) — approved client and public design
- `store_assets/release_notes/<version>.md` — release records

Historical only (they describe the retired workspace; never build from them):

- `docs/OUTREACH_LEAD_CAMPAIGN_FLOW_AUDIT.md` (Apr 2026 outbound flow audit)
- `../docs/CLIENT_WORKSPACE_END_TO_END_AUDIT.md` (31K)
- `../docs/CLIENT_WORKSPACE_END_TO_END_IMPLEMENTATION.md`
- `../docs/MAILBOX_ACTIVATION_AND_RESPONSE_SENDING.md`

Operator and foundation references:

- `../orchestrate_docs/00_governance/OPERATOR_WORKSPACE_SPECIFICATION.md` (22K) — operator doctrine; its seven-faculty IA is retired, the console in `operator_shell.dart` is current
- `../orchestrate_docs/01_foundation/ORCHESTRATE_FOUNDATION_AND_EXECUTION_RECORD.md`

Do not load by default:

- `../orchestrate_docs/00_governance/SYSTEM_GUIDANCE_SPECIFICATION.md` (42K)
- `../docs/CLIENT_REVENUE_ENGINE_WORKFLOW.md` (23K)
- `../marketing/**` — load only for positioning, copy, or external-facing work
- `docs/business_deck/` — marketing-adjacent
- `store_assets/` — marketing-adjacent
- `.dart_tool/`, `build/`, `ios/Pods/`, `android/.gradle/`, `web/canvaskit/` — generated

## Required validation

For Dart code changes (with the release toolchain, `C:\flutter-release-3.47.2\bin\flutter`):

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
8. No `/app/*` route or retired page added back; unknown server values still degrade gracefully.
9. A PR / commit message explains the change and the validation run.

## Known live findings (re-verified in code 4 Oct 2026)

The earlier findings are closed by removal (DD-36, `293f81a`, and the Sep 2026 operator retirement):
`ClientSequenceAuthorScreen`, `MessageGovernancePanel`, `ClientBackendSurfaceScreen` on
`/client/trust`, the legacy `/app/*` routes, and the `AiApprovalsScreen` / `PlatformSupervisionScreen`
stubs no longer exist in `lib/`. Do not recreate them.

Open:

- Dead client and public files still on disk (listed under "Current product, and what is
  retired"). They carry retired vocabulary ("Opportunities", "commercial-intelligence outcomes").
  Deletion needs founder approval; until then never route or construct them.
- `OperatorBackendSurfaceScreen` remains on several `/operator/*` routes (operator surface only;
  allowed there, never on a Client route).

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
