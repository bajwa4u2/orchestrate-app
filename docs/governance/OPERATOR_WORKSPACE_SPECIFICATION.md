# Operator Workspace Specification

Version 1.0 · 2026-05-19
Authority: governance · binds operator-surface engineering

This document is the doctrine for Orchestrate's operator workspace. It complements `SYSTEM_GUIDANCE_SPECIFICATION.md` (client + guidance doctrine) and `ORCHESTRATE_OPERATIONAL_FULFILLMENT_DIRECTIVE.md` (operational truth). Where this document conflicts with either, the more conservative reading wins.

The operator workspace is not a CRM, not an admin panel, not a queue inspector, not a JSON browser, not a chatbot dashboard, not a metrics wall, not a duplicate of the client surface with more buttons. It is the **supervision console for autonomous revenue infrastructure**.

---

## 1. Position

**Orchestrate is adaptive operational revenue infrastructure.** The system runs itself — deterministic checks first, learned memory second, AI only on residual uncertainty. The operator workspace exists to let trained operators *supervise* that autonomous system: see what it is doing, see what it is observing and learning, see what is deferred to a human, and intervene only where the system explicitly defers.

Operators do not operate the system. The system operates itself. Operators supervise.

This position must hold across every operator surface, copy line, control affordance, and information density choice.

---

## 2. The Seven Operator Faculties

The operator workspace is organized around what an operator must be able to *know* and *decide*, not around backend services. The faculties replace the prior five-group navigation. Every operator surface must declare which faculty it belongs to.

| # | Faculty | What it answers | Authority |
|---|---|---|---|
| F1 | Cognition | What is the system thinking, observing, and learning right now? What deserves attention before any tab is opened? | Read |
| F2 | Trust & Readiness | For every client and campaign, is the seven-state readiness gate cleared, blocked on the client, blocked on us, or in recovery? What is the trust posture (mailbox, identity, DNS, vault)? | Read |
| F3 | Continuity | Is governed dispatch flowing? Where is it blocked? When will it converge? Is pacing / retry / recovery doing its job autonomously? | Read + narrow recovery levers |
| F4 | Runtime Truth | What is the observed behavior of providers, mailboxes, throughput, deliverability, warmup, engagement, recovery — independent of what was configured? | Read |
| F5 | Adaptation | What has the cognition layer learned? What playbooks fired? What policy adjustments are proposed? What did self-healing do? What is the cost utilization? | Read + accept / reject + activate / disable + rollback |
| F6 | Governance | What needs operator approval, intervention, or audit review right now? | Read + approve + intervene + audit |
| F7 | Platform Supervision | Across all tenants supervised, what systemic risks, provider incidents, or cross-tenant patterns matter today? | Read (platform operator role only) |

Surfaces that do not fit a faculty either belong on the developer drawer (below the IA fold) or do not belong on the operator workspace at all.

---

## 3. Principles That Bind Every Operator Surface

### 3.1 Supervision-first, intervention-second

Every screen renders **what the system is doing autonomously** first, **what defers to the operator** second, **intervention controls** last. Intervention surfaces appear only where the system has explicitly deferred (e.g., `PolicyAdjustmentSuggestion.status = PROPOSED`, an AI decision pending approval, a recovering subsystem awaiting confirmation). They never appear as ambient "manage this" controls.

### 3.2 Deterministic > memory > AI (rendered in that order)

Mirrors the cognition layer order pinned by `architecture-self-ai-learning`. On any surface that mixes sources:

1. Deterministic state (readiness, continuity, runtime truth, audit) renders first.
2. Learned memory (`OperationalMemory`, confirmed `RuntimePattern`) renders second, tagged `learned`.
3. AI-derived suggestions (`PolicyAdjustmentSuggestion`, AI decisions) render last, tagged `suggested`, and always carry reversibility metadata.

Operators must be able to tell at a glance which row came from which layer.

### 3.3 Four-question contract is universal

Every operator surface that displays a state answers, on demand:

1. **What state am I in?**
2. **Why am I in it?**
3. **Who owns the next step?**
4. **What changes when?**

This is the same contract from `SYSTEM_GUIDANCE_SPECIFICATION.md §6.1`. The operator surface honors it via an operator-port of the `WhyAffordance` widget and a guidance drawer that reads operator-scoped explain endpoints. Free-text chat is forbidden.

