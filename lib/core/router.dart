import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/client_login_screen.dart';
import '../screens/auth/ops_login_screen.dart';
import '../screens/client_workspace_screen.dart';
import '../screens/operator_workspace_screen.dart';
import '../screens/public/contact_screen.dart';
import '../screens/public/pricing_screen.dart';
import '../screens/public/public_content_screen.dart';
import '../screens/public/public_home_screen.dart';
import '../shell/app_shell.dart';
import '../shell/client_shell.dart';
import '../shell/public_shell.dart';
import 'auth/auth_session.dart';

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: AuthSessionController.instance,
  redirect: (context, state) {
    final session = AuthSessionController.instance;
    if (!session.isReady) return null;
    final path = state.uri.path;
    final isClientAuth = path == '/client/login' || path == '/client/join';
    final isOpsAuth = path == '/ops/login' || path == '/ops/join';
    final isPublic = path == '/' || path.startsWith('/how-it-works') || path.startsWith('/pricing') || path.startsWith('/contact') || path.startsWith('/legal/');

    if (session.isAuthenticated) {
      if (session.surface == 'operator') {
        if (isOpsAuth || path == '/') return '/app/command';
      }
      if (session.surface == 'client') {
        if (isClientAuth || path == '/') return '/client/workspace';
      }
    }

    if (!session.isAuthenticated) {
      if (path.startsWith('/app/')) return '/ops/login';
      if (path.startsWith('/client/workspace') || path.startsWith('/client/billing') || path.startsWith('/client/agreements') || path.startsWith('/client/statements') || path.startsWith('/client/account')) {
        return '/client/login';
      }
    }

    if (isPublic || isClientAuth || isOpsAuth || path.startsWith('/client/verify-email') || path.startsWith('/client/reset-password')) {
      return null;
    }
    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) => PublicShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const PublicHomeScreen()),
        GoRoute(path: '/how-it-works', builder: (context, state) => buildHowItWorksScreen()),
        GoRoute(path: '/pricing', builder: (context, state) => const PricingScreen()),
        GoRoute(path: '/contact', builder: (context, state) => const ContactScreen()),
        GoRoute(path: '/client/login', builder: (context, state) => const ClientLoginScreen()),
        GoRoute(path: '/client/join', builder: (context, state) => const ClientLoginScreen(createMode: true)),
        GoRoute(path: '/client/verify-email', builder: (context, state) => const ClientLoginScreen(verificationMode: true)),
        GoRoute(path: '/client/reset-password', builder: (context, state) => const ClientLoginScreen(resetMode: true)),
        GoRoute(path: '/legal/terms', builder: (context, state) => buildTermsScreen()),
        GoRoute(path: '/legal/privacy', builder: (context, state) => buildPrivacyScreen()),
        GoRoute(path: '/legal/billing', builder: (context, state) => buildBillingPolicyScreen()),
        GoRoute(path: '/legal/refunds', builder: (context, state) => buildRefundPolicyScreen()),
        GoRoute(path: '/legal/acceptable-use', builder: (context, state) => buildAcceptableUseScreen()),
        GoRoute(path: '/legal/service-agreement', builder: (context, state) => buildServiceAgreementScreen()),
        GoRoute(path: '/legal/deliverability', builder: (context, state) => buildDeliverabilityScreen()),
      ],
    ),
    GoRoute(path: '/ops/login', builder: (context, state) => const OpsLoginScreen()),
    GoRoute(path: '/ops/join', builder: (context, state) => const OpsLoginScreen(createMode: true)),
    ShellRoute(
      builder: (context, state, child) => ClientShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/client/workspace', builder: (context, state) => const ClientWorkspaceScreen(section: ClientSection.overview)),
        GoRoute(path: '/client/billing', builder: (context, state) => const ClientWorkspaceScreen(section: ClientSection.billing)),
        GoRoute(path: '/client/agreements', builder: (context, state) => const ClientWorkspaceScreen(section: ClientSection.agreements)),
        GoRoute(path: '/client/statements', builder: (context, state) => const ClientWorkspaceScreen(section: ClientSection.statements)),
        GoRoute(path: '/client/account', builder: (context, state) => const ClientWorkspaceScreen(section: ClientSection.account)),
      ],
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/app/command', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.command)),
        GoRoute(path: '/app/pipeline', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.pipeline)),
        GoRoute(path: '/app/execution/campaigns', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.execution)),
        GoRoute(path: '/app/execution/replies', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.execution)),
        GoRoute(path: '/app/execution/meetings', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.execution)),
        GoRoute(path: '/app/clients', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.clients)),
        GoRoute(path: '/app/revenue', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.revenue)),
        GoRoute(path: '/app/deliverability', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.deliverability)),
        GoRoute(path: '/app/communications', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.communications)),
        GoRoute(path: '/app/records', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.records)),
        GoRoute(path: '/app/settings', builder: (context, state) => const OperatorWorkspaceScreen(section: OperatorSection.settings)),
      ],
    ),
  ],
  errorBuilder: (context, state) => Theme(
    data: ThemeData.light(useMaterial3: true),
    child: const Scaffold(body: Center(child: Text('This surface is unavailable.'))),
  ),
);
