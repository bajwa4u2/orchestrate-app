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

  static const double _maxFrameWidth = 1320;

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
      return Theme(data: AppTheme.lightTheme, child: child);
    }

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: Column(
          children: [
            _PublicHeader(currentPath: currentPath),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxFrameWidth),
                  child: SizedBox.expand(child: child),
                ),
              ),
            ),
            _PublicFooter(),
          ],
        ),
      ),
    );
  }
}

class _PublicHeader extends StatelessWidget {
  const _PublicHeader({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
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
              constraints: const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1024;

                  final brand = InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.go('/'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: BrandAssets.logo(context, height: 28),
                    ),
                  );

                  final nav = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _HeaderLink(
                        label: 'How it works',
                        active: currentPath == '/how-it-works',
                        onTap: () => context.go('/how-it-works'),
                      ),
                      _HeaderLink(
                        label: 'Pricing',
                        active: currentPath == '/pricing',
                        onTap: () => context.go('/pricing'),
                      ),
                      _HeaderLink(
                        label: 'Contact',
                        active: currentPath == '/contact',
                        onTap: () => context.go('/contact'),
                      ),
                    ],
                  );

                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => context.go('/client/login'),
                        style: TextButton.styleFrom(
                          foregroundColor: currentPath == '/client/login'
                              ? AppTheme.publicText
                              : AppTheme.publicMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Sign in'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => context.go('/client/join'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.publicText,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
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
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
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

class _PublicFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicBackground,
        border: Border(top: BorderSide(color: AppTheme.publicLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 920;

                final label = Text(
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
                    _FooterLink(label: 'Deliverability Notice', onTap: () => context.go('/legal/deliverability-notice')),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, const SizedBox(height: 14), links],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 140, child: label),
                    Expanded(child: links),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({
    required this.label,
    required this.active,
    required this.onTap,
  });

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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.publicMuted,
              ),
        ),
      ),
    );
  }
}
