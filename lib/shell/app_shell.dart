import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
              width: 296,
              color: AppTheme.sidebar,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Orchestrate',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Opportunity, billing, and records carried in one system.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 20),
                      Container(
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
                              decoration: const BoxDecoration(color: AppTheme.emerald, shape: BoxShape.circle),
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
                      const SizedBox(height: 18),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.panel,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.line),
                            ),
                            child: Text('Operator', style: Theme.of(context).textTheme.titleMedium),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.panel,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.line),
                            ),
                            child: Text('Today', style: Theme.of(context).textTheme.titleMedium),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.go('/'),
                            child: const Text('Public site'),
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