### 3.4 Push, not pull

The shell carries attention badges on each faculty group. Active blockers, breached cost guardrails, pending suggestions, healing rollback opportunities, AI approvals pending, and platform-wide incidents push to the shell. Operators must never have to visit every tab to verify nothing is on fire.

Badge counts are deterministic (rule-ordered), debounced (no flap), and read from the cognition composition endpoint.

### 3.5 Auditable everything

Every operator action and every system decision rendered in the workspace is **one click from its `AuditLog` row**, with request id, decision id, and provenance trace. The audit timeline (Governance faculty) is queryable and operator-grade — not a backend-only forensic surface.

### 3.6 Honest before pretty

No fabricated metrics, no success theater, no decorative pills that claim live state without proof. If a subsystem is degraded, the surface says so plainly (`ORCHESTRATE_OPERATIONAL_FULFILLMENT_DIRECTIVE §5.1`). If platform supervision is not provisioned for an operator, the surface says so plainly.

### 3.7 No JSON in nav

Raw endpoint browsers are debug-grade and belong in the developer drawer, never as top-level supervision routes. JSON viewers are read-only inspection of a single endpoint, not a faculty.

### 3.8 No worker mechanics at supervision altitude

Queues, workers, jobs, dead-letter plumbing, backoff exponentials, lease semantics — these are engineering primitives, not supervision concerns. They surface as **drill-down detail inside Continuity** when an operator needs them, never as top-level IA. The mental model the IA reinforces is "continuity health," not "operate the worker pool."

### 3.9 Vocabulary discipline

Disallowed terms from `SYSTEM_GUIDANCE_SPECIFICATION.md §5.2` do not appear in operator copy. Operator-specific vocabulary that the doctrine approves:

- **continuity health** — composite of dispatch flow + recovery + pacing + blocked work
- **trust posture** — composite of mailbox + sending identity + DNS + vault adapter state
- **cognition feed** — composed, ordered surface of patterns / suggestions / healing / guardrail breaches / recovery events / cost anomalies / blockers
- **governed adaptation** — operator-gated playbook activation and policy suggestion acceptance
- **attention** — what the system defers to the operator (not "alerts")
- **supervision** — what operators do (not "operate", not "manage", not "control")

New vocabulary earns approved status by addition to this spec, not by accretion in code.

### 3.10 Platform operator ≠ tenant operator

The role model expresses scope. A **tenant operator** supervises one organization. A **platform operator** supervises across organizations (Platform Supervision faculty). Routes, endpoints, and surfaces must respect this distinction. Cross-tenant reads require platform-operator role; tenant operators see an honest empty state on Platform Supervision.

### 3.11 No fragmented IA

The seven faculties are the IA. Surfaces that legitimately exist but do not fit (one-off debug tools, deprecated routes, single-customer artifacts) live in the developer drawer or are removed. The IA must not drift into a junk-drawer "Business" group again.

### 3.12 Read-only by default

Every operator endpoint is read-only unless it accepts / rejects / activates / disables / rolls back something the system has explicitly surfaced for that purpose. The workspace does not enable direct mutation of learning rows, audit rows, or readiness state. Mutations flow through governed accept / activate / rollback paths that themselves create audit rows.

---

## 4. Information Architecture

### 4.1 Shell layout

```
ORCHESTRATE OPERATOR · [Org switcher · platform-op only]
─── Trust ribbon (always visible) ───
  Vault: <adapter> · Providers: <h/total> · DNS: <verified/total> · OAuth: <reauth count>

[F1] COGNITION                                  [attention count badge]
        Home (cognition center)

[F2] TRUST & READINESS                          [client-required count]
        Readiness state board (7 buckets)
        Trust posture
        Authorization continuity

[F3] CONTINUITY                                 [recovering count]
        Execution continuity
        Recovery & retries
        Pacing & throttling
        Blocked work
          └─ Drill: queues / jobs / workers

[F4] RUNTIME TRUTH                              [provider degraded count]
        Providers
        Mailboxes (per-mailbox detail + OAuth timeline)
        Sending identity (per-domain DNS history)
        Deliverability
        Throughput & latency

[F5] ADAPTATION & COGNITION                     [pending suggestions count]
        Learning feed
        Operational memory
        Patterns
        Suggestions
        Playbooks
        Self-healing
        Cost guardrails

[F6] GOVERNANCE                                 [pending approvals count]
        Dispatch governance
        AI decision approvals
        Audit timeline
        Inquiries

[F7] PLATFORM SUPERVISION                       [systemic incident count]
        Cross-tenant risk
        Provider-wide incidents
        Org footprint

──────── below the IA fold ────────
Developer drawer:
  Backend surfaces (raw JSON viewers)
  System Doctor (manual diagnose)
  Debug / system checks
  Suppression editor
Settings · Sign out
```

