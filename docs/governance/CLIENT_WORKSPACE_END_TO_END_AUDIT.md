# Client Workspace End-to-End Audit

Audit date: 2026-04-29  
Scope: `/client/settings` and requested client left navigation tabs: Outreach, Replies, Meetings, Billing, Records, Notifications, Support, Settings, Sign out.  
Mode: controlled audit only. No source code was edited.

## A. Executive Summary

Overall health rating: **partial / not production-ready as an end-to-end client workspace**.

The backend has real client-scoped data models and several useful client endpoints, but the requested client tabs are unevenly wired. Outreach, Replies, Records, Notifications, and Settings are mostly generic endpoint surfaces, not finished operational screens. Meetings derives client meetings from `/replies` instead of a client meetings endpoint. Billing shows real invoices/subscription data but omits portal error handling and usage/limits. Support can create persisted client support inquiries through `/client/support/intake`, but there is no client-visible support history list.

Biggest blockers:

1. The client shell is desktop-only: `ClientShell` uses a fixed `Row` plus 284px sidebar and no drawer/bottom navigation for mobile.
2. Records nav points to `/client/agreements`; there is no `/client/records` route or unified records screen.
3. Outreach has no campaign list screen, no start/pause/retry actions, and no mailbox reconnect action; `/client/outreach` is a read-only generic endpoint viewer.
4. Replies has no detail/thread view; `/client/replies` only renders rows from `/replies`.
5. Meetings does not call `/meetings` because that backend route is operator-only; it extracts embedded meeting objects from `/replies`.
6. Notifications are history-only alerts from `/client/notifications`; there are no preference models, toggles, or save endpoints.
7. Settings does not render a true settings product surface; it calls `/clients/me/profile` and `/clients/me/setup` through a generic endpoint table and does not expose representation authorization records.
8. Billing portal action exists in repository/account screen, but `/client/billing` does not expose it and portal failures are not surfaced there.
9. Several frontend safe fallbacks swallow backend failures and convert them into empty data, which can hide contract or auth problems.
10. Sign out only clears local session storage and does not call `/auth/logout`.

Tab readiness:

| Tab | Readiness |
| --- | --- |
| Outreach | Partial / misleading |
| Replies | Partial |
| Meetings | Partial |
| Billing | Partial |
| Records | Partial / ambiguous |
| Notifications | Partial / history-only |
| Support | Partial |
| Settings | Partial / generic |
| Sign out | Partial |

## B. Route/API Matrix

