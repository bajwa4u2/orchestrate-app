# Current State — orchestrate_app

Last updated: 4 Oct 2026 (rewritten from code, git log and the design decision log; replaces the 31 Aug 2026 version)

Repository documentation is authoritative. Conversation history is temporary.

## Identity

Orchestrate Flutter client, one codebase for Web, Android, iOS and Windows. Three surfaces with hard separation in `lib/app/routing/app_router.dart`: Public site, Client workspace, Operator console. Category guardrail and governance: `AGENTS.md`.

## The product as it is today (Direction B, DD-26 onward)

Look: paper `#F3EFE7`, white cards, ink `#17202B` (`lib/core/theme/ob.dart`). Amber means only "waiting for your yes"; green means only money (guard: `test/design/colour_has_one_meaning_test.dart`). The operator console keeps its own dark theme.

**Client workspace** (`lib/app/shell/client_shell.dart`):
- Places: **Today** (`/client/today`, absorbs `/client/inbound`), **Customers** (`/client/relationships`), **Market** (`/client/market`), **Money** (`/client/money`), **Setup** (`/client/setup`), plus **Search** (command palette) and **Support** (`/client/support`).
- Account menu: People & authority (`/account/people`), Plan & billing (`/account/plan`), Account & security (`/account/security`), Support; Search also offers Your record with Orchestrate (`/account/record`).
- The full list of client addresses is `_clientCanonicalRoutes` in `app_router.dart`. Anything else shows the not-found page with the way back.

**Setup** (`lib/features/client/setup/one_path_setup_screen.dart`, DD-34): one path, 8 steps, chosen by kind of business (33 kinds): Your business · Who you want · When they're ready · What you offer · How you get paid · Your email · Who acts for it · Your plan, then "Where it stands". The plan is last; setting up and readiness are free. Buyer roles, moments, proof kinds, payment choices and kind questions come from the server playbook, so new kinds need no release.

**Market** (DD-30, DD-39): only businesses that passed five checks (exists, alive on its own website, fits, published address that accepts mail, explainable). Each is put to the owner as a proposal: Yes, write to them / Not now / Not for us. "Write automatically" is the owner's standing yes within a daily limit. A yes writes from the client's own mailbox. Follow-ups are automatic per the Setup choice. Replies are drafted and every answer needs the owner's yes (Today shows "They wrote back"). Required wording is printed in each note's footer.

**Mailbox privacy promise:** Orchestrate never reads or comments on unrelated mail in a client's inbox or sent folder (backend guard `orchestrate-never-reads-unrelated-mail.spec.ts`).

**Public site** (DD-26, DD-37): `/` front door, `/how-it-works` (One customer, start to paid), `/pricing`, `/trust`, `/about`, `/contact` (visitor assistant), `/diagnostics`, `/legal/*`, `/account-deletion`. Retired public addresses redirect to one of these.

**Operator console** (`lib/app/shell/operator_shell.dart`): Work queue (`/ops/work`, answers in place, DD-38), Authority, Clients, Contacts & imports, Transport, Dispatch, Campaigns, Message provenance, Audit history, Jobs, Inquiries, Feedback, Debug checks. Retired operator addresses land on `/ops/work` (`_retiredOperatorSurfaces`).

## Release baseline

- **2.1.0 (19)** submitted 4 Oct 2026, source `d8d45a3`, record `95fb7ef`: Microsoft LIVE and Google Play LIVE (both read from the store APIs 4 Oct 2026 · 9:08 PM ET), iOS build 19 through Codemagic TestFlight, submitted to App Review 4 Oct 2026 · 9:00 PM ET (automatic release on approval). Web deployed from `main` 4 Oct 7:55 PM ET. Record: `store_assets/release_notes/2.1.0.md`.
- 2.0.0 (17), 3 Oct 2026: the major transformation (DD-34 to DD-37). Record: `store_assets/release_notes/2.0.0.md`.
- Release toolchain: Flutter 3.47.2 at `C:\flutter-release-3.47.2` (`docs/RELEASE_TOOLCHAIN.md`). The global `C:\flutter` is a different version and gives false test failures ("Unsupported runtime stages format"). Run analyze and tests with the release toolchain.

## Rules that hold the current product

- Forward tolerance (`test/a_newer_server_needs_no_release_test.dart`): a server value this app does not know degrades to something generic and usable; it never forces a store release.
- Retired addresses stay retired (`test/navigation_promises_test.dart`, `test/router_redirect_integrity_test.dart`); every route the server names must be a page the app shows.

## RETIRED — do not rebuild (recorded 4 Oct 2026)

- Legacy client workspace and its names: Home, Operations, Opportunities, Leads, Replies, Meetings, Notifications, Infrastructure, Representation, Records, Billing, Settings, Business hub/identity, Mailbox, Credentials, Evidence, Artifacts, Branding, Subscribe, Workspace settings, Contacts inventory, Sequence author. Their jobs moved into Setup, Account, Customers and Money (DD-34, DD-35).
- Every `/app/*` address and every retired `/client/*` page: removed outright, not redirected (DD-36, `293f81a`).
- Widgets and surfaces deleted with them: `ClientSequenceAuthorScreen`, `MessageGovernancePanel`, `ClientBackendSurfaceScreen` on `/client/trust`, `WhyAffordance` and the guidance drawer, `ClientMomentumCard`, `ClientConfidencePanel`.
- The six-step setup (DD-26 first version) and the setup where the plan came before "Who acts for it": the plan is now last (`d5553ad`).
- The old public flagship lifecycle on Home (`PublicOverviewWidget`) and the public pages retired in DD-26 (`/product`, `/ai-governed-revenue`, `/lead-sourcing`, `/trust-architecture`, `/for-evaluators`, `/why-orchestrate`, `/answers`, `/journey/*`, newsletter and others), plus the four public knowledge feeds (`1c6e182`).
- The seven-faculty operator workspace (Cognition, Trust & Readiness, Continuity, Runtime Truth, Adaptation, Governance, Platform Supervision) and `/ops/overview`.
- Retired commercial packages: lanes, tiers (focused/multi/precision, opportunity/revenue), trials. Prices are $29.99 a month or $299.99 a year on the web; store builds show the store's own offer.
- Deleted 4 Oct 2026 (dead, never routed): `leads_screen.dart`, `meetings_screen.dart`, `client_replies_screen.dart`, `client_notifications_screen.dart`, `public_overview_widget.dart`, `commercial_execution_surface.dart`; the router's leftover `/app/*` and `/client/subscribe` names removed. Do not recreate them.

## Where truth lives

- Routes: `lib/app/routing/app_router.dart`. Navigation: `lib/app/shell/client_shell.dart`, `lib/features/client/widgets/command_palette.dart`.
- Design decisions: `company/docs/design/DESIGN_DECISIONS.md` (DD-26 to DD-39 for Orchestrate).
- Releases: `store_assets/release_notes/<version>.md`.
- Backend continuity: `../orchestrate_backend/audit/working-directory/`.

## Superseded

The 31 Aug 2026 version described the public Home flagship lifecycle (`aa46ec4` and earlier), release `0.2.2+11` and the ROS Phase II closeout (`a71b39e`, 13 Jul 2026). All of it is history; see git log.
