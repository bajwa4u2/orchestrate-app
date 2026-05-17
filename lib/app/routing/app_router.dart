import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/features/auth/screens/client_login_screen.dart';
import 'package:orchestrate_app/features/auth/screens/ops_login_screen.dart';
import 'package:orchestrate_app/features/client/screens/campaigns_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_activity_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_branding_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_contacts_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_mailbox_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_newsletter_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_account_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_billing_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_business_identity_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_setup_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_subscribe_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_workspace_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_backend_surface_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_notifications_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_outreach_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_records_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_replies_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_settings_screen.dart';
import 'package:orchestrate_app/features/client/screens/leads_screen.dart';
import 'package:orchestrate_app/features/operator/screens/inquiry_detail_screen.dart';
import 'package:orchestrate_app/features/client/screens/meetings_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_support_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_backend_surface_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_debug_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_governance_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_providers_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_system_doctor_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_workspace_screen.dart';
import 'package:orchestrate_app/features/public/screens/contact_screen.dart';
import 'package:orchestrate_app/features/public/screens/pricing_screen.dart';
import 'package:orchestrate_app/features/client/screens/oauth_return_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_sequence_author_screen.dart';
import 'package:orchestrate_app/features/public/screens/activation_preview_screen.dart';
import 'package:orchestrate_app/features/public/screens/for_evaluators_screen.dart';
import 'package:orchestrate_app/features/public/screens/orchestrate_operations_screen.dart';
import 'package:orchestrate_app/features/public/screens/public_diagnostics_screen.dart';
import 'package:orchestrate_app/features/public/screens/public_content_screen.dart';
import 'package:orchestrate_app/features/public/screens/public_home_screen.dart';
import 'package:orchestrate_app/app/shell/operator_shell.dart';
import 'package:orchestrate_app/app/shell/client_shell.dart';
import 'package:orchestrate_app/app/shell/public_shell.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _clientShellNavigatorKey = GlobalKey<NavigatorState>();
final _operatorShellNavigatorKey = GlobalKey<NavigatorState>();

const _clientCoreRoutes = <String>{
  '/app/home',
  '/app/contacts',
  '/app/campaigns',
  '/app/activity',
  '/app/mailbox',
  '/app/newsletter',
  '/app/branding',
  '/app/billing',
  '/app/account',
  '/app/setup',
  '/app/subscribe',
};

