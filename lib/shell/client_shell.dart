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
    final session = AuthSessionController.instance;
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.publicBackground,
                border: Border(bottom: BorderSide(color: AppTheme.publicLine)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1080;

                          final brandBlock = InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => context.go('/client/workspace'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BrandAssets.logo(context, height: 26),
                                  if (session.workspaceName.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      session.workspaceName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: AppTheme.publicMuted,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );

                          final nav = Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
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
                            ],
                          );

                          final actions = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await AuthSessionController.instance.clear();
                                  if (context.mounted) context.go('/client/login');
                                },
                                child: const Text('Sign out'),
                              ),
                            ],
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                brandBlock,
                                const SizedBox(height: 14),
                                nav,
                                const SizedBox(height: 10),
                                actions,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 3, child: brandBlock),
                              Expanded(flex: 5, child: Align(alignment: Alignment.centerLeft, child: nav)),
                              actions,
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
