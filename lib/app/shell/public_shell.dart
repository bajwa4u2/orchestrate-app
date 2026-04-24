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
  static const double _footerReserveHeight = 168;

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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: (constraints.maxHeight -
                                        _footerReserveHeight)
                                    .clamp(0, double.infinity)
                                    .toDouble(),
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: _maxFrameWidth,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                    ),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                            const _PublicFooter(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
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
                final desktop = constraints.maxWidth >= 1120;
                final tablet = constraints.maxWidth >= 720;

                final brand = InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  onTap: () => context.go('/'),
                  child: SizedBox(
                    height: 38,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BrandAssets.logo(context, height: 24),
                    ),
                  ),
                );

                final nav = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderLink(
                      label: 'Product',
                      active: _isActive(const ['/product']),
                      onTap: () => context.go('/product'),
                    ),
                    _HeaderLink(
                      label: 'How it works',
                      active: _isActive(const ['/how-it-works']),
                      onTap: () => context.go('/how-it-works'),
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
                      label: 'Contact',
                      active: _isActive(const ['/contact', '/intake']),
                      onTap: () => context.go('/intake'),
                    ),
                  ],
                );

                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/auth/login'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.publicText,
                        side: const BorderSide(color: AppTheme.publicLine),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius)),
                      ),
                      child: const Text('Sign in'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => context.go('/auth/join'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.publicText,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius)),
                      ),
                      child: const Text('Start setup'),
                    ),
                  ],
                );

                if (desktop) {
                  return SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        SizedBox(width: 190, child: brand),
                        Expanded(child: Center(child: nav)),
                        SizedBox(
                          width: 246,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: actions,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(child: brand),
                      if (tablet) ...[
                        OutlinedButton(
                          onPressed: () => context.go('/auth/login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.publicText,
                            side: const BorderSide(
                              color: AppTheme.publicLine,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius),
                            ),
                          ),
                          child: const Text('Sign in'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () => context.go('/auth/join'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.publicText,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius),
                            ),
                          ),
                          child: const Text('Start setup'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _PublicMenuButton(currentPath: currentPath),
                    ],
                  ),
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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicBackground,
        border: Border(top: BorderSide(color: AppTheme.publicLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final groups = [
                  _FooterGroup(
                    title: 'Product',
                    links: [
                      _FooterLink(
                          label: 'Product',
                          onTap: () => context.go('/product')),
                      _FooterLink(
                          label: 'How it works',
                          onTap: () => context.go('/how-it-works')),
                      _FooterLink(
                          label: 'Sourcing',
                          onTap: () => context.go('/lead-sourcing')),
                      _FooterLink(
                          label: 'Trust',
                          onTap: () => context.go('/trust-compliance')),
                    ],
                  ),
                  _FooterGroup(
                    title: 'Start',
                    links: [
                      _FooterLink(
                          label: 'Pricing',
                          onTap: () => context.go('/pricing')),
                      _FooterLink(
                          label: 'Start setup',
                          onTap: () => context.go('/auth/join')),
                      _FooterLink(
                          label: 'Contact',
                          onTap: () => context.go('/contact')),
                    ],
                  ),
                  _FooterGroup(
                    title: 'Legal',
                    links: [
                      _FooterLink(
                          label: 'Terms',
                          onTap: () => context.go('/legal/terms')),
                      _FooterLink(
                          label: 'Privacy',
                          onTap: () => context.go('/legal/privacy')),
                      _FooterLink(
                          label: 'Service Agreement',
                          onTap: () => context.go('/legal/service-agreement')),
                      _FooterLink(
                          label: 'Billing',
                          onTap: () => context.go('/legal/billing')),
                      _FooterLink(
                          label: 'Refunds',
                          onTap: () => context.go('/legal/refunds')),
                    ],
                  ),
                  _FooterGroup(
                    title: 'Trust',
                    links: [
                      _FooterLink(
                          label: 'Acceptable Use',
                          onTap: () => context.go('/legal/acceptable-use')),
                      _FooterLink(
                          label: 'Deliverability',
                          onTap: () => context.go('/legal/deliverability')),
                    ],
                  ),
                ];
                final compact = constraints.maxWidth < 720;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: compact
                          ? WrapAlignment.start
                          : WrapAlignment.spaceBetween,
                      spacing: compact ? 22 : 32,
                      runSpacing: 14,
                      children: groups,
                    ),
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

class _FooterGroup extends StatelessWidget {
  const _FooterGroup({required this.title, required this.links});

  final String title;
  final List<Widget> links;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            direction: Axis.vertical,
            spacing: 2,
            children: links,
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        minimumSize: const Size(0, 38),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius)),
        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.publicMuted,
                fontSize: 13,
                height: 1.25,
              ),
        ),
      ),
    );
  }
}

class _PublicMenuButton extends StatelessWidget {
  const _PublicMenuButton({required this.currentPath});

  final String currentPath;

  bool _isActive(List<String> paths) => paths.contains(currentPath);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Open navigation',
      position: PopupMenuPosition.under,
      color: AppTheme.publicSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: const BorderSide(color: AppTheme.publicLine),
      ),
      onSelected: (value) => context.go(value),
      itemBuilder: (context) => [
        _menuItem('Product', '/product', _isActive(const ['/product'])),
        _menuItem(
          'How it works',
          '/how-it-works',
          _isActive(const ['/how-it-works']),
        ),
        _menuItem(
          'Sourcing',
          '/lead-sourcing',
          _isActive(const ['/lead-sourcing']),
        ),
        _menuItem(
          'Trust',
          '/trust-compliance',
          _isActive(const ['/trust-compliance']),
        ),
        _menuItem('Pricing', '/pricing', _isActive(const ['/pricing'])),
        _menuItem(
          'Contact',
          '/intake',
          _isActive(const ['/contact', '/intake']),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '/auth/login',
          child: Text('Sign in'),
        ),
        const PopupMenuItem<String>(
          value: '/auth/join',
          child: Text('Start setup'),
        ),
      ],
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.publicSurface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine),
        ),
        child: const Icon(Icons.menu, size: 20, color: AppTheme.publicText),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String label, String value, bool active) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppTheme.publicText : AppTheme.publicMuted,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
