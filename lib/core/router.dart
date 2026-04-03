import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/campaigns_screen.dart';
import '../screens/clients_screen.dart';
import '../screens/command_screen.dart';
import '../screens/public/contact_screen.dart';
import '../screens/public/pricing_screen.dart';
import '../screens/leads_screen.dart';
import '../screens/meetings_screen.dart';
import '../screens/replies_screen.dart';
import '../screens/system_screen.dart';
import '../screens/auth/client_login_screen.dart';
import '../screens/auth/ops_login_screen.dart';
import '../screens/public/public_content_screen.dart';
import '../screens/public/public_home_screen.dart';
import '../shell/app_shell.dart';
import '../shell/public_shell.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => PublicShell(
        currentPath: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const PublicHomeScreen()),
        GoRoute(path: '/how-it-works', builder: (context, state) => buildHowItWorksScreen()),
        GoRoute(path: '/pricing', builder: (context, state) => const PricingScreen()),
        GoRoute(path: '/contact', builder: (context, state) => const ContactScreen()),
        GoRoute(path: '/client/login', builder: (context, state) => const ClientLoginScreen()),
        GoRoute(
          path: '/client/create-account',
          builder: (context, state) => const ClientLoginScreen(createMode: true),
        ),
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
    ShellRoute(
      builder: (context, state, child) => AppShell(
        currentPath: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(path: '/app/command', builder: (context, state) => const CommandScreen()),
        GoRoute(path: '/app/pipeline', builder: (context, state) => const LeadsScreen()),
        GoRoute(path: '/app/execution/campaigns', builder: (context, state) => const CampaignsScreen()),
        GoRoute(path: '/app/execution/replies', builder: (context, state) => const RepliesScreen()),
        GoRoute(path: '/app/execution/meetings', builder: (context, state) => const MeetingsScreen()),
        GoRoute(path: '/app/clients', builder: (context, state) => const ClientsScreen()),
        GoRoute(
          path: '/app/revenue',
          builder: (context, state) => const SystemScreen(
            title: 'Revenue',
            subtitle: 'Billing, agreements, reminders, statements, and payment records carried together.',
          ),
        ),
        GoRoute(
          path: '/app/deliverability',
          builder: (context, state) => const SystemScreen(
            title: 'Deliverability',
            subtitle: 'Mailboxes, sender posture, and sending stability in one controlled surface.',
          ),
        ),
        GoRoute(
          path: '/app/communications',
          builder: (context, state) => const SystemScreen(
            title: 'Communications',
            subtitle: 'Templates, notifications, reminders, and dispatch history in one working layer.',
          ),
        ),
        GoRoute(
          path: '/app/records',
          builder: (context, state) => const SystemScreen(
            title: 'Records',
            subtitle: 'Statements, receipts, agreements, and historical accountability.',
          ),
        ),
        GoRoute(
          path: '/app/settings',
          builder: (context, state) => const SystemScreen(
            title: 'Settings',
            subtitle: 'Workspace policy, access, configuration, and defaults.',
          ),
        ),
      ],
    ),
    GoRoute(path: '/command', redirect: (_, __) => '/app/command'),
    GoRoute(path: '/clients', redirect: (_, __) => '/app/clients'),
    GoRoute(path: '/campaigns', redirect: (_, __) => '/app/execution/campaigns'),
    GoRoute(path: '/leads', redirect: (_, __) => '/app/pipeline'),
    GoRoute(path: '/replies', redirect: (_, __) => '/app/execution/replies'),
    GoRoute(path: '/meetings', redirect: (_, __) => '/app/execution/meetings'),
    GoRoute(path: '/system', redirect: (_, __) => '/app/settings'),
  ],
  errorBuilder: (context, state) => Theme(
    data: ThemeData.light(useMaterial3: true),
    child: const Scaffold(
      body: Center(child: Text('This surface is unavailable.')),
    ),
  ),
);
