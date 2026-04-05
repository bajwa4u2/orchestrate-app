import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
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
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => context.go('/client/workspace'),
                        child: Text('Orchestrate', style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      const SizedBox(width: 24),
                      Wrap(
                        spacing: 8,
                        children: [
                          _NavChip(label: 'Overview', active: currentPath == '/client/workspace', onTap: () => context.go('/client/workspace')),
                          _NavChip(label: 'Billing', active: currentPath == '/client/billing', onTap: () => context.go('/client/billing')),
                          _NavChip(label: 'Agreements', active: currentPath == '/client/agreements', onTap: () => context.go('/client/agreements')),
                          _NavChip(label: 'Statements', active: currentPath == '/client/statements', onTap: () => context.go('/client/statements')),
                          _NavChip(label: 'Account', active: currentPath == '/client/account', onTap: () => context.go('/client/account')),
                        ],
                      ),
                      const Spacer(),
                      if (session.workspaceName.isNotEmpty)
                        Text(session.workspaceName, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.publicMuted)),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          await AuthSessionController.instance.clear();
                          if (context.mounted) context.go('/client/login');
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
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
    return TextButton(onPressed: onTap, child: Text(label));
  }
}
