import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/public/widgets/public_app_acquisition.dart';

class PublicShell extends StatelessWidget {
  const PublicShell(
      {super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  static const double _maxFrameWidth = 1320;
  static const double _footerReserveHeight = 168;

  // PublicShell is the canonical chrome for every public route. The
  // router never mounts it on a path that should bypass the chrome —
  // every GoRoute that wraps a child in PublicShell wants the full
  // header / footer / scroll experience. Previously a whitelist here
  // silently dropped the chrome (and the SingleChildScrollView) for
  // any path it did not know about, which caused new public routes
  // such as /why-orchestrate, /how-orchestrate-operates,
  // /trust-architecture, /for-evaluators, /activation, and
  // /account-deletion to render shell-less + unscrollable ("frozen").
  // Always rendering the chrome is the correct posture: a route that
  // wants different chrome must mount its own scaffold instead of
  // using PublicShell.

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _PublicHeader(currentPath: currentPath),
              PublicAppAcquisition(
                config: orchestratePublicAppAcquisitionConfig,
                currentPath: currentPath,
              ),
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
                      label: 'Intelligence',
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
                // Task #274 — balanced, intentional information architecture.
                // The footer answers five questions (what Orchestrate is,
                // how readiness works, the trust posture, legal obligations,
                // account/billing), each as a comparable column. It is NOT a
                // complete operational index: the ten detailed operational
                // trust policies (mailbox access, reply monitoring, AI usage,
                // credential handling, provider boundaries, suppression,
                // abuse, retention, deliverability) are surfaced on the
                // /trust-compliance hub — reachable from the header "Trust"
                // — rather than as a towering footer column.
                final groups = [
                  _FooterGroup(
                    title: 'Product',
                    links: [
                      _FooterLink(
                          label: 'Product',
                          onTap: () => context.go('/product')),
                      _FooterLink(
                          label: 'Why Orchestrate exists',
                          onTap: () => context.go('/why-orchestrate')),
                      _FooterLink(
                          label: 'How Orchestrate operates',
                          onTap: () => context.go('/how-orchestrate-operates')),
                      _FooterLink(
                          label: 'Intelligence',
                          onTap: () => context.go('/lead-sourcing')),
                    ],
                  ),
                  _FooterGroup(
                    title: 'Readiness',
                    links: [
                      _FooterLink(
                          label: 'Activation journey',
                          onTap: () => context.go('/how-it-works')),
                      _FooterLink(
                          label: 'DNS readiness check',
                          onTap: () => context.go('/diagnostics')),
                      _FooterLink(
                          label: 'Operational answers',
                          onTap: () => context.go('/answers')),
                    ],
                  ),
                  _FooterGroup(
                    title: 'Trust',
                    links: [
                      _FooterLink(
                          label: 'Trust + compliance',
                          onTap: () => context.go('/trust-compliance')),
                      _FooterLink(
                          label: 'Trust architecture',
                          onTap: () => context.go('/trust-architecture')),
                      _FooterLink(
                          label: 'For evaluators',
                          onTap: () => context.go('/for-evaluators')),
                      _FooterLink(
                          label: 'Acceptable use',
                          onTap: () => context.go('/legal/acceptable-use')),
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
                          label: 'Service agreement',
                          onTap: () => context.go('/legal/service-agreement')),
                    ],
                  ),
                  _FooterGroup(
                    title: 'Account',
                    links: [
                      _FooterLink(
                          label: 'Billing',
                          onTap: () => context.go('/legal/billing')),
                      _FooterLink(
                          label: 'Refunds',
                          onTap: () => context.go('/legal/refunds')),
                      _FooterLink(
                          label: 'Account deletion',
                          onTap: () => context.go('/account-deletion')),
                    ],
                  ),
                ];
                // Desktop: all five columns share ONE row as flexible
                // (Expanded) columns, distributed evenly edge-to-edge. They
                // get narrower as the viewport shrinks instead of a fixed
                // 208 px column wrapping onto a lonely second row (the bug
                // that left the 5th column stranded below). The threshold is
                // the width below which five columns can no longer hold their
                // longest label on one line; under it they fall back to a
                // fixed-width wrap (2–3 per row on tablet) and finally a clean
                // single-column stack on mobile.
                final wide = constraints.maxWidth >= 920;
                final groupArea = wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < groups.length; i++) ...[
                            Expanded(child: groups[i]),
                            if (i != groups.length - 1)
                              const SizedBox(width: 24),
                          ],
                        ],
                      )
                    : Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 32,
                        runSpacing: 32,
                        children: [
                          for (final g in groups)
                            SizedBox(width: 208, child: g),
                        ],
                      );
                // Reconciled 2026-06-01 — see
                // docs/ecosystem/FOOTER_RECONCILIATION_2026-06-01.md
                // in the personal repo. The earlier stacked
                // institutional band beneath the column groups read
                // as a second footer. The ecosystem is now a single
                // bottom-row attribution: "Aura Platform LLC ·
                // Part of Aura Platform LLC." on the left,
                // canonical five-link continuity on the right.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    groupArea,
                    const SizedBox(height: 24),
                    Container(height: 1, color: AppTheme.publicLine),
                    const SizedBox(height: 16),
                    const _PublicFooterBottomRow(),
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
    // Width-agnostic footer column. The caller sizes it: an Expanded slot
    // on desktop (all columns share one row and flex) or a fixed-width box
    // in the wrap fallback. Links are a plain Column so a wrapped heading
    // pushes its own links down without bleeding across neighbours.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.publicText,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 8),
        ...links,
      ],
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
          'Intelligence',
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

