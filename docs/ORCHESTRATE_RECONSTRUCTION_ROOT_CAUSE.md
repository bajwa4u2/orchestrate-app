# Reconstruction failure root cause and prevention

## Why the defects passed

| Defect | Immediate cause | Why it survived | Preventive guard |
|---|---|---|---|
| Dark-on-dark public middle content | PublicShell moved the page substrate to dark, while transparent `PublicContentScreen` sections inherited light-theme dark text | Shell presence and first-viewport screenshots were treated as page completion; no descendant contrast assertion or full-scroll review existed | Every public chapter must own both surface and foreground tokens; full-page contrast review and static token checks are required |
| Unreadable diagnostics doctrine/source | Shared substrate annotations selected colors from `ThemeData.brightness`; PublicShell intentionally uses lightTheme for controls even on a dark canvas | Theme brightness was incorrectly treated as canvas brightness | Dark-surface annotation parameter is explicit and covered by public diagnostics conformance |
| Empty/unconstructed-looking destinations | Destination bodies were rendered as transparent/unowned content beneath a finished hero | Route registration and shared shell ownership were accepted as evidence of destination quality | Retained pages require top/middle/bottom evidence and a declared visual chapter owner |
| Redundant footer destinations | Footer was preserved from historical route inventory and comments, not a current visitor-purpose contract | Existing route was mistaken for current navigation purpose | Canonical footer contract plus test rejecting retired entries |
| Setup and Sign In collapsed | Unauthenticated router logic treated setup as a client-area route and defaulted all such routes to `/auth/login` | “Unauthenticated means login” was used as a universal redirect assumption; CTA intent was not modeled | Setup/subscribe intent is checked before generic client-area redirect and routes to registration with plan/tier/trial context |
| False convergence reports | Tests asserted shell/components/routes, not perceptual visibility, full-page completeness, click purpose, or next action | Structural evidence was reported as visual/product evidence | Separate route graph, clickable journey graph, and rendered evidence are now required |

## Permanent audit model

The authoritative model is:

`route graph + user-reachable action graph + rendered visual evidence`.

For each action, record source surface, label, intent, actual destination,
destination purpose, next actions, return path, and visual disposition. Flutter
canvas limitations do not remove actions from the audit; source action maps,
router behavior, pointer clicks, keyboard traversal, accessibility semantics,
and screenshots are combined.

## Required loop

`open → inspect top → scroll entire page → inspect every chapter → click every
action → inspect destination → return → continue → redeploy → repeat`.

Shell ownership, HTTP 200, route registration, and green tests are necessary
signals only; none is destination acceptance by itself.
