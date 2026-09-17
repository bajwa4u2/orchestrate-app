# Onboarding presentation corrections — 2026-09-17

Four presentation and friction defects found while mapping the Getting Started
walkthrough, plus one layout defect the fourth fix exposed. **Presentation and
routing only. No doctrine, entitlement, authority or pricing behaviour changed.**

Discovery that produced these: `representation/presentation/orchestrate/getting-started/`
(`…_DISCOVERY_2026-09-17.md`, POLISH 1–4).

---

## 1 — Setup ended at a paywall it does not mean

`client_setup_screen.dart` routed to `/app/subscribe` on save.

The router's own doctrine says subscription is **not a door**: a workspace is
reached by being authenticated and a member, and entitlement refuses an ACTION
at the capability boundary. The routing was already correct. The **sequencing**
contradicted it — a plan screen appeared at the exact moment the product had
just decided a plan was not required, which is the strongest possible statement
that it is.

**Now:** save → `/client/today`.

Plans remain reachable in Account and Billing, and the eligibility authority
still raises a subscription blocker when one genuinely stops execution. Nothing
about entitlement moved.

## 2 — Readiness had no completion signal

The product told a business what was missing and never told it when it was
finished. Completion was expressed only as the disappearance of the
*"Finish setting up your business"* row, so the moment someone completed setup
looked identical to the moment before they started. A new owner could not tell
*"I am done"* from *"I do not understand this screen."*

**Now:** an empty Today reads the one readiness authority
(`/client/execution-eligibility`) and says so.

- `TodayState.executionReady` returns true for the buckets that mean the
  preparation is behind them: `ready_to_execute`, `orchestrate_working`,
  `executing`.
- It returns **null, never false**, when eligibility did not answer or returned
  a bucket this build does not know. Today renders the completion state only on
  `== true`, so an unknown falls through to the existing quiet state.
- No new endpoint, no new state, no client-side recomposition of readiness.
  Recomposing is how two surfaces come to disagree about whether a business can
  send.

Copy: **"Your setup is complete."** / *"Your market and your sending are
configured, so Orchestrate can act. What it finds, and anything that needs a
decision from you, will appear here."*

## 3 — Two routes to one setup screen

`/app/setup` and `/client/setup` both resolved. The router redirected to the
first; Today linked to the second; the login screen used the first. Same
surface, two identities.

**Now:** `/client/setup` is canonical — every client surface is spelled
`/client/…` and setup is the first one anybody sees. `/app/setup` is kept as a
redirect so existing links, invitation emails and saved deep links resolve.
Changed in the router redirect, the route table and `client_login_screen.dart`.

## 4 — The first screen spoke in its own architecture

Header: *"Activate your revenue execution infrastructure."* The most abstract
sentence in the product, on the first screen where a new owner has to act.

**Now:** *"Set up your business."* The body paragraph says what the three
questions are and what the answers are used for, and that they can be changed.

## 5 — Setup rendered two sets of chrome (found while doing 3)

`/client/setup` sat inside the client `ShellRoute`, and `ClientSetupScreen`
returns an `AuthShell(setupFlow: true)`. Anyone reaching setup from Today
therefore got the workspace nav rail **and** the AuthShell header, footer and
setup journey rail around one form, with the content squeezed into what was
left. Three layout overflows fell out of it, reproduced in a widget test:

| Widget | Overflow |
|---|---|
| `client_shell.dart:591` — nav rail row | 16 px |
| `auth_shell.dart:132` — auth header row | 37 px |
| `client_setup_screen.dart` — industry field | 38 px |

This was live for every person who reached setup from Today; it was invisible
via `/app/setup`, which was already outside the shell.

**Now:** `/client/setup` is declared outside the shell, exactly where
`/app/setup` was. All three overflows are gone. Setup is a focused flow, not a
workspace destination — which is what `AuthShell.setupFlow` was built for.

---

## Verification

- `flutter analyze lib test` — clean.
- `flutter test` — **427 passing.** 8 failures, all of which fail identically on
  the unmodified `HEAD` (verified by stashing this work and re-running): they
  are pre-existing and unrelated. No test regressed.
- New: `test/onboarding_completion_signal_test.dart` — 10 tests covering the
  readiness buckets, the silence-rather-than-guess rule, the canonical route,
  and that setup no longer routes to checkout.
- Updated deliberately, with the reason in the file:
  `test/sign_in_landing_test.dart`, `test/workspace_entry_test.dart`.

## Still open — not fixed here

- **Sign-out is unreachable from setup.** Setup is outside the shell, so it has
  no sidebar sign-out. Already recorded in
  `docs/governance/CLIENT_WORKSPACE_END_TO_END_AUDIT.md`; the route move does not
  change it. The answer is a sign-out in the AuthShell header, not a shell
  around setup.
- **Eight pre-existing test failures** in `account_authority_reachability`,
  `attention_states`, `authority_gate`, `contact_readiness`,
  `engagement_containment`, `market_states`, `relationship_depth` and
  `store_purchase_order`. Present before this work; not investigated here.