| Tab | Frontend route | Component/screen | API calls | Backend handler | Data source | Status | Main gap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Outreach | `/client/outreach` | `ClientBackendSurfaceScreen(outreach)` | `GET /client/email-dispatches`, `GET /replies?limit=25`; follow-up section has no endpoints | `ClientPortalController.emailDispatches`, `RepliesController.list` | `DocumentDispatch`, `Reply`, related `Lead/Campaign/OutreachMessage/Meeting` | Partial | Generic read-only data; no campaign list, queue/follow-up/action state, mailbox reconnect, pause/retry/start actions |
| Replies | `/client/replies` | `ClientBackendSurfaceScreen(replies)` | `GET /replies?limit=50` | `RepliesController.list` -> `RepliesService.listForClient` | `Reply` plus related `Lead`, `Campaign`, `OutreachMessage`, `Meeting` | Partial | No reply detail/thread view, contact context panel, classification explanation, or supported actions |
| Meetings | `/client/meetings` | `MeetingsScreen` | `GET /replies` | `RepliesController.list`; `MeetingsController` is operator-only | Embedded `meeting` objects joined onto replies from `Meeting` | Partial | No client `/meetings` endpoint; does not show standalone meetings not linked to returned replies or calendar/provider status |
| Billing | `/client/billing` | `ClientHomeScreen(section: billing)` | `GET /client/overview`, `GET /client/notifications`, `GET /billing/subscription`, `GET /client/invoices` | `ClientPortalController.overview/invoices`, `BillingController.getSubscription` | `Client`, `Subscription`, `Invoice`, `Alert`, `DocumentDispatch` | Partial | No portal action, usage/limits, receipts/statements/agreements drill-in, or resilient error/retry UI |
| Records | `/client/agreements` from nav | `ClientBackendSurfaceScreen(agreements)` | `GET /client/agreements` | `ClientPortalController.agreements` | `ServiceAgreement` | Partial / ambiguous | Nav label says Records but route/screen only shows agreements; no unified records/imports/leads/legal docs surface, no view/download/export |
| Notifications | `/client/notifications` | `ClientBackendSurfaceScreen(notifications)` | `GET /client/notifications` | `ClientPortalController.notifications` | `Alert` | Partial | No preferences model/API, no toggles/save, no read/resolve behavior for clients |
| Support | `/client/support` | `ClientSupportScreen` | `POST /client/support/intake`, `POST /client/support/intake/:sessionId/reply` | `ClientSupportController`, `IntakeService`, `SupportCaseService` | `PublicInquiry`, `InquiryMessage`, `InquiryNote` | Partial | Submissions persist, but no ticket/history list, no reload of prior conversations, no operator response visibility in client UI |
| Settings | `/client/settings` | `ClientBackendSurfaceScreen(settings)` | `GET /clients/me/profile`, `GET /clients/me/setup`; auth section has no endpoint | `ClientsController.getProfile/getSetup` | `Client`, setup fields on `Client.scopeJson/selectedPlan/setupCompletedAt`; representation auth model exists | Partial | Generic rows only; no real profile/settings editor, no authorization record endpoint, badges are generic source availability |
| Sign out | Sidebar button | `ClientShell` local action | No API call | None used; backend has `AuthRepository.logout()` to `POST /auth/logout` | `SharedPreferences` key `orch_client_session_v1` | Partial | Local-only logout; no loading/error state; does not call server logout endpoint |

## C. End-to-End Flow Findings

### Outreach

Current state: `/client/outreach` loads a generic backend surface with dispatch rows and reply rows. It explicitly states follow-up lists are unavailable.

Evidence: `orchestrate_app/lib/app/routing/app_router.dart` maps `/client/outreach` to `ClientBackendSurfaceScreen(surface: outreach)`. `client_backend_surface_screen.dart` calls `/client/email-dispatches` and `/replies`. Backend handlers are `ClientPortalController.emailDispatches()` and `RepliesController.list()`. Backend data comes from `ClientPortalService.emailDispatches()` querying `documentDispatch`, and `RepliesService.listForClient()` querying `reply`.

Risks: The requested expectation says campaign list, create/start/pause/retry actions, mailbox connection/reconnect, and unsupported setup states should be meaningful. None of that is implemented on this tab. Dispatches are document dispatches, not necessarily outreach sends from `OutreachMessage`, so the label can be misleading.

Required implementation steps:

1. Add a dedicated client outreach repository/screen contract instead of the generic endpoint surface.
2. Add or expose client-scoped backend endpoint(s) for outreach execution: campaigns, outreach messages, queued sends, follow-ups, mailbox state, and supported actions.
3. Keep actions hidden/disabled unless backend returns capability flags.
4. Make start/retry/pause/reconnect call real backend endpoints or remove those actions from this tab.
5. Show blocked setup states from backend truth: setup incomplete, inactive subscription, missing representation authorization, no mailbox, mailbox reauth, no leads, consent/suppression blocks.

### Replies

Current state: `/client/replies` shows a generic table of `/replies` records.

Evidence: router maps `/client/replies` to `ClientBackendSurfaceScreen(replies)`. `RepliesController.list()` first attempts `requireClient(headers)` and returns `RepliesService.listForClient(clientId)`. `RepliesService.listForScope()` selects reply fields including `intent`, `confidence`, `requiresHumanReview`, `handledAt`, `bodyText`, then joins related lead, campaign, message, and meeting.

Risks: The UI has no reply detail route, no thread view, no explicit classification badge mapping, and no ability to inspect the linked contact/campaign/message in a client-safe way. Generic row formatting may expose the wrong fields first and hides useful thread context.

Required implementation steps:

