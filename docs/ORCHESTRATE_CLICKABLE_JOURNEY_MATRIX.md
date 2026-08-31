# Orchestrate clickable journey matrix

This matrix records browser-observed visitor actions. Destination acceptance is
based on opening and visually inspecting the rendered destination, not on HTTP
status or route registration alone.

| Source surface | Visible action | Observed destination | Judgment / next action |
|---|---|---|---|
| Public header | Execution | `/product` | Purposeful product explanation; continue to activation CTA |
| Public header | Readiness | `/how-it-works` | Purposeful readiness/lifecycle explanation |
| Public header | Signals | `/lead-sourcing` | Purposeful signal/qualification explanation |
| Public header | Trust | `/trust-compliance` | Purposeful trust surface |
| Public header | Plans | `/pricing` | Purposeful commercial decision surface |
| Public header | Talk to us | `/intake` | Purposeful conversation path |
| Public header | Sign in | `/auth/login` | Existing-account authentication |
| Public header | Start setup | `/auth/join` | Registration-first acquisition |
| Public footer | Product | `/product` | Retained; distinct product explanation |
| Public footer | Signals and sourcing | `/lead-sourcing` | Retained; distinct qualification explanation |
| Public footer | Activation journey | `/how-it-works` | Retained; readiness path |
| Public footer | DNS readiness check | `/diagnostics` | Retained; signup-free live readiness check |
| Public footer | Operational answers | `/answers` | Retained; curated product answers |
| Public footer | Trust + compliance | `/trust-compliance` | Retained; trust hub |
| Public footer | Trust architecture | `/trust-architecture` | Retained; technical trust explanation |
| Public footer | For evaluators | `/for-evaluators` | Retained; evaluation path |
| Public footer | Acceptable use | `/legal/acceptable-use` | Retained; legal/policy surface |
| Public footer | Terms / Privacy / Service agreement | canonical legal routes | Retained; document surfaces |
| Public footer | Billing / Refunds / Account deletion | canonical legal/account routes | Retained; operational/legal purpose |
| Public header / pricing CTA | Start setup / trial | `/auth/join` when unauthenticated | Registration carries plan, tier, and trial intent |
| Direct setup deep link | `/app/setup`, `/client/setup` | `/auth/join` when unauthenticated | Corrected from sign-in to registration-first |
| Auth | Create workspace | setup continuation | Registration explains verification and setup continuation |
| Auth | Sign in | intended authenticated destination | Existing-account path; intent preserved by router query context |

## Retired from footer

`Why Orchestrate exists` and `How Orchestrate operates` were removed from the
footer because they duplicated the primary product/readiness journey. Their
routes remain available for contextual links where they have a specific reason
to exist.

## Browser evidence

The audit opened the retained footer destinations and captured their rendered
top surfaces at 1440 px. The full-page visual loop must continue for any newly
added public destination; a route must not be accepted solely because it
returns 200 or mounts `PublicShell`.