// ─────────────────────────────────────────────────────────────────────────────
// ECOSYSTEM CONTINUITY BAND
// ─────────────────────────────────────────────────────────────────────────────
//
// See docs/ecosystem/ECOSYSTEM_CONTINUITY_ARCHITECTURE.md in the
// personal repo for the doctrine this implements.
//
// Orchestrate's attribution copy is "Part of Aura Platform LLC." —
// substrate framing, not parent-corp framing. The five canonical links
// appear in doctrine-locked order; the current surface (Orchestrate)
// is the "you are here" link.

class _OrchEcosystemEntry {
  const _OrchEcosystemEntry({
    required this.slug,
    required this.label,
    required this.url,
  });
  final String slug;
  final String label;
  final String url;
}

const String _kOrchCompanyUrl = 'https://company.auraplatform.org';

const List<_OrchEcosystemEntry> _kOrchEcosystemLinks = <_OrchEcosystemEntry>[
  _OrchEcosystemEntry(slug: 'company', label: 'Company', url: _kOrchCompanyUrl),
  _OrchEcosystemEntry(
      slug: 'aura', label: 'Aura', url: 'https://auraplatform.org'),
  _OrchEcosystemEntry(
      slug: 'orchestrate',
      label: 'Orchestrate',
      url: 'https://orchestrateops.com'),
  _OrchEcosystemEntry(
      slug: 'bajwa-writes',
      label: 'Bajwa Writes',
      url: 'https://bajwawrites.com'),
  _OrchEcosystemEntry(
      slug: 'founder', label: 'Founder', url: 'https://bajwa.auraplatform.org'),
];

/// Bottom row of `_PublicFooter`. Sits beneath the column groups and
/// the single hairline. Institution lockup on the left (linked to the
/// company surface), canonical five-link continuity on the right.
/// One footer container, two layers — same pattern as the founder
/// surface, which is the reference implementation per
/// `docs/ecosystem/FOOTER_RECONCILIATION_2026-06-01.md`.
class _PublicFooterBottomRow extends StatelessWidget {
  const _PublicFooterBottomRow();

  static const String _kCurrentSlug = 'orchestrate';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final lockup = _lockup();
        const links = _OrchEcosystemLinkRow(currentSlug: _kCurrentSlug);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              lockup,
              const Spacer(),
              // Bound the link Wrap's width so it wraps onto additional rows
              // instead of overflowing the Row at narrower "wide" widths
              // (e.g. the 800px test surface). Without this the Wrap is given
              // unbounded width and lays every link on one line.
              Flexible(child: links),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lockup,
            const SizedBox(height: 10),
            links,
          ],
        );
      },
    );
  }

  Widget _lockup() {
    return InkWell(
      onTap: () => _orchOpenExternal(_kOrchCompanyUrl),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Aura Platform LLC',
              style: TextStyle(
                color: AppTheme.publicText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Part of Aura Platform LLC.',
              style: TextStyle(
                color: AppTheme.publicMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrchEcosystemLinkRow extends StatelessWidget {
  const _OrchEcosystemLinkRow({required this.currentSlug});
  final String currentSlug;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < _kOrchEcosystemLinks.length; i++) ...[
          if (i > 0)
            const Text('·',
                style: TextStyle(color: AppTheme.publicMuted, fontSize: 11)),
          _OrchEcosystemLink(
            link: _kOrchEcosystemLinks[i],
            currentSlug: currentSlug,
          ),
        ],
      ],
    );
  }
}

class _OrchEcosystemLink extends StatelessWidget {
  const _OrchEcosystemLink({required this.link, required this.currentSlug});
  final _OrchEcosystemEntry link;
  final String currentSlug;

  @override
  Widget build(BuildContext context) {
    final isCurrent = link.slug == currentSlug;
    final style = TextStyle(
      color: isCurrent ? AppTheme.publicText : AppTheme.publicMuted,
      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
      fontSize: 11,
      decoration: isCurrent ? TextDecoration.underline : TextDecoration.none,
      decorationColor: AppTheme.publicLine,
      decorationThickness: 1.2,
    );
    if (isCurrent) {
      return Semantics(
        selected: true,
        label: '${link.label} (current surface)',
        child: Text(link.label, style: style),
      );
    }
    return Semantics(
      link: true,
      label: 'Open ${link.label} surface',
      child: InkWell(
        onTap: () => _orchOpenExternal(link.url),
        child: Text(link.label, style: style),
      ),
    );
  }
}

Future<void> _orchOpenExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}