1. Build a dedicated `ClientRepliesScreen`.
2. Add reply list DTO mapping in frontend: status, intent, confidence, review state, received time, contact, campaign, linked message, meeting.
3. Add a selected reply panel or detail route using existing `/replies` payload, or add `GET /client/replies/:id`.
4. Keep client actions minimal unless backend supports them.
5. Add clear empty state: replies appear after prospects respond to sent outreach.

### Meetings

Current state: `/client/meetings` calls `ClientMeetingsRepository.fetchMeetings()`, which calls `/replies` and extracts `reply.meeting`.

Evidence: `client_meetings_repository.dart` never calls `/meetings`; it reads `/replies`. `MeetingsController` requires operator access for `GET /meetings`. `MeetingsService.listOpenHandoffs(clientId)` exists but is not exposed by a client controller.

Risks: Meetings without a reply in the returned replies list will not appear. The frontend cannot query by status, date, or pagination. Calendar/provider state is absent. The empty state says meetings derive from reply/handoff activity, but there is no backend-backed booking flow explanation.

Required implementation steps:

1. Add `GET /client/meetings` backed by `Meeting` with client/organization scope.
2. Return status, scheduled time, booking URL, reply/lead/campaign context, and provider/calendar connection summary when available.
3. Update `ClientMeetingsRepository` to call `/client/meetings`.
4. Hide actions until backend supports reschedule/cancel/confirm.
5. Add empty state explaining that meetings appear after interested replies are classified and handed off/booked.

### Billing

Current state: `/client/billing` reuses `ClientHomeScreen(section: billing)`. It loads overview, notifications, subscription, and invoices. Billing portal support exists in `ClientBillingRepository.createBillingPortalSession()`, but this tab does not call it.

Evidence: `client_workspace_screen.dart` calls `workspaceRepo.fetchOverview()`, `workspaceRepo.fetchNotifications()`, `workspaceRepo.fetchSubscription()`, `billingRepo.fetchInvoices()`. Backend routes exist: `/client/overview`, `/client/invoices`, `/billing/subscription`, `/billing/portal`. `BillingService.createPortalSession()` throws if no Stripe customer is linked.

Risks: The billing tab does not surface external billing portal access, portal errors, receipts, statements, reminders, agreements, usage/limits, or plan capability limits. It links direct actions to legacy `/app/campaigns` and `/app/contacts`, not canonical `/client/*` routes.

Required implementation steps:

1. Replace reused home billing mode with a dedicated `ClientBillingScreen`.
2. Show subscription, plan/tier, status, period, trial, open balance, invoices, receipts/statements/agreements links.
3. Add billing portal button only when `/billing/portal` can succeed or show exact setup gap when unavailable.
4. Add usage/limits if backend exposes plan limits; otherwise document “not available yet” from backend contract.
5. Normalize invoice money/date/status display from real fields.

### Records

Current state: the sidebar label “Records” routes to `/client/agreements`. The route renders only agreements from `/client/agreements`. Separate routes exist for `/client/invoices`, `/client/receipts`, `/client/statements`, and `/client/reminders`, but the left nav does not expose them as separate tabs.

Evidence: `ClientShell._primaryItems` maps Records to `/client/agreements`. `_isSelected()` treats `/client/agreements`, `/client/statements`, and `/client/reminders` as Records but omits `/client/invoices` and `/client/receipts`. `ClientBackendSurface.receipts` has no endpoint even though backend has operator `/billing/receipts` and client portal service has no `receipts()` method.

Risks: Records are ambiguous: could mean imported contacts/leads, client setup records, legal agreements, statements, or authorization documents. There is no view/download/export behavior. Representation authorization exists in `ClientRepresentationAuth` but is not exposed.

Required implementation steps:

1. Decide records taxonomy: legal/service records, billing documents, import/source records, and authorization records.
2. Add `/client/records` route and screen.
3. Expose client endpoints for receipts and representation authorizations if they should be visible.
4. Add view/download/render links only for backend-supported document render/download endpoints.
5. Keep imported contacts/leads in Leads/Outreach unless records screen intentionally includes source/import batches.

