import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/brand/brand_assets.dart';
import '../core/theme/app_theme.dart';

class ClientShell extends StatelessWidget {
  const ClientShell({super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  static const double _maxFrameWidth = 1320;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: Column(
          children: [
            _ClientHeader(currentPath: currentPath),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxFrameWidth),
                    child: SizedBox.expand(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.publicBackground,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppTheme.publicLine),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicBackground,
        border: Border(bottom: BorderSide(color: AppTheme.publicLine)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ClientShell._maxFrameWidth),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1080;

                  final brand = InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.go('/client/workspace'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BrandAssets.logo(context, height: 28),
                          const SizedBox(height: 8),
                          Text(
                            session.workspaceName.isNotEmpty
                                ? session.workspaceName
                                : 'Client workspace',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.publicMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );

                  final nav = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ClientNavChip(
                        label: 'Overview',
                        active: currentPath == '/client/workspace',
                        onTap: () => context.go('/client/workspace'),
                      ),
                      _ClientNavChip(
                        label: 'Billing',
                        active: currentPath == '/client/billing',
                        onTap: () => context.go('/client/billing'),
                      ),
                      _ClientNavChip(
                        label: 'Agreements',
                        active: currentPath == '/client/agreements',
                        onTap: () => context.go('/client/agreements'),
                      ),
                      _ClientNavChip(
                        label: 'Statements',
                        active: currentPath == '/client/statements',
                        onTap: () => context.go('/client/statements'),
                      ),
                      _ClientNavChip(
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
                        onPressed: () => context.go('/'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.publicMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Public site'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          await AuthSessionController.instance.clear();
                          if (context.mounted) context.go('/client/login');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.publicText,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Sign out'),
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        brand,
                        const SizedBox(height: 12),
                        nav,
                        const SizedBox(height: 12),
                        actions,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(width: 260, child: brand),
                      const SizedBox(width: 24),
                      Expanded(child: nav),
                      const SizedBox(width: 20),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientNavChip extends StatelessWidget {
  const _ClientNavChip({required this.label, required this.active, required this.onTap});

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
