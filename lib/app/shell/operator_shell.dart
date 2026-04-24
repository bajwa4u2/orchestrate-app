import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

class OperatorShell extends StatelessWidget {
  const OperatorShell(
      {super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  static const double _sidebarWidth = 292;
  static const double _maxContentWidth = 1320;

  static const groups = [
    _NavGroup('Overview', [
      _NavItem(
          'System health', '/operator/overview', Icons.monitor_heart_outlined),
      _NavItem(
          'Alerts and context', '/operator/system', Icons.dashboard_outlined),
      _NavItem('System Doctor', '/operator/system-doctor',
          Icons.health_and_safety_outlined),
    ]),
    _NavGroup('Operations', [
      _NavItem('Campaigns', '/operator/campaigns', Icons.campaign_outlined),
      _NavItem('Leads', '/operator/leads', Icons.people_alt_outlined),
      _NavItem('Jobs', '/operator/jobs', Icons.playlist_play_outlined),
      _NavItem('Queues', '/operator/queues', Icons.low_priority_outlined),
      _NavItem('Workers', '/operator/workers', Icons.engineering_outlined),
    ]),
    _NavGroup('Intelligence', [
      _NavItem('AI governance', '/operator/ai-governance',
          Icons.psychology_alt_outlined),
      _NavItem('Signals', '/operator/signals', Icons.insights_outlined),
      _NavItem(
          'Qualification', '/operator/qualification', Icons.verified_outlined),
      _NavItem('Reachability', '/operator/reachability',
          Icons.alternate_email_outlined),
    ]),
    _NavGroup('Infrastructure', [
      _NavItem('Providers', '/operator/providers', Icons.hub_outlined),
      _NavItem('Sources', '/operator/sources', Icons.travel_explore_outlined),
      _NavItem('Deliverability', '/operator/deliverability',
          Icons.health_and_safety_outlined),
      _NavItem('Email operations', '/operator/emails', Icons.mail_outline),
    ]),
    _NavGroup('Business', [
      _NavItem('Clients', '/operator/clients', Icons.business_outlined),
      _NavItem('Organizations', '/operator/organizations',
          Icons.account_tree_outlined),
      _NavItem('Finance', '/operator/billing', Icons.receipt_long_outlined),
      _NavItem('Documents', '/operator/documents', Icons.description_outlined),
      _NavItem('Support', '/operator/support', Icons.support_agent_outlined),
      _NavItem('Activity', '/operator/activity', Icons.history_outlined),
      _NavItem('Analytics', '/operator/analytics', Icons.query_stats_outlined),
      _NavItem('System checks', '/ops/debug', Icons.tune_outlined),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: Row(
          children: [
            Container(
              width: _sidebarWidth,
              color: AppTheme.sidebar,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OperatorBrand(currentPath: currentPath),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.panel,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: AppTheme.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppTheme.emerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Operating status live',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.separated(
                          itemCount: groups.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            return _NavGroupWidget(
                              group: group,
                              currentPath: currentPath,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: AppTheme.background,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: AppTheme.line)),
                      ),
                      child: SafeArea(
                        bottom: false,
                        left: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: _maxContentWidth),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _topbarTitle(currentPath),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: AppTheme.subdued,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const _TopPill(label: 'Operator'),
                                      const _TopPill(label: 'Live'),
                                      TextButton(
                                        onPressed: () async {
                                          await AuthSessionController.instance
                                              .clear();
                                          if (context.mounted) {
                                            context.go('/ops/login');
                                          }
                                        },
                                        child: const Text('Sign out'),
                                      ),
                                    ],
                                  ),
                                ],
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
                                maxWidth: _maxContentWidth),
                            child: SizedBox.expand(child: child),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _topbarTitle(String currentPath) {
    for (final group in groups) {
      for (final item in group.items) {
        if (_matchesPath(currentPath, item.path)) return item.label;
      }
    }
    return 'Operator';
  }
}

bool _matchesPath(String currentPath, String itemPath) {
  if (currentPath == itemPath) return true;
  if (itemPath == '/ops/inquiries' &&
      currentPath.startsWith('/ops/inquiries/')) {
    return true;
  }
  return false;
}

class _OperatorBrand extends StatelessWidget {
  const _OperatorBrand({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final selected = _matchesPath(currentPath, '/ops/overview');
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: () => context.go('/ops/overview'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.panel : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected ? AppTheme.line : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandAssets.operatorLockup(context),
            const SizedBox(height: 14),
            Text('Command center',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Control, recovery, and system visibility for live revenue operations.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _NavGroupWidget extends StatelessWidget {
  const _NavGroupWidget({required this.group, required this.currentPath});

  final _NavGroup group;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: Text(
            group.label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.subdued),
          ),
        ),
        for (final item in group.items) ...[
          _ShellNavButton(
              item: item, selected: _matchesPath(currentPath, item.path)),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _ShellNavButton extends StatelessWidget {
  const _ShellNavButton({required this.item, required this.selected});

  final _NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.panelRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
                color: selected ? AppTheme.lineSoft : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: selected ? AppTheme.text : AppTheme.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 15,
                        color: selected ? AppTheme.text : AppTheme.muted,
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

class _NavGroup {
  const _NavGroup(this.label, this.items);

  final String label;
  final List<_NavItem> items;
}

class _NavItem {
  const _NavItem(this.label, this.path, this.icon);

  final String label;
  final String path;
  final IconData icon;
}
