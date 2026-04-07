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
        path == '/pricing' ||
        path == '/contact' ||
        path == '/privacy' ||
        path == '/terms' ||
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
            const _PublicFooter(),
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
                        onPressed: () => context.go('/login'),
                        style: TextButton.styleFrom(
                          foregroundColor: currentPath == '/login'
                              ? AppTheme.publicText
                              : AppTheme.publicMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Sign in'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => context.go('/join'),
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
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;

                final intro = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orchestrate',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.publicText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Text(
                        'A connected operating system for outbound work, client visibility, and revenue follow-through.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.publicMuted,
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                );

                final legal = _FooterGroup(
                  title: 'Legal',
                  links: [
                    _FooterLink(label: 'Terms of Use', onTap: () => context.go('/terms')),
                    _FooterLink(label: 'Privacy Policy', onTap: () => context.go('/privacy')),
                    _FooterLink(label: 'Service Agreement', onTap: () => context.go('/legal/service-agreement')),
                  ],
                );

                final operations = _FooterGroup(
                  title: 'Operations',
                  links: [
                    _FooterLink(label: 'Billing Policy', onTap: () => context.go('/legal/billing')),
                    _FooterLink(label: 'Refund Policy', onTap: () => context.go('/legal/refunds')),
                    _FooterLink(label: 'Acceptable Use', onTap: () => context.go('/legal/acceptable-use')),
                    _FooterLink(label: 'Deliverability Notice', onTap: () => context.go('/legal/deliverability')),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      intro,
                      const SizedBox(height: 22),
                      legal,
                      const SizedBox(height: 18),
                      operations,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: intro),
                    const SizedBox(width: 28),
                    Expanded(flex: 3, child: legal),
                    const SizedBox(width: 28),
                    Expanded(flex: 3, child: operations),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.publicText,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        ...[
          for (int i = 0; i < links.length; i++) ...[
            links[i],
            if (i != links.length - 1) const SizedBox(height: 10),
          ],
        ],
      ],
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
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
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