### Notifications

Current state: `/client/notifications` lists client alerts from `/client/notifications` through a generic endpoint surface.

Evidence: `ClientPortalController.notifications()` returns `ClientPortalService.notifications()`, which queries `prisma.alert.findMany({ where: { organizationId, clientId } })`. `NotificationsController` has operator-only alert create/list/resolve endpoints. No notification preference model was found in the inspected schema excerpt or controllers.

Risks: The requested expectation includes preferences/history and toggle/save behavior. Current UI has no preferences and no client action to mark/resolve/read notifications. Generic rows can make resolved/open/severity/category unclear.

Required implementation steps:

1. Build a dedicated `ClientNotificationsScreen`.
2. Treat current alerts as notification history.
3. Add backend models/endpoints for preferences only if product requires toggles.
4. Otherwise do not show fake toggles; state that preferences are not configurable yet.
5. Add read/resolve behavior only if client authorization policy allows it.

### Support

Current state: `/client/support` is a real support intake/chat surface. It posts to client support endpoints and persists inquiries/messages through support services.

Evidence: `ClientSupportScreen` uses `SupportController(publicMode: false)`. `SupportService` posts to `/client/support/intake` and `/client/support/intake/:sessionId/reply`. `ClientSupportController` calls `requireClient()`, builds a client-context intake payload, and routes through `IntakeService.handlePublic()` with `source: 'CLIENT'`. `SupportCaseRepository` writes `PublicInquiry` and `InquiryMessage`.

Risks: Existing conversation state is in memory only in the current widget. Browser refresh loses the visible thread even though records persist. There is no list of prior tickets, no ticket status view, and no operator replies visible in the client workspace.

Required implementation steps:

1. Add `GET /client/support/inquiries` and `GET /client/support/inquiries/:id/thread`.
2. Render current and historical support requests with status, priority/category, last activity, and thread messages.
3. Preserve the current intake composer but attach it to persisted case/session data.
4. Show clear escalation/AI-resolved status from backend response.
5. Add retry/error states around submission.

### Settings

Current state: `/client/settings` uses generic endpoint sections for `/clients/me/profile` and `/clients/me/setup`. Representation authorization section has no endpoint.

Evidence: router maps `/client/settings` to `ClientBackendSurfaceScreen(settings)`. Backend has `ClientsController.getProfile()`, `getSetup()`, and `acceptRepresentationAuth()`, but no `GET /clients/me/representation-auth` endpoint. `ClientAccountScreen` has a richer profile editor at `/client/account`, but Settings does not use it.

Risks: Settings looks like a diagnostic endpoint viewer rather than a client account settings product surface. Badges only represent endpoint availability, not real setup/authorization state. Retry refetches generic endpoint data, but no user-facing settings save path is exposed on this route.

Required implementation steps:

1. Replace generic settings screen with a dedicated `ClientSettingsScreen`.
2. Reuse or move profile editor behavior from `ClientAccountScreen`.
3. Show setup state, selected plan/tier, billing status, record sources/import summary, mailbox state, and authorization state from explicit backend fields.
4. Add a read endpoint for representation authorization records.
5. Keep sign out action visible and consistent here and in the shell.

### Sign out

Current state: sidebar button calls `AuthSessionController.instance.clear()` and routes to `/auth/login`.

Evidence: `ClientShell` sign-out `TextButton` does not use `AuthRepository.logout()`. `AuthRepository.logout()` exists and posts `/auth/logout`, but backend controller behavior was not inspected in detail for logout persistence.

Risks: If backend adds revocation/session invalidation, sign out will bypass it. There is no disabled/loading state or failure handling. If both client and operator sessions exist, `clear()` removes only the key resolved from current surface.

Required implementation steps:

1. Route sign out through an auth service that attempts `/auth/logout` then clears local session.
2. Add loading/disabled state and guaranteed local cleanup on network failure.
3. Confirm behavior from every route and after refresh/direct URL entry.

## D. Cross-Cutting Audit

