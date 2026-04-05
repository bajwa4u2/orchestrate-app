import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/brand/brand_assets.dart';
import '../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  static const groups = [
    _NavGroup('Command', [_NavItem('Command', '/app/command')]),
    _NavGroup('Pipeline', [_NavItem('Leads', '/app/pipeline')]),
    _NavGroup('Execution', [
      _NavItem('Campaigns', '/app/execution/campaigns'),
      _NavItem('Replies', '/app/execution/replies'),
      _NavItem('Meetings', '/app/execution/meetings'),
    ]),
    _NavGroup('Clients', [_NavItem('Clients', '/app/clients')]),
    _NavGroup('Revenue', [_NavItem('Revenue', '/app/revenue')]),
    _NavGroup('Deliverability', [_NavItem('Deliverability', '/app/deliverability')]),
    _NavGroup('Communications', [_NavItem('Communications', '/app/communications')]),
    _NavGroup('Records', [_NavItem('Records', '/app/records')]),
    _NavGroup('Settings', [_NavItem('Settings', '/app/settings')]),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: Row(
          children: [
            Container(
              width: 300,
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.panel,
                          borderRadius: BorderRadius.circular(18),
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
                                'Operator workspace live',
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
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            return _NavGroupWidget(group: group, currentPath: currentPath);
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
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.line)),
                      ),
                      child: Row(
                        children: [
                          _TopPill(label: 'Operator'),
                          const SizedBox(width: 10),
                          _TopPill(label: 'Today'),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.go('/'),
                            child: const Text('Public site'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await AuthSessionController.instance.clear();
                              if (context.mounted) context.go('/ops/login');
                            },
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
                        child: child,
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
}

class _OperatorBrand extends StatelessWidget {
  const _OperatorBrand({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go('/app/command'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
        decoration: BoxDecoration(
          color: currentPath == '/app/command' ? AppTheme.panel : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: currentPath == '/app/command' ? AppTheme.line : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandAssets.logo(context, height: 28),
            const SizedBox(height: 12),
            Text(
              'Operations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Opportunity, billing, and records carried in one system.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
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
        borderRadius: BorderRadius.circular(16),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.subdued),
          ),
        ),
        for (final item in group.items) ...[
          _ShellNavButton(item: item, selected: currentPath == item.path),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.panelRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppTheme.lineSoft : Colors.transparent),
          ),
          child: Text(
            item.label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 15,
                  color: selected ? AppTheme.text : AppTheme.muted,
                ),
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
  const _NavItem(this.label, this.path);
  final String label;
  final String path;
}