### 4.2 Landing

Operator login lands on **`/ops/overview` (Cognition Home)**. This URL is preserved from the legacy shell so deep links still work; the page composition is replaced.

### 4.3 Legacy routes

All legacy operator routes are preserved as **redirects** to their new faculty home. No legacy route is removed in this pass. Old paths resolve; mental model evolves. Examples:

- `/operator/jobs` → `/ops/continuity/blocked-work?drill=jobs`
- `/operator/queues` → `/ops/continuity/blocked-work?drill=queues`
- `/operator/workers` → `/ops/continuity/blocked-work?drill=workers`
- `/operator/ai-governance` → `/ops/adaptation/suggestions`
- `/operator/sources` → `/ops/runtime-truth/providers`
- `/operator/system` → `/ops/developer/backend-surface?surface=system`

---

## 5. The Cognition Home Composition Contract

Cognition Home is the radar. Its contract:

### 5.1 Trust ribbon (always-on, shell-wide)

A single ribbon at the top of every operator screen, reading from real services:

- **Vault**: adapter name (`encrypted-db` / `hashicorp` / `memory`). Production-misuse cases (`memory` in prod) render in warning tone.
- **Providers**: `h / total` healthy from `/providers/status`.
- **DNS**: `verified / total` from sending-identity rollup.
- **OAuth**: count of mailboxes flagged `requires-reauth`. Non-zero counts render in attention tone.

### 5.2 Composed feed (deterministic order, push-driven)

The feed is composed by `OperatorCognitionService` and delivered by `GET /operator/cognition/home`. Ordering is rule-based, not ML-ranked:

1. Cost guardrail breaches (active)
2. Self-healing actions awaiting confirmation
3. AI decisions pending approval
4. Policy adjustment suggestions (status `PROPOSED`)
5. Recently confirmed patterns (within 24h)
6. Recent self-healing actions (within 24h)
7. Recent recovery events (within 24h)

Each row carries: source row id, faculty link, four-question payload reference, and (when applicable) the operator-action endpoint.

### 5.3 Attention queue

What defers to the operator right now:

- Pending AI approvals
- Pending policy adjustment suggestions
- Readiness blockers owned by the operator (`orchestrate_blocked_internal`)
- Self-healing actions awaiting confirmation
- Cross-tenant incidents (platform operator only)

### 5.4 Continuity health summary

- In-flight dispatch (count + rate over rolling window)
- Blocked continuity, categorized by reason
- Retry convergence ETA per blocked cohort (best-effort; honest "unknown" allowed)
- Pacing headroom per active campaign (best-effort)

### 5.5 Runtime truth highlights

- Provider health summary
- Throughput delta vs baseline
- Deliverability deltas

### 5.6 Active adaptations

- Playbooks fired today
- Suggestions queued
- Guardrails currently armed
- Self-healing actions today

### 5.7 Recent operator activity

Attributed operator actions in the last 24h. Read from `AuditLog`.

### 5.8 Forbidden on Cognition Home

- "Sent today / Replies today / Booked today" counters at the top (these are outputs, not cognition; they live in Continuity and Truth).
- "Activate / Run now / Dispatch due jobs" buttons in the hero (intervention surfaces are reached via attention rows that carry full context).
- Raw JSON.
- Fabricated "Live" or "Healthy" pills.

---

## 6. The Four-Question Contract Applied to Operator Surfaces

Every operator state surface (readiness, continuity, mailbox, sending identity, provider, playbook, suggestion, healing action, guardrail) carries an inline `WhyAffordance` widget that opens a guidance drawer pre-seeded with the target. The drawer reads from operator-scoped explain endpoints under `/operator/guidance/*` (added by this spec). Drawer contract is identical to the client-side drawer: right-side, deliberate, system-framed, no persona, no chat, no auto-open.

