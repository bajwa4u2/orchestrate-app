# Orchestrate public visual surface register

This register is the route-level contract for the public visual system. Every
listed route is mounted through `PublicShell`; the route decides the intensity
and visual chapter, while the shell owns the header, closing sequence, support
ecosystem, footer, and mobile navigation.

| Route family | Purpose / boundary | Class | Primary mechanism | Close / mobile |
|---|---|---:|---|---|
| `/` | Product front door / public | A | Commercial objects, lifecycle state graph, recovery, signals, revenue records, bounded AI | Home close + shared support/footer; compact object stack |
| `/product` | Product explanation / public | A | Execution-object chapter | Shared commercial close; responsive |
| `/how-it-works` | Activation/readiness / public | A | Selectable commercial state machine | Shared commercial close; responsive |
| `/ai-governed-revenue` | AI role / public | B | AI → policy → business-authority sequence | Shared commercial close; responsive |
| `/lead-sourcing` | Signals and qualification / public | B | Inputs → qualify → opportunity | Shared commercial close; responsive |
| `/trust-compliance` | Trust and operating conditions / public | B | Hold, condition, recovery, execute | Shared commercial close; responsive |
| `/pricing` | Commercial decision / public | C | Pricing and activation clarity | Shared commercial close; responsive |
| `/intake`, `/contact` | Conversation / public | C | Relationship CTA and support drawer | Contact-specific close; mobile drawer |
| `/about` | Product/company relationship / public | D | Connected commercial records | Shared commercial close; responsive |
| `/why-orchestrate`, `/how-orchestrate-operates`, `/trust-architecture`, `/for-evaluators` | Editorial/deep explanation / public | B/D | Canonical dark hero + editorial sections | Shared commercial close; responsive |
| `/diagnostics`, `/answers`, `/faq`, `/security-evaluation` | Readiness/evaluation / public | B/C | Existing qualified explanation inside shell | Shared commercial close; responsive |
| `/legal/*`, `/terms`, `/privacy`, `/account-deletion`, `/newsletter` | Policy, account, and institutional surfaces / public | E | Quiet document framing | Shared support/footer; no cinematic treatment |
| `/auth/*`, `/ops/*`, `/app/*` | Authentication/workspace / auth | Outside public estate | Application shell and auth boundary | Not governed by public visual register |

## Shared primitives

- `PublicShell`: canonical header, mobile navigation, public page frame,
  commercial closing band, support ecosystem, and footer.
- `execution_visual_chapters.dart`: product-native object, state, recovery,
  revenue, signal, AI-authority, and governed-support visual primitives.
- `PublicContentScreen`: canonical public hero and editorial/document section
  framing for route-specific content.
- `assets/branding/support/`: governed Company-sourced official support marks.

The public system does not use customer metrics, fabricated activity, stock
imagery, or text-only sponsor pills as visual proof.
