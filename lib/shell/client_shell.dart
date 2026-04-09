import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/brand/brand_assets.dart';
import '../core/theme/app_theme.dart';

class ClientShell extends StatelessWidget {
  const ClientShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  static const double _sidebarWidth = 284;
  static const double _maxContentWidth = 1320;

  static const List<_ClientNavGroup> _groups = [
    _ClientNavGroup(
      'Workspace',
      [
        _ClientNavItem(label: 'Home', path: '/client/workspace'),
      ],
    ),
    _ClientNavGroup(
      'Billing & Records',
      [
        _ClientNavItem(label: 'Billing', path: '/client/billing'),
        _ClientNavItem(label: 'Agreements', path: '/client/agreements'),
        _ClientNavItem(label: 'Statements', path: '/client/statements'),
      ],
    ),
    _ClientNavGroup(
      'Support',
      [
        _ClientNavItem(label: 'Help & Support', path: '/client/help'),
      ],
    ),
    _ClientNavGroup(
      'Account',
      [
        _ClientNavItem(label: 'Account', path: '/client/account'),
      ],
    ),
  ];

  bool _isSelected(_ClientNavItem item) => currentPath == item.path;

  bool _matchesBillingGroup() {
    return currentPath == '/client/billing' ||
        currentPath == '/client/agreements' ||
        currentPath == '/client/statements';
  }

  String _topTitle() {
    for (final group in _groups) {
      for (final item in group.items) {
        if (item.path == currentPath) return item.label;
      }
    }
    return 'Client workspace';
  }

  String _billingStatus(AuthSessionController session) {
    final normalized = session.normalizedSubscriptionStatus;
    if (normalized == 'active') return 'Billing active';
    if (normalized == 'trialing') return 'In start period';
    if (normalized == 'past_due' || normalized == 'unpaid') {
      return 'Billing needs attention';
    }
    if (normalized == 'canceled' || normalized == 'cancelled') {
      return 'Billing inactive';
    }
    return 'Billing not active';
  }

  String _scopeLabel(AuthSessionController session) {
    final parts = <String>[];
    final country = session.countryName.trim();
    final region = session.regionName.trim();

    if (country.isNotEmpty) parts.add(country);
    if (region.isNotEmpty) parts.add(region);

    if (parts.isEmpty) return session.hasSetupCompleted ? 'Scope set' : 'Scope incomplete';
    return parts.join(' • ');
  }

  String _supportLabel() {
    if (currentPath == '/client/help') return 'Support open';
    return 'Support available';
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    final workspaceName = session.workspaceName.trim().isNotEmpty
        ? session.workspaceName.trim()
        : (session.fullName.trim().isNotEmpty ? session.fullName.trim() : 'Client workspace');

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
                      _ClientBrand(
                        currentPath: currentPath,
                        workspaceName: workspaceName,
                        email: session.email,
                      ),
                      const SizedBox(height: 18),
                      _WorkspaceStateCard(
                        billingLabel: _billingStatus(session),
                        scopeLabel: _scopeLabel(session),
                        setupComplete: session.hasSetupCompleted,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _groups.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final group = _groups[index];
                            return _ClientNavGroupWidget(
                              group: group,
                              currentPath: currentPath,
                              billingGroupSelected: _matchesBillingGroup(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () async {
                            await AuthSessionController.instance.clear();
                            if (context.mounted) context.go('/client/login');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.publicMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            alignment: Alignment.centerLeft,
                            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
                                    Text(
                                      _topTitle(),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.publicText,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Plan, billing, scope, and support stay visible while you work.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppTheme.publicMuted,
                                          ),
                                    ),
                                  ],
                                );

                                final statusWrap = Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    _StatusPill(
                                      label: 'Plan',
                                      value: _title(session.selectedTier ?? 'Focused'),
                                    ),
                                    _StatusPill(
                                      label: 'Billing',
                                      value: _billingStatus(session),
                                    ),
                                    _StatusPill(
                                      label: 'Scope',
                                      value: _scopeLabel(session),
                                    ),
                                    _StatusPill(
                                      label: 'Support',
                                      value: _supportLabel(),
                                    ),
                                  ],
                                );

                                if (compact) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      titleBlock,
                                      const SizedBox(height: 16),
                                      statusWrap,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: titleBlock),
                                    const SizedBox(width: 20),
                                    Flexible(child: statusWrap),
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
                          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                          child: SizedBox.expand(child: child),
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

class _WorkspaceStateCard extends StatelessWidget {
  const _WorkspaceStateCard({
    required this.billingLabel,
    required this.scopeLabel,
    required this.setupComplete,
  });

  final String billingLabel;
  final String scopeLabel;
  final bool setupComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: setupComplete ? AppTheme.publicAccent : AppTheme.publicMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  setupComplete ? 'Workspace ready' : 'Setup still needs attention',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.publicText,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StateLine(label: 'Billing', value: billingLabel),
          const SizedBox(height: 8),
          _StateLine(label: 'Scope', value: scopeLabel),
        ],
      ),
    );
  }
}

class _StateLine extends StatelessWidget {
  const _StateLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicText,
                ),
          ),
        ),
      ],
    );
  }
}

class _ClientNavGroupWidget extends StatelessWidget {
  const _ClientNavGroupWidget({
    required this.group,
    required this.currentPath,
    required this.billingGroupSelected,
  });

  final _ClientNavGroup group;
  final String currentPath;
  final bool billingGroupSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: Text(
            group.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ),
        for (final item in group.items) ...[
          _ClientShellButton(
            item: item,
            selected: group.label == 'Billing & Records'
                ? (billingGroupSelected && currentPath == item.path)
                : currentPath == item.path,
          ),
          const SizedBox(height: 6),
        ],
      ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
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

class _ClientNavGroup {
  const _ClientNavGroup(this.label, this.items);

  final String label;
  final List<_ClientNavItem> items;
}

class _ClientNavItem {
  const _ClientNavItem({required this.label, required this.path});

  final String label;
  final String path;
}

String _title(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) return 'Not set';
  return normalized
      .split(RegExp(r'[-_]'))
      .where((part) => part.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
