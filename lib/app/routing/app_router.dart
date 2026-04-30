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
import 'package:orchestrate_app/features/operator/screens/operator_providers_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_system_doctor_screen.dart';
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
            title: 'Turn target markets into qualified conversations.',
            subtitle:
                'Orchestrate helps businesses find the right accounts, start outreach, handle follow-up, manage replies, and move interested prospects toward booked meetings.',
            sideNote:
                'Start with outreach. Add revenue follow-through when billing, documents, and reminders need to stay connected.',
            sideActions: [
              ContentAction(
                  label: 'Start setup', path: '/auth/join', filled: true),
              ContentAction(label: 'View pricing', path: '/pricing'),
            ],
            sections: [
              ContentSection(
                title: 'What your business gets',
                body:
                    'A managed workspace for target market setup, outreach coverage, follow-up handling, replies, meetings, billing standing, service records, and support.',
                points: [
                  'More qualified conversations from the markets you choose',
                  'Less manual prospecting and fewer missed follow-ups',
                  'Clear sales activity without exposing operational clutter',
                  'A faster path from target market to booked meetings',
                ],
              ),
              ContentSection(
                title: 'How it is organized',
                body:
                    'Public pages help you decide. The client workspace shows what is set up, what is running, what needs action, and what happens next. Operator tools keep the managed service moving.',
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
            title: 'From target market to booked meeting.',
            subtitle:
                'The work starts with your business profile and target customers, then moves through sourcing, outreach, replies, meetings, billing records, and support.',
            sideNote:
                'You see business progress. Operators keep the deeper service controls out of your way.',
            sideActions: [
              ContentAction(
                  label: 'View pricing', path: '/pricing', filled: true),
              ContentAction(label: 'Talk through fit', path: '/contact'),
            ],
            sections: [
              ContentSection(
                title: '1. Set up the business profile',
                body:
                    'Tell Orchestrate what you sell, who you want to reach, where you serve, and how outreach should represent your business.',
                points: [
                  'Business profile',
                  'Target customers',
                  'Target location',
                  'Representation authorization'
                ],
              ),
              ContentSection(
                title: '2. Source and prepare the right leads',
                body:
                    'Lead sourcing stays tied to your target market so contacted records are easier to understand and review.',
                points: [
                  'Lead records',
                  'Contact readiness',
                  'Target market fit',
                  'Outreach readiness'
                ],
              ),
              ContentSection(
                title: '3. Run outreach and follow-up',
                body:
                    'First messages, follow-ups, replies, and meeting handoff stay connected so momentum does not depend on scattered manual tracking.',
                points: [
                  'Queued outreach',
                  'Sent messages',
                  'Follow-ups',
                  'Replies',
                  'Meetings'
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
            title: 'AI helps run the work with service controls.',
            subtitle:
                'AI assists with strategy, messages, sequences, revenue documents, and diagnosis while the managed service stays reviewable and controlled.',
            sideActions: [
              ContentAction(
                  label: 'Talk through fit', path: '/contact', filled: true),
              ContentAction(label: 'See journey', path: '/how-it-works'),
            ],
            sections: [
              ContentSection(
                title: 'Governed assistance',
                body:
                    'Operators can review readiness, trust status, diagnosis, and generation actions before service decisions affect live work.',
              ),
              ContentSection(
                title: 'Client-safe trust',
                body:
                    'Clients see clear service progress, blocked states, and next steps without being asked to interpret technical logs.',
              ),
              ContentSection(
                title: 'Service truth',
                body:
                    'When a view is not available for an account yet, the workspace says so plainly and points to the next useful action.',
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
                'Sourcing starts from your target market, not a generic list.',
            subtitle:
                'Orchestrate is designed to find opportunities from the market, region, industry, and offer context you provide.',
            sections: [
              ContentSection(
                title: 'Sourcing philosophy',
                body:
                    'The goal is qualified conversations, so sourcing is tied to target clarity, contact readiness, and business fit.',
              ),
              ContentSection(
                title: 'What you see',
                body:
                    'Clients see sourced leads, readiness, contact status, and outreach progress. Operator-only provider details stay out of the client workspace.',
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
                'Deliverability, permission, and records are part of the service.',
            subtitle:
                'Outbound work needs a clear sender posture, representation authorization, suppression handling, and service records.',
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
                    'The system tracks domains, mailboxes, policies, suppressions, bounces, complaints, and mailbox health.',
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
            title:
                'Managed revenue operations for businesses that need follow-through.',
            subtitle:
                'Orchestrate exists to connect opportunity creation, outreach execution, replies, meetings, billing continuity, records, and support.',
            sections: [
              ContentSection(
                title: 'Why the separation matters',
                body:
                    'Visitors get a buying journey, clients get a calm service workspace, and operators get the command tools needed to keep work moving.',
              ),
              ContentSection(
                title: 'What stays fixed',
                body:
                    'Setup defines the business and target market. Campaigns guide sourcing and outreach. Replies and meetings carry the outcome forward.',
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
            eyebrow: 'Updates',
            title: 'Updates will appear here when available.',
            subtitle:
                'Public product notes and revenue operations updates are not available yet. Account-specific notices appear inside the client workspace.',
            sections: [
              ContentSection(
                title: 'Public updates',
                body:
                    'This page will hold public product updates when the update subscription is enabled.',
              ),
              ContentSection(
                title: 'Client communications',
                body:
                    'Client notices, reminders, and service records appear after sign-in when they are available for the account.',
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
                'Public update subscriptions are not connected yet. Use contact for now if you want to talk through fit or timing.',
            sections: [
              ContentSection(
                title: 'Status',
                body:
                    'This feature will appear here when it is available. For now, contact is the useful next action.',
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
            builder: (context, state) => const ClientOutreachScreen()),
        GoRoute(
            path: '/client/replies',
            builder: (context, state) => const ClientRepliesScreen()),
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
