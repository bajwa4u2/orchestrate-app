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
                          final compact = constraints.maxWidth < 920;

                          final logo = InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.go('/client/workspace'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: BrandAssets.logo(context, height: 30),
                            ),
                          );

                          final navItems = <Widget>[
                            _NavLink(
                              label: 'Overview',
                              active: currentPath == '/client/workspace',
                              onTap: () => context.go('/client/workspace'),
                            ),
                            _NavLink(
                              label: 'Billing',
                              active: currentPath == '/client/billing',
                              onTap: () => context.go('/client/billing'),
                            ),
                            _NavLink(
                              label: 'Agreements',
                              active: currentPath == '/client/agreements',
                              onTap: () => context.go('/client/agreements'),
                            ),
                            _NavLink(
                              label: 'Statements',
                              active: currentPath == '/client/statements',
                              onTap: () => context.go('/client/statements'),
                            ),
                            _NavLink(
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                                  alignment: WrapAlignment.start,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  runSpacing: 6,
                                  children: [
                                    ...navItems,
                                    const SizedBox(width: 6),
                                    signOut,
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              logo,
                              const Spacer(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ..._withSpacing(navItems, 2),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 1,
                                    height: 22,
                                    color: AppTheme.publicLine,
                                  ),
                                  const SizedBox(width: 8),
                                  signOut,
                                ],
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

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? AppTheme.publicText : AppTheme.publicMuted,
        overlayColor: AppTheme.publicSurfaceSoft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
      ),
      child: Text(label),
    );
  }
}