Client auth flow and token storage: `AuthSessionController` stores JSON in `SharedPreferences` under `orch_client_session_v1` and `orch_operator_session_v1`. API calls attach `Authorization: Bearer <token>` if present. Backend validates a custom signed HMAC session token in `AccessContextService`.

Client role/tenant/account resolution: backend `requireClient()` requires user, organization, and client context, then confirms the client belongs to the organization. If a client session lacks `clientId`, `buildFromHeaders()` can infer by matching membership email to `Client.primaryEmail`, `billingEmail`, `legalEmail`, or `opsEmail`.

Route guards and redirects: `GoRouter.redirect` blocks unauthenticated client routes, unverified email, incomplete setup, and inactive subscription. Some canonical `/client/*` routes are allowed before setup/subscription only for setup/billing/settings/account/campaign. Direct URL entry should execute the same redirect logic once `AuthSessionController.init()` has completed.

API base URL usage: `AppConfig.normalizedApiBaseUrl` defaults to `http://localhost:3000/v1` and uses compile-time `API_BASE_URL`.

Error normalization: `ApiException.fromResponse()` reads `message`/`error`, request IDs, and correlation IDs. `ApiClient` clears auth on 401/403. Generic `BackendSurfaceScreen` converts API failures into “not available” snapshots, which is useful for diagnostics but too vague for client product screens.

Loading states: generic surfaces show skeleton blocks. Meetings and billing/home use centered spinners. Support shows composer loading state. Loading is functional but inconsistent.

Empty states: generic surfaces have static empty labels. Meetings has a useful but broad empty label. Billing empty state only says no invoices. Notifications/settings/outreach empty states are not action-oriented enough.

Toast/banner feedback: campaign screen has snackbars and errors; generic surfaces have retry but no toast. Billing portal errors on account screen are not guarded with user-visible handling in the inspected method.

Button disabled/loading behavior: campaign actions track `_starting`, `_saving`, `_restarting`; support disables through `isLoading`. Sign out has no loading state. Generic retry is always enabled.

Backend validation errors surfaced to UI: `ApiException.displayMessage` can surface backend messages. Some repositories use safe fallbacks and swallow errors, especially overview/campaign/home composition paths.

401/403 handling: `ApiClient._decode()` calls `AuthSessionController.handleAuthFailure()` for 401/403. Generic surfaces then show source unavailable, while router should redirect after auth state changes.

Network retry behavior: no automatic retry strategy. Generic surfaces have manual Retry. Meetings/billing home do not expose retry buttons.

Data freshness/refetch strategy: no polling or live updates. Screens fetch on load; generic surfaces retry manually; campaign reloads after actions.

Left navigation active state: Records active state is inconsistent. `/client/agreements`, `/client/statements`, `/client/reminders` select Records; `/client/invoices` and `/client/receipts` do not select Records or Billing consistently.

Mobile/responsive shell: `ClientShell` is not mobile-ready because the outer layout is always a horizontal row with fixed sidebar. Inner panels often stack, but the shell itself will overflow or compress content on small screens.

Browser refresh/direct URL: GoRouter supports direct route definitions. Static hosting must rewrite all paths to Flutter `index.html`; this audit did not inspect deployment rewrite config. Auth session hydration depends on `SharedPreferences`.

Sign out from every route: shell-rendered `/client/*` routes get the sidebar sign-out. `/app/setup` and `/app/subscribe` are outside the shell and need separate sign-out handling if reachable during incomplete setup/subscription.

## E. Prioritized Execution Plan

### Phase 0: safety / branch / test baseline

1. Create a branch from the current frontend and backend repositories.
2. Record initial `git status --short` in both `orchestrate_app` and `orchestrate_backend`.
3. Run frontend `flutter analyze` and `flutter test`.
4. Run backend `npm run build` and `npm test`.
5. Capture any pre-existing failures before code changes.

### Phase 1: routing / auth / session correctness

1. Add a canonical `/client/records` route and make Records nav point there.
2. Fix active state grouping for Billing vs Records.
3. Decide whether legacy `/app/*` links should remain or redirect to canonical `/client/*` paths.
4. Add mobile navigation behavior to `ClientShell`.
5. Wrap sign out in a real logout flow: call backend logout if available, then clear local session and route to `/auth/login`.

