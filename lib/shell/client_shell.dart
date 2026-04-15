import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/brand/brand_assets.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client/client_billing_repository.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key, required this.currentPath, required this.child});

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
    _ClientNavItem(label: 'Workspace', path: '/client/workspace'),
    _ClientNavItem(label: 'Campaigns', path: '/client/campaigns'),
    _ClientNavItem(label: 'Leads', path: '/client/leads'),
    _ClientNavItem(label: 'Meetings', path: '/client/meetings'),
    _ClientNavItem(label: 'Billing', path: '/client/billing'),
    _ClientNavItem(label: 'Account', path: '/client/account'),
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
    final service = (_subscription?['serviceName'] ?? _subscription?['service'] ?? session.selectedPlan ?? 'Not set').toString().trim();
    final tier = (_subscription?['tierName'] ?? _subscription?['tier'] ?? session.selectedTier ?? '').toString().trim();
    return [service, tier].where((e) => e.isNotEmpty).join(' · ');
  }

  String _billingLabel(AuthSessionController session) {
    return (_subscription?['status'] ?? session.subscriptionStatus).toString().trim().isEmpty
        ? 'Unknown'
        : (_subscription?['status'] ?? session.subscriptionStatus).toString().trim();
  }

  String _topTitle() {
    switch (widget.currentPath) {
      case '/client/campaigns':
        return 'Campaign targeting';
      case '/client/leads':
        return 'Lead generation';
      case '/client/meetings':
        return 'Meetings';
      case '/client/billing':
        return 'Billing';
      case '/client/account':
        return 'Account';
      case '/client/help':
        return 'Help';
      default:
        return 'Workspace';
    }
  }

  String _topStateLine(AuthSessionController session) {
    if (!session.emailVerified) return 'Verify the account so client access stays clear.';
    if (!session.hasSetupCompleted) return 'Finish setup so targeting and delivery stay grounded in the right scope.';
    if (session.normalizedSubscriptionStatus != 'active') {
      return 'Campaign control stays visible while activation and billing are still being completed.';
    }
    if (widget.currentPath == '/client/campaigns') {
      return 'This is the one place for targeting, geography, and activation control.';
    }
    if (widget.currentPath == '/client/leads') {
      return 'This view keeps sourcing, sendability, and communication movement together.';
    }
    if (widget.currentPath == '/client/meetings') {
      return 'Handoff, booking, and outcomes stay separate so meeting truth is visible.';
    }
    return 'Campaigns, leads, meetings, billing, and account control stay in view from here.';
  }

  bool _isSelected(String path) {
    return widget.currentPath == path;
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    final name = session.workspaceName.trim().isNotEmpty ? session.workspaceName.trim() : 'Client workspace';
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
                        onTap: () => context.go('/client/workspace'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BrandAssets.logo(context, height: 30),
                            const SizedBox(height: 16),
                            Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(email, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _primaryItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = _primaryItems[index];
                            final selected = _isSelected(item.path);
                            return _NavButton(item: item, selected: selected);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SecondaryButton(
                        label: 'Help',
                        selected: _isSelected('/client/help'),
                        onTap: () => context.go('/client/help'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () async {
                          await AuthSessionController.instance.clear();
                          if (context.mounted) context.go('/client/login');
                        },
                        style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
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
                      border: Border(bottom: BorderSide(color: AppTheme.publicLine)),
                    ),
                    child: SafeArea(
                      bottom: false,
                      left: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 980;
                                final titleBlock = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_topTitle(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.publicText)),
                                    const SizedBox(height: 6),
                                    Text(_topStateLine(session), style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                );
                                final utility = Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _Pill(label: 'State', value: session.hasSetupCompleted ? 'Ready for activation' : 'Setup incomplete'),
                                    _Pill(label: 'Plan', value: _subscriptionLabel(session)),
                                    _Pill(label: 'Billing', value: _billingLabel(session)),
                                  ],
                                );
                                if (compact) {
                                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 14), utility]);
                                }
                                return Row(children: [Expanded(child: titleBlock), const SizedBox(width: 20), utility]);
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
                          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go(item.path),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(item.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: selected ? AppTheme.publicAccent : AppTheme.publicText, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.publicAccentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: selected ? AppTheme.publicAccent : AppTheme.publicText, fontWeight: FontWeight.w700)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.publicLine)),
      child: Text('$label: $value', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _ClientNavItem {
  const _ClientNavItem({required this.label, required this.path});
  final String label;
  final String path;
}