Operator-specific guidance targets:

- `readiness-board` — explains the seven-bucket board state for the current scope
- `continuity-summary` — explains the continuity composition for the current scope
- `runtime-truth-overview` — explains the runtime truth composition
- `playbook-execution` — explains a specific playbook execution
- `policy-suggestion` — explains a specific suggestion (why proposed, evidence, reversibility)
- `self-healing-action` — explains a specific action and its rollback envelope
- `cost-guardrail-breach` — explains a breach (signal, threshold, recommended action)

---

## 7. Self-AI Surfaces

The Adaptation faculty hosts seven subsurfaces, one per row of the learning substrate. Each follows the same template (list + detail + provenance + operator action). The doctrine `architecture-self-ai-learning` is binding.

| Subsurface | Reads | Operator action | Reversibility |
|---|---|---|---|
| Learning feed | `GET /operator/learning/events` | Read, filter | n/a (append-only) |
| Operational memory | `GET /operator/learning/memory` | Read, filter | n/a |
| Patterns | `GET /operator/learning/patterns` | Read; status set automatically | n/a |
| Suggestions | `GET /operator/learning/suggestions` + accept/reject | Accept / Reject with notes | acceptance creates a `SelfHealingAction` (reversible) |
| Self-healing | `GET /operator/learning/healing-actions` | Inspect; rollback narrow-blast actions | rollback is a new audit row |
| Cost guardrails | `GET/POST /operator/learning/guardrails` | Configure thresholds; view utilization | edits are new revisions; previous revisions preserved in audit |
| Playbooks | `GET /operator/learning/playbooks` + executions + activate/disable/archive/rollback | Lifecycle ops with required `automationLevel` and notes; `LEVEL_3` blocked in UI | activation reversible; execution rollback creates new audit row |

The UI never mutates a learning row directly. It accepts / rejects / activates / rolls back, which themselves create new rows. `factsJson` may be rendered raw (doctrine guarantees it carries no credentials, no message bodies, no PII).

Cognition Home composes only the subset relevant to "what needs my attention now"; the Adaptation surfaces hold the full record.

---

## 8. Trust Ribbon, Attention Badges, Push Channel

### 8.1 Trust ribbon refresh cadence

The trust ribbon refreshes every 60 seconds (poll) by default. A push channel (SSE) is acceptable in a later phase but not required; the spec mandates only that the ribbon never claims state it cannot prove.

### 8.2 Attention badges

Each faculty group carries one badge:

- Cognition: composed attention count
- Trust & Readiness: client-required count
- Continuity: recovering + blocked count
- Runtime Truth: degraded provider count
- Adaptation: pending suggestions + breached guardrails
- Governance: pending approvals
- Platform Supervision: cross-tenant incidents (platform op only)

Badges are read from the same composition endpoint as Cognition Home. Counts are zero-truthful (zero is shown as no badge, not "0").

### 8.3 Sidebar layout

The shell renders faculty groups in the order F1–F7. Each group carries its label, badge (if non-zero), and its items. Items render attention indicators only when the system has explicitly deferred something to the operator within that item.

---

## 9. Backend Composition Endpoints (Spec)

This spec defines the endpoints; the implementation lives in `src/operator-cognition/` (new module). All endpoints are operator-auth gated via `requireOperator()` and respect organization scope.

### 9.1 `GET /operator/cognition/home`

Returns the composed Cognition Home payload:

```
{
  trustRibbon: {
    vault: { adapter: string, warning: boolean },
    providers: { healthy: number, total: number },
    dns: { verified: number, total: number },
    oauthReauthRequired: number
  },
  attention: { totalCount: number, byFaculty: Record<string, number> },
  feed: Array<CognitionFeedItem>,
  continuityHealth: { inFlight: number, blockedByReason: Record<string, number>, recovering: number },
  truthHighlights: { providers: ProviderSummary[], throughput: ThroughputDelta, deliverability: DeliverabilityDelta },
  activeAdaptations: { playbooksFiredToday: number, suggestionsPending: number, guardrailsArmed: number, healingToday: number },
  recentOperatorActivity: Array<AuditEntry>
}
```

