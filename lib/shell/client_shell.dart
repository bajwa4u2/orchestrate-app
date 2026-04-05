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
              decoration: const BoxDecoration(
                color: AppTheme.publicBackground,
                border: Border(bottom: BorderSide(color: AppTheme.publicLine)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1120;

                          final brandBlock = InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.go('/client/workspace'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BrandAssets.logo(context, height: 28),
                                  const SizedBox(width: 14),
                                  Text(
                                    'Client workspace',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.publicText,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          final nav = Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
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

                          final signOut = TextButton(
                            onPressed: () async {
                              await AuthSessionController.instance.clear();
                              if (context.mounted) context.go('/client/login');
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
                                brandBlock,
                                const SizedBox(height: 14),
                                nav,
                                const SizedBox(height: 8),
                                Align(alignment: Alignment.centerLeft, child: signOut),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: brandBlock)),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 7,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(child: Align(alignment: Alignment.centerRight, child: nav)),
                                    const SizedBox(width: 12),
                                    signOut,
                                  ],
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
