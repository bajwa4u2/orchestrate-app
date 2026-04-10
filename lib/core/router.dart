import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/client_login_screen.dart';
import '../screens/auth/ops_login_screen.dart';
import '../screens/client_setup_screen.dart';
import '../screens/client_subscribe_screen.dart';
import '../screens/client_support_screen.dart';
import '../screens/client_workspace_screen.dart';
import '../screens/inquiries_list_screen.dart';
import '../screens/inquiry_detail_screen.dart';
import '../screens/meetings_screen.dart';
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
final _appShellNavigatorKey = GlobalKey<NavigatorState>();

const _clientCoreRoutes = <String>{
  '/client/workspace',
  '/client/outreach',
  '/client/meetings',
  '/client/billing',
  '/client/account',
  '/client/help',
};

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: AuthSessionController.instance,
  redirect: (context, state) {
    final session = AuthSessionController.instance;
    if (!session.isReady) return null;

    final path = state.uri.path;
    final plan = _normalized(state.uri.queryParameters['plan']) ??
        session.selectedPlan;
    final tier = _normalized(state.uri.queryParameters['tier']) ??
        session.selectedTier;
    final trial = _normalized(state.uri.queryParameters['trial']);

    final isClientAuth =
        <String>{'/client/login', '/client/join', '/login', '/join'}
            .contains(path);
    final isOpsAuth =
        <String>{'/ops/login', '/ops/join', '/ops-login', '/ops-join'}
            .contains(path);
    final isVerification = path == '/client/verify-email';
    final isReset = path == '/client/reset-password';
    final isSetup = path == '/client/setup';
    final isSubscribe = path == '/client/subscribe';
    final isClientArea =
        _clientCoreRoutes.contains(path) || path.startsWith('/client/');

    if (!session.isAuthenticated) {
      if (path.startsWith('/app/')) return '/ops/login';
      if (isClientArea || isSetup || isSubscribe) {
        return _clientRoute('/client/login', plan: plan, tier: tier, trial: trial);
      }
      return null;
    }

    if (session.surface == 'operator') {
      if (isOpsAuth || path == '/') return '/app/command';
      if (path.startsWith('/client/')) return '/app/command';
      return null;
    }

    if (session.surface == 'client') {
      if (!session.emailVerified) {
        if (isVerification || isReset) return null;
        return _clientRoute(
          '/client/verify-email',
          plan: plan,
          tier: tier,
          trial: trial,
        );
      }

      final setupAllowed = <String>{
        '/client/setup',
        '/client/workspace',
        '/client/billing',
        '/client/account',
        '/client/help',
      };

      if (!session.hasSetupCompleted) {
        if (setupAllowed.contains(path)) return null;
        return _clientRoute('/client/setup', plan: plan, tier: tier, trial: trial);
      }

      final subscriptionAllowed = <String>{
        '/client/workspace',
        '/client/outreach',
        '/client/meetings',
        '/client/billing',
        '/client/account',
        '/client/help',
        '/client/subscribe',
      };

      if (session.normalizedSubscriptionStatus != 'active') {
        if (subscriptionAllowed.contains(path)) return null;
        return _clientRoute(
          '/client/workspace',
          plan: plan,
          tier: tier,
          trial: trial,
        );
      }

      if (isClientAuth ||
          isVerification ||
          isReset ||
          isSetup ||
          isSubscribe ||
          path == '/') {
        return '/client/workspace';
      }
      if (isOpsAuth) return '/client/workspace';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/ops/login', builder: (context, state) => const OpsLoginScreen()),
    GoRoute(
      path: '/ops/join',
      builder: (context, state) => const OpsLoginScreen(createMode: true),
    ),
    GoRoute(path: '/ops-login', redirect: (context, state) => '/ops/login'),
    GoRoute(path: '/ops-join', redirect: (context, state) => '/ops/join'),
    GoRoute(
      path: '/client/login',
      builder: (context, state) => const ClientLoginScreen(),
    ),
    GoRoute(
      path: '/client/join',
      builder: (context, state) => const ClientLoginScreen(createMode: true),
    ),
    GoRoute(path: '/login', redirect: (context, state) => '/client/login'),
    GoRoute(path: '/join', redirect: (context, state) => '/client/join'),
    GoRoute(
      path: '/client/verify-email',
      builder: (context, state) => const ClientLoginScreen(verificationMode: true),
    ),
    GoRoute(
      path: '/client/reset-password',
      builder: (context, state) => const ClientLoginScreen(resetMode: true),
    ),
    GoRoute(path: '/client/setup', builder: (context, state) => const ClientSetupScreen()),
    GoRoute(
      path: '/client/subscribe',
      builder: (context, state) => const ClientSubscribeScreen(),
    ),
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: const PublicHomeScreen()),
      ),
    ),
    GoRoute(
      path: '/how-it-works',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: buildHowItWorksScreen()),
      ),
    ),
    GoRoute(
      path: '/pricing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: const PricingScreen()),
      ),
    ),
    GoRoute(
      path: '/contact',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(currentPath: state.uri.path, child: const ContactScreen()),
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
    ShellRoute(
      navigatorKey: _clientShellNavigatorKey,
      builder: (context, state, child) => ClientShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/client/workspace',
          builder: (context, state) =>
              const ClientWorkspaceScreen(section: ClientSection.workspace),
        ),
        GoRoute(
          path: '/client/outreach',
          builder: (context, state) =>
              const ClientWorkspaceScreen(section: ClientSection.outreach),
        ),
        GoRoute(
          path: '/client/meetings',
          builder: (context, state) => const MeetingsScreen(),
        ),
        GoRoute(
          path: '/client/billing',
          builder: (context, state) =>
              const ClientWorkspaceScreen(section: ClientSection.billing),
        ),
        GoRoute(
          path: '/client/account',
          builder: (context, state) =>
              const ClientWorkspaceScreen(section: ClientSection.account),
        ),
        GoRoute(
          path: '/client/help',
          builder: (context, state) => const ClientSupportScreen(),
        ),
      ],
    ),
    ShellRoute(
      navigatorKey: _appShellNavigatorKey,
      builder: (context, state, child) => AppShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/app/command',
          builder: (context, state) =>
              const OperatorWorkspaceScreen(section: OperatorSection.command),
        ),
        GoRoute(
          path: '/app/pipeline',
          builder: (context, state) =>
              const OperatorWorkspaceScreen(section: OperatorSection.pipeline),
        ),
        GoRoute(path: '/app/inquiries', builder: (context, state) => const InquiriesListScreen()),
        GoRoute(
          path: '/app/inquiries/:id',
          builder: (context, state) =>
              InquiryDetailScreen(inquiryId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/app/execution/campaigns',
          builder: (context, state) =>
              const OperatorWorkspaceScreen(section: OperatorSection.execution),
        ),
        GoRoute(
          path: '/app/execution/replies',
          builder: (context, state) =>
              const OperatorWorkspaceScreen(section: OperatorSection.execution),
        ),
        GoRoute(
          path: '/app/execution/meetings',
          builder: (context, state) =>
              const OperatorWorkspaceScreen(section: OperatorSection.execution),
        ),
        GoRoute(
          path: '/app/clients',
          builder: (context, state) =>
              const OperatorWorkspaceScreen(section: OperatorSection.clients),
        ),
        GoRoute(
          path: '/app/revenue',
          builder: (context, state) =>
              const OperatorWorkspaceScreen(section: OperatorSection.revenue),
        ),
        GoRoute(
          path: '/app/deliverability',
          builder: (context, state) => const OperatorWorkspaceScreen(
            section: OperatorSection.deliverability,
          ),
        ),
        GoRoute(
          path: '/app/communications',
          builder: (context, state) => const OperatorWorkspaceScreen(
            section: OperatorSection.communications,
          ),
        ),
        GoRoute(
          path: '/app/records',
          builder: (context, state) =>
              const OperatorWorkspaceScreen(section: OperatorSection.records),
        ),
        GoRoute(
          path: '/app/settings',
          builder: (context, state) =>
              const OperatorWorkspaceScreen(section: OperatorSection.settings),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Theme(
    data: ThemeData.light(useMaterial3: true),
    child: const Scaffold(body: Center(child: Text('This surface is unavailable.'))),
  ),
);

String? _normalized(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  return text;
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