### Phase 2: backend contract fixes

1. Add client-scoped meetings endpoint: `GET /client/meetings`.
2. Add client-scoped outreach endpoint(s): campaign list/current campaign, outreach messages, queued/follow-up summary, mailbox readiness, action capability flags.
3. Add client-scoped records endpoint: unified agreements/statements/reminders/receipts/representation auth/import summaries.
4. Add client support list/thread endpoints.
5. Add notification preferences endpoints only if toggles are required; otherwise keep notifications as history-only.
6. Add read endpoint for representation authorization records.
7. Review whether receipts should be exposed through `/client/receipts`.

### Phase 3: frontend data wiring per tab

1. Replace generic Outreach surface with `ClientOutreachScreen`.
2. Replace generic Replies surface with `ClientRepliesScreen`.
3. Update Meetings to call `/client/meetings`.
4. Replace Billing home reuse with `ClientBillingScreen`.
5. Build `ClientRecordsScreen` for the clarified records taxonomy.
6. Replace generic Notifications with `ClientNotificationsScreen`.
7. Extend Support to load persisted cases/threads.
8. Replace generic Settings with `ClientSettingsScreen`.

### Phase 4: action behavior and error states

1. Only show actions returned as supported by backend capability flags.
2. Add action loading/disabled states everywhere.
3. Surface validation errors with `ApiException.displayMessage`.
4. Add manual retry to every data screen.
5. Add action-specific success/failure feedback.
6. Remove or relabel any unsupported/no-op actions.

### Phase 5: responsive / live QA

1. Test all tabs at desktop, tablet, and mobile widths.
2. Verify text does not overflow inside nav, badges, buttons, and cards.
3. Verify browser refresh and direct URL entry on every `/client/*` tab.
4. Verify 401/403 redirects after token removal/expiry.
5. Verify empty states using a new client with no data and an active client with data.

### Phase 6: deployment verification

1. Confirm Flutter web build uses correct `API_BASE_URL`.
2. Confirm static hosting rewrites `/client/*` to `index.html`.
3. Confirm backend production env has auth token secrets, CORS origin, Stripe env, and webhook secrets.
4. Run smoke tests against deployed API for each tab endpoint with a client token.

## F. Exact Implementation Checklist

Likely frontend files to edit:

| File | Purpose |
| --- | --- |
| `orchestrate_app/lib/app/routing/app_router.dart` | Add `/client/records`; point requested tabs to dedicated screens; keep route guards intact |
| `orchestrate_app/lib/app/shell/client_shell.dart` | Fix Records route, active state grouping, mobile shell, sign-out flow |
| `orchestrate_app/lib/core/auth/auth_session.dart` | Adjust session clearing only if logout flow needs safer multi-surface cleanup |
| `orchestrate_app/lib/data/repositories/auth_repository.dart` | Use existing `logout()` from shell sign-out or harden it |
| `orchestrate_app/lib/data/repositories/client/client_outreach_repository.dart` | Add real outreach overview/messages/actions contract |
| `orchestrate_app/lib/data/repositories/client/client_meetings_repository.dart` | Change from `/replies` extraction to `/client/meetings` |
| `orchestrate_app/lib/data/repositories/client/client_billing_repository.dart` | Add receipts/portal availability/error helpers as needed |
| `orchestrate_app/lib/data/repositories/client/client_workspace_repository.dart` | Reduce silent fallbacks or expose typed errors for product screens |
| `orchestrate_app/lib/features/client/screens/client_backend_surface_screen.dart` | Remove requested tabs from generic use after dedicated screens exist |
| `orchestrate_app/lib/features/client/screens/meetings_screen.dart` | Render real client meetings endpoint, calendar/provider status, retry |
| `orchestrate_app/lib/features/client/screens/client_support_screen.dart` | Add persisted case/thread list and reload behavior |
| New `orchestrate_app/lib/features/client/screens/client_outreach_screen.dart` | Dedicated outreach product surface |
| New `orchestrate_app/lib/features/client/screens/client_replies_screen.dart` | Dedicated replies list/detail surface |
| New `orchestrate_app/lib/features/client/screens/client_billing_screen.dart` | Dedicated billing surface |
| New `orchestrate_app/lib/features/client/screens/client_records_screen.dart` | Unified records surface |
| New `orchestrate_app/lib/features/client/screens/client_notifications_screen.dart` | Notification history/preferences surface |
| New `orchestrate_app/lib/features/client/screens/client_settings_screen.dart` | Settings/profile/setup/auth surface |