const _clientCanonicalRoutes = <String>{
  '/client',
  '/client/overview',
  '/client/setup',
  '/client/subscribe',
  '/client/workspace',
  // New operational IA — these are the canonical paths.
  '/client/operations',
  '/client/opportunities',
  '/client/infrastructure',
  '/client/representation',
  // Legacy paths kept so deep links keep resolving via redirects.
  '/client/leads',
  '/client/outreach',
  '/client/mailbox',
  '/client/business-identity',
  '/client/campaign',
  '/client/campaign/targeting',
  '/client/campaigns',
  '/client/replies',
  '/client/meetings',
  '/client/billing',
  '/client/records',
  '/client/invoices',
  '/client/receipts',
  '/client/agreements',
  '/client/statements',
  '/client/reminders',
  '/client/notifications',
  '/client/support',
  '/client/settings',
  '/client/account',
  '/client/help',
  '/client/trust',
  '/client/oauth/return',
};

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: AuthSessionController.instance,
  redirect: (context, state) {
    final session = AuthSessionController.instance;
    if (!session.isReady) return null;

    final path = state.uri.path;
    final plan = _normalizedPlan(state.uri.queryParameters['plan']) ??
        session.selectedPlan;
    final tier = _normalizedTier(state.uri.queryParameters['tier']) ??
        session.selectedTier;
    final trial = _normalizedTrial(state.uri.queryParameters['trial']);

    final isClientAuth = <String>{
      '/auth/login',
      '/auth/join',
      '/login',
      '/join',
      '/client/login',
      '/client/join',
    }.contains(path);
    final isOpsAuth = <String>{
      '/ops/login',
      '/ops/join',
      '/ops-login',
      '/ops-join',
    }.contains(path);
    final isVerification =
        <String>{'/auth/verify-email', '/client/verify-email'}.contains(path);
    final isReset = <String>{'/auth/reset-password', '/client/reset-password'}
        .contains(path);
    final isSetup = <String>{'/app/setup', '/client/setup'}.contains(path);
    final isSubscribe =
        <String>{'/app/subscribe', '/client/subscribe'}.contains(path);
    final isClientArea = _clientCoreRoutes.contains(path) ||
        _clientCanonicalRoutes.contains(path) ||
        path.startsWith('/app/');
    final isOperatorArea =
        (path.startsWith('/ops/') || path.startsWith('/operator/')) &&
            !isOpsAuth;

    if (!session.isAuthenticated) {
      if (isOperatorArea) return '/ops/login';
      if (isVerification || isReset) return null;
      if (isClientArea || isSetup || isSubscribe) {
        return _clientRoute('/auth/login',
            plan: plan, tier: tier, trial: trial);
      }
      return null;
    }

    if (session.surface == 'operator') {
      if (isOpsAuth || path == '/') return '/ops/overview';
      if (path.startsWith('/app/')) return '/ops/overview';
      if (path.startsWith('/auth/')) return '/ops/overview';
      if (path.startsWith('/client/')) return '/ops/overview';
      return null;
    }

    if (session.surface == 'client') {
      if (!session.emailVerified) {
        if (isVerification || isReset) return null;
        return _clientRoute('/auth/verify-email',
            plan: plan, tier: tier, trial: trial);
      }

      final setupAllowed = <String>{
        '/app/setup',
        '/app/home',
        '/app/billing',
        '/app/account',
        '/client/setup',
        '/client/overview',
        '/client/billing',
        '/client/account',
        '/client/settings',
      };
      if (!session.hasSetupCompleted) {
        if (setupAllowed.contains(path)) return null;
        return _clientRoute('/app/setup', plan: plan, tier: tier, trial: trial);
      }

      // Routes that remain reachable during subscription degradation
      // (past_due / paused / canceled / expired / incomplete).
      // Doctrine: subscription degradation is governed operational
      // degradation, not hard SaaS lockout. The workspace home stays
      // reachable so the SubscriptionContinuityCard names what
      // dispatch is gated, what reply ingestion continues, and what
      // resolution restores. Hard-redirect to /app/subscribe is
      // reserved for the fully-uninitialised state (status='none').
      final subscriptionAllowed = <String>{
        '/app/home',
        '/app/subscribe',
        '/app/billing',
        '/app/account',
        '/app/campaigns',
        '/client/overview',
        '/client/subscribe',
        '/client/billing',
        '/client/account',
        '/client/settings',
        '/client/campaign',
        '/client/campaigns',
      };
      // Subscription gate. The backend ExecutionEligibilityService
      // treats both ACTIVE and TRIALING as dispatch-eligible — the
      // frontend gate must mirror that, otherwise a trialing client
      // gets redirected to /app/subscribe from /app/home even though
      // their managed execution is running. Every other state
      // (past_due, paused, canceled, expired, incomplete, none)
      // routes to the subscribe surface so the lifecycle can be
      // resolved there; the workspace SubscriptionContinuityCard
      // names the operational consequence calmly while billing is
      // resolved.
      final subStatus = session.normalizedSubscriptionStatus;
      final subEligible = subStatus == 'active' || subStatus == 'trialing';
      if (!subEligible) {
        if (subscriptionAllowed.contains(path)) return null;
        return _clientRoute('/app/subscribe',
            plan: plan, tier: tier, trial: trial);
      }

      if (isClientAuth ||
          isVerification ||
          isReset ||
          isSetup ||
          isSubscribe ||
          path == '/') {
        return '/app/home';
      }
      if (isOpsAuth || path.startsWith('/ops/')) return '/app/home';
    }

    return null;
  },
  routes: [
    GoRoute(
        path: '/ops/login',
        builder: (context, state) => const OpsLoginScreen()),
    GoRoute(
        path: '/ops/join',
        builder: (context, state) => const OpsLoginScreen(createMode: true)),
    GoRoute(path: '/ops-login', redirect: (context, state) => '/ops/login'),
    GoRoute(path: '/ops-join', redirect: (context, state) => '/ops/join'),
    GoRoute(
        path: '/auth/login',
        builder: (context, state) => const ClientLoginScreen()),
    GoRoute(
        path: '/auth/join',
        builder: (context, state) => const ClientLoginScreen(createMode: true)),
    GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) =>
            const ClientLoginScreen(verificationMode: true)),
    GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) => const ClientLoginScreen(resetMode: true)),
    GoRoute(path: '/login', redirect: (context, state) => '/auth/login'),
    GoRoute(path: '/join', redirect: (context, state) => '/auth/join'),
    GoRoute(path: '/signup', redirect: (context, state) => '/auth/join'),
    GoRoute(
        path: '/forgot-password',
        redirect: (context, state) => '/auth/reset-password'),
    GoRoute(
        path: '/reset-password',
        redirect: (context, state) => '/auth/reset-password'),
    GoRoute(
        path: '/verify-email',
        redirect: (context, state) => '/auth/verify-email'),
    GoRoute(path: '/client/login', redirect: (context, state) => '/auth/login'),
    GoRoute(path: '/client/join', redirect: (context, state) => '/auth/join'),
    GoRoute(path: '/client/signup', redirect: (context, state) => '/auth/join'),
    GoRoute(
        path: '/client/verify-email',
        redirect: (context, state) => '/auth/verify-email'),
    GoRoute(
        path: '/client/reset-password',
        redirect: (context, state) => '/auth/reset-password'),
    GoRoute(path: '/operator', redirect: (context, state) => '/ops/overview'),
    GoRoute(
        path: '/app/command', redirect: (context, state) => '/ops/overview'),
    GoRoute(
        path: '/app/pipeline', redirect: (context, state) => '/ops/contacts'),
    GoRoute(
        path: '/app/inquiries', redirect: (context, state) => '/ops/inquiries'),
    GoRoute(
        path: '/app/inquiries/:id',
        redirect: (context, state) =>
            '/ops/inquiries/${state.pathParameters['id'] ?? ''}'),
    GoRoute(
        path: '/app/execution', redirect: (context, state) => '/ops/campaigns'),
    GoRoute(
        path: '/app/execution/campaigns',
        redirect: (context, state) => '/ops/campaigns'),
    GoRoute(
        path: '/app/execution/replies',
        redirect: (context, state) => '/ops/activity'),
    GoRoute(
        path: '/app/execution/meetings',
        redirect: (context, state) => '/ops/activity'),
    GoRoute(path: '/app/clients', redirect: (context, state) => '/ops/clients'),
    GoRoute(
        path: '/app/revenue', redirect: (context, state) => '/ops/activity'),
    GoRoute(
        path: '/app/deliverability',
        redirect: (context, state) => '/ops/mailboxes'),
    GoRoute(
        path: '/app/communications',
        redirect: (context, state) => '/ops/activity'),
    GoRoute(
        path: '/app/records', redirect: (context, state) => '/ops/activity'),
    GoRoute(path: '/app/settings', redirect: (context, state) => '/ops/debug'),
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: const PublicHomeScreen()),
      ),
    ),
    GoRoute(
      path: '/product',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Product',
            title: 'Commercial intelligence + execution infrastructure.',
            subtitle:
                'Orchestrate is managed revenue automation infrastructure. You connect your business identity and sending identity. Orchestrate detects opportunity, verifies readiness, runs governed execution, and keeps it running.',
            sideNote:
                'Pick the scope of managed execution at activation: execution alone, or execution plus revenue continuity (invoices, statements, reminders, agreements).',
            sideActions: [
              ContentAction(
                  label: 'Activate infrastructure',
                  path: '/auth/join',
                  filled: true),
              ContentAction(label: 'View pricing', path: '/pricing'),
            ],
            sections: [
              ContentSection(
                title: 'What you provide',
                body:
                    'Four inputs. Business identity, mailbox transport (OAuth or custom SMTP+IMAP), sending-domain verification, and representation authorization. That is the full client surface.',
                points: [
                  'Business identity, market, and offer context',
                  'Mailbox transport — Google Workspace, Microsoft 365, or custom SMTP + IMAP',
                  'Sending-domain verification (SPF / DKIM / DMARC)',
                  'Representation authorization',
                ],
              ),
              ContentSection(
                title: 'What Orchestrate owns',
                body:
                    'Everything after readiness. Signal-driven discovery, qualification, readiness orchestration, governed dispatch, follow-up continuity, recovery, deliverability posture, and operational continuity — all visible, explainable, audited.',
                points: [
                  'Signal-driven opportunity detection',
                  'Readiness orchestration + auto-activation',
                  'Governed dispatch + follow-up continuity',
                  'Automatic recovery, retry, and deliverability posture',
                  'Explainable readiness transitions + audit trail',
                ],
              ),
              ContentSection(
                title: 'How it is organized',
                body:
                    'Public pages explain the category and the activation path. The client workspace shows what is verified, what is running, and what is awaiting your input — never lifecycle buttons. Operator tools run the deeper infrastructure controls.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/how-it-works',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Activation journey',
            title: 'From business identity to managed revenue execution.',
            subtitle:
                'A short, verifiable handoff. You verify business identity, mailbox, and sending domain. Orchestrate verifies readiness, then activates managed execution and keeps it running.',
            sideNote:
                'You see verified state and outcomes. Lifecycle controls, retries, and dispatch governance stay inside Orchestrate.',
            sideActions: [
              ContentAction(
                  label: 'Activate infrastructure',
                  path: '/auth/join',
                  filled: true),
              ContentAction(label: 'Talk through fit', path: '/contact'),
            ],
            sections: [
              ContentSection(
                title: '1. Connect your business identity',
                body:
                    'Define market, offer, target segments, and grant representation. The inputs Orchestrate needs before discovery can be tied to your business — no generic lists.',
                points: [
                  'Business profile and offer context',
                  'Target market, region, and industry',
                  'Representation authorization',
                ],
              ),
              ContentSection(
                title: '2. Connect your mailbox transport',
                body:
                    'Three first-class transport paths: Google Workspace OAuth, Microsoft 365 OAuth, or custom SMTP + IMAP for any other mail infrastructure (SES, Mailgun, SendGrid, Postfix, regional providers, or your own server). All three vault their credentials behind the same encrypted adapter — never touch the browser, never persisted unsealed in the database. Custom SMTP gets a per-transport DKIM keypair generated by Orchestrate. Inbound reply monitoring on SMTP transports is wired via IMAP in the same setup; reply ingestion is operation-scoped (header-first, body-on-match-only).',
                points: [
                  'Google Workspace / Microsoft 365 OAuth (backend-owned)',
                  'Custom SMTP + IMAP for any other mail infrastructure',
                  'Encrypted vault credential storage (no plaintext, no browser exposure)',
                  'Operation-scoped reply monitoring — unrelated inbox content never read',
                ],
              ),
              ContentSection(
                title: '3. Verify sending identity',
                body:
                    'Publish SPF, DKIM, and DMARC records for your domain. Orchestrate verifies them with live DNS, surfaces propagation progress, and re-checks automatically until they pass.',
                points: [
                  'Live SPF / DKIM / DMARC verification',
                  'DNS propagation history visible to you',
                  'Automatic re-verification',
                ],
              ),
              ContentSection(
                title: '4. Readiness orchestration takes over',
                body:
                    'A single readiness engine watches subscription, authorization, mailbox, and sending identity. Dispatch eligibility is granted when every layer is verified.',
                points: [
                  'Centralized readiness engine',
                  'Dispatch eligibility on full verification',
                  'Audited readiness transitions',
                ],
              ),
              ContentSection(
                title: '5. Managed execution runs',
                body:
                    'Signal discovery, qualification, governed dispatch, follow-up continuity, reply handling, and recovery run as managed infrastructure. You watch outcomes, not buttons.',
                points: [
                  'Signal-driven discovery + qualification',
                  'Governed dispatch + follow-up continuity',
                  'Automatic recovery and deliverability posture',
                  'Reply classification and meeting handoff',
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/ai-governed-revenue',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'AI governance',
            title: 'AI runs inside the governance layer — never around it.',
            subtitle:
                'AI assists with strategy, message drafting, follow-up cadence, and revenue-document generation. Every action is reviewable, auditable, and gated by readiness checks before it affects live execution.',
            sideActions: [
              ContentAction(
                  label: 'Talk through fit', path: '/contact', filled: true),
              ContentAction(label: 'See activation journey', path: '/how-it-works'),
            ],
            sections: [
              ContentSection(
                title: 'Governed assistance',
                body:
                    'Operators can review readiness, trust status, diagnosis, and generation decisions before they affect live execution. AI is decision support inside the readiness engine, not an autonomous SDR running outside it.',
              ),
              ContentSection(
                title: 'Client-safe explainability',
                body:
                    'Clients see verified state, blocked states, and the next concrete step — never raw logs, never decision-tree internals. The readiness engine is the explanation surface.',
              ),
              ContentSection(
                title: 'Execution truth',
                body:
                    'When a view is not available for an account yet, the workspace says so plainly and points to the next useful action. No fabricated dashboards. No invented metrics.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/lead-sourcing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Commercial intelligence',
            title:
                'Signal-driven opportunity detection, not a rented contact list.',
            subtitle:
                'Orchestrate continuously watches your defined market for commercial signals and turns them into qualified, contactable opportunities. The discovery layer is provider-agnostic and bound to your business identity — never a generic database.',
            sideActions: [
              ContentAction(
                  label: 'Activate infrastructure',
                  path: '/auth/join',
                  filled: true),
              ContentAction(label: 'See how it operates', path: '/how-it-works'),
            ],
            sections: [
              ContentSection(
                title: 'How discovery works',
                body:
                    'Signal discovery runs against the market, region, industry, and offer context you provide. Each opportunity is qualified against contact readiness, reachability, and business fit before it enters governed dispatch.',
                points: [
                  'Provider-agnostic signal sources',
                  'Tied to your defined business identity, not a vendor list',
                  'Qualification gates run before any send',
                ],
              ),
              ContentSection(
                title: 'What you see',
                body:
                    'You see qualified opportunities with explainable reasoning — why each one matched your scope, the contact path Orchestrate found, and where it sits in managed execution. Operator-only signal-source plumbing stays out of the client surface.',
              ),
              ContentSection(
                title: 'Why this matters',
                body:
                    'A contact list rented from one vendor goes stale and locks you in. Signal-driven discovery scales with your scope, stays explainable, and lets the rest of the infrastructure (governed dispatch, follow-up continuity, recovery) operate against high-quality input.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/trust-compliance',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Trust and compliance',
            title:
                'Operation-scoped mailbox access, vaulted credentials, governed dispatch, audited execution.',
            subtitle:
                'Trust is infrastructure, not marketing. Operation-scoped mailbox ingestion (header-first, body-on-match-only), encrypted credential vault, real DNS-based SPF / DKIM / DMARC verification, governed dispatch, AI processing bounded to operation-attributed data, and an auditable readiness trail are all first-class. The dedicated policy pages below describe each layer.',
            sideActions: [
              ContentAction(
                  label: 'Mailbox access policy',
                  path: '/legal/mailbox-access',
                  filled: true),
              ContentAction(
                  label: 'Reply monitoring', path: '/legal/reply-monitoring'),
              ContentAction(label: 'AI usage', path: '/legal/ai-usage'),
              ContentAction(
                  label: 'Credential handling', path: '/legal/credentials'),
              ContentAction(
                  label: 'Provider boundaries', path: '/legal/providers'),
              ContentAction(
                  label: 'Suppression / opt-out', path: '/legal/suppression'),
              ContentAction(
                  label: 'Abuse policy', path: '/legal/abuse'),
              ContentAction(
                  label: 'Retention / deletion', path: '/legal/retention'),
              ContentAction(
                  label: 'Deliverability policy', path: '/legal/deliverability'),
              ContentAction(
                  label: 'Acceptable use', path: '/legal/acceptable-use'),
            ],
            sections: [
              ContentSection(
                title: 'Operation-scoped mailbox access',
                body:
                    'Orchestrate does not behave as a general inbox reader. Inbound mail is inspected at the header level only; bodies are fetched and stored exclusively for messages that resolve to an Orchestrate-managed operation. Unrelated mailbox content is not stored, classified, surfaced, or fed to AI. The IMAP cursor is initialized to the current highest UID on connect, so no historical mailbox content is ever inspected.',
                points: [
                  'Headers fetched first, body only after operation match',
                  'No historical-mailbox scan on first connect',
                  'Sent folder is not mirrored',
                  'Unmatched mail stays in the upstream mailbox untouched',
                ],
              ),
              ContentSection(
                title: 'Verified sending identity',
                body:
                    'SPF, DKIM, and DMARC are verified with live DNS before any non-sandbox dispatch. A background poller keeps re-verifying pending domains so propagation is visible. For custom SMTP transports, Orchestrate generates a per-transport DKIM keypair and surfaces the public-key TXT record the client must publish.',
                points: [
                  'Live DNS verification (no third-party deliverability vendor)',
                  'Per-record propagation history visible to the client',
                  'Per-transport DKIM keypair on custom SMTP',
                  'Dispatch eligibility is gated on the verification state',
                ],
              ),
              ContentSection(
                title: 'Encrypted credential vault',
                body:
                    'Mailbox OAuth refresh tokens, SMTP and IMAP passwords, and DKIM private keys are sealed by a vault adapter (encrypted-DB AES-256-GCM today, or HashiCorp Vault). Production refuses to boot with the in-memory adapter. Credentials never appear in API responses, browser state, logs, or unencrypted database storage.',
              ),
              ContentSection(
                title: 'Governed dispatch + auditable readiness',
                body:
                    'Every dispatch passes a readiness check, a suppression check, and a governance check. Readiness transitions, credential reads, OAuth callbacks, DNS verification outcomes, SMTP and IMAP connect events, reply ingestion, and follow-up suppressions are recorded in append-only audit trails tied to the account. Audit records carry metadata only — never credentials, never message bodies.',
              ),
              ContentSection(
                title: 'AI processing scope',
                body:
                    'AI-assisted systems operate against operation-scoped data only — Orchestrate-generated outbound content and operation-attributed replies. Unrelated mailbox content never enters an AI pipeline. AI-assisted output carries a stored traceability record.',
              ),
              ContentSection(
                title: 'Suppression and opt-out enforcement',
                body:
                    'Opt-out signals, hard bounces, complaints, and operator blocks create suppression entries that block every subsequent FIRST_SEND and FOLLOWUP_SEND against the affected recipient. There is no UI affordance or API path that bypasses the suppression check.',
              ),
              ContentSection(
                title: 'Authorization and records',
                body:
                    'Representation authorization, agreements, statements, reminders, notifications, and formal documents are governed alongside execution under the revenue-continuity scope — same infrastructure, same audit trail.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/intake',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: const ContactScreen()),
      ),
    ),
    GoRoute(
      path: '/pricing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: const PricingScreen()),
      ),
    ),
    GoRoute(
      path: '/about',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'About',
            title:
                'Commercial intelligence + execution infrastructure.',
            subtitle:
                'Orchestrate exists because revenue automation deserves to be infrastructure, not another tool you operate. Connect business identity and sending identity — Orchestrate detects opportunity, verifies readiness, and runs governed execution end to end.',
            sections: [
              ContentSection(
                title: 'The category',
                body:
                    'Not a CRM. Not an AI SDR. Not sequence software. Managed revenue automation infrastructure: signal discovery, readiness orchestration, governed dispatch, follow-up continuity, recovery, and operational visibility — owned by the platform after the client verifies identity.',
              ),
              ContentSection(
                title: 'The handoff',
                body:
                    'Clients own four inputs: business identity, mailbox, mailbox ownership, sending-domain verification. Everything after readiness belongs to Orchestrate. The infrastructure is the product — not a workspace of buttons.',
              ),
              ContentSection(
                title: 'Why the separation matters',
                body:
                    'Visitors get a clear category. Clients get verified state and explainable outcomes. Operators get the deeper infrastructure controls. No surface tries to be all three.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/contact',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: const ContactScreen()),
      ),
    ),
    GoRoute(
      path: '/account-deletion',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Account access',
            title: 'Account deletion',
            subtitle:
                'Orchestrate users can request account deletion from inside the app or by contacting support from the email address associated with the account.',
            sideNote:
                'Orchestrate by Aura Platform LLC. Support: support@orchestrateops.com.',
            sections: [
              ContentSection(
                title: 'Request from inside the app',
                body:
                    'Users can request account deletion from inside the app: Client workspace → Settings → Account → Deactivate account.',
              ),
              ContentSection(
                title: 'Alternative contact method',
                body:
                    'You may also request deletion by emailing support@orchestrateops.com from the email address associated with your Orchestrate account.',
              ),
              ContentSection(
                title: 'What is deleted',
                body:
                    'When an account deletion request is processed, Orchestrate deletes or deactivates eligible account profile information, workspace access, client account records where eligible, and user-provided account data where deletion is legally permitted.',
                points: [
                  'account profile',
                  'workspace access',
                  'client account records where eligible',
                  'user-provided account data where deletion is legally permitted',
                ],
              ),
              ContentSection(
                title: 'What may be retained',
                body:
                    'Some records may be retained for a limited period where required for billing, security, fraud prevention, audit logs, legal compliance, dispute resolution, or unpaid balances.',
                points: [
                  'billing records',
                  'security/audit logs',
                  'fraud prevention records',
                  'legal/compliance records',
                  'records required to resolve active disputes or unpaid balances',
                ],
              ),
              ContentSection(
                title: 'Timeline',
                body:
                    'Requests are reviewed and processed within a reasonable period, normally within 30 days, unless retention is required by law, billing, security, or dispute obligations.',
              ),
              ContentSection(
                title: 'Developer and support',
                body:
                    'Orchestrate is operated by Aura Platform LLC. For account deletion support, email support@orchestrateops.com.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/newsletter',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Updates',
            title: 'Infrastructure updates will appear here.',
            subtitle:
                'Public infrastructure notes — provider adapters, readiness-orchestration changes, sending-identity verification updates — are not published here yet. Account-specific notices appear inside the client workspace.',
            sections: [
              ContentSection(
                title: 'What goes here',
                body:
                    'When enabled, this page will publish updates to the managed-execution infrastructure: new mailbox provider adapters, deliverability posture changes, readiness-engine behavior, and similar operational notes that matter to verified clients.',
              ),
              ContentSection(
                title: 'Client communications',
                body:
                    'Per-account notices, reminders, and audit records appear inside the client workspace after sign-in when they are available for the account.',
              ),
            ],
            sideActions: [
              ContentAction(
                  label: 'Contact us', path: '/contact', filled: true),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/newsletter/subscribe',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Updates',
            title: 'Update subscription is not available yet.',
            subtitle:
                'Public update subscriptions for infrastructure notes are not connected yet. Use contact in the meantime if you want to talk through scope, fit, or activation timing.',
            sections: [
              ContentSection(
                title: 'Status',
                body:
                    'When enabled, this page will let you subscribe to public infrastructure updates. Until then, contact is the right next action.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(path: '/terms', redirect: (context, state) => '/legal/terms'),
    GoRoute(path: '/privacy', redirect: (context, state) => '/legal/privacy'),
    GoRoute(
      path: '/legal/terms',
      pageBuilder: (context, state) => NoTransitionPage(
        child:
            PublicShell(currentPath: state.uri.path, child: buildTermsScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/privacy',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildPrivacyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/billing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildBillingPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/refunds',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildRefundPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/acceptable-use',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildAcceptableUseScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/service-agreement',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildServiceAgreementScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/deliverability',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildDeliverabilityScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/mailbox-access',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildMailboxAccessPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/ai-usage',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildAiUsagePolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/credentials',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildCredentialHandlingScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/reply-monitoring',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildReplyMonitoringDisclosureScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/suppression',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildSuppressionPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/providers',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildProviderResponsibilityScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/abuse',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildAbusePolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/retention',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildRetentionPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/why-orchestrate',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildWhyOrchestrateExistsScreen()),
      ),
    ),
    GoRoute(
      path: '/how-orchestrate-operates',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: const OrchestrateOperationsScreen()),
      ),
    ),
    GoRoute(
      path: '/trust-architecture',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildTrustArchitectureScreen()),
      ),
    ),
    GoRoute(
      path: '/for-evaluators',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: const ForEvaluatorsScreen()),
      ),
    ),
    GoRoute(
      path: '/activation',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: const ActivationPreviewScreen()),
      ),
    ),
    GoRoute(
      path: '/security-evaluation',
      redirect: (context, state) => '/for-evaluators',
    ),
    // Public DNS diagnostic surface — visitors can verify SPF / DKIM /
    // DMARC for their sending domain without signup. Live DNS lookups;
    // no records stored.
    GoRoute(
      path: '/diagnostics',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: const PublicDiagnosticsScreen()),
      ),
    ),
    GoRoute(
      path: '/dns-diagnostic',
      redirect: (context, state) => '/diagnostics',
    ),
    GoRoute(
      path: '/trust-review',
      redirect: (context, state) => '/for-evaluators',
    ),
    GoRoute(
        path: '/app/setup',
        builder: (context, state) => const ClientSetupScreen()),
    GoRoute(
        path: '/app/subscribe',
        builder: (context, state) => const ClientSubscribeScreen()),
    ShellRoute(
      navigatorKey: _clientShellNavigatorKey,
      builder: (context, state, child) =>
          ClientShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
            path: '/client', redirect: (context, state) => '/client/overview'),
        GoRoute(
            path: '/client/overview',
            builder: (context, state) =>
                const ClientHomeScreen(section: ClientSection.home)),
        GoRoute(
            path: '/client/workspace',
            redirect: (context, state) => '/client/overview'),
        GoRoute(
            path: '/client/setup',
            builder: (context, state) => const ClientSetupScreen()),
        // Representation — the canonical client-owned commercial-profile
        // surface. Old /client/business-identity + /client/campaign paths
        // redirect here so the operational IA stays single-source.
        GoRoute(
            path: '/client/representation',
            builder: (context, state) => const ClientBusinessIdentityScreen()),
        // OAuth return surface — backend's ORCH_APP_OAUTH_RETURN_URL
        // should be configured to land here so the result is rendered
        // with operation-scoped mailbox disclosure + next-action CTAs
        // rather than dumping the user on a bare query-string URL.
        GoRoute(
            path: '/client/oauth/return',
            builder: (context, state) => OAuthReturnScreen(
                  status: state.uri.queryParameters['status'] ?? '',
                  provider: state.uri.queryParameters['provider'],
                  reason: state.uri.queryParameters['reason'],
                  email: state.uri.queryParameters['email'],
                  mailboxId: state.uri.queryParameters['mailboxId'],
                )),
        GoRoute(
            path: '/client/business-identity',
            redirect: (context, state) => '/client/representation'),
        GoRoute(
            path: '/client/campaign',
            redirect: (context, state) => '/client/representation'),
        GoRoute(
            path: '/client/campaign/targeting',
            redirect: (context, state) => '/client/representation'),
        GoRoute(
            path: '/client/campaigns',
            redirect: (context, state) => '/client/representation'),
        // Targeting scope editor (geographies + industries). Kept under
        // /app/campaigns for now; representation links to it as
        // "refine targeting".
        GoRoute(
            path: '/client/representation/targeting',
            redirect: (context, state) => '/app/campaigns'),
        // Sequence authoring (governed template vs legacy custom body).
        // Mounted under the client shell so the workspace chrome wraps
        // it. Step CRUD posts directly to the new ClientPortalService
        // endpoints (POST /client/sequences/:id/steps,
        // PATCH /client/sequence-steps/:stepId,
        // DELETE /client/sequence-steps/:stepId).
        GoRoute(
            path: '/client/sequences/:sequenceId',
            builder: (context, state) => ClientSequenceAuthorScreen(
                  sequenceId: state.pathParameters['sequenceId'] ?? '',
                )),
        GoRoute(
            path: '/client/subscribe',
            builder: (context, state) => const ClientSubscribeScreen()),
        // Opportunities — signal-driven intelligence (was "Leads").
        GoRoute(
            path: '/client/opportunities',
            builder: (context, state) => const LeadsScreen()),
        GoRoute(
            path: '/client/leads',
            redirect: (context, state) => '/client/opportunities'),
        // Operations — managed execution runtime (was "Outreach").
        GoRoute(
            path: '/client/operations',
            builder: (context, state) => const ClientOutreachScreen()),
        GoRoute(
            path: '/client/outreach',
            redirect: (context, state) => '/client/operations'),
        GoRoute(
            path: '/client/replies',
            builder: (context, state) => const ClientRepliesScreen()),
        // Infrastructure — mailbox + sending identity + provider trust
        // consolidated under one surface (was /client/mailbox).
        GoRoute(
            path: '/client/infrastructure',
            builder: (context, state) => ClientMailboxScreen(
                  focus: state.uri.queryParameters['focus'],
                )),
        GoRoute(
            path: '/client/mailbox',
            redirect: (context, state) => '/client/infrastructure'),
        GoRoute(
            path: '/client/meetings',
            builder: (context, state) => const MeetingsScreen()),
        GoRoute(
            path: '/client/billing',
            builder: (context, state) => const ClientBillingScreen()),
        GoRoute(
            path: '/client/records',
            builder: (context, state) => const ClientRecordsScreen()),
        GoRoute(
            path: '/client/invoices',
            redirect: (context, state) => '/client/records'),
        GoRoute(
            path: '/client/receipts',
            redirect: (context, state) => '/client/records'),
        GoRoute(
            path: '/client/agreements',
            redirect: (context, state) => '/client/records'),
        GoRoute(
            path: '/client/statements',
            redirect: (context, state) => '/client/records'),
        GoRoute(
            path: '/client/reminders',
            redirect: (context, state) => '/client/records'),
        GoRoute(
            path: '/client/notifications',
            builder: (context, state) => const ClientNotificationsScreen()),
        GoRoute(
            path: '/client/support',
            builder: (context, state) => const ClientSupportScreen()),
        GoRoute(
            path: '/client/settings',
            builder: (context, state) => const ClientSettingsScreen()),
        GoRoute(
            path: '/client/account',
            builder: (context, state) => const ClientAccountScreen()),
        GoRoute(
            path: '/client/help',
            redirect: (context, state) => '/client/support'),
        GoRoute(
            path: '/client/trust',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.trust)),
        GoRoute(
            path: '/app/home',
            builder: (context, state) =>
                const ClientHomeScreen(section: ClientSection.home)),
        GoRoute(
            path: '/app/contacts',
            builder: (context, state) => const ClientContactsScreen()),
        GoRoute(
            path: '/app/contacts/import',
            redirect: (context, state) => '/app/contacts'),
        GoRoute(
            path: '/app/contacts/:contactId',
            redirect: (context, state) => '/app/contacts'),
        GoRoute(
            path: '/app/campaigns',
            builder: (context, state) => const CampaignsScreen()),
        GoRoute(
            path: '/app/campaigns/create',
            redirect: (context, state) => '/app/campaigns'),
        GoRoute(
            path: '/app/campaigns/:campaignId',
            redirect: (context, state) => '/app/campaigns'),
        GoRoute(
            path: '/app/activity',
            builder: (context, state) => const ClientActivityScreen()),
        GoRoute(
            path: '/app/mailbox',
            builder: (context, state) => const ClientMailboxScreen()),
        GoRoute(
            path: '/app/newsletter',
            builder: (context, state) => const ClientNewsletterScreen()),
        GoRoute(
            path: '/app/newsletter/audience',
            redirect: (context, state) => '/app/newsletter'),
        GoRoute(
            path: '/app/newsletter/issues',
            redirect: (context, state) => '/app/newsletter'),
        GoRoute(
            path: '/app/newsletter/settings',
            redirect: (context, state) => '/app/newsletter'),
        GoRoute(
            path: '/app/branding',
            builder: (context, state) => const ClientBrandingScreen()),
        GoRoute(
            path: '/app/branding/identity',
            redirect: (context, state) => '/app/branding'),
        GoRoute(
            path: '/app/branding/templates',
            redirect: (context, state) => '/app/branding'),
        GoRoute(
            path: '/app/branding/signatures',
            redirect: (context, state) => '/app/branding'),
        GoRoute(
            path: '/app/billing',
            builder: (context, state) =>
                const ClientHomeScreen(section: ClientSection.billing)),
        GoRoute(
            path: '/app/account',
            builder: (context, state) => const ClientAccountScreen()),
      ],
    ),
    ShellRoute(
      navigatorKey: _operatorShellNavigatorKey,
      builder: (context, state, child) =>
          OperatorShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
            path: '/operator/overview',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.command)),
        GoRoute(
            path: '/operator/system',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.system)),
        GoRoute(
            path: '/operator/system-doctor',
            builder: (context, state) => const OperatorSystemDoctorScreen()),
        GoRoute(
            path: '/operator/clients',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.clients)),
        GoRoute(
            path: '/operator/organizations',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.organizations)),
        GoRoute(
            path: '/operator/campaigns',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.campaigns)),
        GoRoute(
            path: '/operator/leads',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.leads)),
        GoRoute(
            path: '/operator/jobs',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.execution)),
        GoRoute(
            path: '/operator/workers',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.execution)),
        GoRoute(
            path: '/operator/queues',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.execution)),
        GoRoute(
            path: '/operator/ai-governance',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.aiGovernance)),
        GoRoute(
            path: '/operator/providers',
            builder: (context, state) => const OperatorProvidersScreen()),
        GoRoute(
            path: '/operator/sources',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.sources)),
        GoRoute(
            path: '/operator/reachability',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.reachability)),
        GoRoute(
            path: '/operator/qualification',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.qualification)),
        GoRoute(
            path: '/operator/signals',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.signals)),
        GoRoute(
            path: '/operator/deliverability',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.deliverability)),
        GoRoute(
            path: '/operator/emails',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.communications)),
        GoRoute(
            path: '/operator/replies',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.replies)),
        GoRoute(
            path: '/operator/meetings',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.meetings)),
        GoRoute(
            path: '/operator/billing',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.revenue)),
        GoRoute(
            path: '/operator/documents',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.records)),
        GoRoute(
            path: '/operator/support',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.inquiries)),
        GoRoute(
            path: '/operator/analytics',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.analytics)),
        GoRoute(
            path: '/operator/activity',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.activity)),
        GoRoute(
            path: '/ops/overview',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.command)),
        GoRoute(
            path: '/ops/clients',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.clients)),
        GoRoute(
            path: '/ops/contacts',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.pipeline)),
        GoRoute(
            path: '/ops/campaigns',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.campaigns)),
        GoRoute(
            path: '/ops/mailboxes',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.deliverability)),
        GoRoute(
            path: '/ops/providers',
            builder: (context, state) => const OperatorProvidersScreen()),
        GoRoute(
            path: '/ops/activity',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.activity)),
        GoRoute(
            path: '/ops/inquiries',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.inquiries)),
        GoRoute(
            path: '/ops/inquiries/:id',
            builder: (context, state) => InquiryDetailScreen(
                inquiryId: state.pathParameters['id'] ?? '')),
        GoRoute(
            path: '/ops/debug',
            builder: (context, state) => const OperatorDebugScreen()),
        // Operator governance workspace — cross-client provenance + lifecycle
        // visibility. Reads /operator/governance/messages/{recent,:id}.
        GoRoute(
            path: '/ops/governance',
            builder: (context, state) => const OperatorGovernanceScreen()),
        GoRoute(
            path: '/operator/governance',
            redirect: (context, state) => '/ops/governance'),
      ],
    ),
  ],
  errorBuilder: (context, state) => Theme(
    data: ThemeData.light(useMaterial3: true),
    child: const Scaffold(
        body: Center(child: Text('This surface is unavailable.'))),
  ),
);

String? _normalizedPlan(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == 'opportunity' || text == 'revenue') return text;
  return null;
}

String? _normalizedTier(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == 'focused') return 'focused';
  if (text == 'multi' || text == 'multi-market' || text == 'multi_market') {
    return 'multi';
  }
  if (text == 'precision') return 'precision';
  return null;
}

String? _normalizedTrial(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == '15d') return '15d';
  return null;
}

String _clientRoute(String path, {String? plan, String? tier, String? trial}) {
  final query = <String, String>{
    if (plan != null && plan.isNotEmpty) 'plan': plan,
    if (tier != null && tier.isNotEmpty) 'tier': tier,
    if (trial != null && trial.isNotEmpty) 'trial': trial,
  };
  if (query.isEmpty) return path;
  return Uri(path: path, queryParameters: query).toString();
}