### 9.2 `GET /operator/readiness/board`

The canonical seven-bucket readiness board. Returns per-client rows mapped to one of `client_action_required`, `orchestrate_working`, `ready_to_execute`, `executing`, `recovering`, `degraded`, `orchestrate_blocked_internal` (the buckets pinned by `operational-readiness.types.ts`).

### 9.3 `GET /operator/continuity/summary`

Composes execution continuity at supervision altitude:
- In-flight dispatch count
- Blocked work by reason
- Recovery events in last 24h
- Pacing headroom per active campaign (best-effort)

### 9.4 `GET /operator/runtime-truth/overview`

Composes runtime truth:
- Provider health
- Mailbox health rollup
- Sending identity rollup
- Throughput summary
- Deliverability summary
- Recovery effectiveness summary

### 9.5 `GET /operator/audit/events`

Queryable `AuditLog` read for the operator's organization. Supports filtering by `action`, `actorUserId`, `resourceType`, time window. Returns metadata only — never credentials, never message bodies (doctrine).

### 9.6 `GET /operator/guidance/explain/*`

Operator-scoped guidance explain endpoints, mirroring the client `/client/guidance/explain/*` contract. Targets enumerated in section 6.

---

## 10. Never-Regress Constraints (Operator-Specific)

These bind every change to the operator surface from this spec forward:

1. **Seven faculties or none.** Adding a new top-level operator nav item that doesn't belong to a faculty is forbidden. If a new capability emerges, find its faculty or update this spec.
2. **No JSON in nav.** Raw backend-surface browsers go in the developer drawer.
3. **No worker mechanics at supervision altitude.** Queues / workers / jobs are drill-downs inside Continuity.
4. **No campaign manager.** Operator does not become a campaign builder. The current `Campaign.status = START / PAUSE / RESUME` dormant enum stays dormant; no operator UI may surface these values as actions.
5. **No fabricated state.** Every claim on every operator surface reads from a real backend source. If a source is unavailable, the surface says so.
6. **No chat / chatbot.** Operator guidance is drawer-only, system-framed, four-question contract. Free-text chat is forbidden.
7. **No platform-operator endpoints without role scope.** Cross-tenant reads must be gated by platform-operator role.
8. **Audit-everything posture.** Operator actions create AuditLog rows; operator UI exposes the audit timeline; operators can navigate from any surface to the underlying audit rows.
9. **Vault abstraction inviolate.** Operator never sees plaintext credentials. Trust ribbon shows adapter name only.
10. **Reversibility tagged.** Anything operator-acceptable (suggestion accept, playbook activate, healing rollback) is tagged with its reversibility envelope in the UI.

---

## 11. Phasing (Internal)

Spec adoption ships in one coherent landing pass:

- Phase 0 (this document) — doctrine.
- Phase A (backend) — `operator-cognition` module + composition endpoints (additive, no schema change).
- Phase B (Flutter shell) — seven-faculty shell + trust ribbon + attention badges + legacy redirects.
- Phase C (Flutter screens) — Cognition Home, Trust & Readiness board, Continuity, Runtime Truth, Adaptation hub (all seven subsurfaces), Governance extension (audit timeline + AI approvals), Platform Supervision (honest empty state until role provisioned).
- Phase D (operator guidance drawer) — operator-port of WhyAffordance + drawer + operator-scoped explain endpoints stubbed against existing guidance service.

Phases A–D ship as a single coherent evolution. No phased UX drift is acceptable.

---

## 12. Doctrine cross-references

- `SYSTEM_GUIDANCE_SPECIFICATION.md` — bound: §4.1 drawer, §5 vocabulary, §6.1 four-question contract, §9 AI boundaries, §10 never-regress.
- `ORCHESTRATE_OPERATIONAL_FULFILLMENT_DIRECTIVE.md` — bound: §5.1 operational truth, §6 mandatory operational priorities, §14.4 known operator-related risks.
- `architecture-mailbox-identity` — bound: vault abstraction, readiness centralization.
- `architecture-self-ai-learning` — bound: deterministic > memory > AI ordering, append-only, nothing auto-applies.
- `product-philosophy-managed-infra` — bound: client surface does not grow back; operator owns infrastructure.

---

End of specification.
