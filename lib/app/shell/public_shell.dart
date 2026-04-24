import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

class PublicShell extends StatelessWidget {
  const PublicShell(
      {super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  static const double _maxFrameWidth = 1320;

  bool _shouldUsePublicChrome(String path) {
    return path == '/' ||
        path == '/product' ||
        path == '/how-it-works' ||
        path == '/ai-governed-revenue' ||
        path == '/lead-sourcing' ||
        path == '/trust-compliance' ||
        path == '/pricing' ||
        path == '/about' ||
        path == '/contact' ||
        path == '/intake' ||
        path == '/newsletter' ||
        path == '/newsletter/subscribe' ||
        path.startsWith('/auth/') ||
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
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _PublicHeader(currentPath: currentPath),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: _maxFrameWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
              const _PublicFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicHeader extends StatelessWidget {
  const _PublicHeader({required this.currentPath});

  final String currentPath;

  bool _isActive(List<String> paths) => paths.contains(currentPath);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicBackground,
        border: Border(bottom: BorderSide(color: AppTheme.publicLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 1080;

                final brand = InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  onTap: () => context.go('/'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: BrandAssets.logo(context, height: 26),
                  ),
                );

                final nav = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _HeaderLink(
                      label: 'Product',
                      active: _isActive(const ['/product', '/how-it-works']),
                      onTap: () => context.go('/how-it-works'),
                    ),
                    _HeaderLink(
                      label: 'Governance',
                      active: _isActive(const ['/ai-governed-revenue']),
                      onTap: () => context.go('/ai-governed-revenue'),
                    ),
                    _HeaderLink(
                      label: 'Sourcing',
                      active: _isActive(const ['/lead-sourcing']),
                      onTap: () => context.go('/lead-sourcing'),
                    ),
                    _HeaderLink(
                      label: 'Trust',
                      active: _isActive(const ['/trust-compliance']),
                      onTap: () => context.go('/trust-compliance'),
                    ),
                    _HeaderLink(
                      label: 'Pricing',
                      active: _isActive(const ['/pricing']),
                      onTap: () => context.go('/pricing'),
                    ),
                    _HeaderLink(
                      label: 'About',
                      active: _isActive(const ['/about']),
                      onTap: () => context.go('/about'),
                    ),
                    _HeaderLink(
                      label: 'Updates',
                      active: _isActive(
                          const ['/newsletter', '/newsletter/subscribe']),
                      onTap: () => context.go('/newsletter'),
                    ),
                    _HeaderLink(
                      label: 'Contact',
                      active: _isActive(const ['/contact', '/intake']),
                      onTap: () => context.go('/intake'),
                    ),
                  ],
                );

                final actions = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/auth/login'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.publicText,
                        side: const BorderSide(color: AppTheme.publicLine),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius)),
                      ),
                      child: const Text('Sign in'),
                    ),
                    FilledButton(
                      onPressed: () => context.go('/auth/join'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.publicText,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius)),
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
                      nav,
                      const SizedBox(height: 14),
                      actions,
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
    );
  }
}

class _PublicFooter extends StatelessWidget {
  const _PublicFooter();

  @override
  Widget build(BuildContext context) {
    final links = [
      _FooterLink(label: 'Terms', onTap: () => context.go('/legal/terms')),
      _FooterLink(label: 'Privacy', onTap: () => context.go('/legal/privacy')),
      _FooterLink(
          label: 'Service Agreement',
          onTap: () => context.go('/legal/service-agreement')),
      _FooterLink(label: 'Billing', onTap: () => context.go('/legal/billing')),
      _FooterLink(label: 'Refund', onTap: () => context.go('/legal/refunds')),
      _FooterLink(
          label: 'Acceptable Use',
          onTap: () => context.go('/legal/acceptable-use')),
      _FooterLink(
          label: 'Deliverability',
          onTap: () => context.go('/legal/deliverability')),
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicBackground,
        border: Border(top: BorderSide(color: AppTheme.publicLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 8,
              children: links,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink(
      {required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? AppTheme.publicText : AppTheme.publicMuted,
        backgroundColor:
            active ? AppTheme.publicSurfaceSoft : Colors.transparent,
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.publicMuted,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.publicMuted.withOpacity(0.3),
              ),
        ),
      ),
    );
  }
}
