import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/brand/brand_assets.dart';
import '../core/theme/app_theme.dart';

class ClientShell extends StatelessWidget {
  const ClientShell({super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  static const double _shellMaxWidth = 1280;

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: Column(
          children: [
            _ClientTopBar(currentPath: currentPath, session: session),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _shellMaxWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                    child: child,
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

class _ClientTopBar extends StatelessWidget {
  const _ClientTopBar({
    required this.currentPath,
    required this.session,
  });

  final String currentPath;
  final AuthSessionController session;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              constraints: const BoxConstraints(maxWidth: ClientShell._shellMaxWidth),
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
                    spacing: 6,
                    runSpacing: 6,
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
                        onPressed: () => context.go('/'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.publicMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          minimumSize: const Size(0, 42),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                          foregroundColor: AppTheme.publicMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          minimumSize: const Size(0, 42),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              nav,
                              const SizedBox(width: 20),
                              actions,
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      brand,
                      const Spacer(),
                      nav,
                      const SizedBox(width: 24),
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
        minimumSize: const Size(0, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
      ),
      child: Text(label),
    );
  }
}
