import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

class PublicShell extends StatelessWidget {
  const PublicShell({super.key, required this.currentPath, required this.child});

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
                border: Border(
                  bottom: BorderSide(color: AppTheme.publicLine),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1120;

                          final brand = InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => context.go('/'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppTheme.publicAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Orchestrate',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontSize: 28,
                                          height: 1.0,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          final navLinks = Wrap(
                            spacing: 0,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _TopLink(
                                label: 'How it works',
                                onTap: () => context.go('/how-it-works'),
                                active: currentPath == '/how-it-works',
                              ),
                              _TopLink(
                                label: 'Pricing',
                                onTap: () => context.go('/pricing'),
                                active: currentPath == '/pricing',
                              ),
                              _TopLink(
                                label: 'Contact',
                                onTap: () => context.go('/contact'),
                                active: currentPath == '/contact',
                              ),
                              _TopLink(
                                label: 'Sign in',
                                onTap: () => context.go('/client/login'),
                                active: currentPath == '/client/login',
                              ),
                            ],
                          );

                          final cta = FilledButton(
                            onPressed: () => context.go('/client/create-account'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.publicText,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              minimumSize: const Size(0, 48),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            child: const Text('Create account'),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                brand,
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(child: navLinks),
                                    const SizedBox(width: 14),
                                    cta,
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(flex: 0, child: brand),
                              const Spacer(),
                              Flexible(child: navLinks),
                              const SizedBox(width: 16),
                              cta,
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
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.publicBackground,
                border: Border(top: BorderSide(color: AppTheme.publicLine)),
              ),
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 920;
                      final legalHeading = Text(
                        'Legal',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.publicText,
                            ),
                      );

                      final links = Wrap(
                        spacing: 18,
                        runSpacing: 10,
                        children: [
                          _FooterLink(label: 'Terms of Use', onTap: () => context.go('/legal/terms')),
                          _FooterLink(label: 'Privacy Policy', onTap: () => context.go('/legal/privacy')),
                          _FooterLink(label: 'Billing Policy', onTap: () => context.go('/legal/billing')),
                          _FooterLink(label: 'Refund Policy', onTap: () => context.go('/legal/refunds')),
                          _FooterLink(label: 'Acceptable Use', onTap: () => context.go('/legal/acceptable-use')),
                          _FooterLink(label: 'Service Agreement', onTap: () => context.go('/legal/service-agreement')),
                          _FooterLink(label: 'Deliverability Notice', onTap: () => context.go('/legal/deliverability')),
                        ],
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [legalHeading, const SizedBox(height: 14), links],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 120, child: legalHeading),
                          const SizedBox(width: 20),
                          Expanded(child: links),
                        ],
                      );
                    },
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

class _TopLink extends StatelessWidget {
  const _TopLink({required this.label, required this.onTap, required this.active});

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? AppTheme.publicText : AppTheme.publicMuted,
        overlayColor: AppTheme.publicSurfaceSoft,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 40),
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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.publicMuted,
            ),
      ),
    );
  }
}
