import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/client_login_screen.dart';
import '../screens/auth/ops_login_screen.dart';
import '../screens/campaigns_screen.dart';
import '../screens/client/client_activity_screen.dart';
import '../screens/client/client_branding_screen.dart';
import '../screens/client/client_contacts_screen.dart';
import '../screens/client/client_mailbox_screen.dart';
import '../screens/client/client_newsletter_screen.dart';
import '../screens/client_account_screen.dart';
import '../screens/client_setup_screen.dart';
import '../screens/client_subscribe_screen.dart';
import '../screens/client_workspace_screen.dart';
import '../screens/inquiry_detail_screen.dart';
import '../screens/meetings_screen.dart';
import '../screens/operator/operator_debug_screen.dart';
import '../screens/operator/operator_providers_screen.dart';
import '../screens/operator_workspace_screen.dart';
import '../screens/public/contact_screen.dart';
import '../screens/public/pricing_screen.dart';
import '../screens/public/public_content_screen.dart';
import '../screens/public/public_home_screen.dart';
import '../shell/app_shell.dart';
import '../shell/client_shell.dart';
import '../shell/public_shell.dart';
import 'auth/auth_session.dart';

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

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: AuthSessionController.instance,
  redirect: (context, state) {
    final session = AuthSessionController.instance;
    if (!session.isReady) return null;

    final path = state.uri.path;
    final plan = _normalizedPlan(state.uri.queryParameters['plan']) ?? session.selectedPlan;
    final tier = _normalizedTier(state.uri.queryParameters['tier']) ?? session.selectedTier;
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
    final isVerification = <String>{'/auth/verify-email', '/client/verify-email'}.contains(path);
    final isReset = <String>{'/auth/reset-password', '/client/reset-password'}.contains(path);
    final isSetup = <String>{'/app/setup', '/client/setup'}.contains(path);
    final isSubscribe = <String>{'/app/subscribe', '/client/subscribe'}.contains(path);
    final isClientArea = _clientCoreRoutes.contains(path) || path.startsWith('/app/');
    final isOperatorArea = path.startsWith('/ops/') && !isOpsAuth;

    if (!session.isAuthenticated) {
      if (isOperatorArea) return '/ops/login';
      if (isVerification || isReset) return null;
      if (isClientArea || isSetup || isSubscribe) {
        return _clientRoute('/auth/login', plan: plan, tier: tier, trial: trial);
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
        return _clientRoute('/auth/verify-email', plan: plan, tier: tier, trial: trial);
      }

      final setupAllowed = <String>{'/app/setup', '/app/home', '/app/billing', '/app/account'};
      if (!session.hasSetupCompleted) {
        if (setupAllowed.contains(path)) return null;
        return _clientRoute('/app/setup', plan: plan, tier: tier, trial: trial);
      }

      final subscriptionAllowed = <String>{'/app/subscribe', '/app/billing', '/app/account', '/app/campaigns'};
      if (session.normalizedSubscriptionStatus != 'active') {
        if (subscriptionAllowed.contains(path)) return null;
        return _clientRoute('/app/subscribe', plan: plan, tier: tier, trial: trial);
      }

      if (isClientAuth || isVerification || isReset || isSetup || isSubscribe || path == '/') {
        return '/app/home';
      }
      if (isOpsAuth || path.startsWith('/ops/')) return '/app/home';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/ops/login', builder: (context, state) => const OpsLoginScreen()),
    GoRoute(path: '/ops/join', builder: (context, state) => const OpsLoginScreen(createMode: true)),
    GoRoute(path: '/ops-login', redirect: (context, state) => '/ops/login'),
    GoRoute(path: '/ops-join', redirect: (context, state) => '/ops/join'),
    GoRoute(path: '/auth/login', builder: (context, state) => const ClientLoginScreen()),
    GoRoute(path: '/auth/join', builder: (context, state) => const ClientLoginScreen(createMode: true)),
    GoRoute(path: '/auth/verify-email', builder: (context, state) => const ClientLoginScreen(verificationMode: true)),
    GoRoute(path: '/auth/reset-password', builder: (context, state) => const ClientLoginScreen(resetMode: true)),
    GoRoute(path: '/login', redirect: (context, state) => '/auth/login'),
    GoRoute(path: '/join', redirect: (context, state) => '/auth/join'),
    GoRoute(path: '/client/login', redirect: (context, state) => '/auth/login'),
    GoRoute(path: '/client/join', redirect: (context, state) => '/auth/join'),
    GoRoute(path: '/client/verify-email', redirect: (context, state) => '/auth/verify-email'),
    GoRoute(path: '/client/reset-password', redirect: (context, state) => '/auth/reset-password'),
    GoRoute(path: '/client/setup', redirect: (context, state) => '/app/setup'),
    GoRoute(path: '/client/subscribe', redirect: (context, state) => '/app/subscribe'),
    GoRoute(path: '/client/workspace', redirect: (context, state) => '/app/home'),
    GoRoute(path: '/client/leads', redirect: (context, state) => '/app/contacts'),
    GoRoute(path: '/client/outreach', redirect: (context, state) => '/app/contacts'),
    GoRoute(path: '/client/campaigns', redirect: (context, state) => '/app/campaigns'),
    GoRoute(path: '/client/meetings', redirect: (context, state) => '/app/activity'),
    GoRoute(path: '/client/billing', redirect: (context, state) => '/app/billing'),
    GoRoute(path: '/client/account', redirect: (context, state) => '/app/account'),
    GoRoute(path: '/client/help', redirect: (context, state) => '/app/account'),
    GoRoute(path: '/app/command', redirect: (context, state) => '/ops/overview'),
    GoRoute(path: '/app/pipeline', redirect: (context, state) => '/ops/contacts'),
    GoRoute(path: '/app/inquiries', redirect: (context, state) => '/ops/inquiries'),
    GoRoute(path: '/app/inquiries/:id', redirect: (context, state) => '/ops/inquiries/${state.pathParameters['id'] ?? ''}'),
    GoRoute(path: '/app/execution', redirect: (context, state) => '/ops/campaigns'),
    GoRoute(path: '/app/execution/campaigns', redirect: (context, state) => '/ops/campaigns'),
    GoRoute(path: '/app/execution/replies', redirect: (context, state) => '/ops/activity'),
    GoRoute(path: '/app/execution/meetings', redirect: (context, state) => '/ops/activity'),
    GoRoute(path: '/app/clients', redirect: (context, state) => '/ops/clients'),
    GoRoute(path: '/app/revenue', redirect: (context, state) => '/ops/activity'),
    GoRoute(path: '/app/deliverability', redirect: (context, state) => '/ops/mailboxes'),
    GoRoute(path: '/app/communications', redirect: (context, state) => '/ops/activity'),
    GoRoute(path: '/app/records', redirect: (context, state) => '/ops/activity'),
    GoRoute(path: '/app/settings', redirect: (context, state) => '/ops/debug'),

    GoRoute(
      path: '/',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: const PublicHomeScreen()),
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
            subtitle: 'Orchestrate separates public trust, client control, and operator execution so revenue work stays legible.',
            sections: [
              ContentSection(
                title: 'What the system does',
                body: 'The product is built to handle targeting, outreach movement, follow-up, and meeting handoff without confusing those surfaces with billing, support, or operator governance.',
              ),
              ContentSection(
                title: 'How the frontend is organized',
                body: 'Public explains the product. Client manages its own working system. Operator carries execution, inquiries, providers, and debug reality.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/pricing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: const PricingScreen()),
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
            subtitle: 'The structure matters because products drift when public messaging, client work, and operator control are mixed together.',
            sections: [
              ContentSection(
                title: 'Why the separation matters',
                body: 'Public should explain. Client should control its own system. Operator should manage execution truth. That boundary is now carried directly in the frontend constitution.',
              ),
              ContentSection(
                title: 'What stays fixed',
                body: 'Contacts remains the client memory surface, campaigns remains execution setup, and activity remains execution truth.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/contact',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: const ContactScreen()),
      ),
    ),
    GoRoute(
      path: '/newsletter',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Newsletter',
            title: 'Newsletter belongs in the public system and the client system.',
            subtitle: 'Public subscription and client management remain separate on purpose.',
            sections: [
              ContentSection(
                title: 'Public side',
                body: 'This is where subscription starts, without pretending to be part of the client workspace.',
              ),
              ContentSection(
                title: 'Client side',
                body: 'Audience, issues, and settings remain owned by the client shell once those controls are expanded.',
              ),
            ],
            sideActions: [
              ContentAction(label: 'Subscribe', path: '/newsletter/subscribe', filled: true),
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
            subtitle: 'This public route stays in place so newsletter does not drift into the wrong system while the final subscribe experience is still being completed.',
            sections: [
              ContentSection(
                title: 'Status',
                body: 'The route is live and intentionally reserved. The final subscription form can land here without reworking the public IA again.',
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
        child: PublicShell(currentPath: state.uri.path, child: buildTermsScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/privacy',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: buildPrivacyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/billing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: buildBillingPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/refunds',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: buildRefundPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/acceptable-use',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: buildAcceptableUseScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/service-agreement',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: buildServiceAgreementScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/deliverability',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: buildDeliverabilityScreen()),
      ),
    ),

    GoRoute(path: '/app/setup', builder: (context, state) => const ClientSetupScreen()),
    GoRoute(path: '/app/subscribe', builder: (context, state) => const ClientSubscribeScreen()),
    ShellRoute(
      navigatorKey: _clientShellNavigatorKey,
      builder: (context, state, child) => ClientShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/app/home', builder: (context, state) => const ClientHomeScreen(section: ClientSection.home)),
        GoRoute(path: '/app/contacts', builder: (context, state) => const ClientContactsScreen()),
        GoRoute(path: '/app/contacts/import', redirect: (context, state) => '/app/contacts'),
        GoRoute(path: '/app/contacts/:contactId', redirect: (context, state) => '/app/contacts'),
        GoRoute(path: '/app/campaigns', builder: (context, state) => const CampaignsScreen()),
        GoRoute(path: '/app/campaigns/create', redirect: (context, state) => '/app/campaigns'),
        GoRoute(path: '/app/campaigns/:campaignId', redirect: (context, state) => '/app/campaigns'),
        GoRoute(path: '/app/activity', builder: (context, state) => const ClientActivityScreen()),
        GoRoute(path: '/app/mailbox', builder: (context, state) => const ClientMailboxScreen()),
        GoRoute(path: '/app/newsletter', builder: (context, state) => const ClientNewsletterScreen()),
        GoRoute(path: '/app/newsletter/audience', redirect: (context, state) => '/app/newsletter'),
        GoRoute(path: '/app/newsletter/issues', redirect: (context, state) => '/app/newsletter'),
        GoRoute(path: '/app/newsletter/settings', redirect: (context, state) => '/app/newsletter'),
        GoRoute(path: '/app/branding', builder: (context, state) => const ClientBrandingScreen()),
        GoRoute(path: '/app/branding/identity', redirect: (context, state) => '/app/branding'),
        GoRoute(path: '/app/branding/templates', redirect: (context, state) => '/app/branding'),
        GoRoute(path: '/app/branding/signatures', redirect: (context, state) => '/app/branding'),
        GoRoute(path: '/app/billing', builder: (context, state) => const ClientHomeScreen(section: ClientSection.billing)),
        GoRoute(path: '/app/account', builder: (context, state) => const ClientAccountScreen()),
      ],
    ),

    ShellRoute(
      navigatorKey: _operatorShellNavigatorKey,
      builder: (context, state, child) => AppShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/ops/overview', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.command)),
        GoRoute(path: '/ops/clients', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.clients)),
        GoRoute(path: '/ops/contacts', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.pipeline)),
        GoRoute(path: '/ops/campaigns', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.campaigns)),
        GoRoute(path: '/ops/mailboxes', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.deliverability)),
        GoRoute(path: '/ops/providers', builder: (context, state) => const OperatorProvidersScreen()),
        GoRoute(path: '/ops/activity', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.inquiries)),
        GoRoute(path: '/ops/inquiries', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.inquiries)),
        GoRoute(path: '/ops/inquiries/:id', builder: (context, state) => InquiryDetailScreen(inquiryId: state.pathParameters['id'] ?? '')),
        GoRoute(path: '/ops/debug', builder: (context, state) => const OperatorDebugScreen()),
      ],
    ),
  ],
  errorBuilder: (context, state) => Theme(
    data: ThemeData.light(useMaterial3: true),
    child: const Scaffold(body: Center(child: Text('This surface is unavailable.'))),
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
  if (text == 'multi' || text == 'multi-market' || text == 'multi_market') return 'multi';
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
