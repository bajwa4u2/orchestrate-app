
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

  bool _active(String route) => currentPath == route;

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
                          final compact = constraints.maxWidth < 980;

                          final brand = InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => context.go('/client/workspace'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: BrandAssets.logo(context, height: 30),
                            ),
                          );

                          final primaryNav = <Widget>[
                            _ClientNavItem(
                              label: 'Workspace',
                              active: _active('/client/workspace'),
                              onTap: () => context.go('/client/workspace'),
                            ),
                            _ClientNavItem(
                              label: 'Billing',
                              active: _active('/client/billing'),
                              onTap: () => context.go('/client/billing'),
                            ),
                            _ClientNavItem(
                              label: 'Agreements',
                              active: _active('/client/agreements'),
                              onTap: () => context.go('/client/agreements'),
                            ),
                            _ClientNavItem(
                              label: 'Statements',
                              active: _active('/client/statements'),
                              onTap: () => context.go('/client/statements'),
                            ),
                          ];

                          final accountLink = _ClientNavItem(
                            label: 'Account',
                            active: _active('/client/account'),
                            onTap: () => context.go('/client/account'),
                            emphasized: true,
                          );

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

                          final session = AuthSessionController.instance;
                          final identity = _WorkspaceIdentity(
                            name: session.workspaceName.isNotEmpty
                                ? session.workspaceName
                                : (session.fullName.isNotEmpty ? session.fullName : 'Client workspace'),
                            email: session.email,
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: brand),
                                    signOut,
                                  ],
                                ),
                                const SizedBox(height: 14),
                                identity,
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...primaryNav,
                                    accountLink,
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              brand,
                              const SizedBox(width: 18),
                              Expanded(child: identity),
                              const SizedBox(width: 18),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ...primaryNav,
                                  accountLink,
                                  const _ShellDivider(),
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

class _WorkspaceIdentity extends StatelessWidget {
  const _WorkspaceIdentity({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.publicText,
                fontWeight: FontWeight.w700,
              ),
        ),
        if (email.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ],
    );
  }
}

class _ShellDivider extends StatelessWidget {
  const _ShellDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: AppTheme.publicLine,
    );
  }
}

class _ClientNavItem extends StatelessWidget {
  const _ClientNavItem({
    required this.label,
    required this.active,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final bool active;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = active
        ? AppTheme.publicSurfaceSoft
        : emphasized
            ? Colors.white
            : Colors.transparent;

    final borderColor = active || emphasized ? AppTheme.publicLine : Colors.transparent;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? AppTheme.publicText : AppTheme.publicMuted,
        backgroundColor: background,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: active || emphasized ? FontWeight.w600 : FontWeight.w500,
            ),
      ),
      child: Text(label),
    );
  }
}
