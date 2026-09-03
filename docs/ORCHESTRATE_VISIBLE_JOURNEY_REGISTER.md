# Orchestrate visible journey register

This register extends the public estate register across the visitor-to-product
boundary. Redirect aliases are recorded with their canonical destination rather
than treated as independent visual surfaces.

| Surface / state | Entry and purpose | Boundary / owner | Next / return | Disposition |
|---|---|---|---|---|
| `/`, public route family | Discover commercial execution and choose a path | PublicShell / Class A-D pages | `/product`, `/pricing`, `/auth/join`, `/intake` | CANONICAL |
| `/auth/login`, `/auth/join`, aliases | Authenticate or create client access while retaining plan/trial intent | AuthShell / focused auth | `/app/setup` or intended return | TRANSFORM |
| `/auth/verify-email` | Confirm account ownership | AuthShell / verification state | `/app/setup` or sign-in | TRANSFORM |
| `/auth/reset-password` | Recover account access | AuthShell / recovery state | `/auth/login` | TRANSFORM |
| `/ops/login`, `/ops/join`, aliases | Operator account entry | AuthShell / operator boundary | `/ops/overview` | TRANSFORM |
| `/app/setup`, `/client/setup` | Establish market scope and activation inputs | AuthShell + setup journey rail | `/app/subscribe` | TRANSFORM |
| `/app/subscribe`, `/client/subscribe` | Select execution scope and secure billing continuation | AuthShell + setup journey rail | `/client/overview` after activation | TRANSFORM |
| `/client/oauth/return` | Render mailbox authorization result and next action | ClientShell / OAuth state | setup or infrastructure | CANONICAL |
| `/client/overview`, `/app/home` | First operational product entry | ClientShell / converged workspace boundary | workspace navigation | TRANSFORM: operational content remains dense, but the receiving shell now inherits the Orchestrate dark canvas, identity and chrome |
| `/client/representation`, `/client/infrastructure`, `/client/records` | Complete identity, transport, readiness and records | ClientShell / authenticated workspace | `/client/overview` | EXEMPT_WITH_REASON: workspace UI, not public acquisition |
| loading / validation / error / retry / blocked / success states | Preserve state meaning during auth, setup, billing and OAuth | Owning route plus AuthShell or ClientShell | resume, back, or next action | CANONICAL |

## Shared journey ownership

- `PublicShell`: public canvas, public identity, header, commercial close,
  support, footer, and public scrolling.
- `AuthShell`: focused authentication and acquisition frame, dark Orchestrate
  identity, return-to-site path, setup journey context, and focused footer.
- `ClientShell`: authenticated workspace boundary and operational navigation.
- `AuthSessionController`: selection, trial, return intent, setup draft, and
  authenticated continuation authority.
- `ClientSetupScreen` and `ClientSubscribeScreen`: route-specific setup and
  billing content; they do not own global chrome.

The first workspace is not treated as an automatic exemption. Its operational
content remains a separate dense product programme, while `ClientShell` owns a
converged receiving boundary: identity, sidebar and page chrome around the
existing operational content and states.

The canvas itself changed with the workspace reconstruction. It was the dark
Orchestrate receiving canvas; it is now the light workspace ground, because the
reconstruction put dense operational content directly onto it and dark-on-dark
made the content pane unreadable. The boundary is unchanged — only what is
painted behind it.
