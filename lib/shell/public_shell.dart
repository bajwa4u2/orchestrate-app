import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/brand/brand_assets.dart';
import '../core/theme/app_theme.dart';

class PublicShell extends StatelessWidget {
  const PublicShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  static const double _shellMaxWidth = 1280;

  bool _shouldUsePublicChrome(String path) {
    return path == '/' ||
        path == '/how-it-works' ||
        path == '/pricing' ||
        path == '/contact' ||
        path.startsWith('/legal/');
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldUsePublicChrome(currentPath)) {
      return Theme(
        data: AppTheme.lightTheme,
        child: child,
      );
    }

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: Column(
          children: [
            _PublicTopBar(currentPath: currentPath),
            Expanded(child: child),
            const _PublicFooter(),
          ],
        ),
      ),
    );
  }
}

class _PublicTopBar extends StatelessWidget {
  const _PublicTopBar({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PublicShell._shellMaxWidth),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1024;

                  final brand = _ShellBrand(onTap: () => context.go('/'));

                  final navLinks = Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
                    ],
                  );

                  final accessGroup = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => context.go('/client/login'),
                        style: TextButton.styleFrom(
                          foregroundColor: currentPath == '/client/login'
                              ? AppTheme.publicText
                              : AppTheme.publicMuted,
                          overlayColor: AppTheme.publicSurfaceSoft,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(0, 42),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: currentPath == '/client/login'
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                        ),
                        child: const Text('Sign in'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => context.go('/client/join'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.publicText,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          minimumSize: const Size(0, 46),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        child: const Text('Join'),
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
                              navLinks,
                              const SizedBox(width: 20),
                              accessGroup,
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
                      navLinks,
                      const SizedBox(width: 24),
                      accessGroup,
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

class _PublicFooter extends StatelessWidget {
  const _PublicFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.publicBackground,
        border: Border(
          top: BorderSide(color: AppTheme.publicLine),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PublicShell._shellMaxWidth),
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
                  _FooterLink(
                    label: 'Terms of Use',
                    onTap: () => context.go('/legal/terms'),
                  ),
                  _FooterLink(
                    label: 'Privacy Policy',
                    onTap: () => context.go('/legal/privacy'),
                  ),
                  _FooterLink(
                    label: 'Billing Policy',
                    onTap: () => context.go('/legal/billing'),
                  ),
                  _FooterLink(
                    label: 'Refund Policy',
                    onTap: () => context.go('/legal/refunds'),
                  ),
                  _FooterLink(
                    label: 'Acceptable Use',
                    onTap: () => context.go('/legal/acceptable-use'),
                  ),
                  _FooterLink(
                    label: 'Service Agreement',
                    onTap: () => context.go('/legal/service-agreement'),
                  ),
                  _FooterLink(
                    label: 'Deliverability Notice',
                    onTap: () => context.go('/legal/deliverability'),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    legalHeading,
                    const SizedBox(height: 14),
                    links,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 160, child: legalHeading),
                  Expanded(child: links),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShellBrand extends StatelessWidget {
  const _ShellBrand({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: BrandAssets.logo(context, height: 26),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.publicMuted,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      child: Text(label),
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
