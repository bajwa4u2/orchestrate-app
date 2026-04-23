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
    _ClientNavItem(label: 'Home', path: '/app/home'),
    _ClientNavItem(label: 'Contacts', path: '/app/contacts'),
    _ClientNavItem(label: 'Campaigns', path: '/app/campaigns'),
    _ClientNavItem(label: 'Activity', path: '/app/activity'),
    _ClientNavItem(label: 'Mailbox', path: '/app/mailbox'),
    _ClientNavItem(label: 'Newsletter', path: '/app/newsletter'),
    _ClientNavItem(label: 'Branding', path: '/app/branding'),
    _ClientNavItem(label: 'Billing', path: '/app/billing'),
    _ClientNavItem(label: 'Account', path: '/app/account'),
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
      return 'Verify the account so client access stays clear.';
    }
    if (!session.hasSetupCompleted) {
      return 'Finish setup so targeting and delivery stay grounded in the right scope.';
    }
    if (session.normalizedSubscriptionStatus != 'active') {
      return 'Activation and billing are still being completed, but the client system remains visible.';
    }

    switch (widget.currentPath) {
      case '/app/contacts':
        return 'Contacts is the client memory surface for sourced records and readiness.';
      case '/app/campaigns':
        return 'Campaigns remains the one place for targeting, geography, and activation control.';
      case '/app/activity':
        return 'Activity holds execution truth across replies, meetings, and movement.';
      case '/app/mailbox':
        return 'Mailbox shows dispatch and reply movement without mixing it into targeting.';
      case '/app/newsletter':
        return 'Newsletter is reserved here so future communication stays in the client system.';
      case '/app/branding':
        return 'Branding remains a first-class family for identity, templates, and signatures.';
      case '/app/billing':
        return 'Billing stays separate from execution so service standing remains clear.';
      case '/app/account':
        return 'Profile, password, and client-level controls stay under account.';
      default:
        return 'Home keeps the client system readable without blending campaigns, activity, or billing.';
    }
  }

  bool _isSelected(String path) => widget.currentPath == path;

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
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                                      style: Theme.of(context).textTheme.bodyMedium,
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go(item.path),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(
            item.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? AppTheme.publicAccent : AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                ),
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
        borderRadius: BorderRadius.circular(16),
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
  const _ClientNavItem({required this.label, required this.path});

  final String label;
  final String path;
}
