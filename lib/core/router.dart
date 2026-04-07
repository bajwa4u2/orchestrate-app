import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/client_login_screen.dart';
import '../screens/auth/ops_login_screen.dart';
import '../screens/client_setup_screen.dart';
import '../screens/client_subscribe_screen.dart';
import '../screens/client_workspace_screen.dart';
import '../screens/inquiries_list_screen.dart';
import '../screens/inquiry_detail_screen.dart';
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

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: AuthSessionController.instance,
  redirect: (context, state) {
    final session = AuthSessionController.instance;
    if (!session.isReady) return null;

    final path = state.uri.path;
    final planQuery = state.uri.queryParameters['plan']?.trim().toLowerCase();

    final isClientAuth = path == '/client/login' || path == '/client/join';
    final isOpsAuth = path == '/ops/login' || path == '/ops/join';
    final isPublic = path == '/' ||
        path == '/how-it-works' ||
        path == '/pricing' ||
        path == '/contact' ||
        path.startsWith('/legal/');
    final isVerificationFlow = path == '/client/verify-email';
    final isResetFlow = path == '/client/reset-password';
    final isSetupFlow = path == '/client/setup';
    final isSubscribeFlow = path == '/client/subscribe';
    final isClientWorkspacePath =
        path.startsWith('/client/workspace') ||
        path.startsWith('/client/billing') ||
        path.startsWith('/client/agreements') ||
        path.startsWith('/client/statements') ||
        path.startsWith('/client/account');

    if (!session.isAuthenticated) {
      if (path.startsWith('/app/')) return '/ops/login';
      if (isClientWorkspacePath || isSetupFlow || isSubscribeFlow) return '/client/login';
      return null;
    }

    if (session.surface == 'operator') {
      if (isOpsAuth || path == '/') return '/app/command';
      if (path.startsWith('/client/')) return '/app/command';
      return null;
    }

    if (session.surface == 'client') {
      final selectedPlan = session.selectedPlan ?? planQuery;
      final subscribeTarget = selectedPlan != null && selectedPlan.isNotEmpty
          ? Uri(path: '/client/subscribe', queryParameters: {'plan': selectedPlan}).toString()
          : '/client/subscribe';

      if (!session.emailVerified) {
        if (!isVerificationFlow && !isResetFlow) {
          return '/client/verify-email';
        }
        return null;
      }

      if (!session.hasSetupCompleted) {
        if (!isSetupFlow) {
          return selectedPlan != null && selectedPlan.isNotEmpty
              ? Uri(path: '/client/setup', queryParameters: {'plan': selectedPlan}).toString()
              : '/client/setup';
        }
        return null;
      }

      if (session.normalizedSubscriptionStatus != 'active') {
        final allowAccess =
            isSubscribeFlow || path.startsWith('/client/account');

        if (!allowAccess) {
         return subscribeTarget;
        }
        
        return null;
      }

      if (isClientAuth || path == '/' || isVerificationFlow || isSubscribeFlow || isSetupFlow) {
        return '/client/workspace';
      }

      return null;
    }

    if (isPublic || isClientAuth || isOpsAuth || isVerificationFlow || isResetFlow) {
      return null;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/ops/login',
      builder: (context, state) => const OpsLoginScreen(),
    ),
    GoRoute(
      path: '/ops/join',
      builder: (context, state) => const OpsLoginScreen(createMode: true),
    ),
    GoRoute(
      path: '/client/login',
      builder: (context, state) => const ClientLoginScreen(),
    ),
    GoRoute(
      path: '/client/join',
      builder: (context, state) => const ClientLoginScreen(createMode: true),
    ),
    GoRoute(
      path: '/client/verify-email',
      builder: (context, state) =>
          const ClientLoginScreen(verificationMode: true),
    ),
    GoRoute(
      path: '/client/reset-password',
      builder: (context, state) => const ClientLoginScreen(resetMode: true),
    ),
    GoRoute(
      path: '/client/setup',
      builder: (context, state) => const ClientSetupScreen(),
    ),
    GoRoute(
      path: '/client/subscribe',
      builder: (context, state) => const ClientSubscribeScreen(),
    ),
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicHomeScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/how-it-works',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: buildHowItWorksScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/pricing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PricingScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/contact',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const ContactScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/legal/terms',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: buildTermsScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/legal/privacy',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: buildPrivacyScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/legal/billing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: buildBillingPolicyScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/legal/refunds',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: buildRefundPolicyScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/legal/acceptable-use',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: buildAcceptableUseScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/legal/service-agreement',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: buildServiceAgreementScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/legal/deliverability',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: buildDeliverabilityScreen(),
        ),
      ),
    ),
    ShellRoute(
      navigatorKey: _clientShellNavigatorKey,
      builder: (context, state, child) =>
          ClientShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/client/workspace',
          builder: (context, state) =>
              const ClientWorkspaceScreen(section: ClientSection.overview),
        ),
        GoRoute(
          path: '/client/billing',
          builder: (context, state) =>
              const ClientWorkspaceScreen(section: ClientSection.billing),
        ),
        GoRoute(
          path: '/client/agreements',
          builder: (context, state) =>
              const ClientWorkspaceScreen(section: ClientSection.agreements),
        ),
        GoRoute(
          path: '/client/statements',
          builder: (context, state) =>
              const ClientWorkspaceScreen(section: ClientSection.statements),
        ),
        GoRoute(
          path: '/client/account',
          builder: (context, state) =>
              const ClientWorkspaceScreen(section: ClientSection.account),
        ),
      ],
    ),
    ShellRoute(
      navigatorKey: _appShellNavigatorKey,
      builder: (context, state, child) =>
          AppShell(currentPath: state.uri.path, child: child),
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
        GoRoute(
          path: '/app/inquiries',
          builder: (context, state) => const InquiriesListScreen(),
        ),
        GoRoute(
          path: '/app/inquiries/:id',
          builder: (context, state) => InquiryDetailScreen(
            inquiryId: state.pathParameters['id'] ?? '',
          ),
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
    child: const Scaffold(
      body: Center(child: Text('This surface is unavailable.')),
    ),
  ),
);
