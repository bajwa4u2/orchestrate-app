# Orchestrate — App Review Resubmission Package

App: **Orchestrate** · Bundle ID: `com.orchestrateops.app` · Version **0.1.3 (5)**

This document covers the four App Review findings, the exact code changes that
resolve them, the reviewer-credentials structure, the App Review "Notes" text,
and the operator runbook + submission checklist.

> ⚠️ The backend changes must be **deployed to production** and the reviewer
> accounts **seeded** *before* the new TestFlight build is submitted — the app
> calls the new backend endpoints. See the runbook at the end.

---

## Finding 1 — Login failure ("We could not complete that request.")

**Root cause.** The login screen's error mapper collapsed *every* unrecognized
error — including the backend's `"Please verify your email first"`, network
failures, timeouts, HTTP 429, and HTTP 5xx — into the single generic string. A
reviewer creating a new account (or hitting any transient error) saw a dead end
with no next step.

**Fix (client).** `lib/features/auth/screens/client_login_screen.dart`
`_humanize()` / `_humanizeCodeError()` now map distinct, actionable messages:
- **Email not verified →** "Please verify your email first. Open the
  confirmation link we emailed you, then sign in…"
- **Network / connectivity →** "We could not reach Orchestrate. Check your
  internet connection and try again."
- **Timeout →** "The request timed out…"
- **Rate limit / 429 →** "Too many attempts. Please wait a moment…"
- **Server 5xx →** "Something went wrong on our end…" + a support reference id.
- Known 4xx surface the backend's own message instead of the generic fallback.

**How App Review tests it.** Use the pre-seeded reviewer accounts below — they
are **pre-verified** and use a deterministic, OTP-free login (no email access
needed). Do **not** create a brand-new account; reviewers cannot receive the
verification email.

## Finding 2 — Reviewer access to subscription lifecycle (active + expired)

The backend has an env-gated, allowlisted, time-boxed **review-safe login**
(`src/auth/review-mode.ts`) that lets allowlisted reviewer emails sign in
**without an email OTP**. Seeding now produces **two** accounts:

- **Active account** — full workspace access (TRIALING reviewer subscription).
- **Expired account** — `Subscription.status = EXPIRED`; lands in the
  restricted-access experience. (`scripts/create-reviewer-account.js` now honors
  `REVIEWER_SUBSCRIPTION_STATE=expired`.)

**Expired experience (no dead end).** After login the workspace loads and the
Billing screen shows **Status: Expired** with a restricted-access state. On iOS
the app shows a plan-management notice (External purchases are disabled per
Guideline 3.1.1 — see Finding 4); there is no broken purchase button.

## Finding 3 — Account deletion (Guideline 5.1.1(v))

**Before:** only a reversible **Deactivate** existed.
**Now:** a permanent, in-app **Delete account** flow.

- **App:** Client workspace → **Account** → **Delete account** → type `DELETE`
  to confirm. (`client_account_screen.dart`, `client_account_repository.dart`.)
- **Backend:** `POST /clients/me/delete` → `ClientsService.deleteAccount()`
  (`src/clients/clients.controller.ts`, `src/clients/clients.service.ts`):
  cancels active subscriptions (Stripe + local `CANCELED`), deletes all
  credentials / OAuth identities / trusted devices / pending login challenges,
  deactivates membership, and **erases personal data** (login email replaced
  with a non-routable tombstone, name and contact fields cleared). After
  deletion the account **cannot be signed into or recovered**. Records required
  for legal/tax/billing obligations are retained by id only (no personal data).

**How App Review tests it.** Sign in with a reviewer account → Account → Delete
account → confirm. The app signs out and the account can no longer log in.
*(Deletion is permanent — test it last, or use the dedicated deletable account.)*

## Finding 4 — Business model clarification

**Orchestrate is B2B commercial execution infrastructure (SaaS).** It provides
governed managed-outbound execution for businesses. Plain answers for Apple:

- Services are sold to **organizations/businesses**, not consumers.
- **No consumer digital goods or content are sold through the app.**
- **Billing is managed outside the app** (web Stripe billing portal, arranged
  with the organization). The iOS app intentionally **does not offer in-app or
  external purchases** — external billing is suppressed on iOS per Guideline
  3.1.1 (`client_billing_screen.dart`), showing a plan-management notice only.
- The iOS app is a **workspace client** that gives an organization's users
  access to a service the organization already pays for. There is therefore no
  In-App Purchase to implement.

---

## App Review "Notes" — paste into App Store Connect → App Review Information

> Orchestrate is a B2B SaaS workspace for organizations; it sells no consumer
> digital goods and contains no in-app purchases. Subscriptions are arranged
> with the organization and billed externally (web); on iOS the app shows
> subscription status only.
>
> Please use the credentials below — they are pre-verified and use a
> deterministic login (no email code required). Do not create a new account
> (verification emails cannot reach a reviewer inbox).
>
> 1) Active subscription account
>    Email: <ACTIVE_REVIEWER_EMAIL>
>    Password: <ACTIVE_REVIEWER_PASSWORD>
>
> 2) Expired subscription account (to review the lapsed/restricted experience)
>    Email: <EXPIRED_REVIEWER_EMAIL>
>    Password: <EXPIRED_REVIEWER_PASSWORD>
>
> Account deletion: Sign in → Account → "Delete account" → type DELETE to
> confirm. Deletion is permanent; please test it last (the dedicated account #1
> can be re-seeded by us afterward).

## Reviewer credentials structure (operator fills in the real values)

| Account  | Email (env `REVIEWER_EMAIL`)        | `REVIEWER_SUBSCRIPTION_STATE` | Password (`REVIEWER_PASSWORD`) |
|----------|-------------------------------------|-------------------------------|--------------------------------|
| Active   | `reviewer@orchestrateops.com`       | (unset / `active`)            | operator-chosen                |
| Expired  | `reviewer-expired@orchestrateops.com` | `expired`                   | operator-chosen                |

Both emails MUST be in `STORE_REVIEWER_EMAILS` and `REVIEW_MODE_ENABLED=true`
on the production deployment.

---

## Operator runbook (production — required before submitting the build)

1. **Set production env (Railway, backend):**
   - `REVIEW_MODE_ENABLED=true`
   - `STORE_REVIEWER_EMAILS=reviewer@orchestrateops.com,reviewer-expired@orchestrateops.com`
2. **Deploy the backend** (account-deletion endpoint + seeding script changes).
3. **Seed the two reviewer accounts** (against production DB):
   ```bash
   # Active reviewer
   REVIEWER_EMAIL=reviewer@orchestrateops.com REVIEWER_PASSWORD='<pw1>' \
     node scripts/create-reviewer-account.js
   # Expired reviewer
   REVIEWER_EMAIL=reviewer-expired@orchestrateops.com REVIEWER_PASSWORD='<pw2>' \
     REVIEWER_SUBSCRIPTION_STATE=expired node scripts/create-reviewer-account.js
   ```
4. **Verify** both accounts log in (OTP-free) and the expired one shows the
   restricted/expired billing state; verify Delete account works on a throwaway
   reviewer account.
5. **Build & submit** the iOS app (0.1.3 build 5) via Codemagic `ios-testflight`.
6. **Enter the credentials + notes** above in App Store Connect and resubmit.

## Submission checklist
- [ ] Backend deployed with delete endpoint + review-mode env set.
- [ ] `REVIEW_MODE_ENABLED=true`, both emails in `STORE_REVIEWER_EMAILS`.
- [ ] Active + expired reviewer accounts seeded and login-verified.
- [ ] Delete-account flow verified end-to-end (account unrecoverable after).
- [ ] App version 0.1.3 build **5** (> rejected build 4).
- [ ] App Review Notes + both credentials entered in App Store Connect.
- [ ] New TestFlight build processed, then submitted for review.
