import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/brand/brand_assets.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client/client_billing_repository.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  static const double sidebarWidth = 284;
  static const double maxContentWidth = 1320;

  static const List<_ClientNavItem> primaryItems = [
    _ClientNavItem(label: 'Workspace', path: '/client/workspace'),
    _ClientNavItem(label: 'Outreach', path: '/client/outreach'),
    _ClientNavItem(label: 'Meetings', path: '/client/meetings'),
    _ClientNavItem(label: 'Billing', path: '/client/billing'),
    _ClientNavItem(label: 'Account', path: '/client/account'),
  ];

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  final ClientBillingRepository _billingRepository = ClientBillingRepository();
  Future<Map<String, dynamic>?>? _subscriptionFuture;

  @override
  void initState() {
    super.initState();
    _subscriptionFuture = _loadSubscription();
  }

  @override
  void didUpdateWidget(covariant ClientShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _subscriptionFuture = _loadSubscription();
    }
  }

  Future<Map<String, dynamic>?> _loadSubscription() async {
    try {
      return await _billingRepository.fetchSubscription();
    } catch (_) {
      return null;
    }
  }

  String _topTitle() {
    for (final item in ClientShell.primaryItems) {
      if (item.path == widget.currentPath) return item.label;
    }
    if (widget.currentPath == '/client/help') return 'Support';
    return 'Client workspace';
  }

  String _billingStatus(AuthSessionController session) {
    final normalized = session.normalizedSubscriptionStatus;
    if (normalized == 'active') return 'Active';
    if (normalized == 'trialing') return 'In start period';
    if (normalized == 'past_due' || normalized == 'unpaid') {
      return 'Attention needed';
    }
    if (normalized == 'canceled' || normalized == 'cancelled') {
      return 'Inactive';
    }
    return 'Not active';
  }

  String _accountState(AuthSessionController session) {
    if (!session.emailVerified) return 'Verification pending';
    if (!session.hasSetupCompleted) return 'Draft';
    if (session.normalizedSubscriptionStatus == 'active') return 'Active';
    return 'Review';
  }

  String _workspaceName(AuthSessionController session) {
    final candidates = <String>[
      session.workspaceName.trim(),
      session.fullName.trim(),
    ];

    for (final value in candidates) {
      if (value.isEmpty) continue;
      final lower = value.toLowerCase();
      if (lower.contains('aura platform')) continue;
      if (lower == 'aura') continue;
      if (lower == 'orchestrate') continue;
      return value;
    }

    return 'Client workspace';
  }

  String _workspaceEmail(AuthSessionController session) {
    final email = session.email.trim();
    if (email.toLowerCase() == 'support@auraplatform.org') return '';
    return email;
  }

  String _topStateLine(AuthSessionController session) {
    if (!session.emailVerified) {
      return 'Verify the account so workspace access stays fully clear.';
    }
    if (!session.hasSetupCompleted) {
      return 'Finish setup so scope and account control are properly in place.';
    }
    if (session.normalizedSubscriptionStatus != 'active') {
      return 'Account control stays open while billing awaits activation.';
    }
    if (widget.currentPath == '/client/help') {
      return 'Support stays available without leaving the client workspace.';
    }
    return 'Workspace, outcomes, billing, and account control are all in view.';
  }

  String _planLabel(AuthSessionController session, Map<String, dynamic>? subscription) {
    final subscriptionLabel = _displayPlanLabel(subscription);
    if (subscriptionLabel.isNotEmpty) return subscriptionLabel;

    final lane = _title(session.selectedPlan ?? '');
    final tier = _title(session.selectedTier ?? '');
    if (lane.isNotEmpty && tier.isNotEmpty) return '$lane · $tier';
    if (tier.isNotEmpty) return tier;
    if (lane.isNotEmpty) return lane;
    return 'Not set';
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    final workspaceName = _workspaceName(session);
    final workspaceEmail = _workspaceEmail(session);

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _subscriptionFuture,
          builder: (context, snapshot) {
            final subscription = snapshot.data;

            return Row(
              children: [
                Container(
                  width: ClientShell.sidebarWidth,
                  color: Colors.white,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 18, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClientBrand(
                            currentPath: widget.currentPath,
                            workspaceName: workspaceName,
                            email: workspaceEmail,
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: ListView.separated(
                              itemCount: ClientShell.primaryItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final item = ClientShell.primaryItems[index];
                                return _ClientShellButton(
                                  item: item,
                                  selected: widget.currentPath == item.path,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          _UtilityButton(
                            label: 'Support',
                            selected: widget.currentPath == '/client/help',
                            onTap: () => context.go('/client/help'),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () async {
                                await AuthSessionController.instance.clear();
                                if (context.mounted) context.go('/client/login');
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.publicMuted,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                alignment: Alignment.centerLeft,
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              child: const Text('Sign out'),
                            ),
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
                        width: double.infinity,
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
                                  maxWidth: ClientShell.maxContentWidth,
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
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppTheme.publicMuted,
                                              ),
                                        ),
                                      ],
                                    );

                                    final utilityWrap = Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.end,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        _StatusPill(
                                          label: 'State',
                                          value: _accountState(session),
                                        ),
                                        _StatusPill(
                                          label: 'Plan',
                                          value: _planLabel(session, subscription),
                                        ),
                                        _StatusPill(
                                          label: 'Billing',
                                          value: _billingStatus(session),
                                        ),
                                        FilledButton.tonal(
                                          onPressed: () => context.go('/client/help'),
                                          style: FilledButton.styleFrom(
                                            foregroundColor: AppTheme.publicText,
                                            backgroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: const Text('Support'),
                                        ),
                                      ],
                                    );

                                    if (compact) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          titleBlock,
                                          const SizedBox(height: 16),
                                          utilityWrap,
                                        ],
                                      );
                                    }

                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: titleBlock),
                                        const SizedBox(width: 20),
                                        Flexible(child: utilityWrap),
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
                                maxWidth: ClientShell.maxContentWidth,
                              ),
                              child: SizedBox.expand(child: widget.child),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClientBrand extends StatelessWidget {
  const _ClientBrand({
    required this.currentPath,
    required this.workspaceName,
    required this.email,
  });

  final String currentPath;
  final String workspaceName;
  final String email;

  @override
  Widget build(BuildContext context) {
    final selected = currentPath == '/client/workspace';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/client/workspace'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.publicSurfaceSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.publicLine : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandAssets.logo(context, height: 30),
            const SizedBox(height: 16),
            Text(
              workspaceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.publicText,
                  ),
            ),
            if (email.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                email.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClientShellButton extends StatelessWidget {
  const _ClientShellButton({required this.item, required this.selected});

  final _ClientNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.publicSurfaceSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.publicLine : Colors.transparent,
            ),
          ),
          child: Text(
            item.label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppTheme.publicText : AppTheme.publicMuted,
                ),
          ),
        ),
      ),
    );
  }
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? AppTheme.publicText : AppTheme.publicMuted,
          side: BorderSide(color: selected ? AppTheme.publicLine : AppTheme.publicLine),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ClientNavItem {
  const _ClientNavItem({required this.label, required this.path});

  final String label;
  final String path;
}

String _title(String value) {
  if (value.trim().isEmpty) return '';
  return value
      .trim()
      .split(RegExp(r'[\s_\-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _displayPlanLabel(Map<String, dynamic>? subscription) {
  if (subscription == null || subscription.isEmpty) return '';

  final display = (subscription['displayPlanLabel'] as String?)?.trim() ?? '';
  if (display.isNotEmpty) return display;

  final service = _title(
    (subscription['service'] ?? subscription['lane'] ?? subscription['plan'])?.toString() ?? '',
  );
  final tier = _title(subscription['tier']?.toString() ?? '');

  if (service.isNotEmpty && tier.isNotEmpty) return '$service · $tier';
  if (service.isNotEmpty) return service;
  if (tier.isNotEmpty) return tier;
  return '';
}
