import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/brand/brand_assets.dart';
import '../core/theme/app_theme.dart';

class ClientShell extends StatelessWidget {
  const ClientShell({super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppTheme.publicBackground,
                border: Border(bottom: BorderSide(color: AppTheme.publicLine)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1120;

                          final logo = InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.go('/client/workspace'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: BrandAssets.logo(context, height: 30),
                            ),
                          );

                          final navItems = <Widget>[
                            _NavChip(
                              label: 'Overview',
                              active: currentPath == '/client/workspace',
                              onTap: () => context.go('/client/workspace'),
                            ),
                            _NavChip(
                              label: 'Billing',
                              active: currentPath == '/client/billing',
                              onTap: () => context.go('/client/billing'),
                            ),
                            _NavChip(
                              label: 'Agreements',
                              active: currentPath == '/client/agreements',
                              onTap: () => context.go('/client/agreements'),
                            ),
                            _NavChip(
                              label: 'Statements',
                              active: currentPath == '/client/statements',
                              onTap: () => context.go('/client/statements'),
                            ),
                            _NavChip(
                              label: 'Account',
                              active: currentPath == '/client/account',
                              onTap: () => context.go('/client/account'),
                            ),
                          ];

                          final signOut = TextButton(
                            onPressed: () async {
                              await AuthSessionController.instance.clear();
                              if (context.mounted) {
                                context.go('/client/login');
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.publicMuted,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            child: const Text('Sign out'),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                logo,
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [...navItems, signOut],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              logo,
                              const Spacer(),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ..._withSpacing(navItems, 6),
                                        const SizedBox(width: 12),
                                        signOut,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

List<Widget> _withSpacing(List<Widget> widgets, double spacing) {
  final items = <Widget>[];
  for (var i = 0; i < widgets.length; i++) {
    if (i > 0) {
      items.add(SizedBox(width: spacing));
    }
    items.add(widgets[i]);
  }
  return items;
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? AppTheme.publicText : AppTheme.publicMuted,
        backgroundColor: active ? AppTheme.publicSurfaceSoft : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
      ),
      child: Text(label),
    );
  }
}
