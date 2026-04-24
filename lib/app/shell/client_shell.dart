import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';

class ClientShell extends StatefulWidget {
  const ClientShell(
      {super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  final ClientBillingRepository _billingRepository = ClientBillingRepository();
  Map<String, dynamic>? _subscription;

  static const double _sidebarWidth = 284;
  static const double _maxContentWidth = 1320;

  static const List<_ClientNavItem> _primaryItems = [
    _ClientNavItem(
        label: 'Overview',
        path: '/client/overview',
        icon: Icons.space_dashboard_outlined),
    _ClientNavItem(
        label: 'Campaign', path: '/client/campaign', icon: Icons.flag_outlined),
    _ClientNavItem(
        label: 'Leads', path: '/client/leads', icon: Icons.people_alt_outlined),
    _ClientNavItem(
        label: 'Outreach',
        path: '/client/outreach',
        icon: Icons.mark_email_unread_outlined),
    _ClientNavItem(
        label: 'Replies', path: '/client/replies', icon: Icons.forum_outlined),
    _ClientNavItem(
        label: 'Meetings',
        path: '/client/meetings',
        icon: Icons.calendar_month_outlined),
    _ClientNavItem(
        label: 'Billing',
        path: '/client/billing',
        icon: Icons.credit_card_outlined),
    _ClientNavItem(
        label: 'Records',
        path: '/client/agreements',
        icon: Icons.description_outlined),
    _ClientNavItem(
        label: 'Notifications',
        path: '/client/notifications',
        icon: Icons.notifications_none_outlined),
    _ClientNavItem(
        label: 'Support',
        path: '/client/support',
        icon: Icons.support_agent_outlined),
    _ClientNavItem(
        label: 'Settings',
        path: '/client/settings',
        icon: Icons.manage_accounts_outlined),
  ];

  @override
  void initState() {
    super.initState();
    AuthSessionController.instance.addListener(_handleSessionChanged);
    _refreshSubscription();
  }

  @override
  void dispose() {
    AuthSessionController.instance.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    _refreshSubscription();
  }

  Future<void> _refreshSubscription() async {
    try {
      final data = await _billingRepository.fetchSubscription();
      if (!mounted) return;
      setState(() => _subscription = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _subscription = null);
    }
  }

  String _subscriptionLabel(AuthSessionController session) {
    final service = (_subscription?['serviceName'] ??
            _subscription?['service'] ??
            session.selectedPlan ??
            'Not set')
        .toString()
        .trim();
    final tier = (_subscription?['tierName'] ??
            _subscription?['tier'] ??
            session.selectedTier ??
            '')
        .toString()
        .trim();
    return [service, tier].where((e) => e.isNotEmpty).join(' · ');
  }

  String _billingLabel(AuthSessionController session) {
    return (_subscription?['status'] ?? session.subscriptionStatus)
            .toString()
            .trim()
            .isEmpty
        ? 'Unknown'
        : (_subscription?['status'] ?? session.subscriptionStatus)
            .toString()
            .trim();
  }

  String _topTitle() {
    switch (widget.currentPath) {
      case '/client/overview':
        return 'Overview';
      case '/client/setup':
        return 'Setup';
      case '/client/campaign':
      case '/client/campaign/targeting':
        return 'Campaign';
      case '/client/leads':
        return 'Leads';
      case '/client/outreach':
        return 'Outreach';
      case '/client/replies':
        return 'Replies';
      case '/client/meetings':
        return 'Meetings';
      case '/client/invoices':
      case '/client/receipts':
      case '/client/agreements':
      case '/client/statements':
      case '/client/reminders':
        return 'Records';
      case '/client/notifications':
        return 'Notifications';
      case '/client/support':
        return 'Support';
      case '/client/settings':
        return 'Settings';
      case '/app/contacts':
        return 'Contacts';
      case '/app/campaigns':
        return 'Campaigns';
      case '/app/activity':
        return 'Activity';
      case '/app/mailbox':
        return 'Mailbox';
      case '/app/newsletter':
        return 'Newsletter';
      case '/app/branding':
        return 'Branding';
      case '/app/billing':
        return 'Billing';
      case '/app/account':
        return 'Account';
      default:
        return 'Home';
    }
  }

  String _topStateLine(AuthSessionController session) {
    if (!session.emailVerified) {
      return 'Confirm your email to open your workspace.';
    }
    if (!session.hasSetupCompleted) {
      return 'Finish setup so your target market and service preferences are ready.';
    }
    if (session.normalizedSubscriptionStatus != 'active') {
      return 'Complete billing to keep service records and campaign activation moving.';
    }

    switch (widget.currentPath) {
      case '/client/overview':
        return 'Setup, campaign movement, outreach, replies, meetings, billing, and support stay readable in one workspace.';
      case '/client/setup':
        return 'Setup captures your business profile, target customers, market, offer, and authorization.';
      case '/client/campaign':
      case '/client/campaign/targeting':
        return 'Campaign shows target market, authorization, status, and the next safe action.';
      case '/client/leads':
        return 'Leads show whether records are sourced, ready, contacted, or still waiting.';
      case '/client/outreach':
        return 'Outreach shows queued, sent, follow-up, and reply movement when records are available.';
      case '/client/replies':
        return 'Replies show real inbound outcomes from your outreach.';
      case '/client/meetings':
        return 'Meetings stay tied to replies and handoff progress.';
      case '/client/billing':
      case '/client/invoices':
      case '/client/receipts':
      case '/client/agreements':
      case '/client/statements':
      case '/client/reminders':
        return 'Billing, documents, and service records stay easy to review.';
      case '/client/notifications':
        return 'Notifications show account notices available for your workspace.';
      case '/client/support':
        return 'Support uses your account context for setup, billing, and service questions.';
      case '/client/settings':
        return 'Settings shows account details, setup status, and authorization.';
      case '/app/contacts':
        return 'Contacts show sourced records and readiness.';
      case '/app/campaigns':
        return 'Campaigns is the place for target market, geography, and activation.';
      case '/app/activity':
        return 'Activity shows replies, meetings, and outreach movement.';
      case '/app/mailbox':
        return 'Mailbox shows sent outreach and reply movement.';
      case '/app/newsletter':
        return 'Update controls will appear here when available for your account.';
      case '/app/branding':
        return 'Brand controls will appear here when available for your account.';
      case '/app/billing':
        return 'Billing stays clear so service standing is easy to review.';
      case '/app/account':
        return 'Profile, password, billing links, and account controls stay here.';
      default:
        return 'Home shows what is happening now, what is ready, what needs action, and what happens next.';
    }
  }

  bool _isSelected(String path) {
    if (widget.currentPath == path) return true;
    if (path == '/client/campaign' &&
        widget.currentPath.startsWith('/client/campaign')) {
      return true;
    }
    if (path == '/client/billing' &&
        const {
          '/client/invoices',
          '/client/receipts',
          '/client/statements',
          '/client/reminders',
        }.contains(widget.currentPath)) {
      return true;
    }
    if (path == '/client/agreements' &&
        const {
          '/client/agreements',
          '/client/statements',
          '/client/reminders',
        }.contains(widget.currentPath)) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    final name = session.workspaceName.trim().isNotEmpty
        ? session.workspaceName.trim()
        : 'Client workspace';
    final email = session.email.trim();

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: Row(
          children: [
            Container(
              width: _sidebarWidth,
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => context.go('/app/home'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BrandAssets.logo(context, height: 30),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                email,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _primaryItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = _primaryItems[index];
                            return _NavButton(
                              item: item,
                              selected: _isSelected(item.path),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () async {
                          await AuthSessionController.instance.clear();
                          if (context.mounted) context.go('/auth/login');
                        },
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.publicBackground,
                      border: Border(
                        bottom: BorderSide(color: AppTheme.publicLine),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      left: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxContentWidth,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 980;
                                final titleBlock = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _topTitle(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.publicText,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _topStateLine(session),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                );
                                final utility = Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _Pill(
                                      label: 'State',
                                      value: session.hasSetupCompleted
                                          ? 'Setup complete'
                                          : 'Setup incomplete',
                                    ),
                                    _Pill(
                                      label: 'Plan',
                                      value: _subscriptionLabel(session),
                                    ),
                                    _Pill(
                                      label: 'Billing',
                                      value: _billingLabel(session),
                                    ),
                                  ],
                                );
                                if (compact) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      titleBlock,
                                      const SizedBox(height: 14),
                                      utility,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: titleBlock),
                                    const SizedBox(width: 20),
                                    utility,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _maxContentWidth,
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected});

  final _ClientNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.publicAccentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => context.go(item.path),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 19,
                color: selected ? AppTheme.publicAccent : AppTheme.publicMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: selected
                            ? AppTheme.publicAccent
                            : AppTheme.publicText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ClientNavItem {
  const _ClientNavItem({
    required this.label,
    required this.path,
    required this.icon,
  });

  final String label;
  final String path;
  final IconData icon;
}
