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
import 'package:orchestrate_app/features/client/screens/client_setup_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_subscribe_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_workspace_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_backend_surface_screen.dart';
import 'package:orchestrate_app/features/client/screens/leads_screen.dart';
import 'package:orchestrate_app/features/operator/screens/inquiry_detail_screen.dart';
import 'package:orchestrate_app/features/client/screens/meetings_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_support_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_backend_surface_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_debug_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_providers_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_workspace_screen.dart';
import 'package:orchestrate_app/features/public/screens/contact_screen.dart';
import 'package:orchestrate_app/features/public/screens/pricing_screen.dart';
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
  '/client/leads',
  '/client/outreach',
  '/client/replies',
  '/client/campaign',
  '/client/campaign/targeting',
  '/client/campaigns',
  '/client/meetings',
  '/client/billing',
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

      final subscriptionAllowed = <String>{
        '/app/subscribe',
        '/app/billing',
        '/app/account',
        '/app/campaigns',
        '/client/subscribe',
        '/client/billing',
        '/client/account',
        '/client/settings',
        '/client/campaign',
        '/client/campaigns',
      };
      if (session.normalizedSubscriptionStatus != 'active') {
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
            title: 'From lead to meeting, with structure that does not drift.',
            subtitle:
                'Orchestrate separates public trust, client control, and operator execution so revenue work stays legible.',
            sections: [
              ContentSection(
                title: 'What the system does',
                body:
                    'The product is built to handle targeting, outreach movement, follow-up, and meeting handoff without confusing those surfaces with billing, support, or operator governance.',
              ),
              ContentSection(
                title: 'How the frontend is organized',
                body:
                    'Public explains the product. Client manages its own working system. Operator carries execution, inquiries, providers, and debug reality.',
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
            eyebrow: 'Campaign journey',
            title:
                'Lead source to meeting, governed by system execution truth.',
            subtitle:
                'Orchestrate presents the journey without pretending public pages know operational data that only the system owns.',
            sideNote:
                'Public explains the system. Client and operator routes show live system state after authentication.',
            sideActions: [
              ContentAction(
                  label: 'Review pricing', path: '/pricing', filled: true),
              ContentAction(label: 'Start intake', path: '/intake'),
            ],
            sections: [
              ContentSection(
                title: '1. Scope and authorization',
                body:
                    'The client provides account, market, targeting, and representation details before outbound work is activated.',
                points: [
                  'Setup state',
                  'campaign profile',
                  'targeting boundaries',
                  'representation authorization'
                ],
              ),
              ContentSection(
                title: '2. Source and prepare leads',
                body:
                    'Provider-flexible sourcing feeds lead records that can be checked for reachability, qualification, and readiness.',
                points: [
                  'provider status',
                  'source runs',
                  'lead records',
                  'reachability and qualification where selected'
                ],
              ),
              ContentSection(
                title: '3. Execute outreach and follow-up',
                body:
                    'Execution jobs, dispatches, reply handling, and meeting handoff remain system-governed and operator-visible.',
                points: [
                  'email dispatches',
                  'first sends',
                  'follow-ups',
                  'reply classification',
                  'meeting handoff'
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
            title:
                'AI assists revenue execution under readiness, authority, and enforcement controls.',
            subtitle:
                'AI in Orchestrate is not a decorative writing widget. It supports strategy, messages, sequences, revenue documents, and governed execution decisions.',
            sideActions: [
              ContentAction(
                  label: 'Talk through fit', path: '/contact', filled: true),
              ContentAction(label: 'See journey', path: '/how-it-works'),
            ],
            sections: [
              ContentSection(
                title: 'Governed assistance',
                body:
                    'The system exposes AI capability status, trust status, readiness, evaluation sets, authority decisions, diagnosis, and generation actions for operator-controlled use.',
              ),
              ContentSection(
                title: 'Client-safe trust',
                body:
                    'Clients see operational summaries and clear blocked or pending states. Raw AI decision and enforcement internals remain operator surfaces unless a client-safe system capability is added.',
              ),
              ContentSection(
                title: 'Service truth',
                body:
                    'The frontend reads AI status from system capabilities and reports missing decision-log read capabilities as gaps instead of inventing AI activity.',
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
            eyebrow: 'Lead sourcing',
            title:
                'Provider-flexible sourcing instead of dependence on one list vendor.',
            subtitle:
                'Orchestrate treats sourcing as a governed supply layer that can use providers, internal discovery, campaign source plans, and source runs.',
            sections: [
              ContentSection(
                title: 'Sourcing philosophy',
                body:
                    'The system is designed around target clarity, provider flexibility, reachability, qualification, and source-run records.',
              ),
              ContentSection(
                title: 'Operational posture',
                body:
                    'Operators can inspect providers and campaign-specific source runs where the system exposes them. Clients see sourced leads and readiness without provider internals.',
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
                'Deliverability, representation, suppression, and records are first-class system concerns.',
            subtitle:
                'The product separates execution from trust posture so outbound work can be inspected, paused, and corrected.',
            sideActions: [
              ContentAction(
                  label: 'Deliverability policy',
                  path: '/legal/deliverability',
                  filled: true),
              ContentAction(
                  label: 'Acceptable use', path: '/legal/acceptable-use'),
            ],
            sections: [
              ContentSection(
                title: 'Deliverability posture',
                body:
                    'The system models domains, mailboxes, policies, suppressions, bounces, complaints, and mailbox health.',
              ),
              ContentSection(
                title: 'Authorization and records',
                body:
                    'Client representation authorization, agreements, statements, reminders, notifications, and formal documents stay tied to system records.',
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
            title: 'A revenue system built with clearer boundaries.',
            subtitle:
                'The structure matters because products drift when public messaging, client work, and operator control are mixed together.',
            sections: [
              ContentSection(
                title: 'Why the separation matters',
                body:
                    'Public should explain. Client should control its own system. Operator should manage execution truth. That boundary is now carried directly in the frontend constitution.',
              ),
              ContentSection(
                title: 'What stays fixed',
                body:
                    'Contacts remains the client memory surface, campaigns remains execution setup, and activity remains execution truth.',
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
      path: '/newsletter',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Newsletter',
            title:
                'Newsletter belongs in the public system and the client system.',
            subtitle:
                'Public subscription and client management remain separate on purpose.',
            sections: [
              ContentSection(
                title: 'Public side',
                body:
                    'This is where subscription starts, without pretending to be part of the client workspace.',
              ),
              ContentSection(
                title: 'Client side',
                body:
                    'Audience, issues, and settings remain owned by the client shell once those controls are expanded.',
              ),
            ],
            sideActions: [
              ContentAction(
                  label: 'Subscribe',
                  path: '/newsletter/subscribe',
                  filled: true),
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
            eyebrow: 'Newsletter',
            title: 'Subscription entry is reserved here.',
            subtitle:
                'This public route stays in place so newsletter does not drift into the wrong system while the final subscribe experience is still being completed.',
            sections: [
              ContentSection(
                title: 'Status',
                body:
                    'The route is live and intentionally reserved. The final subscription form can land here without reworking the public IA again.',
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
        GoRoute(
            path: '/client/subscribe',
            builder: (context, state) => const ClientSubscribeScreen()),
        GoRoute(
            path: '/client/leads',
            builder: (context, state) => const LeadsScreen()),
        GoRoute(
            path: '/client/outreach',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.outreach)),
        GoRoute(
            path: '/client/replies',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.replies)),
        GoRoute(
            path: '/client/campaign',
            builder: (context, state) => const CampaignsScreen()),
        GoRoute(
            path: '/client/campaign/targeting',
            builder: (context, state) => const CampaignsScreen()),
        GoRoute(
            path: '/client/campaigns',
            redirect: (context, state) => '/client/campaign'),
        GoRoute(
            path: '/client/meetings',
            builder: (context, state) => const MeetingsScreen()),
        GoRoute(
            path: '/client/billing',
            builder: (context, state) =>
                const ClientHomeScreen(section: ClientSection.billing)),
        GoRoute(
            path: '/client/invoices',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.invoices)),
        GoRoute(
            path: '/client/receipts',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.receipts)),
        GoRoute(
            path: '/client/agreements',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.agreements)),
        GoRoute(
            path: '/client/statements',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.statements)),
        GoRoute(
            path: '/client/reminders',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.reminders)),
        GoRoute(
            path: '/client/notifications',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.notifications)),
        GoRoute(
            path: '/client/support',
            builder: (context, state) => const ClientSupportScreen()),
        GoRoute(
            path: '/client/settings',
            builder: (context, state) => const ClientBackendSurfaceScreen(
                surface: ClientBackendSurface.settings)),
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
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.jobs)),
        GoRoute(
            path: '/operator/workers',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.workers)),
        GoRoute(
            path: '/operator/queues',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.queues)),
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
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.emails)),
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
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.billing)),
        GoRoute(
            path: '/operator/documents',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.documents)),
        GoRoute(
            path: '/operator/support',
            builder: (context, state) => const OperatorWorkspaceScreen(
                section: OperatorSection.inquiries)),
        GoRoute(
            path: '/operator/analytics',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.analytics)),
        GoRoute(
            path: '/operator/activity',
            builder: (context, state) => const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.activity)),
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
                section: OperatorSection.inquiries)),
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