Likely backend files to edit:

| File | Purpose |
| --- | --- |
| `orchestrate_backend/src/client-portal/client-portal.controller.ts` | Add client meetings, records, receipts, outreach, support history endpoints |
| `orchestrate_backend/src/client-portal/client-portal.service.ts` | Implement scoped Prisma queries and response DTOs for client surfaces |
| `orchestrate_backend/src/meetings/meetings.service.ts` | Reuse client-scoped meeting list logic or add helper |
| `orchestrate_backend/src/replies/replies.service.ts` | Add detail/thread helper if `/client/replies/:id` is implemented |
| `orchestrate_backend/src/support/client-support.controller.ts` | Add list/thread GET routes |
| `orchestrate_backend/src/support/support-case.service.ts` | Add client-scoped support list/thread methods |
| `orchestrate_backend/src/support/support-case.repository.ts` | Query `PublicInquiry`, `InquiryMessage`, and ownership safely |
| `orchestrate_backend/src/billing/billing.controller.ts` | Only if client receipts or portal availability need new endpoints |
| `orchestrate_backend/src/billing/billing.service.ts` | Add client-safe receipt/portal capability shape if needed |
| `orchestrate_backend/src/clients/clients.controller.ts` | Add representation auth read endpoint if kept under `/clients/me` |
| `orchestrate_backend/src/clients/clients.service.ts` | Query latest/list `ClientRepresentationAuth` |
| `orchestrate_backend/prisma/schema.prisma` | Only if notification preferences or new persisted settings are required |

## G. Verification Checklist

Commands identified from repo files:

Frontend:

```bash
cd orchestrate_app
flutter analyze
flutter test
flutter build web --release
```

Backend:

```bash
cd orchestrate_backend
npm run build
npm test
```

Runtime/manual QA:

1. Login as a client with setup incomplete; verify allowed routes and redirects.
2. Login as a client with inactive subscription; verify billing/settings/campaign access and other redirects.
3. Login as an active client; open `/client/outreach`, `/client/replies`, `/client/meetings`, `/client/billing`, `/client/records`, `/client/notifications`, `/client/support`, `/client/settings`.
4. Refresh browser on each route.
5. Paste each direct URL into a new browser tab.
6. Test mobile width for shell/nav and each tab.
7. Remove/expire token and verify 401/403 redirects.
8. Test sign out from each shell route.

Network/API checklist per tab:

| Tab | Verify |
| --- | --- |
| Outreach | Calls client-scoped outreach endpoints; no unsupported action fires; mailbox blocked/reauth states render |
| Replies | Calls reply list/detail; classification and review state match response; detail opens with contact/thread context |
| Meetings | Calls `/client/meetings`; statuses, dates, booking URLs, and empty state match backend |
| Billing | Calls subscription/invoices/portal; portal unavailable state is clear; invoice states/money render correctly |
| Records | Calls records endpoint(s); agreements/statements/receipts/auth/import records are clearly separated |
| Notifications | Calls alerts/history and preferences only if implemented; toggles persist or are absent |
| Support | Intake creates `PublicInquiry`; replies append `InquiryMessage`; refresh can reload persisted thread |
| Settings | Calls profile/setup/auth endpoints; displayed badges map to real fields; retry refetches |
| Sign out | Calls logout if implemented, clears local session, returns to `/auth/login` |

Validation performed during this audit:

- Read-only inspection commands were run across frontend and backend.
- No lint/test/build commands were run during this audit pass.
- The only intended file change is this report: `docs/CLIENT_WORKSPACE_END_TO_END_AUDIT.md`.

